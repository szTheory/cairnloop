---
phase: 41-conversation-rail-progressive-disclosure-d2
plan: "02"
subsystem: web-components
tags: [cl_disclosure, global-passthrough, data-tier, RAIL-03, tdd-green]
dependency_graph:
  requires: [41-01]
  provides: [cl_disclosure-rest-passthrough]
  affects: [lib/cairnloop/web/components.ex]
tech_stack:
  added: []
  patterns: [":global attr passthrough (cl_switch idiom)"]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/components.ex
decisions:
  - "attr(:rest, :global) with no include: list — data-tier/data-density are plain data-* globals that pass by default; no phx-* added to the include: because the disclosure must never receive a dynamic open binding"
  - "Placed attr(:rest, :global) immediately after attr(:open, :boolean, default: false) and {@rest} after open={@open} on <details> — mirrors cl_switch idiom"
metrics:
  duration: "< 5 min"
  completed_date: "2026-06-04"
  tasks_completed: 1
  files_modified: 1
---

# Phase 41 Plan 02: cl_disclosure :global Passthrough Summary

## One-liner

Added `attr(:rest, :global)` + `{@rest}` to `cl_disclosure/1` so `data-tier="2"` (and any `data-*` global) reaches the rendered `<details>` element — the Wave 0 RED passthrough test is now GREEN.

## What Was Built

**Task 1: Add attr(:rest, :global) to cl_disclosure/1 and spread {@rest} onto <details>**

`cl_disclosure/1` in `lib/cairnloop/web/components.ex` (lines 181–205) received three additive changes:

1. `attr(:rest, :global)` inserted immediately after `attr(:open, :boolean, default: false)` — no `include:` list needed (plain `data-*` globals pass by default; no `phx-*` included to guard against dynamic open binding).
2. `{@rest}` spread on the `<details>` element after `open={@open}`: `<details ... open={@open} {@rest}>`.
3. One-line `@doc` extension noting `:rest` carries `data-tier`/`data-density` scoping hooks for RAIL-03.

No other attrs, slots, or behavior changed. All existing call sites render identically (additive proof: no existing caller passes `:rest`).

## Verification

- `mix compile --warnings-as-errors` exits 0 (no warnings).
- `mix test test/cairnloop/web/components_test.exs` — 32 tests, 0 failures:
  - Wave 0 RED test `cl_disclosure passes data-tier=2 through to the <details> element` is now GREEN.
  - `cl_disclosure open=true renders <details ...>` still passes.
  - `cl_disclosure open=false (default) omits the open attribute ...` still passes.
  - `cl_disclosure token-pure: no hex in rendered output` still passes.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. This is a pure primitive attribute addition; no data-flow stubs introduced.

## Threat Surface Scan

No new network endpoints, auth paths, file access, or schema changes. The `{@rest}` passthrough was already in the plan's threat model as T-41-02 (accepted: first-party HEEx callers only; HEEx escapes attribute values, no XSS surface).

## Self-Check: PASSED

- [x] `lib/cairnloop/web/components.ex` exists and contains `attr(:rest, :global)` and `{@rest}`
- [x] Commit `979236a` exists: `feat(41-02): add attr(:rest, :global) passthrough to cl_disclosure/1`
- [x] 32 component tests green, 0 failures
- [x] Build warnings-clean
