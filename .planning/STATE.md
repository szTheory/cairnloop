---
gsd_state_version: 1.0
milestone: vM013
milestone_name: Support-Triggered Outbound Lifecycle
status: executing
stopped_at: "Phase 25 plan 02 — all 3 tasks committed; ready for Plan 25-03 (InboxLive selection + sticky bar + confirmation modal). Plan 25-01 Task 4 (mix ecto.migrate) STILL awaiting operator for full integration validation of both plans 01 + 02."
last_updated: "2026-05-27T07:07:04Z"
last_activity: 2026-05-27 -- Phase 25 plan 02 complete (Outbound.bulk_trigger/2 + Oban dedup + additive opt landed; 23/23 plan-touched tests green; trigger/2 sealed)
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 3
  completed_plans: 2
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Phase 25 — bulk-selection-fan-out

## Current Position

Phase: 25 (bulk-selection-fan-out) — EXECUTING
Plan: 2 of 3 — Plan 25-02 complete; ready for Plan 25-03 (InboxLive)
Status: Plan 25-02 fully landed. Plan 25-01 Task 4 (`mix ecto.migrate`) STILL awaiting operator for full integration validation; headless flows for both plans pass without it.
Last activity: 2026-05-27 -- Plan 25-02 Tasks 1-3 committed (372b895, 96430b5, 6a38c60)

Progress bar: `██████░░░░ 60%` (3/5 phases)

## Accumulated Context

### Decisions (carried for next milestone)

- MCP write surfaces (MCP-02, MCP-03) and remote OAuth were proven in vM012; they are available for use in outbound triggers if needed.
- `ToolExecutionWorker` is the sole `run/3` caller — any new action type should follow this pattern.
- Integration harness (`MIX_ENV=test mix test.integration`) is available for DB-backed proof lanes — prefer it for Oban worker + LiveView + repo round-trips.
- Telemetry must use enum-only labels; no actor_id/conversation_id/payload in metric event names.
- All approval-surface prose must read from snapshotted columns on `cairnloop_tool_proposals` — never call live `Preview.render` from approval or execution context.
- `Tool.run/3` must NEVER be called from MCP handlers or directly from the Outbound facade — hard architectural constraint.
- **[2026-05-26 roadmap]** Outbound messages are treated as `system_outbound` records appended to the `Conversation` timeline for context continuity.
- **[2026-05-26 roadmap]** Use Oban for scheduling delayed recovery messages (e.g., "Check back in 2 hours").
- **[2026-05-26 roadmap]** Bulk outbound actions require a confirmation preview and batch size limits to prevent resource exhaustion.
- **[2026-05-26 Phase 22]** `system_outbound` messages require `template_id` in metadata and default to `status: "pending"`.
- **[2026-05-26 Phase 23]** All outbound triggers go through `OutboundWorker` for durability and status tracking.
- **[2026-05-26 Phase 24]** The first manual operator affordance is a resolved-only fixed sidebar action that uses a configured recovery template and appends a `system_outbound` card to the thread.
- **[2026-05-27 Phase 25 D-01/D-02]** Bulk selection in `InboxLive` is restricted to resolved conversations and to currently-rendered/filtered rows only — no cross-page selection in v1.
- **[2026-05-27 Phase 25 D-03/D-04/D-05]** Selection model is explicit checkbox multi-select + sticky bulk action bar + "select all visible". State is a LiveView-local `MapSet`, cleared on filter change / navigate; no persistence across reloads.
- **[2026-05-27 Phase 25 D-06/D-07/D-08]** Bulk send reuses the configured recovery template (no free-form composition in v1). A mandatory confirmation modal must show recipient count, first-5 recipient sample, and the rendered template body before sending.
- **[2026-05-27 Phase 25 D-09/D-10/D-11]** Hard fail-closed at `max_batch_size = 25` (env-configurable). No silent chunking or partial sends. Per-recipient `OutboundWorker` jobs carry a bulk-envelope-keyed idempotency token for at-most-once delivery.
- **[2026-05-27 Phase 25 D-12/D-13]** `Cairnloop.Outbound.trigger/2` stays sealed; a new `bulk_trigger/2`-shaped envelope wraps the fan-out, snapshots template + cohort at confirmation time, and emits a single OBS-02-shaped audit row per bulk action.
- **[2026-05-27 Phase 25 D-14]** Cohort eligibility reads from the web layer go through the narrow `Cairnloop.Governance` facade — no direct `Ecto` queries from `InboxLive`.
- **[2026-05-27 Phase 25 plan 01]** `Cairnloop.Outbound.BulkEnvelope` is the durable audit row per bulk action (D-13). PK is `binary_id` (caller-supplied UUID at confirm time); `status :: :submitted | :refused_cap_exceeded`. Refused attempts persist on the same table so OBS-02 (Phase 26) reads see both lanes from one query.
- **[2026-05-27 Phase 25 plan 01]** Migration `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs` creates `cairnloop_outbound_bulk_envelopes` with `recipient_conversation_ids :: {:array, :bigint}` (no FK — array FKs are awkward; join is audit-time only, research A6) plus indexes on `:requested_at` and `:template_id`. Must be applied via `mix ecto.migrate` on the project's Postgres-available host.
- **[2026-05-27 Phase 25 plan 01]** `Cairnloop.Governance.list_eligible_conversation_ids_for_bulk_recovery/1` and `Cairnloop.Governance.preview_bulk_recovery_cohort/1` are the narrow cohort-eligibility reads (D-14). InboxLive (plan 03) MUST NOT run direct `Conversation |> where(...)` queries — the threat register T-25-04 mitigation grep will enforce this.
- **[2026-05-27 Phase 25 plan 02]** `Cairnloop.Outbound.bulk_trigger/2` is the D-13 envelope entry point. Public signature: `bulk_trigger(conversation_ids, opts)` requiring `:template_id` and `:rendered_body` (caller pre-renders — T-25-03 mitigation; the function never calls the template engine). Returns `{:ok, results}` on submit with per-recipient keys `:"message_#{cid}"` and `:"delivery_job_#{cid}"`; returns `{:error, :batch_too_large}` on cap overflow AND persists a `:refused_cap_exceeded` envelope row (research Open Question 5; mirrors `Governance.propose_blocked` so OBS-02 sees both lanes from one table). Per-recipient multi-key prefix convention: conversation_id (e.g. `:message_10`).
- **[2026-05-27 Phase 25 plan 02]** `Cairnloop.Outbound.trigger/2` public signature `def trigger(conversation_id, opts)` is SEALED (D-12) — Phase 25 added the additive optional `:bulk_envelope_id` opt (defaults to `nil`); Phase 24 callers observe identical behavior. A private `build_trigger_multi/2` helper is the shared per-recipient multi-builder reused by both `trigger/2` and `bulk_trigger/2` (research Open Question 1 — extract-and-share rather than call-trigger-twice-inside-bulk).
- **[2026-05-27 Phase 25 plan 02]** `Cairnloop.Workers.OutboundWorker` declares `unique: [period: :infinity, fields: [:worker, :args], keys: [:conversation_id, :template_id, :bulk_envelope_id]]` per D-11 — at-most-once delivery enforced at the Oban job-uniqueness layer. Phase 24 single-conversation callers pass `bulk_envelope_id: nil` and participate in the same dedup (research Open Question 2, locked decision: this IS the desired Phase 24 behavior).
- **[2026-05-27 Phase 25 plan 02]** Bulk telemetry event vocabulary (Phase 26 OBS-01 will read these): `[:cairnloop, :outbound, :bulk, :triggered, :start | :stop | :exception]` for the submitted span, and a point-in-time `[:cairnloop, :outbound, :bulk, :triggered]` for cap refusals. Labels are enum-only per D-B: `outcome :: :submitted | :refused_cap_exceeded` + `count`. `template_id`, `actor`, recipient ids, and `bulk_envelope_id` live in the durable `BulkEnvelope` row + auditor metadata, NEVER in telemetry.
- **[2026-05-27 Phase 25 plan 02]** `max_batch_size/0` reads `Application.get_env(:cairnloop, :max_batch_size, 25)` (research Open Question 3 — direct env access, no `Cairnloop.Outbound.Config` module). Defense-in-depth (research Pitfall 4): the cap is enforced at the envelope boundary regardless of caller (LiveView, MCP, console, future tools), not only in InboxLive.

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear.
- Root `SECURITY.md` carries 5 open threats (T-10-09..T-10-13) from vM010 — pre-existing debt.

