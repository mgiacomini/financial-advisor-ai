defmodule FinancialAdvisorAi.RAG do
  alias FinancialAdvisorAi.RAG.Engine

  @doc """
  Searches the knowledge base using semantic similarity.

  ## Parameters
    - user_id: The ID of the user
    - query: The search query string
    
  ## Returns
    - A list of search results with content, metadata, and relevance scores
  """
  def search(user_id, query) do
    Engine.search(user_id, query)
  end
end
