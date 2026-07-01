---
phase: 40-drift-remediation-brand-token-gate-hardening
plan: "03"
subsystem: ci-gate
tags: [brand-token, credo, exunit, lint-gate, render-layer]
dependency_graph:
  requires: [40-01, 40-02]
  provides: [brand-token-hardened-gate, advisory-credo-check]
  affects: [lib/cairnloop/web/**/*.ex, test/cairnloop/web/brand_token_gate_test.exs, .credo.exs]
tech_stack:
  added: [Cairnloop.CredoChecks.NoHardcodedColor]
  patterns: [ExUnit-file-scan-gate, Credo-custom-check, cl-allow-color-sentinel, interpolation-strip-anchoring]
key_files:
  created:
    - lib/cairnloop/credo_checks/no_hardcoded_color.ex
  modified:
    - test/cairnloop/web/brand_token_gate_test.exs
    - .credo.exs
    - lib/cairnloop/web/components.ex
    - lib/cairnloop/web/inbox_live.ex
decisions:
  - "cl-allow-color sentinel suppresses violations on N and N+1; used for docstring color references in components.ex and inbox_live.ex (documentation context, not render output)"
  - "Credo check uses SourceFile.lines/1 which returns {line_no, line_text} tuples (not plain strings) — corrected from initial design"
  - "Two chained Enum.reject calls consolidated to avoid Credo's RejectReject check flagging its own module"
metrics:
  duration_minutes: 20
  completed_date: "2026-06-04"
  tasks_completed: 2
  files_changed: 5
---

# Phase 40 Plan 03: Brand-Token Gate Hardening + Advisory Credo Check Summary

Hardened the ExUnit brand-token gate to detect inline hex, raw rgba/hsl, and helper-returned hex in render `.ex` files. Added a complementary advisory Credo check mirroring the same patterns. The two remediated files (conversation_live.ex, search_modal_component.ex from 40-01/40-02) scan clean under both tools.

## What Was Built

**Task 1 — Hardened ExUnit gate** (`test/cairnloop/web/brand_token_gate_test.exs`):
- Added `@hex_color ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/` for bare hex (GATE-01 a+c)
- Added `@func_color ~r/\b(?:rgba?|hsla?)\(/` for function-color literals (GATE-01 b)
- `collect_violations/2`: strips `#{...}` interpolation, skips color-free comment lines, applies allowlist suppression
- `allowed_line_numbers/1`: lines containing `cl-allow-color` sentinel suppress violations on that line AND the next (covers same-line trailing comment and prev-line block comment)
- Fixture test: asserts all 6 FAIL cases are flagged, all 5 PASS cases are clean, and both allowlist forms (same-line + prev-line) suppress violations
- Hardened real-file scan: scans all `@web_dir` + `@example_live_dir` `.ex` files — finds zero violations
- DB-free: pure `File.read!` / string scan throughout

**Task 2 — Advisory Credo check** (`lib/cairnloop/credo_checks/no_hardcoded_color.ex` + `.credo.exs`):
- Module `Cairnloop.CredoChecks.NoHardcodedColor` with `use Credo.Check, id: "CL_NoHardcodedColor", base_priority: :low, category: :warning`
- Mirrors same `@hex_color`, `@func_color`, `@allow_sentinel`, interpolation stripping, comment skipping, and allowlist as the ExUnit gate
- Restricts to render dirs via `@render_dir_patterns`; CSS excluded by design (not a Credo source)
- No `exit_status:` override — advisory only (D-07); does NOT become a second hard CI gate
- Wired into `.credo.exs`: `requires: ["lib/cairnloop/credo_checks/no_hardcoded_color.ex"]` + `{Cairnloop.CredoChecks.NoHardcodedColor, [priority: :low]}` under `## Warnings`
- 57 checks active (was 56); finds zero violations on the remediated codebase

## Verification Results

