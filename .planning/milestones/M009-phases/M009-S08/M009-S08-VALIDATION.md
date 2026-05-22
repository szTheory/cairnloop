---
phase: M009-S08
slug: gap-signal-semantics-telemetry-closure
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-21
---

# Phase M009-S08 — Validation Strategy

> Phase-local validation contract for the Phase 4 telemetry and gap-semantics closure backfill.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~25-50 seconds |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| M009-S08-01-01 | 01 | 1 | M009-REQ-08 | Phase-local closure summary and original Phase 4 verification artifact agree on telemetry semantics | docs + unit | `rg -n '^# Phase M009-S04 Verification$|M009-REQ-08|M009-REQ-09' .planning/milestones/M009-phases/M009-S04/M009-S04-VERIFICATION.md && mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs` | ✅ passed on 2026-05-21 |
| M009-S08-01-02 | 01 | 1 | M009-REQ-09 | Gap recorder, retention, and boundary-owned persistence remain proven by focused suites | unit + liveview | `mix test test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs` | ✅ passed on 2026-05-21 |

## Closure Notes

- The phase summary already carries `requirements-completed: [M009-REQ-08, M009-REQ-09]`.
- The realism lane remained blocked because `Cairnloop.Repo` is unavailable in this shell.
- Closure therefore lands in `verified_with_residual_risk`, matching the underlying S04 closure
  artifact.

## Validation Sign-Off

- [x] Phase-local summary includes explicit completed requirements
- [x] Phase-local verification artifact exists
- [x] Focused proof suite is documented and green
- [x] Residual-risk posture is explicit and justified
- [x] `nyquist_compliant: true` set before completion

**Approval:** verified_with_residual_risk
