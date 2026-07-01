defmodule Cairnloop.Web.HealthPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias Cairnloop.Web.HealthPlug

  test "returns 200 with status ok" do
    conn = conn(:get, "/health")

    conn = HealthPlug.call(conn, HealthPlug.init([]))

    assert conn.status == 200
    assert conn.resp_body == ~s({"status": "ok"})
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
  end

  test "does not include readiness claims or dependency state" do
    conn =
      :get
      |> conn("/health")
      |> HealthPlug.call(HealthPlug.init([]))

    decoded = Jason.decode!(conn.resp_body)

    assert decoded == %{"status" => "ok"}

    refute Map.has_key?(decoded, "ready")
    refute Map.has_key?(decoded, "readiness")
    refute Map.has_key?(decoded, "database")
    refute Map.has_key?(decoded, "repo")
    refute Map.has_key?(decoded, "oban")
    refute Map.has_key?(decoded, "pgvector")
    refute Map.has_key?(decoded, "notifier")
    refute Map.has_key?(decoded, "ingress")
    refute Map.has_key?(decoded, "mcp")
    refute Map.has_key?(decoded, "scrypath")
  end
end
