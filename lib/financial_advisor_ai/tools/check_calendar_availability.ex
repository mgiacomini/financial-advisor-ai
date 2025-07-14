defmodule FinancialAdvisorAi.Tools.CheckCalendarAvailability do
  alias FinancialAdvisorAi.Tasks

  def open_ai_spec do
    %{
      type: "function",
      function: %{
        name: "check_calendar_availability",
        description: "Check calendar availability",
        parameters: %{
          type: "object",
          properties: %{
            start_date: %{type: "string", description: "ISO 8601 date"},
            end_date: %{type: "string", description: "ISO 8601 date"}
          },
          required: ["start_date", "end_date"]
        }
      }
    }
  end

  def call(user_id, start_date, end_date) do
    Tasks.check_calendar_availability(user_id, start_date, end_date)
  end
end
