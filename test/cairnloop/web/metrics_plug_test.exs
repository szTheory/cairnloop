defmodule Cairnloop.Web.MetricsPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias Cairnloop.Web.MetricsPlug

  test "returns 200 and prometheus payload when dependency is loaded" do
    start_supervised!({TelemetryMetricsPrometheus.Core, metrics: []})

    conn = conn(:get, "/metrics")

    # TelemetryMetricsPrometheus.Core is loaded because it's in mix.exs
    opts = MetricsPlug.init([])
    conn = MetricsPlug.call(conn, opts)

    assert conn.status == 200
    assert is_binary(conn.resp_body)
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end

  test "returns 501 when dependency is not loaded" do
    conn = conn(:get, "/metrics")

    # Pass a module that definitely doesn't exist
    opts = MetricsPlug.init(prom_module: MissingPrometheusModule)
    conn = MetricsPlug.call(conn, opts)

    assert conn.status == 501

    assert conn.resp_body ==
             "Metrics not available. Add :telemetry_metrics_prometheus_core to your dependencies."

    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
