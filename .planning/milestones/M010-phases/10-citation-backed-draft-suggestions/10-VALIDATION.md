---
phase: 10
slug: citation-backed-draft-suggestions
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-23
validated: 2026-05-24
---

# Phase 10 — Validation Strategy

> Validated post-execution on 2026-05-24. Every planned task now maps to an automated proof that
> runs green: the full quick-run suite passes (`52 tests, 0 failures`), and phase verification
> passed (10/10 observable truths). No validation gaps remain. The DB-connection boot log noise
> (`missing the :database key in options for Chimeway.Repo`) is the known workspace baseline, not a
> regression.

## Execution Readiness

| Property | Value |
|----------|-------|
| **Planned status** | `ready_for_execution` |
| **Plan count** | `5` |
| **Wave structure** | `01 -> 02 -> 03 -> 04 -> 05` |
| **Quick run command** | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs test/cairnloop/web/knowledge_base_live_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | `~0.4 seconds for the focused suite (52 tests, measured 2026-05-24)` |

## Source Coverage Audit

### GOAL

| Source Item | Covered By | Notes |
|-------------|------------|-------|
| Operators can safely turn a gap candidate into a grounded KB draft suggestion | Plan 01, Plan 02, Plan 03, Plan 04, Plan 05 | Shared durable artifact, async generation, review surface, explicit manual-edit handoff, and gap-candidate evidence hydration cover the full create-suggestion lane |
| Operators can generate a suggested revision for a stale or incomplete published article | Plan 01, Plan 02, Plan 03, Plan 04, Plan 05 | Published revision anchor, deterministic stale gate, review UI, editor handoff, and repo-backed stale-evidence loading cover the revision lane |
| Missing citations or weak grounding fail closed | Plan 01, Plan 02, Plan 03, Plan 05 | Storage contract, generation pipeline, UI, and additive entrypoint proof all preserve failed suggestion state and reasons |

### REQ

| Requirement | Covered By | Notes |
|-------------|------------|-------|
| `DRAFT-01` | Plan 01, Plan 02, Plan 03, Plan 04, Plan 05 | Durable shared suggestion artifact, worker generation, operator review surface, explicit manual-edit handoff, and candidate-specific grounding at the shipped gap entrypoint |
| `DRAFT-02` | Plan 01, Plan 02, Plan 03, Plan 04, Plan 05 | `base_revision_id` anchor, stale-article trigger, revision proposal generation, derived diff review, authoring-target handoff, and repo-backed stale-evidence loading at the shipped article entrypoint |
| `DRAFT-03` | Plan 01, Plan 02, Plan 03, Plan 05 | Citation validation, deterministic stale/grounding gate, durable failure state, failure rendering, and end-to-end fail-closed proof on both shipped entrypoints |

### RESEARCH

| Research Constraint | Covered By | Notes |
|---------------------|------------|-------|
| Shared host-owned suggestion domain, not two pipelines | Plan 01, Plan 02 | `ArticleSuggestion` plus shared `KnowledgeAutomation` seams |
| Suggestion artifact stores full markdown, metadata, and evidence snapshot | Plan 01 | Full durable storage contract |
| Generation runs behind unique Oban worker keyed by identity + digest | Plan 02 | Dedicated worker and queueing semantics |
| Revision suggestions require published anchor and valid canonical citations | Plan 01, Plan 02 | `base_revision_id` contract and stale gate |
| Review surface is dedicated and evidence-first | Plan 03 | Suggestion review LiveView + presenter seam |
| Gap/revision entrypoints must load durable evidence on the real shipped path | Plan 05 | Gap candidate hydration plus repo-backed stale-evidence loading close the verification blockers without reopening later-phase scope |

### CONTEXT

| Decision Range | Covered By | Notes |
|----------------|------------|-------|
| D-01 to D-05 | Plan 01, Plan 02, Plan 03, Plan 04 | Shared entrypoints, one domain, gap-home primary entrypoint, stale secondary entrypoint, async unique worker, and explicit editor handoff |
| D-06 to D-10 | Plan 02 | Deterministic stale gate over repeated article-linked failures, not age-only |
| D-11 to D-17 | Plan 01, Plan 02, Plan 03 | Full markdown artifact, metadata, `base_revision_id`, derived diff, fail-closed fallback, adjacent citations |
| D-18 to D-22 | Plan 03 | Dedicated review surface with inspect/regenerate/dismiss/open-for-manual-edit only |
| D-23 to D-26 | Plan 01, Plan 02, Plan 03 | Host-owned artifact, shared evidence/grounding policy, Phoenix/Ecto/Oban posture, bounded telemetry/failure metadata |
| D-01 to D-08, D-13 to D-17 | Plan 05 | Real entrypoints keep thin UI contracts while the domain loads durable evidence, preserves strict stale gating, and continues to fail closed |

## Phase Boundary Audit

- Included in Phase 10:
  - suggestion generation from gap candidates
  - deterministic stale-revision trigger and generation
  - dedicated suggestion inspection/review surface
  - regenerate, dismiss, and open-for-manual-edit actions
  - explicit host-owned authoring-target handoff for manual editing
- Explicitly excluded from Phase 10 plans:
  - publish approval or rejection workflows
  - review-task creation or decision tracking
  - publish-triggered reindex follow-through
  - in-thread quick-fix initiation

## Sampling Rate

