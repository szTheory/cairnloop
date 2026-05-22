# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current State

**Latest shipped milestone:** `vM009 Retrieval-First Support Answers & Search Ops` on 2026-05-21.

**What is now true:**
- Cairnloop has a host-owned hybrid retrieval layer over published Knowledge Base content and
  resolved support evidence.
- Operators have a retrieval-backed `cmd+k` search flow with explicit source, recency, trust, and
  citation cues.
- Draft generation is grounded in retrieval evidence and surfaces clarification or escalation
  states instead of pretending certainty.
- Retrieval quality now emits bounded telemetry and durable gap signals that can seed the next
  maintenance milestone.
- Phase 9 of `vM010` now turns those durable signals into clustered KB gap candidates with a
  dedicated inspection dashboard.
- Phase 12 of `vM010` now lets operators launch bounded KB maintenance directly from conversation
  evidence, keeps shell/manual fallback inside the shared review lane, and emits coarse telemetry
  across quick-fix, publish, and reindex follow-through.

**Closeout posture:** `vM009` is shipped and archived as a `tech_debt` milestone. All milestone
requirements are verified; the remaining debt is explicit and non-blocking.

## Current Milestone: vM010 KB AI Maintenance

**Goal:** Turn retrieval misses, weak grounding, and repeated manual handling into a safe
Knowledge Base maintenance workflow.

**Target features:**
- Gap detection and clustering from retrieval no-hits, weak grounding, and repeated support
  handling.
- AI-assisted draft article creation and suggested revisions for existing KB content.
- Operator review workflow with evidence, citations, diff/review actions, and publish gated by
  the existing KB review path.
- In-thread quick-fix flow so operators can start a KB draft directly from conversation evidence.

**Why now:** `vM009` already emits retrieval telemetry and durable gap signals. The highest-leverage
next step is to turn those signals into operator-reviewed KB improvements before expanding AI
agency or external integration surface area.

## Requirements

### Validated
- ✓ Multi-Channel Ingress Engine — vM001
- ✓ AI Triage, Drafting, & Governance — vM002
- ✓ Deep Context Enrichment — vM003
- ✓ Customer Voice Activation — vM004
- ✓ Durable Auditing & SRE Observability — vM005
- ✓ Omnichannel SLA Escalation — vM006
- ✓ Semantic Search UI Foundations — vM007
- ✓ Knowledge Base Engine — vM008
- ✓ Retrieval-First Support Answers & Search Ops — vM009

### Active
- [ ] Deliver the remaining `vM010` KB maintenance scope from citation-backed suggestions through
  review-gated draft creation and revision suggestions.
- [ ] Preserve citation-backed review and publish guardrails so AI-prepared KB work never becomes
  canonical without operator approval.
- [ ] Keep the milestone inside Cairnloop-owned Phoenix, Ecto, and Oban paths, with Scoria
  remaining optional.

## Validated Requirements

- Phase 12 validated `OPS-01`: operators can start KB maintenance directly from conversation
  evidence inside the existing support workflow.
- Phase 12 validated `OPS-03`: the maintenance loop emits bounded telemetry for gap creation,
  suggestion outcomes, review decisions, and publish or reindex follow-through.

### Out of Scope
- External vector/search infrastructure as the default path.
- Autonomous customer-visible replies based only on retrieval confidence.
- Treating raw live conversations as canonical policy truth.
- Autonomous publishing of substantive KB content.
- Broad MCP or governed-tool expansion before the KB maintenance loop is operational.

## Previous Milestone Brief

<details>
<summary>Archived vM009 brief</summary>

### vM009 Retrieval-First Support Answers & Search Ops

**Goal:** Turn the Knowledge Base substrate into visible operator and AI value through grounded
retrieval, trustworthy search, and measurable answer quality.

**Target features:**
- Hybrid retrieval over published Knowledge Base revisions and resolved conversation summaries
  using `pgvector` plus PostgreSQL full-text search.
- Operator `cmd+k` search and similar-case assist inside the LiveView dashboard.
- Grounded AI draft flow with citations, retrieval telemetry, and policy-aware escalation when
  retrieval confidence is weak.
- Failed-search and no-hit analytics that feed the future knowledge-gap workflow.

**Why now:** M008 shipped the durable RAG substrate on 2026-05-17. The highest-leverage next step
is to make retrieval the trust layer before expanding into broader tool autonomy or outbound
workflows.

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-22 after completing Phase 12*
