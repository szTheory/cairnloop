---
phase: 38-shared-page-shell-migration
plan: "01"
subsystem: web/ui
tags: [shell-migration, cl_page, SHELL-01, LiveView, headless-tests]
dependency_graph:
  requires:
    - "Phase 37 — cl_page/1 component (components.ex:321-346)"
  provides:
    - "SHELL-01: Home, Inbox, Audit Log, Settings render inside cl_page width=wide"
  affects:
    - "lib/cairnloop/web/home_live.ex"
    - "lib/cairnloop/web/inbox_live.ex"
    - "lib/cairnloop/web/audit_log_live.ex"
    - "lib/cairnloop/web/settings_live.ex"
tech_stack:
  added: []
  patterns:
    - "cl_page HEEx component adoption — title/subtitle/width attrs, inner_block slot"
    - ":actions slot for single primary button (Settings Toggle dark mode)"
    - "Pitfall 4 pattern: live_component as first child of inner_block for overlay modals"
key_files:
  created:
    - path: "test/cairnloop/web/audit_log_live_test.exs"
      purpose: "New headless render test for AuditLogLive (no prior dedicated render test existed)"
  modified:
    - path: "lib/cairnloop/web/home_live.ex"
      change: "Replace <header style=...><h1>Welcome back</h1> with <.cl_page title='Welcome back' subtitle='What needs you today?' width='wide'>; body unchanged"
    - path: "lib/cairnloop/web/inbox_live.ex"
      change: "Wrap in <.cl_page title='Inbox' width='wide'>; search-modal as first child of inner_block (Pitfall 4); remove bare <h1>Inbox</h1>"
    - path: "lib/cairnloop/web/audit_log_live.ex"
      change: "Replace <header class='cl-mb-7'><h1>Audit Log</h1> with <.cl_page title='Audit Log' subtitle='...' width='wide'>; cl_card filter bar stays in body"
    - path: "lib/cairnloop/web/settings_live.ex"
      change: "Wrap in <.cl_page title='Settings' width='wide'>; Toggle dark mode button moved to <:actions> slot; search-modal as first child of inner_block"
    - path: "test/cairnloop/web/home_live_test.exs"
      change: "Added Phase 38 SHELL-01 render assertions: cl-page--wide, cl-page__title, verbatim title and subtitle"
    - path: "test/cairnloop/web/inbox_live_test.exs"
      change: "Added Phase 38 SHELL-01 render assertions: cl-page--wide, cl-page__title, search-modal in body"
    - path: "test/cairnloop/web/settings_live_test.exs"
      change: "Added Phase 38 SHELL-01 render assertions: cl-page--wide, cl-page__title, Toggle dark mode in header region"
decisions:
  - "Pitfall 4 confirmed: live_component (search-modal) must be FIRST CHILD of inner_block in both Inbox and Settings; inner position is CSS-driven (fixed overlay)"
  - "Test 3 (Inbox) assertion changed from id='search-modal' to id='search-modal-search-root' (live_component id= is internal; SearchModalComponent renders id={@id <> '-search-root'})"
  - "Audit Log filter forms stay in cl_card :header slot inside inner_block (D-04: substantial filter bars never go in :actions)"
  - "Settings Toggle dark mode is textbook :actions case — single primary button, moved verbatim including onclick"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 7
  files_created: 1
---

# Phase 38 Plan 01: Home/Inbox/AuditLog/Settings cl_page Shell Migration Summary

**One-liner:** Pure structural lift of four operator screens into the locked `cl_page` primitive — uniform header height, inner content width, and verbatim page titles across Home, Inbox, Audit Log, and Settings (SHELL-01).

## What Was Built

All four non-KB operator cockpit screens now render their body through `<.cl_page>` nested inside `<.cl_shell>`. The migration is purely structural (D-05): no body markup was rewritten, no copy was changed, no new components were introduced. The `cl_page` primitive was built in Phase 37 and adopted here verbatim.

**Screen-by-screen changes:**

| Screen | Before | After | Slots used |
|--------|--------|-------|------------|
| Home | `<header style="margin-bottom: var(--cl-space-7);">` + `<h1>Welcome back</h1>` | `<.cl_page title="Welcome back" subtitle="What needs you today?" width="wide">` | `inner_block` only |
| Inbox | bare `<h1>Inbox</h1>` inside `<div class="cairnloop-inbox">` | `<.cl_page title="Inbox" width="wide">` | `inner_block` (search-modal as first child per Pitfall 4) |
| Audit Log | `<header class="cl-mb-7"><h1>Audit Log</h1>` + subtitle `<p>` | `<.cl_page title="Audit Log" subtitle="..." width="wide">` | `inner_block` only |
| Settings | `<div class="cl-row cl-row--between cl-mb-7"><h1>Settings</h1>` + Toggle button | `<.cl_page title="Settings" width="wide">` with `<:actions>` | `inner_block` + `:actions` |

