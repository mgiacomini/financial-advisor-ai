defmodule FinancialAdvisorAi.Integrations.HubSpotClient do
  use Tesla

  @base_url "https://api.hubapi.com"

  def client(token) do
    Tesla.client([
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{token}"}]},
      {Tesla.Middleware.JSON, []}
    ])
  end

  # Contacts
  def list_contacts(token, params \\ %{}) do
    client(token)
    |> get("/crm/v3/objects/contacts", query: params)
  end

  def search_contacts(token, query) do
    body = %{
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

    client(token)
    |> post("/crm/v3/objects/contacts/search", body)
  end

  def create_contact(token, properties) do
    client(token)
    |> post("/crm/v3/objects/contacts", %{properties: properties})
  end

  # Notes (Engagements)
  def create_note(token, contact_id, note_content) do
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

    client(token)
    |> post("/crm/v3/objects/notes", body)
  end
end
