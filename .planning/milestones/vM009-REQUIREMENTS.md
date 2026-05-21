# Requirements Archive: vM009 Retrieval-First Support Answers & Search Ops

**Status:** ✅ Archived 2026-05-21

## Milestone Goal

Turn the shipped Knowledge Base substrate into visible product value by making retrieval
trustworthy, inspectable, and reusable across operator search and grounded draft generation.

## Final Requirement Outcomes

### Hybrid Retrieval Corpus

- [x] **M009-REQ-01**: System indexes published Knowledge Base revisions into a hybrid retrieval
  corpus that supports both semantic similarity and keyword search.
  Outcome: validated through Phase 6 closure evidence and focused suite reruns.
- [x] **M009-REQ-02**: System indexes resolved conversation summaries separately from Knowledge Base
  content and marks them as assistive evidence rather than canonical policy.
  Outcome: validated through retrieval corpus verification and explicit corpus separation artifacts.
- [x] **M009-REQ-03**: System updates retrieval indexes asynchronously via Oban when Knowledge Base
  revisions publish and when conversations resolve.
  Outcome: validated through indexing workers, enqueue hooks, and closure verification.

### Operator Search

- [x] **M009-REQ-04**: Operator can open a global `cmd+k` search and query Knowledge Base content
  plus similar resolved cases from the LiveView dashboard.
  Outcome: validated through Phase 5 scope closure and operator search verification.
- [x] **M009-REQ-05**: Search results enforce tenant and visibility filtering before ranking and
  show clear source cues such as content type, recency, and citation target.
  Outcome: validated through provider-side filtering, fail-closed mounting, and trust-cue tests.

### Grounded Drafting

- [x] **M009-REQ-06**: AI drafting can request grounded retrieval context before proposing a
  response.
  Outcome: validated through Phase 7 closure artifacts and focused grounded-drafting reruns.
- [x] **M009-REQ-07**: Drafts display supporting citations or retrieved evidence and fall back to
  escalation when retrieval confidence is weak or no trustworthy sources exist.
  Outcome: validated through operator evidence-rail behavior and explicit clarification or
  escalation handling.

### Retrieval Telemetry & Gap Signals

- [x] **M009-REQ-08**: System emits retrieval telemetry for latency, hit or miss, ranking
  outcomes, and grounding decisions using Scoria- and Parapet-safe contracts.
  Outcome: validated through bounded retrieval telemetry plus Phase 8 closure evidence.
- [x] **M009-REQ-09**: System records failed searches and no-hit retrieval events so future
  knowledge-gap workflows can prioritize missing content from real evidence.
  Outcome: validated through durable gap-event storage, retention, corrected semantics, and
  closure verification.

## Final Traceability

| Requirement | Final Phase | Status | Evidence |
|-------------|-------------|--------|----------|
| M009-REQ-01 | Phase 6 (M009) | Verified | `M009-S01-VERIFICATION.md` |
| M009-REQ-02 | Phase 6 (M009) | Verified | `M009-S01-VERIFICATION.md` |
| M009-REQ-03 | Phase 6 (M009) | Verified | `M009-S01-VERIFICATION.md` |
| M009-REQ-04 | Phase 5 (M009) | Verified | `M009-S02-VERIFICATION.md` |
| M009-REQ-05 | Phase 5 (M009) | Verified | `M009-S02-VERIFICATION.md` |
| M009-REQ-06 | Phase 7 (M009) | Verified | `M009-S03-VERIFICATION.md` |
| M009-REQ-07 | Phase 7 (M009) | Verified | `M009-S03-VERIFICATION.md` |
| M009-REQ-08 | Phase 8 (M009) | Verified | `M009-S04-VERIFICATION.md` |
| M009-REQ-09 | Phase 8 (M009) | Verified | `M009-S04-VERIFICATION.md` |

## Out of Scope At Close

- External vector or search infrastructure as the default retrieval path.
- Real-time indexing of every live conversation message.
- Autonomous customer-visible replies based only on retrieval confidence.
- Full external MCP exposure of retrieval and search during this milestone.

## Deferred Follow-On Work

- Centralize search fail-closed surface guards instead of keeping duplicated mounted-surface lists.
- Unblock repo-backed realism lanes so future closure artifacts can include live DB-backed proof
  instead of residual-risk wording.

## Forward Candidates

The following future requirements remain candidates for later milestones and were not part of the
`vM009` success contract:

- `M010-FUTURE-01`: Classify support intents durably and cluster recurring unsupported issues into
  ranked knowledge gaps.
- `M011-FUTURE-01`: Expose policy-gated support tools to the drafting loop with operator approval
  and audit snapshots.
- `M012-FUTURE-01`: Trigger transactional support outbound flows for incident recovery and bug-fix
  follow-up.
