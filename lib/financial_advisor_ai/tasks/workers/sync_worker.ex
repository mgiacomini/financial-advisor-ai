defmodule FinancialAdvisorAi.Tasks.SyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 1

  alias FinancialAdvisorAi.{RAG, Integrations}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "type" => "gmail"}}) do
    Logger.info("Syncing Gmail for user #{user_id}")

    access_token =
      user_id
      |> Integrations.get_google_oauth_token()
      |> Map.get(:access_token)

    # Get recent emails
    Logger.info("Fetching recent emails for user #{user_id}")

    case Integrations.GoogleClient.list_messages(access_token, "is:unread") do
      {:ok, %{body: %{"messages" => messages}}} when is_list(messages) ->
        Logger.info("Found #{length(messages)} unread emails for user #{user_id}")

        # Process each message
        Enum.each(messages, fn %{"id" => message_id} ->
          Logger.info("Processing email message ID #{message_id} for user #{user_id}")

          case Integrations.GoogleClient.get_message(access_token, message_id) do
            {:ok, %{body: email_data}} ->
              Logger.info("Fetched email data for message ID #{message_id} for user #{user_id}")
              RAG.Engine.ingest_email(user_id, email_data)

            error ->
              Logger.error(
                "Failed to fetch email data for message ID #{message_id} for user #{user_id}. Error: #{inspect(error)}"
              )
          end
        end)

      error ->
        Logger.error(
          "Failed to fetch recent emails for user #{user_id}. Error: #{inspect(error)}"
        )
    end
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id, "type" => "hubspot"}}) do
    Logger.info("Syncing HubSpot contacts for user #{user_id}")
    api_key = Integrations.get_hubspot_api_key(user_id)

    case Integrations.HubSpotClient.list_contacts(api_key) do
      {:ok, %{body: %{"results" => contacts}}} when is_list(contacts) ->
        Logger.info("Ingesting #{length(contacts)} HubSpot contacts for user #{user_id}")
        RAG.Engine.ingest_hubspot_contacts(user_id, contacts)

      {:ok, resp} ->
        Logger.error("Failed to fetch HubSpot contacts for user #{user_id}: #{inspect(resp)}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to fetch HubSpot contacts for user #{user_id}: #{inspect(reason)}")
        :ok
    end
  end
end
