defmodule Cairnloop.Channels.WidgetChannel do
  use Phoenix.Channel

  @impl true
  def join("widget:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("widget:" <> _private_room_id, _payload, socket) do
    # For a real implementation, we would check if the user has access to this room.
    # For now, allow it if they are authenticated.
    if socket.assigns[:user_token] do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_message", %{"content" => content}, socket) do
    # T-M001-03 Mitigation: Enqueueing to Oban prevents channel blocking.
    %{channel: "widget", content: content}
    |> Cairnloop.Workers.ProcessMessage.new()
    |> Oban.insert()

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("submit_csat", %{"rating" => rating}, socket) do
    "widget:" <> conversation_id = socket.topic

    case Cairnloop.Chat.submit_csat(conversation_id, rating) do
      {:ok, _conversation} ->
        {:reply, :ok, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "invalid_rating"}}, socket}
    end
  end
end
