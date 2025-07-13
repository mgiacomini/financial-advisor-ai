defmodule FinancialAdvisorAi.Chat.Agent do
  @moduledoc """
  Main agent module that delegates to specialized agents.
  This module maintains backward compatibility while the codebase transitions to the new structure.
  """

  alias FinancialAdvisorAi.Chat.Agents.{ChatAgent, WebhookAgent}

  require Logger

  @doc """
  Processes a user message in a conversation and replies.
  Delegates to ChatAgent.

  ## Parameters
    - user_id: The ID of the user
    - conversation_id: The ID of the conversation
    - user_message: The content of the user's message

  ## Returns
    - {:ok, message} on success
    - {:error, reason} on failure
  """
  def process_message(user_id, conversation_id, user_message) do
    ChatAgent.process_message(user_id, conversation_id, user_message)
  end

  @doc """
  Processes a system event triggered by webhooks.
  Delegates to WebhookAgent.

  ## Parameters
    - user_id: The ID of the user
    - prompt: The system prompt describing the event
    - instructions: List of ongoing instructions that might apply

  ## Returns
    - :ok on success
    - {:error, reason} on failure
  """
  def process_system_event(user_id, prompt, instructions) do
    WebhookAgent.process_system_event(user_id, prompt, instructions)
  end

  @doc """
  Builds a system prompt with ongoing instructions.

  ## Parameters
    - instructions: List of ongoing instructions
    - prompt_description: Optional description to include in the prompt

  ## Returns
    - String containing the system prompt
  """
  def system_prompt(instructions, prompt_description \\ "") do
    Logger.info("Building system prompt with instructions")

    base_prompt = """
    You are an AI assistant for a financial advisor processing system events. You have access to their emails,
    calendar, and HubSpot CRM.

    #{prompt_description}
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
