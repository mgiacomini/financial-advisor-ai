defmodule FinancialAdvisorAi.RAG.Engine do
  import Ecto.Query
  import Pgvector.Ecto.Query

  alias FinancialAdvisorAi.{Repo, Integrations}
  alias FinancialAdvisorAi.RAG.Embedding

  require Logger

  ## Configs

  @chunk_size 1000
  @overlap 200
  @embedding_dimension 1536

  @zero_vector List.duplicate(0.0, @embedding_dimension)

  ## Ingestion sources

  @email_source_type "email"
  @hubspot_contact_source_type "hubspot_contact"

  ## Ingestion API

  @doc """
  Ingest email data into the knowledge base.

  ## Parameters
    - user_id: The ID of the user
    - email_data: The email data map containing subject, body, etc.

  ## Returns
    - :ok
  """
  @spec ingest_email(integer(), map()) :: :ok
  def ingest_email(user_id, email_data) do
    Logger.info("Ingesting email for user #{user_id}")

    content = extract_email_content(email_data)
    chunks = chunk_text(content, @chunk_size, @overlap)

    embeddings =
      generate_email_embeddings(
        user_id,
        email_data["id"],
        email_data["subject"],
        email_data["from"],
        email_data["date"],
        chunks
      )

    Repo.insert_all(Embedding, embeddings)
    :ok
  end

  @doc """
  Ingest HubSpot contacts into the knowledge base.

  ## Parameters
    - user_id: The ID of the user
    - contacts: The contacts list from HubSpot

  ## Returns
    - :ok
  """
  @spec ingest_hubspot_contacts(integer(), list()) :: :ok
  def ingest_hubspot_contacts(user_id, contacts) do
    Logger.info("Ingesting #{length(contacts)} HubSpot contacts for user #{user_id}")

    embeddings =
      Enum.map(contacts, fn contact ->
        generate_hubspot_contact_embedding(user_id, contact)
      end)

    Repo.insert_all(Embedding, embeddings)
    :ok
  end

  ## Search API

  @doc """
  Searches the knowledge base using semantic similarity.

  ## Parameters
    - user_id: The ID of the user
    - query: The search query string
    - limit: Maximum number of results to return (default: 10)

  ## Returns
    - A list of search results with content, metadata, and relevance scores
  """
  @spec search(integer(), String.t(), integer()) :: list()
  def search(user_id, query, limit \\ 10) do
    Logger.info("Searching knowledge base for user #{user_id} with query: #{query}")

    query_embedding = generate_open_ai_embedding(query)

    # Search similar embeddings
    Embedding
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], cosine_distance(e.embedding, ^query_embedding))
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(&format_result/1)
  end

  ## Embedding generation

  defp generate_email_embeddings(user_id, source_id, subject, from, date, chunks) do
    Enum.map(chunks, fn chunk ->
      %{
        user_id: user_id,
        source_id: source_id,
        source_type: @email_source_type,
        content: chunk,
        embedding: generate_open_ai_embedding(chunk),
        metadata: %{subject: subject, from: from, date: date},
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp generate_hubspot_contact_embedding(user_id, contact_data) do
    content = build_contact_content(contact_data)

    %{
      user_id: user_id,
      source_type: @hubspot_contact_source_type,
      source_id: to_string(contact_data["id"]),
      content: content,
      embedding: generate_open_ai_embedding(content),
      metadata: %{
        email: contact_data["properties"]["email"],
        name:
          "#{contact_data["properties"]["firstname"]} #{contact_data["properties"]["lastname"]}",
        company: contact_data["properties"]["company"]
      },
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp generate_open_ai_embedding(text) do
    Logger.info("Generating OpenAI embedding for text: #{text}")

    case Integrations.OpenAIClient.create_embedding(text) do
      {:ok, %{body: %{"data" => [%{"embedding" => embedding}]}}} ->
        Logger.info("Generated OpenAI embedding successfully")
        embedding

      {:ok, response} ->
        # Return zero vector as fallback
        Logger.error(
          "Failed to generate OpenAI embedding, returning zero vector. Reason: #{inspect(response)}"
        )

        @zero_vector

      {:error, reason} ->
        # Return zero vector as fallback
        Logger.error(
          "Failed to generate OpenAI embedding, returning zero vector. Reason: #{inspect(reason)}"
        )

        @zero_vector
    end
  end

  ## Email helpers

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
        # Handle URL-safe base64 encoding (used by Gmail API)
        try do
          # Convert URL-safe base64 to standard base64
          data
          |> String.replace("-", "+")
          |> String.replace("_", "/")
          |> Base.decode64!(padding: false)
        rescue
          ArgumentError ->
            # If decoding fails, try with padding
            try do
              data
              |> String.replace("-", "+")
              |> String.replace("_", "/")
              |> Base.decode64!()
            rescue
              ArgumentError ->
                Logger.error("Failed to decode base64 data: #{inspect(data)}")
                ""
            end
        end

      %{"parts" => parts} when is_list(parts) ->
        parts
        |> Enum.map(&extract_body_from_parts/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      _ ->
        ""
    end
  end

  ## HubSpot contact helpers

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

  ## Search helpers

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
