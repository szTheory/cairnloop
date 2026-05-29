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
        %{inserted_at: ~U[2024-01-01 12:00:00Z], actor_id: "user_123", action: :approved_action, metadata: %{proposal_id: 1}},
        %{inserted_at: ~U[2024-01-02 12:00:00Z], actor_id: "system", action: :executed_tool, metadata: %{tool: "refund"}}
      ]
    end
  end

  setup %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
    conn = Plug.Test.init_test_session(conn, %{"host_user_id" => "operator_1"})
    %{conn: conn}
  end

  test "mounts and renders audit log empty state", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/audit-log")
    assert html =~ "Audit Log"
    assert html =~ "No audit events found"
  end

  test "renders events when auditor returns events", %{conn: conn} do
    Application.put_env(:cairnloop, :auditor, MockAuditor)
    
    {:ok, _view, html} = live(conn, "/audit-log")
    assert html =~ "user_123"
    assert html =~ "approved_action"
    assert html =~ "proposal_id: 1"
    
    assert html =~ "system"
    assert html =~ "executed_tool"
    assert html =~ "refund"
  end
end
