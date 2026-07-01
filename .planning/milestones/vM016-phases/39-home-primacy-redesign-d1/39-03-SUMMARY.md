---
phase: 39-home-primacy-redesign-d1
plan: "03"
subsystem: home-live-d1-restructure
tags: [elixir, phoenix-liveview, tdd, brand-tokens, throttle, fail-closed, css]
dependency_graph:
  requires: [39-01-chat-facade-scoped-queries]
  provides:
    - HomeLive D1 two-tier render (hero + 3-up band + zero-state)
    - scoped assign_counts/1 using Chat.count_conversations/1
    - pending_recount? coalescing throttle (500ms, D-09)
    - safe_count/1 + split/1 fail-closed unavailable? signal (D-06)
    - health_variant mapping at assign time (D-08)
    - definite .cl-applied-filter CSS rule (sole wave-2 CSS owner)
  affects:
    - lib/cairnloop/web/home_live.ex
    - test/cairnloop/web/home_live_test.exs
    - priv/static/cairnloop.css
tech_stack:
  added: []
  patterns:
    - tdd-red-green
    - coalescing-pubsub-throttle
    - fail-closed-unavailable-signal
    - brand-token-class-only-render
key_files:
  created: []
  modified:
    - lib/cairnloop/web/home_live.ex
    - test/cairnloop/web/home_live_test.exs
    - priv/static/cairnloop.css
decisions:
  - "safe_count/1 and split/1 made @doc false public functions so throttle/D-06 tests can call them directly without a LiveView process"
  - "cl-stat count regex test uses ~r/class=\"cl-stat(?:\\s+cl-focusable)?\"/ to distinguish root tiles from sub-elements (cl-stat__count, etc.)"
  - "Icon test checks for cl-empty__icon class (SVG class) rather than the icon name string (icons render as inline SVG paths, no name in HTML)"
  - "Band gaps/audit counts pass through split/1 too — they get the unavailable? signal even though their source is safe/2 (consistent unavailable? threading)"
metrics:
  duration: "~6 minutes"
  completed: "2026-06-04T07:33:00Z"
  tasks_completed: 3
  files_modified: 3
---

# Phase 39 Plan 03: HomeLive D1 Restructure Summary

**One-liner:** Restructured `HomeLive` from a flat 5-cell grid to a D1 two-tier primacy model (copper hero + 3-up band + zero-state), backed by scoped throttled counts, a fail-closed unavailable? signal, and a definite `.cl-applied-filter` CSS rule for the parallel Plan 02 dependency.

## What Was Built

### `lib/cairnloop/web/home_live.ex`

**Tier 1 — Hero (or zero-state swap):**
- `open_count == 0 and not open_count_unavailable?` → `cl_empty icon="check-circle" title="All caught up"` with body "Nothing is waiting on you right now." (D-07; band persists below)
- Otherwise → `cl_hero job="Work the queue" count={@open_count}` with:
  - `:detail` slot: "Count unavailable" span when `open_count_unavailable?`; resolved sub-line `<a href="/inbox?status=resolved">` only when `resolved_count > 0 and not resolved_count_unavailable?` (HOME-02, D-10)
  - `:cta_slot`: `<.link navigate="/inbox"><.cl_button variant="primary" size="lg">Open inbox</.cl_button></.link>` (A1 fix — `cl_button` is a `<button>`, not a link)

**Tier 2 — 3-up secondary band (always renders):**
- `cl_stat job="Tend knowledge"` (href=/knowledge-base/gaps)
- `cl_stat job="Audit trail"` (href=/audit-log)
- Hand-built `<div class="cl-stat">` health cell with `cl_chip variant={@health_variant} label={@health_label}` (D-08 — never a numeric count slot) and `@health_meta`

**Backend — `assign_counts/1`:**
- `open_count` / `resolved_count`: `safe_count/1` + `split/1` over `Chat.count_conversations(status: :open/:resolved)` — scoped `SELECT count(*)` instead of full-list `Enum.count` (D-09, HOME-05)
- `gaps_count` / `audit_count`: existing `safe/2`-wrapped sources; also threaded through `split/1` for consistent `unavailable?` signal
- `health_variant` mapped from `health_ok?` at assign time: `"success"` / `"warning"` (D-08)
- `health_meta` string assigned at assign time

**Throttle (D-09, T-39-06):**
- `@recount_ms 500` module attr
- `handle_info({:conversations_changed}, socket)`: if `pending_recount?` → coalesce (noreply); else arm `Process.send_after(self(), :recount, @recount_ms)` ONLY when `connected?(socket)`, set `pending_recount?` to `connected?(socket)`
- `handle_info(:recount, socket)`: clears flag, re-runs `assign_counts/1`

