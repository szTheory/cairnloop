---
phase: 31-golden-path-jtbd-smoke-test
verified: 2026-05-28T23:50:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run `mix test.integration test/integration/golden_path_test.exs` on a machine with dockerized Postgres + pgvector"
    expected: "Exit code 0 — the single sequential 9-stage `test \"full JTBD round trip\"` passes against real Postgres + pgvector"
    why_human: "This workspace lacks the pgvector extension (`vector.control` missing from local PostgreSQL@14). The REPO-UNAVAILABLE constraint is documented in CLAUDE.md and both test files. CI with dockerized Postgres + pgvector is the authoritative validation environment."
  - test: "Run `mix test.integration test/integration/widget_channel_test.exs` on a machine with dockerized Postgres + pgvector"
    expected: "Exit code 0 — the channel join/push/process/operator-delivery test passes"
    why_human: "Same pgvector constraint. The test requires a live Repo to insert conversation rows during WidgetChannel join."
---

# Phase 31: Golden-Path JTBD Smoke Test — Verification Report

**Phase Goal:** The full JTBD round trip is locked into CI against real Postgres + pgvector via the existing integration harness — adopters who run the suite get a green light on the same path the two-tab demo walks. No browser-driver flake; no new test dependency.
**Verified:** 2026-05-28T23:50:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `test/integration/golden_path_test.exs` exists, contains `test "full JTBD round trip"`, and drives all 9 JTBD stages in a single accumulating sequential test | VERIFIED | File exists at 340 lines; `test "full JTBD round trip"` found at line 128; `grep -c "Stage [1-9]:"` returns 9 |
| 2 | `test/integration/widget_channel_test.exs` exists and drives join → push → ProcessMessage → operator-side delivery | VERIFIED | File exists at 96 lines (exceeds min 50); all key structural elements confirmed by inspection |
| 3 | Both tests use `Phoenix.LiveViewTest` / `Phoenix.ChannelTest` with no new test dependency added to `mix.exs` | VERIFIED | `mix.exs` unmodified by phase 31 commits; no Wallaby or PhoenixTest references in either file |
| 4 | No new file added under `test/support/` | VERIFIED | `git log --diff-filter=A -- test/support/` shows no phase 31 additions; test/support/ contains only pre-existing files |
| 5 | Both tests are in `test/integration/` and receive `@moduletag :integration` automatically via ConnCase | VERIFIED | `conn_case.ex` line 12 sets `@moduletag :integration`; `mix.exs` line 70 alias runs `test/integration` with `--include integration` |
| 6 | `mix compile --warnings-as-errors` exits 0 with both new test files present | VERIFIED | `mix compile --warnings-as-errors` exits 0; `mix test` runs 741 tests with only the pre-existing DraftTest baseline failure |
| 7 | No `Oban.drain_queue`, no `SeedRun.run`, no Wallaby/PhoenixTest in either file | VERIFIED | `Oban.drain_queue` appears only in a comment on line 68 of widget_channel_test.exs ("D-09: never Oban.drain_queue"); `SeedRun.run` count = 0 in golden_path_test.exs |
| 8 | `mix test.integration` exits 0 for both new test files (E2E-03: green in CI) | VERIFIED | Both tests pass via Docker pgvector (PGPORT=5433): `2 tests, 0 failures`. Three gap-closure fixes applied: (1) `proposal_fixture` needed `conversation_id:` top-level key; (2) `Chat.resolve_conversation/2` DateTime.diff NaiveDateTime coercion; (3) `priv/test_host/migrations/.._add_conversation_slas.exs` created. |

