---
phase: 42-cross-screen-threading
plan: "02"
subsystem: domain-facade
tags: [chat, knowledge-automation, facade-read, cheap-read, thread-01, thread-03b]
dependency_graph:
  requires: []
  provides: [Chat.next_open_conversation/1, KnowledgeAutomation.originating_conversation_id/2]
  affects: [plans/42-04, plans/42-05]
tech_stack:
  added: []
  patterns: [select-id-only cheap read, apply_scope/2 operator scope, parameterized ^ Ecto pins, repo() indirection]
key_files:
  created: []
  modified:
    - lib/cairnloop/chat.ex
    - lib/cairnloop/knowledge_automation.ex
    - test/cairnloop/chat_test.exs
    - test/cairnloop/knowledge_automation_test.exs
decisions:
  - "Additive sibling placement in Chat — sealed list_conversations/count_conversations clauses untouched"
  - "apply_scope/2 piped before the conversation_quick_fix filter — operator scope honored (V4, T-42-04)"
  - "order_by desc: c.id as deterministic tiebreak for next_open_conversation (D-07)"
  - "order_by asc: s.inserted_at for earliest origin in originating_conversation_id (A2)"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 4
---

# Phase 42 Plan 02: Domain Facade Reads for Cross-Screen Threading Summary

**One-liner:** Two cheap select-id facade reads — `Chat.next_open_conversation/1` (inbox-order next-open id) and `KnowledgeAutomation.originating_conversation_id/2` (article→conversation-quick-fix origin) — backing THREAD-01 and THREAD-03b.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing tests for Chat.next_open_conversation/1 | eab20ec | test/cairnloop/chat_test.exs |
| 1 (GREEN) | Chat.next_open_conversation/1 implementation | aa71c33 | lib/cairnloop/chat.ex |
| 2 (RED) | Failing tests for KnowledgeAutomation.originating_conversation_id/2 | 57d380c | test/cairnloop/knowledge_automation_test.exs |
| 2 (GREEN) | KnowledgeAutomation.originating_conversation_id/2 implementation | 8e39278 | lib/cairnloop/knowledge_automation.ex |

## What Was Built

### Task 1: Chat.next_open_conversation/1

Added to `lib/cairnloop/chat.ex` as an additive sibling to `list_conversations/1`. Sealed
`list_conversations/0`, `list_conversations/1`, `count_conversations/1`, and `scope_status/2`
are untouched.

```elixir
def next_open_conversation(current_id) do
  Conversation
  |> where([c], c.status == :open and c.id != ^current_id)
  |> order_by([c], desc: c.updated_at, desc: c.id)
  |> limit(1)
  |> select([c], c.id)
  |> repo().one()
end
```

- `select([c], c.id)` — id-only, never loads the full row (D-07)
- `order_by desc: updated_at, desc: id` — mirrors inbox order with deterministic tiebreak (D-04/D-07)
- `^current_id` — parameterized pin, never interpolated (T-42-05)
- Returns nil when queue is clear (D-06)
- Routes through `repo()` indirection — no raw `Cairnloop.Repo`

### Task 2: KnowledgeAutomation.originating_conversation_id/2

Added to `lib/cairnloop/knowledge_automation.ex` as an additive sibling to `list_article_suggestions/1`.

```elixir
def originating_conversation_id(article_id, opts \\ []) do
  ArticleSuggestion
  |> apply_scope(opts)
  |> where([s], s.article_id == ^article_id and s.entrypoint_type == :conversation_quick_fix)
  |> order_by([s], asc: s.inserted_at)
  |> limit(1)
  |> select([s], s.entrypoint_id)
  |> repo().one()
end
```

- `apply_scope(opts)` before the filter — tenant_scope + host_user_id honored (V4 access control, T-42-04)
- `entrypoint_type == :conversation_quick_fix` — only this type carries a conversation id (D-12)
- `order_by asc: inserted_at` — earliest origin when multiple suggestions for same article (A2)
- `select([s], s.entrypoint_id)` — id-only, minimal field exposure (T-42-06)
- `^article_id` — parameterized, never interpolated (T-42-05)
- Returns nil for :gap_candidate/:article_revision or unknown article_id (honest absence, D-12)
- Routes through `repo()` indirection — no raw `Cairnloop.Repo`

## Test Coverage

Both test files follow the REPO-UNAVAILABLE pattern from CLAUDE.md:

- **Headless (run in plain `mix test`):** query shape assertions using MockRepo — verify `one/1` is
  called (not `all/1`, not `aggregate`); verify nil-return for unknown ids; verify opts default
- **REPO-UNAVAILABLE (commented, for `mix test.integration`):** round-trip cases for actual DB
  behavior — next-open id, exclusion, queue-clear nil, tiebreak determinism, entrypoint_type
  discrimination, scope enforcement, earliest-origin selection

## Deviations from Plan

None — plan executed exactly as written. All implementation shapes match the PATTERNS.md exact
fn shapes verbatim.

## Threat Model Coverage

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-42-04 | apply_scope/2 in originating_conversation_id/2 | Implemented |
| T-42-05 | ^ parameterized pins in both functions | Implemented |
| T-42-06 | select(:id)/select(:entrypoint_id) only | Implemented |

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced. Both functions
are read-only facade reads with existing scope guards applied.

## Known Stubs

None — both functions are complete implementations with no placeholder values.

## Self-Check: PASSED

- [x] `lib/cairnloop/chat.ex` contains `def next_open_conversation(`
- [x] `lib/cairnloop/knowledge_automation.ex` contains `def originating_conversation_id(`
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/cairnloop/chat_test.exs test/cairnloop/knowledge_automation_test.exs` exits 0 (39 tests, 0 failures)
- [x] No `Cairnloop.Repo` direct usage in either lib file
- [x] No schema changes in either module
- [x] Commits eab20ec, aa71c33, 57d380c, 8e39278 all exist in git log
