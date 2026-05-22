# Research Summary: Cairnloop Omnichannel SLA Escalation (M006)

**Domain:** Support Ticketing SLA Management & Notification Routing
**Researched:** Current Date
**Overall confidence:** HIGH

## Executive Summary

The M006 milestone focuses on building an Omnichannel SLA Escalation system that pushes critical support events (SLA breaches, VIP tickets, long wait times) to the channels where operators actually live (Slack, PagerDuty, Discord, Email). Instead of building a complex, Turing-complete trigger engine like Zendesk, Cairnloop will lean on simple, idiomatic Elixir abstractions: Oban for durable scheduled countdowns and Chimeway for abstracting the outbound delivery mechanics.

By scheduling a `CheckSLA` Oban job at the moment a ticket is created or updated, we achieve a durable "countdown timer" that can fire notifications if the ticket remains unresolved or unresponded. When triggered, the job relies on a `Cairnloop.Notifier` behaviour, backed by Chimeway, which routes the alert based on host-defined adapters. This guarantees Cairnloop remains decoupled from the specific APIs of third-party chat tools while offering best-in-class developer ergonomics.

## Key Findings

**Stack:** Oban (for precise, distributed SLA countdowns) and Chimeway (for durable, adapter-based async notification routing).
**Architecture:** Event-driven Oban schedules. A `CheckSLA` job evaluates state upon execution and dispatches to a `Notifier` behaviour (Chimeway) if the SLA is breached.
**Critical pitfall:** Oban table bloat and queue clutter from millions of SLA countdowns. Jobs must be properly partitioned and pruning strategies must be configured.

## Implications for Roadmap

Based on research, suggested phase structure for M006:

1. **Phase 1: SLA Countdown Engine (Oban)** - Establish the `CheckSLA` worker and the insertion logic upon ticket creation/update.
   - Addresses: Scheduling, verifying, and cancelling SLA jobs when tickets are resolved early.
   - Avoids: Orphaned jobs firing alerts for already-resolved tickets.

2. **Phase 2: The Notifier Behaviour & Chimeway Integration** - Define the `Cairnloop.Notifier` behaviour and integrate Chimeway for the delivery layer.
   - Addresses: Abstracting Slack/Discord/Email delivery away from Cairnloop core.
   - Avoids: Hardcoding third-party API clients.

3. **Phase 3: LiveView Configuration & Thresholds** - Build the UI for operators to set SLA durations based on priority (e.g., VIP = 15 mins, Normal = 4 hours).
   - Addresses: Giving control back to support managers without requiring developer intervention for every threshold tweak.
   - Avoids: Building a convoluted "Zendesk Trigger" rule engine; we stick to simple, strict SLA types.

**Phase ordering rationale:**
- The engine (Oban) must exist before we can deliver the notification (Chimeway), which in turn must exist before we provide the UI to configure the thresholds.

**Research flags for phases:**
- Phase 1: Needs deeper research into Oban job cancellation (e.g., cancelling a scheduled SLA job if a user replies or resolves the ticket before the timer pops).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Oban is the industry standard in Elixir. Chimeway fits the exact architectural mandate. |
| Features | HIGH | Clear distinction between our approach and Zendesk's complex triggers. |
| Architecture | HIGH | Event-driven architecture with Oban schedules is well-documented and robust. |
| Pitfalls | MEDIUM | Oban partitioning requires some care at extreme scale, but standard pruning is usually sufficient. |

## Gaps to Address

- **Job Cancellation vs Idempotency:** Should we cancel an SLA job in Oban when a ticket is resolved, or let it run and just cleanly NOOP if the ticket state is already resolved? (Recommendation: Idempotent NOOP is usually simpler and less prone to race conditions).