- After schema/context changes in Plan 01: run `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs`
- After stale-gate or worker changes in Plan 02: run `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs`
- After review-surface changes in Plan 03: run `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`
- After authoring-target and editor-handoff changes in Plan 04: run `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/web/knowledge_base_live_test.exs`
- After gap-closure entrypoint fixes in Plan 05: run `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs`
- Before phase verification: run the full quick run command above, then `mix test` if the focused suite is green

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 10-01-01 | 01 | 1 | DRAFT-01, DRAFT-02, DRAFT-03 | T-10-01, T-10-02 | Shared suggestion artifact preserves full markdown, bounded evidence rows, and canonical revision anchors without leaking publish/review-task state | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs` | COVERED ✓ |
| 10-01-02 | 01 | 1 | DRAFT-01, DRAFT-02, DRAFT-03 | T-10-03 | Public suggestion facade enforces scope and published revision anchors before queueing work | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs` | COVERED ✓ |
| 10-02-01 | 02 | 2 | DRAFT-02, DRAFT-03 | T-10-05, T-10-06 | Stale-revision gate requires repeated article-linked failures plus canonical anchors and fails closed when grounding is insufficient | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs` | COVERED ✓ |
| 10-02-02 | 02 | 2 | DRAFT-01, DRAFT-02, DRAFT-03 | T-10-04, T-10-06 | Shared worker queues uniquely by entrypoint identity plus evidence digest and persists ready or failed suggestion outcomes durably | unit | `mix test test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs test/cairnloop/knowledge_automation/article_suggestion_test.exs` | COVERED ✓ |
| 10-03-01 | 03 | 3 | DRAFT-01, DRAFT-02, DRAFT-03 | T-10-07, T-10-08 | Dedicated review surface renders both suggestion types with evidence, trust labels, grounding state, and proposal content from one lane | liveview | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | COVERED ✓ |
| 10-03-02 | 03 | 3 | DRAFT-01, DRAFT-02, DRAFT-03 | T-10-07, T-10-08 | Review actions stay limited to regenerate, dismiss, and explicit manual-edit affordances, with revision diffs derived rather than stored | liveview | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | COVERED ✓ |
| 10-04-01 | 04 | 4 | DRAFT-01, DRAFT-02 | T-10-09, T-10-10 | New-article suggestions acquire a non-published authoring target before editor navigation, while revision suggestions reuse existing article ids | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs` | COVERED ✓ |
| 10-04-02 | 04 | 4 | DRAFT-01, DRAFT-02 | T-10-09, T-10-11 | Editor handoff preloads reviewed suggestion markdown by `suggestion_id` without saving or publishing as a side effect | liveview | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | COVERED ✓ |
| 10-05-01 | 05 | 5 | DRAFT-01, DRAFT-03 | T-10-12 | Gap-driven article suggestions derive grounding from the selected candidate's durable evidence and fail closed instead of using a generic retrieval fallback | unit + liveview | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs` | COVERED ✓ |
| 10-05-02 | 05 | 5 | DRAFT-02, DRAFT-03 | T-10-13, T-10-14 | Revision suggestions load article-linked stale evidence and a fresh canonical snapshot inside the domain, then redirect into the suggestion review lane with auditable metadata | unit + liveview | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs` | COVERED ✓ |

## Wave 0 Requirements

- [x] Every planned task has an automated command
- [x] Focused test files are named and partitioned by domain, worker, and LiveView surface
- [x] No task depends on a missing pre-plan scaffold command
- [x] Phase 10 boundary exclusions are explicit in the plan set
- [x] The quick-run command spans every plan in the phase, including the additive gap-closure plan

## Manual-Only Checks To Reserve For Verification

> The mechanical aspects originally reserved here are now covered by deterministic tests at the gap
> entrypoint, stale-article entrypoint, suggestion review lane, and review-origin editor handoff (see
> VERIFICATION.md truths 9–10), so live-browser verification is no longer required for routing,
> preload, or publish suppression. Only the genuinely editorial residue below stays manual.

| Behavior | Requirement | Why Manual | Verification Instructions | Status |
|----------|-------------|------------|---------------------------|--------|
| Suggestion review copy keeps “canonical guidance” distinct from “supporting evidence” and never reads like publish approval | DRAFT-01, DRAFT-03 | Trust-language register is an editorial judgment, not a mechanical assertion | Read the suggestion review surface with one ready and one failed suggestion; confirm the brand-voice register (calm, reason-forward, never raw terms) | Manual (editorial) |
| Manual-edit handoff *feels* deliberate — the editor is not the default suggestion destination | DRAFT-01, DRAFT-02 | The experiential framing is subjective; the routing/preload mechanics below are now automated | Mechanics covered by `knowledge_base_live_test.exs` and `suggestion_review_test.exs` (routing to `/knowledge-base/:id/edit?suggestion_id=...`, authoring-target reuse/creation, `proposed_markdown` preload, publish suppression). Manual residue: judge whether the flow reads as inspect-first | Mechanics COVERED ✓ · framing Manual |

## Validation Sign-Off

- [x] Every planned task maps to an automated proof command
- [x] Requirement coverage is explicit across all five plans
- [x] Phase 11 and Phase 12 work is excluded from the plan set
- [x] The stale-revision threshold is deterministic and testable
- [x] Phase is executed and verified (10/10), and the focused suite runs green (`52 tests, 0 failures`)

The verification artifact (`10-VERIFICATION.md`) confirms these commands have actually run.

## Validation Audit 2026-05-24

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Audit method: cross-referenced all 10 tasks in the Per-Task Verification Map against the named test
files (all 5 exist), then ran the full quick-run suite — `52 tests, 0 failures` (0.4s). Every task is
COVERED by an automated proof that targets its behavior and runs green; auditor spawn was unnecessary
(no MISSING/PARTIAL gaps). Manual-only residue narrowed to two editorial/experiential judgments after
their mechanical aspects became deterministic tests. One pre-existing test-file warning fixed in the
same pass (unused default args on `valid_revision_attrs/1`).
