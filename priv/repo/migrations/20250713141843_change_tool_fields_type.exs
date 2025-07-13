defmodule FinancialAdvisorAi.Repo.Migrations.ChangeToolFieldsType do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      modify :tool_calls, :jsonb, null: true
      modify :tool_responses, :jsonb, null: true
    end
  end
end
