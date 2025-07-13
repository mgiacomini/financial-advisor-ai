defmodule FinancialAdvisorAi.Chat.Agents.WebhookAgent do
  alias FinancialAdvisorAi.{Tools, Integrations}

  require Logger

  @tools Tools.list_tools()

  @doc """
  Processes a system event triggered by webhooks.

  ## Parameters
    - user_id: The ID of the user
    - prompt: The system prompt describing the event
    - instructions: List of ongoing instructions that might apply

  ## Returns
    - :ok on success
    - {:error, reason} on failure
  """
  def process_system_event(user_id, prompt, instructions) do
    Logger.info("Processing system event for user #{user_id}")

    api_messages = [
      %{role: "system", content: build_system_prompt(instructions)},
      %{role: "user", content: prompt}
    ]

    # Call OpenAI to determine if action should be taken
    case Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      {:ok, %{body: %{"choices" => [%{"message" => assistant_message}]}}} ->
        Logger.info("Received assistant response for system event for user #{user_id}")

        # Execute any tool calls without saving to conversation
        case assistant_message do
          %{"tool_calls" => tool_calls} when is_list(tool_calls) ->
            Tools.execute_tool_calls(user_id, tool_calls)

          _ ->
            # No tool calls needed
            :ok
        end

        :ok

      {:error, error} ->
        Logger.error("Failed to process system event for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  ## Helper functions

  defp build_system_prompt(instructions) do
    Logger.info("Building system prompt with instructions")

    base_prompt = """
    You are an AI assistant for a financial advisor processing system events. You have access to their emails,
    calendar, and HubSpot CRM. You can perform actions based on incoming events and webhooks.

    Be proactive and respond to events that require action. Only take action when necessary and appropriate.
    When processing events, consider the user's ongoing instructions and preferences.
    """

    if Enum.any?(instructions) do
      instruction_text =
        instructions
        |> Enum.map(& &1.instruction)
        |> Enum.join("\n- ")

      base_prompt <> "\n\nOngoing instructions to follow:\n- " <> instruction_text
    else
      base_prompt
    end
  end
end
