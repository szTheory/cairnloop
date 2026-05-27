# Milestones

## vM013 Support-Triggered Outbound Lifecycle (Shipped: 2026-05-27)

**Phases completed:** 2 phases, 6 plans, 15 tasks

**Key accomplishments:**

- Cairnloop.Outbound.BulkEnvelope schema + cairnloop_outbound_bulk_envelopes migration + two narrow Cairnloop.Governance cohort-eligibility reads (list_eligible_conversation_ids_for_bulk_recovery/1, preview_bulk_recovery_cohort/1) so InboxLive (plan 03) can show a fail-closed bulk-recovery confirmation modal without ever running a direct Ecto query from the web layer (D-14).
- Cairnloop.Outbound.bulk_trigger/2 + private build_trigger_multi/2 shared helper + additive :bulk_envelope_id opt on the sealed trigger/2 + Oban unique: dedup keys on OutboundWorker, all landed without churning the Phase 22/23 sealed primitive. InboxLive (plan 03) can now call a single envelope function that enforces the D-09 cap, snapshots the rendered template body on a durable BulkEnvelope row, and fans out per-recipient deliveries under one Ecto.Multi with at-most-once Oban semantics (D-11).
- InboxLive becomes a checkbox-driven multi-select cockpit: `@selected_ids :: MapSet.t/0`, a sticky bottom bulk-action bar with the brand-primary `Send recovery follow-up to N` button, a `<.focus_wrap>` confirmation modal that snapshots the rendered template body at confirm-open time, a calm fail-closed refusal banner (icon + danger token + reason-forward copy) for oversized cohorts, and a submit handler that calls `Cairnloop.Outbound.bulk_trigger/2` and surfaces per-outcome calm flash copy without ever leaking a raw Elixir term to the operator.
- OpenInference trace lane + delivery-side bounded metrics for the outbound domain, mirroring Phase 17 verbatim — new `Cairnloop.Outbound.Telemetry.Traces` module on the disjoint `[:cairnloop, :outbound, :trace, …]` 4-segment namespace, delivery telemetry on all four arms of `OutboundWorker.perform/1`, and OI emissions wired alongside (never replacing) the sealed `:telemetry.span/3` blocks in `Outbound.trigger/2`, `bulk_trigger_submit/6`, and `bulk_trigger_refused/6` (all three refusal arms).
- Narrow `Cairnloop.Governance` audit READ facade for the Phase 25 `BulkEnvelope` substrate — two new functions (`list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`) appended after `preview_bulk_recovery_cohort/1`, both routed through `repo().all/1` / `repo().get/2` per D-14 (zero direct `Cairnloop.Repo` references), guarded by the `@bulk_envelope_hard_cap 500` `ArgumentError` rail (T-26-06 DoS mitigation), accepting an optional `:status` enum filter (`:submitted | :refused_cap_exceeded | :all`) — plus a D-05 regression block in `outbound_test.exs` that pins the EXACT auditor metadata key set on both `:outbound_trigger` and `:bulk_outbound_trigger` lanes via `Enum.sort()`-equality + negative `refute Map.has_key?` for PII-rich extras (T-26-07 mitigation).
- Pure template-patch polish pass on `InboxLive` and `ConversationLive` — closes the Phase 26 roadmap success criterion 3 ("tightens empty/error states and outbound affordance polish") by adding (a) the calm "No conversations yet." empty-state paragraph under `<h1>Inbox</h1>`, (b) the top-right × close button affordance inside the bulk-confirm dialog (aria-label="Close", 44px tap target, muted-color glyph anchored by `position: relative` on the dialog, placed as the FIRST child of the dialog so `<.focus_wrap>` lands focus there on modal-open per Pitfall 6), and (c) the calm reason-forward subhead "Delivery did not complete. Try again from the Outbound recovery card." below the failed-delivery chip on `:system_outbound` messages with `metadata["status"] == "failed"` — additive only, sealed chip + `outbound_recovery_card/1` + `outbound_status_label/1` byte-for-byte unchanged per Pitfall 7. D-10 (brand-token CSS extraction) explicitly deferred — the inline `var(--cl-<token>, <hex>)` strings are the headless-test contract.

