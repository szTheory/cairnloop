---
phase: 15-approval-state-machine-oban-resume
plan: "02"
subsystem: governance-workers-policy
tags: [approval-resume, approval-expiry, oban-worker, policy-pdp, fail-closed, tdd, wave-2]
dependency_graph:
  requires:
    - "15-01"
  provides:
    - lib/cairnloop/workers/approval_resume_worker.ex
    - lib/cairnloop/workers/approval_expiry_worker.ex
    - lib/cairnloop/governance/policy.ex (extended)
  affects:
    - "15-03"
    - "15-04"
tech_stack:
  added: []
  patterns:
    - "ApprovalResumeWorker: re-validate-before-execute gate (Terraform stale-plan semantics)"
    - "Lazy expires_at guard fires BEFORE re-validation — defense-in-depth (D15-12)"
    - "Sequential `with` co-commit: update approval + insert ToolActionEvent (NOT Ecto.Multi)"
    - "MockRepo + Application.put_env injection for headless Oban worker testing"
    - "PassTool/ScopeFailTool test fixtures for headless validate-pass and validate-fail coverage"
    - "Policy.resolve/3 apply_context_factors/4 pass-through PDP seam (D15-08 offered-not-enforced)"
    - "humanize_reason/1: traverse_errors/2 for changesets, Atom.to_string, pass-through (WR-01)"
    - "String.to_existing_atom/1 + rescue ArgumentError for JSONB key rehydration (D-19)"
    - "Telemetry emitted AFTER with success (D-29)"
key_files:
  created:
    - lib/cairnloop/workers/approval_resume_worker.ex
    - lib/cairnloop/workers/approval_expiry_worker.ex
  modified:
    - lib/cairnloop/governance/policy.ex
    - test/cairnloop/workers/approval_resume_worker_test.exs
    - test/cairnloop/workers/approval_expiry_worker_test.exs
decisions:
  - "Added PassTool + ScopeFailTool test modules in approval_resume_worker_test.exs to enable headless validate-pass (id=1→:execution_pending) and validate-fail (id=5→:invalidated) paths without Repo; tool_ref uses Atom.to_string so ToolRegistry.find_tool_module can resolve it"
  - "perform/1 always returns :ok regardless of transition helper result — Oban workers must return :ok for success, not {:ok, struct}"
  - "rebuild_context_from_snapshot/1 handles both atom-key maps (runtime structs) and string-key maps (JSONB rehydration path) for scope_snapshot and input_snapshot"
  - "Telemetry uses Cairnloop.Telemetry.execute/3 directly for :approval_transition — Governance.Telemetry module only covers proposal events and is not extended in Phase 15"
metrics:
  duration: "~4 min"
  completed_date: "2026-05-24"
  tasks: 2
  files_created: 2
  files_modified: 3
---

# Phase 15 Plan 02: Oban Workers + Policy PDP Seam Summary

ApprovalResumeWorker (re-validate-before-execute gate with lazy expiry guard), ApprovalExpiryWorker (scheduled :pending→:expired flip), and Policy.resolve/3 PDP seam extension — all Wave 0 worker tests turned green.

## What Was Built

### ApprovalResumeWorker (`lib/cairnloop/workers/approval_resume_worker.ex`)

THE Phase 15 deliverable: the re-validate-before-execute gate (Terraform "stale plan" semantics).

- `use Oban.Worker, queue: :default, unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]` — double-enqueue protection (D15-09)
- `perform/1` branch logic:
  1. `nil` → `:ok` (deleted, idempotent no-op)
  2. `:pending` + `expires_at < now` → `:expired` + `:expired` event (lazy guard, D15-12)
  3. `:pending` + `Governance.validate/3` pass → `:execution_pending` + `:revalidation_passed` event; **STOP** (never calls `run/3`, D15-10)
  4. `:pending` + `Governance.validate/3` fail → `:invalidated` + `:revalidation_failed` event with humanized reason (fail-closed, APRV-03)
  5. Any other status → `:ok` (idempotent no-op)
- `rebuild_context_from_snapshot/1`: reconstructs `%{scopes: [...], tool_params: %{...}}` from proposal snapshot fields; handles both atom-key and string-key maps (JSONB path); uses `String.to_existing_atom/1` + rescue `ArgumentError` for scope rehydration (D-19, T-15-08)
- `humanize_reason/1`: `traverse_errors/2` for changesets → `Atom.to_string/1` for atoms → pass-through for binaries → `"blocked"` fallback (WR-01, T-15-09); never `inspect/1`
- Sequential `with` co-commit (NOT Ecto.Multi); telemetry AFTER success (D-29)
- `defp repo, do: Application.fetch_env!(:cairnloop, :repo)` — headless/MockRepo testable

### ApprovalExpiryWorker (`lib/cairnloop/workers/approval_expiry_worker.ex`)

Scheduled `:pending → :expired` flip — the sweep half of the dual-mechanism TTL (D15-12).

- `use Oban.Worker, queue: :default` (no uniqueness — job is enqueued once at `scheduled_at: approval.expires_at` from plan 15-03)
- `perform/1`: `nil` → `:ok`; `:pending` → `expire_approval/1` (flip + event); `_` → `:ok`
- `expire_approval/1`: sequential `with` co-commit — update status `:expired` + insert `:expired` `ToolActionEvent`; telemetry after success (D-29)
- Mirrors `SlaCountdownWorker` `:active → :breached` idiom exactly

### Policy.resolve/3 extension (`lib/cairnloop/governance/policy.ex`)

Phase 15 PDP seam (D15-08) — actor-scope / four-eyes hook, offered NOT enforced.

