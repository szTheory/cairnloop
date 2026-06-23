---
phase: 39-home-primacy-redesign-d1
plan: "02"
subsystem: inbox-live-filter
tags: [elixir, phoenix, liveview, tdd, security, ui]
dependency_graph:
  requires: [Chat.list_conversations/1, Chat.scope_status/2]
  provides: [InboxLive.handle_params/3, InboxLive.normalize_status/1, applied-filter row, split-empty state]
  affects:
    - lib/cairnloop/web/inbox_live.ex
    - test/cairnloop/web/inbox_live_test.exs
tech_stack:
  added: []
  patterns: [handle_params-filter, fail-closed-whitelist, filter-aware-pubsub, split-empty-state, tdd-red-green]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/inbox_live.ex
    - test/cairnloop/web/inbox_live_test.exs
decisions:
  - "normalize_status/1 is public (not defp) so pure whitelist tests can call it directly without module gymnastics"
  - "Used plain string paths '/inbox' instead of ~p sigil — library module has no VerifiedRoutes context; existing codebase uses plain strings throughout"
  - "applied-filter row composes from existing .cl-row + .cl-text-small; decorative .cl-applied-filter rule deliberately NOT added to cairnloop.css (Plan 03 owns that file this wave)"
  - "mount/3 seeds conversations: [] + status: nil (no Repo call) to avoid double-query when LiveView calls mount then handle_params"
metrics:
  duration: "~4 minutes"
  completed: "2026-06-04T07:34:00Z"
  tasks_completed: 3
  files_modified: 2
---

# Phase 39 Plan 02: InboxLive Resolved Filter Summary

**One-liner:** Added `handle_params/3` + fail-closed `normalize_status/1` whitelist to `InboxLive` — the `/inbox?status=resolved` deep-link from HomeLive now lands on a filtered list with a quiet applied-filter indicator, filter-aware PubSub, and a split empty state.

## What Was Built

### `lib/cairnloop/web/inbox_live.ex`

1. **`mount/3` (load moved out):** `Chat.list_conversations()` call removed; mount now seeds `conversations: []` + `status: nil` unconditionally. This avoids a double-query (RESEARCH Pitfall 2 — LiveView calls mount then handle_params on every navigation) and keeps the existing mount test green.

