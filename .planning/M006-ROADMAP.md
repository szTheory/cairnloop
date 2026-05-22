# M006 Roadmap: Omnichannel SLA Escalation (Chimeway)

## Overview
**Goal:** Route critical support events (SLA breaches, VIP tickets) to the Host's internal channels (Slack, PagerDuty, Email) without hardcoding integrations.
**Architecture:** Oban for SLA countdown jobs, Chimeway for abstracting the delivery layer, and LiveView for threshold configuration.

## Requirements
- **M006-REQ-01**: System schedules an Oban job (`CheckSLA`) when a conversation is created or updated.
- **M006-REQ-02**: The `CheckSLA` job executes idempotently, returning NOOP if the conversation is already resolved or replied to.
- **M006-REQ-03**: System defines a `Cairnloop.Notifier` behaviour for omnichannel delivery.
- **M006-REQ-04**: System integrates `Chimeway` to deliver notifications when an SLA is breached.
- **M006-REQ-05**: Host application can configure Chimeway adapters to route messages to Slack, Discord, or Email.
- **M006-REQ-06**: Operators can configure SLA thresholds (e.g., Time to First Response, Time to Resolution) via the LiveView dashboard.

## Phases

- [ ] **Phase 1: SLA Countdown Engine (Oban)** - Schedule and evaluate SLA timers for conversations
- [ ] **Phase 2: The Notifier Behaviour & Chimeway** - Dispatch actionable notifications to external channels
- [ ] **Phase 3: LiveView Configuration** - Provide UI for operators to define and adjust SLA thresholds

## Phase Details

### Phase 1: SLA Countdown Engine (Oban)
**Goal**: System durably schedules and evaluates SLA timers for conversations.
**Depends on**: Nothing
**Requirements**: M006-REQ-01, M006-REQ-02
**Success Criteria**:
  1. A `CheckSLA` Oban job is inserted upon conversation creation or update.
  2. The job idempotently returns NOOP if the SLA has not been breached by execution time.
**Plans**: 1

### Phase 2: The Notifier Behaviour & Chimeway
**Goal**: System dispatches actionable notifications to external channels when an SLA is breached.
**Depends on**: Phase 1
**Requirements**: M006-REQ-03, M006-REQ-04, M006-REQ-05
**Success Criteria**:
  1. `CheckSLA` job routes breach details to the `Notifier` behaviour.
  2. Host application can receive and process these notifications via a Chimeway adapter.
**Plans**: 1

### Phase 3: LiveView Configuration
**Goal**: Operators can define and adjust SLA thresholds directly in the UI.
**Depends on**: Phase 2
**Requirements**: M006-REQ-06
**Success Criteria**:
  1. Operator can set custom SLA times for different priority levels in the dashboard.
  2. New thresholds immediately apply to newly created conversations.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. SLA Countdown Engine (Oban) | 1/1 | Planned | - |
| 2. The Notifier Behaviour & Chimeway | 0/1 | Planned | - |
| 3. LiveView Configuration | 0/0 | Not started | - |
