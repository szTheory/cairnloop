---
phase: 17-optional-evidence-lane-read-only-mcp-seam
plan: M011-S05-01
subsystem: governance/telemetry
tags: [telemetry, traces, openinference, evidence-lane, observability]
dependency_graph:
  requires: []
  provides: [Cairnloop.Governance.Telemetry.Traces]
  affects:
    - lib/cairnloop/governance.ex
    - lib/cairnloop/workers/tool_execution_worker.ex
    - lib/cairnloop/workers/approval_resume_worker.ex
tech_stack:
  added: []
  patterns:
    - OI-conformant telemetry trace events with 4-segment namespace
    - build_metadata/2 payload-content exclusion shape
    - Guard-clause no-op for unknown events
    - Fire-and-forget additive call sites after bounded-metrics telemetry
decisions:
  - Traces module calls :telemetry.execute/3 directly with no aliases to Cairnloop.Telemetry or Cairnloop.Governance.Telemetry (zero Scoria dependency, D17-03)
  - 2-arity emit/2 (not 3-arity) — measurements always %{count: 1}, callers don't supply measurements
  - string key "openinference.span.kind" per OI spec; attribution keys remain atoms
  - policy_snapshot_ref = tool_proposal_id (ref only, never content, D17-02)
key_files:
  created:
    - lib/cairnloop/governance/telemetry/traces.ex
    - test/cairnloop/governance/telemetry/traces_test.exs
  modified:
    - lib/cairnloop/governance.ex
    - lib/cairnloop/workers/tool_execution_worker.ex
    - lib/cairnloop/workers/approval_resume_worker.ex
metrics:
  duration: 10 minutes
  completed: "2026-05-25T14:18:58Z"
  tasks: 3
  files: 5
---

# Phase 17 Plan M011-S05-01: OI Trace Event Module + 7 Call Sites Summary

**One-liner:** OI-conformant `Cairnloop.Governance.Telemetry.Traces` module with 12-atom event registry, span-kind routing (TOOL/GUARDRAIL), payload-content exclusion, and 7 additive emit call sites across governance + workers — zero Scoria dependency.

## What Was Built

### Task 1: Failing test stubs (RED) — ef14983

Created `test/cairnloop/governance/telemetry/traces_test.exs` with 8 tests covering:
- OI span kind assertions (`:execution_succeeded` → TOOL, `:approval_requested` / `:proposal_created` → GUARDRAIL)
- Attribution field presence (`tool_proposal_id`, `actor_id` in metadata)
- Payload content exclusion (`:content`, `:input_snapshot` must not appear in metadata, D17-02)
- Guard-clause no-op for unknown event atom (D17-05)
- Namespace isolation: 4-segment trace path does NOT fire handlers on 3-segment bounded-metrics path (D17-01)

All 8 tests failed at RED because `Cairnloop.Governance.Telemetry.Traces` did not exist.

### Task 2: Implement Traces module (GREEN) — d9b9d7d

Created `lib/cairnloop/governance/telemetry/traces.ex`:

- `@events` list of 12 atoms covering full proposal/approval/execution lifecycle
- `emit/2` (2-arity): fires `[:cairnloop, :governance, :trace, event]` (4-segment OI path)
- `emit/2` guard-clause no-op: unknown events return `:ok`, no `:telemetry.execute` call
- `build_metadata/2`: only attribution refs — `"openinference.span.kind"` (string key per OI spec), `:tool_proposal_id`, `:actor_id`, `:policy_snapshot_ref`, `:decided_by`, `:attempt`. No `:content`, `:input_snapshot`, `:policy_snapshot`
- `span_kind_for/1`: TOOL for `[:execution_started, :execution_succeeded, :execution_failed]`, GUARDRAIL for all others
- Direct `:telemetry.execute/3` call — no aliases to `Cairnloop.Telemetry` or `Cairnloop.Governance.Telemetry`

All 8 tests passed GREEN. `mix compile --warnings-as-errors` clean.

### Task 3: Wire 7 additive call sites — ae284b7

**`lib/cairnloop/governance.ex`** (4 sites):
1. `insert_new_proposal/6`: `Traces.emit(:proposal_created, ...)` after bounded-metrics, before `{:ok, proposal}`
2. `insert_blocked_proposal/10`: `Traces.emit(:proposal_blocked, ...)` after bounded-metrics, before `:ok`
3. `update_approval_with_event/3`: `Traces.emit(event_type, ...)` after `Cairnloop.Telemetry.execute`, before `{:ok, updated_approval}`
4. `execute_approved/2`: `Traces.emit(:execution_started, ...)` after `enqueue_fn`, before `{:ok, updated}`

**`lib/cairnloop/workers/tool_execution_worker.ex`** (2 sites):
5. `record_success/6`: `Traces.emit(:execution_succeeded, ...)` after `GovTelemetry.emit(:action_executed, ...)`, before `broadcast_executed`
6. `handle_transient_failure/6` terminal branch: `Traces.emit(:execution_failed, ...)` after `GovTelemetry.emit(:action_failed, ...)`, before `broadcast_execution_failed`

**`lib/cairnloop/workers/approval_resume_worker.ex`** (1 site):
7. `transition_approval/5`: `Traces.emit(event_type, ...)` after `Cairnloop.Telemetry.execute`, before `{:ok, updated}`

## Verification

```
mix compile --warnings-as-errors         → 0 warnings, exits 0
mix test traces_test.exs --warnings-as-errors → 8 tests, 0 failures
mix test --warnings-as-errors            → 534 tests, 1 failure (pre-existing Automation.DraftTest M005 drift baseline)
git diff lib/cairnloop/governance/telemetry.ex → (empty — UNCHANGED)
grep -c Traces.emit governance.ex        → 4
grep -c Traces.emit tool_execution_worker.ex → 2
grep -c Traces.emit approval_resume_worker.ex → 1
```

## Deviations from Plan

None — plan executed exactly as written.

All 7 call sites are placed exactly as specified: additive, fire-and-forget, after existing bounded-metrics telemetry, before the success return value. The sealed `lib/cairnloop/governance/telemetry.ex` module was not modified.

## Known Stubs

None — all trace emission call sites are fully wired. The `Traces` module emits real `:telemetry.execute/3` events.

## Threat Flags

No new security-relevant surface beyond what was planned. All metadata crosses the telemetry boundary as attribution refs (IDs, atom enums) only — confirmed by `build_metadata/2` shape and asserted in negative tests.

T-17-01-01 (Information Disclosure) mitigation verified: `:content`, `:input_snapshot`, `:policy_snapshot` keys do not appear in emitted metadata.

T-17-01-02 (Tampering / namespace isolation) mitigation verified: dedicated namespace isolation test confirms 4-segment trace path does not fire handlers on the 3-segment bounded-metrics path.

## TDD Gate Compliance

- RED gate: `test(17-M011-S05-01)` commit ef14983 — 8 failing stubs before Traces module existed
- GREEN gate: `feat(17-M011-S05-01)` commit d9b9d7d — Traces module makes all 8 tests pass
- REFACTOR gate: not needed — implementation was clean on first pass

## Self-Check

Verified:
- [x] `lib/cairnloop/governance/telemetry/traces.ex` exists
- [x] `test/cairnloop/governance/telemetry/traces_test.exs` exists
- [x] Commits ef14983, d9b9d7d, ae284b7 present in git log
- [x] `governance/telemetry.ex` unchanged (git diff empty)
- [x] 7 call sites total (4+2+1) confirmed via grep
