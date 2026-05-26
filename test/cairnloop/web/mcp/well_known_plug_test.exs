defmodule Cairnloop.Web.MCP.WellKnownPlugTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Cairnloop.Web.MCP.WellKnownPlug

  setup do
    servers = [
      %{
        "issuer" => "https://cairnloop.example.com/mcp",
        "authorization_endpoint" => "https://cairnloop.example.com/oauth/authorize",
        "token_endpoint" => "https://cairnloop.example.com/oauth/token"
      }
    ]

    Application.put_env(:cairnloop, :mcp_authorization_servers, servers)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :mcp_authorization_servers)
    end)

    :ok
  end

  test "returns authorization servers json and halts" do
    conn =
      conn(:get, "/.well-known/mcp-authorization")
      |> WellKnownPlug.call([])

    assert conn.status == 200
    assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
    assert conn.halted

    body = Jason.decode!(conn.resp_body)
    assert Map.has_key?(body, "authorization_servers")

    [server] = body["authorization_servers"]
    assert server["issuer"] == "https://cairnloop.example.com/mcp"
  end
end
