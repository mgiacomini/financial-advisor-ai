defmodule FinancialAdvisorAi.Tasks do
  import Ecto.Query, warn: false
  alias FinancialAdvisorAi.Repo
  alias FinancialAdvisorAi.Tasks.{OngoingInstruction, Task}
  alias FinancialAdvisorAi.{Accounts, Integrations}

  @doc """
  Gets all active ongoing instructions for a user.

  ## Parameters
    - user_id: The ID of the user
    
  ## Returns
    - A list of OngoingInstruction structs
  """
  def get_user_instructions(user_id) do
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
  def search_hubspot_contacts(user_id, query) do
    case Accounts.get_valid_oauth_token!(user_id, "hubspot") do
      %{access_token: token} ->
        Integrations.HubSpotClient.search_contacts(token, query)

      nil ->
        {:error, "No valid HubSpot token found for user"}
    end
  rescue
    e ->
      {:error, "Failed to search HubSpot contacts: #{Exception.message(e)}"}
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
    case Accounts.get_valid_oauth_token!(user_id, "google") do
      %{access_token: token} ->
        calendars = ["primary"]
        Integrations.GoogleClient.get_free_busy(token, start_date, end_date, calendars)

      nil ->
        {:error, "No valid Google token found for user"}
    end
  rescue
    e ->
      {:error, "Failed to check calendar availability: #{Exception.message(e)}"}
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
    execute_at =
      case args["execute_at"] do
        nil ->
          nil

        datetime_string ->
          case DateTime.from_iso8601(datetime_string) do
            {:ok, datetime, _} -> datetime
            _ -> nil
          end
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
