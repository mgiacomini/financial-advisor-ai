defmodule FinancialAdvisorAi.RAG.Embedding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "embeddings" do
    field :source_type, :string
    field :source_id, :string
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector
    field :metadata, :map

    belongs_to :user, FinancialAdvisorAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(embedding, attrs) do
    embedding
    |> cast(attrs, [:source_type, :source_id, :content, :embedding, :metadata, :user_id])
    |> validate_required([:source_type, :source_id, :content, :embedding, :user_id])
  end
end
