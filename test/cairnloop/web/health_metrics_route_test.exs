defmodule Cairnloop.Web.HealthMetricsRouteTest do
  @moduledoc """
  Route-level coverage for the operations endpoints a host mounts via
  `Cairnloop.Router.cairnloop_operations/0` (OPS-01, OPS-02). Automates Phase 35 UAT
  checks 1 & 2 so no human has to curl the probes.

  Unlike `health_plug_test.exs` / `metrics_plug_test.exs` (which call the plugs directly),
  this exercises the actual macro hosts call, dispatched through a real router pipeline —
  proving `/health` and `/metrics` are wired at the documented paths.

  `/metrics` asserts the 200 path: `:telemetry_metrics_prometheus_core` is in this build's
  deps (optional deps are still compiled in the library's own build), so the live behavior
  is a 200 Prometheus scrape. The 501 fail-closed branch — a downstream host omitting the
  optional dep — is covered by `metrics_plug_test.exs` via an injected missing module.
  """
  use ExUnit.Case, async: false

  import Plug.Conn, only: [get_resp_header: 2]

  defmodule OpsRouter do
    use Phoenix.Router
    import Cairnloop.Router

    scope "/" do
      cairnloop_operations()
    end
  end

  defp call(method, path) do
    method
    |> Plug.Test.conn(path)
    |> OpsRouter.call(OpsRouter.init([]))
  end

  test "GET /health is wired and returns 200 with the liveness JSON payload" do
    conn = call(:get, "/health")

    assert conn.status == 200
    assert conn.resp_body == ~s({"status": "ok"})
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
  end

  test "GET /metrics is wired and returns 200 Prometheus text when the dep is present" do
    # MetricsPlug calls TelemetryMetricsPrometheus.Core.scrape/0, which needs the core
    # running (it reads its ETS-backed registry) — mirror metrics_plug_test.exs.
    start_supervised!({TelemetryMetricsPrometheus.Core, metrics: []})

    conn = call(:get, "/metrics")

    assert conn.status == 200
    assert is_binary(conn.resp_body)
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
