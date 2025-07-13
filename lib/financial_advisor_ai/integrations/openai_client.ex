defmodule FinancialAdvisorAi.Integrations.OpenAIClient do
  use Tesla

  alias FinancialAdvisorAi.Integrations

  @base_url "https://api.openai.com/v1"
  @model "gpt-4o"
  @embedding_model "text-embedding-3-small"

  def client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.Headers,
       [
         {"authorization", "Bearer #{api_key()}"},
         {"content-type", "application/json"}
       ]},
      {Tesla.Middleware.JSON, []}
    ])
  end

  def chat_completion(messages, tools \\ nil) do
    body = %{
      model: @model,
      messages: messages,
      temperature: 0.7
    }

    body = if tools, do: Map.put(body, :tools, tools), else: body

    client()
    |> post("/chat/completions", body)
  end

  def create_embedding(text) do
    body = %{
      model: @embedding_model,
      input: text
    }

    client()
    |> post("/embeddings", body)
  end

  defp api_key do
    Integrations.get_openai_api_key()
  end
end
