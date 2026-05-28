---
phase: 29-brand-token-css-extraction-d-10-closure
plan: "03"
subsystem: integration-tests
tags:
  - brand-tokens
  - integration-tests
  - test-pin
  - d-10-closure
dependency_graph:
  requires:
    - 29-02
  provides:
    - brand-03-closed
    - headless-token-contract-re-pinned
  affects:
    - test/integration/approval_footer_live_test.exs
    - test/integration/tool_execution_outcome_live_test.exs
    - test/integration/bulk_recovery_live_test.exs
tech_stack:
  added: []
  patterns:
    - "Bare var(--cl-token) assertions with closing paren (Pitfall 8 strictness)"
    - "Never-color-alone contract preserved via surrounding text/SVG assertions"
key_files:
  created: []
  modified:
    - test/integration/approval_footer_live_test.exs
    - test/integration/tool_execution_outcome_live_test.exs
    - test/integration/bulk_recovery_live_test.exs
decisions:
  - "Closing paren preserved in all 6 re-pinned literals per Pitfall 8 — bare-token strictness excludes future hex-fallback regression"
  - "replace_all used for the 3-site tool_execution_outcome_live_test.exs change (all same token); 2 separate edits for bulk_recovery_live_test.exs (different tokens)"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-28"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 3
---

# Phase 29 Plan 03: Integration Test Re-pin (BRAND-03) Summary

**One-liner:** Re-pinned all 6 hex-fallback assertions (`var(--cl-primary, #A94F30)` / `var(--cl-danger, #B54C36)`) across 3 integration test files to bare `var(--cl-token)` form with closing paren, closing BRAND-03.

## What Was Built

Updated 3 integration test files to match the bare-token rendered HTML output from Plan 02 (which dropped `, #hex` suffixes from render code). Each re-pinned assertion preserves the closing parenthesis per Pitfall 8 — strictness check: `"var(--cl-primary)"` not `"var(--cl-primary"` — ensuring future hex-fallback regression is excluded, not silently admitted.

### Re-pin table (6 sites, 3 files)

| File | Line | Before | After |
|------|------|--------|-------|
| test/integration/approval_footer_live_test.exs | 52 | `"var(--cl-primary, #A94F30)"` | `"var(--cl-primary)"` |
| test/integration/tool_execution_outcome_live_test.exs | 316 | `"var(--cl-primary, #A94F30)"` | `"var(--cl-primary)"` |
| test/integration/tool_execution_outcome_live_test.exs | 394 | `"var(--cl-primary, #A94F30)"` | `"var(--cl-primary)"` |
| test/integration/tool_execution_outcome_live_test.exs | 443 | `"var(--cl-primary, #A94F30)"` | `"var(--cl-primary)"` |
| test/integration/bulk_recovery_live_test.exs | 99 | `"var(--cl-primary, #A94F30)"` | `"var(--cl-primary)"` |
| test/integration/bulk_recovery_live_test.exs | 267 | `"var(--cl-danger, #B54C36)"` | `"var(--cl-danger)"` |

All surrounding never-color-alone context preserved byte-for-byte: text labels (`"2 selected"`, `"Send recovery follow-up to 2"`, `"Batch too large."`, `"safe send limit of 2"`, `"Status chip must use brand token (never hardcoded hex)"`), SVG icon assertions (`assert html =~ "<svg"`), and approval footer affordances.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Re-pin 1 assertion in approval_footer_live_test.exs (line 52) | 23d8ff1 | test/integration/approval_footer_live_test.exs |
| 2 | Re-pin 3 assertions in tool_execution_outcome_live_test.exs (lines 316, 394, 443) | 731aa7b | test/integration/tool_execution_outcome_live_test.exs |
| 3 | Re-pin 2 assertions in bulk_recovery_live_test.exs (lines 99 + 267) | 9c123ea | test/integration/bulk_recovery_live_test.exs |

## Verification Results

- `grep -rE '"var\(--cl-(primary|danger), #' test/integration/...` returns nothing (0 hex-fallback patterns remain) ✓
- `grep -c 'assert html =~ "var(--cl-primary)"' ...` across all 3 files = 5 (1 + 3 + 1) ✓
- `grep -c 'assert html =~ "var(--cl-danger)"' bulk_recovery_live_test.exs` = 1 ✓
- `mix compile --warnings-as-errors` exits 0 ✓
- `mix test test/cairnloop/web/brand_token_gate_test.exs` exits 0 (BRAND-04 gate unaffected) ✓
- `mix test.integration` against live Postgres: requires dockerized pgvector (REPO-UNAVAILABLE in this workspace); compile + string inspection are the available proof. CI integration lane is the authoritative gating signal.

## Deviations from Plan

None — plan executed exactly as written. All 6 assertions re-pinned in 3 commits, closing parens preserved at every site.

## Known Stubs

None — this plan modifies test assertion strings only. No data sources, no UI rendering, no stubs.

## Threat Flags

None — test-only file edits with no new network endpoints, auth paths, file access patterns, or schema changes.

## Phase 29 Completion

With Plan 03 complete, all 4 Phase 29 / BRAND criteria are satisfied:

1. **BRAND-01** (Plan 01): Canonical `:root` block + `@theme` + `[data-theme="dark"]` landed in `examples/cairnloop_example/assets/css/app.css`.
2. **BRAND-02** (Plan 02): Zero `var(--cl-<token>, #hex)` strings in all 4 render files.
3. **BRAND-03** (Plan 03 — this plan): All 6 hex-fallback assertions re-pinned to bare `var(--cl-token)` form.
4. **BRAND-04** (Plan 02): Negative-grep gate in `test/cairnloop/web/brand_token_gate_test.exs` prevents re-introduction.

D-10 deferred decision from vM013 close is resolved via Option B (drop hex fallback, not migrate to named CSS classes).

## Self-Check: PASSED

- `test/integration/approval_footer_live_test.exs` exists and contains `assert html =~ "var(--cl-primary)"` ✓
- `test/integration/tool_execution_outcome_live_test.exs` exists and contains 3 bare-token assertions ✓
- `test/integration/bulk_recovery_live_test.exs` exists and contains primary + danger bare-token assertions ✓
- Commit `23d8ff1` exists in git log ✓
- Commit `731aa7b` exists in git log ✓
- Commit `9c123ea` exists in git log ✓
