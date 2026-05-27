# Phase 26: Observability & Polish - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Close out the vM013 Support-Triggered Outbound Lifecycle by finishing the observability
substrate and tightening operator-visible surfaces — without changing any sealed contracts
from Phases 22–25.

**In scope (this phase delivers):**

1. **OBS-01 — Telemetry parity (triggers + delivery, OpenInference-conformant).** The
   trigger and bulk-trigger telemetry already land via `Cairnloop.Telemetry.span/3`
   (Phase 22/25 substrate). This phase closes two real gaps:
   - **Delivery-side telemetry on `Cairnloop.Workers.OutboundWorker.perform/1`** —
     currently zero events emit when a per-recipient delivery flips `metadata["status"]`
     from `"pending"` → `"sent"`/`"failed"`. Phase 26 adds enum-only bounded-metrics
     events for the delivery half of the lane.
   - **OpenInference trace lane for the outbound domain** — Phase 17 introduced
     `Cairnloop.Governance.Telemetry.Traces` on the disjoint 4-segment
     `[:cairnloop, :governance, :trace, …]` namespace (D17-01). Phase 26 mirrors that
     pattern for outbound: a new `Cairnloop.Outbound.Telemetry.Traces` module emits
     OI-conformant trace events on a parallel `[:cairnloop, :outbound, :trace, …]`
     namespace, alongside (never replacing) the bounded-metrics events.

2. **OBS-02 — Audit readability for bulk outbound actions.** The `BulkEnvelope` row +
   `auditor.audit(:bulk_outbound_trigger, …)` callback are the durable write-side audit
   substrate landed in Phase 25. This phase adds the narrow `Cairnloop.Governance`
   READ facade so hosts can consume bulk envelope history without breaching D-14
   (no direct Ecto reads from the web layer).

3. **Final UI polish on existing surfaces.** Empty/error states + outbound affordance
   polish on `InboxLive` and `ConversationLive`. No new pages, no new LiveViews. The
   roadmap success criterion is "tightens empty/error states and outbound affordance
   polish" — that's a polish pass on what already exists.

**Out of scope (explicitly):**

- New Cairnloop-owned operator UI for bulk outbound history (e.g., a
  `BulkOutboundHistoryLive` route or rail card). Host apps consume the facade and
  build their own admin surface if they want one — that's where the layering
  belongs. **Auto-decided per shift-left; flagged for cheap owner veto.**
- Per-conversation outbound trigger audit READ facade. Only `BulkEnvelope` reads
  land in this phase; single-trigger audits remain host-auditor-only (callback fires,
  no first-party reader).
- Consolidating bounded-metrics + OI traces under a single `Cairnloop.Outbound.Telemetry`
  umbrella. Mirrors the Phase 17 / Governance posture: sibling modules, not a merged
  surface.
- Extracting duplicated brand-token button-style declarations from `inbox_live.ex`
  to a CSS class — flagged as future cleanup in the InboxLive moduledoc (WR-03);
  needs a CSS-pipeline conversation first.

</domain>

<decisions>
## Implementation Decisions

### OBS-01 — Telemetry (bounded metrics)

- **D-01 — Carry-forward enum-only labels (D-B from Phase 25):** Every new telemetry
  event in this phase uses enum-only metadata: `outcome :: atom`, `count :: integer`,
  and a structured `reason :: atom` when an error needs disambiguation. NO
  `conversation_id`, `template_id`, `actor`, recipient IDs, or `bulk_envelope_id`
  in telemetry labels — those facts live in the durable `Message` row, the
  `BulkEnvelope` row, the `OutboundWorker` job args, and the host auditor metadata.
  **Why:** Protects attached Prometheus/StatsD/Datadog handlers from cardinality
  explosion + PII leakage; matches the lockstep posture Phase 25 plan 02 baked into
  `Outbound.trigger/2` + `bulk_trigger/2`. Listed in `.planning/STATE.md`
  "Accumulated Context > Decisions" as a cross-milestone carried decision.

