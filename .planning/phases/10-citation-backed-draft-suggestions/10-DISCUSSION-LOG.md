# Phase 10: Citation-Backed Draft Suggestions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `10-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-23
**Phase:** 10-Citation-Backed Draft Suggestions
**Areas discussed:** stale article trigger strictness, suggestion artifact shape, grounding and fallback policy, entrypoint/API cohesion

---

## Stale article trigger strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Strict composite gate | Repeated recent article-linked failures plus fresh canonical snapshot; deterministic and inspectable | ✓ |
| Looser heuristics | Broader weak-grounding/manual patterns create more actionable candidates earlier | |
| Age/timestamp-driven trigger | Time-since-publish or time-since-update drives stale suggestions | |

**User's choice:** Recommendation-driven lock. User explicitly asked for deep one-shot recommendations with preference shifted left.
**Notes:** Research favored low false positives, strong operator trust, and coherence with existing `StaleArticleSignal` and evidence-first product posture.

---

## Suggestion artifact shape

| Option | Description | Selected |
|--------|-------------|----------|
| Full markdown body as canonical truth | Persist complete proposed markdown and derive diff for revisions | ✓ |
| Patch/diff-first storage | Persist AI-authored patch as the primary artifact | |
| Outline/skeleton-first storage | Persist only structure or shell and expect manual completion | |

**User's choice:** Recommendation-driven lock.
**Notes:** Full markdown best matches `KnowledgeBase.save_draft/2`, current Ecto schemas, and least-surprise authoring handoff. Outline/shell remains only a fallback posture.

---

## Review surface truth model

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated suggestion review lane | Proposal, evidence, and decision truth live in a separate review surface before editing | ✓ |
| Reuse editor as first stop | Suggestion opens directly in the editor | |

**User's choice:** Recommendation-driven lock.
**Notes:** Research aligned this with GitHub PR review and explicit suggestion-review workflows: review before mutation, then manual edit if needed.

---

## Grounding and fallback policy

| Option | Description | Selected |
|--------|-------------|----------|
| Strict block by default | Missing or weak canonical citation grounding blocks normal suggestion generation | ✓ |
| Shell fallback | Create a visibly incomplete shell when maintenance need is real but grounding is incomplete | |
| Permissive best-effort suggestion | Generate a full draft anyway with warnings | |

**User's choice:** Recommendation-driven lock with narrow exception.
**Notes:** Shell fallback was retained only as a future quick-fix exception, not a general Phase 10 suggestion behavior. Best-effort full drafts were rejected as trust-eroding.

---

## Entry point and API cohesion

| Option | Description | Selected |
|--------|-------------|----------|
| One shared suggestion lane with multiple entrypoints | One domain, one artifact model, one review lane, separate launch surfaces | ✓ |
| Separate flows per entrypoint | Gap, stale revision, and thread quick fix each own their own workflow | |
| Shared backend with split operator UIs | Same domain contract with diverging operator surfaces | |

**User's choice:** Recommendation-driven lock.
**Notes:** Keep separate launch affordances but one suggestion/review truth. Public API should stay small and Phoenix-context shaped.

---

## the agent's Discretion

- Exact threshold tuning for stale-signal windows and counts.
- Exact schema/helper names for internal preparation and evidence-building modules.
- Exact copy and layout in the review lane, as long as provenance is obvious before editing.
- Exact telemetry field names, as long as they remain low-cardinality and operational.

## Deferred Ideas

- Hygiene sweeps based on article age or republish age.
- Advisory stale watchlists with looser heuristics.
- Patch-first persistence or editor-first AI review.
- General shell fallback outside future thread quick-fix initiation.
