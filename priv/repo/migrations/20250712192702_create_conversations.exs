defmodule FinancialAdvisorAi.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:user_id])
  end
end
