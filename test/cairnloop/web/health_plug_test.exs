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
end
