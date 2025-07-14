defmodule FinancialAdvisorAi.Tasks do
  import Ecto.Query, warn: false

  alias FinancialAdvisorAi.Repo
  alias FinancialAdvisorAi.Tasks.{OngoingInstruction, Task}
  alias FinancialAdvisorAi.Integrations

  require Logger

  @doc """
  Gets all active ongoing instructions for a user.

  ## Parameters
    - user_id: The ID of the user

  ## Returns
    - A list of OngoingInstruction structs
  """
  def get_user_instructions(user_id) do
    Logger.info("Getting user instructions for user #{user_id}")

    OngoingInstruction
    |> where([i], i.user_id == ^user_id and i.active == true)
    |> Repo.all()
  end

  @doc """
  Searches HubSpot contacts for a user.

  ## Parameters
    - user_id: The ID of the user
    - query: The search query string

  ## Returns
    - {:ok, results} on success
    - {:error, reason} on failure
  """
  @spec search_hubspot_contacts(integer(), String.t()) :: {:ok, list()} | {:error, any()}
  def search_hubspot_contacts(user_id, query) do
    Logger.info("Searching HubSpot contacts for user #{user_id} with query: #{query}")
    api_key = Integrations.get_hubspot_api_key(user_id)

    case Integrations.HubSpotClient.search_contacts(api_key, query) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        Logger.info("Found #{length(results)} contacts for query '#{query}'")
        {:ok, results}

      {:ok, %{body: body} = response} ->
        Logger.error("Failed to search HubSpot contacts: #{inspect(body)}")
        {:error, response}

      {:error, reason} ->
        Logger.error("Failed to search HubSpot contacts: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Checks calendar availability for a user within a date range.

  ## Parameters
    - user_id: The ID of the user
    - start_date: The start date/time (ISO 8601 string)
    - end_date: The end date/time (ISO 8601 string)

  ## Returns
    - {:ok, availability_data} on success
    - {:error, reason} on failure
  """
  def check_calendar_availability(user_id, start_date, end_date) do
    Logger.info(
      "Checking calendar availability for user #{user_id} from #{start_date} to #{end_date}"
    )

    # Assuming we check the primary calendar for simplicity
    calendars = ["primary"]

    case Integrations.get_google_oauth_token(user_id) do
      %{access_token: token} ->
        Integrations.GoogleClient.get_free_busy(
          token,
          start_date,
          end_date,
          calendars
        )

      nil ->
        {:error, "No valid Google token found for user"}
    end
  end

  @doc """
  Creates a deferred task for later execution.

  ## Parameters
    - user_id: The ID of the user
    - args: Map containing task data with keys:
      - "type": The type of task (required)
      - "data": The task data (required)
      - "execute_at": ISO 8601 datetime string for when to execute (optional)

  ## Returns
    - {:ok, task} on success
    - {:error, changeset} on validation failure
  """
  def create_deferred_task(user_id, args) do
    Logger.info("Creating deferred task for user #{user_id} with args: #{inspect(args)}")

    execute_at =
      case DateTime.from_iso8601(args["execute_at"] || "") do
        {:ok, datetime, _} -> datetime
        _ -> nil
      end

    task_attrs = %{
      type: args["type"],
      data: args["data"],
      user_id: user_id,
      execute_at: execute_at,
      status: "pending"
    }

    %Task{}
    |> Task.changeset(task_attrs)
    |> Repo.insert()
  end
end
