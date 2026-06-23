---
phase: 42-cross-screen-threading
plan: "03"
subsystem: audit-web-layer
tags: [threading, audit-log, live-view, handle-params, tdd, a11y, THREAD-02, THREAD-03]
dependency_graph:
  requires: [enriched-auditor-map, proposal-id-filter, subject-href-presenter]
  provides: [audit-log-proposal-filter, audit-row-conversation-link]
  affects: [AuditLogLive, audit-log-ux, cross-screen-threading]
tech_stack:
  added: []
  patterns:
    - handle_params/2 two-clause tolerant param parser (Integer.parse/1 with positive guard)
    - Conditional opts threading via case + Keyword.put (nil-safe, unfiltered path unchanged)
    - <.link navigate={href}> branched on subject_href/1 nil vs present (fail-closed, D-08)
key_files:
  created: []
  modified:
    - lib/cairnloop/web/audit_log_live.ex
    - test/cairnloop/web/audit_log_live_test.exs
decisions:
  - Integer.parse/1 with id > 0 guard: only positive integers are valid proposal ids; zero, negative, and garbage all map to nil (mirrors subject_href/1 positive-integer guard from Plan 01)
  - proposal_filter key (not proposal_id) and proposal URL param (not proposal_id) as specified in plan action (D-10)
  - Explicit cell link (<.link>) not whole-row-as-link (RESEARCH Open Q2, Pitfall 6, brand §7.5 — text+tone, never color alone)
  - aria-label on subject link includes conversation id for screen reader specificity (inbox a11y idiom)
  - Conditional opts threading via case on Map.get: keeps unfiltered path byte-identical when proposal_filter is nil
metrics:
  duration: "~8 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_changed: 2
---

# Phase 42 Plan 03: Audit Log Web Layer Threading Summary

Wired the Audit Log web layer: `AuditLogLive` now has a `handle_params/2` tolerant proposal filter (THREAD-03a) and per-row subject conversation links built on Plan 01's `subject_href/1` presenter (THREAD-02). The audit log is no longer a dead-end leaf — each row links to its subject conversation, and the log can be deep-linked/filtered to one governed action's trail.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| RED | Failing tests for handle_params/2 + subject link | `9f44204` | `audit_log_live_test.exs` |
| 1 GREEN | handle_params/2 proposal filter threaded through load_events | `af45bfb` | `audit_log_live.ex`, `audit_log_live_test.exs` |
| 2 GREEN | Per-row subject link with accessible name + fail-closed fallback | `da4c810` | `audit_log_live.ex`, `audit_log_live_test.exs` |

## What Was Built

### Task 1: handle_params/2 + Proposal Filter Threading

**`lib/cairnloop/web/audit_log_live.ex` — `handle_params/2`:**

Two new clauses added (net-new — none existed before):

- `handle_params(%{"proposal" => raw}, _uri, socket)`: parses `raw` with `Integer.parse/1`; extracts `{id, _rest}` when `id > 0` → assigns `proposal_filter: id`; any other result (`:error`, zero, negative) → `proposal_filter: nil`. Full honest view on invalid input, never a crash (T-42-07 mitigated).
- `handle_params(_params, _uri, socket)` catch-all: `proposal_filter: nil`, full view.

Both clauses pipe into `load_events/1`.

`mount/3` extended with `proposal_filter: nil` in the initial assign so the key always exists.

**`load_events/1` threading:**

The opts list is conditionally extended via `case Map.get(socket.assigns, :proposal_filter)`:
- `nil` → opts unchanged (unfiltered path is byte-identical to before — D-09)
- `id` → `Keyword.put(opts, :proposal_id, id)` threads the filter into the auditor read

No `Cairnloop.Repo` in the LiveView; reads flow through the configured auditor (criterion-4, D-03).

### Task 2: Per-Row Subject Link

**`lib/cairnloop/web/audit_log_live.ex` — audit table template:**

- Added `<th>Conversation</th>` header to `<thead>`.
- New subject cell added to each row, branching on `P.subject_href(event)`:
  - Non-nil href → `<.link navigate={href} aria-label={"View conversation #{id}"}>View conversation</.link>` (scope-relative `/#{id}`, never mount-prefixed — Pitfall 3; explicit accessible name — Pitfall 6)
  - Nil → `<span class="cl-text-muted">—</span>` (fail-closed plain text — D-08, T-42-09)

## Verification Results

- `mix compile --warnings-as-errors` exits 0
- `mix test test/cairnloop/web/audit_log_live_test.exs` exits 0 (14 tests, 0 failures)
- `grep 'Cairnloop.Repo\.' lib/cairnloop/web/audit_log_live.ex` → no matches (criterion-4)
- `grep '/support/' lib/cairnloop/web/audit_log_live.ex` → no matches (scope-relative)

## TDD Gate Compliance

Both tasks followed RED → GREEN:
- RED: `9f44204` — 7 new tests fail (`UndefinedFunctionError` for handle_params, missing link/header for subject column)
- Task 1 GREEN: `af45bfb` — handle_params/2 + load_events threading → 4 Task 1 tests pass; 3 Task 2 still fail (correct)
- Task 2 GREEN: `da4c810` — subject cell + header → all 14 tests green

## Deviations from Plan

**1. [Rule 1 - Bug] Test assertion corrected: `<.link navigate>` renders `href=` not `navigate=`**
- **Found during:** Task 2 GREEN — first test run after implementation
- **Issue:** The plan's test action said to assert `navigate="/5"` but `<.link navigate={href}>` in Phoenix LiveView renders as `<a href="/5" data-phx-link="redirect" ...>` — the `navigate` attribute is a component prop, not a rendered HTML attribute
- **Fix:** Changed assertion to `href="/5"` and updated the nil-link test to assert absence of "View conversation" text instead of a raw navigate attribute
- **Files modified:** `test/cairnloop/web/audit_log_live_test.exs`
- **Commit:** `da4c810`

## Known Stubs

None. All new functions are wired to real data flowing through Plan 01's enriched auditor map.

## Threat Flags

No new threat surface beyond what was modeled in the plan's threat register:
- T-42-07 (Tampering via `?proposal=` param): `Integer.parse/1` + `id > 0` guard; bad input → nil → full view, never crash.
- T-42-08 (IDOR): reads route through auditor → governance facade (Plan 01); operator-scoped.
- T-42-09 (broken link): `subject_href/1` returns nil → plain-text cell; no `navigate=` with nil segment.

## Self-Check: PASSED

- [x] `lib/cairnloop/web/audit_log_live.ex` defines `def handle_params(%{"proposal" => raw}` (grep confirmed)
- [x] `lib/cairnloop/web/audit_log_live.ex` contains `Integer.parse` (grep confirmed)
- [x] `lib/cairnloop/web/audit_log_live.ex` contains `subject_href` (grep confirmed)
- [x] No `Cairnloop.Repo.` in `audit_log_live.ex` (grep confirmed)
- [x] No `/support/` in `audit_log_live.ex` (grep confirmed)
- [x] `test/cairnloop/web/audit_log_live_test.exs` has 14 tests covering both tasks (run confirmed)
- [x] Commits `9f44204`, `af45bfb`, `da4c810` exist in git log
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/cairnloop/web/audit_log_live_test.exs` exits 0 (14 tests, 0 failures)