- **D-02 — Delivery-side telemetry call sites:** `Cairnloop.Workers.OutboundWorker.perform/1`
  emits point-in-time events on every terminal arm of its `case` over the notifier
  call (current file: `lib/cairnloop/workers/outbound_worker.ex` lines 70–93):
  - `[:cairnloop, :outbound, :delivery, :sent]` with `%{count: 1}` measurements and
    `%{outcome: :sent, reason: :notifier_ok | :no_notifier_configured}` metadata.
  - `[:cairnloop, :outbound, :delivery, :failed]` with `%{count: 1}` measurements and
    `%{outcome: :failed, reason: :notifier_returned_error}` metadata.
  These are point-in-time (`:telemetry.execute/3` via `Cairnloop.Telemetry.execute/3`),
  NOT spans — `perform/1` is already a unit-of-work; the Oban job timing is observable
  through `Oban.Telemetry`. **Why:** The pending → sent/failed transition IS the
  "delivery" half of OBS-01 ("telemetry events for outbound triggers and delivery").

- **D-03 — OpenInference trace lane (mirrors Phase 17):** Introduce a new module
  `Cairnloop.Outbound.Telemetry.Traces` modeled exactly on
  `lib/cairnloop/governance/telemetry/traces.ex` (Phase 17, D17-01 / D17-02 / D17-05).
  Same architectural posture:
  - **Disjoint 4-segment namespace:** `[:cairnloop, :outbound, :trace, <event>]`,
    never overlapping with the bounded-metrics 3-segment / 4-segment
    `[:cairnloop, :outbound, …]` paths.
  - **`@events` enum guard:** `:trigger_started`, `:trigger_completed`, `:trigger_failed`,
    `:bulk_submitted`, `:bulk_refused`, `:delivery_sent`, `:delivery_failed`. Unknown
    atoms return `:ok` silently (D17-05 fail-closed).
  - **OI span-kind taxonomy:** trigger/bulk events emit `"openinference.span.kind"`
    = `"GUARDRAIL"`; delivery events emit `"TOOL"` (mirrors Phase 17 D17-03 — execution
    events are the "TOOL" span, lifecycle events are "GUARDRAIL"). Delivery IS the
    execution of an outbound, so the analogy holds.
  - **Attribution-ref-only metadata (D17-02):** `:bulk_envelope_id`, `:conversation_id`
    (numeric refs only — these are not free-text PII in the OI namespace by design;
    contrast bounded-metrics where they would explode cardinality), `:template_id`,
    `:actor_id`, `:outcome`. NO `rendered_body`, NO `content`, NO `refused_reason`
    free-text. **Trade-off vs bounded-metrics labels:** OI traces are sampled
    span-tree observability — attribution refs are the whole point and don't go to
    a metrics aggregator. Hosts that don't want OI traces simply don't attach a
    handler; events drop silently per the `:telemetry` library contract.
  - **Zero Scoria dep:** module calls `:telemetry.execute/3` directly. No imports
    from Scoria-owned namespaces.
  **Why:** REQ-OBS-01 literally names "OpenInference"; Phase 17 set the precedent
  for how Cairnloop emits OI-conformant traces; mirroring the pattern keeps the
  observability story coherent across governed actions and outbound. **Flagged for
  owner veto** — drop this module to ship only bounded-metrics if OI is unwanted.

- **D-04 — `Cairnloop.Telemetry` moduledoc gets an "Outbound Events" block:**
  Document the new bounded-metrics + OI trace event vocabulary alongside the existing
  Conversation / Feedback / Retrieval / Knowledge-Maintenance sections in
  `lib/cairnloop/telemetry.ex`. Cross-reference the new traces module.

### OBS-02 — Audit reads (narrow facade)

