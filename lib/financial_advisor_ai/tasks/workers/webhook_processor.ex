defmodule FinancialAdvisorAi.Tasks.WebhookProcessor do
  use Oban.Worker, queue: :default

  alias FinancialAdvisorAi.{Tasks, Chat}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "source" => source, "data" => data}}) do
    # Get user's ongoing instructions
    instructions =
      Tasks.get_user_instructions(user_id)
      |> Enum.filter(fn inst ->
        inst.trigger_type == source or inst.trigger_type == "any"
      end)

    if Enum.any?(instructions) do
      # Build context about the event
      context = build_event_context(source, data)

      # Ask the agent if it should take any action
      prompt = """
      An event occurred: #{context}

      Based on the user's ongoing instructions, should any action be taken?
      If yes, describe what actions should be taken.
      """

      # Process through agent (simplified - would integrate with Chat.Agent)
      # This would trigger tool calls as needed
      Chat.Agent.process_system_event(user_id, prompt, instructions)
    end

    :ok
  end

  defp build_event_context("gmail", data) do
    "New email received from #{data["from"]} with subject: #{data["subject"]}"
  end

  defp build_event_context("calendar", data) do
    "Calendar event: #{data["summary"]} at #{data["start"]}"
  end

  defp build_event_context("hubspot", data) do
    "HubSpot event: #{data["type"]} for #{data["object_type"]}"
  end
end
