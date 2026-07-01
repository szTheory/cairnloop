---
phase: 51-full-html-brand-book-assembly
plan: 01
subsystem: brandbook
tags: [brandbook, static-html, elixir-script, source-guards]
requires:
  - phase: 50-brandbook-scaffold-token-derivation-pipeline
    provides: "brandbook scaffold, derived tokens.css, and swatches.json"
  - phase: 49-chosen-logo-finalization-asset-family
    provides: "approved logo assets and logo/USAGE.md inventory"
provides:
  - "Deterministic brandbook/index.html assembly and --check drift gate"
  - "Phase 51 source/package/content guards for required sections, labels, contrast text, and logo downloads"
affects: [brandbook, phase-52-wiring]
tech-stack:
  added: []
  patterns: ["Repo-local Elixir collateral assembly with byte-for-byte --check verification"]
key-files:
  created: [scripts/assemble_brandbook.exs]
  modified: [brandbook/index.html, test/cairnloop/web/brandbook_scaffold_test.exs]
key-decisions:
  - "Use scripts/assemble_brandbook.exs as the Phase 51 deterministic HTML assembly seam, modeled on derive_brandbook_tokens.exs."
  - "Keep required brandbook content in committed HTML and verify drift with mix run scripts/assemble_brandbook.exs --check."
  - "Validate approved logo assets through relative ../logo/* links rather than copying or recomposing logo files."
patterns-established:
  - "Generated brandbook HTML is committed and checked byte-for-byte against repo-local sources."
  - "DB-free ExUnit coverage owns brandbook source, package-boundary, logo-inventory, and status-label checks."
requirements-completed: [BOOK-03, BOOK-04, BOOK-05]
duration: 8 min
completed: 2026-06-25
status: complete
---

# Phase 51 Plan 01: Assembly and Source Guards Summary

**Deterministic static brandbook assembly with DB-free source, package, status-label, and logo-download guards**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-25T20:25:00Z
- **Completed:** 2026-06-25T20:33:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `Cairnloop.BrandbookAssembly.run/1` in `scripts/assemble_brandbook.exs` with deterministic generation and byte-for-byte `--check` drift detection for `brandbook/index.html`.
- Generated Phase 51 starter HTML from local token, logo, contrast, and prompt inputs with required labels, section anchors, visible status text, and relative `../logo/*` download links.
- Expanded `Cairnloop.Web.BrandbookScaffoldTest` from scaffold coverage to Phase 51 source/package/content coverage, including the assembly freshness check.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add deterministic brandbook assembly/check script** - `4d880b2` (feat)
2. **Task 2: Extend DB-free source/package/content guards** - `0de48c7` (test)

**Plan metadata:** this summary commit

## Files Created/Modified

- `scripts/assemble_brandbook.exs` - Generates and checks `brandbook/index.html` from repo-local sources.
- `brandbook/index.html` - Deterministic generated Phase 51 starter brand book with required source, status, section, and logo labels.
- `test/cairnloop/web/brandbook_scaffold_test.exs` - DB-free guard for required labels, sections, contrast status text, logo inventory, remote dependency bans, package boundary, and assembly drift.

## Decisions Made

- Use a script-level module instead of a public Mix task so Phase 51 collateral tooling remains repo-local and unshipped.
- Keep logo downloads as relative `../logo/*` links, preserving the committed Phase 49 assets as source of truth.
- Treat the Chimeway Repo connection errors emitted during `mix run` as existing app-start noise because the required commands exit 0 and produce/check the expected files.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- `mix run scripts/*` emits repeated `Chimeway.Repo` missing database-key connection errors during app startup, but the commands exit 0. The plan gates passed despite the noise.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix run scripts/derive_brandbook_tokens.exs --check` - passed.
- `mix run scripts/assemble_brandbook.exs` - passed and wrote `brandbook/index.html`.
- `mix run scripts/assemble_brandbook.exs --check` - passed.
- `mix test test/cairnloop/web/brandbook_scaffold_test.exs` - passed, 10 tests, 0 failures.

## Next Phase Readiness

Ready for Plan 02 to expand the generated HTML and token-driven CSS into the full professional visual brand book while preserving the assembly seam and source guards.

---
*Phase: 51-full-html-brand-book-assembly*
*Completed: 2026-06-25*
