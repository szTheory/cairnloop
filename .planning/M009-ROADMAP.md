# M009 Roadmap: Retrieval-First Support Answers & Search Ops

## Overview
**Goal:** Turn the shipped Knowledge Base substrate into visible product value through grounded retrieval, trustworthy operator search, and inspectable answer quality.
**Architecture:** Host-owned hybrid retrieval using `pgvector` plus PostgreSQL full-text search, asynchronous indexing with Oban, and retrieval telemetry that feeds Scoria traces and Parapet-safe metrics.

## Requirements
- **M009-REQ-01**: System indexes published Knowledge Base revisions into a hybrid retrieval corpus that supports both semantic similarity and keyword search.
- **M009-REQ-02**: System indexes resolved conversation summaries separately from Knowledge Base content and marks them as assistive evidence rather than canonical policy.
- **M009-REQ-03**: System updates retrieval indexes asynchronously via Oban when Knowledge Base revisions publish and when conversations resolve.
- **M009-REQ-04**: Operator can open a global `cmd+k` search and query Knowledge Base content plus similar resolved cases from the LiveView dashboard.
- **M009-REQ-05**: Search results enforce tenant and visibility filtering before ranking and show clear source cues such as content type, recency, and citation target.
- **M009-REQ-06**: AI drafting can request grounded retrieval context before proposing a response.
- **M009-REQ-07**: Drafts display supporting citations or retrieved evidence and fall back to escalation when retrieval confidence is weak or no trustworthy sources exist.
- **M009-REQ-08**: System emits retrieval telemetry for latency, hit/miss, ranking outcomes, and grounding decisions using Scoria- and Parapet-safe contracts.
- **M009-REQ-09**: System records failed searches and no-hit retrieval events so future knowledge-gap workflows can prioritize missing content from real evidence.

## Phases

- [ ] **Phase 1: Hybrid Retrieval Corpus & APIs** - Build the durable retrieval corpus, indexing jobs, and internal retrieval boundary
- [ ] **Phase 2: Operator Search Experience** - Turn retrieval into a trustworthy keyboard-first operator workflow
- [ ] **Phase 3: Grounded Drafting & Citations** - Feed grounded retrieval into the AI draft loop with inspectable evidence
- [ ] **Phase 4: Retrieval Telemetry & Gap Signals** - Measure retrieval quality and preserve no-hit evidence for future gap clustering
- [x] **Phase 5: Search Scope Enforcement & Operator Search Closure** - Close the remaining search safety blocker on non-conversation surfaces and backfill Phase 2 verification
- [x] **Phase 6: Retrieval Corpus Verification Closure** - Backfill Phase 1 verification and validation evidence so retrieval corpus requirements can close cleanly
- [x] **Phase 7: Grounded Drafting Verification Closure** - Backfill Phase 3 verification and manual review evidence for grounded drafting requirements
- [x] **Phase 8: Gap Signal Semantics & Telemetry Closure** - Reconcile telemetry/gap-storage semantics and backfill Phase 4 verification evidence

## Phase Details

### Phase 1: Hybrid Retrieval Corpus & APIs
**Goal**: Build a host-owned retrieval layer over published Knowledge Base content and resolved support evidence.
**Depends on**: Nothing
**Requirements**: M009-REQ-01, M009-REQ-02, M009-REQ-03
**Success Criteria**:
  1. Publishing a Knowledge Base revision and resolving a conversation each enqueue durable indexing work through Oban.
  2. Retrieval queries can combine keyword and vector matches through one internal API without leaking tenant or visibility boundaries.
  3. Retrieved conversation evidence is stored and labeled separately from canonical Knowledge Base facts.
**Plans**: 2 plans
Plans:
- [x] `M009-S05-01-PLAN.md` — Make every search mount explicitly scoped or fail closed, enforce provider-side filtering before ranking, and prove the runtime slice with targeted search tests.
- [x] `M009-S05-02-PLAN.md` — Backfill Phase 2 verification, update validation state, and move operator-search requirement traceability to verified.

### Phase 2: Operator Search Experience
**Goal**: Make grounded retrieval feel fast and trustworthy for operators inside the dashboard.
**Depends on**: Phase 1
**Requirements**: M009-REQ-04, M009-REQ-05
**Success Criteria**:
  1. Operator can open a global `cmd+k` search and query both Knowledge Base content and similar resolved cases.
  2. Search results expose source type, recency, and citation targets while enforcing visibility and tenant safety.
  3. Search works through Cairnloop retrieval APIs rather than direct remote HTTP calls from UI components.
**Plans**: 1 plan
Plans:
- [x] `M009-S07-01-PLAN.md` — Create the durable Phase 3 verification artifact, record the freshness and limits of the focused proof lane, capture manual editorial closure checks, and update validation plus requirement traceability for `M009-REQ-06` and `M009-REQ-07`.
**UI hint**: yes

### Phase 3: Grounded Drafting & Citations
**Goal**: Improve draft quality by grounding AI responses in retrieved evidence before the operator reviews them.
**Depends on**: Phase 1
**Requirements**: M009-REQ-06, M009-REQ-07
**Success Criteria**:
  1. Draft generation requests retrieval context before producing a proposal.
  2. Drafts show supporting citations or evidence references in a form the operator can inspect quickly.
  3. Retrieval misses or weak evidence push the workflow toward escalation instead of pretending certainty.
