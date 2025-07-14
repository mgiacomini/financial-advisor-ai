defmodule FinancialAdvisorAi.Tools.CreateHubspotContact do
  alias FinancialAdvisorAi.Tasks

  def open_ai_spec do
    %{
      type: "function",
      function: %{
        name: "create_hubspot_contact",
        description: "Create a HubSpot contact",
        parameters: %{
          type: "object",
          properties: %{
            email: %{type: "string"},
            firstname: %{type: "string"},
            lastname: %{type: "string"},
            phone: %{type: "string"}
          },
          required: ["email"]
        }
      }
    }
  end

  def call(user_id, email, first_name, last_name, phone) do
    %{
      user_id: user_id,
      action: "create_contact",
      data: %{
        email: email,
        firstname: first_name,
        lastname: last_name,
        phone: phone
      }
    }
    |> Tasks.HubSpotWorker.new()
    |> Oban.insert()
  end
end
