defmodule FinancialAdvisorAi.Tools.SearchKnowledgeBase do
  @moduledoc "Search through emails and HubSpot data"

  alias FinancialAdvisorAi.RAG

  require Logger

  ## Tool specification for OpenAI API

  @open_api_spec %{
    type: "function",
    function: %{
      name: "search_knowledge_base",
      description: "Search through emails and HubSpot data",
      parameters: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Search query"}
        },
        required: ["query"]
      }
    }
  }

  @spec open_api_spec() :: map()
  def open_api_spec, do: @open_api_spec

  ## Tool call implementation

  @doc """
  Searches the knowledge base for a user with a given query.

  ## Parameters
    - user_id: The ID of the user
    - query: The search query string

  ## Returns
    - A list of search results with content, metadata, and relevance scores
  """
  @spec call(integer(), String.t()) :: {:ok, list()} | {:error, String.t()}
  def call(user_id, query) do
    Logger.info("Searching knowledge base for user #{user_id} with query: #{query}")

    knowledge_base_search_results = RAG.search(user_id, query)
    {:ok, knowledge_base_search_results}
  end
end
