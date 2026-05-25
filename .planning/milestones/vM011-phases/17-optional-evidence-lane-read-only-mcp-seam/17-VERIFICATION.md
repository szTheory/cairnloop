---
phase: 17-optional-evidence-lane-read-only-mcp-seam
verified: 2026-05-25T16:32:00Z
status: passed
score: 13/13 must-haves verified
overrides_applied: 0
re_verification: false
gaps: []
deferred: []
human_verification: []
---

# Phase 17: Optional Evidence Lane & Read-Only MCP Seam Verification Report

**Phase Goal:** The internal governed-action contract can project into optional evidence adapters and a read-only MCP seam without changing core approval or execution truth.
**Verified:** 2026-05-25T16:32:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Traces.emit(:execution_succeeded, attrs) fires [:cairnloop, :governance, :trace, :execution_succeeded] | VERIFIED | `traces.ex:85-91` — 4-segment event path; `traces_test.exs:46-56` passes (8/8 tests) |
| 2 | Emitted trace metadata carries openinference.span.kind, tool_proposal_id, actor_id; does NOT carry policy_snapshot content or input payloads | VERIFIED | `build_metadata/2` in `traces.ex:111-119` — only attribution refs; `traces_test.exs:102-127` negative assertions pass |
| 3 | Calling Traces.emit(:unknown_event, attrs) silently returns :ok and fires no telemetry event | VERIFIED | Guard-clause no-op `traces.ex:94`; `traces_test.exs:134-153` — refute_receive 100ms passes |
| 4 | Attaching a handler to [:cairnloop, :governance, :proposal_created] does NOT fire when Traces.emit(:proposal_created, ...) is called (namespace isolation) | VERIFIED | `traces_test.exs:159-184` — 3-segment vs 4-segment path isolation; test passes |
| 5 | POST / with method tools/list returns JSON-RPC 2.0 response with result.tools array (HTTP 200) | VERIFIED | `router.ex:73-78`; `router_test.exs:50-66` passes |
| 6 | POST / with method initialize returns protocolVersion 2025-03-26 and capabilities: {tools: {}} | VERIFIED | `router.ex:60-71`; `router_test.exs:73-95` passes |
| 7 | POST / with method tools/call returns JSON-RPC -32601 Method not found error (HTTP 200) | VERIFIED | `router.ex:83-85` catch-all; `router_test.exs:102-114` passes |
| 8 | InternalNote Spec projects to MCP tool definition with name Elixir.Cairnloop.Tools.InternalNote, correct inputSchema, x-cairnloop-* extension fields | VERIFIED | `tool_projector.ex:46-55`; `tool_projector_test.exs:32-61` passes |
| 9 | inputSchema for InternalNote has properties conversation_id and content (both type string), required: [conversation_id, content], NO id property | VERIFIED | `derive_input_schema/1` in `tool_projector.ex:64-80` excludes :id; test assertions at lines 48-56 pass |
| 10 | 7 additive Traces.emit call sites exist across governance.ex (4), tool_execution_worker.ex (2), approval_resume_worker.ex (1) | VERIFIED | grep -c confirms 4/2/1; all aliased; placed after bounded-metrics telemetry, before return values |
| 11 | lib/cairnloop/governance/telemetry.ex is UNCHANGED (sealed module not churned) | VERIFIED | `git diff lib/cairnloop/governance/telemetry.ex` — empty output |
| 12 | mix compile --warnings-as-errors passes with zero warnings on all modified files | VERIFIED | `mix compile --warnings-as-errors` exits 0 with no output |
| 13 | mix test --warnings-as-errors exits 0 (full headless suite, excluding known baseline failure) | VERIFIED | 541 tests, 1 failure = pre-existing `Automation.DraftTest` M005 drift (baseline, not a regression) |

