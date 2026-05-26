defmodule Cairnloop.Web.MCP.WellKnownPlug do
  @moduledoc """
  Serves RFC 9728 metadata for MCP authorization.
  """
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    servers = Application.get_env(:cairnloop, :mcp_authorization_servers, [])
    body = Jason.encode!(%{authorization_servers: servers})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
    |> halt()
  end
end
