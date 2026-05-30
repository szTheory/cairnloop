defmodule Cairnloop.RouterOperationsTest do
  @moduledoc """
  Verifies that `Cairnloop.Router.cairnloop_operations/1` actually mounts the OPS
  endpoints into a host router (OPS-01, OPS-02). Prior to this, `HealthPlug`/`MetricsPlug`
  existed but were reachable from no router — see the vM015 milestone audit.
  """
  use ExUnit.Case, async: true
  import Plug.Test

  defmodule OpsRouter do
    use Phoenix.Router
    require Cairnloop.Router

    Cairnloop.Router.cairnloop_operations()
  end

  defmodule CustomOpsRouter do
    use Phoenix.Router
    require Cairnloop.Router

    Cairnloop.Router.cairnloop_operations(health_path: "/healthz", metrics_path: "/prom")
  end

  test "mounts /health and /metrics to the OPS plugs" do
    by_path = Map.new(OpsRouter.__routes__(), &{&1.path, &1.plug})

    assert by_path["/health"] == Cairnloop.Web.HealthPlug
    assert by_path["/metrics"] == Cairnloop.Web.MetricsPlug
  end

  test "honors custom paths" do
    paths = CustomOpsRouter.__routes__() |> Enum.map(& &1.path)

    assert "/healthz" in paths
    assert "/prom" in paths
  end

  test "GET /health dispatches to a 200 liveness response" do
    conn = OpsRouter.call(conn(:get, "/health"), OpsRouter.init([]))

    assert conn.status == 200
    assert conn.resp_body =~ "ok"
  end
end
