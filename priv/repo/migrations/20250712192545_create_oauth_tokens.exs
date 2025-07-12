defmodule FinancialAdvisorAi.Repo.Migrations.CreateOauthTokens do
  use Ecto.Migration

  def change do
    create table(:oauth_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :access_token, :binary, null: false
      add :refresh_token, :binary
      add :expires_at, :utc_datetime
      add :scopes, {:array, :string}

      timestamps(type: :utc_datetime)
    end

    create index(:oauth_tokens, [:user_id])
    create unique_index(:oauth_tokens, [:user_id, :provider])
  end
end
