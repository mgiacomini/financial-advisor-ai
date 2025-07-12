defmodule FinancialAdvisorAi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar_url, :string

    has_many :oauth_tokens, FinancialAdvisorAi.Accounts.OAuthToken
    has_many :conversations, FinancialAdvisorAi.Chat.Conversation
    has_many :embeddings, FinancialAdvisorAi.RAG.Embedding
    has_many :tasks, FinancialAdvisorAi.Tasks.Task
    has_many :instructions, FinancialAdvisorAi.Tasks.OngoingInstruction

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
