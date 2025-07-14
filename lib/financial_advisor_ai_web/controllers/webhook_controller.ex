defmodule FinancialAdvisorAiWeb.WebhookController do
  use FinancialAdvisorAiWeb, :controller

  alias FinancialAdvisorAi.Tasks.WebhookProcessor
  alias FinancialAdvisorAi.{Accounts, Repo}
  alias FinancialAdvisorAi.Accounts.{User, OAuthToken}

  import Ecto.Query
  require Logger

  def handle(conn, %{"provider" => provider} = params) do
    Logger.info("Received webhook from provider: #{provider}")

    case process_webhook(provider, params) do
      {:ok, result} ->
        Logger.info("Webhook processed successfully for provider: #{provider}")

        conn
        |> put_status(:ok)
        |> json(%{status: "success", result: result})

      {:error, reason} ->
        Logger.error("Webhook processing failed for provider #{provider}: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: reason})
    end
  end

  def handle(conn, params) do
    Logger.warning("Webhook received without provider parameter: #{inspect(params)}")

    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", message: "Provider parameter is required"})
  end

  defp process_webhook(provider, params) do
    case provider do
      "gmail" ->
        handle_gmail_webhook(params)

      "calendar" ->
        handle_calendar_webhook(params)

      "hubspot" ->
        handle_hubspot_webhook(params)

      _ ->
        {:error, "Unsupported webhook provider: #{provider}"}
    end
  end

  defp handle_gmail_webhook(%{"message" => %{"data" => data}} = params) do
    Logger.info("Processing Gmail webhook")

    # Decode the base64 encoded pub/sub message
    case Base.decode64(data) do
      {:ok, decoded_data} ->
        case Jason.decode(decoded_data) do
          {:ok, gmail_data} ->
            # Extract user_id from the topic or resource if available
            user_id = extract_user_id_from_gmail_data(gmail_data, params)

            if user_id do
              # Queue the webhook processor job
              %{user_id: user_id, source: "gmail", data: gmail_data}
              |> WebhookProcessor.new()
              |> Oban.insert()

              {:ok, %{message: "Gmail webhook queued for processing"}}
            else
              {:error, "Unable to extract user_id from Gmail webhook"}
            end

          {:error, _} ->
            {:error, "Invalid JSON in Gmail webhook data"}
        end

      :error ->
        {:error, "Invalid base64 encoding in Gmail webhook"}
    end
  end

  defp handle_gmail_webhook(params) do
    Logger.warning("Gmail webhook missing expected structure: #{inspect(params)}")
    {:error, "Invalid Gmail webhook format"}
  end

  defp handle_calendar_webhook(
         %{"resourceId" => resource_id, "resourceUri" => resource_uri} = params
       ) do
    Logger.info("Processing Google Calendar webhook for resource: #{resource_id}")

    # Extract user_id from resource or headers
    user_id = extract_user_id_from_calendar_data(params)

    if user_id do
      calendar_data = %{
        resource_id: resource_id,
        resource_uri: resource_uri,
        event_type: params["eventType"] || "updated"
      }

      # Queue the webhook processor job
      %{user_id: user_id, source: "calendar", data: calendar_data}
      |> WebhookProcessor.new()
      |> Oban.insert()

      {:ok, %{message: "Calendar webhook queued for processing"}}
    else
      {:error, "Unable to extract user_id from Calendar webhook"}
    end
  end

  defp handle_calendar_webhook(params) do
    Logger.warning("Calendar webhook missing expected structure: #{inspect(params)}")
    {:error, "Invalid Calendar webhook format"}
  end

  defp handle_hubspot_webhook(params) do
    Logger.info("Processing HubSpot webhook")

    # HubSpot sends an array of subscription events
    events = params["subscriptionEvents"] || []

    if Enum.any?(events) do
      # Process each event
      results =
        Enum.map(events, fn event ->
          user_id = extract_user_id_from_hubspot_event(event, params)

          if user_id do
            hubspot_data = %{
              object_id: event["objectId"],
              subscription_id: event["subscriptionId"],
              portal_id: event["portalId"],
              event_id: event["eventId"],
              subscription_type: event["subscriptionType"],
              attempt_number: event["attemptNumber"],
              object_type: event["subscriptionType"],
              type: "webhook_event"
            }

            # Queue the webhook processor job
            %{user_id: user_id, source: "hubspot", data: hubspot_data}
            |> WebhookProcessor.new()
            |> Oban.insert()

            {:ok, "Event #{event["eventId"]} queued"}
          else
            {:error, "Unable to extract user_id for event #{event["eventId"]}"}
          end
        end)

      {:ok, %{message: "HubSpot webhook events processed", results: results}}
    else
      {:error, "No subscription events found in HubSpot webhook"}
    end
  end

  # Helper functions to extract user_id from webhook data

  defp extract_user_id_from_gmail_data(gmail_data, params) do
    # Strategy 1: Check if user email is in the webhook topic or attributes
    cond do
      # Check if topic contains user identifier
      topic = get_in(params, ["message", "attributes", "topic"]) ->
        extract_user_from_topic(topic)

      # Check if email address is in the message attributes
      email = get_in(params, ["message", "attributes", "emailAddress"]) ->
        get_user_id_by_email(email)

      # Check if histogram_id contains user info (Gmail specific)
      _histogram_id = get_in(gmail_data, ["historyId"]) ->
        # For now, we'll need to get all Google OAuth users and try to match
        # In production, you'd store the histogram_id or email mapping
        get_user_id_by_google_token_heuristic()

      true ->
        Logger.warning("Unable to extract user from Gmail webhook data")
        nil
    end
  end

  defp extract_user_id_from_calendar_data(params) do
    cond do
      # Check X-Goog-Channel-Token header (custom token you set when creating the watch)
      token = get_in(params, ["headers", "x-goog-channel-token"]) ->
        # Parse user_id from custom token format like "user_id:123"
        case String.split(token, ":") do
          ["user_id", user_id] when user_id != "" ->
            case Integer.parse(user_id) do
              {id, ""} -> id
              _ -> nil
            end

          _ ->
            nil
        end

      # Check if resource URI contains calendar ID we can map to user
      resource_uri = params["resourceUri"] ->
        extract_user_from_calendar_resource(resource_uri)

      # Fallback: try to match by existing Google OAuth tokens
      true ->
        get_user_id_by_google_token_heuristic()
    end
  end

  defp extract_user_id_from_hubspot_event(event, _params) do
    portal_id = event["portalId"]

    if portal_id do
      # Strategy 1: Look up user by portal ID in OAuth tokens or user metadata
      # Since HubSpot uses API keys per user, we can look for the portal in the token scopes
      case get_user_by_hubspot_portal(portal_id) do
        nil ->
          # Strategy 2: If we only have one HubSpot user, use that
          get_single_hubspot_user()

        user_id ->
          user_id
      end
    else
      Logger.warning("No portal ID found in HubSpot webhook event")
      nil
    end
  end

  # Helper functions for user lookup

  defp extract_user_from_topic(topic) do
    # Parse topic like "projects/myproject/topics/gmail-user-123"
    case Regex.run(~r/gmail-user-(\d+)$/, topic) do
      [_, user_id] ->
        case Integer.parse(user_id) do
          {id, ""} -> id
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp get_user_id_by_email(email) do
    case Accounts.get_user_by_email(email) do
      %User{id: user_id} -> user_id
      nil -> nil
    end
  end

  defp get_user_id_by_google_token_heuristic do
    # Get all users with Google OAuth tokens
    google_users =
      from(t in OAuthToken,
        where: t.provider == "google",
        select: t.user_id,
        distinct: true
      )
      |> Repo.all()

    case google_users do
      [single_user_id] ->
        Logger.info("Found single Google OAuth user: #{single_user_id}")
        single_user_id

      [] ->
        Logger.warning("No Google OAuth users found")
        nil

      multiple ->
        Logger.warning(
          "Multiple Google OAuth users found: #{inspect(multiple)}. Cannot determine which user."
        )

        # In production, you'd need better identification strategy
        nil
    end
  end

  defp extract_user_from_calendar_resource(resource_uri) do
    # Parse calendar ID from resource URI and look up user
    # Resource URI format: https://www.googleapis.com/calendar/v3/calendars/primary/events
    case Regex.run(~r|/calendars/([^/]+)/events|, resource_uri) do
      [_, calendar_id] when calendar_id != "primary" ->
        # If it's not "primary", try to match calendar_id to a user
        # This would require storing calendar IDs in your user data
        get_user_by_calendar_id(calendar_id)

      _ ->
        # For "primary" calendars, use heuristic approach
        get_user_id_by_google_token_heuristic()
    end
  end

  defp get_user_by_calendar_id(_calendar_id) do
    # TODO: Implement calendar ID to user mapping
    # This would require storing calendar IDs when setting up watches
    nil
  end

  defp get_user_by_hubspot_portal(portal_id) do
    # Look for HubSpot tokens that might contain portal info in scopes or metadata
    # Since the current implementation uses env vars, we'll use a heuristic approach
    hubspot_users =
      from(t in OAuthToken,
        where: t.provider == "hubspot",
        select: t.user_id,
        distinct: true
      )
      |> Repo.all()

    case hubspot_users do
      [single_user_id] ->
        Logger.info("Found single HubSpot user: #{single_user_id} for portal: #{portal_id}")
        single_user_id

      [] ->
        Logger.warning("No HubSpot OAuth users found for portal: #{portal_id}")
        nil

      multiple ->
        Logger.warning(
          "Multiple HubSpot users found for portal #{portal_id}: #{inspect(multiple)}"
        )

        # In production, you'd store portal_id mapping
        List.first(multiple)
    end
  end

  defp get_single_hubspot_user do
    case from(t in OAuthToken,
           where: t.provider == "hubspot",
           select: t.user_id,
           distinct: true,
           limit: 1
         )
         |> Repo.one() do
      nil ->
        Logger.warning("No HubSpot OAuth users found")
        nil

      user_id ->
        Logger.info("Using single HubSpot user: #{user_id}")
        user_id
    end
  end
end
