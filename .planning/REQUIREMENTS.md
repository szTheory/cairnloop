# Requirements: Cairnloop vM010 KB AI Maintenance

**Defined:** 2026-05-21
**Core Value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Milestone Gates

### Capability Selection Rubric

| Capability Family | Route Owner | Bridge Frequency | Permission / Policy Sensitivity | Support-Matrix Impact | Proof Required | Package Classification |
|-------------------|-------------|------------------|---------------------------------|-----------------------|----------------|------------------------|
| Gap detection and clustering | Cairnloop core | Low-frequency semantic | Medium | Medium | Hermetic plus seeded retrieval-event proof | core |
| AI draft article and revision suggestion generation | Cairnloop core | Low-frequency semantic | High | High | Hermetic plus citation-validity proof and operator review flow proof | core |
| Operator review dashboard and in-thread quick fix | Cairnloop core | Native screen | High | High | LiveView interaction proof and publish-guard proof | core |
| Scoria evidence/governance adapter | Optional adapter | Low-frequency semantic | Medium | Low | Advisory integration proof only | defer |

### Packaging Ledger

| Surface | Classification | Notes |
|---------|----------------|-------|
| Gap dashboard and clustered candidate queue | core | Primary operator entrypoint for KB maintenance |
| KB draft article / revision suggestion domain APIs | core | Lives inside Cairnloop-owned Phoenix/Ecto/Oban stack |
| Review task workflow with citations and diff actions | core | Required before any publish recommendation |
| In-thread quick-fix draft trigger | core | Reuses conversation evidence rail from `vM009` |
| Scoria evidence/governance lane | defer | Optional later adapter, not required for milestone closure |

### Proof Posture Gate

| Support Claim | Merge-Blocking Proof | Advisory Proof | Doctor / Operational Coverage |
|---------------|----------------------|----------------|-------------------------------|
| Retrieval miss and weak grounding signals become actionable gap candidates | Targeted tests for gap creation, clustering, and dedupe semantics | Seeded DB-backed walkthrough when repo realism lane is available | Telemetry fields and retention job documented |
| Suggested drafts and revisions remain citation-backed and non-canonical | Tests for citation presence, invalid-citation rejection, and draft persistence | Editorial walkthrough for draft quality and evidence readability | Review task metrics and publish/reject counts |
| Publish remains gated by existing KB review flow | Tests proving AI suggestions cannot bypass review/publish boundary | Manual operator flow verification | Existing publish path docs plus milestone traceability |
| Missing prerequisites fail closed with operator-visible guidance | Tests for unavailable evidence, stale sources, and disabled optional integrations | Manual UX smoke checks | Support note in docs and fallback coverage in review UI |

### Support Truth Gate

| Surface | Denial / Fallback Behavior | Missing Prerequisite Behavior | Native Rebuild Required | Rough-Edge Docs |
|---------|----------------------------|-------------------------------|-------------------------|-----------------|
| Gap dashboard | Show empty or deferred state with actionable reason instead of synthetic AI output | If insufficient signals exist, present no candidates and point operators to search / conversation evidence | No | Operator note on what creates a gap candidate |
| Draft article / revision suggestion | Refuse suggestion when citations are missing or grounding is weak; route to manual authoring | If evidence snapshot cannot be built, keep review task blocked and explain why | No | Review guidance for weak-grounding and stale-source cases |
| Review and publish workflow | Operators can reject, edit, or defer; AI cannot publish directly | If publish prerequisites fail, keep item draft-only and preserve evidence | No | KB maintenance workflow overview |
| In-thread quick fix | Falls back to manual draft creation from conversation context | If conversation lacks resolved evidence, create draft shell without recommendation | No | Conversation-to-KB quick-fix note |

## v1 Requirements

### Gap Discovery

- [x] **GAP-01**: Operator can view ranked KB gap candidates generated from retrieval no-hit, weak-grounding, and repeated manual-handling evidence.
- [x] **GAP-02**: System clusters related gap evidence into a single candidate with stable identity, freshness metadata, and supporting evidence counts.
- [x] **GAP-03**: Operator can inspect the evidence behind a gap candidate, including retrieval events, similar cases, and why the candidate was raised.

### Draft Suggestions

- [ ] **DRAFT-01**: Operator can generate a draft article suggestion from a selected gap candidate using citation-backed evidence only.
- [ ] **DRAFT-02**: Operator can generate a suggested revision for an existing KB article when retrieval evidence shows the published article is stale or incomplete.
- [ ] **DRAFT-03**: System blocks draft or revision recommendations that lack valid citations or exceed grounding confidence thresholds.

### Review Workflow

- [x] **REVIEW-01**: Operator can review a suggested article or revision with visible evidence, citation anchors, and a proposed content diff or draft body.
- [x] **REVIEW-02**: Operator can approve, reject, or edit-before-publish a review task without bypassing the existing KB publish flow.
- [x] **REVIEW-03**: System records review-task state transitions, decision metadata, and reindex follow-up work for approved KB updates.

### Quick Fix & Operations

- [ ] **OPS-01**: Operator can start a KB draft directly from conversation evidence inside the existing support workflow.
- [x] **OPS-02**: Approved KB updates trigger the normal revision publish and reindex path so retrieval reflects the new canonical content.
- [ ] **OPS-03**: System emits bounded telemetry for gap creation, draft suggestion outcomes, review decisions, and publish/reindex follow-through.

## v2 Requirements

### Optional Expansion

- **ADAPT-01**: Optional Scoria adapter persists KB-maintenance evidence and evaluation artifacts without becoming a required runtime dependency.
- **AUTO-01**: System can auto-queue low-risk maintenance chores such as stale-source detection or metadata cleanup under policy gates.
- **GOV-01**: KB maintenance review tasks can participate in broader MCP or governed-tool workflows after the core maintenance lane is proven.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Autonomous publishing of article drafts or revisions | Violates the canonical review boundary for KB content |
| External search/vector stack by default | Conflicts with the host-owned retrieval strategy already validated in `vM009` |
| Broad intent taxonomy or CRM analytics lane | This milestone is about actionable KB maintenance, not standalone analytics |
| Required Scoria integration for core milestone closure | Scoria is optional evidence/governance support, not a hard dependency |
| Customer-visible autonomous replies from maintenance suggestions | Answer automation should not expand before maintenance proof and review guardrails exist |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GAP-01 | Phase 9 | Verified |
| GAP-02 | Phase 9 | Verified |
| GAP-03 | Phase 9 | Verified |
| DRAFT-01 | Phase 10 | Pending |
| DRAFT-02 | Phase 10 | Pending |
| DRAFT-03 | Phase 10 | Pending |
| REVIEW-01 | Phase 11 | Verified |
| REVIEW-02 | Phase 11 | Complete |
| REVIEW-03 | Phase 11 | Verified |
| OPS-01 | Phase 12 | Pending |
| OPS-02 | Phase 11 | Verified |
| OPS-03 | Phase 12 | Pending |

**Coverage:**
- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-21*
*Last updated: 2026-05-22 after Phase 11 execution*
