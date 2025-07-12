defmodule FinancialAdvisorAi.Repo.Migrations.CreateEmbeddings do
  use Ecto.Migration

  def change do
    create table(:embeddings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :source_type, :string, null: false
      add :source_id, :string, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 1536
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:embeddings, [:user_id])
    create index(:embeddings, [:source_type, :source_id])

    # Create vector index for similarity search
    execute """
    CREATE INDEX embeddings_embedding_idx ON embeddings
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    """
  end
end
