defmodule FinancialAdvisorAi.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    # "user", "assistant", "system"
    field :role, :string
    field :content, :string
    field :tool_calls, :map
    field :tool_responses, :map

    belongs_to :conversation, FinancialAdvisorAi.Chat.Conversation

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :tool_calls, :tool_responses, :conversation_id])
    |> validate_required([:role, :content, :conversation_id])
    |> validate_inclusion(:role, ["user", "assistant", "system"])
  end
end
