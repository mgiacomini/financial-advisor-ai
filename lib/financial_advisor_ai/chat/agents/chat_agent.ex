defmodule FinancialAdvisorAi.Chat.Agents.ChatAgent do
  alias FinancialAdvisorAi.{Tasks, Tools, Integrations}
  alias FinancialAdvisorAi.Chat.{Agent, Message}
  alias FinancialAdvisorAi.Repo

  import Ecto.Query

  require Logger

  @tools Tools.list_tools()

  @doc """
  Processes a user message in a conversation.
  """
  def process_message(user_id, conversation_id, user_message) do
    Logger.info("Processing user message for user #{user_id} in conversation #{conversation_id}")

    # Save user message
    {:ok, _} = create_message(conversation_id, "user", user_message)
    Logger.info("Message created for user #{user_id} in conversation #{conversation_id}")

    # Get conversation history
    messages = get_conversation_messages(conversation_id)
    Logger.info("Retrieved #{length(messages)} messages for conversation #{conversation_id}")

    # Check for ongoing instructions that might apply
    instructions = Tasks.get_user_instructions(user_id)
    Logger.info("Found #{length(instructions)} ongoing instructions for user #{user_id}")

    # Build system prompt
    system_prompt = build_system_prompt(instructions)
    Logger.info("Built system prompt for user #{user_id}")

    # Prepare messages for API
    api_messages = prepare_api_messages(system_prompt, messages)
    Logger.info("Prepared API messages for user #{user_id}")

    # Call OpenAI
    case Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      {:ok, %{body: %{"choices" => [%{"message" => assistant_message}]}}} ->
        Logger.info("Received assistant response for user #{user_id}")
        handle_assistant_response(user_id, conversation_id, assistant_message)

      {:ok, %{body: %{"error" => error}}} ->
        Logger.error(
          "OpenAI API error for user #{user_id} - code = #{error["code"]}, message = #{error["message"]}"
        )

        {:error, error}

      {:error, error} ->
        Logger.error("Failed to get assistant response for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end

    # create_new_user_message(conversation_id, user_message)
    # get_conversation_history(conversation_id)
    # get_user_ongoing_instructions(user_id)
    # new_system_prompt(instructions)
    # new_assistant_messages()

    # Assistant.fetch_tool_calls(instructions, user_messages)
    # execute_tool_calls(user_id, tool_calls)
    # store_tool_calls_ressponses(tool_calls, user_id, conversation_id)
    # Assistant.process_tool_calls_responses(user_id, conversation_id, tool_calls_responses)
  end

  ## Handles the assistant's response after processing a message

  defp handle_assistant_response(user_id, conversation_id, %{
         "content" => content,
         "tool_calls" => tool_calls
       })
       when not is_nil(tool_calls) do
    Logger.info("Handling assistant response with tool calls for user #{user_id}")

    role = "assistant"
    tool_responses = Tools.execute_tool_calls(user_id, tool_calls)
    IO.inspect(tool_responses, label: "Tool responses")
    opts = [tool_calls: tool_calls, tool_responses: tool_responses]

    with {:ok, _} <- create_message(conversation_id, role, content, opts) do
      Logger.info("Assistant message saved with tool calls for user #{user_id}")

      # Continue conversation with tool results
      continue_with_tool_results(user_id, conversation_id, tool_responses)
    end
  end

  defp handle_assistant_response(_user_id, conversation_id, %{"content" => content}) do
    # Save and return regular message
    create_message(conversation_id, "assistant", content)
  end

  ## Conversation continuation
  ## Reply to the user message with tool results

  defp continue_with_tool_results(user_id, conversation_id, tool_responses) do
    # Format tool responses and continue conversation
    Logger.info("Continuing conversation with tool results for user #{user_id}")
    response_content = format_tool_responses(tool_responses)

    # Get updated conversation
    Logger.info(
      "Getting conversation messages for user #{user_id} in conversation #{conversation_id}"
    )

    messages = get_conversation_messages(conversation_id)
    api_messages = prepare_api_messages("", messages)

    # Add tool response message
    Logger.info(
      "Adding tool response message for user #{user_id} in conversation #{conversation_id}"
    )

    api_messages = api_messages ++ [%{role: "function", content: response_content}]

    # Continue conversation
    Logger.info("Continuing conversation with tool results for user #{user_id}")

    case Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      {:ok, %{body: %{"choices" => [%{"message" => assistant_message}]}}} ->
        Logger.info("Received chat completion response for user #{user_id}")
        handle_assistant_response(user_id, conversation_id, assistant_message)

      {:ok, %{body: %{"error" => error}}} ->
        Logger.error(
          "OpenAI API error while continuing conversation for user #{user_id}: #{inspect(error)}"
        )

        {:error, error}

      {:error, error} ->
        Logger.error("Failed to continue conversation for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  ## Helper functions

  defp build_system_prompt(instructions) do
    prompt_description = """
    You can search for information and perform actions on their behalf.

    Be helpful, professional, and proactive. When scheduling meetings, always check availability first.
    When creating contacts, gather all relevant information from previous interactions.
    """

    Agent.system_prompt(instructions, prompt_description)
  end

  defp prepare_api_messages(system_prompt, messages) do
    Logger.info("Preparing API messages for conversation")
    system_message = %{role: "system", content: system_prompt}

    message_list =
      Enum.map(messages, fn msg ->
        %{role: msg.role, content: msg.content}
      end)

    [system_message | message_list]
  end

  defp format_tool_responses(responses) do
    responses
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
  end

  ## Message creation and retrieval functions

  defp create_message(conversation_id, role, content, opts \\ []) do
    Logger.info("Creating message for conversation #{conversation_id} with role #{role}")

    %Message{}
    |> Message.changeset(%{
      conversation_id: conversation_id,
      role: role,
      content: content,
      tool_calls: opts[:tool_calls],
      tool_responses: opts[:tool_responses]
    })
    |> Repo.insert()
  end

  defp get_conversation_messages(conversation_id) do
    Logger.info("Retrieving messages for conversation #{conversation_id}")

    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end
end