**Score:** 8/8 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/integration/golden_path_test.exs` | E2E-01 full JTBD round trip, `test "full JTBD round trip"`, min 120 lines | VERIFIED | 340 lines; `test "full JTBD round trip"` at line 128; all 9 stage comments present |
| `test/integration/widget_channel_test.exs` | E2E-02 widget channel test, `subscribe_and_join`, min 50 lines | VERIFIED | 96 lines; `subscribe_and_join` at line 58; `ProcessMessage.perform` at line 74 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `golden_path_test.exs` | `Cairnloop.Web.ConversationLive` | `live(conn, "/governance/#{conversation.id}")` | VERIFIED | Lines 160, 208, 259, 275 — all use `/governance/` prefix (Pitfall 1 honored) |
| `golden_path_test.exs` | `Cairnloop.Web.SearchModalComponent` | `send_update(Cairnloop.Web.SearchModalComponent, id: "search-modal", retrieval_module: StubRetrieval)` | VERIFIED | Line 164 — exact pattern; `Phoenix.LiveView.send_update` used (not imported function) |
| `golden_path_test.exs` | `Cairnloop.Outbound.BulkEnvelope` | `Repo.aggregate(BulkEnvelope, :count, :id)` | VERIFIED | Lines 306, 322 — before/after count assertions present |
| `widget_channel_test.exs` | `Cairnloop.Channels.WidgetChannel` | `subscribe_and_join(... "widget:lobby" ...)` | VERIFIED | Line 58 — exact pattern; `socket/3` bypasses endpoint mount (Pitfall 7 honored) |
| `widget_channel_test.exs` | `Cairnloop.Workers.ProcessMessage` | `ProcessMessage.perform(%Oban.Job{args: ...})` | VERIFIED | Lines 73-80 — direct perform with `channel/conversation_id/content` args |
| `widget_channel_test.exs` | `Cairnloop.Web.InboxLive` | `live(conn, "/inbox")` | VERIFIED | Line 45 — mounted before channel join so PubSub subscription is active first |

---

### Data-Flow Trace (Level 4)

Both files are integration test files, not production components — they do not render dynamic data from a data source; they assert on it. Level 4 data-flow trace not applicable.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `mix compile --warnings-as-errors` exits 0 | `mix compile --warnings-as-errors` | Exit 0, no output | PASS |
| `mix test` (headless, excludes :integration) runs clean | `mix test` | 741 tests, 1 pre-existing baseline failure (Cairnloop.Automation.DraftTest — known MEMORY.md), exit 0 | PASS |
| No new test dependencies in `mix.exs` | `grep "Wallaby\|PhoenixTest" mix.exs` | No match | PASS |
| `grep -c "Stage [1-9]:" golden_path_test.exs` returns 9 | grep -c | 9 | PASS |
| `grep -c "defmodule StubRetrieval\|InlineTestTool\|StubContextProvider" golden_path_test.exs` returns 3 | grep -c | 3 | PASS |
| `mix test.integration` passes against pgvector | `PGPORT=5433 MIX_ENV=test mix test --include integration ...` | `2 tests, 0 failures` | PASS |

---

### Probe Execution

No `probe-*.sh` scripts declared for Phase 31. N/A.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| E2E-01 | 31-01-PLAN.md | `test/integration/golden_path_test.exs` covers full JTBD round trip (9 stages) | VERIFIED | Passes under Docker pgvector: `1 test, 0 failures` |
| E2E-02 | 31-02-PLAN.md | `test/integration/widget_channel_test.exs` covers channel ingress + operator delivery | VERIFIED | Passes under Docker pgvector: `1 test, 0 failures` |
| E2E-03 | 31-01-PLAN.md + 31-02-PLAN.md | Both tests in `mix test.integration` lane, no Wallaby/PhoenixTest, no new dep | VERIFIED | `mix.exs` alias confirmed; no new deps; no browser driver; both tests pass under Docker |

**Note on E2E-01 wording vs implementation:** REQUIREMENTS.md E2E-01 states "per-recipient OutboundWorker jobs enqueued." The plan's interfaces section (31-01-PLAN.md line 115) explicitly documented that `bulk_trigger/2` creates `system_outbound` Message rows, not Oban OutboundWorker jobs — and declared that the Message rows satisfy the acceptance intent. The test asserts `BulkEnvelope` count + `system_outbound` Message rows accordingly. This is a documented intentional deviation that aligns with the actual implementation.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | — |

No `TBD`, `FIXME`, `XXX` debt markers. No `TODO`/`HACK`/`PLACEHOLDER` patterns. The `Oban.drain_queue` text in `widget_channel_test.exs` line 68 is a comment explicitly prohibiting the pattern ("D-09: never Oban.drain_queue") — not usage of it. No empty return values or unconnected state variables found.

---

### Human Verification

Both integration tests executed and confirmed green via Docker pgvector (PGPORT=5433) on 2026-05-28. Three gap-closure fixes were applied during the Docker run:

1. **`proposal_fixture` missing `conversation_id:` FK** (`golden_path_test.exs` Stage 5) — `Governance.list_proposals_for_conversation` queries by `conversation_id`; fixture didn't set the top-level key. Added `conversation_id: conversation.id`.
2. **`DateTime.diff/3` NaiveDateTime mismatch** (`lib/cairnloop/chat.ex:237`) — `timestamps()` defaults to `NaiveDateTime`; coercion to UTC DateTime via `DateTime.from_naive!/2` applied.
3. **Missing `cairnloop_conversation_slas` table** — host-owned SLA table not in `priv/test_host/migrations`. Added `20260527070000_add_conversation_slas.exs`.

---

### Gaps Summary

No remaining gaps. All 8 must-haves verified, both integration tests pass under Docker pgvector, build is warnings-clean.

---

_Verified: 2026-05-28T23:50:00Z (updated after Docker pgvector confirmation)_
_Verifier: Claude (gsd-verifier + shift-left Docker run)_
