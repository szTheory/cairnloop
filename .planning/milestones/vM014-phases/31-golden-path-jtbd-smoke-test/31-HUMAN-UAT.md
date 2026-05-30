---
status: resolved
phase: 31-golden-path-jtbd-smoke-test
source: [31-VERIFICATION.md]
started: 2026-05-28T17:45:00Z
updated: 2026-05-28T23:50:00Z
---

## Current Test

Both integration tests pass under Docker pgvector (PGPORT=5433).

## Tests

### 1. Full JTBD round trip (golden_path_test.exs)
expected: `mix test.integration test/integration/golden_path_test.exs` exits 0 — the single sequential 9-stage `test "full JTBD round trip"` passes against real Postgres + pgvector
result: PASSED — ran via Docker (`PGPORT=5433 MIX_ENV=test mix test --include integration test/integration/golden_path_test.exs`) on 2026-05-28. 2 fixes required: (1) `proposal_fixture` needed `conversation_id: conversation.id` top-level key so `Governance.list_proposals_for_conversation` finds it; (2) `Chat.resolve_conversation/2` `DateTime.diff/3` called with NaiveDateTime from `timestamps()` — fixed by coercing to UTC DateTime. Also added `priv/test_host/migrations/20260527070000_add_conversation_slas.exs` for the host-owned SLA table.

### 2. Widget channel ingress + operator delivery (widget_channel_test.exs)
expected: `mix test.integration test/integration/widget_channel_test.exs` exits 0 — channel join/push/process/operator-delivery test passes against real Postgres + pgvector
result: PASSED — ran via Docker (`PGPORT=5433 MIX_ENV=test mix test --include integration test/integration/widget_channel_test.exs`) on 2026-05-28.

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
