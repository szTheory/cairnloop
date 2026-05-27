# Phase 25: Bulk Selection & Fan-out - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning
**Provenance:** Auto-ratified per CLAUDE.md shift-left posture, owner-approved 2026-05-27. The prior session crashed mid-`/gsd:discuss-phase` after presenting four discussion topics; on resume the owner approved auto-resolution of all four with the recommended defaults rather than re-running the Q&A.

<domain>
## Phase Boundary

Add a bulk outbound flow in `InboxLive` for support recovery outreach. Operators target, preview, and execute the existing per-conversation outbound lane in batch. **In scope:** multi-select on resolved conversations in the inbox, a sticky bulk action bar, a mandatory confirmation preview, fan-out over the existing `Cairnloop.Outbound.trigger/2` primitive, and a hard fail-closed batch cap. **Out of scope:** marketing/newsletter campaigns, rich template editing, free-form bulk composition, cross-page selection, tag-driven cohorts (deferrable later without reworking the selection model).

Mapped requirements: **BULK-01** (multi-select), **BULK-02** (compose-once fan-out with preview), **BULK-03** (max batch size + at-most-once / idempotency), **UI-03** (bulk action toolbar).

</domain>

<decisions>
## Implementation Decisions

### Cohort Eligibility (BULK-01)
- **D-01:** Bulk selection is restricted to **resolved** conversations only in v1. Mirrors Phase 24's resolved-only single-conversation recovery affordance. Tag-driven cohorts remain a future-phase concern and do not require reworking the selection model when added.
- **D-02:** Selection acts on **currently-rendered / filtered rows only** — no cross-page or "select across all pages" affordance in v1. Avoids the hidden-footgun where an operator selects more than they can see.

