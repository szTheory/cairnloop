# Cairnloop: Research Synthesis

## The Vision
Cairnloop (Cairnloop) is an embedded, Ecto-native customer support automation library for Phoenix.

## Core Value Loop
1. **Ingress**: Capture support requests (Web Widget, Email).
2. **Context Enrichment**: Natively access host data (billing, identity).
3. **AI Triage & Drafting**: Classify intent, retrieve KB context, and draft a response.
4. **Policy Gate**: Rely on `AutomationPolicy` to determine if AI can auto-reply or needs human review.
5. **Growth Activation**: Emit telemetry upon successful resolution to trigger "Customer Voice Activation" (reviews, referrals) in the host app.

## Milestone vM013 — Support-Triggered Outbound Lifecycle (In Progress)

### Phase 22: Outbound Foundation & Persistence
- Established the `Cairnloop.Outbound` facade with a `trigger/2` entrypoint.
- Updated `Cairnloop.Message` schema to support the `:system_outbound` role.
- Implemented metadata validation requiring `template_id` for outbound messages.
- Added telemetry (`[:cairnloop, :outbound, :triggered]`) and `Cairnloop.Auditor` support.
- Verified persistence and link to `Conversation` via unit tests.

### Phase 23: Delivery & Scheduling Engine
- Implemented `Cairnloop.Workers.OutboundWorker` for durable delivery via Oban.
- Updated `Cairnloop.Outbound.trigger/2` to support `:schedule_in` for delayed recovery checks.
- Created `Cairnloop.Chimeway.OutboundNotifier` and updated `Cairnloop.Notifier` behavior.
- Integrated outbound triggers into the `Chimeway` notification pipeline.
- Added status tracking (`pending` -> `sent`/`failed`) in message metadata.

### Phase 24: Individual Outbound UI
- Rendered `system_outbound` messages in `ConversationLive` with distinct timeline styling.
- Added outbound delivery chips for persisted `Pending`, `Sent`, and `Failed` states.
- Added a resolved-only sidebar action, `Send Recovery Follow-up`, for manual support recovery outreach.
- Kept the UI on the existing right rail and reused `Cairnloop.Outbound.trigger/2` rather than introducing a compose flow.
