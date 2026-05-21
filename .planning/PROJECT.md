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

**Closeout posture:** `vM009` is shipped and archived as a `tech_debt` milestone. All milestone
requirements are verified; the remaining debt is explicit and non-blocking.

## Next Milestone Goals

- Turn repeated retrieval misses, weak grounding, and manual support handling into actionable
  Knowledge Base maintenance work.
- Keep KB content canonical only after review and publish, while letting AI prepare safe article
  drafts and revision proposals.
- Reuse retrieval evidence, gap signals, and operator workflows from `vM009` instead of inventing
  a new top-level product lane.
- Preserve Cairnloop-owned Phoenix, Ecto, and Oban infrastructure, with Scoria as an optional
  evidence or governance lane rather than a hard dependency.

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
- [ ] Define the scoped `M010` requirement set for KB maintenance using the archived `vM009`
  evidence and the existing `M010` spec.
- [ ] Centralize search fail-closed scope guards before search expands to more mounted surfaces.
- [ ] Unblock repo-backed realism lanes so future milestone closure can include live DB-backed proof
  instead of residual-risk wording.

### Out of Scope
- External vector/search infrastructure as the default path.
- Autonomous customer-visible replies based only on retrieval confidence.
- Treating raw live conversations as canonical policy truth.

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
*Last updated: 2026-05-21 after shipping vM009*
