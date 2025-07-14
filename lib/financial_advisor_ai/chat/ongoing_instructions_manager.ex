defmodule FinancialAdvisorAi.Chat.OngoingInstructionsManager do
  @moduledoc """
  Manages the ongoing instructions flow for conversations.

  This module handles:
  - Processing ongoing instructions during chat flow
  - Managing message states throughout the process
  - Handling tool calls and responses with proper state tracking
  - Error handling and recovery mechanisms
  """

  alias FinancialAdvisorAi.{Tasks, Tools, Integrations, Repo}
  alias FinancialAdvisorAi.Chat.{Agent, Message}

  import Ecto.Query
  require Logger

  @doc """
  Processes ongoing instructions for a conversation message.

  This is the main entry point for the ongoing instructions flow.
  It manages the complete lifecycle of processing a user message
  with ongoing instructions and tool calls.
  """
  def process_instructions(user_id, conversation_id, message_id) do
    Logger.info("Starting ongoing instructions flow for user #{user_id}, message #{message_id}")

    with {:ok, instructions} <- get_user_instructions(user_id),
         {:ok, messages} <- get_conversation_context(conversation_id),
         {:ok, system_prompt} <- build_system_prompt(instructions),
         {:ok, api_messages} <- prepare_messages_for_api(system_prompt, messages),
         {:ok, response} <- call_openai_with_tools(api_messages),
         {:ok, result} <- handle_openai_response(user_id, conversation_id, message_id, response) do
      Logger.info("Ongoing instructions flow completed successfully for message #{message_id}")
      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.error(
          "Ongoing instructions flow failed for message #{message_id}: #{inspect(reason)}"
        )

        update_message_state(message_id, "failed", inspect(reason))
        error
    end
  end

  @doc """
  Retrieves and validates user instructions.
  """
  def get_user_instructions(user_id) do
    try do
      instructions = Tasks.get_user_instructions(user_id)
      Logger.info("Retrieved #{length(instructions)} instructions for user #{user_id}")
      {:ok, instructions}
    rescue
      e ->
        Logger.error("Failed to retrieve instructions for user #{user_id}: #{inspect(e)}")
        {:error, :instructions_fetch_failed}
    end
  end

  @doc """
  Gets conversation context with message history.
  """
  def get_conversation_context(conversation_id) do
    messages =
      Message
      |> where([m], m.conversation_id == ^conversation_id)
      |> where([m], m.state in ["completed", "processing"])
      |> order_by([m], asc: m.inserted_at)
      |> Repo.all()

    {:ok, messages}
  end

  @doc """
  Builds system prompt with ongoing instructions.
  """
  def build_system_prompt(instructions) do
    try do
      prompt_description = """
      You are a financial advisor AI assistant. You can search for information and perform actions on behalf of your users.

      Be helpful, professional, and proactive. When scheduling meetings, always check availability first.
      When creating contacts, gather all relevant information from previous interactions.

      Follow the ongoing instructions provided by the user to maintain context and continuity.
      """

      system_prompt = Agent.system_prompt(instructions, prompt_description)
      {:ok, system_prompt}
    rescue
      e ->
        Logger.error("Failed to build system prompt: #{inspect(e)}")
        {:error, :prompt_build_failed}
    end
  end

  @doc """
  Prepares messages for OpenAI API format.
  """
  def prepare_messages_for_api(system_prompt, messages) do
    system_message = %{role: "system", content: system_prompt}

    message_list =
      Enum.map(messages, fn msg ->
        base_message = %{role: msg.role, content: to_string(msg.content || "")}

        # Add tool_calls if present for assistant messages
        if msg.role == "assistant" && msg.tool_calls && length(msg.tool_calls) > 0 do
          assistant_message = Map.put(base_message, :tool_calls, msg.tool_calls)

          tool_messages =
            Enum.map(msg.tool_calls, fn tool_call ->
              %{
                role: "tool",
                tool_call_id: tool_call["id"],
                content: Jason.encode!(msg.tool_responses)
              }
            end)

          [assistant_message | tool_messages]
        else
          base_message
        end
      end)
      |> List.flatten()

    api_messages = [system_message | message_list]
    {:ok, api_messages}
  end

  @doc """
  Calls OpenAI API with tool support.
  """
  def call_openai_with_tools(api_messages) do
    tools = Tools.list_tools()

    case Integrations.OpenAIClient.chat_completion(api_messages, tools) do
      {:ok, %{body: %{"choices" => [%{"message" => message}]}}} ->
        Logger.info("OpenAI API call successful")
        {:ok, message}

      {:ok, %{body: %{"error" => error}}} ->
        Logger.error("OpenAI API error: #{error["message"]}")
        {:error, {:openai_error, error}}

      {:error, error} ->
        Logger.error("OpenAI API call failed: #{inspect(error)}")
        {:error, {:api_call_failed, error}}
    end
  end

  @doc """
  Handles the OpenAI response and manages tool calls.
  """
  def handle_openai_response(user_id, conversation_id, message_id, %{
        "content" => _content,
        "tool_calls" => tool_calls
      })
      when not is_nil(tool_calls) do
    Logger.info("Processing OpenAI response with #{length(tool_calls)} tool calls")

    with {:ok, tool_responses} <- execute_tool_calls(user_id, tool_calls),
         {:ok, _} <-
           update_message_with_tools(
             message_id,
             "updated with tools resp",
             tool_calls,
             tool_responses
           ),
         {:ok, final_response} <-
           continue_conversation_with_tools(user_id, conversation_id, message_id, tool_responses) do
      {:ok, final_response}
    else
      error -> error
    end
  end

  def handle_openai_response(_user_id, _conversation_id, message_id, %{"content" => content}) do
    Logger.info("Processing OpenAI response with content only")
    update_message_completion(message_id, content)
  end

  @doc """
  Executes tool calls and handles errors gracefully.
  """
  def execute_tool_calls(user_id, tool_calls) do
    try do
      Logger.info("Executing #{length(tool_calls)} tool calls for user #{user_id}")
      tool_responses = Tools.execute_tool_calls(user_id, tool_calls)

      # Validate that every tool call got a response
      tool_call_ids = Enum.map(tool_calls, & &1["id"])
      response_ids = Enum.map(tool_responses, & &1.tool_call_id)

      missing_ids = tool_call_ids -- response_ids

      if length(missing_ids) > 0 do
        Logger.error("Missing responses for tool call IDs: #{inspect(missing_ids)}")

        # Create error responses for missing tool calls
        missing_responses =
          Enum.map(missing_ids, fn id ->
            %{
              tool_call_id: id,
              content: %{error: "No response generated"}
            }
          end)

        Enum.concat(tool_responses, missing_responses)
      end

      Logger.info("Tool execution completed with #{length(tool_responses)} responses")
      {:ok, tool_responses}
    rescue
      e ->
        Logger.error("Tool execution failed for user #{user_id}: #{inspect(e)}")
        {:error, {:tool_execution_failed, e}}
    end
  end

  @doc """
  Continues conversation after tool execution.
  """
  def continue_conversation_with_tools(_user_id, conversation_id, message_id, _tool_responses) do
    Logger.info("Continuing conversation with tool results")

    with {:ok, messages} <- get_conversation_context(conversation_id),
         {:ok, api_messages} <- prepare_messages_for_api("", messages),
         #  {:ok, enhanced_messages} <- add_tool_responses_to_messages(api_messages, tool_responses),
         {:ok, response} <- call_openai_with_tools(api_messages),
         {:ok, result} <- finalize_conversation(message_id, response) do
      {:ok, result}
    else
      error -> error
    end
  end

  @doc """
  Finalizes the conversation with the final response.
  """
  def finalize_conversation(message_id, %{"content" => final_content}) do
    update_message_completion(message_id, final_content)
  end

  # Private helper functions

  defp update_message_with_tools(message_id, content, tool_calls, tool_responses) do
    try do
      from(m in Message, where: m.id == ^message_id)
      |> Repo.update_all(
        set: [
          content: content,
          tool_calls: tool_calls,
          tool_responses: tool_responses,
          state: "processing"
        ]
      )

      Logger.info("Message #{message_id} updated with tool data")
      {:ok, :updated}
    rescue
      e ->
        Logger.error("Failed to update message with tools: #{inspect(e)}")
        {:error, :message_update_failed}
    end
  end

  defp update_message_completion(message_id, content) do
    try do
      from(m in Message, where: m.id == ^message_id)
      |> Repo.update_all(
        set: [
          content: content,
          state: "completed",
          processed_at: DateTime.utc_now()
        ]
      )

      Logger.info("Message #{message_id} marked as completed")
      {:ok, :completed}
    rescue
      e ->
        Logger.error("Failed to complete message: #{inspect(e)}")
        {:error, :message_completion_failed}
    end
  end

  defp update_message_state(message_id, state, error_message) do
    try do
      update_params = [
        state: state,
        processed_at: DateTime.utc_now()
      ]

      update_params =
        if error_message,
          do: [{:error_message, error_message} | update_params],
          else: update_params

      from(m in Message, where: m.id == ^message_id)
      |> Repo.update_all(set: update_params)

      Logger.info("Message #{message_id} state updated to #{state}")
      {:ok, state}
    rescue
      e ->
        Logger.error("Failed to update message state: #{inspect(e)}")
        {:error, :state_update_failed}
    end
  end
end
