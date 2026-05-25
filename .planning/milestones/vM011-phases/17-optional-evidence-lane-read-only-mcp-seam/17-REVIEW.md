---
phase: 17-optional-evidence-lane-read-only-mcp-seam
reviewed: 2026-05-25T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - lib/cairnloop/governance.ex
  - lib/cairnloop/governance/telemetry/traces.ex
  - lib/cairnloop/tool_registry.ex
  - lib/cairnloop/web/mcp/router.ex
  - lib/cairnloop/web/mcp/tool_projector.ex
  - lib/cairnloop/workers/approval_resume_worker.ex
  - lib/cairnloop/workers/tool_execution_worker.ex
  - test/cairnloop/governance/telemetry/traces_test.exs
  - test/cairnloop/web/mcp/router_test.exs
  - test/cairnloop/web/mcp/tool_projector_test.exs
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-05-25
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 17 adds: (1) an OI-conformant telemetry trace module (`Traces`), (2) a read-only MCP seam (`Router` + `ToolProjector`), and (3) `Traces.emit/2` call sites threaded into `governance.ex` and the two workers. The Traces module, MCP Router, and ToolProjector are well-structured and meet the stated design constraints. Two existing workers carry a non-obvious return-value pattern that this phase touches; one of them has a latent correctness defect that becomes more consequential now that the Traces emit is wired in.

One blocker: `ApprovalResumeWorker.perform/1` silently swallows `transition_approval/5` failures, telling Oban the job succeeded even when no DB write committed. Three warnings: (1) the same resume worker does not emit a Traces event for the `:revalidation_passed → execution_pending` path (the Traces call is inside `transition_approval` but the event_type passed is the ToolActionEvent event, not a Traces-known lifecycle atom for that transition — covered below), (2) the MCP Router pattern-match requires `"id"` which silently rejects JSON-RPC notifications as `-32600 Invalid Request` rather than silently discarding them per spec, (3) `ToolProjector.derive_input_schema/1` is uncovered against a tool whose `changeset/2` raises — one crashing tool brings down the entire `tools/list` response. Two informational items.

---

## Critical Issues

### CR-01: `ApprovalResumeWorker.perform/1` always returns `:ok` — DB failures in `transition_approval/5` are silently swallowed; Oban never retries

**File:** `lib/cairnloop/workers/approval_resume_worker.ex:55-70`

**Issue:**

```elixir
%ToolApproval{status: :approved} = approval ->
  if approval.expires_at && DateTime.before?(approval.expires_at, DateTime.utc_now()) do
    expire_approval(approval)       # returns {:ok, _} or {:error, _}
  else
    revalidate_and_transition(approval)  # returns {:ok, _} or {:error, _}
  end

  :ok   # <-- unconditional; result of the if/else is discarded
```

Both `expire_approval/1` and `revalidate_and_transition/1` delegate to `transition_approval/5`, which is a sequential `with` pipeline that can return `{:error, changeset_or_reason}` if either the `repo().update/1` or the `repo().insert/1` step fails (e.g., DB connection blip, constraint violation). The caller (`perform/1`) discards that return value and returns `:ok`, which Oban interprets as job success. The approval stays in `:approved` forever — no status transition, no OI trace event — and Oban will never re-enqueue.

The contrast with `ToolExecutionWorker` is instructive: every failure path there returns `{:error, :persist_failed}` so Oban retries, and `{:cancel, reason}` only after a confirmed durable write. `ApprovalResumeWorker` has no equivalent guard.

**Fix:**

```elixir
%ToolApproval{status: :approved} = approval ->
  result =
    if approval.expires_at && DateTime.before?(approval.expires_at, DateTime.utc_now()) do
      expire_approval(approval)
    else
      revalidate_and_transition(approval)
    end

  case result do
    {:ok, _} -> :ok
    {:error, reason} ->
      Logger.error("ApprovalResumeWorker transition failed for approval #{approval.id}: #{inspect(reason)}")
      {:error, :persist_failed}  # Oban will retry
  end
```

---

## Warnings

### WR-01: `ToolProjector.derive_input_schema/1` — a crashing `changeset/2` in any one tool aborts the entire `tools/list` response with no isolation

**File:** `lib/cairnloop/web/mcp/tool_projector.ex:64-79`

**Issue:**

`derive_input_schema/1` calls `tool_module.changeset(struct(tool_module), %{})` with no `rescue`. If any registered tool's `changeset/2` raises (e.g., a tool with a side-effecting changeset, a callback with a pattern-match error, or a tool under development) the exception propagates through `ToolProjector.spec_to_mcp/1` → `Enum.map/2` → `Router.handle_method/4` → `Router.call/2`. The Router has no `rescue` wrapper around `handle_method`, so the exception becomes an unhandled crash in the Plug pipeline. The MCP client gets a 500 or a dropped connection instead of a valid JSON-RPC response for the tools it *can* discover.

The Router's `call/2` only rescues in the `with`'s `else` clause, which catches `{:error, ...}` tuples and JSON parse failures — not exceptions raised inside `handle_method`.

**Fix:** Wrap the per-tool projection in a `rescue` and skip (or log) failing tools, so one bad tool does not block the entire listing:

```elixir
defp handle_method(conn, id, "tools/list", _params) do
  tools =
    Cairnloop.ToolRegistry.list_all_tools()
    |> Enum.flat_map(fn {mod, spec} ->
      try do
        [Cairnloop.Web.MCP.ToolProjector.spec_to_mcp({mod, spec})]
      rescue
        e ->
          Logger.warning("ToolProjector failed for #{inspect(mod)}: #{inspect(e)}")
          []
      end
    end)

  json_result(conn, id, %{"tools" => tools})
end
```

