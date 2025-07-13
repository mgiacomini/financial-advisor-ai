defmodule FinancialAdvisorAi.Repo.Migrations.CreateOngoingInstructions do
  use Ecto.Migration

  def change do
    create table(:ongoing_instructions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :instruction, :text, null: false
      add :trigger_type, :string, null: false
      add :active, :boolean, default: true
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:ongoing_instructions, [:user_id])
    create index(:ongoing_instructions, [:active])
  end
end
