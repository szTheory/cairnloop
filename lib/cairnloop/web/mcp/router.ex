defmodule Cairnloop.Web.MCP.Router do
  @moduledoc """
  Optional read-only MCP seam for Cairnloop-governed tools.

  Handles JSON-RPC 2.0 POST requests per MCP spec 2025-03-26:
  - `initialize` — capability negotiation; returns `protocolVersion` and `capabilities.tools`
  - `tools/list` — projects all configured governed tools through `ToolProjector.spec_to_mcp/1`
  - All other methods — returns JSON-RPC error `-32601 Method not found` (HTTP 200)

  ## Host integration

  Mount this Plug via `forward` in the host's Phoenix router:

      forward "/mcp", Cairnloop.Web.MCP.Router

  The host SHOULD add authentication middleware before the `forward` — Cairnloop does not
  prescribe an auth mechanism (D17-09). This Plug handles discovery only; no tool execution
  path is reachable (D17-06).

  ## JSON-RPC 2.0 semantics

  Per the JSON-RPC 2.0 spec, error responses carry HTTP status 200 — error information is
  in the response body's `error` field, not the HTTP status code (Pitfall 3 from RESEARCH.md).

  ## Security

  The `method` field from incoming JSON-RPC requests is NEVER converted to an atom —
  all dispatch uses string `case` pattern matching to prevent atom exhaustion (T-17-02-01,
  D-19 security posture). No Ecto queries, no `propose/3`, no `run/3` are reachable
  from this Plug.
  """

  @behaviour Plug

  import Plug.Conn

  @protocol_version "2025-03-26"
  @server_name "cairnloop-mcp"
  @server_version Mix.Project.config()[:version]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = req} <-
           Jason.decode(body) do
      handle_method(conn, id, method, Map.get(req, "params", %{}))
    else
      _ ->
        json_error(conn, nil, -32600, "Invalid Request")
    end
  end

  # ---------------------------------------------------------------------------
  # Method handlers
  # ---------------------------------------------------------------------------

  defp handle_method(conn, id, "initialize", _params) do
    result = %{
      "protocolVersion" => @protocol_version,
      "capabilities" => %{
        # Empty object = no listChanged — static read-only registry (RESEARCH.md A2)
        "tools" => %{}
      },
      "serverInfo" => %{"name" => @server_name, "version" => @server_version}
    }

    json_result(conn, id, result)
  end

  defp handle_method(conn, id, "tools/list", _params) do
    tools =
      Cairnloop.ToolRegistry.list_all_tools()
      |> Enum.map(&Cairnloop.Web.MCP.ToolProjector.spec_to_mcp/1)

    json_result(conn, id, %{"tools" => tools})
  end

  # Catch-all: tools/call, resources/list, and any other unsupported method returns -32601.
  # tools/call is explicitly deferred (D17-06) — no execution path is reachable from this Plug.
  defp handle_method(conn, id, _other, _params) do
    json_error(conn, id, -32601, "Method not found")
  end

  # ---------------------------------------------------------------------------
  # Response helpers
  # ---------------------------------------------------------------------------

  defp json_result(conn, id, result) do
    body = Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "result" => result})
    conn |> put_resp_content_type("application/json") |> send_resp(200, body)
  end

  defp json_error(conn, id, code, message) do
    # NOTE: HTTP 200 always for JSON-RPC errors — error info lives in the response body.
    # Returning HTTP 4xx would violate JSON-RPC 2.0 semantics (Pitfall 3).
    body =
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => %{"code" => code, "message" => message}
      })

    conn |> put_resp_content_type("application/json") |> send_resp(200, body)
  end
end
