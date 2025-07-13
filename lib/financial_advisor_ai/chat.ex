defmodule FinancialAdvisorAi.Chat do
  import Ecto.Query, warn: false
  alias FinancialAdvisorAi.Repo
  alias FinancialAdvisorAi.Chat.Conversation
  alias FinancialAdvisorAi.Chat.Message

  def list_user_conversations(user_id) do
    Conversation
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def get_conversation!(id) do
    Repo.get!(Conversation, id)
  end

  def list_conversation_messages(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  def create_conversation(attrs) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end
end
