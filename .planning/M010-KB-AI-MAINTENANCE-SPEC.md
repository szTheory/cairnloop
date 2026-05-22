# M010 KB AI Maintenance Spec

## Summary

This spec sharpens M010 so it does not stop at intent classification and gap clustering.

The recommended product lane is:

**Use support-derived evidence to propose safe KB draft articles and KB draft revisions, while keeping the KB's canonical boundary intact.**

This is an extension of Cairnloop's existing KB JTBD, not a new top-level product.

Recommended defaults:

- operator-copilot core,
- architecture ready for hybrid maintainer evolution,
- Scoria as an optional governance/evidence lane,
- no autonomous publishing of substantive KB content.

## Product Shape

### JTBD framing

When repeated support questions expose missing or stale guidance, help operators turn support evidence into safe KB draft updates without weakening the KB's canonical status.

### Primary flows

1. **Gap-driven create**
   - Retrieval miss, weak grounding, or repeated manual handling creates a gap candidate.
   - Operator reviews the cluster and generates a new article draft.

2. **Staleness-driven update**
   - A published article keeps being retrieved but still leads to clarification, escalation, or manual rewrite.
   - Operator generates a suggested revision against the existing article.

3. **In-thread quick fix**
   - From the conversation evidence rail, the operator creates a KB draft directly from the current case.

### Product posture

- KB content remains canonical only after the existing review/publish flow.
- Resolved cases may inform drafts, but they are never treated as canonical evidence on their own.
- AI helps prepare KB work; operators remain responsible for publication.

## Architecture

### Cairnloop-owned domain

Add a narrow Cairnloop context for KB maintenance, e.g. `Cairnloop.KnowledgeAutomation`.

Suggested public API:

- `list_gap_candidates/1`
- `suggest_article/2`
- `suggest_revision/2`
- `create_review_task/2`
- `approve_review_task/2`
- `reject_review_task/2`

Suggested domain objects:

- `GapCandidate`
- `SuggestedRevision`
- `ReviewTask`
- `EvidenceSnapshot`

### Behavior seams

Add behaviours rather than hardcoded vendor logic:

- `GapDetector`
- `RevisionSuggester`
- `CitationBuilder`
- `GroundingJudge`

### Retrieval and authoring policy

- Default to hybrid retrieval for KB maintenance recommendations.
- Require citation-backed evidence for generated KB draft claims.
- Preserve a clear draft-vs-published boundary in both storage and UI.
- Support narrow later autonomy only for non-canonical operations:
  - reindexing,
  - stale-source detection,
  - metadata cleanup,
  - eval-triggered requeueing.

## Scoria Integration

Scoria should be an **optional governance/evidence lane**, not a hard dependency.

### What Scoria should provide

- retrieval-run persistence,
- citation anchor construction and validation,
- grounding score persistence,
- eval datasets/specs/runs,
- workflow/approval evidence for high-risk KB actions.

### What Cairnloop should still own

- article lifecycle,
- KB visibility/business semantics,
- operator-facing review and publish UX,
- final answer composition contract.

### Integration shape

Use a thin adapter such as `Cairnloop.ScoriaKB`.

Do not make Scoria tables part of Cairnloop's primary read model. Attach Scoria IDs as evidence references only.

## UI / DX / Validation

### Operator UX

- Add a **Gap Dashboard**, not a blank AI writing canvas.
- Evolve the KB editor into a review surface showing:
  - source evidence,
  - proposed diff,
  - citations,
  - approve / reject / edit-before-publish actions.

### Developer experience

The lane should feel like Phoenix/Ecto/Oban infrastructure, not hosted AI glue:

- Oban for clustering, drafting, reindexing, and eval jobs
- LiveView for review flows
- PubSub for live refresh
- Telemetry for retrieval, grounding, review, and publish metrics
- stable IDs / digests for source freshness and dedupe

### Test expectations

- weak grounding and no-hit signals create actionable gap candidates
- clustered evidence can generate a draft article or draft revision
- publish still runs through the normal KB revision flow
- invalid or missing citations block publish recommendation
- optional Scoria integration augments evidence without becoming required for the core flow
