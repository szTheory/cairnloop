defmodule Cairnloop.Web.MCP.RouterTest do
  @moduledoc """
  Integration (DB-backed) proof of `Cairnloop.Web.MCP.Router` JSON-RPC 2.0 routing shapes.

  MCP-01 requirements verified here:
  - POST with method `tools/list` returns HTTP 200 and JSON-RPC 2.0 result envelope with a tools array.
  - POST with method `initialize` returns HTTP 200, protocolVersion "2025-11-05", and capabilities.tools.
  - POST with an unknown method returns HTTP 200 and JSON-RPC error with code -32601.
  - POST with malformed JSON body returns HTTP 200 and JSON-RPC error with code -32600.
  - HTTP status is always 200 — JSON-RPC errors carry error info in the body, not HTTP status (Pitfall 3).

  MCP-03 requirements verified here:
  - tools/call with valid token and tool returns 200 OK and success block with proposal_id.
  - tools/call identically duplicated returns the exact same success block without error.
  - tools/call with missing token returns 401 Unauthorized.
  - tools/call with invalid arguments returns JSON-RPC error -32602.
  - tools/call with unsupported tool returns JSON-RPC error -32601.
  """

  use Cairnloop.ConnCase, async: true

  # ---------------------------------------------------------------------------
  # Env isolation: ensure :tools env has a known tool for list tests
  # ---------------------------------------------------------------------------

  setup do
    Application.put_env(:cairnloop, :tools, [Cairnloop.Tools.InternalNote])
    on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)

    {:ok, _token, raw_token} = Cairnloop.MCP.issue_token(%{name: "Test Token"})
    %{raw_token: raw_token}
  end

  # ---------------------------------------------------------------------------
  # Private helper: build a test conn and call the Router
  # ---------------------------------------------------------------------------

  defp call(_conn, body_map, raw_token) do
    conn =
      Plug.Test.conn(:post, "/", Jason.encode!(body_map))
      |> put_req_header("content-type", "application/json")

    conn =
      if raw_token do
        put_req_header(conn, "authorization", "Bearer #{raw_token}")
      else
        conn
      end

    Cairnloop.Web.MCP.Router.call(conn, [])
  end

  defp call_raw(_conn, raw_body) do
    Plug.Test.conn(:post, "/", raw_body)
    |> put_req_header("content-type", "application/json")
    |> Cairnloop.Web.MCP.Router.call([])
  end

  defp assert_unauthorized(resp) do
    assert resp.status == 401
    assert {"www-authenticate", "Bearer"} in resp.resp_headers

    body = Jason.decode!(resp.resp_body)
    assert body["error"] == "Unauthorized"
    refute Map.has_key?(body, "result")
    refute inspect(body) =~ "capabilities"
    refute inspect(body) =~ "tools"
    body
  end

  defp initialize_request do
    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{}
    }
  end

  defp tools_list_request do
    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list",
      "params" => %{}
    }
  end

  # ---------------------------------------------------------------------------
  # tools/list
  # ---------------------------------------------------------------------------

  describe "tools/list" do
    test "missing token returns 401 without exposing tool metadata", %{conn: conn} do
      conn = call(conn, tools_list_request(), nil)

      assert_unauthorized(conn)
    end

    test "invalid token returns 401 without exposing tool metadata", %{conn: conn} do
      conn = call(conn, tools_list_request(), "invalid-token")

      assert_unauthorized(conn)
    end

    test "returns JSON-RPC 2.0 result envelope with tools array", %{
      conn: conn,
      raw_token: raw_token
    } do
      conn = call(conn, tools_list_request(), raw_token)

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
    test "missing token returns 401 without exposing capabilities", %{conn: conn} do
      conn = call(conn, initialize_request(), nil)

      assert_unauthorized(conn)
    end

    test "invalid token returns 401 without exposing capabilities", %{conn: conn} do
      conn = call(conn, initialize_request(), "invalid-token")

      assert_unauthorized(conn)
    end

    test "returns protocolVersion 2025-11-05 and capabilities.tools", %{
      conn: conn,
      raw_token: raw_token
    } do
      conn = call(conn, initialize_request(), raw_token)

      assert conn.status == 200

      assert %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "result" => %{
                 "protocolVersion" => protocol_version,
                 "capabilities" => %{"tools" => _tools_cap}
               }
             } = Jason.decode!(conn.resp_body)

      assert protocol_version == "2025-11-05"
    end
  end

  # ---------------------------------------------------------------------------
  # tools/call
  # ---------------------------------------------------------------------------

  describe "tools/call" do
    test "valid token and valid tool name returns success block with proposal_id", %{
      conn: conn,
      raw_token: raw_token
    } do
      req_body = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => Atom.to_string(Cairnloop.Tools.InternalNote),
          "arguments" => %{
            "conversation_id" => "conv_123",
            "content" => "test note"
          }
        }
      }

      resp = call(conn, req_body, raw_token)

      assert resp.status == 200
      body = Jason.decode!(resp.resp_body)
      assert body["jsonrpc"] == "2.0"
      assert body["id"] == 2

      result = body["result"]
      assert result["isError"] == false
      assert [%{"type" => "text", "text" => text}] = result["content"]
      assert text =~ "Proposal created"
      assert text =~ "Proposal ID:"
      assert text =~ "Status: proposed"
    end

    test "identically duplicated call returns the exact same success block", %{
      conn: conn,
      raw_token: raw_token
    } do
      req_body = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => Atom.to_string(Cairnloop.Tools.InternalNote),
          "arguments" => %{
            "conversation_id" => "conv_123",
            "content" => "duplicated note"
          }
        }
      }

      resp1 = call(conn, req_body, raw_token)
      body1 = Jason.decode!(resp1.resp_body)
      assert body1["result"]["isError"] == false

      resp2 = call(conn, req_body, raw_token)
      body2 = Jason.decode!(resp2.resp_body)

      assert body1["result"] == body2["result"]
    end

    test "missing token returns 401 Unauthorized", %{conn: conn} do
      req_body = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => Atom.to_string(Cairnloop.Tools.InternalNote),
          "arguments" => %{
            "conversation_id" => "conv_123",
            "content" => "test"
          }
        }
      }

      resp = call(conn, req_body, nil)

      assert resp.status == 401
      assert {"www-authenticate", "Bearer"} in resp.resp_headers

      body = Jason.decode!(resp.resp_body)
      assert body["error"] == "Unauthorized"
    end

    test "invalid token returns 401 before governed write validation", %{conn: conn} do
      req_body = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => Atom.to_string(Cairnloop.Tools.InternalNote),
          "arguments" => %{}
        }
      }

      resp = call(conn, req_body, "invalid-token")

      assert_unauthorized(resp)
    end

    test "invalid arguments returns JSON-RPC error -32602", %{conn: conn, raw_token: raw_token} do
      req_body = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => Atom.to_string(Cairnloop.Tools.InternalNote),
          # missing required fields
          "arguments" => %{}
        }
      }

      resp = call(conn, req_body, raw_token)

      assert resp.status == 200
      body = Jason.decode!(resp.resp_body)

      assert %{"code" => -32602, "message" => msg} = body["error"]
      assert is_binary(msg)
      assert msg =~ "Invalid params"
    end

    test "unsupported tool name returns JSON-RPC error -32601", %{
      conn: conn,
      raw_token: raw_token
    } do
      req_body = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{
          "name" => "NonExistentTool",
          "arguments" => %{}
        }
      }

      resp = call(conn, req_body, raw_token)

      assert resp.status == 200
      body = Jason.decode!(resp.resp_body)

      assert %{"code" => -32601} = body["error"]
    end
  end

  # ---------------------------------------------------------------------------
  # Unsupported methods / malformed — must return errors with HTTP 200
  # ---------------------------------------------------------------------------

  describe "unsupported methods & malformed" do
    test "unknown method returns JSON-RPC -32601 error with HTTP 200", %{
      conn: conn,
      raw_token: raw_token
    } do
      conn =
        call(
          conn,
          %{
            "jsonrpc" => "2.0",
            "id" => 3,
            "method" => "unknown_method"
          },
          raw_token
        )

      assert conn.status == 200

      assert %{"jsonrpc" => "2.0", "id" => 3, "error" => %{"code" => -32601}} =
               Jason.decode!(conn.resp_body)
    end

    test "malformed JSON body returns JSON-RPC -32600 error with HTTP 200", %{conn: conn} do
      conn = call_raw(conn, "not valid json {{{")

      assert conn.status == 200

      assert %{"jsonrpc" => "2.0", "id" => nil, "error" => %{"code" => -32600}} =
               Jason.decode!(conn.resp_body)
    end
  end
end
