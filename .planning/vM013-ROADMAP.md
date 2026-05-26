# Roadmap — vM013 Support-Triggered Outbound Lifecycle

**Milestone**: vM013
**Goal**: Enable proactive, support-related outbound actions (like incident recovery or bug-fix notifications) that are linked to support conversations.

## Phases

- [x] **Phase 22: Outbound Foundation & Persistence** - Establish the core Outbound facade and schema updates.
- [x] **Phase 23: Delivery & Scheduling Engine** - Implement Oban-backed scheduling and Chimeway routing.
- [x] **Phase 24: Individual Outbound UI** - Visualize outbound messages in the conversation timeline and enable manual triggers.
- [ ] **Phase 25: Bulk Selection & Fan-out** - Add inbox bulk actions for fanning out resolution/recovery messages.
- [ ] **Phase 26: Observability & Polish** - Add telemetry, audit logging, and final status indicators.

## Phase Details

### Phase 22: Outbound Foundation & Persistence
**Goal**: Establish the contract and database substrate for outbound support messages.
**Depends on**: Nothing
**Requirements**: OUT-01, OUT-02, OUT-05
**Success Criteria** (what must be TRUE):
  1. `Cairnloop.Outbound.trigger/2` can be called from the console to initiate an outbound intent.
  2. A new `system_outbound` message type is persisted in the database and linked to an existing conversation.
  3. The `Cairnloop.Message` schema enforces a `template_id` requirement for outbound types.
**Plans**: TBD

### Phase 23: Delivery & Scheduling Engine
**Goal**: Wire outbound intents to real-world delivery through Oban and Chimeway.
**Depends on**: Phase 22
**Requirements**: OUT-03, OUT-04
**Success Criteria** (what must be TRUE):
  1. Calling `trigger/2` with a `schedule_in` option creates a pending Oban job.
  2. The `OutboundWorker` successfully hands off the message to the `Chimeway.Notifier` for delivery.
  3. Delivery failures are automatically retried by Oban and then marked as `failed` in the message metadata.
**Plans**: TBD

### Phase 24: Individual Outbound UI
**Goal**: Let operators see and manually trigger outbound recovery from the conversation thread.
**Depends on**: Phase 23
**Requirements**: UI-01, UI-02
**Success Criteria** (what must be TRUE):
  1. `system_outbound` messages appear in `ConversationLive` with a distinct visual style (different from agent/customer).
  2. The message bubble displays a status chip (Sent, Pending, Failed).
  3. A manual "Send Recovery Follow-up" button exists in the conversation sidebar for resolved tickets.
**Plans**: TBD
**UI hint**: yes

### Phase 25: Bulk Selection & Fan-out
**Goal**: Empower operators to handle mass incident recovery or bug-fix notifications.
**Depends on**: Phase 24
**Requirements**: BULK-01, BULK-02, BULK-03, UI-03
**Success Criteria** (what must be TRUE):
  1. Operator can multi-select conversations in `InboxLive`.
  2. A "Bulk Outbound" toolbar appears upon selection, offering a "Fan-out Recovery" action.
  3. Fan-out displays a confirmation preview (e.g., "Send to 15 recipients") before executing.
  4. Large batches (e.g., >100) are blocked or chunked to prevent host-app resource exhaustion.
**Plans**: TBD
**UI hint**: yes

### Phase 26: Observability & Polish
**Goal**: Ensure production readiness through audit trails and telemetry.
**Depends on**: Phase 25
**Requirements**: OBS-01, OBS-02
**Success Criteria** (what must be TRUE):
  1. `:telemetry` events are emitted for every outbound attempt, completion, and failure.
  2. An audit log entry is created for every bulk action, identifying the actor and the number of conversations impacted.
  3. Final UI pass: smooth animations for bulk selection and improved error state empty-states.
**Plans**: TBD
**UI hint**: yes

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 22. Outbound Foundation & Persistence | 1/1 | Completed | 2026-05-26 |
| 23. Delivery & Scheduling Engine | 1/1 | Completed | 2026-05-26 |
| 24. Individual Outbound UI | 1/1 | Completed | 2026-05-26 |
| 25. Bulk Selection & Fan-out | 0/1 | Not started | - |
| 26. Observability & Polish | 0/1 | Not started | - |

---
*Created: 2026-05-26 — vM013 roadmap structured for Support-Triggered Outbound Lifecycle.*
