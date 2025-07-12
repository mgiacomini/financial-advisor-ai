defmodule FinancialAdvisorAi.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :tool_calls, :map
      add :tool_responses, :map

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id])
  end
end
