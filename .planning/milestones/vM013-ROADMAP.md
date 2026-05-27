# Milestone vM013: Support-Triggered Outbound Lifecycle

**Status:** ✅ SHIPPED 2026-05-27
**Phases:** 22–26
**Total Plans:** 9 (Phases 22-24: 1 plan each, Phases 25-26: 3 plans each)

## Overview

vM013 added the support-triggered outbound lane to Cairnloop without violating the host-owned
workflow-truth posture established in vM011. Outbound intents flow through a new sealed
`Cairnloop.Outbound` facade, persist as `system_outbound` Messages appended to the
`Conversation` timeline, route through an Oban-backed `OutboundWorker` for durable delivery via
Chimeway, and surface in `ConversationLive` (individual recovery) and `InboxLive`
(multi-conversation fan-out). Bulk fan-out goes through a new `bulk_trigger/2` envelope that
records a durable `BulkEnvelope` audit row, enforces a fail-closed `max_batch_size` cap, and
fans out per-recipient deliveries with Oban `unique:` keys for at-most-once semantics. The
milestone closes with OpenInference-conformant trace telemetry, a narrow `Governance` audit
READ facade, and final operator-surface polish.

## Phases

### Phase 22: Outbound Foundation & Persistence

**Goal**: Establish the outbound contract and persistence substrate for support-triggered
follow-up.
**Depends on**: Nothing (vM013 starting phase)
**Plans**: 1 plan

Plans:

- [x] 22-01 — `Cairnloop.Outbound.trigger/2` sealed facade + `system_outbound` Message type with required `template_id` metadata + immutable `Conversation` linkage.

**Details:**

- Outbound is a host-owned facade — never a separate CRM lane.
- `system_outbound` messages appended to `Conversation` timeline for context continuity.
- Default `status: "pending"` on creation; subsequent status transitions via the delivery worker.

**Delivered:**
- Sealed public `Cairnloop.Outbound.trigger(conversation_id, opts)` contract.
- `system_outbound` message type added to `Cairnloop.Message` with `template_id` required in metadata.
- Outbound messages immutably linked to a parent `Conversation` for full context continuity.

---

### Phase 23: Delivery & Scheduling Engine

**Goal**: Route outbound intents through durable scheduling and Chimeway delivery.
**Depends on**: Phase 22
**Plans**: 1 plan

Plans:

- [x] 23-01 — Oban-backed `Cairnloop.Workers.OutboundWorker` + `Cairnloop.Notifier` behaviour wired through Chimeway + persisted status transitions (`pending` → `sent` | `failed`).

**Details:**

- All outbound triggers go through `OutboundWorker` for durability and status tracking.
- Delivery failures resolve into a persisted `failed` status with a per-message reason.
- `schedule_in` honored — supports delayed recovery messages (e.g., "Check back in 2 hours").

**Delivered:**
- `OutboundWorker.perform/1` with the disjoint terminal-arm pattern that Phase 26 OBS-01 will instrument.
- `Cairnloop.Notifier` behaviour for omnichannel delivery (Chimeway-backed in v1).
- Persisted status transitions visible in subsequent UI surfaces (Phase 24+).

---

### Phase 24: Individual Outbound UI

**Goal**: Let operators see and manually trigger outbound recovery from the conversation thread.
**Depends on**: Phase 23
**Plans**: 1 plan

Plans:

- [x] 24-01 — `ConversationLive` outbound bubble rendering + status chip (Pending / Sent / Failed) + resolved-only sidebar "Send Recovery Follow-up" action.

**Details:**

- `system_outbound` messages render with distinct visual treatment (differentiated from agent + customer messages).
- Status chip reads from persisted `metadata["status"]` — never from `:telemetry` or live config.
- Operator's first manual affordance is a resolved-only fixed sidebar action using a configured recovery template; appends a `system_outbound` card to the thread.

**Delivered:**
- Distinct outbound timeline bubble in `ConversationLive`.
- Status indicators visible per-bubble.
- Resolved-only "Send Recovery Follow-up" action in the conversation sidebar.

---

### Phase 25: Bulk Selection & Fan-out

**Goal**: Enable multi-conversation outbound recovery while keeping operator review and safety
explicit.
**Depends on**: Phase 24
**Plans**: 3 plans

Plans:

