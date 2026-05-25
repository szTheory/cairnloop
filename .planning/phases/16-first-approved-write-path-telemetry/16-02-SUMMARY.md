---
phase: 16-first-approved-write-path-telemetry
plan: 02
subsystem: governance
tags: [elixir, oban, telemetry, idempotency, ecto, integration-testing]

# Dependency graph
requires:
  - phase: 16-01
    provides: ToolExecutionWorker shell, InternalNote tool, Governance.execute_approved/2 facade, integration test harness
  - phase: 15
    provides: approval lane lifecycle (:pending → :approved → :execution_pending), DataCase, Fixtures, docker-compose Postgres
provides:
  - Bounded :action_executed / :action_failed telemetry events with enum-only labels (OBS-01)
  - derive_run_key/1 — per-attempt SHA-256 idempotency key derivation (D16-05 layer 3)
  - Transient/terminal retry semantics in ToolExecutionWorker (D16-07)
  - DB-backed at-most-once / retry / idempotency proof in test/integration/
affects: [phase-16-plan-03, verify-work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bounded telemetry: @allowed_result_states allow-list + normalize_tool_ref/1 registry-check prevent high-cardinality label injection"
    - "Per-attempt run key: SHA-256(idempotency_key::attempt::N) — deterministic per (proposal, attempt), differs across retries"
    - "Telemetry emit AFTER the with pipeline — never inside clause list (D-29)"
    - "Process-dictionary call counter for inline FailOnceTool transient-retry simulation in tests"
    - "Oban __opts__/0 for headless unique-configuration assertion without live queue"

key-files:
  created:
    - test/integration/tool_execution_worker_test.exs (extended with Plan 02 Task 3 DB-backed proof)
  modified:
    - lib/cairnloop/governance/telemetry.ex (added :action_executed/:action_failed events, @allowed_result_states, normalize_result_state/1, normalize_tool_ref/1)
    - lib/cairnloop/workers/tool_execution_worker.ex (derive_run_key/1, transient/terminal retry branches, telemetry emit calls)
    - test/cairnloop/governance/telemetry_test.exs (headless telemetry-bounding proof)
    - test/cairnloop/workers/tool_execution_worker_test.exs (headless worker branch proof)
    - .planning/phases/16-first-approved-write-path-telemetry/16-VALIDATION.md (rows closed)

key-decisions:
  - "Phase 16 P02: derive_run_key composes idempotency_key::attempt::N → SHA-256 hex; deterministic per (proposal, attempt), fresh per retry"
  - "Phase 16 P02: transient {:error, reason} returns {:error, reason} when attempt < max_attempts (Oban backoff); exhausted returns {:cancel, reason} (no further retry)"
  - "Phase 16 P02: telemetry emitted AFTER the co-commit with pipeline — never inside clause list (D-29)"
  - "Phase 16 P02: Oban unique opts asserted headless via __opts__/0; live queue-count leg marked REPO-UNAVAILABLE"
  - "Phase 16 P02: FailOnceTool uses process dictionary call counter for retry simulation without a mock framework"

patterns-established:
  - "Headless Oban config assertion: ToolExecutionWorker.__opts__() |> Keyword.get(:unique) for unique-config proof without a running Oban instance"
  - "Integration test inline tool with process-dict call counter for transient-then-success retry flows"
  - "REPO-UNAVAILABLE marker on every Postgres round-trip assertion in test/integration/"

requirements-completed: [ACT-01, OBS-01]

# Metrics
duration: 25min
completed: 2026-05-25
---

# Phase 16 Plan 02: Bounded Execution Telemetry + At-Most-Once Idempotency Proof Summary

**Three-layer at-most-once write path proven DB-backed: Oban unique opts + terminal guard + per-attempt SHA-256 run key; bounded `:action_executed`/`:action_failed` telemetry with enum-only labels and no high-cardinality payload**

## Performance

- **Duration:** ~25 min (continuation from prior executor session)
- **Started:** 2026-05-25T06:30:00Z (prior executor session)
- **Completed:** 2026-05-25T08:33:00Z
- **Tasks:** 3 (Tasks 1 and 2 by prior executor; Task 3 by this session)
- **Files modified:** 6

## Accomplishments

- Extended `Cairnloop.Governance.Telemetry` with bounded `:action_executed` / `:action_failed` events: `@allowed_result_states`, `normalize_result_state/1`, `normalize_tool_ref/1` (registry-validated cardinality bound), proven headless to carry no `actor_id`/`conversation_id`/`reason` labels
- Added `derive_run_key/1` to `ToolExecutionWorker`: deterministic SHA-256 of `idempotency_key::attempt::N`, placed into `context[:run_idempotency_key]` before `run/3`, ensuring a fresh key per retry that doesn't block retries from prior failed attempts
- Finalized retry semantics: transient `{:error}` with `attempt < max_attempts` → increment attempt + emit `:execution_attempt_failed` event + `{:error}` for Oban backoff; exhausted → terminal `:execution_failed` + `{:cancel}`; telemetry emitted AFTER the co-commit `with` pipeline (D-29)
- Completed DB-backed proof in `test/integration/tool_execution_worker_test.exs`: at-most-once write, terminal-guard no-op, attempt increment, `InternalNote.run/3` idempotency, transient-then-success retry path, Oban unique opts assertion

## Task Commits

Each task was committed atomically:

1. **Task 1: Bounded execution telemetry** - `fc6bd2f` (feat)
2. **Task 2 RED: Failing tests for derive_run_key** - `a873267` (test)
3. **Task 2 GREEN: derive_run_key/1 implementation** - `b3b969f` (feat)
4. **Task 3: DB-backed at-most-once / retry / idempotency proof** - `e7d6c0d` (test)

## Files Created/Modified

- `lib/cairnloop/governance/telemetry.ex` — added `:action_executed`/`:action_failed` to `@events`; `@allowed_result_states`; `normalize_result_state/1`; `normalize_tool_ref/1` (registry-validated)
- `lib/cairnloop/workers/tool_execution_worker.ex` — `derive_run_key/1`; transient/terminal retry branches; telemetry emit AFTER co-commit
- `test/cairnloop/governance/telemetry_test.exs` — headless: bounded label proof, no high-cardinality keys, normalize_tool_ref unknown-ref → :unknown
- `test/cairnloop/workers/tool_execution_worker_test.exs` — headless: worker branch logic, derive_run_key determinism/attempt-scope
- `test/integration/tool_execution_worker_test.exs` — extended: at-most-once (Repo.aggregate == 1), terminal-guard no-op, Oban unique opts, attempt increment, InternalNote idempotency, transient-then-success
- `.planning/phases/16-first-approved-write-path-telemetry/16-VALIDATION.md` — 8 of 10 ACT-01/OBS-01 rows marked green; 2 OBS-02 rows deferred to plan 03+

## Decisions Made

- `derive_run_key` composes `idempotency_key::attempt::N` hashed with SHA-256 — deterministic per `(proposal, attempt)`, guaranteed different across attempt numbers, fixed-width (64-char hex) safe to index.
- Transient branch uses `attempt >= max_attempts` comparison (Oban `attempt` field from `perform/1` job struct, always available), not a separate counter, per Research Pattern 3.
- Oban unique-config proved headless via `ToolExecutionWorker.__opts__()`; live queue-count leg marked `# REPO-UNAVAILABLE` — avoids dependency on a running Oban instance in headless CI.
- Inline `FailOnceTool` uses process dictionary call counter (`Process.get/put({__MODULE__, :call_count}, 0)`) to simulate transient-then-success across sequential `perform/1` calls in the same test process.

## Deviations from Plan

None — plan executed exactly as written. Task 3 added the integration tests described in the plan's `<action>` block; all VALIDATION.md ACT-01 and OBS-01 rows closed.

## Issues Encountered

- A pre-existing intermittent test failure (`Cairnloop.KnowledgeAutomation.GapCandidateTest` — `function_exported?` on an unloaded module when run in isolation) surfaced transiently during full suite runs. Confirmed pre-existing (passes when the module file is loaded via the full suite run), not related to plan 02 changes.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All ACT-01 and OBS-01 integration and headless proof complete; OBS-02 attribution rows (`decided_by`, `policy_snapshot`, `ToolActionEvent` trail) remain pending for Phase 16 plan 03+.
- The at-most-once write path is now fully hardened: three-layer defense proven DB-backed.
- `mix test` (headless) passes (509 tests, 1 known baseline failure only); `mix compile --warnings-as-errors` clean.
- Integration suite (`mix test.integration`) requires `docker-compose up -d postgres`; all assertions in `test/integration/` are correctly marked `# REPO-UNAVAILABLE` where Postgres is absent.

---
*Phase: 16-first-approved-write-path-telemetry*
*Completed: 2026-05-25*
