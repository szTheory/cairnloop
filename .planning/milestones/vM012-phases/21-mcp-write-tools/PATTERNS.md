# Phase 21: MCP Write Tools - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 1
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/mcp/router.ex` | router / plug | request-response | `lib/cairnloop/web/conversation_live.ex` (for Governance) & `lib/cairnloop/web/mcp/router.ex` (for JSON-RPC) | exact |

## Pattern Assignments

### `lib/cairnloop/web/mcp/router.ex` (router, request-response)

**Analog 1: `lib/cairnloop/web/conversation_live.ex` (Governance usage)**

**Core Propose Pattern** (lines 193-217):
```elixir
  def handle_event("execute_tool", %{"tool" => tool_ref} = params, socket) do
    actor_id = socket.assigns.conversation.host_user_id
    context = socket.assigns.host_context
    # Merge form params into context so Governance.validate/3 can call changeset/2 (D-27)
    context = Map.put(context, :tool_params, params["tool_params"] || %{})
    # D-07: thread server-trusted conversation_id into propose context (NOT from request params)
    context = Map.put(context, :conversation_id, socket.assigns.conversation.id)

    case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
      {:ok, proposal} ->
        {:noreply, put_flash(socket, :info, "Proposed — pending review. (##{proposal.id})")}

      {:blocked, outcome, reason} ->
        {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}

      {:error, _changeset} ->
        # Fail closed: never surface a raw changeset to the operator (CR-01)
        {:noreply,
         put_flash(
           socket,
           :error,
           "This action could not be recorded right now. Please try again."
         )}
    end
  end
```

**Analog 2: `lib/cairnloop/web/mcp/router.ex` (JSON-RPC handling)**

**JSON-RPC Response and Error format** (lines 80-92):
```elixir
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
```

## Expected MCP `tools/call` Implementation Structure

By combining these two analogs, the new `tools/call` handler in `lib/cairnloop/web/mcp/router.ex` should look like:

```elixir
  defp handle_method(conn, id, "tools/call", %{"name" => tool_ref} = params) do
    if token = conn.assigns[:mcp_token] do
      actor_id = "mcp_token:#{token.id}"
      
      # Prepare context explicitly per ACT-02
      context = %{
        origin: :mcp,
        mcp_token_id: token.id,
        mcp_token_name: token.name,
        tool_params: Map.get(params, "arguments", %{})
      }

      case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
        {:ok, proposal} ->
           # ACT-03: both new and already_existing fall through to this case via Governance mechanics
           json_result(conn, id, %{
             "content" => [
               %{
                 "type" => "text",
                 "text" => "Proposal created successfully. Proposal ID: #{proposal.id}. Status: pending_approval. The action will be executed asynchronously once approved by a host operator."
               }
             ],
             "isError" => false
           })

        {:blocked, :unsupported, :unknown_tool} ->
           json_error(conn, id, -32601, "Method not found")

        {:blocked, :needs_input, changeset} ->
           # Serialize changeset errors for invalid params
           errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
           json_error(conn, id, -32602, "Invalid params: #{inspect(errors)}")

        {:blocked, outcome, _reason} ->
           # Registered tool but blocked immediately by scope/policy
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
           json_error(conn, id, -32000, "Internal error: could not record proposal")
      end
    else
      conn
      |> put_resp_header("www-authenticate", "Bearer")
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
      |> halt()
    end
  end
```

## Shared Patterns

### Authentication/Authorization Guards
**Source:** `lib/cairnloop/web/mcp/router.ex`
**Apply to:** MCP method handlers
```elixir
    if Map.has_key?(conn.assigns, :mcp_token) do
      # perform authorized action
    else
      # return 401
```

### JSON-RPC Responses
**Source:** `lib/cairnloop/web/mcp/router.ex`
**Apply to:** All MCP endpoint handlers. Must return 200 OK for errors too.

## Metadata

**Analog search scope:** `lib/cairnloop/web/**/*.ex`
**Files scanned:** 1 main target and analog matches
**Pattern extraction date:** 2026-05-26
