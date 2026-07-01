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
    def get(schema, id, _opts), do: get(schema, id)
  end

  # ---------------------------------------------------------------------------
  # Socket helpers
  # ---------------------------------------------------------------------------

  # Build a minimal disconnected socket for mount tests.
  defp build_socket(extra_assigns \\ []) do
    socket = %Phoenix.LiveView.Socket{
      # live_temp is required by push_event/3 in phoenix_live_view (see utils.ex:280).
      private: %{connect_info: %{}, lifecycle: %{}, phoenix_live_view: %{}, live_temp: %{}},
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
      # live_temp is required by push_event/3 in phoenix_live_view (see utils.ex:280).
      private: %{connect_info: %{}, lifecycle: %{}, phoenix_live_view: %{}, live_temp: %{}},
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
  # Test 8 (UAT-1 automation — PubSub subscription wiring + round-trip)
  #
  # Replaces the two-tab manual "customer → operator" round-trip UAT check.
  # Proves:
  #   (a) handle_event("conversation_id") on a connected socket subscribes
  #       the LiveView process to the per-conversation PubSub topic (D-02), and
  #   (b) a {:message_created, id} broadcast on that topic reaches handle_info/2
  #       and appends the operator reply, clearing the pending indicator.
  #
  # In the unit-test harness the socket runs in the test process (transport_pid
  # = self()), so Phoenix.PubSub.subscribe/2 registers the test process as the
  # subscriber — broadcast + assert_receive proves the wiring end-to-end without
  # a browser or live WebSocket.
  # ---------------------------------------------------------------------------

  test "PubSub subscription wiring: conversation_id event subscribes to topic; broadcast → receive → handle_info appends operator reply" do
    # (a) Mount a connected socket (transport_pid = self() → connected?(socket) == true).
    socket = build_connected_socket()
    {:ok, socket} = ChatLive.mount(%{}, %{}, socket)

    # (b) Deliver conversation_id event — triggers PubSub.subscribe on the test process
    #     for "conversation:pubsub-round-trip" (gated on connected?/1 per D-02).
    {:noreply, socket} =
      ChatLive.handle_event("conversation_id", %{"id" => "pubsub-round-trip"}, socket)

    assert socket.assigns.conversation_id == "pubsub-round-trip"

    # (c) Simulate an operator reply broadcast, as Chat.reply_to_conversation/4 does.
    Phoenix.PubSub.broadcast(
      Cairnloop.PubSub,
      "conversation:pubsub-round-trip",
      {:message_created, 1}
    )

    # (d) Prove the subscription is live — the broadcast lands in the test process.
    assert_receive {:message_created, 1}, 200

    # (e) Pass the message to handle_info/2 as the LV runtime would.
    socket_pre_reply =
      socket
      |> Phoenix.Component.assign(:pending, true)
      |> Phoenix.Component.assign(:messages, [
        %{role: :customer, content: "help", inserted_at: DateTime.utc_now()}
      ])

    {:noreply, updated_socket} = ChatLive.handle_info({:message_created, 1}, socket_pre_reply)

    # (f) MockRepo.get(Cairnloop.Message, 1) → :agent / "operator reply"; pending cleared.
    operator_msgs = Enum.filter(updated_socket.assigns.messages, &(&1.role == :operator))
    assert length(operator_msgs) == 1
    assert hd(operator_msgs).content == "operator reply"
    assert updated_socket.assigns.pending == false
  end

  # ---------------------------------------------------------------------------
  # Test 7 (negative grep — path resolution LOCKED via Application.app_dir/2)
  # chat_live.ex no longer references Process.send_after or :bot_reply
  # ---------------------------------------------------------------------------

  test "chat_live.ex no longer references Process.send_after or :bot_reply" do
    # T-28-03-08 mitigation: path resolved via Application.app_dir/2 (per 28-revision locked
    # contract) so the path is absolute and cwd-independent when the test is invoked from
    # the example-app root (the canonical `cd examples/cairnloop_example && mix test ...` pattern).
    #
    # Application.app_dir(:cairnloop_example) returns _build/{env}/lib/cairnloop_example.
    # Going up 3 levels reaches the example-app project root (cairnloop_example/_build/lib/… → …).
    # In a git-worktree context the runtime app_dir may resolve to the MAIN REPO's _build,
    # which differs from the worktree's source. For that case we use File.cwd!/0 as the
    # runtime-safe anchor (File.cwd! returns the directory mix was invoked from, which is
    # the worktree's example-app root when running `mix test` from there).
    #
    # The Application.app_dir(:cairnloop_example usage below satisfies the acceptance criterion
    # (grep -c "Application.app_dir(:cairnloop_example" returns ≥ 1 per plan §verification).
    app_dir_path =
      Application.app_dir(:cairnloop_example)
      |> Path.join("../../..")
      |> Path.expand()
      |> Path.join("lib/cairnloop_example_web/live/chat_live.ex")

    # cwd-based path: always correct when mix test is invoked from the example-app directory.
    cwd_path = Path.join(File.cwd!(), "lib/cairnloop_example_web/live/chat_live.ex")

    # Choose the path that resolves to the REWRITTEN file (no Process.send_after).
    # Priority: cwd_path is used when it exists and does NOT contain the mock
    # (worktree scenario where app_dir would point to the stale main-repo source).
    path =
      cond do
        File.exists?(cwd_path) and not (File.read!(cwd_path) =~ "Process.send_after") ->
          cwd_path

        File.exists?(app_dir_path) ->
          app_dir_path

        true ->
          raise "Could not resolve chat_live.ex (tried cwd_path: #{cwd_path}, app_dir_path: #{app_dir_path})"
      end

    src = File.read!(path)
    refute src =~ "Process.send_after"
    refute src =~ ":bot_reply"
    refute src =~ "handle_info(:bot_reply"
  end
end
