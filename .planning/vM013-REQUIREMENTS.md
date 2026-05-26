# Requirements — vM013 Support-Triggered Outbound Lifecycle

**Milestone:** vM013
**Status:** In Progress
**Created:** 2026-05-26

## v1 Requirements

### Core Outbound (OUT)

- **OUT-01** — `Cairnloop.Outbound` facade for programmatically triggering support lifecycle events (e.g., `trigger_recovery/2`).
- **OUT-02** — `system_outbound` message type added to `Cairnloop.Message` schema with distinct metadata (template_id, status).
- **OUT-03** — Durable scheduling of outbound messages via Oban (supporting `schedule_in` for delayed recovery checks).
- **OUT-04** — Chimeway integration for routing outbound messages to delivery channels (Email/Webhook) using host-defined templates.
- **OUT-05** — Outbound messages are immutably linked to a parent `Conversation` for context continuity.

### Bulk Affordances (BULK)

- **BULK-01** — Bulk selection capability in `InboxLive` for resolved or tagged conversations.
- **BULK-02** — Bulk outbound trigger workflow: "Compose once, fan-out to N recipients" with preview.
- **BULK-03** — Safety guards for bulk actions: max batch size limits and at-most-once delivery guarantee (idempotency).

### Operator Experience (UI)

- **UI-01** — Distinct visual styling for `system_outbound` messages in `ConversationLive` timeline (differentiating from agent and AI messages).
- **UI-02** — Outbound delivery status indicators (Pending, Sent, Failed) visible in the message bubble.
- **UI-03** — Bulk action toolbar in the Inbox for multi-select operations.

### Observability (OBS)

- **OBS-01** — Telemetry events for outbound triggers, delivery success, and failures (OpenInference compatible).
- **OBS-02** — Audit log entries for bulk outbound actions, recording the operator and the cohort of conversations affected.

## Out of Scope

| Excluded | Reason |
|---------|--------|
| Marketing/Newsletter drip campaigns | Cairnloop is a support library, not a marketing CRM. |
| In-browser Rich Text Editor for templates | Host should manage templates in Mailglass/Chimeway for consistency. |
| SMS/WhatsApp delivery | Beyond current scope; host can add via Chimeway if needed. |
| Automatic "Cold" outbound (lead gen) | Strictly support-triggered or resolution-linked only. |

## Traceability

| Req ID | Phase | Status |
|--------|-------|--------|
| OUT-01 | Phase 1 | Completed |
| OUT-02 | Phase 1 | Completed |
| OUT-03 | Phase 2 | Completed |
| OUT-04 | Phase 2 | Completed |
| OUT-05 | Phase 1 | Completed |
| BULK-01 | Phase 4 | Pending |
| BULK-02 | Phase 4 | Pending |
| BULK-03 | Phase 4 | Pending |
| UI-01 | Phase 3 | Completed |
| UI-02 | Phase 3 | Completed |
| UI-03 | Phase 4 | Pending |
| OBS-01 | Phase 5 | Pending |
| OBS-02 | Phase 5 | Pending |

---
*Created: 2026-05-26 — vM013 requirements identified based on Epic 11.*
