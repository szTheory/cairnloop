defmodule Cairnloop.Web.MCP.RouterTest do
  @moduledoc """
  Headless (pure, no DB) proof of `Cairnloop.Web.MCP.Router` JSON-RPC 2.0 routing shapes.

  MCP-01 requirements verified here:
  - POST with method `tools/list` returns HTTP 200 and JSON-RPC 2.0 result envelope with a tools array.
  - POST with method `initialize` returns HTTP 200, protocolVersion "2025-03-26", and capabilities.tools.
  - POST with method `tools/call` returns HTTP 200 and JSON-RPC error with code -32601.
  - POST with an unknown method returns HTTP 200 and JSON-RPC error with code -32601.
  - POST with malformed JSON body returns HTTP 200 and JSON-RPC error with code -32600.
  - HTTP status is always 200 — JSON-RPC errors carry error info in the body, not HTTP status (Pitfall 3).
  """

  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  # ---------------------------------------------------------------------------
  # Env isolation: ensure :tools env has a known tool for list tests
  # ---------------------------------------------------------------------------

  setup do
    Application.put_env(:cairnloop, :tools, [Cairnloop.Tools.InternalNote])
    on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helper: build a test conn and call the Router
  # ---------------------------------------------------------------------------

  defp call(body_map) do
    conn(:post, "/", Jason.encode!(body_map))
    |> put_req_header("content-type", "application/json")
    |> Cairnloop.Web.MCP.Router.call([])
  end

  defp call_raw(raw_body) do
    conn(:post, "/", raw_body)
    |> put_req_header("content-type", "application/json")
    |> Cairnloop.Web.MCP.Router.call([])
  end

  # ---------------------------------------------------------------------------
  # tools/list
  # ---------------------------------------------------------------------------

  describe "tools/list" do
    test "returns JSON-RPC 2.0 result envelope with tools array" do
      conn =
        call(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/list",
          "params" => %{}
        })

      assert conn.status == 200

      assert %{"jsonrpc" => "2.0", "id" => 1, "result" => %{"tools" => tools}} =
               Jason.decode!(conn.resp_body)

      assert is_list(tools)
    end
  end

  # ---------------------------------------------------------------------------
  # initialize
  # ---------------------------------------------------------------------------

  describe "initialize" do
    test "returns protocolVersion 2025-03-26 and capabilities.tools" do
      conn =
        call(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{}
        })

      assert conn.status == 200

      assert %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "result" => %{
                 "protocolVersion" => protocol_version,
                 "capabilities" => %{"tools" => _tools_cap}
               }
             } = Jason.decode!(conn.resp_body)

      assert protocol_version == "2025-03-26"
    end
  end

  # ---------------------------------------------------------------------------
  # Unsupported methods — must return -32601, HTTP 200
  # ---------------------------------------------------------------------------

  describe "unsupported methods" do
    test "tools/call returns JSON-RPC -32601 error with HTTP 200" do
      conn =
        call(%{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "tools/call",
          "params" => %{"name" => "some_tool", "arguments" => %{}}
        })

      assert conn.status == 200

      assert %{"jsonrpc" => "2.0", "id" => 2, "error" => %{"code" => -32601}} =
               Jason.decode!(conn.resp_body)
    end

    test "unknown method returns JSON-RPC -32601 error with HTTP 200" do
      conn =
        call(%{
          "jsonrpc" => "2.0",
          "id" => 3,
          "method" => "unknown_method"
        })

      assert conn.status == 200

      assert %{"jsonrpc" => "2.0", "id" => 3, "error" => %{"code" => -32601}} =
               Jason.decode!(conn.resp_body)
    end
  end

  # ---------------------------------------------------------------------------
  # Malformed input — must return -32600, HTTP 200
  # ---------------------------------------------------------------------------

  describe "malformed input" do
    test "malformed JSON body returns JSON-RPC -32600 error with HTTP 200" do
      conn = call_raw("not valid json {{{")

      assert conn.status == 200

      assert %{"jsonrpc" => "2.0", "id" => nil, "error" => %{"code" => -32600}} =
               Jason.decode!(conn.resp_body)
    end
  end
end
