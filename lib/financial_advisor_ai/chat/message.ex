defmodule FinancialAdvisorAi.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :role, :string
    field :content, :string
    field :tool_calls, {:array, :map}
    field :tool_responses, {:array, :map}
    field :state, :string, default: "pending"
    field :processed_at, :utc_datetime
    field :error_message, :string

    belongs_to :conversation, FinancialAdvisorAi.Chat.Conversation

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :role,
      :content,
      :tool_calls,
      :tool_responses,
      :conversation_id,
      :state,
      :processed_at,
      :error_message
    ])
    |> validate_required([:role, :conversation_id])
    |> validate_inclusion(:role, ["user", "assistant", "system"])
    |> validate_inclusion(:state, ["pending", "processing", "completed", "failed"])
    |> validate_content_or_tool_calls()
  end

  defp validate_content_or_tool_calls(changeset) do
    content = get_field(changeset, :content)
    tool_calls = get_field(changeset, :tool_calls)

    # Content is required unless there are tool calls
    cond do
      # If there's content, it's valid
      content && String.trim(content) != "" ->
        changeset

      # If there are tool calls but no content, provide default content
      tool_calls && length(tool_calls) > 0 ->
        put_change(changeset, :content, "")

      # Neither content nor tool calls - invalid
      true ->
        add_error(changeset, :content, "can't be blank when no tool calls are present")
    end
  end
end