**Plans**: 1 plan
Plans:
- [x] `M009-S08-01-PLAN.md` — Repair Phase 4 gap-event semantics, persist assistive-only search outcomes with bounded durable semantics, and backfill verification plus validation closure for `M009-REQ-08` and `M009-REQ-09`.

### Phase 4: Retrieval Telemetry & Gap Signals
**Goal**: Make retrieval quality inspectable and preserve evidence for the next knowledge-gap milestone.
**Depends on**: Phase 1, Phase 2, Phase 3
**Requirements**: M009-REQ-08, M009-REQ-09
**Success Criteria**:
  1. Retrieval traces capture latency, hit/miss outcomes, and grounding decisions without unsafe label cardinality.
  2. No-hit and failed-search events persist in a form that can seed future gap clustering work.
  3. Operators and developers can tell whether retrieval improved or weakened answer quality over time.
**Plans**: TBD

### Phase 5: Search Scope Enforcement & Operator Search Closure
**Goal**: Close the remaining operator-search blocker by enforcing tenant and visibility scope on every mounted surface and provider path.
**Depends on**: Phase 2, Phase 4
**Requirements**: M009-REQ-04, M009-REQ-05
**Gap Closure**: Closes the audit's non-conversation search-scope integration blocker and broken operator-search flow.
**Success Criteria**:
  1. Inbox, Settings, and conversation surfaces all pass the user/scope context needed for retrieval safely.
  2. `KnowledgeBase` and `ResolvedCases` enforce tenant and visibility filtering before ranking on every search path.
  3. Phase 2 receives explicit verification evidence showing operator search now satisfies the full filtering contract.
**Plans**: TBD
**UI hint**: yes

### Phase 6: Retrieval Corpus Verification Closure
**Goal**: Convert implemented retrieval corpus work into auditable closure evidence for the Phase 1 requirements.
**Depends on**: Phase 1
**Requirements**: M009-REQ-01, M009-REQ-02, M009-REQ-03
**Gap Closure**: Closes the audit's orphaned Phase 1 requirements and missing `M009-S01` verification artifact.
**Success Criteria**:
  1. `M009-S01` gains a `VERIFICATION.md` that maps each requirement to concrete test and implementation evidence.
  2. `M009-S01` validation state matches the actual completed test surface instead of remaining draft-only.
  3. Requirement traceability reflects that Phase 1 evidence has been revalidated and closed through the gap phase.
**Plans**: 1 plan
Plans:
- [x] `M009-S06-01-PLAN.md` — Create the durable Phase 1 verification artifact, capture one realistic proof lane or explicit blocker, repair `M009-S01` validation state, and mark `M009-REQ-01..03` verified in milestone traceability.

### Phase 7: Grounded Drafting Verification Closure
**Goal**: Convert implemented grounded-drafting work into auditable closure evidence for the Phase 3 requirements.
**Depends on**: Phase 3
**Requirements**: M009-REQ-06, M009-REQ-07
**Gap Closure**: Closes the audit's orphaned Phase 3 requirements and missing `M009-S03` verification artifact.
**Success Criteria**:
  1. `M009-S03` gains a `VERIFICATION.md` that maps each requirement to concrete test and implementation evidence.
  2. Manual editorial checks for clarification tone and evidence-rail trust semantics are recorded explicitly.
  3. `M009-S03` validation state reflects the verified execution state instead of remaining draft-only.
**Plans**: TBD

### Phase 8: Gap Signal Semantics & Telemetry Closure
**Goal**: Align telemetry and durable gap storage semantics with the retrieval contract and close the remaining Phase 4 audit gaps.
**Depends on**: Phase 4, Phase 5
**Requirements**: M009-REQ-08, M009-REQ-09
**Gap Closure**: Closes the audit's Phase 4 semantic mismatch findings and missing `M009-S04` verification artifact.
**Success Criteria**:
  1. Durable gap records use tenant/visibility semantics that match the requirement language rather than UI-surface names.
  2. Assistive-only search outcomes are represented in durable gap storage as well as telemetry.
  3. `M009-S04` gains verification evidence and an updated validation state that reflects the real implementation.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Hybrid Retrieval Corpus & APIs | 2/2 | Complete | 2026-05-20 |
| 2. Operator Search Experience | 2/2 | Complete | 2026-05-20 |
| 3. Grounded Drafting & Citations | 2/2 | Complete | 2026-05-20 |
| 4. Retrieval Telemetry & Gap Signals | 3/3 | Complete | 2026-05-20 |
| 5. Search Scope Enforcement & Operator Search Closure | 2/2 | Complete | 2026-05-20 |
| 6. Retrieval Corpus Verification Closure | 1/1 | Complete | 2026-05-21 |
| 7. Grounded Drafting Verification Closure | 1/1 | Complete | 2026-05-21 |
| 8. Gap Signal Semantics & Telemetry Closure | 1/1 | Complete | 2026-05-21 |
