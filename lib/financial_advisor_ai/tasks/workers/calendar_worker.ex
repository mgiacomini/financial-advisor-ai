defmodule FinancialAdvisorAi.Tasks.CalendarWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias FinancialAdvisorAi.{Accounts, Integrations}

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "action" => "create_event", "data" => data}
      }) do
    token = Accounts.get_valid_oauth_token!(user_id, "google")

    event_data = %{
      summary: data["title"],
      start: %{
        dateTime: data["start_time"],
        timeZone: "America/New_York"
      },
      end: %{
        dateTime: data["end_time"],
        timeZone: "America/New_York"
      },
      attendees: Enum.map(data["attendees"] || [], &%{email: &1})
    }

    case Integrations.GoogleClient.create_event(token.access_token, "primary", event_data) do
      {:ok, _response} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end
