<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None.

### the agent's Discretion
None.

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACT-02 | MCP clients invoke write-capable governed tools via `tools/call`; every call creates a `ToolProposal` via `Governance.propose/3` (never calls `Tool.run/3` directly) | `Governance.propose/3` verified to handle tool execution proposal without synchronous invocation. |
| ACT-03 | MCP write responses include `proposal_id` + `"pending_approval"` status; duplicate calls within the approval window return the existing proposal | `Governance.propose/3` verified to return `{:ok, existing_proposal}` on duplicate matching `idempotency_key`. |
</phase_requirements>

# Phase 21: MCP Write Tools - Research

**Researched:** 2026-05-26
**Domain:** Model Context Protocol (MCP) Server, JSON-RPC 2.0, Governance Proposal Pipeline
**Confidence:** HIGH

## Summary

This phase connects the Model Context Protocol (MCP) JSON-RPC API to the Cairnloop governance pipeline. Specifically, it enables remote MCP clients to request tool executions via the `tools/call` JSON-RPC method. Following Cairnloop's strict "proposal-first" architecture, the MCP router will never execute tools synchronously. Instead, it will map the request into `Cairnloop.Governance.propose/3`, delegating execution to the host's asynchronous approval and worker queues.

**Primary recommendation:** Replace the existing `tools/call` 404 handler in `Cairnloop.Web.MCP.Router` with a function that transforms the MCP context to call `Governance.propose/3` and maps the four possible return types (`:ok`, `:blocked` unrecoverable, `:blocked` recoverable, and `:error` changeset) into proper JSON-RPC or text responses.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| MCP Auth / Identity | API / Backend | — | Handled by `Cairnloop.Web.MCP.AuthPlug` and injected into `conn.assigns.mcp_token`. |
| Tool Invocation | API / Backend | — | Plugs and JSON-RPC router (`Cairnloop.Web.MCP.Router`). |
| Tool Deduplication | Database / Storage | API / Backend | `Governance.propose/3` handles idempotent proposal creation and unique constraint logic. |
| Tool Execution | Database / Storage | — | Handled strictly by asynchronous Oban workers (vM011), completely decoupled from the MCP synchronous lifecycle. |

## Project Constraints (from GEMINI.md)

- **Automated Discuss Phase:** Do not prompt the user with questions unless the decision is extremely high-impact or there is no clear technical winner. Synthesize one-shot, perfect recommendations weighing tradeoffs and following idiomatic Phoenix/Ecto/Plug patterns.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Plug/Phoenix Router | (existing) | JSON-RPC routing | Existing infrastructure in `Cairnloop.Web.MCP.Router`. |
| Ecto Changeset | (existing) | Error formatting | Serializing `{:error, changeset}` and `{:blocked, :needs_input, changeset}` for invalid MCP inputs. |

## Architecture Patterns

### System Architecture Diagram

```mermaid
graph TD
    Client[MCP Client] -->|tools/call| Router[Cairnloop.Web.MCP.Router]
    Router -->|conn.assigns.mcp_token| AuthCheck{Is Authenticated?}
    AuthCheck -->|No| 401[HTTP 401 Unauthorized]
    AuthCheck -->|Yes| MapContext[Map mcp_token to context]
    MapContext --> Propose[Governance.propose/3]
    Propose -->|{:ok, proposal}| Success[MCP Success: isError: false]
    Propose -->|{:blocked, :unsupported, _}| Err1[MCP Error: -32601 Method Not Found]
    Propose -->|{:blocked, :needs_input, cs}| Err2[MCP Error: -32602 Invalid Params]
    Propose -->|{:blocked, outcome, reason}| Err3[MCP Success: isError: true]
    Propose -->|{:error, cs}| Err4[MCP Error: -32603 Internal Error]
```

### Pattern 1: Idempotency by default
**What:** The underlying `Governance.propose/3` API natively supports idempotency based on the tool arguments, user context, and `tool_ref`.
**When to use:** In MCP's `tools/call`, no extra check needs to be written. The router blindly invokes `propose/3`. If the caller submits the same identical tool call, `propose/3` returns the existing `{:ok, proposal}`, which correctly generates the exact same MCP response.
**Example:**
```elixir
# Router does not need to handle {:error, :already_exists, ...}
# because propose/3 returns {:ok, existing_proposal} on duplicates.
case Cairnloop.Governance.propose(tool_name, actor_id, context) do
  {:ok, proposal} ->
    json_result(conn, id, %{
      "content" => [%{"type" => "text", "text" => "Proposal created successfully. Proposal ID: #{proposal.id}. Status: pending_approval..."}],
      "isError" => false
    })
  # ...
end
```