- **D-05 — Audit-write substrate already exists; verify it via regression test:**
  `Cairnloop.Outbound.trigger/2` (line 95) already calls
  `auditor.audit(:outbound_trigger, actor, %{conversation_id, template_id})`;
  `Cairnloop.Outbound.bulk_trigger/2` happy path (line 339) already calls
  `auditor.audit(:bulk_outbound_trigger, actor, %{bulk_envelope_id, count, template_id})`.
  The refusal path persists a `:refused_cap_exceeded` envelope row. Phase 26 adds a
  small regression test that pins the metadata shape so future refactors can't drift it.

- **D-06 — `Cairnloop.Governance` READ facade for bulk envelopes:** Append two
  narrow reads to `lib/cairnloop/governance.ex` (after `preview_bulk_recovery_cohort/1`,
  ~line 1090):
  - `list_recent_bulk_outbound_envelopes(opts \\ [])` — returns the `BulkEnvelope`
    rows ordered `requested_at desc`, bounded by `:limit` (default `50`, capped at
    `500`). Optional `:status` filter (`:submitted | :refused_cap_exceeded | :all`,
    default `:all`).
  - `get_bulk_outbound_envelope(id)` — returns `nil` on miss (no raising). Used by
    detail lookups.
  Both go through `repo().all/1` / `repo().get/2` per D-14 — never `Cairnloop.Repo`
  directly. **Why:** D-14 forbids direct `Ecto` queries from the web layer; a host
  app that wants to render bulk history (or an example-app admin panel) MUST consume
  the facade. This phase ships the facade; the consumer is host-side.

- **D-07 — No first-party operator UI for bulk history this phase:** The roadmap
  success criterion 3 is "tightens empty/error states and outbound affordance polish"
  — that's a polish pass on EXISTING surfaces (`InboxLive`, `ConversationLive`),
  not a new admin LiveView. Host apps consume the facade. **Auto-decided per
  shift-left; flagged for cheap owner veto.** Veto path: add a `BulkOutboundHistoryLive`
  to Wave 3 (1 extra plan, ~3–4 tasks).

### Polish (final UI pass on existing surfaces)

- **D-08 — `InboxLive` polish punch list** (`lib/cairnloop/web/inbox_live.ex`):
  - **Empty inbox state:** when `@conversations == []` render a single calm sentence
    ("No conversations yet.") under the `<h1>Inbox</h1>` — no bulk header, no toolbar.
    Brand tokens, no emoji, no exclamation marks.
  - **No-eligible-resolved state:** when `@conversations != []` but
    `visible_eligible_ids/1` is empty, the bulk header already correctly hides via
    `has_visible_eligible?/1` — this is a verification gate, not new work. Confirm
    with a regression test.
  - **Modal close-button affordance:** add a top-right `×` button in the confirm
    dialog (44px tap target, `aria-label="Close"`, calls `cancel_bulk_confirm`).
    Escape already works (`phx-window-keydown="cancel_bulk_confirm"`); this is a
    discoverability polish — operators expect a visible close on modal dialogs.
  - **Refusal banner copy review:** verify against `prompts/cairnloop_brand_book.md`
    §7.5 (never state-by-color-alone). Current copy is calm, reason-forward, has
    inline SVG icon + `var(--cl-danger)` accent — likely already correct; the gate
    is a copy-pass review, not new copy.

- **D-09 — `ConversationLive` polish punch list** (`lib/cairnloop/web/conversation_live.ex`):
  - **`outbound_recovery_card` (~line 825):** verify a11y hierarchy
    (`<section aria-label="Outbound recovery">` with eyebrow + body). No behavior
    change.
  - **`system_outbound` failure bubble (~line 990–1014):** ensure `:failed` state
    renders reason-forward calm copy. Current `outbound_status_label/1` returns
    `"Failed"` chip only — Phase 26 adds a calm subhead sentence when
    `metadata["status"] == "failed"` ("Delivery did not complete. Try again from the
    Outbound recovery card."). Retry path is the existing `trigger_recovery_follow_up`
    handler on `:resolved` conversations.

- **D-10 — Out-of-scope for Phase 26 polish:** Extracting the duplicated
  brand-token button-style declarations from `inbox_live.ex` to a CSS class. This
  was flagged in the InboxLive moduledoc (WR-03) as "future cleanup once the project
  has a CSS pipeline" — it changes the test contract (the headless `inbox_live_test.exs`
  asserts on inline `var(--cl-…)` strings in rendered HTML). Defer.

