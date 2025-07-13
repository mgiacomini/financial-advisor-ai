defmodule FinancialAdvisorAi.Tools do
  alias FinancialAdvisorAi.{Tasks, Tools}

  require Logger

  @doc """
  Returns the list of all available tools for OpenAI API.
  """
  def list_tools do
    [
      Tools.SearchKnowledgeBase.open_api_spec(),
      Tools.SendEmail.open_api_spec(),
      Tools.CreateCalendarEvent.open_api_spec(),
      Tools.SearchHubspotContacts.open_api_spec(),
      Tools.CreateHubspotContact.open_api_spec(),
      Tools.AddHubspotNote.open_api_spec(),
      Tools.CheckCalendarAvailability.open_api_spec(),
      Tools.CreateTask.open_api_spec()
    ]
  end

  @doc """
  Executes multiple tool calls for a user.
  """
  def execute_tool_calls(user_id, tool_calls) do
    Logger.info("Executing tool calls for user #{user_id}")

    Enum.map(tool_calls, fn tool_call ->
      execute_tool_call(user_id, tool_call)
    end)
  end

  @doc """
  Executes a single tool call for a user.
  """
  def execute_tool_call(user_id, %{"function" => %{"name" => name, "arguments" => args}}) do
    Logger.info(
      "Executing #{inspect(name)} tool call for user #{user_id} with args: #{inspect(args)}"
    )

    args = Jason.decode!(args)

    tool_call_response =
      case name do
        "search_knowledge_base" ->
          Tools.SearchKnowledgeBase.call(user_id, args["query"])

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
          search_hubspot_contacts(user_id, args["query"])

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
          Logger.info("Creating task for user #{user_id} with details: #{inspect(args)}")
          Tools.CreateTask.call(user_id, args)

        _ ->
          Logger.error("Unknown tool call: #{name} for user #{user_id}")
          {:error, "Unknown tool: #{name}"}
      end

    case tool_call_response do
      {:ok, result} ->
        result

      {:error, reason} ->
        Logger.error("Tool call #{name} failed for user #{user_id}: #{inspect(reason)}")
        %{error: "Tool call failed"}
    end
  end

  # This function is kept here since it's not in the individual tool modules yet
  defp search_hubspot_contacts(user_id, query) do
    Logger.info("Searching HubSpot contacts for user #{user_id} with query: #{query}")
    Tasks.search_hubspot_contacts(user_id, query)
  end
end
