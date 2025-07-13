defmodule FinancialAdvisorAi.Integrations do
  @moduledoc """
  This module serves as a namespace for all integrations with external services.
  It includes clients for OpenAI, HubSpot, and other integrations.
  """

  def get_hubspot_api_key(_user_id \\ nil) do
    # Replace this, by a database lookup or configuration management in production
    # For now, we use an environment variable for simplicity
    # System.get_env("HUBSPOT_API_KEY") || raise "HUBSPOT_API_KEY environment variable is not set"
    System.get_env("HUBSPOT_API_KEY") || "pat-na1-f2f9ec91-4ffa-4c96-918e-f36664bc364b"
  end

  def get_openai_api_key do
    # System.get_env("OPENAI_API_KEY") || raise "OPENAI_API_KEY environment variable is not set"
    System.get_env("OPENAI_API_KEY") ||
      "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"
  end

  def get_google_oauth_token(user_id) do
    FinancialAdvisorAi.Accounts.get_valid_oauth_token!(user_id, "google")
  end
end
