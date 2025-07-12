defmodule FinancialAdvisorAi.Accounts.OAuthToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_tokens" do
    field :provider, :string
    field :access_token, FinancialAdvisorAi.Encrypted.Binary
    field :refresh_token, FinancialAdvisorAi.Encrypted.Binary
    field :expires_at, :utc_datetime
    field :scopes, {:array, :string}

    belongs_to :user, FinancialAdvisorAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:provider, :access_token, :refresh_token, :expires_at, :scopes, :user_id])
    |> validate_required([:provider, :access_token, :user_id])
    |> validate_inclusion(:provider, ["google", "hubspot"])
  end
end