- [x] 25-01 — `Cairnloop.Outbound.BulkEnvelope` schema + `cairnloop_outbound_bulk_envelopes` migration + two narrow `Cairnloop.Governance` cohort-eligibility reads (`list_eligible_conversation_ids_for_bulk_recovery/1`, `preview_bulk_recovery_cohort/1`) so InboxLive can show a fail-closed bulk-recovery modal without ever running a direct Ecto query from the web layer (D-14).
- [x] 25-02 — `Cairnloop.Outbound.bulk_trigger/2` + private `build_trigger_multi/2` shared helper + additive `:bulk_envelope_id` opt on the sealed `trigger/2` + Oban `unique:` dedup keys on `OutboundWorker`. Submission enforces the D-09 cap, snapshots the rendered template body on a durable `BulkEnvelope` row, and fans out per-recipient deliveries under one `Ecto.Multi` with at-most-once Oban semantics (D-11). Persists a `:refused_cap_exceeded` envelope row on overflow so OBS-02 sees both lanes from one table.
- [x] 25-03 — `Cairnloop.Web.InboxLive` becomes a checkbox-driven multi-select cockpit: `@selected_ids :: MapSet.t/0`, sticky bottom bulk-action bar with the brand-primary `Send recovery follow-up to N` button, `<.focus_wrap>` confirmation modal that snapshots the rendered template body at confirm-open time, calm fail-closed refusal banner (icon + danger token + reason-forward copy) for oversized cohorts, and a submit handler that calls `bulk_trigger/2` without ever leaking a raw Elixir term to the operator.

**Details:**

- Bulk selection is restricted to resolved conversations and to currently-rendered/filtered rows only — no cross-page selection in v1.
- Selection state is LiveView-local (`MapSet`); cleared on filter change / navigate; no persistence across reloads.
- Bulk send reuses the configured recovery template (no free-form composition in v1); mandatory confirmation modal shows recipient count, first-5 recipient sample, and the rendered template body.
- Hard fail-closed at `max_batch_size = 25` (env-configurable via `Application.get_env(:cairnloop, :max_batch_size, 25)`) — no silent chunking or partial sends.
- Per-recipient `OutboundWorker` jobs carry a bulk-envelope-keyed idempotency token for at-most-once delivery.
- D-14: cohort eligibility reads from the web layer go through the narrow `Cairnloop.Governance` facade — never direct `Ecto` queries from `InboxLive`. Negative-grep gate pins this.

**Delivered:**
- `BulkEnvelope` schema with `:submitted | :refused_cap_exceeded` status — refused attempts persist on the same table.
- `Outbound.bulk_trigger/2` envelope entry point with `:template_id` + `:rendered_body` required (caller pre-renders; T-25-03 mitigation).
- Sealed `trigger/2` extended additively only with optional `:bulk_envelope_id`; Phase 24 callers observe identical behavior.
- `InboxLive` confirmation modal uses `<.focus_wrap>` for a11y; Cancel preserves selection; success resets it.
- Operator handoff: `mix ecto.migrate` + REPO-UNAVAILABLE integration tests tracked in `25-HUMAN-UAT.md` and closed via CI shift-left tests landed 2026-05-27 (commits `5bad851` → `23e700b`).

---

### Phase 26: Observability & Polish

**Goal**: Finish the outbound lane with telemetry, auditability, and final UI polish.
**Depends on**: Phase 25
**Plans**: 3 plans

Plans:

- [x] 26-01 — `Cairnloop.Outbound.Telemetry.Traces` OpenInference-conformant trace module on the disjoint `[:cairnloop, :outbound, :trace, …]` 4-segment namespace (mirrors vM011 Phase 17 Governance pattern) + delivery-side bounded-metrics + OI traces emitted on every terminal arm of `OutboundWorker.perform/1` + OI emissions wired alongside (never replacing) the sealed bounded-metrics spans in `Outbound.trigger/2` + `bulk_trigger/2`.
- [x] 26-02 — Narrow `Cairnloop.Governance` audit READ facade for the `BulkEnvelope` substrate: `list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`, routed through `repo()` indirection (D-14 clean, default limit 50, hard cap 500, optional `:status` enum filter). D-05 regression block in `outbound_test.exs` pins the EXACT auditor metadata key set on both `:outbound_trigger` and `:bulk_outbound_trigger` lanes (negative `refute Map.has_key?` for PII-rich extras; T-26-07 mitigation).
- [x] 26-03 — Pure template-patch polish on `InboxLive` + `ConversationLive`: (a) calm "No conversations yet." empty-state paragraph; (b) top-right `×` close button inside the bulk-confirm dialog (`aria-label="Close"`, 44px tap target, focus-landed-first per Pitfall 6); (c) reason-forward subhead under failed-delivery chips ("Delivery did not complete. Try again from the Outbound recovery card."). Sealed `outbound_recovery_card/1` + `outbound_status_label/1` untouched per Pitfall 7. D-10 brand-token CSS extraction explicitly deferred — inline `var(--cl-<token>, <hex>)` strings are the headless-test contract.

