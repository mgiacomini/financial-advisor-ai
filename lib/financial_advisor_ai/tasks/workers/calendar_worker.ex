defmodule FinancialAdvisorAi.Tasks.CalendarWorker do
  use Oban.Worker, queue: :default

  alias FinancialAdvisorAi.Integrations

  require Logger

  @default_calendar_id "primary"
  @default_time_zone "America/New_York"

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "action" => "create_event", "data" => data}
      }) do
    Logger.info("Creating calendar event for user #{user_id} with data: #{inspect(data)}")
    token = Integrations.get_google_oauth_token(user_id)

    event_data = %{
      summary: data["title"],
      start: %{
        dateTime: data["start_time"],
        timeZone: @default_time_zone
      },
      end: %{
        dateTime: data["end_time"],
        timeZone: @default_time_zone
      },
      attendees: Enum.map(data["attendees"] || [], &%{email: &1})
    }

    case Integrations.GoogleClient.create_event(
           token.access_token,
           @default_calendar_id,
           event_data
         ) do
      {:ok, _response} ->
        Logger.info("Calendar event created successfully")

      {:error, error} ->
        Logger.error("Failed to create calendar event: #{inspect(error)}")
        {:error, error}
    end
  end
end
