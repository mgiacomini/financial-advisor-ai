defmodule FinancialAdvisorAi.RAG.Engine do
  alias FinancialAdvisorAi.{Repo, Integrations}
  alias FinancialAdvisorAi.RAG.Embedding
  import Ecto.Query
  import Pgvector.Ecto.Query

  @chunk_size 1000
  @overlap 200
  @embedding_dimension 1536

  def ingest_email(user_id, email_data) do
    # Extract text content from email
    content = extract_email_content(email_data)

    # Chunk the content
    chunks = chunk_text(content, @chunk_size, @overlap)

    # Generate embeddings and save
    Enum.each(chunks, fn chunk ->
      embedding = generate_embedding(chunk)

      %Embedding{}
      |> Embedding.changeset(%{
        user_id: user_id,
        source_type: "email",
        source_id: email_data["id"],
        content: chunk,
        embedding: embedding,
        metadata: %{
          subject: email_data["subject"],
          from: email_data["from"],
          date: email_data["date"]
        }
      })
      |> Repo.insert()
    end)
  end

  def ingest_hubspot_contact(user_id, contact_data) do
    # Build content from contact properties
    content = build_contact_content(contact_data)

    # Generate embedding
    embedding = generate_embedding(content)

    %Embedding{}
    |> Embedding.changeset(%{
      user_id: user_id,
      source_type: "hubspot_contact",
      source_id: to_string(contact_data["id"]),
      content: content,
      embedding: embedding,
      metadata: %{
        email: contact_data["properties"]["email"],
        name:
          "#{contact_data["properties"]["firstname"]} #{contact_data["properties"]["lastname"]}",
        company: contact_data["properties"]["company"]
      }
    })
    |> Repo.insert()
  end

  def search(user_id, query, limit \\ 10) do
    # Generate embedding for query
    query_embedding = generate_embedding(query)

    # Search similar embeddings
    Embedding
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], cosine_distance(e.embedding, ^query_embedding))
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(&format_result/1)
  end

  defp generate_embedding(text) do
    case Integrations.OpenAIClient.create_embedding(text) do
      {:ok, %{body: %{"data" => [%{"embedding" => embedding}]}}} ->
        embedding

      {:error, _} ->
        # Return zero vector as fallback
        List.duplicate(0.0, @embedding_dimension)
    end
  end

  defp chunk_text(text, chunk_size, overlap) do
    words = String.split(text, ~r/\s+/)

    words
    |> Enum.chunk_every(chunk_size, chunk_size - overlap)
    |> Enum.map(&Enum.join(&1, " "))
  end

  defp extract_email_content(email_data) do
    # Extract plain text from email
    # This is simplified - in reality you'd parse MIME parts
    subject = email_data["subject"] || ""
    body = extract_body_from_parts(email_data["payload"])

    "Subject: #{subject}\n\n#{body}"
  end

  defp extract_body_from_parts(payload) do
    # Simplified extraction - real implementation would handle MIME properly
    case payload do
      %{"body" => %{"data" => data}} when not is_nil(data) ->
        Base.decode64!(data, padding: false)

      %{"parts" => parts} when is_list(parts) ->
        parts
        |> Enum.map(&extract_body_from_parts/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      _ ->
        ""
    end
  end

  defp build_contact_content(contact_data) do
    props = contact_data["properties"] || %{}

    parts = [
      "Contact: #{props["firstname"]} #{props["lastname"]}",
      "Email: #{props["email"]}",
      "Company: #{props["company"]}",
      "Phone: #{props["phone"]}",
      "Notes: #{props["notes"]}"
    ]

    parts
    |> Enum.reject(fn part -> part =~ "nil" or part =~ ": $" end)
    |> Enum.join("\n")
  end

  defp format_result(embedding) do
    %{
      content: embedding.content,
      source_type: embedding.source_type,
      source_id: embedding.source_id,
      metadata: embedding.metadata,
      # Would be actual cosine similarity
      relevance_score: 1.0
    }
  end
end
