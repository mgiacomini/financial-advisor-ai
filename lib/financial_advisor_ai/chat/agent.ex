defmodule FinancialAdvisorAi.Chat.Agent do
  alias FinancialAdvisorAi.{RAG, Tasks, Integrations}
  alias FinancialAdvisorAi.Chat.Message
  alias FinancialAdvisorAi.Repo

  import Ecto.Query

  @tools [
    %{
      type: "function",
      function: %{
        name: "search_knowledge_base",
        description: "Search through emails and HubSpot data",
        parameters: %{
          type: "object",
          properties: %{
            query: %{type: "string", description: "Search query"}
          },
          required: ["query"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "send_email",
        description: "Send an email",
        parameters: %{
          type: "object",
          properties: %{
            to: %{type: "string", description: "Recipient email"},
            subject: %{type: "string"},
            body: %{type: "string"}
          },
          required: ["to", "subject", "body"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "create_calendar_event",
        description: "Create a calendar event",
        parameters: %{
          type: "object",
          properties: %{
            title: %{type: "string"},
            start_time: %{type: "string", description: "ISO 8601 datetime"},
            end_time: %{type: "string", description: "ISO 8601 datetime"},
            attendees: %{type: "array", items: %{type: "string"}}
          },
          required: ["title", "start_time", "end_time"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "search_hubspot_contacts",
        description: "Search HubSpot contacts",
        parameters: %{
          type: "object",
          properties: %{
            query: %{type: "string"}
          },
          required: ["query"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "create_hubspot_contact",
        description: "Create a HubSpot contact",
        parameters: %{
          type: "object",
          properties: %{
            email: %{type: "string"},
            firstname: %{type: "string"},
            lastname: %{type: "string"},
            phone: %{type: "string"}
          },
          required: ["email"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "add_hubspot_note",
        description: "Add a note to a HubSpot contact",
        parameters: %{
          type: "object",
          properties: %{
            contact_id: %{type: "string"},
            note: %{type: "string"}
          },
          required: ["contact_id", "note"]
        }
      }
    },
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
    },
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
  ]

  def process_message(user_id, conversation_id, user_message) do
    # Save user message
    {:ok, _} = create_message(conversation_id, "user", user_message)

    # Get conversation history
    messages = get_conversation_messages(conversation_id)

    # Check for ongoing instructions that might apply
    instructions = Tasks.get_user_instructions(user_id)

    # Build system prompt
    system_prompt = build_system_prompt(instructions)

    # Prepare messages for API
    api_messages = prepare_api_messages(system_prompt, messages)

    # Call OpenAI
    case Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      {:ok, %{body: %{"choices" => [%{"message" => assistant_message}]}}} ->
        handle_assistant_response(user_id, conversation_id, assistant_message)

      {:error, error} ->
        {:error, error}
    end
  end

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
    # Build system prompt with instructions
    system_prompt = build_system_prompt(instructions)

    # Create messages for the event
    api_messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: prompt}
    ]

    # Call OpenAI to determine if action should be taken
    case Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      {:ok, %{body: %{"choices" => [%{"message" => assistant_message}]}}} ->
        # Execute any tool calls without saving to conversation
        case assistant_message do
          %{"tool_calls" => tool_calls} when not is_nil(tool_calls) ->
            Enum.each(tool_calls, fn tool_call ->
              execute_tool_call(user_id, tool_call)
            end)

          _ ->
            # No tool calls needed
            :ok
        end

        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_assistant_response(user_id, conversation_id, %{
         "content" => content,
         "tool_calls" => tool_calls
       })
       when not is_nil(tool_calls) do
    # Execute tool calls
    tool_responses =
      Enum.map(tool_calls, fn tool_call ->
        execute_tool_call(user_id, tool_call)
      end)

    # Save assistant message with tool calls
    {:ok, _} =
      create_message(
        conversation_id,
        "assistant",
        content || "",
        tool_calls: tool_calls,
        tool_responses: tool_responses
      )

    # Continue conversation with tool results
    continue_with_tool_results(user_id, conversation_id, tool_responses)
  end

  defp handle_assistant_response(_user_id, conversation_id, %{"content" => content}) do
    # Save and return regular message
    create_message(conversation_id, "assistant", content)
  end

  defp execute_tool_call(user_id, %{"function" => %{"name" => name, "arguments" => args}}) do
    args = Jason.decode!(args)

    case name do
      "search_knowledge_base" ->
        RAG.search(user_id, args["query"])

      "send_email" ->
        Tasks.EmailWorker.new(%{
          user_id: user_id,
          to: args["to"],
          subject: args["subject"],
          body: args["body"]
        })
        |> Oban.insert()

      "create_calendar_event" ->
        Tasks.CalendarWorker.new(%{
          user_id: user_id,
          action: "create_event",
          data: args
        })
        |> Oban.insert()

      "search_hubspot_contacts" ->
        Tasks.search_hubspot_contacts(user_id, args["query"])

      "create_hubspot_contact" ->
        Tasks.HubSpotWorker.new(%{
          user_id: user_id,
          action: "create_contact",
          data: args
        })
        |> Oban.insert()

      "add_hubspot_note" ->
        Tasks.HubSpotWorker.new(%{
          user_id: user_id,
          action: "add_note",
          data: args
        })
        |> Oban.insert()

      "check_calendar_availability" ->
        Tasks.check_calendar_availability(user_id, args["start_date"], args["end_date"])

      "create_task" ->
        Tasks.create_deferred_task(user_id, args)

      _ ->
        %{error: "Unknown tool: #{name}"}
    end
  end

  defp build_system_prompt(instructions) do
    base_prompt = """
    You are an AI assistant for a financial advisor. You have access to their emails,
    calendar, and HubSpot CRM. You can search for information and perform actions on their behalf.

    Be helpful, professional, and proactive. When scheduling meetings, always check availability first.
    When creating contacts, gather all relevant information from previous interactions.
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

  defp create_message(conversation_id, role, content, opts \\ []) do
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
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  defp prepare_api_messages(system_prompt, messages) do
    system_message = %{role: "system", content: system_prompt}

    message_list =
      Enum.map(messages, fn msg ->
        %{role: msg.role, content: msg.content}
      end)

    [system_message | message_list]
  end

  defp continue_with_tool_results(user_id, conversation_id, tool_responses) do
    # Format tool responses and continue conversation
    response_content = format_tool_responses(tool_responses)

    # Get updated conversation
    messages = get_conversation_messages(conversation_id)
    api_messages = prepare_api_messages("", messages)

    # Add tool response message
    api_messages = api_messages ++ [%{role: "function", content: response_content}]

    # Continue conversation
    case Integrations.OpenAIClient.chat_completion(api_messages, @tools) do
      {:ok, %{body: %{"choices" => [%{"message" => assistant_message}]}}} ->
        handle_assistant_response(user_id, conversation_id, assistant_message)

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_tool_responses(responses) do
    responses
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
  end
end
