defmodule FinancialAdvisorAi.Tasks.DeferredTaskWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias FinancialAdvisorAi.{Tasks, Tools, Repo}
  alias FinancialAdvisorAi.Tasks.Task

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    Logger.info("Processing deferred task ID: #{task_id}")

    case Repo.get(Task, task_id) do
      nil ->
        Logger.error("Task #{task_id} not found")
        {:error, :task_not_found}

      task ->
        process_task(task)
    end
  end

  defp process_task(%Task{status: "completed"} = task) do
    Logger.info("Task #{task.id} already completed, skipping")
    :ok
  end

  defp process_task(%Task{status: "failed"} = task) do
    Logger.info("Task #{task.id} previously failed, skipping")
    :ok
  end

  defp process_task(%Task{execute_at: execute_at} = task) when not is_nil(execute_at) do
    now = DateTime.utc_now()

    if DateTime.compare(execute_at, now) == :gt do
      Logger.info("Task #{task.id} scheduled for future execution at #{execute_at}, rescheduling")
      reschedule_task(task)
    else
      execute_task(task)
    end
  end

  defp process_task(%Task{} = task) do
    execute_task(task)
  end

  defp execute_task(task) do
    Logger.info("Executing task #{task.id} of type '#{task.type}' for user #{task.user_id}")

    # Update task status to processing
    {:ok, updated_task} = update_task_status(task, "processing")

    try do
      result =
        case task.type do
          "email" ->
            execute_email_task(task)

          "calendar_event" ->
            execute_calendar_task(task)

          "hubspot_contact" ->
            execute_hubspot_contact_task(task)

          "hubspot_note" ->
            execute_hubspot_note_task(task)

          "search_knowledge_base" ->
            execute_search_task(task)

          "sync_gmail" ->
            execute_sync_task(task, "gmail")

          "sync_hubspot" ->
            execute_sync_task(task, "hubspot")

          "custom" ->
            execute_custom_task(task)

          _ ->
            {:error, "Unknown task type: #{task.type}"}
        end

      case result do
        {:ok, task_result} ->
          Logger.info("Task #{task.id} completed successfully")
          update_task_completion(updated_task, task_result)
          :ok

        {:error, reason} ->
          Logger.error("Task #{task.id} failed: #{inspect(reason)}")
          update_task_failure(updated_task, reason)
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Task #{task.id} raised exception: #{inspect(e)}")
        update_task_failure(updated_task, inspect(e))
        {:error, e}
    end
  end

  # Task execution functions

  defp execute_email_task(%Task{data: data, user_id: user_id}) do
    Tools.SendEmail.call(
      user_id,
      data["to"],
      data["subject"],
      data["body"]
    )
  end

  defp execute_calendar_task(%Task{data: data, user_id: user_id}) do
    Tools.CreateCalendarEvent.call(
      user_id,
      data["title"],
      data["start_time"],
      data["end_time"],
      data["attendees"] || []
    )
  end

  defp execute_hubspot_contact_task(%Task{data: data, user_id: user_id}) do
    Tools.CreateHubspotContact.call(
      user_id,
      data["email"],
      data["firstname"],
      data["lastname"],
      data["phone"]
    )
  end

  defp execute_hubspot_note_task(%Task{data: data, user_id: user_id}) do
    Tools.AddHubspotNote.call(
      user_id,
      data["contact_id"],
      data["note"]
    )
  end

  defp execute_search_task(%Task{data: data, user_id: user_id}) do
    Tools.SearchKnowledgeBase.call(
      user_id,
      data["query"]
    )
  end

  defp execute_sync_task(%Task{user_id: user_id}, sync_type) do
    %{user_id: user_id, type: sync_type}
    |> Tasks.SyncWorker.new()
    |> Oban.insert()
  end

  defp execute_custom_task(%Task{data: data}) do
    # For custom tasks, execute the action specified in the data
    case data["action"] do
      "webhook_processing" ->
        # Process webhook data
        {:ok, %{processed: true, webhook_data: data["webhook_data"]}}

      "data_migration" ->
        # Handle data migration tasks
        {:ok, %{migrated: true, records: data["record_count"] || 0}}

      "cleanup" ->
        # Handle cleanup tasks
        {:ok, %{cleaned: true, items: data["cleanup_items"] || []}}

      _ ->
        Logger.warning("Unknown custom action: #{data["action"]}")
        {:ok, %{message: "Custom task processed", action: data["action"]}}
    end
  end

  # Task management helpers

  defp reschedule_task(%Task{} = task) do
    scheduled_at = task.execute_at

    %{task_id: task.id}
    |> __MODULE__.new(scheduled_at: scheduled_at)
    |> Oban.insert()

    Logger.info("Task #{task.id} rescheduled for #{scheduled_at}")
    :ok
  end

  defp update_task_status(%Task{} = task, status) do
    task
    |> Task.changeset(%{status: status})
    |> Repo.update()
  end

  defp update_task_completion(%Task{} = task, result) do
    task
    |> Task.changeset(%{
      status: "completed",
      result: result
    })
    |> Repo.update()
  end

  defp update_task_failure(%Task{} = task, reason) do
    task
    |> Task.changeset(%{
      status: "failed",
      result: %{error: inspect(reason), failed_at: DateTime.utc_now()}
    })
    |> Repo.update()
  end
end