**Score:** 13/13 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/governance/telemetry/traces.ex` | OI-conformant trace event module with @events | VERIFIED | 12-atom @events list, 2-arity emit/2, guard-clause no-op, build_metadata/2, span_kind_for/1, direct :telemetry.execute/3 — 129 lines, fully substantive |
| `test/cairnloop/governance/telemetry/traces_test.exs` | Trace event emission + namespace isolation proof | VERIFIED | async: false, 8 tests — span kinds, attribution fields, payload-content exclusion, guard no-op, namespace isolation |
| `lib/cairnloop/web/mcp/tool_projector.ex` | Pure Spec->MCP tool definition transform | VERIFIED | spec_to_mcp/1, derive_input_schema/1, ecto_type_to_json_schema/1 — 92 lines, fully substantive |
| `lib/cairnloop/web/mcp/router.ex` | Optional JSON-RPC 2.0 Plug for tools/list and initialize | VERIFIED | @behaviour Plug, handle_method/4 dispatching on string method, json_result/3, json_error/4 — 109 lines |
| `lib/cairnloop/tool_registry.ex` | list_all_tools/0 — unfiltered tool listing for MCP | VERIFIED | Additive at line 64-68; uses Application.get_env(:cairnloop, :tools, []) || [] pattern; existing API untouched |
| `test/cairnloop/web/mcp/tool_projector_test.exs` | InternalNote Spec->MCP round-trip proof (D17-10) | VERIFIED | async: true, 2 tests — full round-trip + x-cairnloop string values |
| `test/cairnloop/web/mcp/router_test.exs` | JSON-RPC routing shape proofs | VERIFIED | async: true, 5 tests — tools/list, initialize, tools/call, unknown method, malformed JSON |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/cairnloop/governance.ex` | `lib/cairnloop/governance/telemetry/traces.ex` | `alias Cairnloop.Governance.Telemetry.Traces` + `Traces.emit` | WIRED | Line 63 alias; 4 Traces.emit calls at lines 124, 360, 484, 865 |
| `lib/cairnloop/workers/tool_execution_worker.ex` | `lib/cairnloop/governance/telemetry/traces.ex` | `alias Cairnloop.Governance.Telemetry.Traces` + `Traces.emit` | WIRED | Line 47 alias; 2 Traces.emit calls at lines 222, 292 |
| `lib/cairnloop/workers/approval_resume_worker.ex` | `lib/cairnloop/governance/telemetry/traces.ex` | `alias Cairnloop.Governance.Telemetry.Traces` + `Traces.emit` | WIRED | Line 41 alias; 1 Traces.emit call at line 182 |
| `lib/cairnloop/web/mcp/router.ex` | `lib/cairnloop/tool_registry.ex` | `Cairnloop.ToolRegistry.list_all_tools/0` | WIRED | Fully-qualified call at line 75 inside tools/list handler |
| `lib/cairnloop/web/mcp/router.ex` | `lib/cairnloop/web/mcp/tool_projector.ex` | `Cairnloop.Web.MCP.ToolProjector.spec_to_mcp/1` | WIRED | Fully-qualified call at line 76 via Enum.map |
| `lib/cairnloop/web/mcp/tool_projector.ex` | `lib/cairnloop/tool/spec.ex` | `%Cairnloop.Tool.Spec{}` struct field access | WIRED | `spec.title`, `spec.description`, `spec.risk_tier`, `spec.approval_mode` at lines 49-53 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `router.ex` tools/list handler | `tools` list | `ToolRegistry.list_all_tools/0` → Application.get_env(:cairnloop, :tools) | Yes — reads actual configured tool modules at runtime | FLOWING |
| `tool_projector.ex` spec_to_mcp/1 | inputSchema | `tool_module.changeset(struct(tool_module), %{})` Ecto reflection | Yes — derives from real module's changeset cs.required / cs.types | FLOWING |
| `traces.ex` emit/2 | telemetry metadata | `build_metadata/2` from caller-supplied attrs (proposal.id, actor_id, etc.) | Yes — populated from live Ecto record fields at each call site | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 8 traces_test.exs tests pass | `mix test test/cairnloop/governance/telemetry/traces_test.exs --warnings-as-errors` | 8 tests, 0 failures | PASS |
| 7 MCP tests pass | `mix test test/cairnloop/web/mcp/ --warnings-as-errors` | 7 tests, 0 failures | PASS |
| Full headless suite | `mix test --warnings-as-errors` | 541 tests, 1 failure (pre-existing DraftTest baseline) | PASS |
| No atom exhaustion risk in Router | `grep -c "String.to_atom\|to_existing_atom" lib/cairnloop/web/mcp/router.ex` | 0 | PASS |
| Sealed telemetry.ex unchanged | `git diff lib/cairnloop/governance/telemetry.ex` | empty | PASS |

---

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` files declared in PLAN or present in the repository for this phase.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MCP-01 | M011-S05-01, M011-S05-02 | Core governed-tool metadata can map cleanly to an optional read-only MCP seam without changing the internal approval and execution model | SATISFIED | `ToolProjector.spec_to_mcp/1` projects Spec structs; `Router` handles tools/list + initialize; no run/3 or propose/3 path reachable from Router; all 7 Phase 17 must-have truths verify clean |

**REQUIREMENTS.md traceability row for MCP-01:** Listed as "Phase 17 — Pending". This phase closes it.

---

### Anti-Patterns Found

No TBD, FIXME, or XXX markers found in any modified file. No HACK, PLACEHOLDER, or "not yet implemented" markers. No empty implementations. No hardcoded empty returns in data paths.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

---

### Human Verification Required

None. All must-haves are verifiable programmatically via tests and static analysis. The MCP Router has no visual UI surface. The evidence-lane telemetry is proven via test assertions on the emitted metadata shape.

---

### Gaps Summary

No gaps found. All 13 must-have truths are verified. All 7 artifacts are substantive and wired. All 6 key links are confirmed. Both plan suites (8 traces tests + 7 MCP tests) pass with warnings-as-errors. The full headless suite has exactly 1 failure, which is the pre-existing `Automation.DraftTest` M005 drift baseline documented in CLAUDE.md and memory. The sealed `lib/cairnloop/governance/telemetry.ex` module is unchanged. The 7 additive Traces.emit call sites (4+2+1) are placed exactly as specified — after bounded-metrics telemetry, before success return values — and are fire-and-forget. MCP-01 is satisfied: governed-tool metadata maps to a read-only MCP seam with no change to the internal approval or execution model.

---

_Verified: 2026-05-25T16:32:00Z_
_Verifier: Claude (gsd-verifier)_
