defmodule FinancialAdvisorAi.Chat.Agents.WebhookAgent do
  alias FinancialAdvisorAi.Chat.Agent
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

    with {:ok, tool_calls} <- fetch_tool_calls_from_event(instructions, prompt) do
      Logger.info("Found #{length(tool_calls)} tool calls to execute for user #{user_id}")
      Tools.execute_tool_calls(user_id, tool_calls)
    else
      {:error, :no_tool_calls} ->
        Logger.info("No tool calls found in event for user #{user_id}")

      {:error, reason} ->
        Logger.error("Failed to process system event for user #{user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Fetches tool calls from the event based on instructions and prompt

  defp fetch_tool_calls_from_event(instructions, prompt) do
    Logger.info("Fetching tool calls from event")

    api_messages = [
      %{role: "system", content: build_system_prompt(instructions)},
      %{role: "user", content: prompt}
    ]

    with {:ok, resp} <- Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      extract_tool_calls_from_chat_completion_response(resp)
    end
  end

  defp extract_tool_calls_from_chat_completion_response(resp) do
    with %{body: body} <- resp,
         %{"choices" => choices} <- body,
         %{"message" => %{"tool_calls" => tool_calls}} <- List.first(choices),
         true <- is_list(tool_calls) do
      {:ok, tool_calls}
    else
      _ -> {:error, :no_tool_calls}
    end
  end

  ## Prompt

  defp build_system_prompt(instructions) do
    prompt_description = """
    You can perform actions based on incoming events and webhooks.

    Be proactive and respond to events that require action. Only take action when necessary and appropriate.
    When processing events, consider the user's ongoing instructions and preferences.
    """

    Agent.system_prompt(instructions, prompt_description)
  end
end
