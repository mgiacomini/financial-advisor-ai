defmodule FinancialAdvisorAi.Chat.Agents.ChatAgent do
  alias FinancialAdvisorAi.Chat.{Message, OngoingInstructionsManager}
  alias FinancialAdvisorAi.Repo

  require Logger

  @doc """
  Processes a user message in a conversation using the ongoing instructions flow.

  This function:
  1. Creates a user message record marked as completed
  2. Creates an assistant message record in processing state
  3. Delegates to OngoingInstructionsManager for the full flow
  """
  def process_message(user_id, conversation_id, user_message) do
    Logger.info("Processing user message for user #{user_id} in conversation #{conversation_id}")

    with {:ok, _user_msg} <-
           create_message(conversation_id, "user", user_message, state: "completed"),
         {:ok, assistant_msg} <-
           create_message(conversation_id, "assistant", "procesing...", state: "processing") do
      # Process the ongoing instructions
      OngoingInstructionsManager.process_instructions(user_id, conversation_id, assistant_msg.id)
    else
      {:error, error} ->
        Logger.error("Failed to create messages for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  ## Message creation functions

  defp create_message(conversation_id, role, content, opts) do
    Logger.info("Creating message for conversation #{conversation_id} with role #{role}")

    %Message{}
    |> Message.changeset(%{
      conversation_id: conversation_id,
      role: role,
      content: content,
      tool_calls: opts[:tool_calls],
      tool_responses: opts[:tool_responses],
      state: opts[:state] || "pending"
    })
    |> Repo.insert()
  end
end
