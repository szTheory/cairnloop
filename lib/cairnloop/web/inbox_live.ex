defmodule Cairnloop.Web.InboxLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

  def mount(_params, session, socket) do
    if connected?(socket) do
      # In a real app we would subscribe to a pubsub here
    end

    conversations = Chat.list_conversations()

    {:ok,
     assign(socket,
       conversations: conversations,
       host_user_id: Map.get(session, "host_user_id")
     )}
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
    <.live_component
      module={Cairnloop.Web.SearchModalComponent}
      id="search-modal"
      host_surface="inbox"
      host_user_id={@host_user_id}
      current_path="/"
    />
    """
  end
end