---

### WR-02: MCP Router rejects JSON-RPC notifications (`"id"`-less requests) with `-32600 Invalid Request` instead of silently discarding them per the JSON-RPC 2.0 spec

**File:** `lib/cairnloop/web/mcp/router.ex:46-53`

**Issue:**

The `call/2` pattern match requires `"id" => id`:

```elixir
{:ok, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = req} <-
  Jason.decode(body)
```

A JSON-RPC 2.0 Notification is a valid request object without an `"id"` field (e.g., `{"jsonrpc":"2.0","method":"notifications/initialized"}`). The MCP 2025-03-26 protocol sends `notifications/initialized` from the client to the server after initialization. The Router's `else` clause treats this as a parse failure and returns `-32600 Invalid Request`, which (a) is the wrong error code (notifications do not expect a response at all) and (b) violates the JSON-RPC 2.0 spec which says the server MUST NOT reply to a notification.

Although the Router's stated scope is only `initialize` and `tools/list`, the incorrect error response to a valid notification could confuse strict MCP clients.

**Fix:** Distinguish notifications from invalid requests in the `with` pipeline:

```elixir
def call(conn, _opts) do
  with {:ok, body, conn} <- Plug.Conn.read_body(conn),
       {:ok, decoded} <- Jason.decode(body) do
    case decoded do
      %{"jsonrpc" => "2.0", "id" => id, "method" => method} = req ->
        handle_method(conn, id, method, Map.get(req, "params", %{}))

      %{"jsonrpc" => "2.0", "method" => _method} ->
        # JSON-RPC 2.0 Notification — server MUST NOT respond
        send_resp(conn, 200, "")

      _ ->
        json_error(conn, nil, -32600, "Invalid Request")
    end
  else
    _ -> json_error(conn, nil, -32600, "Invalid Request")
  end
end
```

---

### WR-03: `ToolRegistry.list_all_tools/0` calls `mod.__tool_spec__()` without `Code.ensure_loaded!/1` — can return a `FunctionClauseError` if a module is not yet loaded

**File:** `lib/cairnloop/tool_registry.ex:65-68`

**Issue:**

`validate_configured_tools!/0` (called at boot) calls `Code.ensure_loaded!/1` before checking each tool module. `list_all_tools/0` does not:

```elixir
def list_all_tools do
  configured_tools = Application.get_env(:cairnloop, :tools, []) || []
  Enum.map(configured_tools, fn mod -> {mod, mod.__tool_spec__()} end)
end
```

If `list_all_tools/0` is called in a context where `validate_configured_tools!/0` has not yet run (e.g., a hot-code-reload scenario, a test that manipulates the config, or if the host conditionally calls the validator), an unloaded module yields `UndefinedFunctionError` on `mod.__tool_spec__()`. The same gap exists in `find_tool_module/1` and `get_available_tools/2`, though those are guarded by `validate_configured_tools!` in practice.

**Fix:** Add `Code.ensure_loaded!/1` (or a guarded variant) inside `list_all_tools/0`, mirroring `validate_configured_tools!/0`:

```elixir
def list_all_tools do
  configured_tools = Application.get_env(:cairnloop, :tools, []) || []
  Enum.flat_map(configured_tools, fn mod ->
    case Code.ensure_loaded(mod) do
      {:module, _} -> [{mod, mod.__tool_spec__()}]
      {:error, _} -> []
    end
  end)
end
```

---

## Info

### IN-01: `Traces.emit/2` call in `governance.ex update_approval_with_event/3` passes `Map.get(event_attrs, :event_type)` — indirection is unnecessary; prefer direct atom

**File:** `lib/cairnloop/governance.ex:124`

**Issue:**

```elixir
Traces.emit(Map.get(event_attrs, :event_type), %{...})
```

`event_attrs` is a literal map constructed by the caller with an atom key `:event_type`. The `Map.get/2` is an indirection that makes the event atom invisible to static analysis tools and cross-reference searches. All other `Traces.emit/2` call sites in the codebase pass the event atom directly. Since `Traces.emit/2` has a guard-clause no-op for unknown atoms (D17-05), passing `nil` (if `:event_type` were somehow absent) is safe but silently swallowed — no telemetry fires. Consistent direct atoms are both clearer and grep-able.

**Fix:** Destructure or use the atom directly in each call site, e.g.:

```elixir
Traces.emit(event_attrs.event_type, %{...})
```

---

### IN-02: Duplicated `humanize_reason/1` and `rebuild_context_from_snapshot/1` across `ApprovalResumeWorker` and `ToolExecutionWorker`

**File:** `lib/cairnloop/workers/approval_resume_worker.ex:207-228`, `lib/cairnloop/workers/tool_execution_worker.ex:491-512`; and lines 107-141 / 388-418 respectively.

**Issue:**

Both workers carry byte-for-byte identical private implementations of `humanize_reason/1` and `rebuild_context_from_snapshot/1`. The comments acknowledge this ("NOTE: mirrors ..."). If the humanization logic or the JSONB rehydration logic changes (e.g., a new scope format), both files must be updated in lockstep. In practice one copy will drift.

**Fix:** Extract both functions to a shared internal module (e.g., `Cairnloop.Workers.Helpers` or `Cairnloop.Governance.WorkerHelpers`) and `alias` it from both workers. Since the project seals completed phases, this refactor should be done in a dedicated cleanup task rather than retroactively touching Phase 15/16 code, but the duplication should not grow further.

---

_Reviewed: 2026-05-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
