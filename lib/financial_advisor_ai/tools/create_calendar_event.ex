defmodule FinancialAdvisorAi.Tools.CreateCalendarEvent do
  @moduledoc "Create calendar events using the configured calendar service"

  alias FinancialAdvisorAi.Tasks

  require Logger

  ## Tool specification for OpenAI API

  @open_ai_spec %{
    type: "function",
    function: %{
      name: "create_calendar_event",
      description: "Create a calendar event",
      parameters: %{
        type: "object",
        properties: %{
          title: %{type: "string"},
          start_time: %{type: "string", description: "ISO 8601 datetime"},
          end_time: %{type: "string", description: "ISO 8601 datetime"},
          attendees: %{type: "array", items: %{type: "string"}}
        },
        required: ["title", "start_time", "end_time"]
      }
    }
  }

  @spec open_ai_spec() :: map()
  def open_ai_spec, do: @open_ai_spec

  ## Tool call implementation

  @doc """
  Creates a calendar event for a user.

  ## Parameters
    - user_id: The ID of the user
    - title: Event title
    - start_time: Start time in ISO 8601 format
    - end_time: End time in ISO 8601 format
    - attendees: List of attendee email addresses (optional)

  ## Returns
    - {:ok, Oban.Job.t()} on success
    - {:error, Ecto.Changeset.t()} on failure
  """
  @spec call(integer(), String.t(), String.t(), String.t(), list()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def call(user_id, title, start_time, end_time, attendees \\ []) do
    Logger.info("Creating calendar event for user #{user_id} with title: #{title}")

    %{
      user_id: user_id,
      action: "create_event",
      data: %{
        title: title,
        start_time: start_time,
        end_time: end_time,
        attendees: attendees
      }
    }
    |> Tasks.CalendarWorker.new()
    |> Oban.insert()
  end
end
