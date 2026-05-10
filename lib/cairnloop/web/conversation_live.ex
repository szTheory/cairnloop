defmodule Cairnloop.Web.ConversationLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

  def mount(%{"id" => id}, _session, socket) do
    conversation = Chat.get_conversation!(id)
    {:ok, assign(socket, conversation: conversation, form: to_form(%{"content" => ""}))}
  end

  def handle_event("reply", %{"content" => content}, socket) do
    if content != "" do
      case Chat.reply_to_conversation(socket.assigns.conversation.id, content) do
        {:ok, _result} ->
          # Reload conversation to get new messages
          conversation = Chat.get_conversation!(socket.assigns.conversation.id)
          {:noreply, assign(socket, conversation: conversation, form: to_form(%{"content" => ""}))}
        {:error, _failed_operation, _failed_value, _changes_so_far} ->
          {:noreply, put_flash(socket, :error, "Failed to send reply.")}
      end
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("change", %{"content" => content}, socket) do
    {:noreply, assign(socket, form: to_form(%{"content" => content}))}
  end

  def render(assigns) do
    ~H"""
    <div class="cairnloop-conversation">
      <.link navigate="/">Back to Inbox</.link>
      <h2><%= @conversation.subject || "No Subject" %></h2>
      
      <div class="messages">
        <%= for msg <- @conversation.messages do %>
          <div class={"message role-#{msg.role}"}>
            <strong><%= msg.role %>:</strong>
            <p><%= msg.content %></p>
          </div>
        <% end %>
      </div>

      <div class="reply-form">
        <.form for={@form} phx-submit="reply" phx-change="change">
          <textarea name="content" placeholder="Type a reply..."><%= @form.params["content"] %></textarea>
          <button type="submit">Send Reply</button>
        </.form>
      </div>
    </div>
    """
  end
end
