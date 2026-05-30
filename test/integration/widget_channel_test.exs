defmodule Cairnloop.Integration.WidgetChannelTest do
  @moduledoc """
  E2E-02: Widget channel ingress + operator-side delivery integration test.
  Contributes to E2E-03 (lives in the `mix test.integration` lane).

  Proves the Phase 28 CHAT-01/CHAT-02 wiring end-to-end:
    - Customer joins WidgetChannel on "widget:lobby" (via socket/3, bypassing endpoint mount)
    - Customer pushes "new_message" — WidgetChannel enqueues ProcessMessage job
    - ProcessMessage.perform/1 called inline (D-09: direct perform, not via Oban queue drain)
    - Chat.ingest_widget_message/2 inserts the Message and broadcasts {:conversations_changed}
    - Operator-side InboxLive (mounted and connected before the push) re-renders showing the conversation

  # REPO-UNAVAILABLE — only runs under mix test.integration
  """

  use Cairnloop.ConnCase, async: false

  # D-05: ConnCase does NOT import Phoenix.ChannelTest; add it inline.
  # Resolve import ambiguities that arise when Phoenix.ChannelTest and the ConnCase
  # transitive imports (Plug.Conn, Phoenix.LiveViewTest) share the same function names:
  #   - push/3: Plug.Conn (HTTP/2 server push) vs Phoenix.ChannelTest (channel push)
  #   - assert_reply/2: Phoenix.LiveViewTest vs Phoenix.ChannelTest (channel reply)
  # Re-import the conflicting modules with `except:` so Phoenix.ChannelTest wins for all.
  import Phoenix.ChannelTest
  import Phoenix.LiveViewTest, except: [assert_reply: 2, assert_reply: 3]

  alias Cairnloop.Workers.ProcessMessage

  # ConnCase already sets @endpoint Cairnloop.Web.Endpoint (line 14 of conn_case.ex).
  # Pitfall 6: @endpoint is required by Phoenix.ChannelTest.socket/3.
  # DO NOT redeclare — rely on the inherited attribute.

  setup %{conn: conn} do
    # WidgetChannel.handle_in/3 calls Oban.insert/1 to enqueue ProcessMessage.
    # The config/test.exs design uses no live Oban instance, so we start one in
    # :manual testing mode — inserts succeed without an oban_jobs table or queue workers.
    start_supervised!({Oban, name: Oban, repo: Cairnloop.Repo, queues: [], testing: :manual})

    # Build an authed operator conn for LiveView mounts.
    conn = Plug.Test.init_test_session(conn, %{"host_user_id" => "widget_operator"})
    %{conn: conn}
  end

  test "customer message joins, processes, and reaches the operator inbox", %{conn: conn} do
    # Step 1 — Mount InboxLive FIRST so the connected process subscribes to "conversations"
    # PubSub topic before any channel activity (D-06). The connected? guard in InboxLive.mount/3
    # fires Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations") for connected sockets.
    {:ok, inbox_view, _html} = live(conn, "/inbox")

    # Belt-and-suspenders: also subscribe the test process directly so we can
    # assert_receive {:conversations_changed} independently of the InboxLive re-render.
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")

    # Step 2 — Join the WidgetChannel.
    # Pitfall 7: The test endpoint does NOT mount WidgetSocket — use socket/3 directly.
    # socket/3 builds the socket struct without going through the endpoint mount.
    {:ok, reply, channel_socket} =
      socket(Cairnloop.Channels.WidgetSocket, "widget_socket:demo_customer", %{
        user_token: "demo_customer"
      })
      |> subscribe_and_join(Cairnloop.Channels.WidgetChannel, "widget:lobby", %{})

    # Join reply includes the server-assigned conversation_id (set in socket.assigns during join).
    assert %{conversation_id: conversation_id} = reply
    assert is_integer(conversation_id)

    # Step 3 — Push a customer message.
    ref =
      Phoenix.ChannelTest.push(channel_socket, "new_message", %{
        "content" => "Hello from the widget"
      })

    assert_reply(ref, :ok)

    # Step 4 — Process the enqueued job inline (D-09: never Oban.drain_queue).
    # ProcessMessage.perform/1 calls Chat.ingest_widget_message/2 which:
    #   1. Inserts a :user-role Message row
    #   2. Broadcasts {:message_created, message.id} on "conversation:#{conversation_id}"
    #   3. Broadcasts {:conversations_changed} on "conversations"
    assert :ok =
             ProcessMessage.perform(%Oban.Job{
               args: %{
                 "channel" => "widget",
                 "conversation_id" => conversation_id,
                 "content" => "Hello from the widget"
               }
             })

    # Step 5 — Prove operator-side delivery (D-06).
    # Belt-and-suspenders: the test process subscribed in Step 1 so we can
    # definitively confirm the {:conversations_changed} broadcast fired.
    assert_receive {:conversations_changed}, 1_000

    # Load-bearing operator-delivery proof: InboxLive re-renders after
    # handle_info({:conversations_changed}, socket) reloads Chat.list_conversations().
    # The conversation created on join has host_user_id="demo_customer" (the token).
    # InboxLive renders conversation.id in the link href and subject in the <strong> tag.
    # Assert the conversation_id appears in the rendered HTML as the definitive proof
    # that the new conversation row reached the operator inbox.
    html = render(inbox_view)
    assert html =~ to_string(conversation_id)
  end
end
