# Phase 31: Golden-Path JTBD Smoke Test - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 31-golden-path-jtbd-smoke-test
**Areas discussed:** cmd+k search approach, Test decomposition, Channel test end-to-end depth

---

## cmd+k search approach

| Option | Description | Selected |
|--------|-------------|----------|
| Stub via `send_update/2` | Fire real LiveViewTest event sequence into SearchModalComponent with a stub retrieval module injected via `Phoenix.LiveViewTest.send_update/2`. No pgvector round-trip. No code changes to ConversationLive. SearchModalComponent already has a `:retrieval_module` overridable assign (lines 21-22). | ✓ |
| Real pgvector | Drain ChunkRevision Oban workers in setup, search against real seeded embeddings from seeds_test. Full-stack but adds Oban drain timing fragility. | |

**User's choice:** Stub via `send_update/2` (recommended)
**Notes:** The embedding pipeline is already locked by seeds_test.exs. The smoke test should exercise the JTBD state machine, not re-prove the embedding pipeline. Advisor research confirmed the SearchModalComponent inject point at line 337 (default: Cairnloop.Retrieval).

---

## Test decomposition

| Option | Description | Selected |
|--------|-------------|----------|
| Single sequential test | One `test "full JTBD round trip"` that flows all 8+ stages. State accumulates naturally. Matches `approval_flow_test.exs` sequential-chain pattern. | ✓ |
| Per-stage describe blocks | Multiple tests, one per stage (ingress, approval, execution, outbound). Each builds its own minimal state independently. | |

**User's choice:** Single sequential test (recommended)
**Notes:** The golden path IS a state machine — forced per-stage independent setup recreates the full fixture chain for every stage, producing brittle fiction. The correct analogy is `approval_flow_test.exs` (sequential chain), not `bulk_recovery_live_test.exs` (independent behaviors).

---

## Channel test end-to-end depth

| Option | Description | Selected |
|--------|-------------|----------|
| PubSub assert only | Subscribe to Cairnloop.PubSub in test, assert `{:conversations_changed}` is received after channel push. Fast but leaves InboxLive `handle_info` → re-render path unverified. | |
| PubSub assert + InboxLive mount | Join WidgetChannel, assert PubSub broadcast fires, then mount InboxLive (connected, subscribes) and assert new conversation row appears in rendered inbox. Closes CHAT-02 "operator-side delivery" definitively. `async: false` shared sandbox handles channel process automatically. | ✓ |

**User's choice:** PubSub assert + InboxLive mount (recommended)
**Notes:** E2E-02's stated claim is "operator-side delivery" and CHAT-02 specifically names the `handle_info({:conversations_changed})` → InboxLive re-render path. Option A stops at the broadcast wire, leaving the second half of CHAT-02 unverified. The `async: false` + `shared: true` sandbox already handles the channel process without explicit `Sandbox.allow/3` calls.

---

## Claude's Discretion

Auto-decided without discussion (below the decision threshold for this profile):
- `ConnCase` for both test files (needs LiveView + ChannelTest + conn)
- Workers called directly via `perform/1` — established pattern across all 9 existing integration tests
- Both files tagged `:integration` via ConnCase automatically
- `async: false` for both tests
- No `SeedRun.run/0` in test setup — inline minimal fixtures via `Cairnloop.Fixtures`
- Phase 30 KB/EditorHandoff gates NOT exercised in golden path (separate surface, separate test suite)

## Deferred Ideas

- Channel topic re-join from `"widget:lobby"` to `"widget:{conversation_id}"` — deferred from Phase 28; still out of scope for Phase 31
- Wallaby / Selenium browser-driven smoke tests — explicitly out of scope per STATE.md
- PhoenixTest as a new test dependency — explicitly out of scope per STATE.md
