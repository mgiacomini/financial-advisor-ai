defmodule FinancialAdvisorAi.Tools.AddHubspotNote do
  alias FinancialAdvisorAi.Tasks

  def open_ai_spec do
    %{
      type: "function",
      function: %{
        name: "add_hubspot_note",
        description: "Add a note to a HubSpot contact",
        parameters: %{
          type: "object",
          properties: %{
            contact_id: %{type: "string"},
            note: %{type: "string"}
          },
          required: ["contact_id", "note"]
        }
      }
    }
  end

  def call(user_id, contact_id, note_content) do
    {:ok, _} =
      %{
        user_id: user_id,
        action: "add_note",
        data: %{
          contact_id: contact_id,
          note: note_content
        }
      }
      |> Tasks.HubSpotWorker.new()
      |> Oban.insert()

    {:ok, "Note for contact #{contact_id} has been queued for addition"}
  end
end
