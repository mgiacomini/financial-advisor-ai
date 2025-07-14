defmodule FinancialAdvisorAi.Tools do
  alias FinancialAdvisorAi.{Tasks, Tools}

  require Logger

  @doc """
  Returns the list of all available tools for OpenAI API.
  """
  def list_tools do
    [
      Tools.SearchKnowledgeBase.open_ai_spec(),
      Tools.SendEmail.open_ai_spec(),
      Tools.CreateCalendarEvent.open_ai_spec(),
      Tools.SearchHubspotContacts.open_ai_spec(),
      Tools.CreateHubspotContact.open_ai_spec(),
      Tools.AddHubspotNote.open_ai_spec(),
      Tools.CheckCalendarAvailability.open_ai_spec(),
      Tools.CreateTask.open_ai_spec()
    ]
  end

  @doc """
  Executes multiple tool calls for a user.
  """
  def execute_tool_calls(user_id, tool_calls) do
    Logger.info("Executing #{length(tool_calls)} tool calls for user #{user_id}")

    responses =
      tool_calls
      |> Enum.map(fn tool_call ->
        case execute_tool_call(user_id, tool_call) do
          response when is_map(response) ->
            response

          other ->
            Logger.error(
              "Invalid tool call response: #{inspect(other)} for tool_call: #{inspect(tool_call)}"
            )

            %{
              tool_call_id: tool_call["id"] || "unknown",
              content: %{error: "Invalid tool response"}
            }
        end
      end)

    Logger.info("Generated #{length(responses)} tool responses")
    responses
  end

  @doc """
  Executes a single tool call for a user.
  """
  def execute_tool_call(user_id, %{
        "id" => tool_call_id,
        "function" => %{"name" => name, "arguments" => args}
      }) do
    Logger.info(
      "Executing #{name} tool call #{tool_call_id} for user #{user_id} with args: #{inspect(args)}"
    )

    try do
      args = Jason.decode!(args)

      tool_call_response =
        case name do
          "search_knowledge_base" ->
            Tools.SearchKnowledgeBase.call(
              user_id,
              args["query"]
            )

          "send_email" ->
            Tools.SendEmail.call(
              user_id,
              args["to"],
              args["subject"],
              args["body"]
            )

          "create_calendar_event" ->
            Tools.CreateCalendarEvent.call(
              user_id,
              args["title"],
              args["start_time"],
              args["end_time"],
              args["attendees"] || []
            )

          "search_hubspot_contacts" ->
            Tasks.search_hubspot_contacts(
              user_id,
              args["query"]
            )

          "create_hubspot_contact" ->
            Tools.CreateHubspotContact.call(
              user_id,
              args["email"],
              args["firstname"],
              args["lastname"],
              args["phone"]
            )

          "add_hubspot_note" ->
            Tools.AddHubspotNote.call(
              user_id,
              args["contact_id"],
              args["note"]
            )

          "check_calendar_availability" ->
            Tools.CheckCalendarAvailability.call(
              user_id,
              args["start_date"],
              args["end_date"]
            )

          "create_task" ->
            Tools.CreateTask.call(
              user_id,
              args
            )

          _ ->
            Logger.error("Unknown tool call: #{name} for user #{user_id}")
            {:error, "Unknown tool: #{name}"}
        end

      case tool_call_response do
        {:ok, result} ->
          %{
            tool_call_id: tool_call_id,
            content: result
          }

        {:error, reason} ->
          Logger.error("Tool call #{name} failed for user #{user_id}: #{inspect(reason)}")

          %{
            tool_call_id: tool_call_id,
            content: %{error: "Tool call failed: #{inspect(reason)}"}
          }
      end
    rescue
      e ->
        Logger.error(
          "Exception in tool call #{name} (#{tool_call_id}) for user #{user_id}: #{inspect(e)}"
        )

        %{
          tool_call_id: tool_call_id,
          content: %{error: "Tool execution exception: #{inspect(e)}"}
        }
    end
  end

  # Fallback for malformed tool calls
  def execute_tool_call(user_id, tool_call) do
    Logger.error("Malformed tool call for user #{user_id}: #{inspect(tool_call)}")
    tool_call_id = tool_call["id"] || "unknown_#{:rand.uniform(1000)}"

    %{
      tool_call_id: tool_call_id,
      content: %{error: "Malformed tool call"}
    }
  end
end