---

## vM012 — Public Release & MCP Write Surface

**Shipped:** 2026-05-26 (archive backfilled 2026-05-27)

**Key accomplishments:**

- Packaged Cairnloop for public consumption: MIT license, `CHANGELOG.md` (Keep-a-Changelog), `mix.exs` package metadata, and ExDoc with semantic module groups — published as `cairnloop` v0.1.0 on Hex.pm via automated `.github/workflows/release.yml` (HEX_API_KEY in GitHub Secrets; any `v*` tag push publishes package + docs).
- Shipped a runnable example host: `examples/cairnloop_example` boots with `mix setup` (pgvector + host + library migrations + seed data), mounts the dashboard at `/support`, and exposes a mock customer `ChatLive` at `/chat` — with documented `cairnloop_dashboard` macro caveat workaround for 0.1.0.
- Added an Ecto-backed OAuth Bearer seam for remote MCP clients: `cairnloop_mcp_tokens` table with SHA-256 hashing, `Cairnloop.MCP` context (`issue_token` / `validate_token` / `revoke_token`), `AuthPlug` + `WellKnownPlug` (RFC 9728), and protocol version aligned to `2025-11-05`.
- Opened the first MCP write surface without compromising vM011's trust model: `tools/call` routes through `Cairnloop.Governance.propose/3` with `origin: :mcp`, `mcp_token_id`, and `tool_params`; JSON-RPC outcomes mapped to standard codes; idempotency-key reuse returns the same proposal; integration tests pass against real pgvector.

**Stats:**

- Phases: 4 (18–21)
- Plans: 7
- Timeline: 2026-05-25 → 2026-05-26 (~1.5 days)
- Git commits: 19 (`84d9a95` → `6cc87d8`)
- Known deferred items at close: 2 (broad external MCP public surface; high-risk financial/destructive mutations as first governed action — both intentionally out of scope) plus the archive-hygiene gap (this entry backfilled on 2026-05-27 during vM013 close).

---

## vM011 — AI Tool Governance & MCP Integration

**Shipped:** 2026-05-25

**Key accomplishments:**

- Established a host-owned compile-time-validated governed-tool contract (`use Cairnloop.Tool`) with durable `ToolProposal` + append-only `ToolActionEvent` records; proposals are fail-closed on unsupported tools, missing input, invalid scope, or denied policy — never execute inline.
- Built a humanized in-thread operator timeline with hybrid preview cards (snapshotted trust facts + best-effort live prose fallback); raw Elixir terms and color-alone state kept off the operator surface.
- Added a durable `ToolApproval` state machine (approve / reject / defer / expiry / resume) with one-active-lane invariant; resume re-validates via a new Oban job before execution — never inline `run/3`.
- Shipped the first narrow approved write path: `ToolExecutionWorker` (sole `run/3` caller) with three-layer at-most-once idempotency (Oban unique + terminal guard + SHA-256 per-attempt run key) and bounded telemetry.
- Added an optional OpenInference-conformant evidence lane (`Cairnloop.Governance.Telemetry.Traces`, 7 call sites across governance + workers) with payload-content exclusion and zero Scoria dependency.
- Delivered a read-only MCP seam (`Cairnloop.Web.MCP.Router` + `ToolProjector`): `tools/list` + `initialize` only, `-32601` for all write methods — core approval and execution truth unchanged.

**Stats:**

- Phases: 5 (13–17)
- Plans: 17
- Timeline: 2026-05-23 → 2026-05-25 (3 days)
- Git commits: 146
- Codebase at close: ~15,389 LOC Elixir
- Known deferred items at close: 2 (root SECURITY.md carries 5 pre-existing open threats from vM010; AR-14-02 governed-actions rail lacks pagination)

## vM010 - KB AI Maintenance

**Shipped:** 2026-05-23

**Key accomplishments:**

- Turned retrieval no-hits, weak grounding, and repeated manual handling into a ranked, inspectable
  KB gap queue.

