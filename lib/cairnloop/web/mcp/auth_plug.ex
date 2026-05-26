defmodule Cairnloop.Web.MCP.AuthPlug do
  @moduledoc """
  Validates Bearer tokens for MCP.
  Does NOT halt the connection on failure. Simply assigns `conn.assigns.mcp_token` if valid.
  """
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Cairnloop.MCP.validate_token(token) do
          {:ok, token_record} ->
            assign(conn, :mcp_token, token_record)

          {:error, _} ->
            conn
        end

      _ ->
        conn
    end
  end
end