### Plan breakdown

- **D-11 — Three-wave plan shape (mirrors Phase 25):** Phase 26 ships as three
  sequential waves so the substrate stabilizes before consumers consume it:
  - **Wave 1 — OBS-01 substrate:** `OutboundWorker` delivery telemetry (D-02) +
    `Cairnloop.Outbound.Telemetry.Traces` module (D-03) + OI trace emissions wired
    into `Outbound.trigger/2` and `Outbound.bulk_trigger/2` alongside existing
    bounded-metrics spans + `Cairnloop.Telemetry` moduledoc update (D-04).
  - **Wave 2 — OBS-02 audit READ facade:** Append
    `list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1` to
    `Cairnloop.Governance` (D-06). Regression test pins the auditor metadata
    contract from D-05.
  - **Wave 3 — Final UI polish:** `InboxLive` empty states + modal close-button
    (D-08) + `ConversationLive` failed-bubble subhead (D-09). Independent waves
    in principle, but ordered last so polish lands on a stable substrate.

### Testing posture

- **D-12 — Build/test gates carry forward:** `mix compile --warnings-as-errors`
  must be clean; `mix test` must pass. Telemetry tests use `:telemetry_test`'s
  built-in `:telemetry_test.attach_event_handlers/2` for `assert_receive` on emit.
  Envelope facade tests that need a real `Cairnloop.Repo` round-trip carry the
  `# REPO-UNAVAILABLE` marker per CLAUDE.md (Postgres is not available in this
  workspace). Headless tests cover everything testable without a live DB; the
  REPO-UNAVAILABLE assertions are captured for the operator to run on a Postgres
  host (mirrors the Phase 25 BLOCKING handoff pattern).

### Claude's Discretion

- **OI trace event atom granularity** (within D-03): the `@events` enum currently
  lists 7 atoms — researcher/planner may add or remove ONE atom if a finer/coarser
  split emerges during planning (e.g., separate `:delivery_attempted` from
  `:delivery_sent`/`:delivery_failed`). Outcome must remain enum-only per D-01.
- **Inbox empty-state copy** (within D-08): exact wording is at planner's discretion
  provided it's calm, reason-forward, brand-aligned, and uses no emoji / no
  exclamation marks.