### Selection Model (BULK-01, UI-03)
- **D-03:** Explicit **checkbox multi-select** on each inbox row, plus a "select all visible" toggle in the column header. No long-press or shift-range selection in v1 (discoverability beats power-user shortcuts on a 44-line baseline inbox).
- **D-04:** Selection state lives in LiveView assigns as a `MapSet` of conversation ids. **No persistence** across reloads. **Cleared** on filter change and on navigate-away. Re-entering the inbox starts empty.
- **D-05:** A **sticky bulk action bar** appears when the selection set is non-empty, anchored to the bottom or top of the inbox panel (planner's call on placement). The bar shows selection count and a single primary action: "Send recovery follow-up to N". An explicit "Clear selection" affordance lives on the bar.

### Preview + Message Contract (BULK-02)
- **D-06:** v1 reuses the **configured recovery template** wired in Phase 24. No free-form composition. Template editing is explicitly out of scope and belongs to a separate (future) phase if ever in scope.
- **D-07:** A **mandatory confirmation modal** is the hard gate before any send. The modal must show:
  - the **recipient count** (with the cap surfaced — see D-09),
  - a **bounded sample** of the first 5 recipient labels (calm-tone "+N more" tail when count > 5),
  - the **rendered template body** as it will be sent (single render, no per-recipient personalization preview in v1).
- **D-08:** Confirmation is a **hard step** (explicit "Confirm send" button) — never a toast or auto-confirm. Cancel returns to the inbox with selection preserved so the operator can adjust.

### Batch Safety Rails (BULK-03)
- **D-09:** Hard fail-closed above a fixed cap: **`max_batch_size = 25`** in v1. No silent chunking, no partial sends. The cap is configurable via application env (so ops can tune without code) but the v1 default is 25.
- **D-10:** Oversized cohorts get a **calm, reason-forward refusal** per brand voice ("This batch exceeds the safe send limit of 25. Narrow your selection and try again."). No state-by-color-alone — the refusal carries icon + text.
- **D-11:** **At-most-once delivery / idempotency** is enforced at the per-recipient level — each fan-out send remains a separate `OutboundWorker` job keyed by `(conversation_id, template_id, bulk_envelope_id)` so accidental double-submits or job retries do not duplicate sends.

### Architecture & Re-use
- **D-12:** Each per-conversation send continues to flow through `Cairnloop.Outbound.trigger/2 → OutboundWorker`. The existing `trigger/2` stays **sealed** (Phase 23 / 24 decision carried forward — see PROJECT-LEVEL D-A below).
- **D-13:** Add a new envelope entry point, working name **`Cairnloop.Outbound.bulk_trigger/2`** (planner may rename), which:
  - validates the cohort against the cap (D-09) under a single transaction-or-fail boundary,
  - **snapshots** the template and the recipient list at confirmation time (no live re-resolution at worker enqueue or run time),
  - records a single audit envelope row (one OBS-02-shaped audit per bulk action, even though delivery is per-recipient),
  - fans out `trigger/2` calls per recipient.
- **D-14:** Cohort eligibility reads go through the narrow **`Cairnloop.Governance`** facade — the web layer must not run direct `Ecto` queries for "is this conversation resolved". If the necessary read doesn't exist on the facade yet, add it; do not bypass.

### Project-Level Decisions (carried forward — restated here for downstream agents)
- **D-A:** `system_outbound` cards remain the single timeline lane for any outbound message — bulk fan-out produces N such cards, not a new card type. (Phase 23 carry.)
- **D-B:** Telemetry stays **enum-only labels** — no `actor_id`, `conversation_id`, `payload`, or recipient identifiers in metric event names or labels. (Project-level carry.)
- **D-C:** Durable Ecto records + Oban jobs are workflow truth. `:telemetry` is observability only; never a UI/display source. (Architecture posture from CLAUDE.md.)
- **D-D:** UI follows brand book — calm fail-closed copy, no state-by-color-alone, brand tokens (`var(--cl-primary, #A94F30)`) over hardcoded hex, never raw Elixir terms / raw JSON to operators.

### Build / Test Constraints (CLAUDE.md)
- **D-15:** All new code must pass `mix compile --warnings-as-errors`. `mix test` must run before declaring work done.
- **D-16:** Per the **REPO-UNAVAILABLE** caveat: prefer headless / pure tests (presenters, total functions, `MapSet`-driven selection logic, cap-validation logic) that do not require a live `Cairnloop.Repo`. Tests that genuinely need a Postgres round-trip (e.g. idempotency keys, audit envelope insert, per-recipient `OutboundWorker` enqueue under bulk envelope) should still be written but tagged `# REPO-UNAVAILABLE` where they cannot run in this workspace.

### Claude's Discretion (planner / executor may choose)
- Exact placement of the sticky bulk bar (top vs bottom of the inbox panel).
- Exact internal name of `bulk_trigger/2` (vs `trigger_bulk/2`, `fan_out/2`, etc.).
- Whether `bulk_envelope_id` is a UUID column on a new `cairnloop_outbound_bulk_envelopes` table or an existing structure — planner decides based on what `Outbound` already has.
- Visual treatment of the "select all visible" header checkbox (tristate vs binary).
- Whether the cap (`max_batch_size`) lives in `config/runtime.exs`, a `Cairnloop.Outbound.Config` module, or the `Application` env directly — planner picks the most idiomatic location given existing patterns.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` § "Phase 25: Bulk Selection & Fan-out" — goal, deps, success criteria.
- `.planning/vM013-ROADMAP.md` — milestone-local roadmap for vM013 (Support-Triggered Outbound Lifecycle).
- `.planning/vM013-REQUIREMENTS.md` — BULK-01, BULK-02, BULK-03, UI-03 (and adjacent OBS-01 / OBS-02 for context on what Phase 26 will need from any telemetry/audit hooks added here).
- `.planning/PROJECT.md` — overall product posture and value statement.
- `.planning/REQUIREMENTS.md` — project-level requirements log.
- `.planning/STATE.md` § "Decisions" — accumulated cross-phase decisions.

### Project conventions (MANDATORY)
- `CLAUDE.md` (repo root) — decide-for-me shift-left posture, warnings-clean build, REPO-UNAVAILABLE caveat, architecture posture (Ecto truth, Governance facade, snapshot-at-decision-time, seal-completed-phases, brand-aligned copy).
- `prompts/cairnloop_brand_book.md` — brand voice, copy register, rail layout, color rules (no state-by-color-alone, calm fail-closed copy, primary token).
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned architecture posture.

### Code anchors for this phase
- `lib/cairnloop/web/inbox_live.ex` (44 lines today, `Chat.list_conversations/0`) — the surface that gains selection state, bulk bar, confirmation modal, and the bulk submit handler.
- `lib/cairnloop/outbound.ex` (65 lines today) — `trigger/2` stays sealed; add `bulk_trigger/2` (or equivalent) as the new envelope/audit entry point that fans `trigger/2`.
- `lib/cairnloop/workers/outbound_worker.ex` — per-recipient worker; idempotency key under the bulk envelope must thread through here.
- `lib/cairnloop/governance.ex` — narrow read facade; cohort eligibility lookups go through it.
- `lib/cairnloop/web/conversation_live.ex` (recovery card at lines ~825–842, handler `trigger_recovery_follow_up` at ~194–225) — reference implementation for the per-conversation recovery action whose copy / template behavior the bulk flow mirrors.

### Tests
- `test/cairnloop/outbound_test.exs` — extend with bulk envelope semantics, cap enforcement, idempotency under fan-out.
- `test/cairnloop/workers/outbound_worker_test.exs` — verify per-recipient enqueue under bulk envelope key.
- `test/cairnloop/web/inbox_live_test.exs` (likely new) — selection state, preview modal, fail-closed cap rendering.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.Outbound.trigger/2` — the per-conversation primitive; sealed. Bulk action calls it N times, not a new code path.
- `Cairnloop.Workers.OutboundWorker` — handles delivery, status, audit. Bulk envelope threads its id through `trigger/2`'s opts so per-job records can be correlated.
- `Cairnloop.Chat.list_conversations/0` — current InboxLive data source. Selection state layers on top; filters and pagination (if any) constrain the visible cohort.
- Recovery-card UI pattern from `ConversationLive` (lines ~825–842) — the resolved-only affordance, calm fail-closed copy, template-driven body. Bulk preview modal should feel of-a-piece with this card visually.

### Established Patterns
- **Sealed primitives, additive envelopes** — when a downstream concern (here: bulk) needs to layer over a completed phase's primitive, wrap it in a new envelope rather than mutate the primitive. See PROJECT-LEVEL D-A and CLAUDE.md "Seal completed phases".
- **Snapshot at decision time** — never re-resolve template body, recipient identity, or eligibility at worker enqueue / run time. Snapshot at the confirmation gate and persist on the envelope. (CLAUDE.md architecture posture.)
- **Narrow facade reads** — new reads from the web layer go through `Cairnloop.Governance`, not direct `Ecto` queries. (CLAUDE.md.)
- **Enum-only telemetry labels** — D-B above, project-wide.

### Integration Points
- InboxLive ↔ Governance: cohort eligibility read.
- InboxLive ↔ Outbound: `bulk_trigger/2` call from the confirmation modal submit handler.
- Outbound (envelope) ↔ OutboundWorker: per-recipient jobs carry the bulk envelope id for audit correlation and idempotency.
- OutboundWorker ↔ Conversation timeline: each delivery still produces a `system_outbound` card (D-A) — no new card type.

</code_context>

<specifics>
## Specific Ideas

- The owner approved auto-ratification rather than re-running the Q&A, so each decision above is the recommendation that was already surfaced (and approved) in the prior session — none are speculative.
- The cap value 25 is a concrete starting number, not a placeholder. Planner should treat it as a value to wire in, not a TBD to revisit. Tuning happens via the env knob (D-09), not via re-litigation.
- The preview modal's recipient sample size (5) is concrete. If the planner needs to change it, that's a decision worth flagging in PLAN.md rather than silently picking a different number.

</specifics>

<deferred>
## Deferred Ideas

- **Tag-driven cohorts.** Selecting all conversations tagged "needs-followup" or similar — out of scope for v1 (cohort restricted to resolved per D-01). Future phase.
- **Cross-page selection.** Selecting more than the visible filtered set — explicitly disallowed in v1 (D-02). If ever needed, requires its own UX (count confirmation, server-side cohort persistence).
- **Free-form bulk composition.** Operator-authored one-off messages sent in bulk — out of scope (D-06). Template editing is its own future phase if ever in scope.
- **Per-recipient personalization preview in the modal.** v1 shows a single rendered template body; per-recipient variable substitution preview is deferred.
- **Long-press / shift-range selection.** Power-user selection shortcuts — deferred until usage signals demand it.
- **Marketing/Newsletter drip campaigns.** Already on the project-level Out-of-Scope list (see PROJECT.md / vM013 planning); restated here so it stays out of any future Phase 25 work.

</deferred>

---

*Phase: 25-bulk-selection-fan-out*
*Context gathered: 2026-05-27*
