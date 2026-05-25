# Phase 17: Optional Evidence Lane & Read-Only MCP Seam — Research

**Researched:** 2026-05-25
**Domain:** Elixir :telemetry / OpenInference trace events + MCP JSON-RPC 2.0 Plug adapter
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D17-01 [OWNER-CONFIRMED]:** New `Cairnloop.Governance.Telemetry.Traces` submodule with OI-conformant event namespace `[:cairnloop, :governance, :trace, ...]` — SEPARATE from bounded-metrics module `Cairnloop.Governance.Telemetry`.
- **D17-02:** OI trace events carry span kind (`:tool`/`:guardrail`/`:agent`), `tool_proposal_id`, `actor_id`, `policy_snapshot_ref`, `decided_by`, `attempt`. No payload content in trace events.
- **D17-03:** Zero explicit Scoria dependency — host opts in via `:telemetry.attach_many`.
- **D17-04:** Trace events emitted AFTER successful transitions, after ToolActionEvent co-commits.
- **D17-05:** Fail-closed if no handler attached (`:telemetry` drops events with no handler).
- **D17-06 [OWNER-CONFIRMED]:** `tools/list` ONLY — no `tools/call`, no `:auto` execution path.
- **D17-07:** Spec → MCP tool definition mapping: `title`, `description`, module name as `name`, `changeset/2` embedded schema → `inputSchema`, `x-cairnloop-*` extension fields for `risk_tier` + `approval_mode`.
- **D17-08:** Optional `Cairnloop.Web.MCP.Router` Plug — POST / handles `tools/list` and `initialize`, all other methods return JSON-RPC error. Host mounts via `forward`.
- **D17-09:** Auth through existing contract — host guards with their own auth middleware.
- **D17-10:** `Cairnloop.Tools.InternalNote` is the concrete proof artifact for MCP projection test.
- **D17-11:** No new Ecto migrations, schemas, or approval-lane modifications.
- **D17-12:** Both adapters optional — not supervised by `Cairnloop.Application`.
- **D17-13:** Proof posture advisory only — attach handler + assert OI fields; assert `tools/list` JSON-RPC response shape.

### Claude's Discretion

- Exact module names, JSON-RPC framing details, OI trace event name spellings under `[:cairnloop, :governance, :trace, ...]`, exact `x-cairnloop-*` field names, how `changeset/2` schema is projected to JSON Schema (reflection vs. explicit), and whether `initialize` capability response is minimal or fuller.
- Whether `Cairnloop.Governance.Telemetry.Traces` lives as a submodule or parallel sibling module — as long as it has its own event namespace that does NOT share names with the bounded-metrics module.
- Whether InternalNote's `inputSchema` projection uses Ecto reflection or an explicit `json_schema` declaration.

### Deferred Ideas (OUT OF SCOPE)

- `tools/call` for `:read_only` tier through MCP (requires `:auto` execution path; future MCP-03).
- MCP write operations through the governed-action pipeline.
- Explicit `Cairnloop.Evidence` behaviour / callback protocol.
- Full MCP server capabilities (`resources/*`, `prompts/*`, streaming, session management).
- Scoria operator dashboard / LiveView integration.
- `:auto` execution path for non-approval tools.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MCP-01 | Core governed-tool metadata can map cleanly to an optional read-only MCP seam without changing the internal approval and execution model | D17-07 Spec→MCP mapping is a pure total function over existing structs; D17-06 tools/list-only; D17-08 optional Plug; D17-09 host-owned auth; Ecto reflection via `__changeset__/0` gives inputSchema derivation without any model change |

</phase_requirements>

---

## Summary

Phase 17 wires two optional read-side adapters over the sealed vM011 governance lane. Neither adapter changes any durable record, schema, or approval path — they are pure read-side projections and observability hooks.

**Evidence lane (M011-S05-01):** A new `Cairnloop.Governance.Telemetry.Traces` module emits OpenInference-conformant `:telemetry` events alongside the existing `ToolActionEvent` co-commits. The events carry attribution references (not content) enabling Scoria or any OI-compatible system to reconstruct a span tree from the durable record trail. The module is structurally identical to the existing `Cairnloop.Governance.Telemetry` (bounded-metrics) module — `@events` allow-list + guard-clause no-op + `normalize_*` helpers — but uses a completely different event namespace and richer attribution payload.

**MCP seam (M011-S05-02):** A new `Cairnloop.Web.MCP.Router` Plug handles JSON-RPC 2.0 POST requests and responds to `tools/list` and `initialize` only. The core data transform is a pure `Spec → map` function over `Cairnloop.Tool.Spec` structs from the tool registry. `inputSchema` derivation is done via Ecto reflection on `changeset/2` — calling `changeset/2` with empty attrs yields `cs.required` and `cs.types`, which map cleanly to a JSON Schema `object`. `Plug` 1.19.1 is already a transitive dependency; no new packages are needed.

