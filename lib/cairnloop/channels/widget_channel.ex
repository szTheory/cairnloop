defmodule Cairnloop.Channels.WidgetChannel do
  use Phoenix.Channel

  @impl true
  # D-01: On join, create a Conversation row via the Chat facade.
  # D-04: Orphan rows (user joins but never sends) are accepted in Phase 28 — no TTL reaper.
  # Pitfall 5: Rejoin race acceptance — duplicate join calls within the same session are
  # possible on reconnect; the Oban unique: option on ProcessMessage mitigates duplicate
  # message processing, and orphan conversations are tolerable per D-04.
  # The host_user_id field is :string on Conversation, so the binary token from
  # socket.assigns[:user_token] is fine without coercion (carried decision).
  def join("widget:lobby", _payload, socket) do
    token = socket.assigns[:user_token]

    case Cairnloop.Chat.create_customer_conversation(%{host_user_id: token}) do
      {:ok, conversation} ->
        updated_socket = Phoenix.Socket.assign(socket, :conversation_id, conversation.id)
        {:ok, %{conversation_id: conversation.id}, updated_socket}

      {:error, _changeset} ->
        {:error, %{reason: "could_not_create_conversation"}}
    end
  end

  # Deferred per CONTEXT.md specifics §122 — Phase 28 stays on widget:lobby.
  # This clause handles conversation-scoped private rooms (used by CSAT and future
  # features) and is preserved byte-for-byte until a future phase re-enables the
  # channel re-join flow.
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
  # D-07: conversation_id is read from socket.assigns[:conversation_id] — set during join.
  # T-M001 security note: conversation_id is NEVER read from the inbound payload.
  # A client-supplied "conversation_id" key in the payload would bypass server-trust
  # state and allow a customer to inject messages into another conversation.
  # The pattern match below binds ONLY "content" from the payload.
  def handle_in("new_message", %{"content" => content}, socket) do
    conversation_id = socket.assigns[:conversation_id]

    %{channel: "widget", conversation_id: conversation_id, content: content}
    |> Cairnloop.Workers.ProcessMessage.new()
    |> Oban.insert()

    {:reply, :ok, socket}
  end

  @impl true
  # CSAT deferred per CONTEXT.md OQ-4 — channel re-join not yet implemented.
  # Returns a structured error instead of crashing on "widget:lobby" pattern mismatch.
  # CR-02 fix: the previous clause destructured socket.topic with "widget:" <> conversation_id,
  # which succeeds with conversation_id = "lobby" on the lobby topic, then called
  # Chat.submit_csat("lobby", rating) → Ecto.Query.CastError (cannot cast "lobby" to integer).
  def handle_in("submit_csat", _payload, socket) do
    {:reply, {:error, %{reason: "csat_not_available"}}, socket}
  end
end
