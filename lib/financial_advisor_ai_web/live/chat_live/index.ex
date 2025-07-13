defmodule FinancialAdvisorAiWeb.ChatLive.Index do
  use FinancialAdvisorAiWeb, :live_view
  alias FinancialAdvisorAi.{Chat, Accounts}
  alias FinancialAdvisorAi.Chat.Message

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || session[:user_id]
    user = Accounts.get_user!(user_id)
    conversations = Chat.list_user_conversations(user_id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:conversations, conversations)
      |> assign(:current_conversation, nil)
      |> assign(:messages, [])
      |> assign(:message_input, "")
      |> assign(:processing, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_conversation", %{"id" => id}, socket) do
    conversation = Chat.get_conversation!(id)
    messages = Chat.list_conversation_messages(id)

    {:noreply,
     socket
     |> assign(:current_conversation, conversation)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    {:ok, conversation} =
      Chat.create_conversation(%{
        user_id: socket.assigns.user.id,
        title: "New Conversation"
      })

    conversations = [conversation | socket.assigns.conversations]

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:current_conversation, conversation)
     |> assign(:messages, [])}
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    if String.trim(content) != "" and socket.assigns.current_conversation do
      send(self(), {:process_message, content})

      {:noreply,
       socket
       |> assign(:message_input, "")
       |> assign(:processing, true)}
    else
      {:noreply, socket}
    end
  end

  # @impl true
  # def handle_event("update_message", %{"message" => %{"content" => content}}, socket) do
  #   {:noreply, assign(socket, :message_input, content)}
  # end

  @impl true
  def handle_info({:process_message, content}, socket) do
    conversation_id = socket.assigns.current_conversation.id
    user_id = socket.assigns.user.id

    # Process with agent
    Task.start(fn ->
      result = Chat.Agent.process_message(user_id, conversation_id, content)
      send(self(), {:message_processed, result})
    end)

    # Add user message to UI immediately
    user_message = %Message{
      id: System.unique_integer([:positive]),
      role: "user",
      content: content,
      conversation_id: conversation_id,
      inserted_at: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> update(:messages, &(&1 ++ [user_message]))}
  end

  @impl true
  def handle_info({:message_processed, {:ok, _}}, socket) do
    # Refresh messages to get the complete conversation
    messages = Chat.list_conversation_messages(socket.assigns.current_conversation.id)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:processing, false)}
  end

  @impl true
  def handle_info({:message_processed, {:error, _error}}, socket) do
    {:noreply,
     socket
     |> assign(:processing, false)
     |> put_flash(:error, "Failed to process message. Please try again.")}
  end
end