| Check | Result |
|-------|--------|
| `mix test test/cairnloop/web/brand_token_gate_test.exs` | 3 tests, 0 failures |
| `mix compile --warnings-as-errors` | Exit 0 |
| `mix credo --strict` | 1 pre-existing baseline warning (breadcrumb_presenter_test.exs length/1); my new check adds 0 violations |
| `grep -rn 'cl-allow-color' lib/cairnloop/web/` | 2 lines — both in docstrings referencing legacy color names |
| Remediated files scan | Zero violations in conversation_live.ex + search_modal_component.ex |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SourceFile.lines/1 returns tuples, not plain strings**
- **Found during:** Task 2 — Credo check crashed with `FunctionClauseError: no function clause matching in String.contains?/2`
- **Issue:** `allowed_line_numbers/1` was written assuming plain string elements; `SourceFile.lines/1` returns `{line_no, line_text}` tuples per `Credo.Code.to_lines/1`
- **Fix:** Updated `allowed_line_numbers/1` to destructure `{no, line_text}` tuples; updated iteration to match
- **Files modified:** `lib/cairnloop/credo_checks/no_hardcoded_color.ex`
- **Commit:** cb2922e

**2. [Rule 1 - Bug] `~s(...)` sigil with `;` inside list causes syntax error**
- **Found during:** Task 1 compile
- **Issue:** `~s(  "background: rgba(0,0,0,0.5);")` inside a list literal causes Elixir parser to treat `;` as statement terminator
- **Fix:** Changed to `~s|...|` pipe-delimited sigils throughout fixture lists
- **Files modified:** `test/cairnloop/web/brand_token_gate_test.exs`
- **Commit:** adf3316

**3. [Rule 2 - Missing Critical] Pre-existing docstring color references flagged by hardened gate**
- **Found during:** Task 1 real-file scan — 3 violations in `components.ex` (lines 264-265) and `inbox_live.ex` (line 42)
- **Issue:** These lines mention legacy hex/rgba values in `@doc`/`@moduledoc` strings for documentation purposes (not render output). They were not anticipated in the plan.
- **Fix:** Added `# cl-allow-color` sentinel at end of each docstring line (or the preceding line to cover N+1). This is the correct use of the allowlist — auditable, per-line, greppable.
- **Files modified:** `lib/cairnloop/web/components.ex`, `lib/cairnloop/web/inbox_live.ex`
- **Commit:** adf3316

**4. [Rule 1 - Bug] Two chained Enum.reject calls in Credo check module**
- **Found during:** Task 2 — `mix credo --strict` flagged the new module itself with `Refactor.RejectReject`
- **Fix:** Merged the two guards into a single `Enum.reject` with `or`
- **Files modified:** `lib/cairnloop/credo_checks/no_hardcoded_color.ex`
- **Commit:** cb2922e

### Pre-existing Baseline

- `mix credo --strict` exits 16 (not 0) due to a pre-existing `length/1` warning in `test/cairnloop/web/breadcrumb_presenter_test.exs:11`. This was present before 40-03 (56 checks, same warning). My changes add 0 new credo violations. The plan's success criterion "credo --strict exits 0" is not achievable without fixing sealed baseline code — documented here for transparency.
- `OutboundWorkerTest` full-suite failure is the known pre-existing baseline flake (documented in project memory).

## Threat Model Coverage

T-40-SC (cl-allow-color tampering) mitigated: sentinel is per-line/block only, suppresses line N and N+1 only (never blanket file). All 2 current usages are in docstrings referencing historical color names, not grandfathering render-layer drift. `grep -rn 'cl-allow-color' lib/cairnloop/web/` is the audit command.

## Known Stubs

None. The gate and Credo check are fully wired and operative.

## Self-Check: PASSED

- `test/cairnloop/web/brand_token_gate_test.exs` exists: FOUND
- `lib/cairnloop/credo_checks/no_hardcoded_color.ex` exists: FOUND
- `.credo.exs` contains `NoHardcodedColor`: FOUND
- Commit adf3316 exists: FOUND
- Commit cb2922e exists: FOUND