**Primary recommendation:** Implement both adapters as thin modules over existing seams. Use Ecto reflection (`__changeset__/0` + `changeset/2` with empty attrs) for `inputSchema` — this approach is proven in the codebase (`conversation_live.ex` already uses `__schema__(:fields)` for form generation) and avoids requiring tool authors to implement a separate `json_schema/0` callback. Total new code volume is small: ~80–100 lines per module plus tests.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| OI trace event emission | API / Backend (`Cairnloop.Governance` + workers) | — | Events shadow ToolActionEvent co-commits; emitted from same call sites in governance.ex + ToolExecutionWorker + ApprovalResumeWorker |
| Trace event namespace definition | Library module (`Governance.Telemetry.Traces`) | — | Mirrors Governance.Telemetry structural pattern; defines @events allow-list + emit/3 guard-clause |
| Spec → MCP tool definition transform | Pure library function | — | Total function over struct fields; no DB, no side effects |
| inputSchema derivation | Pure library function | — | Ecto reflection via `changeset/2` + empty attrs; all data available at module-load time |
| JSON-RPC 2.0 framing (tools/list, initialize) | Plug layer (`Cairnloop.Web.MCP.Router`) | — | Stateless request/response; reads from ToolRegistry; no auth prescribed |
| Auth enforcement | Host middleware (before the Plug) | — | D17-09: host uses their own auth pipeline; `forward "/mcp", Router` goes after auth plug |
| Test: trace emission proof | Headless ExUnit (`:telemetry.attach` pattern) | Integration (for full proposal→execution cycle) | Advisory proof only per D17-13; headless is sufficient for field assertion |
| Test: MCP Plug proof | Headless ExUnit (`Plug.Test.conn`) | — | Pure data proof; no HTTP integration test needed per D17-13 |

---

## Standard Stack

### Core

No new packages are required. All dependencies are already present:

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| `:telemetry` (Elixir) | ~> 1.4 (locked in mix.lock) | Emit OI trace events; `attach_many`, `execute/3`, guard-clause no-op | [VERIFIED: mix.lock] |
| `Plug` | 1.19.1 (locked) | `Plug.Conn`, `Plug.Router` (or plain `@behaviour Plug`) for MCP Plug | [VERIFIED: mix.lock] |
| `Jason` | ~> 1.2 | JSON encode/decode for JSON-RPC 2.0 body | [VERIFIED: mix.exs] |
| `Ecto` (embedded schema) | via `ecto_sql ~> 3.10` | `__changeset__/0` + `changeset/2` for inputSchema derivation | [VERIFIED: mix.exs] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Plug.Test` | (part of Plug) | Build test Conns for headless Plug tests | MCP Router unit tests |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Ecto reflection for inputSchema | Explicit `json_schema/0` callback on tool module | Reflection is zero-friction for tool authors; explicit callback gives more control but adds authoring surface area. Reflection wins for the "advisory proof only" bar of Phase 17 |
| Plain `@behaviour Plug` for MCP Router | `Plug.Router` macro | `Plug.Router` adds method/path routing sugar but MCP has only one endpoint (POST /); plain `@behaviour Plug` with a `case` on method is simpler and more readable |

**Installation:** No new deps. Phase 17 is entirely internal library code.

---

## Package Legitimacy Audit

> Phase 17 installs ZERO external packages. All required functionality (`:telemetry`, `Plug`, `Jason`, `Ecto`) is already declared in `mix.exs` and locked in `mix.lock`.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*No package legitimacy audit required — no new installs.*

---

## Architecture Patterns

### System Architecture Diagram

```
Sealed governance lane (Phases 13–16)
  Cairnloop.Governance / Workers
    ↓ (after successful ToolActionEvent co-commit)
    ↓
    ├─► Cairnloop.Governance.Telemetry.Traces.emit/3
    │     [:cairnloop, :governance, :trace, <event>]
    │     measurements: %{count: 1}
    │     metadata: %{
    │       "openinference.span.kind" => "GUARDRAIL"|"TOOL",
    │       tool_proposal_id: id,
    │       actor_id: actor_id,
    │       policy_snapshot_ref: proposal_id,   ← reference, not content
    │       decided_by: decided_by | nil,
    │       attempt: attempt | nil
    │     }
    │     → :telemetry dispatches to zero-or-more attached handlers
    │       (Scoria.attach_cairnloop_governance_traces/0 calls :telemetry.attach_many)
    │       (no handler → silent no-op, D17-05)
    │
    └─► [read-only path, no writes]
        Cairnloop.ToolRegistry.get_configured_tools/0
          ↓
        Cairnloop.Web.MCP.ToolProjector.spec_to_mcp/2
          │  (pure total function: Spec + module → MCP tool map)
          │  inputSchema via Ecto reflection:
          │    changeset(struct(mod), %{}).required + __changeset__()
          ↓
        Cairnloop.Web.MCP.Router (optional Plug)
          POST / → Jason.decode body
            "initialize" → initialize response (tools capability, read-only)
            "tools/list" → {jsonrpc, id, result: {tools: [...]}}
            other        → JSON-RPC -32601 Method not found
          host mounts: forward "/mcp", Cairnloop.Web.MCP.Router
          auth: host middleware BEFORE forward (D17-09)
