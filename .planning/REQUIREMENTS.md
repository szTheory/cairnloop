# Requirements: vM009 Retrieval-First Support Answers & Search Ops

## Milestone Goal
Turn the shipped Knowledge Base substrate into visible product value by making retrieval trustworthy, inspectable, and reusable across operator search and grounded draft generation.

## Active Requirements (M009)

### Hybrid Retrieval Corpus
- [ ] **M009-REQ-01**: System indexes published Knowledge Base revisions into a hybrid retrieval corpus that supports both semantic similarity and keyword search.
- [ ] **M009-REQ-02**: System indexes resolved conversation summaries separately from Knowledge Base content and marks them as assistive evidence rather than canonical policy.
- [ ] **M009-REQ-03**: System updates retrieval indexes asynchronously via Oban when Knowledge Base revisions publish and when conversations resolve.

### Operator Search
- [ ] **M009-REQ-04**: Operator can open a global `cmd+k` search and query Knowledge Base content plus similar resolved cases from the LiveView dashboard.
- [ ] **M009-REQ-05**: Search results enforce tenant and visibility filtering before ranking and show clear source cues such as content type, recency, and citation target.

### Grounded Drafting
- [ ] **M009-REQ-06**: AI drafting can request grounded retrieval context before proposing a response.
- [ ] **M009-REQ-07**: Drafts display supporting citations or retrieved evidence and fall back to escalation when retrieval confidence is weak or no trustworthy sources exist.

### Retrieval Telemetry & Gap Signals
- [ ] **M009-REQ-08**: System emits retrieval telemetry for latency, hit/miss, ranking outcomes, and grounding decisions using Scoria- and Parapet-safe contracts.
- [ ] **M009-REQ-09**: System records failed searches and no-hit retrieval events so future knowledge-gap workflows can prioritize missing content from real evidence.

## Future Requirements
- [ ] **M010-FUTURE-01**: Classify support intents durably and cluster recurring unsupported issues into ranked knowledge gaps.
- [ ] **M011-FUTURE-01**: Expose policy-gated support tools to the drafting loop with operator approval and audit snapshots.
- [ ] **M012-FUTURE-01**: Trigger transactional support outbound flows for incident recovery and bug-fix follow-up.

## Out of Scope
- External Scrypath dependency as the default retrieval path.
- Real-time indexing of every live conversation message.
- Autonomous customer-visible replies based only on retrieval confidence.
- Full external MCP exposure of retrieval and search during this milestone.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| M009-REQ-01 | Phase 6 (M009) | Pending |
| M009-REQ-02 | Phase 6 (M009) | Pending |
| M009-REQ-03 | Phase 6 (M009) | Pending |
| M009-REQ-04 | Phase 5 (M009) | Pending |
| M009-REQ-05 | Phase 5 (M009) | Pending |
| M009-REQ-06 | Phase 7 (M009) | Pending |
| M009-REQ-07 | Phase 7 (M009) | Pending |
| M009-REQ-08 | Phase 8 (M009) | Pending |
| M009-REQ-09 | Phase 8 (M009) | Pending |
