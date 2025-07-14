defmodule FinancialAdvisorAi.Repo.Migrations.AddStateToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :state, :string, default: "pending"
      add :processed_at, :utc_datetime
      add :error_message, :text
    end

    create index(:messages, [:state])
    create index(:messages, [:processed_at])
  end
end