- **Test naming + file layout for the new traces module**: planner picks naming
  consistent with `test/cairnloop/governance/telemetry_test.exs` (suggested:
  `test/cairnloop/outbound/telemetry/traces_test.exs`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level (always)

- `CLAUDE.md` — shift-left decision policy ("decide for me, don't ask"); build/test
  conventions (`mix compile --warnings-as-errors` + `mix test`; REPO-UNAVAILABLE
  caveat); architecture posture (`Cairnloop.Governance` narrow facade; snapshot
  trust facts at decision time; seal completed phases; calm operator copy; brand
  tokens over hardcoded hex).
- `prompts/cairnloop_brand_book.md` §7.5 — never state-by-color-alone; brand
  token vocabulary; calm operator copy register.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned
  architecture posture.

### Planning surface

- `.planning/PROJECT.md` — vision and core value.
- `.planning/REQUIREMENTS.md` — OBS-01 + OBS-02 wording.
- `.planning/ROADMAP.md` §"Phase 26: Observability & Polish" — Goal + Success
  Criteria + Requirements + UI hint.
- `.planning/STATE.md` "Accumulated Context > Decisions" — D-B telemetry enum-only
  labels (carried), BulkEnvelope per-action audit row, all Phase 25 D-01..D-14
  carried decisions, plus the Phase 25 BLOCKING checkpoints that may still be open
  when this phase begins (`mix ecto.migrate` + in-browser verify on a Postgres host).

### Phase 25 outputs (immediate predecessor)

- `.planning/phases/25-bulk-selection-fan-out/25-CONTEXT.md` — bulk fan-out decisions.
- `.planning/phases/25-bulk-selection-fan-out/25-02-SUMMARY.md` — final lock-in of
  the bulk telemetry vocabulary that Phase 26 extends.
- `.planning/phases/25-bulk-selection-fan-out/25-03-SUMMARY.md` — InboxLive polish
  baseline + WR-06 snapshot-eligible-ids decision (Phase 26 polish builds on top).

### OpenInference / telemetry patterns to mirror

- `lib/cairnloop/governance/telemetry/traces.ex` — **THE** pattern. Phase 26's new
  `Cairnloop.Outbound.Telemetry.Traces` mirrors this file's `@events` guard +
  4-segment namespace + OI span-kind metadata + guard-clause no-op posture
  exactly. Read end-to-end before designing the outbound traces module.
- `lib/cairnloop/telemetry.ex` — bounded-metrics module; moduledoc gets a new
  "Outbound Events" block (D-04).
- `lib/cairnloop/outbound.ex` lines 91 + 254 + 325 — existing trigger/bulk
  bounded-metrics span / execute call sites; Phase 26 adds parallel OI trace
  emissions alongside (does NOT replace).

### OBS-01 delivery-side gap

- `lib/cairnloop/workers/outbound_worker.ex` lines 70–93 — `perform/1` case arms
  where delivery telemetry must land. Currently emits zero events on the
  pending → sent/failed transition.

### Audit substrate (OBS-02)

- `lib/cairnloop/auditor.ex` — `Cairnloop.Auditor.audit/4` callback contract
  (host implements; library no-ops by default).
- `lib/cairnloop/outbound/bulk_envelope.ex` — durable audit row schema; columns
  `:effective_cap`, `:requested_by`, `:requested_at`, `:status`, `:refused_reason`
  are what facade reads expose to hosts.
- `lib/cairnloop/outbound.ex` lines 95–98 + 339–343 — existing auditor.audit
  call sites for `:outbound_trigger` and `:bulk_outbound_trigger`. D-05 regression
  test pins these.

### Governance facade pattern

- `lib/cairnloop/governance.ex` lines 1021–1090 —
  `list_eligible_conversation_ids_for_bulk_recovery/1` +
  `preview_bulk_recovery_cohort/1`. Two reads added by Phase 25 plan 01; Phase 26's
  envelope reads follow the same call shape (`repo().all/1`, query-builder, return
  shape documented in `@doc`).

### UI polish targets

- `lib/cairnloop/web/inbox_live.ex` lines 80–292 — mount, render, event handlers.
  Empty states (D-08) land in `render/1`; modal close button lands in the dialog
  fragment (~line 187).
- `lib/cairnloop/web/conversation_live.ex` lines 825–845 — `outbound_recovery_card/1`
  (D-09 a11y verification target).
- `lib/cairnloop/web/conversation_live.ex` lines 990–1014 — `outbound_status_label/1`
  + `outbound_status_class/1` (D-09 failed-bubble subhead target).

### Tests to extend or pin

- `test/cairnloop/outbound_test.exs` — existing single-trigger + bulk-trigger
  coverage; Phase 26 adds telemetry-attach tests + auditor-metadata-shape
  regression tests.
- `test/cairnloop/workers/outbound_worker_test.exs` — existing perform/1 coverage
  (`# REPO-UNAVAILABLE` for the integration arm); Phase 26 adds delivery-side
  telemetry-attach tests.
- `test/cairnloop/governance_test.exs` + `test/cairnloop/governance/preview_test.exs`
  — pattern reference for Phase 26's new envelope facade tests.
- `test/cairnloop/governance/telemetry_test.exs` — pattern reference for testing
  the new `Cairnloop.Outbound.Telemetry.Traces` emit/guard-clause behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Cairnloop.Governance.Telemetry.Traces.emit/2`** (`lib/cairnloop/governance/telemetry/traces.ex`
  lines 85–94) — copy this module's shape almost verbatim for
  `Cairnloop.Outbound.Telemetry.Traces`: `@events` whitelist guard, 4-segment
  namespace, `build_metadata/2` returning the OI span-kind string key
  (`"openinference.span.kind"`), guard-clause no-op for unknown atoms.
- **`Cairnloop.Telemetry.span/3` + `.execute/3`** — already wraps every existing
  bounded-metrics emission. New delivery events use `.execute/3` (point-in-time);
  trace lane uses `:telemetry.execute/3` directly (mirroring Phase 17 — bypasses the
  centralizer because the namespace is disjoint by design).
- **`Cairnloop.Auditor` behaviour** — already invoked from both `trigger/2` and
  `bulk_trigger/2`. No new wiring; D-05 just pins the metadata shape via test.
- **`Cairnloop.Outbound.BulkEnvelope`** — schema already has every column the
  facade needs to expose: `:effective_cap`, `:requested_by`, `:requested_at`,
  `:status`, `:refused_reason`, `:rendered_body`, `:recipient_conversation_ids`,
  `:count`, `:template_id`. Facade reads consume the schema struct directly.
- **`outbound_module/0`** + **`governance_module/0`** indirection pattern
  (`lib/cairnloop/web/conversation_live.ex` lines 1739–1745 + same in
  `inbox_live.ex` lines 57–63) — used in LiveViews for test substitution; any new
  LiveView consumer in Phase 26 polish work follows the same pattern (no new LiveView
  is planned, but if D-07 is vetoed, this is how the new view substitutes).

### Established Patterns

- **Enum-only telemetry labels** (D-B / WR-04 from Phase 25; restated as D-01):
  cardinality + PII safety. New delivery events MUST follow.
- **Snapshot trust facts at decision time** (CLAUDE.md): `BulkEnvelope.rendered_body`,
  `:effective_cap`, `:requested_at` — never re-derive at read time. Facade reads
  return the row as-snapshotted.
- **Narrow Governance facade** (D-14 from Phase 25): web layer MUST NOT run direct
  `Ecto` queries. The new envelope reads MUST live in `Cairnloop.Governance`. Test
  hosts inject via `:cairnloop, :governance_module` env knob.
- **Disjoint OI namespace** (D17-01 from Phase 17): bounded-metrics events and
  OI trace events NEVER share an event path. Outbound mirrors:
  `[:cairnloop, :outbound, …]` (metrics) is disjoint from
  `[:cairnloop, :outbound, :trace, …]` (OI).
- **Fail-closed on unknown trace events** (D17-05 from Phase 17): `emit/2` for an
  atom outside `@events` returns `:ok` silently. Caller is never penalised.
- **Calm operator copy + brand tokens** (CLAUDE.md / brand book §7.5): no emoji,
  no exclamation marks, never state-by-color-alone, `var(--cl-<token>, <hex>)`
  fallback pattern in inline styles so headless tests can assert on the brand
  vocabulary in rendered HTML.

### Integration Points

- **`Cairnloop.Workers.OutboundWorker.perform/1`** (`lib/cairnloop/workers/outbound_worker.ex`)
  — emit `:cairnloop, :outbound, :delivery, :sent | :failed` inside the existing
  `case` arms; also call `Cairnloop.Outbound.Telemetry.Traces.emit(:delivery_sent | :delivery_failed, %{…})`
  alongside.
- **`Cairnloop.Outbound.trigger/2`** + **`bulk_trigger/2`** — ADD parallel OI trace
  emissions inside the existing telemetry spans (or immediately before/after the
  `:telemetry.span` block — research/planning will pick the exact placement that
  keeps the existing `Cairnloop.Telemetry.span` semantics intact). Do NOT replace
  the bounded-metrics spans.
- **`Cairnloop.Governance`** (`lib/cairnloop/governance.ex` ~line 1090) — append
  the two new envelope reads after `preview_bulk_recovery_cohort/1` so the
  cohort-eligibility + audit-history reads cluster together as the
  "outbound-domain facade" in one part of the file.
- **`Cairnloop.Telemetry`** (`lib/cairnloop/telemetry.ex` lines 1–46) — append
  an "Outbound Events" block under the existing event-vocabulary sections.

</code_context>

<specifics>
## Specific Ideas

- **OpenInference span-kind taxonomy** (Phase 17 mirror):
  trigger/bulk lifecycle events → `"GUARDRAIL"`. Delivery events
  (`:delivery_sent` / `:delivery_failed`) → `"TOOL"`. Rationale: in Phase 17,
  execution events (the actual write to the system) are TOOL spans; lifecycle
  events (proposed, blocked, approved, etc.) are GUARDRAIL. Delivery is the
  outbound-side analog of execution.
- **Modal close-button placement** (D-08): top-right `×` inside the dialog
  `<div class="bulk-confirm-dialog">`, `aria-label="Close"`, 44px minimum tap
  target, calm color (not red — use `var(--cl-text-muted)` or similar), calls
  `cancel_bulk_confirm`. Escape already works; this is the visible affordance.
- **Inbox empty-state copy** (D-08): "No conversations yet." — short,
  reason-forward, brand-aligned. Renders under `<h1>Inbox</h1>` in a calm
  `<p style="color: var(--cl-text-muted, …); font-size: 14px; margin-top: 12px;">`.
- **Failed `system_outbound` subhead** (D-09): "Delivery did not complete. Try
  again from the Outbound recovery card." — calm, reason-forward, no shouting,
  points to the existing retry affordance.
- **Audit-read default limit** (D-06): `50`. Hard cap `500` (rejects with
  `ArgumentError` if a caller asks for more — defense-in-depth against unbounded
  reads).

</specifics>

<deferred>
## Deferred Ideas

- **Operator-visible `BulkOutboundHistoryLive`** — first-party Cairnloop LiveView
  for bulk outbound history. Auto-decided OUT for this phase (D-07). Veto path:
  add to Wave 3 as an extra plan. Belongs in a future "Outbound admin / observability"
  phase, or in the host example app (Phase 19).
- **Per-conversation outbound trigger audit READ facade** — only `BulkEnvelope`
  reads land in Phase 26. Single-trigger audits remain host-auditor-only. Future
  phase if hosts ask for it.
- **Consolidated `Cairnloop.Outbound.Telemetry` umbrella module** — mirroring
  Phase 17 / Governance, bounded-metrics and OI traces stay as sibling modules in
  different parents. No merger this phase.
- **Extracting duplicated brand-token button styles from `inbox_live.ex` into a
  CSS class** — flagged in the InboxLive moduledoc (WR-03) as future cleanup;
  needs a CSS-pipeline conversation first.
- **Centralising duplicated fail-closed search guards** (pending todo from
  STATE.md) — not outbound-domain; defer to a retrieval-adjacent phase.
- **Root `SECURITY.md` open threats T-10-09..T-10-13** (vM010 carry) — not
  outbound-domain; pre-existing debt; out of scope.
- **`Oban.Telemetry` integration** — `Oban` already emits its own telemetry for
  job timing. Phase 26 does not duplicate Oban's events; OBS-01's delivery
  telemetry is the Cairnloop-domain semantics on top (`:sent` / `:failed`
  outcome, not raw job timing).

</deferred>

---

*Phase: 26-observability-polish*
*Context gathered: 2026-05-27*
