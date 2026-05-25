# Phase 17: Optional Evidence Lane & Read-Only MCP Seam — Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 10 (3 new modules, 1 new utility, 2 existing module modifications, 3 new test files, 1 existing module modification)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/governance/telemetry/traces.ex` | module (telemetry) | event-driven | `lib/cairnloop/governance/telemetry.ex` | exact |
| `lib/cairnloop/web/mcp/router.ex` | middleware (Plug) | request-response | `lib/cairnloop/ingress/email_webhook_plug.ex` | role-match |
| `lib/cairnloop/web/mcp/tool_projector.ex` | utility (pure transform) | transform | `lib/cairnloop/tool/spec.ex` (struct consumed) + `lib/cairnloop/tool_registry.ex` (data source) | partial-match |
| `lib/cairnloop/tool_registry.ex` | service (registry) | CRUD | self (additive) | self |
| `lib/cairnloop/governance.ex` | service (facade) | event-driven | self (additive) | self |
| `lib/cairnloop/workers/tool_execution_worker.ex` | worker | event-driven | self (additive) | self |
| `lib/cairnloop/workers/approval_resume_worker.ex` | worker | event-driven | self (additive) | self |
| `test/cairnloop/governance/telemetry/traces_test.exs` | test | event-driven | `test/cairnloop/governance/telemetry_test.exs` | exact |
| `test/cairnloop/web/mcp/tool_projector_test.exs` | test | transform | `test/cairnloop/governance/telemetry_test.exs` | role-match |
| `test/cairnloop/web/mcp/router_test.exs` | test | request-response | `test/cairnloop/governance/telemetry_test.exs` + RESEARCH.md Pattern 6 | role-match |

---

## Pattern Assignments

### `lib/cairnloop/governance/telemetry/traces.ex` (module, event-driven)

**Analog:** `lib/cairnloop/governance/telemetry.ex`

