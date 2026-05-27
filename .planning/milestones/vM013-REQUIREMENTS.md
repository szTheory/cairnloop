# Requirements Archive: vM013 Support-Triggered Outbound Lifecycle

**Archived:** 2026-05-27
**Status:** SHIPPED

For current requirements, see `.planning/REQUIREMENTS.md`.

---

# Cairnloop: Requirements

## Validated

- ✓ Multi-Channel Ingress Engine — vM001
- ✓ AI Triage, Drafting, & Governance — vM002
- ✓ Deep Context Enrichment — vM003
- ✓ Customer Voice Activation — vM004
- ✓ Durable Auditing & SRE Observability — vM005
- ✓ Omnichannel SLA Escalation — vM006
- ✓ Semantic Search UI Foundations — vM007
- ✓ Knowledge Base Engine — vM008
- ✓ Retrieval-First Support Answers & Search Ops — vM009
- ✓ KB AI Maintenance — vM010
- ✓ Governed tool contract with risk tiers, approval modes, idempotency, and fail-closed pipeline — vM011
- ✓ Durable in-thread operator action timeline with humanized preview cards — vM011
- ✓ Approval state machine with append-only decision history — vM011
- ✓ First narrow approved write path with three-layer idempotency — vM011
- ✓ Optional read-only MCP seam over governed-tool contract — vM011
- ✓ CI passes on main and CHANGELOG covers releases — vM012 (REL-01, REL-02)
- ✓ v0.1.0 semver tag pushed and package published to Hex.pm — vM012 (REL-03, REL-05)
- ✓ mix.exs metadata complete and ExDoc configured — vM012 (REL-04, REL-06)
- ✓ Example Phoenix app boots with `mix setup` and demonstrates core loop — vM012 (DEMO-01, DEMO-02)
- ✓ Example app documentation complete and references published hex dep — vM012 (DEMO-03, DEMO-04)
- ✓ MCP server validates OAuth Bearer tokens and serves resource-metadata — vM012 (MCP-02)
- ✓ Ecto-backed OAuth token lifecycle with SHA-256 hashing — vM012 (MCP-03)
- ✓ MCP clients invoke write-capable tools via Governance.propose/3 — vM012 (ACT-02)
- ✓ MCP write responses include proposal_id and support idempotency — vM012 (ACT-03)

## Active (vM013: Support-Triggered Outbound Lifecycle)

- [x] **OUT-01** — `Cairnloop.Outbound` facade for programmatically triggering support lifecycle events. *(Validated Phase 22: `Cairnloop.Outbound.trigger/2` shipped; sealed public contract.)*
- [x] **OUT-02** — `system_outbound` message type added to `Cairnloop.Message` schema with distinct metadata. *(Validated Phase 22: `template_id` required in metadata; default `status: "pending"`.)*
- [x] **OUT-03** — Durable scheduling of outbound messages via Oban. *(Validated Phase 23: `OutboundWorker` with `schedule_in` honored.)*
- [x] **OUT-04** — Chimeway integration for routing outbound messages to delivery channels. *(Validated Phase 23: `Cairnloop.Notifier` behaviour wired through `OutboundWorker.perform/1`; delivery failures resolve into persisted `failed` status.)*
- [x] **OUT-05** — Outbound messages are immutably linked to a parent `Conversation`. *(Validated Phase 22: messages appended to the conversation timeline.)*
- [x] **BULK-01** — Bulk selection capability in `InboxLive` for resolved or tagged conversations.
- [x] **BULK-02** — Bulk outbound trigger workflow: "Compose once, fan-out to N recipients". *(Library layer landed Phase 25 plan 02 — `Cairnloop.Outbound.bulk_trigger/2`; InboxLive operator surface landed Phase 25 plan 03.)*
- [x] **BULK-03** — Safety guards for bulk actions: max batch size limits and idempotency. *(Substrate + envelope landed Phase 25 plans 01 + 02 — `BulkEnvelope` schema with `:refused_cap_exceeded` lane, `max_batch_size = 25` env knob with hard fail-closed envelope guard, Oban `unique:` keys for at-most-once delivery.)*
- [x] **UI-01** — Distinct visual styling for `system_outbound` messages in `ConversationLive`.
- [x] **UI-02** — Outbound delivery status indicators visible in the message bubble.
- [x] **UI-03** — Bulk action toolbar in the Inbox for multi-select operations.
- [x] **OBS-01** — Telemetry events for outbound triggers and delivery (OpenInference).
- [x] **OBS-02** — Audit log entries for bulk outbound actions.

## Out of Scope

- Marketing/Newsletter drip campaigns.
- In-browser Rich Text Editor for templates.
- Broad external MCP server surface for untrusted third-party public clients.
- High-risk financial or destructive mutations as the first governed-action path.
- Autonomous customer-visible replies or side effects based only on retrieval confidence.

## Traceability

| Req ID | Phase | Status |
|--------|-------|--------|
| REL-01 | Phase 18 | Validated |
| REL-02 | Phase 18 | Validated |
| REL-03 | Phase 18 | Validated |
| REL-04 | Phase 18 | Validated |
| REL-05 | Phase 18 | Validated |
| REL-06 | Phase 18 | Validated |
| DEMO-01 | Phase 19 | Validated |
| DEMO-02 | Phase 19 | Validated |
| DEMO-03 | Phase 19 | Validated |
| DEMO-04 | Phase 19 | Validated |
| MCP-02 | Phase 20 | Validated |
| MCP-03 | Phase 20 | Validated |
| ACT-02 | Phase 21 | Validated |
| ACT-03 | Phase 21 | Validated |
| OUT-01 | Phase 22 | Complete |
| OUT-02 | Phase 22 | Complete |
| OUT-03 | Phase 23 | Complete |
| OUT-04 | Phase 23 | Complete |
| OUT-05 | Phase 22 | Complete |
| BULK-01 | Phase 25 | Complete |
| BULK-02 | Phase 25 | Complete |
| BULK-03 | Phase 25 | Complete |
| UI-01 | Phase 24 | Complete |
| UI-02 | Phase 24 | Complete |
| UI-03 | Phase 25 | Complete |
| OBS-01 | Phase 26 | Complete |
| OBS-02 | Phase 26 | Complete |

---
*Last updated: 2026-05-27 — vM013 close: all 13 v1 reqs (OUT/UI/BULK/OBS) Complete across Phases 22-26. Archived to milestones/vM013-REQUIREMENTS.md at milestone close.*