## TDD Cycle

Followed RED → GREEN → (no refactor needed) for each task pair:

**Task 1 (Home + Inbox):**
- RED commit: `bcaf473` — failing tests for cl-page--wide, cl-page__title, title text, subtitle, search-modal in body
- GREEN commit: `ed97590` — implementation + test correction

**Task 2 (Audit Log + Settings):**
- RED commit: `6ca3201` — failing tests for both screens, new `audit_log_live_test.exs`
- GREEN commit: `d3b582f` — implementation

## Commits

| Hash | Type | Description |
|------|------|-------------|
| `bcaf473` | test | Add failing RED tests for Home+Inbox cl_page migration |
| `ed97590` | feat | Migrate Home and Inbox to cl_page shell (SHELL-01) |
| `6ca3201` | test | Add failing RED tests for AuditLog+Settings cl_page migration |
| `d3b582f` | feat | Migrate Audit Log and Settings to cl_page shell (SHELL-01) |

## Verification Results

- `mix compile --warnings-as-errors`: clean (0 warnings in cairnloop itself)
- `mix test test/cairnloop/web/home_live_test.exs test/cairnloop/web/inbox_live_test.exs`: 50 tests, 0 failures
- `mix test test/cairnloop/web/settings_live_test.exs test/cairnloop/web/audit_log_live_test.exs`: 9 tests, 0 failures
- `mix test test/cairnloop/web/brand_token_gate_test.exs`: 1 test, 0 failures
- `mix test test/cairnloop/web/` (full web suite): 340 tests, 0 failures (9 excluded by tag)
- SettingsLive isolation run: 5 tests, 0 failures (pre-existing order-flake did NOT appear — not a P38 regression)

## Deviations from Plan

### Auto-corrected Test Assertion

**[Rule 1 - Bug] Test 3 (Inbox) id="search-modal" check corrected**
- **Found during:** Task 1 GREEN phase
- **Issue:** The plan specified asserting `id="search-modal"` in rendered HTML, but `live_component`'s `id=` parameter is a LiveView-internal identifier, not a rendered HTML attribute. `SearchModalComponent` renders its root element with `id={"#{@id}-search-root"}` (see `search_modal_component.ex:36`).
- **Fix:** Changed test assertion to check for `id="search-modal-search-root"` OR `data-host-surface="inbox"` (both present in the rendered output). This correctly verifies the modal is in the body.
- **Files modified:** `test/cairnloop/web/inbox_live_test.exs`
- **Commit:** `ed97590`

### Added Missing Test File

**[Rule 2 - Missing Critical Functionality] Created audit_log_live_test.exs**
- **Found during:** Task 2 RED phase
- **Issue:** `audit_log_live.ex` had no dedicated render test file (only `audit_log_presenter_test.exs` existed).
- **Fix:** Created `test/cairnloop/web/audit_log_live_test.exs` with headless render assertions per the plan's instruction: "if Audit Log lacks a dedicated render test, add a minimal headless render assertion."
- **Files created:** `test/cairnloop/web/audit_log_live_test.exs`
- **Commit:** `6ca3201`

## Known Stubs

None. All four screens render from real assigns with no placeholders or hardcoded empty values. The `visible_events: []` in audit_log_live_test is a valid test state (the empty-state path), not a stub.

## Threat Flags

None. This plan introduces no new trust boundaries, no new untrusted input, no auth paths, no data flows, and no new network endpoints. All titles/subtitles are static string literals. Per the plan's threat model: T-38-01 (XSS via title/subtitle) is accepted — titles are static verbatim strings, HEEx auto-escapes all interpolation, no `raw/1` used.

## Self-Check: PASSED

Files exist:
- `lib/cairnloop/web/home_live.ex` — FOUND, contains `<.cl_page`
- `lib/cairnloop/web/inbox_live.ex` — FOUND, contains `<.cl_page`
- `lib/cairnloop/web/audit_log_live.ex` — FOUND, contains `<.cl_page`
- `lib/cairnloop/web/settings_live.ex` — FOUND, contains `<.cl_page` and `<:actions>`
- `test/cairnloop/web/audit_log_live_test.exs` — FOUND (new file)

Commits verified:
- `bcaf473` — FOUND
- `ed97590` — FOUND
- `6ca3201` — FOUND
- `d3b582f` — FOUND
