defmodule CairnloopExample.WidgetChannelObanTest do
  # Phase 28 Plan 02: Oban testing for WidgetChannel.handle_in("new_message", ...).
  #
  # These tests live in the example app (not the library test tree) because
  # Oban.Testing requires a Repo that is configured with `testing: :manual`,
  # and the library ships no Oban instance of its own (host-owned library posture).
  # The example app has `config :cairnloop_example, Oban, testing: :manual` in
  # examples/cairnloop_example/config/test.exs, so Oban.Testing works against
  # CairnloopExample.Repo here.
  #
  # This is the path-mismatch resolution documented in Plan 02's action note:
  # "preferred — move the test to examples/cairnloop_example/test/ if needed"
  # async: false — Oban.Testing asserts from the oban_jobs DB table; shared DB state.
  # :requires_postgres — needs CairnloopExample.Repo sandbox (Postgres on localhost:5433).
  # See CLAUDE.md REPO-UNAVAILABLE convention and seeds_test.exs pattern.
  use CairnloopExample.DataCase, async: false
  use Oban.Testing, repo: CairnloopExample.Repo

  @moduletag :requires_postgres

  alias Cairnloop.Channels.WidgetChannel

  describe "handle_in/3 new_message" do
    # T-28-02-07: No Application.get_env(:cairnloop, :oban_module) indirection is used
    # in widget_channel.ex (sealed-contract invariant). Oban.Testing intercepts
    # Oban.insert/1 in :manual mode so the job lands in the testing queue.
    test "reads conversation_id from socket.assigns and enqueues ProcessMessage with channel + conversation_id + content" do
      socket = %Phoenix.Socket{assigns: %{conversation_id: 42}}

      assert {:reply, :ok, ^socket} =
               WidgetChannel.handle_in("new_message", %{"content" => "hi"}, socket)

      assert_enqueued(
        worker: Cairnloop.Workers.ProcessMessage,
        args: %{channel: "widget", conversation_id: 42, content: "hi"}
      )
    end

    # T-28-02-01: Security test — conversation_id is NEVER read from the inbound payload.
    # A client that injects "conversation_id" => 999 in the payload must be silently
    # ignored; only socket.assigns[:conversation_id] (42) is trusted.
    test "never reads conversation_id from the inbound payload (T-M001 security)" do
      socket = %Phoenix.Socket{assigns: %{conversation_id: 42}}

      assert {:reply, :ok, ^socket} =
               WidgetChannel.handle_in(
                 "new_message",
                 %{"content" => "hi", "conversation_id" => 999},
                 socket
               )

      # The enqueued job must use the server-trust conversation_id (42), not the
      # client-supplied one (999).
      assert_enqueued(
        worker: Cairnloop.Workers.ProcessMessage,
        args: %{channel: "widget", conversation_id: 42, content: "hi"}
      )

      refute_enqueued(
        worker: Cairnloop.Workers.ProcessMessage,
        args: %{channel: "widget", conversation_id: 999, content: "hi"}
      )
    end
  end
end
