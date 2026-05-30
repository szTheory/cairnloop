defmodule Cairnloop.Integration.AuditLogLiveTest do
  @moduledoc """
  Integration coverage for the operator Audit Log (AUDIT-01) — Phase 35 UAT check 3.

  Mounts `Cairnloop.Web.AuditLogLive` for real via `Phoenix.LiveViewTest` and asserts the
  automatable behavior:
  - empty state, humanized rendering, search, and action-filter (against a mock auditor);
  - the real default `Cairnloop.Auditor.Governance` surfaces durable `ToolActionEvent` rows
    end-to-end (the "host-supplied auditor lists returned events" UAT clause);
  - the "Load more" affordance pages the timeline once the first page (50) is full.

  Relocated here from `test/cairnloop/web/` so the DB-backed `integration` CI job actually
  runs it — it `use`s `Cairnloop.ConnCase` (tagged `:integration`, needs the Repo boot), so
  the headless job excluded it and the integration job's `test/integration` glob never
  reached its old path. It ran in no CI job before.
  """
  use Cairnloop.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Cairnloop.Fixtures

  defmodule MockAuditor do
    @behaviour Cairnloop.Auditor

    @impl true
    def audit(multi, _action, _actor, _metadata), do: multi

    @impl true
    def list_events(_opts) do
      [
        %{
          inserted_at: ~U[2024-01-01 12:00:00Z],
          actor_id: "user_123",
          action: :approved,
          reason: "approved by supervisor",
          metadata: %{proposal_id: 1}
        },
        %{
          inserted_at: ~U[2024-01-02 12:00:00Z],
          actor_id: nil,
          action: :execution_succeeded,
          reason: nil,
          metadata: %{tool: "refund"}
        }
      ]
    end
  end

  setup %{conn: conn} do
    # Default to NoOp so a test never accidentally hits the governance-backed default.
    Application.put_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
    on_exit(fn -> Application.delete_env(:cairnloop, :auditor) end)
    conn = Plug.Test.init_test_session(conn, %{"host_user_id" => "operator_1"})
    %{conn: conn}
  end

  test "mounts and renders the empty state", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/audit-log")
    assert html =~ "Audit Log"
    assert html =~ "No audit events found"
  end

  test "renders humanized events from the configured auditor", %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, MockAuditor)

    {:ok, _view, html} = live(conn, "/audit-log")

    # actor: present binary passes through; nil reads as "System"
    assert html =~ "user_123"
    assert html =~ "System"

    # action atoms are humanized (no raw atom / inspect output)
    assert html =~ "Approved"
    assert html =~ "Executed"
    refute html =~ "execution_succeeded"

    # reason passes through; metadata only behind the details expander, humanized
    assert html =~ "approved by supervisor"
    assert html =~ "View details"
    assert html =~ "Proposal id"
    assert html =~ "refund"
    # never raw Elixir map syntax to operators
    refute html =~ "%{"
  end

  test "search narrows the visible rows", %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, MockAuditor)
    {:ok, view, _html} = live(conn, "/audit-log")

    html = render_change(view, "search", %{"query" => "refund"})

    assert html =~ "Executed"
    refute html =~ "user_123"
  end

  test "action filter narrows the visible rows", %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, MockAuditor)
    {:ok, view, _html} = live(conn, "/audit-log")

    # The <select> submits the humanized label as the option value (no raw atom leaks).
    html = render_change(view, "filter", %{"action" => "Approved"})

    assert html =~ "user_123"
    refute html =~ "Executed"
  end

  test "the default Governance auditor surfaces durable ToolActionEvent rows end-to-end",
       %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, Cairnloop.Auditor.Governance)

    proposal = proposal_fixture()

    action_event_fixture(proposal, %{
      event_type: :approved,
      actor_id: "supervisor_9",
      reason: "Looks correct, approving the refund.",
      metadata: %{"order_id" => "A-100"}
    })

    {:ok, _view, html} = live(conn, "/audit-log")

    refute html =~ "No audit events found"
    assert html =~ "supervisor_9"
    assert html =~ "Looks correct, approving the refund."
    # humanized action label, not the raw :approved atom
    assert html =~ "Approved"
    # metadata humanized behind the expander, never raw map syntax
    assert html =~ "View details"
    assert html =~ "A-100"
    refute html =~ "%{"
  end

  test "Load more pages the timeline once the first page is full", %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, Cairnloop.Auditor.Governance)

    proposal = proposal_fixture()
    # 51 events: the first page (limit 50) is full → maybe_more? true → button shows.
    # One "Load more" (limit 100) loads all 51 → maybe_more? false → button gone.
    for n <- 1..51 do
      action_event_fixture(proposal, %{actor_id: "actor_#{n}"})
    end

    {:ok, view, _html} = live(conn, "/audit-log")
    assert has_element?(view, "button[phx-click='load_more']")

    html = view |> element("button[phx-click='load_more']") |> render_click()
    refute html =~ ~s(phx-click="load_more")
  end
end
