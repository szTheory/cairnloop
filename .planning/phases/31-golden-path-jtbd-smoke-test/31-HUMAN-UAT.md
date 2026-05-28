---
status: partial
phase: 31-golden-path-jtbd-smoke-test
source: [31-VERIFICATION.md]
started: 2026-05-28T17:45:00Z
updated: 2026-05-28T17:45:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Full JTBD round trip (golden_path_test.exs)
expected: `mix test.integration test/integration/golden_path_test.exs` exits 0 — the single sequential 9-stage `test "full JTBD round trip"` passes against real Postgres + pgvector
result: [pending]

### 2. Widget channel ingress + operator delivery (widget_channel_test.exs)
expected: `mix test.integration test/integration/widget_channel_test.exs` exits 0 — channel join/push/process/operator-delivery test passes against real Postgres + pgvector
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