### Pattern 2: Context mapping for MCP identities
**What:** The `Governance.propose/3` requires an `actor_id` string and a `context` map. For UI operations, this is the user. For MCP operations, this is the token.
**When to use:** Before delegating to `propose/3` in the `tools/call` handler.
**Example:**
```elixir
actor_id = "mcp_token:#{token.id}"
context = %{
  origin: :mcp,
  mcp_token_id: token.id,
  mcp_token_name: token.name,
  tool_params: params["arguments"] || %{}
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deduplication | Custom caching or state logic in `MCP.Router` | `Governance.propose/3` | Core governance logic relies on cryptographic hashing of the payload and Ecto unique constraints. |
| Tool Execution | `Tool.run/3` inside the MCP handler | `Governance.propose/3` | System rules rigidly mandate async approval loops via Oban for write operations. |

## Runtime State Inventory
Step 2.5: SKIPPED (not a rename/refactor/migration phase)

## Common Pitfalls

### Pitfall 1: Returning HTTP 400 or 500 for JSON-RPC Errors
**What goes wrong:** `Plug` attempts to return an HTTP status code for business logic failures, breaking MCP clients.
**Why it happens:** Standard REST APIs map validation errors to `HTTP 422` or `400`.
**How to avoid:** Ensure all responses strictly use HTTP `200` with the `error` or `result` JSON-RPC formatting (handled by `json_error/4` and `json_result/3`).

### Pitfall 2: Expecting `{:error, :already_exists, ...}` from `propose/3`
**What goes wrong:** The DECISION.md hints at pattern matching `{:error, :already_exists, proposal}`.
**Why it happens:** Assumption that `Ecto` unique constraints bubble up as `already_exists`.
**How to avoid:** `Governance.propose/3` internally catches the unique constraint violation and returns `{:ok, existing_proposal}`. The router simply treats `{:ok, proposal}` as success in all cases.

### Pitfall 3: Failing to Serialize Ecto Changeset Errors for `-32602`
**What goes wrong:** Returning raw Ecto changeset structs to MCP clients on `{:blocked, :needs_input, changeset}`.
**Why it happens:** JSON-RPC requires a string message or simple JSON for error data.
**How to avoid:** Map the changeset errors via `Cairnloop.Governance` utilities or a custom helper to provide a clear string to the LLM (e.g. `%{field => ["is invalid"]}`).

## Code Examples

Verified patterns from official sources:

### MCP `tools/call` Implementation
```elixir
defp handle_method(conn, id, "tools/call", params) do
  if token = conn.assigns[:mcp_token] do
    tool_name = params["name"]
    actor_id = "mcp_token:#{token.id}"
    context = %{
      origin: :mcp,
      mcp_token_id: token.id,
      mcp_token_name: token.name,
      tool_params: params["arguments"] || %{}
    }

    case Cairnloop.Governance.propose(tool_name, actor_id, context) do
      {:ok, proposal} ->
        # Returns the same thing for new and duplicate proposals
        text = "Proposal created successfully. Proposal ID: #{proposal.id}. Status: pending_approval. The action will be executed asynchronously once approved by a host operator."
        json_result(conn, id, %{"content" => [%{"type" => "text", "text" => text}], "isError" => false})

      {:blocked, :unsupported, _} ->
        json_error(conn, id, -32601, "Method not found: #{tool_name}")

      {:blocked, :needs_input, changeset} ->
        # Format the changeset errors cleanly for the LLM
        errors = format_changeset_errors(changeset)
        json_error(conn, id, -32602, "Invalid params: #{errors}")

      {:blocked, outcome, reason} ->
        # Tool exists but immediately rejected by policy/scope. Valid MCP response with isError: true.
        text = "Action blocked. Outcome: #{outcome}. Reason: #{inspect(reason)}"
        json_result(conn, id, %{"content" => [%{"type" => "text", "text" => text}], "isError" => true})
        
      {:error, _changeset} ->
        json_error(conn, id, -32603, "Internal error during proposal creation")
    end
  else
    # Handled by fallback in original file, but logic ensures 401
    conn
    |> put_resp_header("www-authenticate", "Bearer")
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
    |> halt()
  end
end

defp format_changeset_errors(changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end)
  |> inspect()
end
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Governance.propose/3` returns `{:error, _changeset}` for database failures | Code Examples | Minimal; Ecto standard pattern, handler catches it and returns internal error. |

## Open Questions (RESOLVED)

None. The `Governance` facade is fully featured and handles the requirements precisely.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` / `test/test_helper.exs` |
| Quick run command | `mix test test/cairnloop/web/mcp/router_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACT-02 | `tools/call` maps to `Governance.propose/3` and returns `isError: false` text block | unit | `mix test test/cairnloop/web/mcp/router_test.exs` | ✅ Wave 0 |
| ACT-03 | Duplicate `tools/call` returns the same success block | unit | `mix test test/cairnloop/web/mcp/router_test.exs` | ✅ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/mcp/router_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- None — existing test infrastructure covers all phase requirements.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | AuthPlug `mcp_token` verification |
| V3 Session Management | no | — |
| V4 Access Control | yes | `Governance.propose/3` policy/scope validation |
| V5 Input Validation | yes | `changeset/2` validations inside `Governance` |
| V6 Cryptography | no | — |

### Known Threat Patterns for Elixir / MCP

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Atom Exhaustion | Denial of Service | Pass the `tool_name` parameter directly to `Governance.propose/3` as a String. DO NOT use `String.to_existing_atom` or similar on user input. `ToolRegistry` relies on matching strings against a pre-loaded list. |
| Duplicate Execution | Tampering | Delegate idempotency to `Governance.propose/3` and do not invoke `Tool.run/3` inline. |

## Sources

### Primary (HIGH confidence)
- Codebase context (`lib/cairnloop/governance.ex`, `lib/cairnloop/web/mcp/router.ex`) - Verified the return paths of `Governance.propose/3` and JSON-RPC router structure.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Core Elixir/Phoenix Plug architecture.
- Architecture: HIGH - Fully adheres to `Governance.propose/3` constraints.
- Pitfalls: HIGH - Accurate understanding of the system's duplicate proposal strategy.

**Research date:** 2026-05-26
**Valid until:** 2026-06-26