defmodule FinancialAdvisorAi.Integrations.GoogleClient do
  use Tesla

  @gmail_base_url "https://gmail.googleapis.com"
  @calendar_base_url "https://www.googleapis.com/calendar/v3"

  def client(token) do
    Tesla.client([
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{token}"}]},
      {Tesla.Middleware.JSON, []}
    ])
  end

  # Gmail methods
  def list_messages(token, query \\ "") do
    client(token)
    |> get("#{@gmail_base_url}/gmail/v1/users/me/messages", query: [q: query])
  end

  def get_message(token, message_id) do
    client(token)
    |> get("#{@gmail_base_url}/gmail/v1/users/me/messages/#{message_id}")
  end

  def send_email(token, email_data) do
    client(token)
    |> post("#{@gmail_base_url}/gmail/v1/users/me/messages/send", email_data)
  end

  # Calendar methods
  def list_events(token, calendar_id \\ "primary", params \\ []) do
    client(token)
    |> get("#{@calendar_base_url}/calendars/#{calendar_id}/events", query: params)
  end

  def create_event(token, calendar_id \\ "primary", event_data) do
    client(token)
    |> post("#{@calendar_base_url}/calendars/#{calendar_id}/events", event_data)
  end

  def get_free_busy(token, time_min, time_max, calendars) do
    body = %{
      timeMin: time_min,
      timeMax: time_max,
      items: Enum.map(calendars, &%{id: &1})
    }

    client(token)
    |> post("#{@calendar_base_url}/freeBusy", body)
  end
end
