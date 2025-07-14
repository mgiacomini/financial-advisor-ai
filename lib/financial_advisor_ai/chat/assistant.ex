defmodule FinancialAdvisorAi.Chat.Assistant do
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

  ## Instructions and message processing

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
         {:ok, response} <- call_openai_with_tools(system_prompt, messages),
         {:ok, result} <- handle_openai_response(user_id, conversation_id, message_id, response) do
      Logger.info("Ongoing instructions flow completed successfully for message #{message_id}")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error(
          "Ongoing instructions flow failed for message #{message_id}: #{inspect(reason)}"
        )

        fail_message(message_id, inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Retrieves and validates user instructions.
  """
  def get_user_instructions(user_id) do
    instructions = Tasks.get_user_instructions(user_id)
    Logger.info("Retrieved #{length(instructions)} instructions for user #{user_id}")
    {:ok, instructions}
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

  ## OpenAI API interaction

  @doc """
  Calls OpenAI API with tool support.
  """
  def call_openai_with_tools(system_prompt, messages) do
    tools = Tools.list_tools()
    api_messages = prepare_open_ai_messages(system_prompt, messages)

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
         {:ok, _} <- process_tool_responses(message_id, tool_calls, tool_responses) do
      continue_conversation_with_tools(user_id, conversation_id, message_id, tool_responses)
    else
      error -> error
    end
  end

  def handle_openai_response(_user_id, _conversation_id, message_id, response) do
    Logger.info("Processing OpenAI response with content only")
    finalize_conversation(message_id, response)
  end

  @doc """
  Continues conversation after tool execution.
  """
  def continue_conversation_with_tools(_user_id, conversation_id, message_id, _tool_responses) do
    Logger.info("Continuing conversation with tool results")

    with {:ok, messages} <- get_conversation_context(conversation_id),
         {:ok, response} <- call_openai_with_tools("", messages) do
      finalize_conversation(message_id, response)
    else
      error -> error
    end
  end

  @doc """
  Prepares messages for OpenAI API format.
  """
  def prepare_open_ai_messages(system_prompt, messages) do
    system_message = %{role: "system", content: system_prompt}

    message_list =
      messages
      |> Enum.map(&build_open_ai_messages_by_role/1)
      |> List.flatten()

    {:ok, [system_message | message_list]}
  end

  defp build_open_ai_messages_by_role(%Message{} = msg) do
    base_message = %{role: msg.role, content: to_string(msg.content || "")}

    # Create assistant message with tool calls if present
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
      [base_message]
    end
  end

  ## Tool execution and response handling

  @doc """
  Executes tool calls and handles errors gracefully.
  """
  def execute_tool_calls(user_id, tool_calls) do
    try do
      Logger.info("Executing #{length(tool_calls)} tool calls for user #{user_id}")

      tool_responses =
        user_id
        |> Tools.execute_tool_calls(tool_calls)
        |> validate_tool_responses(tool_calls)

      Logger.info("Tool execution completed with #{length(tool_responses)} responses")
      {:ok, tool_responses}
    rescue
      e ->
        Logger.error("Tool execution failed for user #{user_id}: #{inspect(e)}")
        {:error, {:tool_execution_failed, e}}
    end
  end

  defp validate_tool_responses(tool_responses, tool_calls) do
    tool_call_ids = Enum.map(tool_calls, & &1["id"])
    response_ids = Enum.map(tool_responses, & &1.tool_call_id)
    missing_ids = tool_call_ids -- response_ids

    missing_responses =
      if length(missing_ids) > 0 do
        Logger.error("Missing responses for tool call IDs: #{inspect(missing_ids)}")
        Enum.map(missing_ids, &new_missing_tool_response/1)
      else
        []
      end

    Enum.concat(tool_responses, missing_responses)
  end

  defp new_missing_tool_response(tool_call_id) do
    %{
      tool_call_id: tool_call_id,
      content: %{error: "No response generated"}
    }
  end

  ## Message handling and state management

  @doc """
  Finalizes the conversation with the final response.
  """
  def finalize_conversation(message_id, %{"content" => content}) do
    Logger.info("Finalizing conversation for message #{message_id} with content: #{content}")
    update_message_state(message_id, "completed", %{content: content})
  end

  defp fail_message(message_id, reason) do
    Logger.error("Failing message #{message_id} due to: #{inspect(reason)}")
    update_message_state(message_id, "failed", %{error_message: reason})
  end

  defp process_tool_responses(message_id, tool_calls, tool_responses) do
    Logger.info("Processing tool responses for message #{message_id}")

    update_message_state(message_id, "processing", %{
      content: "Processing model responses...",
      tool_calls: tool_calls,
      tool_responses: tool_responses
    })
  end

  defp update_message_state(message_id, state, attrs \\ %{}) do
    default_state_change_attrs = %{state: state, updated_at: DateTime.utc_now()}
    attrs = Map.merge(attrs, default_state_change_attrs)

    Message
    |> Repo.get!(message_id)
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Builds system prompt with ongoing instructions.
  """
  def build_system_prompt(instructions) do
    prompt_description = """
    You are a financial advisor AI assistant. You can search for information and perform actions on behalf of your users.

    Be helpful, professional, and proactive. When scheduling meetings, always check availability first.
    When creating contacts, gather all relevant information from previous interactions.

    Follow the ongoing instructions provided by the user to maintain context and continuity.
    """

    system_prompt = Agent.system_prompt(instructions, prompt_description)
    {:ok, system_prompt}
  end
end
