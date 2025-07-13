defmodule FinancialAdvisorAi.Tasks.HubSpotWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias FinancialAdvisorAi.{Accounts, Integrations}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "action" => action, "data" => data}}) do
    token = Accounts.get_valid_oauth_token!(user_id, "hubspot")

    case action do
      "create_contact" ->
        create_contact(token.access_token, data)

      "add_note" ->
        add_note(token.access_token, data["contact_id"], data["note"])

      _ ->
        {:error, "Unknown action: #{action}"}
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
      {:ok, _response} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp add_note(token, contact_id, note_content) do
    case Integrations.HubSpotClient.create_note(token, contact_id, note_content) do
      {:ok, _response} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end