**Details:**

- OI trace module is additive — sealed `:telemetry.span/3` blocks unchanged.
- Telemetry labels are enum-only; `template_id`, `actor`, recipient ids, and `bulk_envelope_id` live in the durable `BulkEnvelope` row + auditor metadata, never in metric event names.
- Audit READ facade preserves D-14: zero direct `Cairnloop.Repo` references in the public function.
- WR-01/02/03 code review findings (failure-path observability gap in bulk + trigger telemetry) acknowledged at close and remediated within the milestone (commits `adb81e6`, `62e5d24`, `dca77a0`, `3778c9d`, `7d628db`, `2c1e779`, `060fa4f`).

**Delivered:**
- `Cairnloop.Outbound.Telemetry.Traces` module (12-atom event registry mirroring vM011 Phase 17 verbatim).
- Two new `Cairnloop.Governance` READ functions on the audit facade.
- Final UI polish closing the Phase 26 roadmap success criterion 3.
- `mix compile --warnings-as-errors` clean; full suite 676/677 (1 documented baseline failure — `Automation.DraftTest` M005 drift, pre-existing).

---

## Milestone Summary

**Key Decisions:**

- Outbound is treated as `system_outbound` messages appended to the conversation timeline — not a separate CRM lane. Preserves operator context continuity.
- Outbound delivery is durable workflow truth via Oban + Chimeway; LiveView reflects persisted status and never owns delivery.
- Sealed `Outbound.trigger/2` public contract — Phase 25 extends additively (`:bulk_envelope_id` opt only). Bulk fan-out goes through a new `bulk_trigger/2`, not a redefined `trigger`.
- `BulkEnvelope` is the durable audit row per bulk action — `:submitted | :refused_cap_exceeded`. Both lanes persist to the same table so OBS-02 reads see both lanes from one query.
- Hard fail-closed at `max_batch_size = 25` enforced at the envelope boundary regardless of caller (LiveView, MCP, console, future tools). Defense-in-depth.
- Oban `unique:` keys `(conversation_id, template_id, bulk_envelope_id)` for at-most-once delivery semantics — Phase 24 single-conversation callers pass `bulk_envelope_id: nil` and participate in the same dedup.
- Cohort eligibility reads from the web layer go through the narrow `Cairnloop.Governance` facade — never direct `Ecto` queries from `InboxLive` (D-14). Negative-grep gate pins this.
- Telemetry: enum-only labels; payload data lives in the durable `BulkEnvelope` row + auditor metadata, never in metric event names.
- OpenInference traces emitted alongside sealed bounded-metrics spans — never replacing them. Mirrors vM011 Phase 17 verbatim.

**Issues Addressed:**

- Closed a real product gap: support operators previously had no host-owned proactive outbound path that stayed attached to the conversation lane.
- Bulk fan-out has explicit safety rails (cap, confirmation, idempotency) — protects host resources and prevents accidental mass sends.
- Code review WR-01..WR-07 findings fully remediated within the milestone (failure-path observability honesty in bulk + trigger telemetry; D-14 grep tightening; fail-closed at boundaries).
- CI shift-left tests cover former Phase 25 human-UAT items — `mix test` + integration lanes now exercise bulk_trigger end-to-end.

**Issues Deferred:**

- Marketing/Newsletter drip campaigns — intentionally out of scope project-wide.
- In-browser rich text template editing — host should manage templates in Mailglass/Chimeway for consistency.
- SMS/WhatsApp delivery — host can add via Chimeway if needed.
- Brand-token CSS extraction (D-10) — inline `var(--cl-<token>, <hex>)` strings remain the headless-test contract for v1.

**Technical Debt Incurred:**

- Root `SECURITY.md` still carries 5 open threats (T-10-09..T-10-13) from vM010 — pre-existing, untouched.
- AR-14-02: governed-actions rail has no pagination — re-evaluate when outbound + action volume grows.
- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear.

---

_For current project status, see .planning/ROADMAP.md_
_Archived: 2026-05-27_