**Helpers:**
- `safe_count/1` — returns `{:ok, result} | :error` via rescue/catch
- `split/1` — `{:ok, n}` when integer → `{n, false}`; anything else → `{0, true}` (fail-closed)
- `safe/2` — preserved verbatim (other callers)
- `count_or_dash/1` — **removed** (no longer needed; `"—"` path replaced by `unavailable?` signal)

### `test/cairnloop/web/home_live_test.exs`

- `assigns/1` extended with: `open_count_unavailable?`, `resolved_count_unavailable?`, `gaps_unavailable?`, `audit_unavailable?`, `health_variant`, `health_meta`, `pending_recount?`
- Stale tests removed/rewritten: "Recover resolved" job label gone, "—" dash → "Count unavailable", 5-card → hero + 3 tiles
- New describes: HOME-01 hero, HOME-02a resolved sub-line, HOME-03 3-tile band, HOME-04 zero-state, D-06 unavailable signal, HOME-05b throttle (no sleep), brand gate
- Throttle tests use bare `%Phoenix.LiveView.Socket{}` (disconnected, `connected?/1 = false`); no `:timer.sleep` or `Process.sleep`
- 29 tests, 0 failures

### `priv/static/cairnloop.css`

Added `.cl-applied-filter` rule (sole wave-2 CSS owner):
```css
.cl-applied-filter {
  display: flex; align-items: center; gap: var(--cl-space-3);
  background: var(--cl-surface); padding: var(--cl-space-3) 0;
}
```
- Token-only, no raw hex (T-39-08)
- Ships unconditionally so parallel Plan 02's `cl-applied-filter` markup is styled with no racy dependency

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] safe_count/1 and split/1 made public for testability**
- **Found during:** Task 2
- **Issue:** The throttle/D-06 tests call `Cairnloop.Web.HomeLive.split/1` directly. Private `defp` is not callable from tests. The plan specified `defp` but the test plan required direct calls.
- **Fix:** Changed `defp safe_count/1` and `defp split/1` to `def safe_count/1` and `def split/1` with `@doc false` so they're public but undocumented. This is the idiomatic Elixir pattern for functions that are internal but need testing.
- **Files modified:** `lib/cairnloop/web/home_live.ex`

**2. [Rule 1 - Bug] cl-stat count test used overly-broad regex**
- **Found during:** Task 2 GREEN verification
- **Issue:** `String.split(~r/class="cl-stat/)` matched sub-elements (`cl-stat__count`, `cl-stat__job`, `cl-stat__meta`) in addition to root tiles, giving 13 instead of 3.
- **Fix:** Changed to `Regex.scan(~r/class="cl-stat(?:\s+cl-focusable)?"/, html)` which matches only root tile elements.
- **Files modified:** `test/cairnloop/web/home_live_test.exs`

**3. [Rule 1 - Bug] check-circle icon test checked string name (not in HTML)**
- **Found during:** Task 2 GREEN verification
- **Issue:** `cl_icon` renders as inline SVG paths; the icon name string "check-circle" never appears in the rendered HTML. Test assertion `html =~ "check-circle"` always fails.
- **Fix:** Changed to check for `"cl-empty__icon"` class which is the actual rendered signal that the icon is present.
- **Files modified:** `test/cairnloop/web/home_live_test.exs`

**4. [Rule 2 - Missing critical] Band counts threaded through split/1 for consistent unavailable? signal**
- **Found during:** Task 2 implementation
- **Issue:** Plan said gaps/audit counts should stay on safe/2-wrapped sources for the count value, but the assign schema now includes `gaps_unavailable?` and `audit_unavailable?` as assigns that render affects. Safe/2 returns nil on error; splitting nil through split/1 correctly gives `{0, true}`.
- **Fix:** Piped the safe/2 result through split/1 for all band counts too, giving consistent unavailability threading across all 4 counts.
- **Files modified:** `lib/cairnloop/web/home_live.ex`

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. The changes are render-layer and process-local (LiveView process mailbox). Threat model is fully covered by the plan's threat register.

## Known Stubs

None — all data paths are wired. The render is fully functional against real Chat.count_conversations/1 calls (Plan 01's facade).

## Self-Check

**Files created/modified:**
- `lib/cairnloop/web/home_live.ex` — present
- `test/cairnloop/web/home_live_test.exs` — present
- `priv/static/cairnloop.css` — present

**Commits:**
- `066894f` — test(39-03): add failing RED tests (Task 1)
- `ad82ec6` — feat(39-03): scoped counts, throttle, fail-closed signal (Task 2)
- `38d2110` — feat(39-03): add .cl-applied-filter CSS rule (Task 3)

## Self-Check: PASSED
