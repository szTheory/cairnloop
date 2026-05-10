defmodule Cairnloop.Web.InboxLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # In a real app we would subscribe to a pubsub here
    end

    conversations = Chat.list_conversations()
    {:ok, assign(socket, conversations: conversations)}
  end

  def render(assigns) do
    ~H"""
    <div class="cairnloop-inbox">
      <h1>Inbox</h1>
      <ul>
        <%= for conv <- @conversations do %>
          <li>
            <.link navigate={"/#{conv.id}"}>
              <strong><%= conv.subject || "No Subject" %></strong>
              - <%= conv.status %>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
