---
phase: 39-home-primacy-redesign-d1
plan: "01"
subsystem: chat-facade
tags: [elixir, ecto, facade, scoped-query, tdd]
dependency_graph:
  requires: []
  provides: [Chat.list_conversations/1, Chat.count_conversations/1, Chat.scope_status/2]
  affects: [lib/cairnloop/chat.ex, test/cairnloop/chat_test.exs]
tech_stack:
  added: []
  patterns: [scoped-ecto-where, aggregate-count, tdd-red-green]
key_files:
  created: []
  modified:
    - lib/cairnloop/chat.ex
    - test/cairnloop/chat_test.exs
decisions:
  - "Sealed 0-arity list_conversations/0 preserved as a distinct clause (A3 invariant) — NOT collapsed into a default opts version"
  - "scope_status/2 uses parameterized ^status pin in where/2 — no string interpolation of user input (T-39-02)"
  - "Unknown/nil status atoms fall through to the _other -> query passthrough clause (D-03 defense-in-depth)"
  - "Whitelist only [:open, :resolved, :archived] — matches the real Ecto.Enum values; no phantom :awaiting_customer/:new"
  - "MockRepo.all/1 + aggregate/3 stubs record call args via Process dict so query-shape assertions work headlessly"
  - "Unscoped count test correctly handles bare schema module (Cairnloop.Conversation) vs %Ecto.Query{} — scope_status/2 passthrough returns the raw module when no where clause is applied"
metrics:
  duration: "~2 minutes"
  completed: "2026-06-04T07:23:10Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 39 Plan 01: Chat Facade Scoped Query Functions Summary

**One-liner:** Added `list_conversations/1` + `count_conversations/1` + private `scope_status/2` to `Cairnloop.Chat` — status-scoped Ecto queries with parameterized where pins and D-03 defense-in-depth passthrough, backed by TDD RED/GREEN cycle.

## What Was Built

### `lib/cairnloop/chat.ex`

Three additive members added after the sealed 0-arity `list_conversations/0` clause:

1. **`list_conversations(opts) when is_list(opts)`** — applies `order_by(desc: :updated_at)`, pipes through `scope_status/2`, calls `repo().all()`. Backs HOME-02 deep-link landing (D-02).

2. **`count_conversations(opts \\ [])`** — pipes through `scope_status/2`, calls `repo().aggregate(:count, :id)`. Cheap `SELECT count(*)` — never a full list load + `Enum.count` (D-09, HOME-05).

3. **`defp scope_status/2`** — three clauses:
   - `scope_status(query, nil)` → passthrough (unscoped)
   - `scope_status(query, status) when status in [:open, :resolved, :archived]` → `where(query, [c], c.status == ^status)` (parameterized pin, T-39-02)
   - `scope_status(query, _other)` → passthrough (D-03: unknown atoms never crash the query builder)

The sealed 0-arity `list_conversations/0` is preserved verbatim as its own distinct clause (not collapsed into a `\\ []` default). `grep -c 'def list_conversations do'` returns `1`.

### `test/cairnloop/chat_test.exs`

- Added `aggregate/3` and `all/1` stubs to `MockRepo` — both record call args in the process dictionary for headless query-shape assertion.
- Added `describe "scope_status/2 (via list_conversations/1 + count_conversations/1)"` with 5 tests:
  - `:resolved` status → scoped query contains "resolved" in inspect output
  - `nil` status → unscoped query (wheres == [])
  - `:bogus` status → unscoped query (D-03 defense-in-depth, wheres == [])
  - `count_conversations/1` → `aggregate(:count, :id)` called, `all/1` NOT called
  - `count_conversations/0` → aggregate called on unscoped queryable
- Added two `# REPO-UNAVAILABLE` round-trip tests as comments for CI `:integration` lane.

## TDD Gate Compliance

- **RED commit:** `9c87326` — `test(39-01): add failing scope_status/2 + count tests (RED)` — all 5 new tests failed with `UndefinedFunctionError` for `list_conversations/1` and `count_conversations/1`.
- **GREEN commit:** `4a461cb` — `feat(39-01): add list_conversations/1 + count_conversations/1 + scope_status/2 (GREEN)` — all 27 `chat_test.exs` tests pass.

## Verification

- `mix compile --warnings-as-errors` passes (0 warnings).
- `mix test test/cairnloop/chat_test.exs --exclude integration` passes (27 tests, 0 failures).
- `mix test --exclude integration` passes (893 tests, 1 failure = pre-existing `OutboundWorkerTest` baseline).
- Sealed contract: exactly 1 `def list_conversations do` clause.
- `aggregate(:count, :id)` present; `to_existing_atom` absent.
- Whitelist `[:open, :resolved, :archived]` present.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unscoped count test assertion for bare schema module passthrough**
- **Found during:** Task 2 (GREEN step)
- **Issue:** Test `count_conversations/0 (no opts)` asserted `%Ecto.Query{} = query` but `scope_status(Conversation, nil)` returns the bare `Cairnloop.Conversation` module (not an `%Ecto.Query{}`) since no where clause is applied. Ecto.Repo.aggregate/3 accepts both forms.
- **Fix:** Changed assertion to `queryable == Cairnloop.Conversation or (is_struct(queryable, Ecto.Query) and queryable.wheres == [])` — correctly handles both the passthrough (raw module) and any future expansion (wrapped query).
- **Files modified:** `test/cairnloop/chat_test.exs`
- **Commit:** `4a461cb` (bundled with GREEN)

## Known Stubs

None. No placeholder values, no hardcoded empty returns wired to UI rendering.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `^status` pin in `scope_status/2` prevents SQL injection (T-39-02 mitigated). Unknown atom passthrough implements D-03 (T-39-01 mitigated).

## Self-Check: PASSED

- [x] `lib/cairnloop/chat.ex` exists and contains `def count_conversations`
- [x] `test/cairnloop/chat_test.exs` exists and contains `scope_status`
- [x] Commit `9c87326` (RED) exists in git log
- [x] Commit `4a461cb` (GREEN) exists in git log
- [x] `mix compile --warnings-as-errors` passes
- [x] `mix test test/cairnloop/chat_test.exs --exclude integration` passes (27/27)
