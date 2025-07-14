defmodule FinancialAdvisorAi.Tools.CreateTask do
  alias FinancialAdvisorAi.Tasks

  def open_ai_spec do
    %{
      type: "function",
      function: %{
        name: "create_task",
        description: "Create a task for later execution",
        parameters: %{
          type: "object",
          properties: %{
            type: %{type: "string"},
            data: %{type: "object"},
            execute_at: %{type: "string", description: "ISO 8601 datetime"}
          },
          required: ["type", "data"]
        }
      }
    }
  end

  def call(user_id, args) do
    Tasks.create_deferred_task(user_id, args)
  end
end