```

### Recommended Project Structure

```
lib/cairnloop/
├── governance/
│   ├── telemetry.ex          # EXISTING bounded-metrics — DO NOT MODIFY
│   └── telemetry/
│       └── traces.ex         # NEW: OI trace event submodule
└── web/
    └── mcp/
        ├── router.ex         # NEW: optional Plug (tools/list + initialize)
        └── tool_projector.ex # NEW: pure Spec → MCP tool definition transform

test/cairnloop/
├── governance/
│   ├── telemetry_test.exs    # EXISTING — DO NOT MODIFY
│   └── telemetry/
│       └── traces_test.exs   # NEW: OI event emission + field assertion
└── web/
    └── mcp/
        ├── router_test.exs        # NEW: JSON-RPC shape proofs (Plug.Test.conn)
        └── tool_projector_test.exs # NEW: InternalNote Spec → MCP tool definition proof
```

### Pattern 1: Governance.Telemetry.Traces — OI event module

Mirror `Cairnloop.Governance.Telemetry` exactly but with a different event namespace and richer metadata payload.

```elixir
# Source: Cairnloop.Governance.Telemetry (verified in codebase)
defmodule Cairnloop.Governance.Telemetry.Traces do
  @moduledoc """
  OpenInference-conformant trace events for the governed-action lane.

  Separate from Cairnloop.Governance.Telemetry (bounded metrics, D17-01).
  Event namespace: [:cairnloop, :governance, :trace, <event>].

  Host opts in via :telemetry.attach_many — Cairnloop ships no Scoria dependency.
  No handler → silent no-op (D17-05).
  """

  @events [
    # Guardrail-kind events (policy evaluation / approval lifecycle)
    :approval_requested,
    :revalidation_passed,
    :revalidation_failed,
    :approved,
    :rejected,
    :deferred,
    :expired,
    # Tool-kind events (execution lifecycle)
    :execution_started,
    :execution_succeeded,
    :execution_failed,
    # Proposal lifecycle (planner discretion on span kind for these)
    :proposal_created,
    :proposal_blocked
  ]

  # Span kind constants (OI canonical string values — uppercase)
  @span_kind_guardrail "GUARDRAIL"
  @span_kind_tool "TOOL"

  def emit(event, attrs) when event in @events do
    :telemetry.execute(
      [:cairnloop, :governance, :trace, event],
      %{count: 1},
      build_metadata(event, attrs)
    )
  end

  # Guard-clause no-op: unknown events silently dropped (mirrors Governance.Telemetry)
  def emit(_event, _attrs), do: :ok

  defp build_metadata(event, attrs) do
    %{
      "openinference.span.kind" => span_kind_for(event),
      tool_proposal_id: attrs[:tool_proposal_id],
      actor_id: attrs[:actor_id],
      policy_snapshot_ref: attrs[:tool_proposal_id],  # ref = proposal id
      decided_by: attrs[:decided_by],
      attempt: attrs[:attempt]
    }
  end

  defp span_kind_for(event) when event in [:execution_started, :execution_succeeded, :execution_failed],
    do: @span_kind_tool
  defp span_kind_for(_), do: @span_kind_guardrail
end
```

**Key invariant:** Do not reference or re-use any event name from `[:cairnloop, :governance, <metric_event>]`. The trace events are under `[:cairnloop, :governance, :trace, <event>]` — a completely disjoint namespace.

### Pattern 2: inputSchema derivation via Ecto reflection

Proven approach: call `changeset/2` with empty attrs to extract `required` and `types`.

```elixir
# Source: verified via `mix run --no-start` against Cairnloop.Tools.InternalNote
defp derive_input_schema(tool_module) do
  struct = struct(tool_module)
  cs = tool_module.changeset(struct, %{})

  # cs.required — list of required field atoms (e.g. [:conversation_id, :content])
  # cs.types    — map of field atom => Ecto type atom (e.g. %{content: :string, ...})
  # cs.validations — [{field, {:length, opts}}, ...] — mine for JSON Schema constraints

  required_fields = cs.required
  type_map = cs.types

  properties =
    type_map
    |> Enum.reject(fn {field, _} -> field == :id end)  # exclude generated :id
    |> Enum.map(fn {field, ecto_type} ->
      {to_string(field), %{"type" => ecto_type_to_json_schema(ecto_type)}}
    end)
    |> Map.new()

  required_json = Enum.map(required_fields, &to_string/1)

  schema = %{"type" => "object", "properties" => properties}
  if required_json != [], do: Map.put(schema, "required", required_json), else: schema
end

