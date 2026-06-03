defmodule CairnloopExampleWeb.OperatorAuthTest do
  # Pure plug/conn logic — no DB round-trip, so skip ConnCase's SQL sandbox.
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias CairnloopExampleWeb.OperatorAuth

  defp session_conn(session) do
    conn(:get, "/support")
    |> init_test_session(session)
  end

  describe "fetch_current_operator/2" do
    test "assigns the operator from the session when present" do
      conn =
        %{}
        |> session_conn()
        |> put_session("operator_id", "alice@acme.test")
        |> OperatorAuth.fetch_current_operator([])

      assert conn.assigns.current_operator == "alice@acme.test"
    end

    test "falls back to the demo operator when the session has none" do
      conn =
        %{}
        |> session_conn()
        |> OperatorAuth.fetch_current_operator([])

      assert conn.assigns.current_operator == "demo_operator"
    end
  end

  describe "cairnloop_session/1" do
    test "builds the dashboard session map from the resolved operator" do
      conn = assign(session_conn(%{}), :current_operator, "alice@acme.test")

      assert OperatorAuth.cairnloop_session(conn) == %{"host_user_id" => "alice@acme.test"}
    end

    test "stringifies non-string operator ids" do
      conn = assign(session_conn(%{}), :current_operator, 42)

      assert OperatorAuth.cairnloop_session(conn) == %{"host_user_id" => "42"}
    end
  end
end
