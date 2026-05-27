# Roadmap: Cairnloop

## Milestones

- ✅ **vM009 Retrieval-First Support Answers & Search Ops** — Phases 1–8 (shipped 2026-05-21)
- ✅ **vM010 KB AI Maintenance** — Phases 9–12 (shipped 2026-05-23)
- ✅ **vM011 AI Tool Governance & MCP Integration** — Phases 13–17 (shipped 2026-05-25)
- ✅ **vM012 Public Release & MCP Write Surface** — Phases 18–21 (shipped 2026-05-26)
- 🚧 **vM013 Support-Triggered Outbound Lifecycle** — Phases 22–26 (in progress)

## Phases

### vM013 Support-Triggered Outbound Lifecycle (Phases 22–26)

- [x] **Phase 22: Outbound Foundation & Persistence** — `Cairnloop.Outbound`, `system_outbound`, immutable conversation linkage
- [x] **Phase 23: Delivery & Scheduling Engine** — Oban-backed `OutboundWorker` plus Chimeway routing and persisted status transitions
- [x] **Phase 24: Individual Outbound UI** — `ConversationLive` timeline rendering for outbound messages and resolved-only manual recovery trigger
- [ ] **Phase 25: Bulk Selection & Fan-out** — multi-select inbox outbound with preview and safety rails
- [ ] **Phase 26: Observability & Polish** — telemetry, audit logging, and final operator-surface polish

Archive: `.planning/vM013-ROADMAP.md`

<details>
<summary>✅ vM012 Public Release & MCP Write Surface (Phases 18–21) — SHIPPED 2026-05-26</summary>

- [x] Phase 18: Release Gate & Hex.pm Publish
- [x] Phase 19: Example Phoenix App
- [x] Phase 20: MCP OAuth Seam
- [x] Phase 21: MCP Write Tools

</details>

<details>
<summary>✅ vM011 AI Tool Governance & MCP Integration (Phases 13–17) — SHIPPED 2026-05-25</summary>

- [x] Phase 13: Governed Tool Contract & Proposal Records (3/3 plans) — completed 2026-05-24
- [x] Phase 14: Operator Timeline & Preview Surface (4/4 plans) — completed 2026-05-24
- [x] Phase 15: Approval State Machine & Oban Resume (5/5 plans) — completed 2026-05-25
- [x] Phase 16: First Approved Write Path & Telemetry (3/3 plans) — completed 2026-05-25
- [x] Phase 17: Optional Evidence Lane & Read-Only MCP Seam (2/2 plans) — completed 2026-05-25

Archive: `.planning/milestones/vM011-ROADMAP.md`

</details>

<details>
<summary>✅ vM010 KB AI Maintenance (Phases 9–12) — SHIPPED 2026-05-23</summary>

- [x] Phase 9: Gap Candidate Discovery (3/3 plans) — completed 2026-05-22
- [x] Phase 10: Citation-Backed Draft Suggestions (4/4 plans) — completed 2026-05-22
- [x] Phase 11: Review-Gated KB Updates (4/4 plans) — completed 2026-05-23
- [x] Phase 12: In-Thread Quick Fix & Ops Closure (4/4 plans) — completed 2026-05-23

Archive: `.planning/milestones/vM010-ROADMAP.md`

</details>

<details>
<summary>✅ vM009 Retrieval-First Support Answers & Search Ops (Phases 1–8) — SHIPPED 2026-05-21</summary>

Archive: `.planning/milestones/vM009-ROADMAP.md`

</details>

## Phase Details

### Phase 22: Outbound Foundation & Persistence

**Goal**: Establish the outbound contract and persistence substrate for support-triggered follow-up.
**Depends on**: Nothing
**Requirements**: OUT-01, OUT-02, OUT-05
**Success Criteria** (what must be TRUE):

  1. `Cairnloop.Outbound.trigger/2` can initiate an outbound intent for an existing conversation
  2. `system_outbound` messages persist with required `template_id`
  3. Outbound messages are linked to the parent `Conversation`

**Plans**: completed

---

### Phase 23: Delivery & Scheduling Engine

**Goal**: Route outbound intents through durable scheduling and Chimeway delivery.
**Depends on**: Phase 22
**Requirements**: OUT-03, OUT-04
**Success Criteria** (what must be TRUE):

  1. `schedule_in` creates a pending Oban job
  2. `OutboundWorker` hands delivery to the notifier path
  3. Delivery failures resolve into persisted `failed` status

**Plans**: completed

---

### Phase 24: Individual Outbound UI

**Goal**: Let operators see and manually trigger outbound recovery from the conversation thread.
**Depends on**: Phase 23
**Requirements**: UI-01, UI-02
**Success Criteria** (what must be TRUE):

  1. `system_outbound` messages appear in `ConversationLive` with distinct visual treatment
  2. The outbound bubble renders `Pending`, `Sent`, or `Failed` chips from persisted metadata
  3. A resolved-only "Send Recovery Follow-up" action exists in the conversation sidebar

**Plans**: completed
**UI hint**: yes

---

### Phase 25: Bulk Selection & Fan-out

**Goal**: Enable multi-conversation outbound recovery while keeping operator review and safety explicit.
**Depends on**: Phase 24
**Requirements**: BULK-01, BULK-02, BULK-03, UI-03
**Success Criteria** (what must be TRUE):

  1. Operators can multi-select conversations in `InboxLive`
  2. A bulk outbound action exposes cohort preview before execution
  3. Large batches are bounded to protect host resources

**Plans**: 3 plans
Plans:
**Wave 1**

- [ ] 25-01-PLAN.md — BulkEnvelope schema + migration + Governance cohort reads (BULK-01, BULK-03 substrate)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 25-02-PLAN.md — Outbound.bulk_trigger/2 + sealed-primitive additive opt + Oban uniqueness (BULK-02, BULK-03)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 25-03-PLAN.md — InboxLive selection, sticky bar, confirmation modal, refusal banner (BULK-01, BULK-02, BULK-03, UI-03)

**UI hint**: yes

---

### Phase 26: Observability & Polish

**Goal**: Finish the outbound lane with telemetry, auditability, and final UI polish.
**Depends on**: Phase 25
**Requirements**: OBS-01, OBS-02
**Success Criteria** (what must be TRUE):

  1. Telemetry emits for outbound attempt, success, and failure
  2. Bulk outbound actions write audit records with actor and cohort size
  3. Final UI pass tightens empty/error states and outbound affordance polish

**Plans**: pending
**UI hint**: yes

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 22. Outbound Foundation & Persistence | vM013 | 1/1 | Complete | 2026-05-26 |
| 23. Delivery & Scheduling Engine | vM013 | 1/1 | Complete | 2026-05-26 |
| 24. Individual Outbound UI | vM013 | 1/1 | Complete | 2026-05-26 |
| 25. Bulk Selection & Fan-out | vM013 | 0/3 | Planned | - |
| 26. Observability & Polish | vM013 | 0/1 | Not started | - |
| 13. Governed Tool Contract & Proposal Records | vM011 | 3/3 | Complete | 2026-05-24 |
| 14. Operator Timeline & Preview Surface | vM011 | 4/4 | Complete | 2026-05-24 |
| 15. Approval State Machine & Oban Resume | vM011 | 5/5 | Complete | 2026-05-25 |
| 16. First Approved Write Path & Telemetry | vM011 | 3/3 | Complete | 2026-05-25 |
| 17. Optional Evidence Lane & Read-Only MCP Seam | vM011 | 2/2 | Complete | 2026-05-25 |

---

_For current project status, see `.planning/STATE.md`_
_vM011 archived: 2026-05-25_
