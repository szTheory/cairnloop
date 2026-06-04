---
phase: 42-cross-screen-threading
plan: "04"
subsystem: web-conversation-rail
tags: [conversation-live, next-in-queue, audit-deep-link, thread-01, thread-03a, tdd]
dependency_graph:
  requires: [plans/42-02]
  provides: [next-in-queue-affordance, queue-clear-state, audit-trail-deep-link]
  affects: []
tech_stack:
  added: []
  patterns: [case-branch-on-assign, scope-relative-declarative-nav, attr-default, map-put-new]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/conversation_live.ex
    - test/cairnloop/web/conversation_live_test.exs
decisions:
  - "next_open_id assigned in reload_conversation_with_context/2 so it is recomputed on every PubSub reload (THREAD-01, T-42-10)"
  - "outbound_recovery_card/1 uses case @next_open_id — nil branch renders calm Queue-clear + /inbox, id branch renders Next in queue link (D-06, T-42-11)"
  - "Map.put_new(:next_open_id, nil) in render/1 so direct render_component tests without @next_open_id do not crash"
  - "View audit trail link placed inside the Tier-3 cl_disclosure after cl_fact_list (D-10, THREAD-03a)"
  - "Test assertions check Phoenix-rendered href= + data-phx-link=redirect output, not navigate= attribute (which is a compile-time prop, not rendered)"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 2
---

# Phase 42 Plan 04: Conversation Rail Threading Summary

**One-liner:** Next-in-queue affordance (resolved + next_open_id → scope-relative link; nil → calm Queue-clear + /inbox) wired via `Chat.next_open_conversation/1` in the reload helper, plus audit-trail deep-link in the Tier-3 trace group — both additive to `conversation_live.ex`, all scope-relative declarative nav, no direct Repo.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing tests for next-in-queue + audit deep-link | 91eb28e | test/cairnloop/web/conversation_live_test.exs |
| 1+2 (GREEN) | Wire next-in-queue affordance and audit deep-link | 0b9b6d7 | lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs |

## What Was Built

### Task 1: Next-in-queue affordance in the resolved region (THREAD-01)

In `reload_conversation_with_context/2`, added:
```elixir
next_open_id = Chat.next_open_conversation(conversation_id)
```
Assigned as `next_open_id:` alongside the existing assigns — recomputed on every PubSub reload,
so the affordance is never stale (T-42-10).

Added `Map.put_new(assigns, :next_open_id, nil)` in `render/1` so direct `render_component` calls
in tests do not crash (same pattern as `governed_actions`).

Updated `outbound_recovery_card/1`: added `attr(:next_open_id, :any, default: nil)`. Updated the
call site to pass `next_open_id={@next_open_id}`. Inside the resolved block:
```elixir
<%= case @next_open_id do %>
  <% nil -> %>
    <p class="cl-text-muted">Queue clear — no more open conversations.</p>
    <.link navigate="/inbox" class="cl-text-small">Back to inbox</.link>
  <% id -> %>
    <.link navigate={"/#{id}"} class="cl-button">Next in queue &rarr;</.link>
<% end %>
```
- `nil` → calm "Queue clear" + `/inbox` back-link — no disabled/dead Next (T-42-11, D-06)
- `id` → scope-relative `/#{id}` declarative navigate (D-14, Pitfall 3)
- Never `/support/` prefixed

### Task 2: Audit-trail deep-link in the governed-action Tier-3 trace group (THREAD-03a)

Inside the existing `<.cl_disclosure id={"ga-#{@proposal.id}-trace"}>` block, added after `cl_fact_list`:
```elixir
<.link navigate={"/audit-log?proposal=#{@trace.proposal_id}"}>View audit trail</.link>
```
- Scope-root-relative path (`/audit-log?proposal=...`) — never mount-prefixed (Pitfall 3)
- Declarative `navigate` (D-14) — not `push_navigate`/`push_patch`
- Explicit link text for accessible name (brand §7.5)
- No signed return-token (D-11 — plain declarative nav)

## Test Coverage

Added 6 headless render tests in `conversation_live_test.exs`:

**THREAD-01 next-in-queue:**
- Resolved + next_open_id=42 → renders "Next in queue" with `href="/42"` and `data-phx-link="redirect"`
- Resolved + next_open_id=nil → renders "Queue clear" with `href="/inbox"` and `data-phx-link="redirect"`
- Open status (non-resolved) + any next_open_id → renders neither affordance
- render/1 with next_open_id=99 in assigns → "Next in queue" link with `href="/99"`

**THREAD-03a audit deep-link:**
- governed_action_card/1 Tier-3 trace → renders "View audit trail" with `href="/audit-log?proposal=55"` and `data-phx-link="redirect"`
- Source-level assertion: `navigate={"/audit-log?proposal=` in source; no `push_navigate.*audit-log`

Note: Phoenix's `<.link navigate>` renders as `href=` + `data-phx-link="redirect"` in `render_component` output — assertions match the actual rendered HTML, not the HEEx source attribute.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test assertions adapted to Phoenix render_component output**
- **Found during:** Task 1/2 GREEN verification
- **Issue:** Plan specified asserting `navigate="/42"` etc., but `render_component` renders `<.link navigate>` as `href="/42" data-phx-link="redirect"` (standard Phoenix LiveView behavior). Asserting the HEEx attribute `navigate=` directly would always fail in headless tests.
- **Fix:** Updated test assertions to check `href=` + `data-phx-link="redirect"` as Phoenix renders them. Source-level assertion for the audit deep-link confirms `navigate=` is in the source code (correct).
- **Files modified:** test/cairnloop/web/conversation_live_test.exs
- **Commit:** 0b9b6d7 (included with GREEN)

## Threat Model Coverage

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-42-10 | next_open_conversation/1 recomputed each reload; nil → Queue-clear, never stale-id navigate | Implemented |
| T-42-11 | case @next_open_id: nil → calm Queue-clear + /inbox, never disabled/dead Next | Implemented |
| T-42-12 | All paths scope-root-relative (/inbox, /{id}, /audit-log?...); grep gate passes | Implemented |

## Known Stubs

None — both affordances are fully wired with real data sources (`Chat.next_open_conversation/1` for Task 1; `@trace.proposal_id` already in scope for Task 2).

## Threat Flags

None — no new network endpoints, auth paths, or schema changes. Both changes are render-only additive edits to an existing LiveView. The `next_open_conversation/1` read is a structural navigation read (not a trust fact — D-02); operator scope is enforced in the facade (Plan 02 implementation).

## Self-Check: PASSED

- [x] `lib/cairnloop/web/conversation_live.ex` contains `next_open_conversation`
- [x] `lib/cairnloop/web/conversation_live.ex` contains "Next in queue"
- [x] `lib/cairnloop/web/conversation_live.ex` contains "Queue clear"
- [x] `lib/cairnloop/web/conversation_live.ex` contains `audit-log?proposal=`
- [x] `lib/cairnloop/web/conversation_live.ex` contains "View audit trail"
- [x] `grep '/support/'` returns no matches
- [x] `grep 'Cairnloop\.Repo\.'` returns no new direct Repo use
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/cairnloop/web/conversation_live_test.exs` exits 0 (83 tests, 0 failures)
- [x] Commits 91eb28e (RED) and 0b9b6d7 (GREEN) exist in git log
