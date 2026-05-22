---
phase: M009-S07
slug: grounded-drafting-verification-closure
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-21
---

# Phase M009-S07 — Validation Strategy

> Phase-local validation contract for the grounded-drafting closure backfill.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs test/cairnloop/web/conversation_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-45 seconds |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| M009-S07-01-01 | 01 | 1 | M009-REQ-06 | Closure artifact proves retrieval grounding is requested before proposal generation | docs + unit | `rg -n '^# Phase M009-S03 Verification$|M009-REQ-06|M009-REQ-07' .planning/milestones/M009-phases/M009-S03/M009-S03-VERIFICATION.md && mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs` | ✅ passed on 2026-05-21 |
| M009-S07-01-02 | 01 | 1 | M009-REQ-06, M009-REQ-07 | Draft worker and UI preserve clarification and escalation semantics under weak grounding | unit + liveview | `mix test test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs test/cairnloop/web/conversation_live_test.exs` | ✅ passed on 2026-05-21 |

## Closure Notes

- `.planning/milestones/M009-phases/M009-S07/M009-S07-01-SUMMARY.md`
  now carries `requirements-completed` frontmatter for the audit matrix.
- The realism lane remained blocked because `Cairnloop.Repo` is unavailable in this shell.
- Closure therefore lands in `verified_with_residual_risk`, matching the underlying S03 closure
  artifact.

## Validation Sign-Off

- [x] Phase-local summary includes explicit completed requirements
- [x] Phase-local verification artifact exists
- [x] Focused proof suite is documented and green
- [x] Residual-risk posture is explicit and justified
- [x] `nyquist_compliant: true` set before completion

**Approval:** verified_with_residual_risk