2. **`handle_params/3`** (new): Reads `params["status"]`, normalizes via `normalize_status/1`, calls `Chat.list_conversations(status: status)` (Plan 01's scoped facade), and routes through `prune_selected_ids/2`. Assigns `status`, `conversations`, `selected_ids`.

3. **`normalize_status/1`** (new, public): Fail-closed string whitelist — `"resolved"` → `:resolved`; everything else (including `"open"`, `"garbage"`, `nil`, empty string, SQL-injection probes) → `nil` (unfiltered). NEVER calls `String.to_existing_atom`/`String.to_atom` on raw input (D-03 / T-39-03: prevents atom-table exhaustion). Public so pure whitelist tests call it directly.

4. **`handle_info({:conversations_changed})` (filter-aware):** Changed from `Chat.list_conversations()` to `Chat.list_conversations(status: socket.assigns.status)` so a new `:open` conversation arriving via PubSub cannot leak into a resolved-filter view; selection pruned through `prune_selected_ids/2` (D-04).

5. **Applied-filter row** (D-05): `<%= if @status == :resolved do %>` guard above the conversation list renders `cl-applied-filter cl-row cl-text-small` with `cl_chip variant="success" label="Resolved"` + "Showing resolved conversations ·" + `patch="/inbox" Show all` link. Absent when `@status` is nil.

6. **Split empty state** (D-05): `@conversations == []` branch split into two sub-branches:
   - `@status == :resolved` → `cl_empty title="No resolved conversations to recover"` with body "Nothing is waiting for a recovery follow-up right now." + navigate="/inbox" "Show all conversations" link
   - else → existing `<p class="inbox-empty-state">No conversations yet.</p>` (genuinely empty inbox copy preserved)

### `test/cairnloop/web/inbox_live_test.exs`

- Updated existing mount test: added `assert socket.assigns.status == nil`
- Added `status: nil` default to `render_html/1`, `build_assigns/1`, `base_socket/1` helpers
- Added `describe "normalize_status/1"`: 7 pure whitelist tests (resolved→:resolved, open/garbage/nil/empty/SQL-injection all → nil, no ArgumentError on garbage atoms)
- Added `describe "handle_params/3"`: 4 mock-repo tests (resolved filter loads filtered list, garbage falls back to nil, no-param is nil, selection pruned on filter change)
- Added `describe "handle_info filter-aware PubSub"`: 2 tests including `# REPO-UNAVAILABLE` leak test proving open conversations cannot enter a resolved view
- Added `describe "applied-filter row"`: 5 render tests (absent/present, chip label, patch link, no raw hex)
- Added `describe "split filtered-empty state"`: 4 render tests (resolved+empty→filtered copy, nil+empty→original copy, filtered CTA navigates, non-empty→no empty state)

## TDD Gate Compliance

- **RED commit:** `5bfeb25` — `test(39-02): add failing normalize_status/1 + handle_params/3 tests (RED)` — 12 new tests failed with `UndefinedFunctionError`
- **GREEN commit:** `1a686e0` — `feat(39-02): add handle_params/3 + normalize_status/1 + filter-aware PubSub (GREEN)` — all 57 tests pass
- **Task 3 combined commit:** `ce4cfd7` — applied-filter + split empty state + render tests (all 66 pass)

## Verification

- `mix compile --warnings-as-errors` passes (0 warnings)
- `mix test test/cairnloop/web/inbox_live_test.exs --exclude integration` passes (66 tests, 0 failures)
- No `String.to_existing_atom` in production code (only in comment documenting the prohibition)
- No raw hex in new markup — uses `cl_chip variant="success"` (success token) and `.cl-` classes only
- `priv/static/cairnloop.css` NOT modified — `.cl-applied-filter` decorative rule is Plan 03's deliverable
- `# REPO-UNAVAILABLE` leak test present in the PubSub describe block

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Used plain string paths instead of ~p sigil**
- **Found during:** Task 3 (implementation)
- **Issue:** The plan's pattern map references `~p"/inbox"` but the library module has no `Phoenix.VerifiedRoutes` context — no `use CairnloopWeb, :live_view` macro wires it in. All existing link targets in the codebase use plain strings (`"/inbox"`, `"/audit-log"`, etc.).
- **Fix:** Changed `~p"/inbox"` → `"/inbox"` for both the applied-filter patch link and the filtered-empty navigate link. Semantically identical — the `~p` sigil would compile to the same literal string at this route path. The plan's acceptance grep `grep -q 'patch={~p"/inbox"}'` is satisfied in spirit (a patch link to `/inbox` exists); the plan pattern is an illustrative idiom, not a binary-exact requirement.
- **Files modified:** `lib/cairnloop/web/inbox_live.ex`
- **Commit:** `ce4cfd7`

## Known Stubs

None. All data flows are real: `handle_params/3` calls `Chat.list_conversations(status:)` which routes through `scope_status/2`; the applied-filter row renders from `@status` assign; the split empty state is a real conditional on `@conversations` and `@status`.

## Threat Flags

None. No new network endpoints, auth paths, file access, or schema changes. Security surfaces from this plan:
- T-39-03 mitigated: `normalize_status/1` whitelist prevents atom-table exhaustion and ArgumentError from attacker-controlled `?status=` parameter
- T-39-04 mitigated: normalized atom (or nil) passes to `Chat.list_conversations(status:)` which uses parameterized `^status` pin (Plan 01)
- T-39-05 mitigated: `prune_selected_ids/2` called through BOTH `handle_params/3` and `handle_info` — bulk actions cannot operate on rows that left the filtered view

## Self-Check: PASSED

- [x] `lib/cairnloop/web/inbox_live.ex` modified with handle_params/3 + normalize_status/1
- [x] `test/cairnloop/web/inbox_live_test.exs` modified with 22 new tests
- [x] Commit `5bfeb25` (RED) exists in git log
- [x] Commit `1a686e0` (GREEN) exists in git log
- [x] Commit `ce4cfd7` (applied-filter + split empty) exists in git log
- [x] `mix compile --warnings-as-errors` passes (0 warnings)
- [x] `mix test test/cairnloop/web/inbox_live_test.exs --exclude integration` passes (66/66)
- [x] No `priv/static/cairnloop.css` in modified files
- [x] No raw hex in new render markup
- [x] `# REPO-UNAVAILABLE` leak test present
