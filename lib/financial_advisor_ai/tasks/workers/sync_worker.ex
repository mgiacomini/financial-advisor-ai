defmodule FinancialAdvisorAi.Tasks.SyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 1

  alias FinancialAdvisorAi.{Accounts, RAG, Integrations}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "type" => "gmail"}}) do
    token = Accounts.get_valid_oauth_token!(user_id, "google")

    # Get recent emails
    case Integrations.GoogleClient.list_messages(token.access_token, "is:unread") do
      {:ok, %{body: %{"messages" => messages}}} when is_list(messages) ->
        # Process each message
        Enum.each(messages, fn %{"id" => message_id} ->
          case Integrations.GoogleClient.get_message(token.access_token, message_id) do
            {:ok, %{body: email_data}} ->
              RAG.Engine.ingest_email(user_id, email_data)

            _ ->
              :ok
          end
        end)

        :ok

      _ ->
        :ok
    end
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id, "type" => "hubspot"}}) do
    token = Accounts.get_valid_oauth_token!(user_id, "hubspot")

    # Sync contacts
    case Integrations.HubSpotClient.list_contacts(token.access_token) do
      {:ok, %{body: %{"results" => contacts}}} when is_list(contacts) ->
        Enum.each(contacts, fn contact ->
          RAG.Engine.ingest_hubspot_contact(user_id, contact)
        end)

        :ok

      _ ->
        :ok
    end
  end
end
