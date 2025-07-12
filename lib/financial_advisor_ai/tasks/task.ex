defmodule FinancialAdvisorAi.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :type, :string
    field :status, :string, default: "pending"
    field :data, :map
    field :result, :map
    field :execute_at, :utc_datetime
    field :parent_task_id, :integer

    belongs_to :user, FinancialAdvisorAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:type, :status, :data, :result, :execute_at, :parent_task_id, :user_id])
    |> validate_required([:type, :data, :user_id])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "failed", "waiting"])
  end
end
