defmodule Cairnloop.Web.ConversationLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
    end

    conversation = Chat.get_conversation!(id)

    provider = Application.get_env(:cairnloop, :context_provider, SupportOS.DefaultContextProvider)

    {context, context_error} =
      if conversation.host_user_id do
        case provider.get_context(conversation.host_user_id, []) do
          {:ok, map} -> {map, nil}
          {:error, reason} -> {%{}, reason}
        end
      else
        {%{}, nil}
      end

    {:ok,
     assign(socket,
       conversation: conversation,
       form: to_form(%{"content" => ""}),
       host_context: context,
       context_error: context_error
     )}
  end

  def handle_info({:draft_created, _draft_id}, socket) do
    conversation = Chat.get_conversation!(socket.assigns.conversation.id)
    {:noreply, assign(socket, conversation: conversation)}
  end

  def handle_event("reply", %{"content" => content}, socket) do
    if content != "" do
      case Chat.reply_to_conversation(socket.assigns.conversation.id, content) do
        {:ok, _result} ->
          # Reload conversation to get new messages
          conversation = Chat.get_conversation!(socket.assigns.conversation.id)

          {:noreply,
           assign(socket, conversation: conversation, form: to_form(%{"content" => ""}))}

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

  def handle_event("approve_draft", %{"draft-id" => draft_id}, socket) do
    case Cairnloop.Automation.approve_draft(String.to_integer(draft_id)) do
      {:ok, _} ->
        conversation = Chat.get_conversation!(socket.assigns.conversation.id)
        {:noreply, assign(socket, conversation: conversation)}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to approve draft.")}
    end
  end

  def handle_event("edit_draft", %{"draft-id" => draft_id}, socket) do
    draft_id = String.to_integer(draft_id)
    draft = Enum.find(socket.assigns.conversation.drafts, &(&1.id == draft_id))

    case Cairnloop.Automation.mark_draft_edited(draft_id) do
      {:ok, _} ->
        conversation = Chat.get_conversation!(socket.assigns.conversation.id)

        {:noreply,
         assign(socket, conversation: conversation, form: to_form(%{"content" => draft.content}))}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to edit draft.")}
    end
  end

  def handle_event("discard_draft", %{"draft-id" => draft_id}, socket) do
    case Cairnloop.Automation.discard_draft(String.to_integer(draft_id)) do
      {:ok, _} ->
        conversation = Chat.get_conversation!(socket.assigns.conversation.id)
        {:noreply, assign(socket, conversation: conversation)}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to discard draft.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="cairnloop-conversation">
      <.link navigate="/">Back to Inbox</.link>
      <h2><%= @conversation.subject || "No Subject" %></h2>
      
      <%= if @context_error do %>
        <div class="host-context error">
          <h3>Customer Context</h3>
          <p>Context Unavailable: <%= inspect(@context_error) %></p>
        </div>
      <% else %>
        <%= if map_size(@host_context) > 0 do %>
          <div class="host-context">
            <h3>Customer Context</h3>
            <ul>
              <%= for {key, value} <- @host_context do %>
                <li><strong><%= key %>:</strong> <%= inspect(value) %></li>
              <% end %>
            </ul>
          </div>
        <% end %>
      <% end %>

      <div class="messages">
        <%= for msg <- @conversation.messages do %>
          <div class={"message role-#{msg.role}"}>
            <strong><%= msg.role %>:</strong>
            <p><%= msg.content %></p>
          </div>
        <% end %>
      </div>

      <div class="drafts">
        <%= if Ecto.assoc_loaded?(@conversation.drafts) and length(@conversation.drafts) > 0 do %>
          <h3>Drafts</h3>
          <%= for draft <- @conversation.drafts do %>
            <div class="draft">
              <p><strong>Draft:</strong> <%= draft.content %></p>
              <p><em>Status: <%= draft.status %></em></p>
              <%= if draft.status in [:pending, :edited] do %>
                <button phx-click="approve_draft" phx-value-draft-id={draft.id}>Approve & Send</button>
                <button phx-click="edit_draft" phx-value-draft-id={draft.id}>Edit</button>
                <button phx-click="discard_draft" phx-value-draft-id={draft.id}>Discard</button>
              <% end %>
            </div>
          <% end %>
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
