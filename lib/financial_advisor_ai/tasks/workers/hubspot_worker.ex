defmodule FinancialAdvisorAi.Tasks.HubSpotWorker do
  use Oban.Worker, queue: :default

  alias FinancialAdvisorAi.Integrations

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "action" => action, "data" => data}}) do
    Logger.info("Performing HubSpot action #{action} for user #{user_id}")
    api_key = Integrations.get_hubspot_api_key(user_id)

    case action do
      "create_contact" -> create_contact(api_key, data)
      "add_note" -> add_note(api_key, data["contact_id"], data["note"])
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp create_contact(token, data) do
    Logger.info("Creating contact with data: #{inspect(data)}")

    properties = %{
      email: data["email"],
      firstname: data["firstname"],
      lastname: data["lastname"],
      phone: data["phone"]
    }

    case Integrations.HubSpotClient.create_contact(token, properties) do
      {:ok, _response} ->
        Logger.info("Contact created successfully")

      {:error, error} ->
        Logger.error("Failed to create contact: #{inspect(error)}")
        {:error, error}
    end
  end

  defp add_note(token, contact_id, note_content) do
    Logger.info("Adding note to contact #{contact_id} with content: #{note_content}")

    case Integrations.HubSpotClient.create_note(token, contact_id, note_content) do
      {:ok, _response} ->
        Logger.info("Note added successfully")

      {:error, error} ->
        Logger.error("Failed to add note: #{inspect(error)}")
        {:error, error}
    end
  end
end
