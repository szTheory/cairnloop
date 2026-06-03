defmodule Cairnloop.DashboardWiringTest do
  @moduledoc """
  Verify-before-publish guard for the host-mount surface.

  `Cairnloop.Router.cairnloop_dashboard/2` mounts every operator dashboard surface (inbox,
  conversations, knowledge base, settings, and the AUDIT-01 audit-log timeline); the example
  app dogfoods this exact macro. This test mounts the shipped macros into a real router and
  asserts the wiring, closing the two defect classes the vM015 milestone audit caught:

    * **the macro did not compile for adopters** — `cairnloop_dashboard/2` imported `live: 4`
      but its knowledge-base routes call `live/3`, so any adopter `use`-ing it failed to
      compile. `DashboardRouter` below `use`s the macro, so this whole file goes red if that
      regresses (it was never exercised before — the example app hand-copied the route list).
    * **a shipped surface was reachable from no route** — `/health` + `/metrics` were mounted
      nowhere at v0.2.0, and the example app dropped `/audit-log`. Asserted present below.

  Render/reachability of AuditLogLive itself (empty state, humanized rows, search, paging) is
  covered by `test/integration/audit_log_live_test.exs`; this test is the cheap, DB-free
  routing guard. It lives under `test/integration/` so the `mix test.integration` glob gates it
  in `release_gate` without an allow-list edit (it needs no Repo).
  """
  use ExUnit.Case, async: true
  import Plug.Test

  defmodule DashboardRouter do
    use Phoenix.Router
    require Cairnloop.Router

    scope "/" do
      Cairnloop.Router.cairnloop_dashboard("/support",
        session: %{"host_user_id" => "demo_operator"}
      )
    end

    scope "/" do
      Cairnloop.Router.cairnloop_operations()
    end
  end

  # A second mount with a custom live_session name + custom operations paths — proves the
  # collision-avoidance opt and that non-Cairnloop opts forward to live_session / the plugs.
  defmodule CustomRouter do
    use Phoenix.Router
    require Cairnloop.Router

    scope "/" do
      Cairnloop.Router.cairnloop_dashboard("/ops", live_session_name: :cairnloop_ops_dashboard)
    end

    scope "/" do
      Cairnloop.Router.cairnloop_operations(health_path: "/healthz", metrics_path: "/prom")
    end
  end

  # Map each path to the module that actually handles it: the LiveView module for `live` routes
  # (it lives in metadata, since `route.plug` is `Phoenix.LiveView.Plug`), or the plug itself for
  # `forward` routes.
  defp handler_by_path do
    Map.new(DashboardRouter.__routes__(), fn route ->
      handler =
        case route.metadata do
          %{phoenix_live_view: {live_view, _action, _opts, _meta}} -> live_view
          _ -> route.plug
        end

      {route.path, handler}
    end)
  end

  test "cairnloop_dashboard mounts the audit-log timeline at <path>/audit-log (AUDIT-01)" do
    assert handler_by_path()["/support/audit-log"] == Cairnloop.Web.AuditLogLive
  end

  test "cairnloop_dashboard mounts the full operator surface" do
    by_path = handler_by_path()

    # Cockpit Home is the task-oriented landing; the inbox moved to <path>/inbox.
    assert by_path["/support"] == Cairnloop.Web.HomeLive
    assert by_path["/support/inbox"] == Cairnloop.Web.InboxLive
    assert by_path["/support/knowledge-base"] == Cairnloop.Web.KnowledgeBaseLive.Index
    assert by_path["/support/knowledge-base/gaps"] == Cairnloop.Web.KnowledgeBaseLive.Gaps

    assert by_path["/support/knowledge-base/suggestions"] ==
             Cairnloop.Web.KnowledgeBaseLive.SuggestionReview

    assert by_path["/support/knowledge-base/:id/edit"] == Cairnloop.Web.KnowledgeBaseLive.Editor
    assert by_path["/support/settings"] == Cairnloop.Web.SettingsLive
    assert by_path["/support/:id"] == Cairnloop.Web.ConversationLive
  end

  test "cairnloop_operations mounts /health and /metrics alongside the dashboard" do
    by_path = handler_by_path()

    assert by_path["/health"] == Cairnloop.Web.HealthPlug
    assert by_path["/metrics"] == Cairnloop.Web.MetricsPlug
  end

  test "GET /health dispatches a 200 liveness response through the combined router" do
    conn = DashboardRouter.call(conn(:get, "/health"), DashboardRouter.init([]))

    assert conn.status == 200
    assert conn.resp_body =~ "ok"
  end

  test "cairnloop_dashboard honors a custom :live_session_name (multi-mount collision fix)" do
    live_session_names =
      CustomRouter.__routes__()
      |> Enum.flat_map(fn route ->
        case route.metadata do
          %{phoenix_live_view: {_lv, _action, _opts, %{name: name}}} -> [name]
          _ -> []
        end
      end)
      |> Enum.uniq()

    assert live_session_names == [:cairnloop_ops_dashboard]
  end

  test "cairnloop_operations forwards custom paths" do
    by_path =
      Map.new(CustomRouter.__routes__(), fn route -> {route.path, route.plug} end)

    assert by_path["/healthz"] == Cairnloop.Web.HealthPlug
    assert by_path["/prom"] == Cairnloop.Web.MetricsPlug
  end

  test "invalid :live_session_name raises a clear error at compile time (NimbleOptions)" do
    assert_raise NimbleOptions.ValidationError, fn ->
      Code.compile_string("""
      defmodule Cairnloop.DashboardWiringTest.BadRouter do
        use Phoenix.Router
        require Cairnloop.Router

        scope "/" do
          Cairnloop.Router.cairnloop_dashboard("/x", live_session_name: "not-an-atom")
        end
      end
      """)
    end
  end
end