defp ecto_type_to_json_schema(:string), do: "string"
defp ecto_type_to_json_schema(:integer), do: "integer"
defp ecto_type_to_json_schema(:float), do: "number"
defp ecto_type_to_json_schema(:boolean), do: "boolean"
defp ecto_type_to_json_schema(:map), do: "object"
defp ecto_type_to_json_schema(:binary_id), do: "string"   # UUIDs project as string
defp ecto_type_to_json_schema({:array, _}), do: "array"
defp ecto_type_to_json_schema(_), do: "string"            # safe fallback
```

**Verified result for `Cairnloop.Tools.InternalNote`:**
- `cs.required` = `[:conversation_id, :content]`
- `cs.types` = `%{id: :binary_id, conversation_id: :string, content: :string}`
- Expected `inputSchema`: `{"type": "object", "properties": {"conversation_id": {"type": "string"}, "content": {"type": "string"}}, "required": ["conversation_id", "content"]}`

### Pattern 3: MCP Plug JSON-RPC 2.0 framing

Minimal `@behaviour Plug` — single endpoint, method dispatch via `case`.

```elixir
# Source: MCP spec 2025-03-26 [CITED: modelcontextprotocol.io/specification/2025-03-26]
# + EmailWebhookPlug pattern (verified in codebase)
defmodule Cairnloop.Web.MCP.Router do
  @behaviour Plug
  import Plug.Conn

  @protocol_version "2025-03-26"
  @server_name "cairnloop-mcp"
  @server_version Mix.Project.config()[:version]

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = req} <- Jason.decode(body) do
      handle_method(conn, id, method, Map.get(req, "params", %{}))
    else
      _ ->
        json_error(conn, nil, -32600, "Invalid Request")
    end
  end

  defp handle_method(conn, id, "initialize", _params) do
    result = %{
      "protocolVersion" => @protocol_version,
      "capabilities" => %{"tools" => %{}},  # no listChanged — static read-only registry
      "serverInfo" => %{"name" => @server_name, "version" => @server_version}
    }
    json_result(conn, id, result)
  end

  defp handle_method(conn, id, "tools/list", _params) do
    tools = Cairnloop.ToolRegistry.list_all_tools()
            |> Enum.map(&Cairnloop.Web.MCP.ToolProjector.spec_to_mcp/1)
    json_result(conn, id, %{"tools" => tools})
  end

  defp handle_method(conn, id, _other, _params) do
    json_error(conn, id, -32601, "Method not found")
  end

  defp json_result(conn, id, result) do
    body = Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "result" => result})
    conn |> put_resp_content_type("application/json") |> send_resp(200, body)
  end

  defp json_error(conn, id, code, message) do
    body = Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}})
    conn |> put_resp_content_type("application/json") |> send_resp(200, body)
    # Note: JSON-RPC errors return HTTP 200 with an error object, not HTTP 4xx
  end
