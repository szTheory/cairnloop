defmodule Cairnloop.Web.MCP.Router do
  @moduledoc """
  Optional read-only MCP seam for Cairnloop-governed tools.

  Handles JSON-RPC 2.0 POST requests per MCP spec 2025-11-05:
  - `initialize` — capability negotiation; returns `protocolVersion` and `capabilities.tools`
  - `tools/list` — projects all configured governed tools through `ToolProjector.spec_to_mcp/1`
  - All other methods — returns JSON-RPC error `-32601 Method not found` (HTTP 200)

  ## Host integration

  Mount this Plug via `forward` in the host's Phoenix router:

      forward "/mcp", Cairnloop.Web.MCP.Router

  The router validates Cairnloop MCP Bearer tokens through `Cairnloop.Web.MCP.AuthPlug`.
  Token-required methods fail closed before capabilities, tool metadata, or governed
  write surfaces are exposed. Well-known OAuth/resource metadata remains the public
  discovery surface.

  ## JSON-RPC 2.0 semantics

  Per the JSON-RPC 2.0 spec, error responses carry HTTP status 200 — error information is
  in the response body's `error` field, not the HTTP status code (Pitfall 3 from RESEARCH.md).

  ## Security

  The `method` field from incoming JSON-RPC requests is NEVER converted to an atom —
  all dispatch uses string `case` pattern matching to prevent atom exhaustion (T-17-02-01,
  D-19 security posture).

  Write actions (`tools/call`) are permitted for authenticated clients but are strictly
  routed through `Cairnloop.Governance.propose/3`. No direct tool execution occurs.
  """

  @behaviour Plug

  import Plug.Conn

  @protocol_version "2025-11-05"
  @server_name "cairnloop-mcp"
  @server_version Mix.Project.config()[:version]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    # Run AuthPlug before parsing JSON
    conn = Cairnloop.Web.MCP.AuthPlug.call(conn, [])

    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = req} <-
           Jason.decode(body) do
      if token_required_method?(method) and not Map.has_key?(conn.assigns, :mcp_token) do
        unauthorized(conn)
      else
        handle_method(conn, id, method, Map.get(req, "params", %{}))
      end
    else
      _ ->
        json_error(conn, nil, -32600, "Invalid Request")
    end
  end

  # ---------------------------------------------------------------------------
  # Method handlers
  # ---------------------------------------------------------------------------

  defp token_required_method?(method) when method in ["initialize", "tools/list", "tools/call"],
    do: true

  defp token_required_method?(_method), do: false

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

  defp handle_method(conn, id, "tools/call", %{"name" => tool_ref} = params) do
    if token = conn.assigns[:mcp_token] do
      actor_id = "mcp_token:#{token.id}"

      context = %{
        origin: :mcp,
        mcp_token_id: token.id,
        mcp_token_name: token.name,
        tool_params: Map.get(params, "arguments", %{})
      }

      case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
        {:ok, proposal} ->
          json_result(conn, id, %{
            "content" => [
              %{
                "type" => "text",
                "text" =>
                  "Proposal created successfully. Proposal ID: #{proposal.id}. Status: #{proposal.status}. The action will be executed asynchronously once approved by a host operator."
              }
            ],
            "isError" => false
          })

        {:blocked, :unsupported, _} ->
          json_error(conn, id, -32601, "Method not found")

        {:blocked, :needs_input, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          json_error(conn, id, -32602, "Invalid params: #{inspect(errors)}")

        {:blocked, outcome, _reason} ->
          json_result(conn, id, %{
            "content" => [
              %{
                "type" => "text",
                "text" => "Proposal blocked immediately. Outcome: #{outcome}."
              }
            ],
            "isError" => true
          })

        {:error, _changeset} ->
          json_error(conn, id, -32603, "Internal error: could not record proposal")
      end
    else
      unauthorized(conn)
    end
  end

  defp handle_method(conn, id, "tools/call", _params) do
    # Fallback for tools/call with missing "name" param
    if Map.has_key?(conn.assigns, :mcp_token) do
      json_error(conn, id, -32602, "Invalid params: missing 'name'")
    else
      unauthorized(conn)
    end
  end

  # Catch-all: resources/list, and any other unsupported method returns -32601.
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

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Bearer")
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
    |> halt()
  end
end
