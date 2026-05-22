---
phase: M010-S01
slug: gap-candidate-discovery
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-21
---

# Phase M010-S01 — Validation Strategy

> Per-phase validation contract for durable gap candidates, deterministic clustering, and the operator gap dashboard.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test test/cairnloop/knowledge_automation/gap_candidate_test.exs test/cairnloop/knowledge_automation/candidate_builder_test.exs test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-45 seconds |

## Sampling Rate

- After schema or migration changes: run `mix test test/cairnloop/knowledge_automation/gap_candidate_test.exs`
- After clustering or manual-handling rule changes: run `mix test test/cairnloop/knowledge_automation/candidate_builder_test.exs`
- After refresh or rebuild worker changes: run `mix test test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs`
- After dashboard or presenter changes: run `mix test test/cairnloop/web/knowledge_base_live/gaps_test.exs`
- Before phase verification: run the full quick run command above

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| M010-S01-01-01 | 01 | 1 | GAP-02 | Candidate and membership schemas preserve stable identity, explicit source links, and bounded score metadata without mutating retrieval gap events | unit | `mix test test/cairnloop/knowledge_automation/gap_candidate_test.exs` | passed |
| M010-S01-01-02 | 01 | 1 | GAP-02 | Public context queries preserve deterministic ordering and scoped reads | unit | `mix test test/cairnloop/knowledge_automation/gap_candidate_test.exs` | passed |
| M010-S01-02-01 | 02 | 2 | GAP-01, GAP-02 | Builder logic clusters evidence lexically, applies the explicit manual-handling threshold, and persists explainable score components | unit | `mix test test/cairnloop/knowledge_automation/candidate_builder_test.exs` | passed |
| M010-S01-02-02 | 02 | 2 | GAP-01, GAP-02 | Refresh and backfill workers rebuild candidates idempotently from durable evidence seams only | unit | `mix test test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs` | passed |
| M010-S01-03-01 | 03 | 3 | GAP-01 | Dashboard list view renders ranked candidates, reason labels, counts, and calm empty-state behavior from the read model | liveview | `mix test test/cairnloop/web/knowledge_base_live/gaps_test.exs` | passed |
| M010-S01-03-02 | 03 | 3 | GAP-03 | Detail view shows grouped retrieval evidence, manual-handling evidence, and deterministic why-raised explanations with scoped navigation | liveview | `mix test test/cairnloop/web/knowledge_base_live/gaps_test.exs` | passed |

## Wave 0 Requirements

- [x] Plan 01 creates focused schema and context tests for stable identity, memberships, and scoped reads
- [x] Plan 02 creates builder fixtures for no-hit, weak-grounding, and repeated manual-handling evidence within the 90-day retention window
- [x] Plan 02 proves refresh and rebuild reuse one clustering path instead of separate logic
- [x] Plan 03 creates LiveView tests for ranked list rendering, explicit empty state, and evidence-detail inspection
- [x] Plan 03 keeps presentation logic in a dedicated presenter seam rather than inlining trust copy throughout the LiveView

`wave_0_complete` is now `true` because the planned candidate, builder, worker, and LiveView fixtures exist and passed the focused quick-run suite.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm candidate queue copy reads as maintenance guidance rather than telemetry jargon | GAP-01 | Tone and operator trust remain partly editorial | Mount `/knowledge-base/gaps` with seeded candidates and review list labels, empty-state copy, and freshness wording |
| Confirm evidence detail makes “why raised” obvious without implying publish readiness | GAP-03 | The distinction between discovery and later suggestion/review phases is partly qualitative | Open a seeded candidate detail pane and review the reason labels, source mix, and navigation affordances manually |

## Validation Sign-Off

- [x] Every planned task has an automated command
- [x] Candidate storage, builder, worker, and dashboard proofs are mapped separately
- [x] The quick-run command covers all three Phase 9 plans
- [x] Manual checks are limited to trust-language and workflow-boundary review
- [x] `wave_0_complete: true` only after the planned fixtures and focused tests exist
- [x] `nyquist_compliant: true` only after the verification-map rows pass during execution

**Approval:** verified with residual environment risk