- Renamed `_actor_id` → `actor_id` and `_context` → `context` (args now used)
- `base_mode` computation unchanged (same precedence: tool declaration → host config → tier default)
- Added `apply_context_factors(base_mode, tool_module, actor_id, context)` call
- `apply_context_factors/4` is a pass-through: returns `mode` unchanged
- No call-site changes (D-12 signature-fixed guarantee)
- Warnings-clean: no unused variable warnings

### Test updates

`approval_resume_worker_test.exs` — all `@tag :skip` removed, all tests now passing:
- Added `PassTool` (no required fields, scope: []) and `ScopeFailTool` (requires :admin_scope) test modules
- `setup` registers both tools in `Application.put_env(:cairnloop, :tools, [PassTool, ScopeFailTool])`
- Fixture id=1 → PassTool proposal (validates pass → `:execution_pending`)
- Fixture id=5 → ScopeFailTool proposal (scope fails → `:invalidated`)
- Fixture id=4 → expired timestamp → `:expired` (lazy guard)

`approval_expiry_worker_test.exs` — all `@tag :skip` removed, all tests now passing.

## Verification Results

```
mix compile --warnings-as-errors  → exit 0 (clean)
mix test test/cairnloop/workers/approval_resume_worker_test.exs
                                  → 9 tests, 0 failures
mix test test/cairnloop/workers/approval_expiry_worker_test.exs
                                  → 4 tests, 0 failures
mix test test/cairnloop/governance/ test/cairnloop/workers/ test/cairnloop/governance_test.exs
                                  → 133 tests, 0 failures, 7 skipped (Waves 3-4 remaining)
Chimeway.Repo boot noise          → pre-existing baseline (not a regression)
No .run( call in ApprovalResumeWorker → verified (grep + test assertion)
No String.to_atom/1 call in ApprovalResumeWorker → verified
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] perform/1 must return :ok, not {:ok, struct} from transition helper**
- **Found during:** Task 1 test run — test `assert :ok = ApprovalResumeWorker.perform(...)` failed because the `%ToolApproval{status: :pending}` branch was returning `{:ok, updated}` from `expire_approval/1` or `revalidate_and_transition/1`
- **Issue:** Oban `perform/1` must return `:ok` on success; the inner transition helpers return `{:ok, updated}` (the pattern for the `with` pipeline result), but `perform/1` must always return `:ok` regardless
- **Fix:** Added explicit `:ok` as the last expression in the `:pending` branch of `perform/1`
- **Files modified:** `lib/cairnloop/workers/approval_resume_worker.ex`
- **Commit:** 2b79dde (included in the same commit as the worker creation)

**2. [Rule 2 - Missing critical functionality] Test needs test tools registered in :cairnloop, :tools**
- **Found during:** Task 1 test design — `approval_resume_worker_test.exs` fixture id=10 referenced `"Cairnloop.GovernanceTest.ValidTool"` which (a) requires `order_id` so validate would fail with empty input_snapshot, and (b) is defined in another test module and not registered in `:cairnloop, :tools`
- **Issue:** The validate-pass test (id=1 → `:execution_pending`) would fail because `ToolRegistry.find_tool_module/1` looks up `:cairnloop, :tools` and `ValidTool` would not be found; additionally `ValidTool` requires `order_id` so validation would fail even if found
- **Fix:** Defined `PassTool` (no required fields, scope: []) and `ScopeFailTool` (requires :admin_scope) within the test module; updated MockRepo fixtures to use these tools; added `Application.put_env(:cairnloop, :tools, [PassTool, ScopeFailTool])` in setup
- **Files modified:** `test/cairnloop/workers/approval_resume_worker_test.exs`

### Notes on Plan Instructions Followed

- The plan allowed inline `humanize_reason/1` OR a shared helper; implemented inline per the `15-PATTERNS.md` "Shared Patterns" guidance since plan 15-01 exposed it only in governance.ex (not as a public shared helper)
- The validate-fail test uses `ScopeFailTool` + empty `scope_snapshot` → scope check fails → `{:blocked, :scope_invalid, reason}` → `:invalidated`; `reason` is `{:missing_scopes, [:admin_scope]}` → `humanize_reason/1` passes `{:missing_scopes, [:admin_scope]}` → the tuple falls through to `"blocked"` fallback (not raw term)

## Known Stubs

None — all implemented code paths are functional.

- `apply_context_factors/4` is intentionally a documented pass-through (D15-08: offered NOT enforced; no identity model in Phase 15). This is not a stub — it is the correct Phase 15 behavior.

## Threat Flags

None — all STRIDE threats from this plan's threat model are now mitigated:
- **T-15-05 (T-stale-exec):** `Governance.validate/3` re-called against current context; `{:blocked, ...}` → `:invalidated`, never proceeds; success stops at `:execution_pending` (no `run/3`).
- **T-15-06 (T-expired-exec):** Lazy `expires_at < now` guard fires BEFORE re-validation; approval cannot execute even if `ApprovalExpiryWorker` never ran.
- **T-15-07 (T-double-enqueue):** `unique: [period: :infinity, keys: [:approval_id]]`; `perform/1` re-checks status and no-ops if not `:pending`.
- **T-15-08 (T-unbounded-atoms):** `String.to_existing_atom/1` + rescue `ArgumentError` for all JSONB key rehydration; never `String.to_atom/1`.
- **T-15-09 (T-raw-terms):** `humanize_reason/1` uses `traverse_errors/2` / `Atom.to_string/1` / pass-through / `"blocked"` fallback; never `inspect/1`; test asserts no `#Ecto.Changeset<` in reason.
- **T-15-SC:** No package installs.

## Self-Check: PASSED
