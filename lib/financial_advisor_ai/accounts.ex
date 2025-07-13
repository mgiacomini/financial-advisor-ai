defmodule FinancialAdvisorAi.Accounts do
  import Ecto.Query, warn: false
  alias FinancialAdvisorAi.Repo
  alias FinancialAdvisorAi.Accounts.OAuthToken

  @doc """
  Gets a valid OAuth token for a user and provider, raising an error if not found or expired.

  ## Parameters
    - user_id: The ID of the user
    - provider: The OAuth provider ("google", "hubspot")
    
  ## Returns
    - OAuthToken struct if valid token found
    - Raises an error if no valid token found
  """
  def get_valid_oauth_token!(user_id, provider) do
    now = DateTime.utc_now()

    token =
      OAuthToken
      |> where([t], t.user_id == ^user_id and t.provider == ^provider)
      |> where([t], is_nil(t.expires_at) or t.expires_at > ^now)
      |> order_by([t], desc: t.updated_at)
      |> limit(1)
      |> Repo.one()

    case token do
      nil ->
        raise "No valid #{provider} OAuth token found for user #{user_id}"

      token ->
        token
    end
  end
end
