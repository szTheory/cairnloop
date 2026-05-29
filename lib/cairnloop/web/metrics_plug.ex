defmodule Cairnloop.Web.MetricsPlug do
  @moduledoc """
  A plug for exposing Prometheus metrics.

  If `TelemetryMetricsPrometheus.Core` is loaded, it responds with 200 and the Prometheus text payload.
  If not loaded, responds with a 501 Not Implemented.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: Keyword.get(opts, :prom_module, TelemetryMetricsPrometheus.Core)

  @impl true
  def call(conn, prom_module) do
    if Code.ensure_loaded?(prom_module) do
      metrics = prom_module.scrape()

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, metrics)
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(
        501,
        "Metrics not available. Add :telemetry_metrics_prometheus_core to your dependencies."
      )
    end
  end
end
