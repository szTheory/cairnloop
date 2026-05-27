defmodule CairnloopExampleWeb.ChatLiveTest do
  use ExUnit.Case, async: false
  alias CairnloopExampleWeb.ChatLive

  # ---------------------------------------------------------------------------
  # MockRepo: enables headless testing without a live Postgres connection.
  # Extends the pattern from test/cairnloop/chat_test.exs and test/cairnloop/web/inbox_live_test.exs.
  # ---------------------------------------------------------------------------
  defmodule MockRepo do
    # Phase 28 Plan 03: get/2 for tolerant message lookup used by Chat.get_message/1.
    # Returns different shapes based on id to test role-dedup logic in handle_info.
    def get(Cairnloop.Message, 1),
      do: %Cairnloop.Message{
        id: 1,
        role: :agent,
        content: "operator reply",
        conversation_id: 1,
        inserted_at: ~U[2026-05-27 12:00:00Z]
      }

    def get(Cairnloop.Message, 2),
      do: %Cairnloop.Message{
        id: 2,
        role: :user,
        content: "customer message",
        conversation_id: 1,
        inserted_at: ~U[2026-05-27 12:00:00Z]
      }

    def get(Cairnloop.Message, 99),
      do: %Cairnloop.Message{
        id: 99,
        role: :agent,
        content: "got it",
        conversation_id: 1,
        inserted_at: ~U[2026-05-27 12:00:00Z]
      }

    def get(Cairnloop.Message, _id), do: nil
  end

  # ---------------------------------------------------------------------------
  # Socket helpers
  # ---------------------------------------------------------------------------

  # Build a minimal disconnected socket for mount tests.
  defp build_socket(extra_assigns \\ []) do
    socket = %Phoenix.LiveView.Socket{
      private: %{connect_info: %{}, lifecycle: %{}, phoenix_live_view: %{}},
      transport_pid: nil
    }

    Enum.reduce(extra_assigns, socket, fn {k, v}, acc ->
      Phoenix.Component.assign(acc, k, v)
    end)
  end

  # Build a minimal "connected" socket for handle_event tests.
  # Phoenix LiveView considers a socket "connected" when transport_pid is non-nil.
  defp build_connected_socket(extra_assigns \\ []) do
    socket = %Phoenix.LiveView.Socket{
      private: %{connect_info: %{}, lifecycle: %{}, phoenix_live_view: %{}},
      transport_pid: self()
    }

    socket =
      socket
      |> Phoenix.Component.assign(:messages, [])
      |> Phoenix.Component.assign(:channel_status, :connecting)
      |> Phoenix.Component.assign(:pending, false)
      |> Phoenix.Component.assign(:conversation_id, nil)
      |> Phoenix.Component.assign(:send_error, false)

    Enum.reduce(extra_assigns, socket, fn {k, v}, acc ->
      Phoenix.Component.assign(acc, k, v)
    end)
  end

  # Build a socket that looks like it has a pending message.
  defp build_socket_with_pending do
    socket = build_connected_socket()

    socket
    |> Phoenix.Component.assign(:messages, [
      %{role: :customer, content: "pending msg", inserted_at: DateTime.utc_now()}
    ])
    |> Phoenix.Component.assign(:pending, true)
  end

  # ---------------------------------------------------------------------------
  # Setup: ensure Cairnloop.PubSub is available (tolerates already-started)
  # and configure MockRepo for Chat.get_message/1 calls.
  # ---------------------------------------------------------------------------

  setup_all do
    case start_supervised({Phoenix.PubSub, name: Cairnloop.PubSub}) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Test 1: mount/3 initializes the four assigns per D-03
  # ---------------------------------------------------------------------------

  test "mount/3 initializes the four assigns per D-03" do
    {:ok, socket} = ChatLive.mount(%{}, %{}, build_socket())

    assert socket.assigns.messages == []
    assert socket.assigns.channel_status == :connecting
    assert socket.assigns.pending == false
    assert socket.assigns.conversation_id == nil
  end

  # ---------------------------------------------------------------------------
  # Test 2: handle_event("conversation_id", ...) sets channel_status: :connected
  # ---------------------------------------------------------------------------

  test ~s[handle_event("conversation_id", ...) sets channel_status: :connected and assigns conversation_id] do
    socket = build_connected_socket()
    {:ok, socket} = ChatLive.mount(%{}, %{}, socket)

    {:noreply, socket} = ChatLive.handle_event("conversation_id", %{"id" => "abc-123"}, socket)

    assert socket.assigns.conversation_id == "abc-123"
    assert socket.assigns.channel_status == :connected
  end

  # ---------------------------------------------------------------------------
  # Test 3: handle_event("send_message", ...) appends optimistic customer message
  # ---------------------------------------------------------------------------

  test ~s[handle_event("send_message", ...) appends optimistic customer message and sets pending] do
    {:ok, socket} = ChatLive.mount(%{}, %{}, build_connected_socket(messages: []))

    {:noreply, socket} =
      ChatLive.handle_event("send_message", %{"message" => "hello"}, socket)

    assert length(socket.assigns.messages) == 1
    [msg] = socket.assigns.messages
    assert msg.role == :customer
    assert msg.content == "hello"
    assert socket.assigns.pending == true
  end

  # ---------------------------------------------------------------------------
  # Test 4: empty message is a no-op
  # ---------------------------------------------------------------------------

  test ~s[handle_event("send_message", ...) with empty message is a no-op] do
    {:ok, socket} = ChatLive.mount(%{}, %{}, build_connected_socket(messages: []))

    {:noreply, socket} =
      ChatLive.handle_event("send_message", %{"message" => ""}, socket)

    assert socket.assigns.messages == []
    assert socket.assigns.pending == false
  end

  # ---------------------------------------------------------------------------
  # Test 5: handle_info({:message_created, _}) appends :agent message (operator reply)
  # ---------------------------------------------------------------------------

  test "handle_info({:message_created, _}) appends :agent message (operator reply) and clears pending" do
    # MockRepo.get/2 returns %Cairnloop.Message{role: :agent, content: "operator reply"} for id 1
    socket = build_socket_with_pending()

    {:noreply, socket} = ChatLive.handle_info({:message_created, 1}, socket)

    # The :agent message should be appended as :operator role in the UI
    operator_msgs = Enum.filter(socket.assigns.messages, &(&1.role == :operator))
    assert length(operator_msgs) == 1
    assert hd(operator_msgs).content == "operator reply"
    assert socket.assigns.pending == false
  end

  # ---------------------------------------------------------------------------
  # Test 5b (multi-message-stack invariant — UI-SPEC interaction step 11)
  # Two pending customer sends then a single agent reply: pending flips to false exactly once,
  # only ONE operator message appended.
  # ---------------------------------------------------------------------------

  test "two pending customer sends then a single agent reply: pending flips to false exactly once, only one operator message appended" do
    socket1 = build_connected_socket(messages: [], pending: false)
    {:ok, socket1} = ChatLive.mount(%{}, %{}, socket1)

    # First customer send
    {:noreply, socket2} =
      ChatLive.handle_event("send_message", %{"message" => "msg one"}, socket1)

    assert socket2.assigns.pending == true
    assert length(socket2.assigns.messages) == 1

    # Second customer send — pending STAYS true, NOT toggled
    {:noreply, socket3} =
      ChatLive.handle_event("send_message", %{"message" => "msg two"}, socket2)

    assert socket3.assigns.pending == true
    assert length(socket3.assigns.messages) == 2
    assert Enum.all?(socket3.assigns.messages, &(&1.role == :customer))

    # Single agent reply via PubSub (MockRepo id 99 → "got it")
    {:noreply, socket4} = ChatLive.handle_info({:message_created, 99}, socket3)

    # pending flips to false exactly once
    assert socket4.assigns.pending == false

    # Only ONE operator message appended — NOT duplicated
    assert length(socket4.assigns.messages) == 3

    # Verify ordering: [customer "msg one", customer "msg two", operator "got it"]
    [m1, m2, m3] = socket4.assigns.messages
    assert m1.role == :customer
    assert m1.content == "msg one"
    assert m2.role == :customer
    assert m2.content == "msg two"
    assert m3.role == :operator
    assert m3.content == "got it"
  end

  # ---------------------------------------------------------------------------
  # Test 6: handle_info({:message_created, _}) skips :user role (Pitfall 7 dedup)
  # ---------------------------------------------------------------------------

  test "handle_info({:message_created, _}) skips :user role (Pitfall 7 dedup)" do
    # MockRepo.get/2 returns %Cairnloop.Message{role: :user} for id 2
    optimistic_user_msg = %{role: :customer, content: "hello", inserted_at: DateTime.utc_now()}
    socket = build_connected_socket(messages: [optimistic_user_msg], pending: true)

    {:noreply, updated_socket} = ChatLive.handle_info({:message_created, 2}, socket)

    # Messages should be unchanged (user-role message skipped by dedup)
    assert updated_socket.assigns.messages == socket.assigns.messages
  end

  # ---------------------------------------------------------------------------
  # Test 7 (negative grep — path resolution LOCKED via Application.app_dir/2)
  # chat_live.ex no longer references Process.send_after or :bot_reply
  # ---------------------------------------------------------------------------

  test "chat_live.ex no longer references Process.send_after or :bot_reply" do
    # Path resolved via Application.app_dir/2 because test runner cwd may differ from
    # example-app root (checker fix per 28-revision — T-28-03-08 mitigation).
    path =
      Application.app_dir(:cairnloop_example, "..")
      |> Path.join("lib/cairnloop_example_web/live/chat_live.ex")
      |> Path.expand()

    src = File.read!(path)
    refute src =~ "Process.send_after"
    refute src =~ ":bot_reply"
    refute src =~ "handle_info(:bot_reply"
  end
end
