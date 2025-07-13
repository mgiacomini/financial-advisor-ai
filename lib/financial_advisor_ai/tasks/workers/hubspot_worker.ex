defmodule FinancialAdvisorAi.Tasks.HubSpotWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias FinancialAdvisorAi.Integrations

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "action" => action, "data" => data}}) do
    api_key = Integrations.get_hubspot_api_key(user_id)

    case action do
      "create_contact" -> create_contact(api_key, data)
      "add_note" -> add_note(api_key, data["contact_id"], data["note"])
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp create_contact(token, data) do
    properties = %{
      email: data["email"],
      firstname: data["firstname"],
      lastname: data["lastname"],
      phone: data["phone"]
    }

    case Integrations.HubSpotClient.create_contact(token, properties) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp add_note(token, contact_id, note_content) do
    case Integrations.HubSpotClient.create_note(token, contact_id, note_content) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end
end
