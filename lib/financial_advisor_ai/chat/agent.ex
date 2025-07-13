defmodule FinancialAdvisorAi.Chat.Agent do
  @moduledoc """
  Main agent module that delegates to specialized agents.
  This module maintains backward compatibility while the codebase transitions to the new structure.
  """

  alias FinancialAdvisorAi.Chat.Agents.{ChatAgent, WebhookAgent}

  @doc """
  Processes a user message in a conversation.
  Delegates to ChatAgent.
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
end
