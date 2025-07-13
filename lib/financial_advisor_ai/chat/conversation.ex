defmodule FinancialAdvisorAi.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :title, :string

    belongs_to :user, FinancialAdvisorAi.Accounts.User
    has_many :messages, FinancialAdvisorAi.Chat.Message

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :user_id])
    |> validate_required([:user_id])
  end
end
