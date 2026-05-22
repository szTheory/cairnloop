# Phase 2: The Notifier Behaviour & Chimeway

**Goal**: System dispatches actionable notifications to external channels when an SLA is breached.

## Requirements
- **M006-REQ-03**: System defines a `Cairnloop.Notifier` behaviour for omnichannel delivery.
- **M006-REQ-04**: System integrates `Chimeway` to deliver notifications when an SLA is breached.
- **M006-REQ-05**: Host application can configure Chimeway adapters to route messages to Slack, Discord, or Email.

## Success Criteria
1. `CheckSLA` job routes breach details to the `Notifier` behaviour.
2. Host application can receive and process these notifications via a Chimeway adapter.
