defmodule FinancialAdvisorAi.Integrations do
  @moduledoc """
  This module serves as a namespace for all integrations with external services.
  It includes clients for OpenAI, HubSpot, and other integrations.
  """

  def get_hubspot_api_key(_user_id \\ nil) do
    # Replace this, by a database lookup or configuration management in production
    # For now, we use an environment variable for simplicity
    case System.get_env("HUBSPOT_API_KEY") do
      nil -> raise "HUBSPOT_API_KEY environment variable is not set"
      "" -> raise "HUBSPOT_API_KEY environment variable is empty"
      "placeholder_for_deps_get" -> raise "HUBSPOT_API_KEY is still using placeholder value"
      key -> key
    end
  end

  def get_openai_api_key do
    case System.get_env("OPENAI_API_KEY") do
      nil -> raise "OPENAI_API_KEY environment variable is not set"
      "" -> raise "OPENAI_API_KEY environment variable is empty"
      "placeholder_for_deps_get" -> raise "OPENAI_API_KEY is still using placeholder value"
      key -> key
    end
  end

  def get_google_oauth_token(user_id) do
    FinancialAdvisorAi.Accounts.get_valid_oauth_token!(user_id, "google")
  end
end