### Blockers/Concerns

- **Plan 25-01 Task 4 (BLOCKING — human action):** Run `mix ecto.migrate` on the project's Postgres-available host so `cairnloop_outbound_bulk_envelopes` exists. The migration file is at `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`. Resume signal: "migrated" (or "blocked: <reason>"). Plans 02 + 03 build on this table; their headless tests pass against MockRepo but their integration assertions need the real DB.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Tech Debt | Root SECURITY.md carries 5 pre-existing open threats (T-10-09..T-10-13) from vM010 | Open | vM011 close |
| Tech Debt | AR-14-02: governed-actions rail lacks pagination (acceptable at current volume) | Open | vM011 Phase 14 |
| Scope | Marketing/Newsletter drip campaigns | Out of Scope | vM013 planning |

## Session Continuity

Last session: 2026-05-27T07:07:04Z
Stopped at: Phase 25 plan 02 — all 3 tasks committed (372b895, 96430b5, 6a38c60). `Cairnloop.Outbound.bulk_trigger/2` + Oban dedup keys + additive `:bulk_envelope_id` opt all landed; trigger/2 sealed (D-12 verified); 23/23 plan-touched headless tests green; 2 REPO-UNAVAILABLE `@tag :integration` tests authored. Plan 25-01 Task 4 (`mix ecto.migrate`) STILL awaiting operator for full integration validation of both 25-01 + 25-02 on a Postgres host.
Next step: Plan 25-03 (Wave 3) — InboxLive selection MapSet + sticky bulk-action bar + confirmation modal + refusal banner. Will consume `Cairnloop.Governance.preview_bulk_recovery_cohort/1` (plan 01) and `Cairnloop.Outbound.bulk_trigger/2` (this plan). T-25-04 mitigation grep on the LiveView (`grep -c "Conversation |> where" lib/cairnloop/web/inbox_live.ex == 0`) is now enforceable since both data needs route through facades.
Resume file: `.planning/phases/25-bulk-selection-fan-out/25-02-SUMMARY.md`
