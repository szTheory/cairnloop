defmodule Cairnloop.Web.AuditLogLiveTest do
  use Cairnloop.ConnCase, async: false
  import Phoenix.LiveViewTest

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

    html = render_change(view, "filter", %{"action" => "approved"})

    assert html =~ "user_123"
    refute html =~ "Executed"
  end
end
