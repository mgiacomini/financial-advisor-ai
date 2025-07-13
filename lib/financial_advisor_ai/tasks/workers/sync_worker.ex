defmodule FinancialAdvisorAi.Tasks.SyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 1

  alias FinancialAdvisorAi.{RAG, Integrations}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "type" => "gmail"}}) do
    access_token =
      user_id
      |> Integrations.get_google_oauth_token()
      |> Map.get(:access_token)

    # Get recent emails
    case Integrations.GoogleClient.list_messages(access_token, "is:unread") do
      {:ok, %{body: %{"messages" => messages}}} when is_list(messages) ->
        # Process each message
        Enum.each(messages, fn %{"id" => message_id} ->
          case Integrations.GoogleClient.get_message(access_token, message_id) do
            {:ok, %{body: email_data}} -> RAG.Engine.ingest_email(user_id, email_data)
            _ -> :ok
          end
        end)

      _ ->
        :ok
    end
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id, "type" => "hubspot"}}) do
    api_key = Integrations.get_hubspot_api_key(user_id)

    # Sync contacts
    case Integrations.HubSpotClient.list_contacts(api_key) do
      {:ok, %{body: %{"results" => contacts}}} when is_list(contacts) ->
        Enum.each(contacts, fn contact ->
          RAG.Engine.ingest_hubspot_contact(user_id, contact)
        end)

      _ ->
        :ok
    end
  end
end
