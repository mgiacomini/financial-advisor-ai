defmodule FinancialAdvisorAi.Accounts do
  import Ecto.Query, warn: false
  alias FinancialAdvisorAi.Repo
  alias FinancialAdvisorAi.Accounts.{User, OAuthToken}

  def find_or_create_user(auth) do
    _provider = to_string(auth.provider)
    email = auth.info.email

    case get_user_by_email(email) do
      nil ->
        create_user(%{
          name: auth.info.name,
          email: email,
          avatar_url: auth.info.image
        })

      user ->
        {:ok, user}
    end
  end

  def create_or_update_oauth_token(user, auth) do
    provider = to_string(auth.provider)
    token_data = auth.credentials |> IO.inspect()

    case get_valid_oauth_token(user.id, provider) do
      nil ->
        create_oauth_token(%{
          user_id: user.id,
          provider: provider,
          access_token: token_data.token,
          refresh_token: token_data.refresh_token,
          expires_at: DateTime.from_unix!(token_data.expires_at)
        })

      existing_token ->
        update_oauth_token(existing_token, %{
          access_token: token_data.token,
          refresh_token: token_data.refresh_token,
          expires_at: DateTime.from_unix!(token_data.expires_at)
        })
    end
  end

  def get_user_by_oauth(_provider, uid) do
    # Find user by email since OAuth UID is not stored in our schema
    # This is a simplified approach - in production you might want to store OAuth UID
    User
    |> where([u], u.email == ^uid)
    |> Repo.one()
  end

  def get_user_by_email(email) do
    User
    |> where([u], u.email == ^email)
    |> Repo.one()
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_valid_oauth_token(user_id, provider) do
    now = DateTime.utc_now()

    OAuthToken
    |> where([t], t.user_id == ^user_id and t.provider == ^provider)
    |> where([t], is_nil(t.expires_at) or t.expires_at > ^now)
    |> order_by([t], desc: t.updated_at)
    |> limit(1)
    |> Repo.one()
  end

  def create_oauth_token(attrs) do
    %OAuthToken{}
    |> OAuthToken.changeset(attrs)
    |> Repo.insert()
  end

  def update_oauth_token(token, attrs) do
    token
    |> OAuthToken.changeset(attrs)
    |> Repo.update()
  end

  def get_user(id) do
    Repo.get(FinancialAdvisorAi.Accounts.User, id)
  end

  def get_user!(id) do
    Repo.get!(FinancialAdvisorAi.Accounts.User, id)
  end

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
    case get_valid_oauth_token(user_id, provider) do
      nil -> raise "No valid #{provider} OAuth token found for user #{user_id}"
      token -> token
    end
  end
end
