defmodule FinancialAdvisorAi.Tools.SearchHubspotContacts do
  @moduledoc "Search HubSpot contacts using the HubSpot API"

  alias FinancialAdvisorAi.Tasks

  require Logger

  ## Tool specification for OpenAI API

  @open_api_spec %{
    type: "function",
    function: %{
      name: "search_hubspot_contacts",
      description: "Search HubSpot contacts",
      parameters: %{
        type: "object",
        properties: %{
          query: %{type: "string"}
        },
        required: ["query"]
      }
    }
  }

  @spec open_api_spec() :: map()
  def open_api_spec, do: @open_api_spec

  ## Tool call implementation

  @doc """
  Searches HubSpot contacts for a user with a given query.

  ## Parameters
    - user_id: The ID of the user
    - query: The search query string

  ## Returns
    - {:ok, results} on success
    - {:error, reason} on failure
  """
  @spec call(integer(), String.t()) :: {:ok, list()} | {:error, any()}
  def call(user_id, query) do
    Logger.info("Searching HubSpot contacts for user #{user_id} with query: #{query}")

    Tasks.search_hubspot_contacts(user_id, query)
  end
end
