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

- [ ] **OUT-01** — `Cairnloop.Outbound` facade for programmatically triggering support lifecycle events.
- [ ] **OUT-02** — `system_outbound` message type added to `Cairnloop.Message` schema with distinct metadata.
- [ ] **OUT-03** — Durable scheduling of outbound messages via Oban.
- [ ] **OUT-04** — Chimeway integration for routing outbound messages to delivery channels.
- [ ] **OUT-05** — Outbound messages are immutably linked to a parent `Conversation`.
- [ ] **BULK-01** — Bulk selection capability in `InboxLive` for resolved or tagged conversations.
- [ ] **BULK-02** — Bulk outbound trigger workflow: "Compose once, fan-out to N recipients".
- [ ] **BULK-03** — Safety guards for bulk actions: max batch size limits and idempotency.
- [x] **UI-01** — Distinct visual styling for `system_outbound` messages in `ConversationLive`.
- [x] **UI-02** — Outbound delivery status indicators visible in the message bubble.
- [ ] **UI-03** — Bulk action toolbar in the Inbox for multi-select operations.
- [ ] **OBS-01** — Telemetry events for outbound triggers and delivery (OpenInference).
- [ ] **OBS-02** — Audit log entries for bulk outbound actions.

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
| OUT-01 | Phase 1 | Pending |
| OUT-02 | Phase 1 | Pending |
| OUT-03 | Phase 2 | Pending |
| OUT-04 | Phase 2 | Pending |
| OUT-05 | Phase 1 | Pending |
| BULK-01 | Phase 4 | Pending |
| BULK-02 | Phase 4 | Pending |
| BULK-03 | Phase 4 | Pending |
| UI-01 | Phase 3 | Validated |
| UI-02 | Phase 3 | Validated |
| UI-03 | Phase 4 | Pending |
| OBS-01 | Phase 5 | Pending |
| OBS-02 | Phase 5 | Pending |

---
*Last updated: 2026-05-26 — vM013 Active; vM012 Validated.*
