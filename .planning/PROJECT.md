# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current Milestone: vM004 Customer Voice Activation

**Goal:** Transform the support center from a cost-center to a growth-engine by triggering actions when users are happiest.

**Target features:**
- Telemetry Triggers: High-signal `[:cairnloop, :conversation, :resolved]` pipeline.
- Sentiment Capture: Frictionless CSAT/CES metrics tracking at resolution.
- Host Extensibility: Reference handlers for the host to wire these signals to external growth actions (e.g., App Store review prompts).

## Requirements

### Validated
- ✓ Multi-Channel Ingress Engine — vM001
- ✓ AI Triage, Drafting, & Governance — vM002
- ✓ Deep Context Enrichment — vM003

### Active
- [ ] Implement resolved conversation telemetry pipeline.
- [ ] Implement CSAT capture mechanism.
- [ ] Build reference implementation for App Store prompts.

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
*Last updated: 2024-05-11 after vM003 milestone*