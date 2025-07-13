defmodule FinancialAdvisorAi.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :status, :string, default: "pending"
      add :data, :map, null: false
      add :result, :map
      add :execute_at, :utc_datetime
      add :parent_task_id, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tasks, [:user_id])
    create index(:tasks, [:status])
    create index(:tasks, [:execute_at])
  end
end
