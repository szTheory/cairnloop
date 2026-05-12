# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current Milestone: vM005 Durable Auditing & SRE Observability

**Goal:** Ensure enterprise-grade compliance and reliability for the support operations.

**Target features:**
- Immutable audit logging for critical operator actions (e.g., manual AI draft approvals, PII redaction).
- Service Level Indicators (SLIs) for support responsiveness (e.g., Time to First Response).
- Integration interfaces for external alerting and audit systems (Threadline and Parapet).

## Requirements

### Validated
- ✓ Multi-Channel Ingress Engine — vM001
- ✓ AI Triage, Drafting, & Governance — vM002
- ✓ Deep Context Enrichment — vM003
- ✓ Customer Voice Activation — vM004

### Active
- [ ] Implement Threadline integration for immutable audit logs.
- [ ] Implement Parapet integration for SLA/SLI alerting.

### Out of Scope
- Visual drip campaign builder.
- Full marketing CRM and unsubscribes.

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
*Last updated: 2026-05-12 after vM004 milestone*