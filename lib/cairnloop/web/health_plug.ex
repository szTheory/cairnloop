defmodule Cairnloop.Web.HealthPlug do
  @moduledoc """
  A plug for liveness-only checks.

  Returns a 200 OK with `{"status": "ok"}` JSON payload. It does not check
  the database, Oban, pgvector, notifier, ingress auth, MCP tokens, or optional
  Scrypath automation. Use `mix cairnloop.doctor` for those readiness and trust
  diagnostics.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, ~s({"status": "ok"}))
  end
end
