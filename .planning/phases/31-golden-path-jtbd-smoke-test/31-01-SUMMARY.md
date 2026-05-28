---
phase: 31-golden-path-jtbd-smoke-test
plan: "01"
subsystem: integration-testing
tags: [integration, e2e, smoke-test, jtbd, liveview-test]
dependency_graph:
  requires: [phases/27, phases/28, phases/29, phases/30]
  provides: [test/integration/golden_path_test.exs]
  affects: [CI integration lane, E2E-01, E2E-03]
tech_stack:
  added: []
  patterns: [Phoenix.LiveViewTest sequential accumulating test, inline defmodule stubs, enqueue_fn capture, direct worker perform]
key_files:
  created:
    - test/integration/golden_path_test.exs
  modified: []
decisions:
  - "Stage 3 element selector uses phx-value-dom_id (underscore) not phx-value-dom-id (hyphen) — matches search_modal_component.ex template attribute"
  - "StubRetrieval returns plain list of %Cairnloop.Retrieval.Result{} structs (not plain maps) to satisfy build_sections/1 source_type field access (Pitfall 4)"
  - "Stage 3 fires toggle_search keydown with metaKey: 'true' (string) — truthy?/1 accepts both true and 'true' in the component"
  - "REPO-UNAVAILABLE: test only runs under mix test.integration with dockerized pgvector — not runnable in this workspace"
metrics:
  duration_seconds: 272
  completed: "2026-05-28"
  tasks_completed: 3
  files_modified: 1
---

# Phase 31 Plan 01: Golden-Path JTBD Smoke Test Summary

One-liner: Single sequential 9-stage integration test locking the Phases 27–30 JTBD substrate using Phoenix.LiveViewTest against real Postgres + pgvector, closing E2E-01.

## What Was Built

Created `test/integration/golden_path_test.exs` — `Cairnloop.Integration.GoldenPathTest` — a single `test "full JTBD round trip"` block with 9 accumulating `# Stage N:` inline stages that drive the full Jobs-To-Be-Done lifecycle:

| Stage | Description | Key API / Event |
|-------|-------------|-----------------|
| 1 | Seed | `conversation_fixture` + `message_fixture` |
| 2 | Inbox sees | `live(conn, "/inbox")`, assert subject |
| 3 | cmd+k search + citation chip | `send_update` StubRetrieval, toggle_search keydown, search form render_change |
| 4 | Approve AI draft | `Automation.create_draft/2`, remount, `approve_draft` event |
| 5 | Tool proposal approve | `proposal_fixture`, `Governance.request_approval/2`, `Governance.approve/3` with enqueue_fn |
| 6 | ToolExecutionWorker :success | `ApprovalResumeWorker.perform/1`, `ToolExecutionWorker.perform/1` (full Oban.Job), assert :executed |
| 7 | Resolve | `Chat.resolve_conversation/2` direct (no LiveView event) |
| 8 | Outbound trigger | remount after resolve, assert trigger_recovery_follow_up renders, render_click |
| 9 | Bulk recovery | InboxLive toggle_select → open_bulk_confirm → confirm_bulk_send, assert BulkEnvelope |

Three inline defmodule stubs (D-10): `StubContextProvider`, `InlineTestTool` (uses Cairnloop.Tool), `StubRetrieval` returning `%Cairnloop.Retrieval.Result{}` structs.

## Acceptance Criteria Met

- `test/integration/golden_path_test.exs` exists, begins with `defmodule Cairnloop.Integration.GoldenPathTest do`
- `use Cairnloop.ConnCase, async: false`
- All three inline stubs present (grep count = 3)
- `StubRetrieval.search/2` returns `%Cairnloop.Retrieval.Result{` structs (not plain maps)
- `grep -c "REPO-UNAVAILABLE"` returns 1
- No `Oban.drain_queue` or `SeedRun.run` in the file
- `grep -c "Stage [1-9]:"` returns 9
- `mix compile --warnings-as-errors` exits 0
- No new dependency in `mix.exs`
- No Wallaby / PhoenixTest in the file

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stage 3 phx-value attribute name**
- **Found during:** Task 3 implementation review
- **Issue:** Plan's stage 3 description referenced `phx-value-dom-id` (hyphen); the actual search_modal_component.ex template uses `phx-value-dom_id` (underscore) on the activate_result button
- **Fix:** Changed element selector to `[phx-click='activate_result'][phx-value-dom_id='#{dom_id}']`
- **Files modified:** test/integration/golden_path_test.exs
- **Commit:** 2ee6dfa

**2. [Rule 1 - Bug] Removed dead expression in stage 3**
- **Found during:** Task 2 implementation review
- **Issue:** Draft stage 3 code had `view |> element("[phx-target]")` with no terminal operation — a dead expression that would generate a compiler warning
- **Fix:** Removed the dead expression; the comment explaining component targeting was preserved as inline documentation
- **Files modified:** test/integration/golden_path_test.exs
- **Commit:** 2ee6dfa

**3. [Rule 1 - Bug] Removed redundant toggle/reopen sequence in stage 3**
- **Found during:** Task 2 implementation review
- **Issue:** First draft had two consecutive `toggle_search` keydowns (open → close → open) plus three `send_update` calls, creating unnecessary redundancy
- **Fix:** Consolidated to one open + one search + one activate_result; single send_update injection
- **Files modified:** test/integration/golden_path_test.exs
- **Commit:** 2ee6dfa

## Environment Constraint

`mix test.integration test/integration/golden_path_test.exs` requires dockerized Postgres + pgvector (`MIX_ENV=test`). This workspace has no pgvector extension, so the test emits `Postgrex.Error: could not open extension control file: vector.control` when run locally. This is the expected REPO-UNAVAILABLE scenario documented in CLAUDE.md — the test is correctly tagged `:integration` and excluded from `mix test`. CI will run it under the dockerized integration harness.

## Pitfalls Honored

| Pitfall | Description | Status |
|---------|-------------|--------|
| P1 | ConversationLive route is `/governance/:id` not `/:id` | Honored |
| P2 | No "resolve" event in ConversationLive — calls `Chat.resolve_conversation/2` directly | Honored |
| P3 | `trigger_recovery_follow_up` button only renders for `:resolved` + remount required | Honored |
| P4 | `StubRetrieval` returns `%Cairnloop.Retrieval.Result{}` structs, not plain maps | Honored |
| P5 | `ToolExecutionWorker.perform` requires `attempt: 1, max_attempts: 3` in Oban.Job | Honored |
| P8 | `Governance.approve/3` requires `enqueue_fn:` capture in tests | Honored |

## Requirements Closed

- **E2E-01**: `test/integration/golden_path_test.exs` covers full JTBD round trip
- **E2E-03** (contribution): Test lives in `mix test.integration` lane, no Wallaby, no PhoenixTest dep

## Commits

| Hash | Description |
|------|-------------|
| 55e02f4 | feat(31-01): Task 1 — module skeleton, inline stubs, and setup block |
| 2ee6dfa | feat(31-01): Tasks 2+3 — all 9 JTBD stages, stage-3 element selector fix |

## Self-Check: PASSED
