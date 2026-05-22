---
phase: M009-S04
slug: retrieval-telemetry-gap-signals
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-20
---

# Phase M009-S04 — Validation Strategy

> Per-phase validation contract for retrieval telemetry, durable gap evidence, scope propagation, and lightweight operator inspectability.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~25-50 seconds |

## Sampling Rate

- After retrieval contract or taxonomy changes: run `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs`
- After durable storage changes: run `mix test test/cairnloop/retrieval/gap_recorder_test.exs`
- After retention changes: run `mix test test/cairnloop/retrieval/workers/prune_gap_events_test.exs`
- After search or draft boundary wiring changes: run `mix test test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs`
- After UI trust-cue changes: run `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs`
- Before phase verification: run `mix test`

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| M009-S04-01-01 | 01 | 1 | M009-REQ-08 | T-M009-S04-01, T-M009-S04-02, T-M009-S04-03 | Retrieval search and draft-grounding emit stable bounded Cairnloop events with structured subordinate diagnostics rather than flat failure buckets | unit | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs` | ✅ passed on 2026-05-21 |
| M009-S04-02-01 | 02 | 2 | M009-REQ-09 | T-M009-S04-03, T-M009-S04-04 | Durable gap events persist sanitized, typed evidence through synchronous boundary-owned writes with append-only semantics and dedupe discipline | unit | `mix test test/cairnloop/retrieval/gap_recorder_test.exs` | ✅ passed on 2026-05-21 |
| M009-S04-02-02 | 02 | 2 | M009-REQ-09 | T-M009-S04-05 | Gap-event retention uses an explicit 90-day pruning contract through an Oban maintenance worker rather than implicit deletes | unit | `mix test test/cairnloop/retrieval/workers/prune_gap_events_test.exs` | ✅ passed on 2026-05-21 |
| M009-S04-03-01 | 03 | 3 | M009-REQ-08, M009-REQ-09 | T-M009-S04-06, T-M009-S04-08 | Search and draft boundaries propagate host scope and record no-hit, retrieval-error, and weak-grounding evidence from the correct application seams | unit | `mix test test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs` | ✅ passed on 2026-05-21 |
| M009-S04-03-02 | 03 | 3 | M009-REQ-08 | T-M009-S04-07 | Existing search and draft surfaces expose explicit no-hit and weak-grounding trust cues without raw-score chrome or a new routed console | liveview | `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs` | ✅ passed on 2026-05-21 |

## Wave 0 Requirements

- [x] Plan 01 Task 1 creates telemetry contract tests that assert event names and bounded metadata shape rather than only presence of side effects
- [x] Plan 02 Task 1 creates recorder fixtures for no-hit search, retrieval error, assistive-only grounding, clarification-limit escalation, and canonical-insufficient-detail outcomes
- [x] Plan 03 Task 1 extends search and draft boundary tests to assert `host_user_id` or surface propagation instead of only returned UI text
- [x] Plan 02 Task 2 adds a retention-pruning test or equivalent contract check so the storage lifecycle is not hand-waved

`wave_0_complete` is now `true` because the prerequisite scaffolds, implementation seams, and
focused assertions all exist in the current output and passed on 2026-05-21.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm no-hit and retrieval-error copy in search feels calm and not misleading | M009-REQ-08 | Editorial trust language can still feel wrong while tests pass | Trigger one true no-hit search and one simulated retrieval failure in the palette after implementation |
| Confirm weak-grounding and escalation explanations in the draft rail remain evidence-first and canonical-aware | M009-REQ-08 | Trust semantics are partly qualitative | Review one assistive-only or clarification-limit draft state in the conversation rail manually |

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Retrieval telemetry tests assert bounded metadata and stable event names
- [x] Gap recorder tests cover sanitized persistence, dedupe discipline, canonical-versus-assistive counts, and the Phase 8 scope repair
- [x] Retention tests prove the 90-day pruning contract
- [x] Search and draft tests assert scope propagation and durable boundary recording
- [x] No validation step depends on a new routed admin surface
- [x] `wave_0_complete: true` because the planned test scaffolds and fixtures are now implemented
- [x] `nyquist_compliant: true` because all five verification-map rows passed on 2026-05-21

Primary automated proof command:
`mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs`

Verification artifact:
`.planning/milestones/M009-phases/M009-S04/M009-S04-VERIFICATION.md`

Validation Sign-Off:
closed with residual verification risk

**Approval:** verified_with_residual_risk