- Shipped citation-backed draft article and revision suggestions that fail closed when evidence or
  grounding is insufficient.

- Added a durable review-task workflow with explicit approve, reject, defer, and publish
  boundaries separate from suggestion truth.

- Unified KB maintenance inside `/knowledge-base/suggestions`, including visible history and
  publish or reindex follow-through.

- Let operators launch KB maintenance directly from conversation context while preserving
  shell/manual fallback inside the shared review lane.

- Added bounded maintenance telemetry for gap creation, suggestion outcomes, review decisions,
  publish, and reindex events.

**Stats:**

- Phases: 4
- Plans: 15
- Tasks: 16
- Timeline: 2026-05-21 -> 2026-05-23
- Git range: `1c8b2ca` -> `42613c8`
- Code delta at close: 253 files changed, 37599 insertions, 316 deletions
- Known deferred items at close: 2 technical debt items (split Phase 10/12 closure artifacts
  across planning layouts; unrelated `Chimeway.Repo` boot noise during focused tests)

## vM009 - Retrieval-First Support Answers & Search Ops

**Shipped:** 2026-05-21

**Key accomplishments:**

- Built a host-owned hybrid retrieval corpus over published Knowledge Base content and resolved
  support evidence.

- Shipped a retrieval-backed `cmd+k` operator search flow with source, trust, recency, and
  citation cues.

- Grounded AI drafts in explicit retrieval evidence with visible clarification and escalation
  states.

- Added bounded retrieval telemetry and durable gap-event storage so future KB maintenance work can
  start from real miss signals.

- Closed the remaining operator-search scope blocker and backfilled milestone verification so all
  nine requirements are traced as verified.

**Stats:**

- Phases: 8
- Plans: 14
- Timeline: 2026-05-17 -> 2026-05-21
- Git range: `2adb75d` -> working tree closeout
- Code delta at close: 30 files changed, 3230 insertions, 181 deletions
- Known deferred items at close: 2 technical debt items (repo-backed realism lanes blocked in this
  workspace; duplicated search-surface guard lists)

## vM006 - Omnichannel SLA Escalation (Chimeway)

**Shipped:** 2026-05-15

**Key accomplishments:**

- Implemented SLA Countdown Engine via Oban for durably tracking conversation SLA timers.
- Defined `Cairnloop.Notifier` behaviour for omnichannel notification delivery.
- Integrated Chimeway to dispatch actionable SLA breach notifications securely and safely without hardcoding external integrations.
- Exposed configuration for host applications to route SLA breach messages to Slack, PagerDuty, or Email.

**Stats:**

- Phases: 2
- Plans: 2

## vM005 - Durable Auditing & SRE Observability

**Shipped:** 2026-05-13

**Key accomplishments:**

- Integrated `Cairnloop.Auditor` behavior for immutable audit logging of critical operator actions.
- Integrated with Parapet to surface Service Level Indicators (SLIs) via Telemetry without cardinality explosions.
- Scaffolded SLO alerts and diagnostic runbooks via Igniter for enterprise compliance.

**Stats:**

- Phases: 3
- Plans: 2

## vM004 - Customer Voice Activation

**Shipped:** 2026-05-12

**Key accomplishments:**

- Implemented core telemetry pipeline for conversation resolution (`[:cairnloop, :conversation, :resolved]`).
- Added robust host extensibility and documentation for reacting to resolution events.
- Created durable Customer Satisfaction (CSAT) data models and storage.
- Integrated frictionless CSAT rating capture into the widget channel with related telemetry emission.

**Stats:**

- Phases: 2
- Plans: 2

## vM003 - Deep Context Enrichment

**Shipped:** 2024-05-11

**Key accomplishments:**

- Implemented robust `Cairnloop.ContextProvider` behaviour for zero API sync.
- Built a dynamic evidence rail and context pane UI in `ConversationLive`.
- Created Extensibility Components & Actions (`Cairnloop.Tool`) for custom action injection.

**Stats:**

- Phases: 3
- Plans: 3
- Lines of code: 1037 insertions, 123 deletions
