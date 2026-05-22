---
phase: M009-S03
slug: grounded-drafting-citations
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-18
---

# Phase M009-S03 — Validation Strategy

> Validation state after Phase 7 backfill execution for grounded drafting, weak-grounding fallback,
> and operator-visible evidence review.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs test/cairnloop/web/conversation_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-45 seconds |

## Sampling Rate

- After retrieval/engine contract changes: run `mix test test/cairnloop/automation/scoria_engine_test.exs`
- After worker or persistence changes: run `mix test test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs`
- After evidence-rail rendering changes: run `mix test test/cairnloop/web/conversation_live_test.exs`
- Before phase verification: run `mix test`

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| M009-S03-01-01 | 01 | 1 | M009-REQ-06 | T-M009-S03-01 | Draft generation requests retrieval context through the host-owned retrieval boundary before proposal generation | unit | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs` | ✅ focused suite passed on 2026-05-21 |
| M009-S03-01-02 | 01 | 1 | M009-REQ-06, M009-REQ-07 | T-M009-S03-02 | Strong, clarification, and escalation grounding outcomes persist distinct structured proposal state | unit | `mix test test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs` | ✅ focused suite passed on 2026-05-21 |
| M009-S03-02-01 | 02 | 2 | M009-REQ-07 | T-M009-S03-03 | Conversation rail renders operator summary, source/trust cues, excerpts, and citation/open targets without polluting the reply body | liveview | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ focused suite passed on 2026-05-21 |
| M009-S03-02-02 | 02 | 2 | M009-REQ-06, M009-REQ-07 | T-M009-S03-04 | Weak grounding never appears as a normal trustworthy reply path in the operator UI | liveview | `mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/automation/workers/draft_worker_test.exs` | ✅ suite passed; realism lane blocked by repo/runtime setup |

## Phase 7 Closure State

- Primary automated proof command:
  `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs test/cairnloop/web/conversation_live_test.exs`
- Fresh observed result on `2026-05-21`:
  `39 tests, 0 failures`
- Preserved caveat:
  test boot still logs `Chimeway.Repo` missing-`:database` startup noise before the suite runs.
- Realism lane status:
  attempted exactly once via `MIX_ENV=test mix run ... ground_for_draft(...)`, but blocked because
  `Cairnloop.Repo` is not available in this shell. See `M009-S03-VERIFICATION.md` for the exact
  command and failure record.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm evidence rail copy keeps KB truth distinct from resolved-case support | M009-REQ-07 | Editorial trust language can still feel wrong while tests pass | Completed through implementation review and `ConversationLive` test assertions on 2026-05-21 |
| Confirm clarification branch asks one bounded question and does not read like a confident answer | M009-REQ-07 | Tone and operator clarity are partly qualitative | Completed through implementation review and structured proposal / LiveView test review on 2026-05-21 |

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Worker tests cover normal draft, clarification, escalation, and deny branches
- [x] `ConversationLive` tests assert source/trust and citation visibility, not just raw text presence
- [x] No verification path depends on direct remote retrieval from `ScoriaEngine`
- [x] `nyquist_compliant: true` set before completion

**Approval:** closed with residual verification risk

The closure artifact is `.planning/milestones/M009-phases/M009-S03/M009-S03-VERIFICATION.md`.
Focused automated proof is fresh and green, while the realism lane remained environment-blocked
without exposing a real grounding/trust defect. Closure therefore lands in
`verified_with_residual_risk` rather than a defect-blocked posture.