**Module declaration + imports** (lines 1–19):
```elixir
defmodule Cairnloop.Governance.Telemetry do
  @moduledoc """..."""

  alias Cairnloop.Telemetry
```
The new `Traces` module does NOT alias `Cairnloop.Telemetry` — it calls `:telemetry.execute/3` directly (same as the analog's underlying `Telemetry.execute/3` calls). No alias needed; the `:telemetry` OTP app is the correct call target.

**@events allow-list pattern** (lines 21–28):
```elixir
  @events [
    :proposal_created,
    :proposal_blocked,
    :proposal_duplicate,
    # Phase 16 execution events (D16-10)
    :action_executed,
    :action_failed
  ]
```
For `Traces`, the allow-list covers the OI trace event atoms under `[:cairnloop, :governance, :trace, ...]`. Use the same `@events` module attribute + guard-clause pattern exactly.

**Guard-clause emit/3 + silent no-op** (lines 50–59):
```elixir
  def emit(event, measurements, metadata) when event in @events do
    Telemetry.execute(
      [:governance, event],
      normalize_measurements(measurements),
      metadata(event, metadata)
    )
  end

  # Unknown events are silently dropped — guard clause (plan requirement, OBS-01).
  def emit(_event, _measurements, _metadata), do: :ok
```
For `Traces`, the emit signature is `emit(event, attrs)` (2-arity, no measurements struct since OI trace events always carry `%{count: 1}`). The guard clause is identical: `def emit(_event, _attrs), do: :ok`.

**metadata/2 dispatch + normalize_* helpers** (lines 65–116):
```elixir
  def metadata(event, metadata)
      when event in [:action_executed, :action_failed] and is_map(metadata) do
    %{
      risk_tier: normalize_risk_tier(Map.get(metadata, :risk_tier)),
      ...
    }
  end
  defp normalize_risk_tier(value) when value in @allowed_risk_tiers, do: value
  defp normalize_risk_tier(_), do: :unknown
```
For `Traces`, the `build_metadata/2` private function mirrors this — but instead of normalization allow-lists it just passes through the attribution refs (which are already typed: `tool_proposal_id` is a string/binary, `actor_id` is a string, etc.). No normalization needed for the OI trace payload.

**Critical invariant — namespace separation (D17-01):**
The bounded-metrics module uses `[:cairnloop, :governance, event]` (3-segment path). The trace module MUST use `[:cairnloop, :governance, :trace, event]` (4-segment path with `:trace` in position 3). This is the ONLY thing that differs from the analog's `:telemetry.execute/3` call.

---

### `lib/cairnloop/web/mcp/router.ex` (Plug, request-response)

**Analog:** `lib/cairnloop/ingress/email_webhook_plug.ex`

**Module + behaviour declaration** (lines 1–6):
```elixir
defmodule Cairnloop.Ingress.EmailWebhookPlug do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts
```
Copy `@behaviour Plug` + `import Plug.Conn` + `def init(opts), do: opts` exactly.

**Body read + JSON decode pattern** (lines 8–12):
```elixir
  def call(conn, _opts) do
    with {:ok, :verified} <- verify_signature(conn),
         {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, payload} <- Jason.decode(body) do
```
For `MCP.Router`, the `call/2` uses the same `Plug.Conn.read_body/1` + `Jason.decode/1` pattern. Drop `verify_signature` (auth is host's responsibility per D17-09). Validate JSON-RPC 2.0 envelope fields (`jsonrpc`, `id`, `method`) via pattern match on the decoded map.

**put_resp_content_type + send_resp pattern** (lines 22–25):
```elixir
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{status: "ok"}))
```
All `json_result/3` and `json_error/4` helpers in `MCP.Router` use this exact pipe pattern. JSON-RPC errors return HTTP 200 (not 4xx) per the JSON-RPC 2.0 spec.

**Error branch pattern** (lines 26–35):
```elixir
    else
      {:error, :unauthorized} ->
        conn |> put_resp_content_type("application/json") |> send_resp(401, ...)
      _ ->
        conn |> put_resp_content_type("application/json") |> send_resp(400, ...)
    end
```
For `MCP.Router`, the `else` branch handles malformed JSON or missing `jsonrpc`/`id`/`method` fields with a JSON-RPC `-32600` Invalid Request error (HTTP 200 body).

**Method dispatch:** Use `case method` string pattern matching — NEVER `String.to_atom/1` on method names from the request (D-19 / security posture from ToolRegistry.find_tool_module/1 precedent).

---

### `lib/cairnloop/web/mcp/tool_projector.ex` (utility, transform)

**Analog:** `lib/cairnloop/tool/spec.ex` (struct being transformed) + `lib/cairnloop/tool_registry.ex` (iteration pattern)

**Struct reference from spec.ex** (lines 22–31):
```elixir
  defstruct [
    :risk_tier,     # atom — :read_only | :low_write | :high_write | :destructive
    :approval_mode, # atom — :auto | :requires_approval | :always_block
    :idempotency,
    :result_states,
    :title,         # string — human-readable name (Phase 14 preview, Phase 17 MCP "title")
    :description    # string — operator description (Phase 17 MCP "description")
  ]
```
The `spec_to_mcp/1` function receives `{module, %Cairnloop.Tool.Spec{}}` tuples from `ToolRegistry.list_all_tools/0`. It accesses `spec.title`, `spec.description`, `spec.risk_tier`, `spec.approval_mode` directly, and calls `module` for `Atom.to_string(module)` (MCP `name`) and `inputSchema` derivation via `module.changeset/2`.

**Module atom-to-string pattern from tool_registry.ex** (lines 65–66):
```elixir
    case Enum.find(configured_tools, fn mod -> Atom.to_string(mod) == tool_ref end) do
```
`Atom.to_string(tool_module)` is the established pattern for producing the MCP tool `name` field (`"Elixir.Cairnloop.Tools.InternalNote"`).

**Application.get_env pattern from tool_registry.ex** (lines 20–21, 47–48):
```elixir
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []
```
`list_all_tools/0` on `ToolRegistry` uses this same pattern — no Ecto, no DB, just config read.

**inputSchema derivation (pure Ecto reflection):** Call `tool_module.changeset(struct(tool_module), %{})` — this yields a changeset with `.required` (list of required field atoms) and `.types` (map of field atom → Ecto type). Filter out `:id` from `.types` before building properties (Pitfall 2 in RESEARCH.md). Map Ecto types to JSON Schema types via a simple `case`:
- `:string` → `"string"`, `:integer` → `"integer"`, `:float` → `"number"`, `:boolean` → `"boolean"`, `:binary_id` → `"string"`, `{:array, _}` → `"array"`, `:map` → `"object"`, `_` → `"string"` (safe fallback)

**x-cairnloop extension fields:** Include `"x-cairnloop-risk-tier"` (kebab-case per RESEARCH.md open question resolution) and `"x-cairnloop-approval-mode"` with `Atom.to_string/1` values.

**Module structure:** Pure `defmodule` with `@moduledoc`, `@spec` annotations, and zero side-effect functions. No `use`, no `alias` for DB modules. No `defstruct`. Follows Cairnloop's idiom for pure total functions over `Spec` structs as noted in CONTEXT.md § Established Patterns.

---

### `lib/cairnloop/tool_registry.ex` (MODIFY — additive)

**Self-analog.** Add `list_all_tools/0` following the established `Application.get_env` pattern (lines 47–48):

```elixir
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    Enum.filter(configured_tools, fn tool_module ->
      ...
    end)
```

New function mirrors the same `|| []` guard and returns `{module, spec}` tuples:
```elixir
  def list_all_tools do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []
    Enum.map(configured_tools, fn mod -> {mod, mod.__tool_spec__()} end)
  end
```
No scope/actor filtering — this is the full registry for MCP listing.

---

### `lib/cairnloop/governance.ex` (MODIFY — additive trace emissions)

**Self-analog.** Three injection points. The pattern is always: emit AFTER the `with` pipeline, at the same indentation as the existing `Telemetry.emit/3` call.

**inject after line 348 (`insert_new_proposal/6` success):**
```elixir
      # Telemetry AFTER with success — never inside the with clause list (D-29)
      Telemetry.emit(:proposal_created, %{count: 1}, %{
        outcome: :proposed,
        risk_tier: validated.risk_tier,
        approval_mode: validated.approval_mode
      })
      # [NEW] OI trace event — after bounded-metrics emit (D17-04)
      Traces.emit(:proposal_created, %{
        tool_proposal_id: proposal.id,
        actor_id: actor_id,
        decided_by: nil,
        attempt: nil
      })

      {:ok, proposal}
```

**inject after line 469 (`insert_blocked_proposal/10` success):**
```elixir
      # Telemetry AFTER with success (D-29)
      Telemetry.emit(:proposal_blocked, %{count: 1}, %{...})
      # [NEW] OI trace event (D17-04)
      Traces.emit(:proposal_blocked, %{
        tool_proposal_id: proposal.id,
        actor_id: actor_id,
        decided_by: nil,
        attempt: nil
      })

      :ok
```

**inject after line 120 (`update_approval_with_event/3` success — covers ALL approval transitions):**
```elixir
      Cairnloop.Telemetry.execute(
        [:governance, :approval_transition],
        %{count: 1},
        %{event_type: Map.get(event_attrs, :event_type), new_status: updated_approval.status}
      )
      # [NEW] OI trace event (D17-04)
      Traces.emit(Map.get(event_attrs, :event_type), %{
        tool_proposal_id: approval.tool_proposal_id,
        actor_id: Map.get(event_attrs, :actor_id),
        decided_by: Map.get(updated_approval, :decided_by),
        attempt: nil
      })

      {:ok, updated_approval}
```

**inject after line 848 (`execute_approved/2` success):**
```elixir
        with {:ok, updated} <- update_approval_with_event(...) do
          enqueue_fn.(ToolExecutionWorker.new(%{"approval_id" => updated.id}))
          # [NEW] OI trace: execution_started (D17-04)
          Traces.emit(:execution_started, %{
            tool_proposal_id: approval.tool_proposal_id,
            actor_id: "system",
            decided_by: nil,
            attempt: nil
          })
          {:ok, updated}
        end
```

**alias to add:** The `Traces` module needs to be aliased in `governance.ex`:
```elixir
  alias Cairnloop.Governance.{Policy, Preview, Telemetry, ToolActionEvent, ToolApproval, ToolProposal}
  # Add:
  alias Cairnloop.Governance.Telemetry.Traces
```

---

### `lib/cairnloop/workers/tool_execution_worker.ex` (MODIFY — additive)

**Self-analog.** Two injection points — after the existing `GovTelemetry.emit` calls.

**After line 218 (success path `record_success/6`):**
```elixir
      {:ok, :ok} ->
        # Telemetry AFTER committed transaction — never inside (D-29)
        GovTelemetry.emit(:action_executed, %{count: 1, duration_ms: duration_ms}, %{...})
        # [NEW] OI trace — after bounded-metrics emit (D17-04)
        Traces.emit(:execution_succeeded, %{
          tool_proposal_id: proposal.id,
          actor_id: proposal.actor_id,
          decided_by: approval.decided_by,
          attempt: new_attempt
        })

        broadcast_executed(approval.id, proposal)
        :ok
```

**After line 285 (terminal failure path `handle_transient_failure/6`):**
```elixir
        {:ok, :ok} ->
          GovTelemetry.emit(:action_failed, %{count: 1}, %{...})
          # [NEW] OI trace (D17-04)
          Traces.emit(:execution_failed, %{
            tool_proposal_id: proposal.id,
            actor_id: proposal.actor_id,
            decided_by: approval.decided_by,
            attempt: new_attempt
          })

          broadcast_execution_failed(approval.id, proposal)
          {:cancel, humanized}
```

**alias to add:**
```elixir
  alias Cairnloop.Governance.Telemetry, as: GovTelemetry
  # Add:
  alias Cairnloop.Governance.Telemetry.Traces
```

---

### `lib/cairnloop/workers/approval_resume_worker.ex` (MODIFY — additive)

**Self-analog.** One injection point — after the existing `Cairnloop.Telemetry.execute/3` call in `transition_approval/5` (lines 174–180):

```elixir
      Cairnloop.Telemetry.execute(
        [:governance, :approval_transition],
        %{count: 1},
        %{event_type: event_type, new_status: new_status}
      )
      # [NEW] OI trace — after existing telemetry (D17-04)
      Cairnloop.Governance.Telemetry.Traces.emit(event_type, %{
        tool_proposal_id: approval.tool_proposal_id,
        actor_id: actor_id,
        decided_by: Map.get(updated, :decided_by),
        attempt: nil
      })

      {:ok, updated}
```

No new alias needed if calling fully-qualified. Alternatively add alias:
```elixir
  alias Cairnloop.Governance.Telemetry.Traces
```

---

### `test/cairnloop/governance/telemetry/traces_test.exs` (NEW — test)

**Analog:** `test/cairnloop/governance/telemetry_test.exs`

**Test module structure** (lines 1–18):
```elixir
defmodule Cairnloop.Governance.TelemetryTest do
  @moduledoc """..."""
  use ExUnit.Case, async: false

  alias Cairnloop.Governance.Telemetry
```
Mirror exactly: `use ExUnit.Case, async: false` (telemetry handlers are process-local; `async: false` prevents handler ID collisions across concurrent tests).

**attach_handler helper** (lines 23–38):
```elixir
  defp attach_handler(test_id, event_name) do
    handler_id = "test-handler-#{test_id}-#{event_name}"

    :telemetry.attach(
      handler_id,
      [:cairnloop, :governance, event_name],
      fn _event, _measurements, metadata, _config ->
        send(self(), {:telemetry_metadata, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    handler_id
  end
```
For `traces_test.exs`, use `[:cairnloop, :governance, :trace, event_name]` (4-segment path). The `send(self(), {:trace_metadata, metadata})` message tag distinguishes from the bounded-metrics tests.

**Event acceptance test pattern** (lines 44–58):
```elixir
    test ":action_executed is accepted and fires ...", %{test: test_id} do
      attach_handler(test_id, :action_executed)
      Telemetry.emit(:action_executed, %{count: 1, duration_ms: 12}, %{...})
      assert_receive {:telemetry_metadata, _meta}, 500, "expected event to fire"
    end
```
Copy this test structure for each major trace event in `@events`.

**Negative assertion pattern for high-cardinality** (lines 128–142):
```elixir
      refute Map.has_key?(meta, :actor_id), "actor_id must never appear..."
      refute Map.has_key?(meta, :content), "content must never appear..."
```
For `traces_test.exs`, assert the trace events DO carry `actor_id` (it IS allowed in OI trace metadata per D17-02) but do NOT carry `:content`, `:input_snapshot`, or `:policy_snapshot` (content exclusion, D17-02).

**Guard-clause no-op test** (lines 75–95):
```elixir
      Telemetry.emit(:not_a_real_event, %{count: 1}, %{})
      refute_receive {:telemetry_metadata, _}, 100, "unknown event must be silently dropped"
```
Same pattern verbatim for the `Traces.emit/2` guard clause.

**Namespace separation test** (new, not in analog): Assert that attaching a handler to `[:cairnloop, :governance, :proposal_created]` does NOT fire when `Traces.emit(:proposal_created, ...)` is called. This proves the namespace isolation required by D17-01.

---

### `test/cairnloop/web/mcp/tool_projector_test.exs` (NEW — test)

**Analog:** `test/cairnloop/governance/telemetry_test.exs` (structure), but this is a pure data assertion (no telemetry).

**Module structure:**
```elixir
defmodule Cairnloop.Web.MCP.ToolProjectorTest do
  use ExUnit.Case, async: true  # pure transform — safe to run async
  alias Cairnloop.Web.MCP.ToolProjector
```
Use `async: true` — no telemetry handlers, no DB, pure function assertions.

**Setup pattern from telemetry_test.exs (lines 171–176) — env manipulation:**
```elixir
    setup do
      Application.delete_env(:cairnloop, :tools)
      on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
      :ok
    end
```
Use same `setup` + `on_exit` pattern to isolate tool registry env per test.

**Core assertion pattern:** Test that `ToolProjector.spec_to_mcp({Cairnloop.Tools.InternalNote, Cairnloop.Tools.InternalNote.__tool_spec__()})` returns a map matching the expected MCP tool definition shape (from RESEARCH.md Code Examples):
- `"name"` = `"Elixir.Cairnloop.Tools.InternalNote"`
- `"title"` = `"Add internal note"`
- `"inputSchema"` = `%{"type" => "object", "properties" => %{"conversation_id" => %{"type" => "string"}, "content" => %{"type" => "string"}}, "required" => ["conversation_id", "content"]}`
- `"x-cairnloop-risk-tier"` present
- `"x-cairnloop-approval-mode"` present
- No `:id` in `inputSchema.properties` (Pitfall 2)

---

### `test/cairnloop/web/mcp/router_test.exs` (NEW — test)

**Analog:** `lib/cairnloop/ingress/email_webhook_plug.ex` structure (Plug test pattern) + RESEARCH.md Pattern 6.

**Module structure:**
```elixir
defmodule Cairnloop.Web.MCP.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn
```
`async: true` — no telemetry, no DB. `Plug.Test` is already available as part of the `plug` dependency.

**Test helper (RESEARCH.md Pattern 6, lines 406–415):**
```elixir
  defp call(body) do
    conn(:post, "/", Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Cairnloop.Web.MCP.Router.call([])
  end
```
The `content-type` header is required to avoid Pitfall 6 in RESEARCH.md.

**Assertion pattern:**
```elixir
  test "tools/list returns JSON-RPC 2.0 result with tools array" do
    conn = call(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list", "params" => %{}})
    assert conn.status == 200
    assert %{"jsonrpc" => "2.0", "id" => 1, "result" => %{"tools" => tools}} =
             Jason.decode!(conn.resp_body)
    assert is_list(tools)
  end
```
Test cases to cover: `tools/list`, `initialize`, unsupported method (`tools/call`), malformed JSON body.

---

## Shared Patterns

### Telemetry: emit-after-success (D-29)

**Source:** `lib/cairnloop/governance/telemetry.ex` lines 50–59; `lib/cairnloop/workers/tool_execution_worker.ex` lines 211–218; `lib/cairnloop/workers/approval_resume_worker.ex` lines 173–179
**Apply to:** All trace emission call sites in governance.ex, tool_execution_worker.ex, approval_resume_worker.ex

```elixir
# Pattern: telemetry/trace emit AFTER with pipeline, at same indentation, never inside with clauses
case tx_result do
  {:ok, :ok} ->
    GovTelemetry.emit(:action_executed, ...)  # bounded metrics — existing
    Traces.emit(:execution_succeeded, ...)    # OI trace — new, after existing emit
    :ok
  {:error, reason} ->
    ...
end
```

### Plug: @behaviour + read_body + Jason.decode

**Source:** `lib/cairnloop/ingress/email_webhook_plug.ex` lines 1–35
**Apply to:** `lib/cairnloop/web/mcp/router.ex`

```elixir
@behaviour Plug
import Plug.Conn

def init(opts), do: opts

def call(conn, _opts) do
  with {:ok, body, conn} <- Plug.Conn.read_body(conn),
       {:ok, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = req} <- Jason.decode(body) do
    handle_method(conn, id, method, Map.get(req, "params", %{}))
  else
    _ -> json_error(conn, nil, -32600, "Invalid Request")
  end
end
```

### Registry: Application.get_env pattern (no DB)

**Source:** `lib/cairnloop/tool_registry.ex` lines 20–21, 47–48, 65
**Apply to:** `lib/cairnloop/tool_registry.ex` (new `list_all_tools/0`), `lib/cairnloop/web/mcp/tool_projector.ex` (indirectly via registry)

```elixir
configured_tools = Application.get_env(:cairnloop, :tools, []) || []
```

### Test: :telemetry.attach + on_exit detach + assert_receive

**Source:** `test/cairnloop/governance/telemetry_test.exs` lines 23–38, 55–57
**Apply to:** `test/cairnloop/governance/telemetry/traces_test.exs`

```elixir
:telemetry.attach(handler_id, event_path, fn _ev, _m, metadata, _cfg ->
  send(self(), {:trace_metadata, metadata})
end, nil)
on_exit(fn -> :telemetry.detach(handler_id) end)
# ...
assert_receive {:trace_metadata, meta}, 500
```

### Module alias pattern for Traces in governance + workers

**Source:** `lib/cairnloop/governance.ex` line 62; `lib/cairnloop/workers/tool_execution_worker.ex` lines 45–46

```elixir
# governance.ex existing alias line:
alias Cairnloop.Governance.{Policy, Preview, Telemetry, ToolActionEvent, ToolApproval, ToolProposal}
# Add Traces to destructured alias:
alias Cairnloop.Governance.Telemetry.Traces

# tool_execution_worker.ex:
alias Cairnloop.Governance.Telemetry, as: GovTelemetry
alias Cairnloop.Governance.Telemetry.Traces
```

---

## No Analog Found

All files have analogs. No entries for this section.

---

## Metadata

**Analog search scope:** `lib/cairnloop/governance/`, `lib/cairnloop/ingress/`, `lib/cairnloop/workers/`, `lib/cairnloop/tool/`, `lib/cairnloop/`, `test/cairnloop/governance/`
**Files scanned:** 8 source files, 1 test file
**Pattern extraction date:** 2026-05-25
