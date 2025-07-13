defmodule FinancialAdvisorAi.Integrations.HubSpotClient do
  use Tesla

  require Logger

  ## Guard clauses

  defguard is_blank(str) when str in [nil, "", " "]

  ## Client constructor

  @base_url "https://api.hubapi.com"

  def client(token) do
    Logger.info("Creating HubSpot client with token")

    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{token}"}]},
      {Tesla.Middleware.JSON, []}
    ])
  end

  ## Contacts

  def list_contacts(token, params \\ %{}) do
    Logger.info("Listing contacts with params: #{inspect(params)}")

    token
    |> client()
    |> get("/crm/v3/objects/contacts", query: params)
  end

  def search_contacts(token, query) do
    Logger.info("Searching contacts")
    body = build_contact_search_query(query)

    token
    |> client()
    |> post("/crm/v3/objects/contacts/search", body)
  end

  defp build_contact_search_query(query) when is_blank(query) do
    Logger.warning("Empty query provided, returning empty search query")

    %{}
  end

  defp build_contact_search_query(query) do
    Logger.info("Building contacts search query for: #{query}")

    %{
      filterGroups: [
        %{
          filters: [
            %{
              propertyName: "email",
              operator: "CONTAINS_TOKEN",
              value: query
            }
          ]
        }
      ]
    }
  end

  def create_contact(token, properties) do
    Logger.info("Creating contact with properties: #{inspect(properties)}")

    token
    |> client()
    |> post("/crm/v3/objects/contacts", %{properties: properties})
  end

  ## Notes (Engagements)

  def create_note(token, contact_id, note_content) do
    Logger.info("Creating note for contact #{contact_id} with content: #{note_content}")

    body = %{
      properties: %{
        hs_note_body: note_content,
        hs_timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      },
      associations: [
        %{
          to: %{id: contact_id},
          types: [%{associationCategory: "HUBSPOT_DEFINED", associationTypeId: 202}]
        }
      ]
    }

    token
    |> client()
    |> post("/crm/v3/objects/notes", body)
  end
end
