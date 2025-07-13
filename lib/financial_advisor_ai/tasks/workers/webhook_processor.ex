defmodule FinancialAdvisorAi.Tasks.WebhookProcessor do
  use Oban.Worker, queue: :default

  alias FinancialAdvisorAi.{Tasks, Chat}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "source" => source, "data" => data}}) do
    Logger.info("Processing webhook event for user #{user_id} from source #{source}")
    instructions = get_user_ongoing_instructions(user_id, source)

    if Enum.any?(instructions) do
      Chat.Agent.process_system_event(
        user_id,
        new_prompt(source, data),
        instructions
      )
    end

    :ok
  end

  ## Instructions

  defp get_user_ongoing_instructions(user_id, source, trigger \\ "any") do
    Logger.info(
      "Fetching ongoing instructions for user #{user_id} with source #{source} and trigger #{trigger}"
    )

    user_id
    |> Tasks.get_user_instructions()
    |> Enum.filter(fn inst ->
      inst.trigger_type == source or inst.trigger_type == trigger
    end)
  end

  ## Prompt

  defp new_prompt(source, data) do
    """
    An event occurred: #{build_event_context(source, data)}

    Based on the user's ongoing instructions, should any action be taken?
    If yes, describe what actions should be taken.
    """
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