end
```

**JSON-RPC error codes in use:** [CITED: json-rpc.org/specification]
- `-32700` — Parse error (malformed JSON)
- `-32600` — Invalid request (missing required JSON-RPC fields)
- `-32601` — Method not found (unsupported methods: `tools/call`, `resources/*`, etc.)

### Pattern 4: ToolRegistry — list all configured tools

The existing `get_available_tools/2` requires `actor_id` + `context` for advisory filtering. The MCP `tools/list` endpoint needs all configured tools regardless of actor scope. Add a simpler accessor:

```elixir
# New function on Cairnloop.ToolRegistry (additive, no churn of existing functions)
def list_all_tools do
  configured_tools = Application.get_env(:cairnloop, :tools, []) || []
  Enum.map(configured_tools, fn mod -> {mod, mod.__tool_spec__()} end)
end
```

The `spec_to_mcp/1` function in `ToolProjector` receives `{module, spec}` tuples.

### Pattern 5: Trace emission call sites

All trace emissions are **additive additions** AFTER existing `Telemetry.emit/3` calls — never inside `with` clause lists.

| Call site | Current last line | OI trace event | Span kind |
|-----------|-------------------|----------------|-----------|
| `governance.ex` `insert_new_proposal/7` after `Telemetry.emit(:proposal_created, ...)` | `{:ok, proposal}` | `:proposal_created` | `GUARDRAIL` |
| `governance.ex` `insert_blocked_proposal/10` after `Telemetry.emit(:proposal_blocked, ...)` | `:ok` | `:proposal_blocked` | `GUARDRAIL` |
| `governance.ex` `update_approval_with_event/3` after `Cairnloop.Telemetry.execute([:governance, :approval_transition], ...)` | `{:ok, updated_approval}` | event_type from event_attrs: `:approval_requested`, `:approved`, `:rejected`, `:deferred`, `:expired` | `GUARDRAIL` |
| `governance.ex` `execute_approved/2` after the co-commit `with` | `{:ok, updated}` | `:execution_started` | `TOOL` |
| `tool_execution_worker.ex` after `GovTelemetry.emit(:action_executed, ...)` | `{:ok, ...}` | `:execution_succeeded` | `TOOL` |
| `tool_execution_worker.ex` after `GovTelemetry.emit(:action_failed, ...)` | `{:cancel, ...}` | `:execution_failed` | `TOOL` |
| `approval_resume_worker.ex` `transition_approval/5` after `Cairnloop.Telemetry.execute(...)` | `{:ok, updated}` | event_type: `:revalidation_passed`, `:revalidation_failed`, `:expired` | `GUARDRAIL` |

**Attribution fields available at each site:**
- `tool_proposal_id` — always available (from proposal.id or approval.tool_proposal_id)
- `actor_id` — from `event_attrs.actor_id`
- `decided_by` — from approval struct (`approval.decided_by`) when it is an approval event
- `attempt` — from `proposal.attempt` for execution events

### Pattern 6: Plug.Test headless testing (MCP Router)

```elixir
# Source: Plug.Test (part of Plug 1.19.1, already available) — [ASSUMED] pattern
defmodule Cairnloop.Web.MCP.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  defp call(body) do
    conn(:post, "/", Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Cairnloop.Web.MCP.Router.call([])
  end

  test "tools/list returns JSON-RPC 2.0 result with tools array" do
    conn = call(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list", "params" => %{}})
    assert conn.status == 200
    assert %{"jsonrpc" => "2.0", "id" => 1, "result" => %{"tools" => tools}} =
             Jason.decode!(conn.resp_body)
    assert is_list(tools)
  end
end
```

### Anti-Patterns to Avoid

- **Sharing event names between `Governance.Telemetry` and `Governance.Telemetry.Traces`:** They MUST be completely disjoint. The bounded-metrics module uses `[:cairnloop, :governance, :proposal_created]`; the trace module uses `[:cairnloop, :governance, :trace, :proposal_created]`.
- **Putting payload content in trace events:** `policy_snapshot` content, `input_snapshot`, note content, or any operator-visible text MUST NOT appear in trace event metadata. Only references (`tool_proposal_id`, `policy_snapshot_ref`).
- **Calling `Governance.validate/3` or any DB function from the MCP Plug:** `tools/list` is pure registry read. No Ecto queries, no `propose/3`, no `run/3`.
- **Using `String.to_existing_atom/1` on MCP request fields:** JSON fields come from untrusted client input. All method dispatch via string `case` pattern matching, not atom conversion.
- **HTTP 4xx for JSON-RPC errors:** JSON-RPC 2.0 errors return HTTP 200 with an `error` object in the response body. The HTTP status code for a well-formed but unsupported-method request is 200.
- **Modifying `Cairnloop.Governance.Telemetry`:** This is sealed (D17-01). Add trace calls next to, never inside, the existing bounded-metrics emit calls.
- **Calling `run/3` or opening `:auto` path from MCP:** `tools/call` is explicitly deferred (D17-06). The MCP Router MUST return `-32601` for any `tools/call` request.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in MCP Plug | Custom JSON parser | `Jason.decode!/1` (already in mix.exs) | Edge cases in escaping, streaming |
| OI span kind lookup | Custom enum | String constants `"TOOL"`, `"GUARDRAIL"`, `"AGENT"` | OI spec uses uppercase strings; no library needed |
| Ecto type → JSON Schema mapping | Elaborate type resolver | Simple `case` on the 5 common Ecto types | InternalNote only uses `:string`; mapping is intentionally minimal for Phase 17 |
| Plug body parsing | Custom `read_body` helper | `Plug.Conn.read_body/1` (already used in `EmailWebhookPlug`) | Handles chunked transfer, limits |
| Test HTTP conn construction | Manual Plug.Conn setup | `Plug.Test.conn/3` (part of existing Plug dep) | Handles headers, body assignment correctly |

**Key insight:** Phase 17 adds ~200 lines of library code. All the hard problems (Ecto reflection, Plug conn handling, JSON-RPC framing, telemetry dispatch) are solved by already-present dependencies. The work is integration glue, not novel infrastructure.

---

## Common Pitfalls

### Pitfall 1: Trace event namespace collision with bounded-metrics module

**What goes wrong:** Accidentally using `[:cairnloop, :governance, :proposal_created]` for trace events — this shares the namespace with `Cairnloop.Governance.Telemetry` and creates false metric/trace conflation for hosts using both.
**Why it happens:** Copy-pasting from `Governance.Telemetry` without updating the event path prefix.
**How to avoid:** `Governance.Telemetry.Traces` MUST use `[:cairnloop, :governance, :trace, event]` — always with the `:trace` segment in position 3. Add a compile-time assertion or comment block.
**Warning signs:** Test handler in `traces_test.exs` fires when `Governance.Telemetry` emits, or vice versa.

### Pitfall 2: inputSchema including the auto-generated `:id` field

**What goes wrong:** `__changeset__()` returns `%{id: :binary_id, ...}` for embedded schemas. Including `id` in `inputSchema` is wrong — it is not a user-visible input.
**Why it happens:** Naively iterating over all keys from `__changeset__()` without filtering.
**How to avoid:** Exclude `:id` in the `Enum.reject` step before building properties.
**Warning signs:** InternalNote projection test fails because `inputSchema` contains an `id` property.

### Pitfall 3: HTTP 4xx for JSON-RPC method-not-found

**What goes wrong:** Returning HTTP 405 or 400 for unsupported MCP methods. MCP clients expect HTTP 200 with a JSON-RPC error object.
**Why it happens:** Confusing HTTP semantics with JSON-RPC semantics.
**How to avoid:** All `send_resp` calls use status 200; error information lives in the JSON body's `error` field.
**Warning signs:** MCP client logs "unexpected HTTP status 405" instead of reading the JSON-RPC error.

### Pitfall 4: Trace events emitted inside the `with` clause list

**What goes wrong:** Placing `Traces.emit/2` inside a `with` clause — if it fails or returns non-`:ok`, it branches the `with` unexpectedly.
**Why it happens:** Copying the wrong pattern from earlier code (pre-D-29 pattern).
**How to avoid:** `Traces.emit/2` MUST be called AFTER the `with` pipeline, at the same indentation level as the existing `Telemetry.emit/3` call. It is always a fire-and-forget call; its return value is discarded.
**Warning signs:** `mix compile --warnings-as-errors` warns about unused `with` clause result.

### Pitfall 5: `mix compile --warnings-as-errors` failure from unused variables

**What goes wrong:** Trace module compiles with `warning: variable "x" is unused` because the `emit/2` return value is not matched.
**Why it happens:** `:telemetry.execute/3` returns `:ok`; the return value of `Traces.emit/2` should be ignored cleanly.
**How to avoid:** The call site uses bare `Traces.emit(:event, attrs)` (discard return), or `_result = Traces.emit(...)`. Use `_ =` prefix if needed to suppress warnings.

### Pitfall 6: `Plug.Test.conn/3` missing `content-type` header causes body parsing to fail

**What goes wrong:** `Plug.Conn.read_body/1` succeeds but `Jason.decode/1` fails because the test didn't set `content-type: application/json`.
**Why it happens:** `Plug.Test.conn/3` creates a bare conn with no headers.
**How to avoid:** Test helper always sets `put_req_header("content-type", "application/json")` and passes JSON-encoded binary as body.

### Pitfall 7: ToolRegistry.list_all_tools/0 vs get_available_tools/2 confusion

**What goes wrong:** Using `get_available_tools/2` for `tools/list` — this applies actor scope filtering, so an unauthenticated MCP call gets an empty list.
**Why it happens:** Confusing the advisory UX filter (scope-filtered) with the full registry (all configured tools).
**How to avoid:** MCP `tools/list` calls a new `list_all_tools/0` (or reads `Application.get_env(:cairnloop, :tools, [])` directly) that returns all configured tool modules without filtering.

---

## Code Examples

### OI Trace Event Shape (verified against OI spec)

```elixir
# Source: OpenInference Semantic Conventions [CITED: arize-ai.github.io/openinference/spec/semantic_conventions.html]
# Span kind attribute name: "openinference.span.kind"
# Values: "TOOL", "GUARDRAIL", "AGENT", "LLM", "CHAIN", "RETRIEVER", etc.
# All UPPERCASE strings.

# Example: execution_succeeded trace event
:telemetry.execute(
  [:cairnloop, :governance, :trace, :execution_succeeded],
  %{count: 1},
  %{
    "openinference.span.kind" => "TOOL",
    tool_proposal_id: "uuid-abc",
    actor_id: "operator-123",
    policy_snapshot_ref: "uuid-abc",   # same as tool_proposal_id (the durable anchor)
    decided_by: "operator-123",
    attempt: 1
  }
)

# Example: approval_requested trace event
:telemetry.execute(
  [:cairnloop, :governance, :trace, :approval_requested],
  %{count: 1},
  %{
    "openinference.span.kind" => "GUARDRAIL",
    tool_proposal_id: "uuid-abc",
    actor_id: "operator-123",
    policy_snapshot_ref: "uuid-abc",
    decided_by: nil,   # nil until operator decides
    attempt: nil
  }
)
```

### MCP tools/list response shape (verified against MCP spec 2025-03-26)

```json
// Source: [CITED: modelcontextprotocol.io/specification/2025-03-26/server/tools]
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "Elixir.Cairnloop.Tools.InternalNote",
        "title": "Add internal note",
        "description": "Appends an operator-only note to the conversation thread.",
        "inputSchema": {
          "type": "object",
          "properties": {
            "conversation_id": {"type": "string"},
            "content": {"type": "string"}
          },
          "required": ["conversation_id", "content"]
        },
        "x-cairnloop-risk-tier": "low_write",
        "x-cairnloop-approval-mode": "requires_approval"
      }
    ]
  }
}
```

### MCP initialize response shape (verified against MCP spec 2025-03-26)

```json
// Source: [CITED: modelcontextprotocol.io/specification/2025-03-26/basic/lifecycle]
// Minimal read-only server — only "tools" capability declared (no prompts, resources, logging)
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-03-26",
    "capabilities": {
      "tools": {}
    },
    "serverInfo": {
      "name": "cairnloop-mcp",
      "version": "0.1.0"
    }
  }
}
```

Note: `"tools": {}` (empty object) without `listChanged` is correct — the registry is static at runtime. `listChanged: true` is only needed if the server pushes `notifications/tools/list_changed` events.

### Test: trace emission assertion (headless)

```elixir
# Source: Cairnloop.Governance.TelemetryTest pattern (verified in codebase)
defp attach_trace_handler(test_id, event) do
  handler_id = "trace-test-#{test_id}-#{event}"
  :telemetry.attach(
    handler_id,
    [:cairnloop, :governance, :trace, event],
    fn _ev, _m, metadata, _cfg -> send(self(), {:trace_metadata, metadata}) end,
    nil
  )
  on_exit(fn -> :telemetry.detach(handler_id) end)
end

test "execution_succeeded trace carries OI span kind TOOL and proposal ref", %{test: t} do
  attach_trace_handler(t, :execution_succeeded)

  Cairnloop.Governance.Telemetry.Traces.emit(:execution_succeeded, %{
    tool_proposal_id: "prop-1",
    actor_id: "actor-1",
    decided_by: "operator-1",
    attempt: 1
  })

  assert_receive {:trace_metadata, meta}, 500
  assert meta["openinference.span.kind"] == "TOOL"
  assert meta.tool_proposal_id == "prop-1"
  assert meta.actor_id == "actor-1"
  refute Map.has_key?(meta, :content), "trace must not carry payload content"
  refute Map.has_key?(meta, :input_snapshot), "trace must not carry input_snapshot"
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MCP protocol version "2024-11-05" | "2025-03-26" (current) | MCP spec 2025-03-26 | Use current version in initialize response; clients check version compatibility |
| `tools` capability with explicit `listChanged: false` | `"tools": {}` empty object = no listChanged | MCP spec current | Empty object is the correct read-only declaration |

**Deprecated/outdated:**
- MCP protocol version `2024-11-05`: Still accepted by many clients but `2025-03-26` is the current spec version. Phase 17 should use `2025-03-26`. [CITED: modelcontextprotocol.io/specification/2025-03-26/basic/lifecycle]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Plug.Test.conn/3` is the correct way to build test conns for a plain `@behaviour Plug` without Phoenix | Patterns / Test examples | Test pattern would need adjustment (use `Phoenix.ConnTest.build_conn` instead) — low risk |
| A2 | `"tools": {}` (empty capabilities object) is valid MCP for read-only; `listChanged` is optional | Code Examples / initialize | If `listChanged` is required, add `"listChanged": false` — trivial fix |
| A3 | `Atom.to_string(module)` produces `"Elixir.Cairnloop.Tools.InternalNote"` as the MCP tool `name` | Architecture / MCP mapping | Verified for the module format; some MCP clients may prefer a short name — can be overridden with a `Spec` field |
| A4 | `approval_resume_worker.ex`'s `transition_approval/5` is the correct injection point for trace events for `revalidation_passed` and `revalidation_failed` | Trace emission call sites | If the worker is refactored in a future phase, injection points move — low risk for Phase 17 |

---

## Open Questions

1. **`x-cairnloop-*` extension field key format**
   - What we know: D17-07 specifies `risk_tier` and `approval_mode` as `x-cairnloop-*` fields.
   - What's unclear: Exact key names — `x-cairnloop-risk-tier` vs `x-cairnloop-riskTier` vs `x-cairnloop-risk_tier`.
   - Recommendation: Use kebab-case (`x-cairnloop-risk-tier`, `x-cairnloop-approval-mode`) per HTTP header convention — standard for JSON extension fields.

2. **Whether to include `proposal_created` / `proposal_blocked` in the Traces module**
   - What we know: These are proposal-lifecycle events, not strictly approval or execution spans.
   - What's unclear: Whether they are useful to Scoria for trace tree reconstruction.
   - Recommendation: Include them as `GUARDRAIL` span kind — they represent the policy gate that determines whether a proposal reaches the approval lane. Scoria can use `tool_proposal_id` to anchor the full span tree from first proposal through execution.

3. **`list_all_tools/0` vs reading `Application.get_env` directly in the Router**
   - What we know: `ToolRegistry.get_available_tools/2` filters by scope; MCP needs all tools.
   - What's unclear: Whether a new public function on `ToolRegistry` is better than the Router reading the env directly.
   - Recommendation: Add `list_all_tools/0` to `ToolRegistry` for clean encapsulation — avoids the Router having knowledge of how tools are stored.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `:telemetry` | OI trace events | Yes | ~> 1.4 | — |
| `Plug` | MCP Router Plug | Yes | 1.19.1 | — |
| `Plug.Router` | Optional (plain Plug.Conn is sufficient) | Yes | 1.19.1 | Use plain `@behaviour Plug` |
| `Jason` | JSON encode/decode in MCP Router | Yes | ~> 1.2 | — |
| `Ecto` (embedded schema reflection) | inputSchema derivation | Yes | ~> 3.10 | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir) |
| Config file | `test/test_helper.exs` (excludes `:integration` by default) |
| Quick run command | `mix test test/cairnloop/governance/telemetry/ test/cairnloop/web/mcp/ --warnings-as-errors` |
| Full suite command | `mix test --warnings-as-errors` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MCP-01 | InternalNote Spec projects to correct MCP tool definition shape | unit | `mix test test/cairnloop/web/mcp/tool_projector_test.exs` | No — Wave 0 |
| MCP-01 | `tools/list` JSON-RPC returns correct envelope shape | unit | `mix test test/cairnloop/web/mcp/router_test.exs` | No — Wave 0 |
| MCP-01 | `initialize` returns `tools` capability with correct protocol version | unit | `mix test test/cairnloop/web/mcp/router_test.exs` | No — Wave 0 |
| MCP-01 | Unsupported method returns JSON-RPC -32601 error | unit | `mix test test/cairnloop/web/mcp/router_test.exs` | No — Wave 0 |
| D17-02 | Trace events carry `openinference.span.kind`, `tool_proposal_id`, `actor_id` | unit | `mix test test/cairnloop/governance/telemetry/traces_test.exs` | No — Wave 0 |
| D17-02 | Trace events do NOT carry `policy_snapshot` content / input payloads | unit | `mix test test/cairnloop/governance/telemetry/traces_test.exs` | No — Wave 0 |
| D17-05 | Unknown trace events are silently dropped (guard-clause no-op) | unit | `mix test test/cairnloop/governance/telemetry/traces_test.exs` | No — Wave 0 |
| D17-01 | Trace events use `[:cairnloop, :governance, :trace, ...]` namespace, NOT `[:cairnloop, :governance, ...]` | unit | `mix test test/cairnloop/governance/telemetry/traces_test.exs` | No — Wave 0 |
| D17-04 | Bounded-metrics module `Cairnloop.Governance.Telemetry` is UNCHANGED | unit (existing) | `mix test test/cairnloop/governance/telemetry_test.exs` | Yes — existing |

### Sampling Rate

- **Per task commit:** `mix test --warnings-as-errors` (full headless suite)
- **Per wave merge:** `mix test --warnings-as-errors`
- **Phase gate:** Full headless suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/cairnloop/governance/telemetry/traces_test.exs` — covers D17-01, D17-02, D17-05 (OI field assertions + namespace separation + guard-clause no-op)
- [ ] `test/cairnloop/web/mcp/tool_projector_test.exs` — covers MCP-01 InternalNote projection round-trip
- [ ] `test/cairnloop/web/mcp/router_test.exs` — covers MCP-01 tools/list + initialize + method-not-found error shapes

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Auth is host middleware (D17-09); Cairnloop does not prescribe auth for the Plug |
| V3 Session Management | No | Stateless JSON-RPC; no sessions |
| V4 Access Control | Partial | `tools/list` is read-only; no execution; auth gate is host responsibility before `forward` |
| V5 Input Validation | Yes | `Jason.decode/1` for JSON parsing; method dispatch via `case` on string (no atom conversion) |
| V6 Cryptography | No | No new crypto in Phase 17 |

### Known Threat Patterns for Elixir Plug / JSON-RPC stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Atom exhaustion via `String.to_atom/1` on MCP method field | Tampering / DoS | Use string `case` pattern matching — never `String.to_atom/1` on untrusted JSON keys |
| Auth bypass via unauthenticated MCP listing | Information Disclosure | Document that host MUST mount auth plug before `forward "/mcp", Router` — Cairnloop itself does not enforce |
| Large body DoS | DoS | `Plug.Conn.read_body/1` default limit is 8MB; acceptable for listing-only endpoint |
| Tool name leakage | Information Disclosure | `tools/list` exposes tool metadata; acceptable by design (advisory listing for MCP clients) |

---

## Sources

### Primary (HIGH confidence)

- Codebase: `lib/cairnloop/governance/telemetry.ex` — exact module structure mirrored by `Traces`; `@events` allow-list + guard-clause pattern
- Codebase: `lib/cairnloop/tools/internal_note.ex` + `mix run --no-start` introspection — verified `cs.required = [:conversation_id, :content]`, `cs.types = %{content: :string, ...}`
- Codebase: `lib/cairnloop/governance.ex` — exact call sites for trace emission (all 7 transition points documented)
- Codebase: `mix.lock` — Plug 1.19.1, Jason ~> 1.2, :telemetry ~> 1.4 all available
- [CITED: modelcontextprotocol.io/specification/2025-03-26/server/tools] — `tools/list` request/response shape, `ListToolsResult`, tool definition fields
- [CITED: modelcontextprotocol.io/specification/2025-03-26/basic/lifecycle] — `initialize` request/response, `protocolVersion: "2025-03-26"`, capability negotiation
- [CITED: arize-ai.github.io/openinference/spec/semantic_conventions.html] — `openinference.span.kind` attribute name, uppercase span kind values (`"TOOL"`, `"GUARDRAIL"`, `"AGENT"`), only `openinference.span.kind` is required

### Secondary (MEDIUM confidence)

- Test pattern: `test/cairnloop/governance/telemetry_test.exs` — verified `:telemetry.attach/4` + `assert_receive {:telemetry_metadata, meta}` test idiom used throughout codebase
- Email webhook plug pattern: `lib/cairnloop/ingress/email_webhook_plug.ex` — verified `@behaviour Plug` + `Plug.Conn.read_body/1` + `Jason.decode` + `put_resp_content_type` pattern

### Tertiary (LOW confidence)

- JSON-RPC 2.0 error codes (-32600, -32601, -32700) — [ASSUMED] based on training knowledge of the JSON-RPC 2.0 spec; standard and stable

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all dependencies verified in mix.exs/mix.lock via codebase read
- Architecture: HIGH — all call sites verified by reading governance.ex, workers; Ecto introspection verified via `mix run`
- OI trace event shapes: HIGH (spec), MEDIUM (Scoria-specific auto-attach API naming)
- MCP JSON-RPC framing: HIGH — verified against official MCP spec
- inputSchema derivation: HIGH — verified via `mix run` that `cs.required` and `cs.types` are available
- Pitfalls: HIGH — all come from direct codebase reading + D-29 constraint chain

**Research date:** 2026-05-25
**Valid until:** 2026-07-01 (MCP spec is evolving; recheck if implementing after this date)
