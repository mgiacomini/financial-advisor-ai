defmodule FinancialAdvisorAi.Tasks.OngoingInstruction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ongoing_instructions" do
    field :instruction, :string
    field :trigger_type, :string
    field :active, :boolean, default: true
    field :metadata, :map

    belongs_to :user, FinancialAdvisorAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(instruction, attrs) do
    instruction
    |> cast(attrs, [:instruction, :trigger_type, :active, :metadata, :user_id])
    |> validate_required([:instruction, :trigger_type, :user_id])
    |> validate_inclusion(:trigger_type, ["email", "calendar", "hubspot", "any"])
  end
end
