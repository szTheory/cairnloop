# Phase 10: Citation-Backed Draft Suggestions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `M010-S02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-21
**Phase:** M010-S02 - Citation-Backed Draft Suggestions
**Areas discussed:** Suggestion entrypoints, Stale article detection, Suggestion output shape, Operator handoff surface

---

## Suggestion entrypoints

| Option | Description | Selected |
|--------|-------------|----------|
| Gap dashboard only | New-article suggestions start only from the Phase 9 gap queue | |
| Published stale articles only | Revision suggestions start only from existing KB article surfaces | |
| Both entrypoints, one shared suggestion domain | Gap-driven article creation and stale-article revision both open the same host-owned suggestion pipeline | ✓ |

**User's choice:** Shift recommendation left; choose the cohesive default unless there is a very impactful tradeoff.
**Notes:** Recommendation locked as: support both entrypoints in Phase 10, keep the gap dashboard as the primary home, and implement stale-article generation as a thinner secondary affordance that feeds the same suggestion domain.

---

## Stale article detection

| Option | Description | Selected |
|--------|-------------|----------|
| Time-based verification only | Suggest revisions because an article is old or due for review | |
| Any single article-linked failure signal | Suggest revisions after any one problematic retrieval/support event | |
| Composite evidence gate | Require repeated recent article-linked failure plus a fresh citation-backed grounding snapshot | ✓ |

**User's choice:** Shift recommendation left; choose the cohesive default unless there is a very impactful tradeoff.
**Notes:** Recommendation locked as: age alone is insufficient; use a deterministic composite gate based on repeated article-linked failure evidence, bounded recency, published revision anchoring, and valid canonical citation support.

---

## Suggestion output shape

| Option | Description | Selected |
|--------|-------------|----------|
| Full markdown draft only | Persist full markdown for both new and revision suggestions without extra structure | |
| Structured outline or shell | Persist outline-like scaffolds as the normal output | |
| AI-authored diff or patch for revisions | Persist patch-like deltas for revision suggestions | |
| Full markdown body plus small structured metadata, with app-computed diff for revisions | Persist proposed markdown as truth and derive review diffs in-app | ✓ |

**User's choice:** Shift recommendation left; choose the cohesive default unless there is a very impactful tradeoff.
**Notes:** Recommendation locked as: persist full markdown draft bodies for both new articles and revisions, anchor revision suggestions to `base_revision_id`, and compute diffs in-app rather than storing model-authored patches as canonical truth.

---

## Operator handoff surface

| Option | Description | Selected |
|--------|-------------|----------|
| Extend the gap dashboard | Keep generation and inspection inside the existing maintenance queue screen | |
| Jump directly into the KB editor | Open AI suggestions inside the current markdown authoring surface | |
| Small dedicated suggestion review surface | Introduce a narrow review artifact screen between queue/editor concerns | ✓ |

**User's choice:** Shift recommendation left; choose the cohesive default unless there is a very impactful tradeoff.
**Notes:** Recommendation locked as: add a dedicated suggestion review surface that foregrounds evidence, grounding state, citations, and proposed body or diff, while reserving publish-shaped actions for Phase 11.

---

## the agent's Discretion

- Exact module, schema, and route names for the suggestion artifact and review surface.
- Exact threshold numbers for the composite stale gate.
- Exact prompt wording, telemetry field names, and UI copy.

## Deferred Ideas

- Pure age-based article reverification chores.
- Full review-task approvals and publish workflow.
- In-thread quick-fix initiation.
- Broader deduplication of fail-closed guards outside the direct Phase 10 seam.
