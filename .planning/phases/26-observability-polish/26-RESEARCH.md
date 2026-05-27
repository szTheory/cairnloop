# Phase 26: Observability & Polish - Research

**Researched:** 2026-05-27
**Domain:** Elixir / Phoenix LiveView / `:telemetry` observability + audit-read facade + LiveView polish
**Confidence:** HIGH (every claim is grounded in the live codebase; the canonical Phase 17 OI pattern is in-tree as `lib/cairnloop/governance/telemetry/traces.ex` and verified end-to-end)

## Summary

Phase 26 is a small, well-scoped closeout phase on a substrate that is fully built. Everything
the planner needs already exists in the repo: the Phase 17 `Cairnloop.Governance.Telemetry.Traces`
module is the verbatim template for the new `Cairnloop.Outbound.Telemetry.Traces`; the
`Cairnloop.Outbound.bulk_trigger/2` + `BulkEnvelope` substrate is sealed and durable; the
governance facade pattern (`repo().all/1`, `repo().get/2`) is established by
`list_eligible_conversation_ids_for_bulk_recovery/1` at `governance.ex:1021`; the
`OutboundWorker.perform/1` case arms (`outbound_worker.ex:70-93`) are exactly the four delivery
outcomes that need point-in-time telemetry. The LiveView polish targets are concrete inline-style
patches against `inbox_live.ex` and `conversation_live.ex` with the brand-token vocabulary
already locked.

**Primary recommendation:** Three-wave plan exactly as D-11 prescribes. Wave 1 ships the new
`Cairnloop.Outbound.Telemetry.Traces` module + `OutboundWorker` delivery telemetry +
`Outbound.trigger/2` / `bulk_trigger/2` parallel OI emissions + `Cairnloop.Telemetry` moduledoc
block. Wave 2 appends `list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`
to `Cairnloop.Governance` plus a regression test that pins the auditor metadata shape. Wave 3
patches the LiveView polish items in `inbox_live.ex` (empty state + modal close `×`) and
`conversation_live.ex` (failed-bubble subhead). All Phase 26 tests are headless-pure (no Repo);
existing test patterns in `test/cairnloop/governance/telemetry/traces_test.exs` are copy-modify.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**OBS-01 — Telemetry (bounded metrics):**
- **D-01** — Carry-forward enum-only labels (D-B from Phase 25): every new telemetry event uses enum-only metadata: `outcome :: atom`, `count :: integer`, optional structured `reason :: atom`. NO `conversation_id`, `template_id`, `actor`, recipient IDs, or `bulk_envelope_id` in telemetry labels.
- **D-02** — Delivery-side telemetry call sites: `Cairnloop.Workers.OutboundWorker.perform/1` emits point-in-time events on every terminal arm of the `case` over the notifier call (current file `lib/cairnloop/workers/outbound_worker.ex` lines 70–93):
  - `[:cairnloop, :outbound, :delivery, :sent]` with `%{count: 1}` measurements and `%{outcome: :sent, reason: :notifier_ok | :no_notifier_configured}` metadata.
  - `[:cairnloop, :outbound, :delivery, :failed]` with `%{count: 1}` measurements and `%{outcome: :failed, reason: :notifier_returned_error}` metadata.
  These are point-in-time (`:telemetry.execute/3` via `Cairnloop.Telemetry.execute/3`), NOT spans — `perform/1` is already a unit-of-work; Oban already emits its own job timing.
- **D-03** — OpenInference trace lane (mirrors Phase 17): introduce a new module `Cairnloop.Outbound.Telemetry.Traces` modeled exactly on `lib/cairnloop/governance/telemetry/traces.ex`. Disjoint 4-segment namespace `[:cairnloop, :outbound, :trace, <event>]`. `@events` enum guard: `:trigger_started`, `:trigger_completed`, `:trigger_failed`, `:bulk_submitted`, `:bulk_refused`, `:delivery_sent`, `:delivery_failed`. Unknown atoms return `:ok` silently. OI span-kind taxonomy: trigger/bulk events → `"GUARDRAIL"`; delivery events → `"TOOL"`. Attribution-ref-only metadata: `:bulk_envelope_id`, `:conversation_id`, `:template_id`, `:actor_id`, `:outcome`. NO `rendered_body`, NO `content`, NO `refused_reason` free-text. Zero Scoria dep; calls `:telemetry.execute/3` directly. **Flagged for owner veto** — drop this module to ship only bounded-metrics if OI is unwanted.
- **D-04** — `Cairnloop.Telemetry` moduledoc gets an "Outbound Events" block.

**OBS-02 — Audit reads (narrow facade):**
- **D-05** — Audit-write substrate already exists (`Outbound.trigger/2` line 95 + `bulk_trigger/2` line 339); add a regression test to pin the metadata shape.
- **D-06** — `Cairnloop.Governance` READ facade for bulk envelopes, appended after `preview_bulk_recovery_cohort/1` (~line 1090):
  - `list_recent_bulk_outbound_envelopes(opts \\ [])` — returns `BulkEnvelope` rows ordered `requested_at desc`, bounded by `:limit` (default `50`, hard cap `500` — `ArgumentError` if exceeded). Optional `:status` filter (`:submitted | :refused_cap_exceeded | :all`, default `:all`).
  - `get_bulk_outbound_envelope(id)` — returns `nil` on miss (no raising).
  Both through `repo().all/1` / `repo().get/2` per D-14.
- **D-07** — No first-party operator UI for bulk history this phase. **Auto-decided per shift-left; flagged for cheap owner veto.**

**Polish (final UI pass on existing surfaces):**
- **D-08** — `InboxLive` polish punch list (`lib/cairnloop/web/inbox_live.ex`):
  - Empty inbox state: when `@conversations == []` render a single calm sentence ("No conversations yet.") under `<h1>Inbox</h1>` — no bulk header, no toolbar. Brand tokens, no emoji, no exclamation marks.
  - No-eligible-resolved state: bulk header already correctly hides via `has_visible_eligible?/1` — verification gate, not new work.
  - Modal close-button affordance: top-right `×` button in the confirm dialog (44px tap target, `aria-label="Close"`, calls `cancel_bulk_confirm`). Escape already works.
  - Refusal banner copy review against brand book §7.5 (verification gate).
- **D-09** — `ConversationLive` polish punch list (`lib/cairnloop/web/conversation_live.ex`):
  - `outbound_recovery_card` (~line 825): verify a11y hierarchy (no behavior change).
  - `system_outbound` `:failed` state: add a calm subhead sentence below the existing "Failed" chip when `metadata["status"] == "failed"` ("Delivery did not complete. Try again from the Outbound recovery card.").
- **D-10** — Out of scope: extracting brand-token button styles to a CSS class.

**Plan breakdown:**
- **D-11** — Three sequential waves: Wave 1 = OBS-01 substrate; Wave 2 = OBS-02 audit READ facade; Wave 3 = final UI polish.

**Testing posture:**
- **D-12** — Build/test gates carry forward. `mix compile --warnings-as-errors` clean; `mix test` passes. Telemetry tests use `:telemetry.attach/4` for `assert_receive` on emit. Envelope facade tests that need a real Repo round-trip carry the `# REPO-UNAVAILABLE` marker.

### Claude's Discretion

- **OI trace event atom granularity** (within D-03): the `@events` enum currently lists 7 atoms — researcher/planner may add or remove ONE atom if a finer/coarser split emerges during planning (e.g., separate `:delivery_attempted` from `:delivery_sent`/`:delivery_failed`). Outcome must remain enum-only per D-01.
- **Inbox empty-state copy** (within D-08): exact wording at planner's discretion provided it's calm, reason-forward, brand-aligned, and uses no emoji / no exclamation marks.
- **Test naming + file layout for the new traces module**: planner picks naming consistent with `test/cairnloop/governance/telemetry_test.exs` (suggested: `test/cairnloop/outbound/telemetry/traces_test.exs`).

### Deferred Ideas (OUT OF SCOPE)

- Operator-visible `BulkOutboundHistoryLive` first-party LiveView.
- Per-conversation outbound trigger audit READ facade.
- Consolidated `Cairnloop.Outbound.Telemetry` umbrella module.
- Extracting duplicated brand-token button styles from `inbox_live.ex` into a CSS class.
- Centralising duplicated fail-closed search guards.
- Root `SECURITY.md` open threats T-10-09..T-10-13.
- `Oban.Telemetry` integration (Oban already emits its own; Phase 26 layers Cairnloop-domain semantics on top, doesn't duplicate).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (verbatim from `.planning/REQUIREMENTS.md:43-44`) | Research Support |
|----|---|---|
| **OBS-01** | Telemetry events for outbound triggers and delivery (OpenInference). | (a) Delivery-side bounded-metrics events land in `OutboundWorker.perform/1` arms (Wave 1) — see *Common Pitfalls — Pitfall 1*. (b) OI trace lane lands as new `Cairnloop.Outbound.Telemetry.Traces` modeled verbatim on `lib/cairnloop/governance/telemetry/traces.ex` (Wave 1). (c) `Cairnloop.Telemetry` moduledoc documents both vocabularies (Wave 1). Trigger-side bounded-metrics events already shipped in Phases 22/25 — see *Standard Stack — Pre-existing telemetry inventory*. |
| **OBS-02** | Audit log entries for bulk outbound actions. | (a) Audit-WRITE substrate already shipped: `BulkEnvelope` row is inserted on every `bulk_trigger/2` call (submit + refusal lanes), and `auditor.audit(:bulk_outbound_trigger, …)` fires on the submit lane (verified in code at `outbound.ex:339-343`). (b) Phase 26 adds the READ facade — `Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1` (Wave 2) — per D-14 narrow-facade posture. (c) Regression test pins the auditor metadata contract (Wave 2). |

This section is REQUIRED. The planner uses it to map requirement IDs to specific deliverables.
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| OpenInference trace event emission (outbound lane) | Domain library — `Cairnloop.Outbound.Telemetry.Traces` | — | New sibling module under `Cairnloop.Outbound.Telemetry.*` namespace; emits via `:telemetry.execute/3` directly (mirrors Phase 17). Zero web/UI involvement. |
| Bounded-metrics delivery telemetry | Worker — `Cairnloop.Workers.OutboundWorker.perform/1` | Domain library — `Cairnloop.Telemetry.execute/3` (centralizer) | Delivery outcome is determined inside the worker's `case` over the notifier return; emission belongs at that exact decision point. |
| Bounded-metrics trigger telemetry (already shipped) | Domain library — `Cairnloop.Outbound.trigger/2` + `bulk_trigger/2` | — | Existing `Cairnloop.Telemetry.span/3` blocks at `outbound.ex:91` (`trigger/2`), `:325` (`bulk_trigger_submit`), and `:254` (`bulk_trigger_refused`). Phase 26 does not touch these — only adds OI trace emissions alongside. |
| Audit READ facade (`list_recent_bulk_outbound_envelopes/1`, `get_bulk_outbound_envelope/1`) | Domain library — `Cairnloop.Governance` | Schema — `Cairnloop.Outbound.BulkEnvelope` | Reads go through `repo().all/1` / `repo().get/2`; web layer is forbidden from direct `Ecto` queries per D-14. The facade module is the API boundary; hosts (or example app) consume it. |
| Audit WRITE substrate (already shipped) | Domain library — `Cairnloop.Outbound.bulk_trigger/2` | Host — `Cairnloop.Auditor` callback | The library inserts the `BulkEnvelope` row durably AND calls the host's `auditor.audit/4` callback. Both lanes exist; Phase 26 only pins their contract via regression test. |
| Inbox empty-state + modal close-button polish | Web layer — `Cairnloop.Web.InboxLive.render/1` | — | Pure template change. No new state, no new event handlers (Escape via `cancel_bulk_confirm` already wired; modal close button reuses the same handler). |
| Failed-bubble subhead polish | Web layer — `Cairnloop.Web.ConversationLive` timeline template (~line 770) | — | Pure template change inside the existing `outbound_status_label`/`outbound_status_class` rendering branch. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| `:telemetry` | ~> 1.0 (already in deps) | Event emission + handler attachment | Erlang/Elixir's stdlib observability primitive. Existing tests use `:telemetry.attach/4` (verified in `traces_test.exs:26-33`). NO `:telemetry_test` library is currently in the deps — CONTEXT.md D-12's mention of `:telemetry_test.attach_event_handlers/2` is not what the existing tests use; **decide and proceed: use plain `:telemetry.attach/4`** to match the in-repo pattern. |
| `Cairnloop.Telemetry` (centralizer) | in-tree at `lib/cairnloop/telemetry.ex` | Wraps `:telemetry.span/3` + `.execute/3` with `:cairnloop` prefix | Established pattern. Delivery events use `Cairnloop.Telemetry.execute/3`; OI trace events bypass the centralizer and call `:telemetry.execute/3` directly (matches Phase 17 / `Cairnloop.Governance.Telemetry.Traces`). |
| `ExUnit` | stdlib | Test framework, `assert_receive`, `refute_receive` | Project standard. Headless tests (`use ExUnit.Case, async: false` per the traces_test pattern — `async: false` because `:telemetry.attach` is process-global). |
| `Ecto.Query` | already imported in `governance.ex` (line 60) | `where/3` + `order_by/3` + `limit/2` query builders | Facade reads use the same Query DSL as Phase 25 cohort reads (`governance.ex:1021-1027`). |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| `Phoenix.LiveViewTest` | already in deps | `render_html/1`, `render_component/2` for the polish-pass assertions | Used in `test/cairnloop/web/inbox_live_test.exs:1-30`. Wave 3 polish tests follow the same `render_html(assigns)` pattern. |
| `Logger` | stdlib | Structured diagnostic logs (already used in `outbound.ex:264`) | Not new; not needed for Phase 26 substrate beyond existing usage. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Direct `:telemetry.execute/3` from `Outbound.Telemetry.Traces` | `Cairnloop.Telemetry.execute/3` centralizer | **Decision: use direct `:telemetry.execute/3` for the trace lane** (matches Phase 17 `governance/telemetry/traces.ex:86`). The centralizer is for the bounded-metrics namespace; the OI trace lane is intentionally disjoint per D-03, and routing through the centralizer would couple the two lanes by namespace prefix. |
| Spans for delivery telemetry | Point-in-time `execute/3` | **Decision: point-in-time** (D-02). `perform/1` is already a unit-of-work, Oban emits job timing via `Oban.Telemetry`, and a span would force restructuring the `case` block. |
| Querying via `Cairnloop.Repo.all/1` directly from a future host-side reader | Going through `Cairnloop.Governance` facade | **Decision: facade** (D-14, D-06). Hosts that want to read bulk history MUST consume the facade — that's the architectural contract. |

**Installation:** No new dependencies. All required libraries are already in `mix.exs` from prior phases.

**Version verification:** Not applicable — no new packages introduced.

## Package Legitimacy Audit

Not applicable — Phase 26 introduces zero new packages, registry installs, or external dependencies. All work uses libraries already present in the project's `mix.exs` from prior phases (`:telemetry`, `:ecto`, `:phoenix_live_view`, `:oban`, etc.). Slopcheck gate not required.

## Architecture Patterns

### System Architecture Diagram

```
Operator action (LiveView, MCP, console, etc.)
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  Cairnloop.Outbound.trigger/2  or  .bulk_trigger/2          │
│  (sealed public API — Phase 22/24/25)                       │
│                                                             │
│  ┌────────────────────────────┐                             │
│  │ Cairnloop.Telemetry.span   │ ── bounded-metrics          │
│  │   [:outbound, :triggered]  │    (already shipped         │
│  │   metadata: enum-only      │     Phase 22/25, sealed)    │
│  └────────────────────────────┘                             │
│                                                             │
│  ┌────────────────────────────┐ NEW — Wave 1                │
│  │ Outbound.Telemetry.Traces  │ ── OI trace (GUARDRAIL)     │
│  │   .emit(:trigger_started)  │    fire-and-forget,         │
│  │   .emit(:trigger_completed)│    AFTER bounded-metrics    │
│  └────────────────────────────┘                             │
│                                                             │
│  ┌────────────────────────────┐                             │
│  │ auditor.audit/4 (host cb)  │ ── audit-write              │
│  └────────────────────────────┘    (already shipped)        │
│                                                             │
│  Insert BulkEnvelope row (durable; both submit + refused)   │
│  Enqueue per-recipient OutboundWorker jobs                  │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  Cairnloop.Workers.OutboundWorker.perform/1                 │
│  (lines 70-93: case over notifier return)                   │
│                                                             │
│  case Application.get_env(:cairnloop, :notifier) do         │
│    notifier when is_atom and not nil ->                     │
│      case notifier.on_outbound_triggered(...) do            │
│        :ok           ─┐                                     │
│        {:ok, _}      ─┴── update status "sent"  ──┐         │
│        error         ──── update status "failed" ─┤         │
│      end                                          │         │
│    _ ───────────────────── update status "sent" ──┤         │
│  end                                              │         │
│                                                   ▼         │
│  NEW — Wave 1: emit at EACH arm                             │
│    [:cairnloop, :outbound, :delivery, :sent]    (3 arms)    │
│      reason: :notifier_ok                                   │
│      reason: :no_notifier_configured                        │
│    [:cairnloop, :outbound, :delivery, :failed]  (1 arm)     │
│      reason: :notifier_returned_error                       │
│                                                             │
│  PLUS:                                                      │
│    Outbound.Telemetry.Traces.emit(:delivery_sent, …)  TOOL  │
│    Outbound.Telemetry.Traces.emit(:delivery_failed, …) TOOL │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Audit READ lane — NEW Wave 2                               │
│                                                             │
│  Host app / future admin LiveView                           │
│        │                                                    │
│        ▼                                                    │
│  Cairnloop.Governance.list_recent_bulk_outbound_envelopes   │
│  Cairnloop.Governance.get_bulk_outbound_envelope            │
│        │ uses repo().all/1, repo().get/2                    │
│        ▼                                                    │
│  cairnloop_outbound_bulk_envelopes table                    │
│  (rows already inserted by bulk_trigger/2 submit + refused) │
└─────────────────────────────────────────────────────────────┘

UI Polish — Wave 3 — pure template patches, no new flow.
```

### Recommended Project Structure

```
lib/cairnloop/
├── outbound.ex                          # EXISTING — bounded-metrics already shipped
├── outbound/
│   ├── bulk_envelope.ex                 # EXISTING — schema already shipped
│   └── telemetry/                       # NEW directory
│       └── traces.ex                    # NEW — Cairnloop.Outbound.Telemetry.Traces
├── workers/
│   └── outbound_worker.ex               # EXISTING — Wave 1 patches lines 70-93
├── governance.ex                        # EXISTING — Wave 2 appends to ~line 1090
├── telemetry.ex                         # EXISTING — Wave 1 appends "Outbound Events" block to @moduledoc
└── web/
    ├── inbox_live.ex                    # EXISTING — Wave 3 patches render/1
    └── conversation_live.ex             # EXISTING — Wave 3 patches the failed-bubble template (~line 770)

test/cairnloop/
├── outbound/
│   └── telemetry/
│       └── traces_test.exs              # NEW — headless, mirrors test/cairnloop/governance/telemetry/traces_test.exs
├── outbound_test.exs                    # EXISTING — Wave 1 adds OI trace assertions + Wave 2 adds auditor-shape regression
├── workers/
│   └── outbound_worker_test.exs         # EXISTING — Wave 1 adds delivery telemetry assertions to MockNotifier arms
├── governance_test.exs                  # EXISTING — Wave 2 adds envelope facade tests
└── web/
    ├── inbox_live_test.exs              # EXISTING — Wave 3 adds empty-state + close-button assertions
    └── conversation_live_test.exs       # EXISTING — Wave 3 adds failed-bubble subhead assertion
```

### Pattern 1: New OI Traces Module (Wave 1, D-03)

**What:** Mirror `lib/cairnloop/governance/telemetry/traces.ex` verbatim, swapping `:governance` for `:outbound` in the namespace and adjusting the `@events` enum + span-kind mapping.

**When to use:** This is THE pattern for OBS-01's OI trace lane. Phase 17 set the precedent; Phase 26 follows it exactly.

**Example (skeleton — adapt from `governance/telemetry/traces.ex:54-128`):**

```elixir
# lib/cairnloop/outbound/telemetry/traces.ex
defmodule Cairnloop.Outbound.Telemetry.Traces do
  @moduledoc """
  Optional OpenInference-conformant trace event module for the Cairnloop outbound lane (Phase 26, D-03).

  Mirrors `Cairnloop.Governance.Telemetry.Traces` (Phase 17, D17-01 / D17-03).

  ## Namespace separation (D-03)

  4-segment trace path:  `[:cairnloop, :outbound, :trace, <event_atom>]`
  Disjoint from bounded-metrics 3-/4-segment paths under `[:cairnloop, :outbound, ...]`
  (e.g. `[:cairnloop, :outbound, :triggered, :start | :stop]`,
  `[:cairnloop, :outbound, :bulk, :triggered, :start | :stop]`,
  `[:cairnloop, :outbound, :delivery, :sent | :failed]`).

  ## OI span kinds (D-03)

    Lifecycle events (trigger_*, bulk_*): "GUARDRAIL"
    Execution events (delivery_*):         "TOOL"

  ## Payload exclusion (D-03 / mirrors D17-02)

  Metadata carries only attribution refs (ids, atom enums). No rendered_body,
  no content, no refused_reason free-text.

  ## Fail-closed (D-03 / mirrors D17-05)

  Unknown event atoms return :ok silently.
  """

  @events [
    :trigger_started,
    :trigger_completed,
    :trigger_failed,
    :bulk_submitted,
    :bulk_refused,
    :delivery_sent,
    :delivery_failed
  ]

  @span_kind_tool "TOOL"
  @span_kind_guardrail "GUARDRAIL"

  def emit(event, attrs) when event in @events do
    :telemetry.execute(
      [:cairnloop, :outbound, :trace, event],
      %{count: 1},
      build_metadata(event, attrs)
    )
  end

  def emit(_event, _attrs), do: :ok

  defp build_metadata(event, attrs) do
    %{
      "openinference.span.kind" => span_kind_for(event),
      bulk_envelope_id: attrs[:bulk_envelope_id],
      conversation_id: attrs[:conversation_id],
      template_id: attrs[:template_id],
      actor_id: attrs[:actor_id],
      outcome: attrs[:outcome]
    }
  end

  defp span_kind_for(event)
       when event in [:delivery_sent, :delivery_failed],
       do: @span_kind_tool

  defp span_kind_for(_event), do: @span_kind_guardrail
end
```

**Source:** Phase 17 / `lib/cairnloop/governance/telemetry/traces.ex` (in-tree, verified)

### Pattern 2: Trace emission alongside (never replacing) bounded-metrics (Wave 1)

**What:** After the existing `Cairnloop.Telemetry.span/3` block returns, call `Cairnloop.Outbound.Telemetry.Traces.emit/2` fire-and-forget. Wrap inside the span only if the trace truly needs to be inside the timed window — for OBS-01 it does not; emit AFTER the span.

**When to use:** Inside `Outbound.trigger/2` and `Outbound.bulk_trigger/2` (both `submit` and `refused` paths). The Phase 17 precedent (`governance.ex:386-392` / `governance.ex:946-952`) places `Traces.emit/2` AFTER the bounded-metrics `Telemetry.emit/3` call, with the comment `"OI trace event — additive, fire-and-forget, after bounded-metrics (Phase 17)"`.

**Example (from `governance.ex:380-392`):**

```elixir
Telemetry.emit(:proposal_created, %{count: 1}, %{
  outcome: :proposed,
  risk_tier: validated.risk_tier,
  approval_mode: validated.approval_mode
})

# OI trace event — additive, fire-and-forget, after bounded-metrics (Phase 17)
Traces.emit(:proposal_created, %{
  tool_proposal_id: proposal.id,
  actor_id: actor_id,
  decided_by: nil,
  attempt: nil
})
```

**Phase 26 adaptation for `Outbound.trigger/2`:** the existing structure is a `:telemetry.span/3` that returns `{result, telemetry_meta}` (see `outbound.ex:91-103`). Emit `Traces.emit(:trigger_started, %{conversation_id: …, template_id: …, actor_id: actor, outcome: :triggered})` BEFORE the span; emit `Traces.emit(:trigger_completed, …)` or `:trigger_failed` AFTER the span, branching on the multi result. This keeps the sealed bounded-metrics span untouched while adding the OI lane around it.

**Phase 26 adaptation for `bulk_trigger_submit/6` (`outbound.ex:325-348`):** emit `Traces.emit(:bulk_submitted, …)` after the `repo().transaction(multi)` call inside the span's `fn` body. The bounded-metrics span sees the multi result; the OI emit sees the same.

**Phase 26 adaptation for `bulk_trigger_refused/6` (`outbound.ex:220-292`):** emit `Traces.emit(:bulk_refused, …)` after each terminal arm of the `case repo().insert(…)` block, just before the existing `Cairnloop.Telemetry.execute/3` call (so insertion-failed lanes still get a refusal trace).

**Phase 26 adaptation for `OutboundWorker.perform/1` (`outbound_worker.ex:75-92`):** at each arm where `update_message_status/2` is called, follow it with both (a) `Cairnloop.Telemetry.execute/3` for the bounded-metrics event AND (b) `Cairnloop.Outbound.Telemetry.Traces.emit/2` for the OI event. The two are emitted side-by-side because they target disjoint namespaces.

### Pattern 3: Governance facade read (Wave 2, D-06)

**What:** Append two narrow read functions after `preview_bulk_recovery_cohort/1` (~line 1090). Use `repo().all/1` and `repo().get/2`. Mirror the comment style and `@doc` shape of `list_eligible_conversation_ids_for_bulk_recovery/1` (`governance.ex:1021-1027`).

**Example:**

```elixir
# Append to lib/cairnloop/governance.ex after preview_bulk_recovery_cohort/1.
# alias Cairnloop.Outbound.BulkEnvelope  (add to the alias block at the top)

@bulk_envelope_default_limit 50
@bulk_envelope_hard_cap 500

@doc """
Returns recent `Cairnloop.Outbound.BulkEnvelope` rows ordered `requested_at desc`.

## Options

  * `:limit` (default `#{50}`, hard cap `#{500}`) — max rows returned. Raises
    `ArgumentError` if the caller asks for more than the cap (defense-in-depth
    against unbounded reads — Phase 26 D-06 / "Specific Ideas").
  * `:status` (default `:all`) — `:submitted` | `:refused_cap_exceeded` | `:all`.
    `:all` returns rows of both lanes.

Reads through the narrow facade per D-14: web layer / host admin surfaces MUST
go through this function, never `Cairnloop.Repo.all/1` directly. Goes through
`repo().all/1`.

## Phase 26 OBS-02 read facade (D-06)

This is the consumer-side read for the durable `BulkEnvelope` substrate landed
in Phase 25 plan 01. Submit + refused rows are stored on the same table so a
single call sees both lanes.
"""
def list_recent_bulk_outbound_envelopes(opts \\ []) do
  limit = Keyword.get(opts, :limit, @bulk_envelope_default_limit)
  status = Keyword.get(opts, :status, :all)

  if limit > @bulk_envelope_hard_cap do
    raise ArgumentError,
          "limit #{limit} exceeds bulk envelope hard cap #{@bulk_envelope_hard_cap}"
  end

  BulkEnvelope
  |> filter_envelope_status(status)
  |> order_by([e], desc: e.requested_at)
  |> limit(^limit)
  |> repo().all()
end

defp filter_envelope_status(query, :all), do: query

defp filter_envelope_status(query, status)
     when status in [:submitted, :refused_cap_exceeded] do
  where(query, [e], e.status == ^status)
end

@doc """
Returns a single `Cairnloop.Outbound.BulkEnvelope` by id, or `nil` if not found.

Returns `nil` on miss (does NOT raise) per D-06 — callers branch on the result.
"""
def get_bulk_outbound_envelope(id) do
  repo().get(BulkEnvelope, id)
end
```

**Note:** add `alias Cairnloop.Outbound.BulkEnvelope` to the alias block at `governance.ex:62-69` (currently only Phase 25 added `alias Cairnloop.Conversation`; the Phase 26 facade brings the outbound schema into scope similarly).

### Anti-Patterns to Avoid

- **Calling the OI trace lane from inside the `:telemetry.span/3` block on the same namespace.** `:telemetry.span/3` already emits 3 events (`:start`, `:stop`, `:exception`) on its `event ++ [...]` path; emitting a 4-segment `[:cairnloop, :outbound, :trace, …]` from inside the `fn` body of `Telemetry.span/3` is fine (the paths are disjoint), but it is conceptually clearer and matches Phase 17 to emit AFTER the span.
- **Routing the OI trace lane through `Cairnloop.Telemetry.execute/3`** — that would prefix `:cairnloop` again (the centralizer at `telemetry.ex:58-60` does `[:cairnloop | event_suffix]`), but more importantly the centralizer is the bounded-metrics surface; the OI lane is intentionally disjoint per D-03. Call `:telemetry.execute/3` directly (matches `governance/telemetry/traces.ex:86`).
- **Embedding `conversation_id`, `template_id`, `bulk_envelope_id`, `actor_id`, `rendered_body`, or `refused_reason` in the bounded-metrics metadata.** That violates D-01 / D-B. Those facts belong in the OI trace metadata (which is sampled span-tree observability) and in the durable rows + auditor metadata (which is the truth source).
- **Running `Cairnloop.Repo.all/1` from `InboxLive` or a future operator surface to read envelopes.** D-14 forbids it; the threat register T-25-04 grep enforces it on InboxLive specifically. Always go through `Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1`.
- **Adding new state-by-color signaling** in the polish wave. Brand book §7.5: every state must have a non-color signal (icon, text, label). The existing refusal banner already passes (inline SVG + danger token); the new failed-bubble subhead adds reason-forward text alongside the existing `"Failed"` chip + `.status-failed` class — both signals are present.
- **Using `inspect/1` on Elixir terms in operator-visible copy.** T-25-06 mitigation. Reason-forward text only.
- **Re-rendering the template at audit-read time.** The `BulkEnvelope.rendered_body` column is the snapshot; facade reads return the row as-is (CLAUDE.md "snapshot trust facts at decision time").

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| OI trace event vocabulary + namespace isolation | A bespoke macro to "register" trace events on a parent module | Verbatim copy-modify of `lib/cairnloop/governance/telemetry/traces.ex` | Phase 17 already solved this. Mirroring the file keeps both surfaces structurally identical and lets the same test patterns work for both. A macro abstraction across only 2 callers (Governance + Outbound) is premature. |
| Telemetry handler attachment in tests | A custom GenServer to buffer events | `:telemetry.attach/4` with `send(self(), …)` + `assert_receive` | The in-repo pattern (`governance/telemetry/traces_test.exs:23-37` + `governance/telemetry_test.exs:23-38`) is exactly this; it's the idiomatic `:telemetry` test pattern and needs no extra deps. |
| BulkEnvelope query builder helpers | Anything more than `where/order_by/limit` composition | `Ecto.Query` DSL (already imported at `governance.ex:60`) | One function = one query. Don't extract micro-helpers; the function is read-once at the call site. |
| Modal close-button icon | Custom SVG or an icon library | Inline plain-text `×` (U+00D7 MULTIPLICATION SIGN) inside a `<button>` | Matches the calm-no-decoration brand register. Tap target sized via inline `min-width: 44px; min-height: 44px;` per existing button pattern. No new asset, no new dependency. |
| Inbox empty-state icon / illustration | Custom illustration or emoji | Plain text paragraph under the existing `<h1>Inbox</h1>` | Brand book: calm operator copy, no emoji, no exclamation marks. The empty-state is "No conversations yet." in a muted-text paragraph — full stop. |
| Repo configuration for headless tests | A new mock repo helper module | Existing `MockRepo` patterns (e.g., `test/cairnloop/workers/outbound_worker_test.exs:7-27`) | Each test file defines its own `MockRepo` with exactly the methods it needs. Phase 26 follows. |
| Auditor metadata shape regression | Property-based testing or schema validators | A plain `defmodule TestAuditor do … end` that calls `send(self(), {:audited, …})`, then `assert_receive` | Mirrors how `MockNotifier` is built at `outbound_worker_test.exs:29-39`. Three lines per arm. |

**Key insight:** Phase 26 is a closeout phase on a substrate that's 95% built. The single biggest risk is hand-rolling abstractions over patterns that already exist in the codebase. Copy-modify the canonical Phase 17 files; add narrow read functions to the existing facade; touch the LiveView render trees minimally. Nothing in this phase justifies a new helper module beyond the one new `Cairnloop.Outbound.Telemetry.Traces` file.

## Common Pitfalls

### Pitfall 1: `OutboundWorker.perform/1` has FOUR delivery arms, not two

**What goes wrong:** Reading CONTEXT.md D-02 quickly and only emitting on the `:ok`/`{:ok, _}`/`error` lanes inside the `case notifier.on_outbound_triggered(…)` block, while missing the outer `_ ->` arm where the notifier is missing entirely.

**Why it happens:** The `case` is nested two levels:

```elixir
# outbound_worker.ex:75-92
case Application.get_env(:cairnloop, :notifier) do
  notifier when is_atom(notifier) and not is_nil(notifier) ->
    case notifier.on_outbound_triggered(message, conversation) do
      :ok          -> update_message_status(message, "sent")  # arm A
      {:ok, _}     -> update_message_status(message, "sent")  # arm B
      error        ->
        update_message_status(message, "failed")
        {:error, error}                                       # arm C
    end

  _ ->
    update_message_status(message, "sent")                    # arm D
    :ok
end
```

There are FOUR terminal arms (A, B, C, D), not two. CONTEXT.md D-02 enumerates them correctly via the `reason` enum:

- Arms A + B → `:sent` event, `reason: :notifier_ok`
- Arm C → `:failed` event, `reason: :notifier_returned_error`
- Arm D → `:sent` event, `reason: :no_notifier_configured`

**How to avoid:** Plan the patch as: emit the bounded-metrics event AND the OI trace event at the exact point where `update_message_status/2` is called, in each of the four arms. Consider refactoring the four arms to a single `emit_delivery_telemetry(:sent | :failed, reason)` private helper to avoid 4× copy-paste of two emit calls each.

**Warning signs:** Tests that only attach to `[:cairnloop, :outbound, :delivery, :sent]` and pass when the notifier is missing without actually firing; a `mix coveralls` report showing the `_ ->` arm has zero telemetry coverage.

### Pitfall 2: `:telemetry.attach/4` is process-global

**What goes wrong:** Tests pollute each other. A handler attached in one test fires in another, or fails to detach when the test crashes.

**Why it happens:** The `:telemetry` library stores handlers in a shared ETS table at the BEAM level, not per-process.

**How to avoid:** Mirror the in-repo pattern verbatim:
```elixir
# from test/cairnloop/governance/telemetry/traces_test.exs:23-37
defp attach_trace_handler(test_id, event_atom) do
  handler_id = "test-trace-handler-#{test_id}-#{event_atom}"
  :telemetry.attach(handler_id, [:cairnloop, :outbound, :trace, event_atom], ...)
  on_exit(fn -> :telemetry.detach(handler_id) end)
  handler_id
end
```
Use `%{test: test_id} = context` from ExUnit so each test's handler ID is unique. Always pair `:telemetry.attach/4` with an `on_exit/1` detach.

**Warning signs:** Flaky test runs where a single test passes in isolation but fails in suite order; `:telemetry` handler counts that grow during a `mix test` run.

### Pitfall 3: Cap-refused lane in `bulk_trigger_refused/6` has THREE arms

**What goes wrong:** Emitting the OI `:bulk_refused` trace only on the happy `{:ok, _envelope}` arm, missing the changeset-error and unexpected-shape lanes (`outbound.ex:260-289`).

**Why it happens:** Phase 25 plan 02's CR-02 hardening added two extra error arms that emit `:refused_cap_exceeded_audit_failed` bounded-metrics events. Symmetry across the OI lane requires the same three arms.

**How to avoid:** Plan task should explicitly enumerate the three arms when patching `bulk_trigger_refused/6`. Emit `Traces.emit(:bulk_refused, %{outcome: :refused_cap_exceeded | :refused_cap_exceeded_audit_failed, …})` on every arm. (Outcome stays enum-only per D-01.)

**Warning signs:** A regression test that mocks `repo().insert/1` to return a changeset error never receives the OI trace event.

### Pitfall 4: `BulkEnvelope` is a `binary_id` PK, not an integer

**What goes wrong:** `get_bulk_outbound_envelope/1` is called with an integer id and crashes when Ecto tries to cast to `:binary_id`.

**Why it happens:** `bulk_envelope.ex:51` declares `@primary_key {:id, :binary_id, autogenerate: false}`. The caller pattern is `repo().get(BulkEnvelope, "uuid-string")`.

**How to avoid:** Document the `id` parameter type in the `@doc` (`"a binary UUID string, e.g. from `Ecto.UUID.generate/0`"`). The function itself should NOT do extra validation — Ecto's `:binary_id` cast handles invalid input and returns `nil`. Test with a valid UUID, an invalid string, and an integer — confirm all three behave correctly (the latter two should return `nil`, not raise).

**Warning signs:** Integration tests that pass integer ids and pass against MockRepo but crash against real Postgres.

### Pitfall 5: The Phase 17 traces test file does NOT use `:telemetry_test.attach_event_handlers/2`

**What goes wrong:** CONTEXT.md D-12 mentions `:telemetry_test.attach_event_handlers/2`, but a `grep` for it returns zero hits in the codebase. Using the wrong API leads to "module not found" failures at compile time.

**Why it happens:** The `:telemetry_test` Erlang module is a separate package (`telemetry_test`) that is not in the project's `deps`. The existing pattern uses `:telemetry.attach/4` directly (verified at `test/cairnloop/governance/telemetry/traces_test.exs:26` + `test/cairnloop/governance/telemetry_test.exs:27`).

**How to avoid:** **Decide-and-proceed: use plain `:telemetry.attach/4` matching the in-repo pattern.** No new dep is needed; the existing tests are self-sufficient. If a future phase wants the `:telemetry_test` helpers, that's a separate dependency-addition decision (and would need slopcheck verification).

**Warning signs:** A compile-time `:telemetry_test.attach_event_handlers/2 (UndefinedFunctionError)` once the test file is added.

### Pitfall 6: Modal close-button collides with `phx-window-keydown="cancel_bulk_confirm"` semantics

**What goes wrong:** Adding the close-button `phx-click="cancel_bulk_confirm"` works for click, but a careless inline style or `aria-modal="true"` interaction with screen readers may swallow the click.

**Why it happens:** The modal is wrapped in `<.focus_wrap>` (`inbox_live.ex:187`) which traps focus inside the dialog. The close button must be inside the focus wrap, must have a positive tab order naturally (no `tabindex="-1"`), and must have `aria-label="Close"` since it has no visible text.

**How to avoid:**
- Place the `<button>` as the FIRST child of `<div class="bulk-confirm-dialog">` (so it's visible top-right and focus lands there first on modal-open per `<.focus_wrap>` semantics — or AFTER the title for slightly nicer reading-order; either is acceptable).
- Inline style: `position: absolute; top: 16px; right: 16px; min-width: 44px; min-height: 44px; border: none; background: transparent; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62)); font-size: 24px; line-height: 1; cursor: pointer;`.
- `aria-label="Close"`.
- `phx-click="cancel_bulk_confirm"`.
- Add `position: relative;` to the `<div class="bulk-confirm-dialog">` inline style so the `position: absolute` close button anchors to the dialog box, not the page.

**Warning signs:** Headless test assertion `assert html =~ "aria-label=\"Close\""` passes, but in-browser the close button is hidden behind the dialog background or has no tap target on mobile.

### Pitfall 7: The failed-bubble subhead must be additive — DO NOT change the existing chip rendering

**What goes wrong:** Removing the existing `<span class="message-status-chip status-failed">Failed</span>` chip and replacing it with the new subhead. That breaks Phase 22 / 23 / 24 tests that assert on the chip class.

**Why it happens:** The chip is at `conversation_live.ex:771-775`; the subhead is a NEW element. Both must render when `metadata["status"] == "failed"`.

**How to avoid:** Render the subhead as a sibling element next to (or below) the existing chip in the `.message-card-header` div, conditional on `outbound_status_label(msg) == "Failed"`. Or render it inside the `.message-card` body below the `<p class="message-content">`. Either is acceptable provided the chip + class stay untouched.

Suggested placement (additive — does not touch existing chip):
```elixir
<%= if outbound_status_label(msg) == "Failed" do %>
  <p class="outbound-failed-subhead" style="margin: 6px 0 0; font-size: 14px; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));">
    Delivery did not complete. Try again from the Outbound recovery card.
  </p>
<% end %>
```

**Warning signs:** Phase 22/23/24 tests fail with `Expected "status-failed" to be in HTML`; the planner's verify gate flags a regression.

### Pitfall 8: REPO-UNAVAILABLE applies to anything that uses `Cairnloop.Repo` indirectly

**What goes wrong:** A facade test for `list_recent_bulk_outbound_envelopes/1` is written without a `MockRepo`, runs against a real `Cairnloop.Repo` config, and fails with `(DBConnection.ConnectionError) connection not available` on the workspace machine.

**Why it happens:** The facade functions call `repo().all/1` where `repo()` resolves to `Application.fetch_env!(:cairnloop, :repo)`. In the headless test environment this must be a MockRepo.

**How to avoid:** Every Wave 2 test that touches the facade defines a local `MockRepo` returning canned `%BulkEnvelope{…}` structs (mirror `test/cairnloop/web/inbox_live_test.exs:36-41` `EmptyRepo`). Integration assertions that need real Postgres carry the `# REPO-UNAVAILABLE` marker and use `@tag :integration` (mirror `outbound_worker_test.exs:139-154`).

**Warning signs:** `mix test` (excludes `:integration` by default per `test_helper.exs:11`) failing with DB connection errors — that's the symptom of a missing MockRepo.

## Code Examples

### Example 1: Headless test for the new `Cairnloop.Outbound.Telemetry.Traces` module

```elixir
# test/cairnloop/outbound/telemetry/traces_test.exs
# Source: copy-modified from test/cairnloop/governance/telemetry/traces_test.exs (in-tree)

defmodule Cairnloop.Outbound.Telemetry.TracesTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Outbound.Telemetry.Traces

  defp attach_trace_handler(test_id, event_atom) do
    handler_id = "outbound-trace-#{test_id}-#{event_atom}"
    :telemetry.attach(
      handler_id,
      [:cairnloop, :outbound, :trace, event_atom],
      fn _event, _measurements, metadata, _config ->
        send(self(), {:trace_metadata, metadata})
      end,
      nil
    )
    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  @attrs %{
    bulk_envelope_id: "env-1",
    conversation_id: 42,
    template_id: "recovery_v1",
    actor_id: "actor-1",
    outcome: :triggered
  }

  describe "emit/2 — span kind mapping (D-03)" do
    test ":delivery_sent fires with span kind TOOL", %{test: test_id} do
      attach_trace_handler(test_id, :delivery_sent)
      Traces.emit(:delivery_sent, Map.put(@attrs, :outcome, :sent))
      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "TOOL"
    end

    test ":delivery_failed fires with span kind TOOL", %{test: test_id} do
      attach_trace_handler(test_id, :delivery_failed)
      Traces.emit(:delivery_failed, Map.put(@attrs, :outcome, :failed))
      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "TOOL"
    end

    test ":trigger_started fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :trigger_started)
      Traces.emit(:trigger_started, @attrs)
      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
    end

    test ":bulk_submitted fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :bulk_submitted)
      Traces.emit(:bulk_submitted, @attrs)
      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
    end
  end

  describe "emit/2 — guard-clause no-op" do
    test "unknown event is silently dropped", %{test: test_id} do
      handler_id = "outbound-trace-#{test_id}-bogus"
      :telemetry.attach(
        handler_id,
        [:cairnloop, :outbound, :trace, :not_a_real_event],
        fn _ev, _m, _md, _c -> send(self(), :should_not_fire) end,
        nil
      )
      on_exit(fn -> :telemetry.detach(handler_id) end)
      Traces.emit(:not_a_real_event, @attrs)
      refute_receive :should_not_fire, 100
    end
  end

  describe "namespace isolation from bounded-metrics (D-03 / mirrors D17-01)" do
    test "attaching to [:cairnloop, :outbound, :delivery, :sent] does NOT fire when Traces.emit(:delivery_sent) is called",
         %{test: test_id} do
      handler_id = "bounded-isolation-#{test_id}"
      :telemetry.attach(
        handler_id,
        [:cairnloop, :outbound, :delivery, :sent],
        fn _ev, _m, _md, _c -> send(self(), :leaked) end,
        nil
      )
      on_exit(fn -> :telemetry.detach(handler_id) end)
      Traces.emit(:delivery_sent, @attrs)
      refute_receive :leaked, 100,
        "Traces.emit must NOT fire the 4-segment bounded-metrics delivery event"
    end
  end

  describe "metadata payload exclusion (D-03 / mirrors D17-02)" do
    test "metadata does not carry :content key", %{test: test_id} do
      attach_trace_handler(test_id, :delivery_sent)
      Traces.emit(:delivery_sent, Map.put(@attrs, :content, "secret body"))
      assert_receive {:trace_metadata, meta}, 500
      refute Map.has_key?(meta, :content)
    end

    test "metadata does not carry :rendered_body key", %{test: test_id} do
      attach_trace_handler(test_id, :bulk_submitted)
      Traces.emit(:bulk_submitted, Map.put(@attrs, :rendered_body, "secret body"))
      assert_receive {:trace_metadata, meta}, 500
      refute Map.has_key?(meta, :rendered_body)
    end
  end
end
```

### Example 2: Delivery-side telemetry in `OutboundWorker.perform/1` (Wave 1)

```elixir
# Patch lib/cairnloop/workers/outbound_worker.ex perform/1 (current lines 70-93).
# Add the alias at the top: alias Cairnloop.Outbound.Telemetry.Traces

def perform(%Oban.Job{args: %{"message_id" => message_id} = args}) do
  repo = Application.fetch_env!(:cairnloop, :repo)
  message = repo.get!(Message, message_id)
  conversation = Chat.get_conversation!(message.conversation_id)

  case Application.get_env(:cairnloop, :notifier) do
    notifier when is_atom(notifier) and not is_nil(notifier) ->
      case notifier.on_outbound_triggered(message, conversation) do
        :ok ->
          update_message_status(message, "sent")
          emit_delivery(:sent, :notifier_ok, message, args)

        {:ok, _} ->
          update_message_status(message, "sent")
          emit_delivery(:sent, :notifier_ok, message, args)

        error ->
          update_message_status(message, "failed")
          emit_delivery(:failed, :notifier_returned_error, message, args)
          {:error, error}
      end

    _ ->
      update_message_status(message, "sent")
      emit_delivery(:sent, :no_notifier_configured, message, args)
      :ok
  end
end

# Phase 26 OBS-01 D-02: bounded-metrics + OI trace, side-by-side, enum-only labels.
defp emit_delivery(outcome, reason, message, args)
     when outcome in [:sent, :failed] do
  Cairnloop.Telemetry.execute(
    [:outbound, :delivery, outcome],
    %{count: 1},
    %{outcome: outcome, reason: reason}
  )

  # OI trace event — additive, fire-and-forget, after bounded-metrics (Phase 26 D-03).
  Cairnloop.Outbound.Telemetry.Traces.emit(
    if(outcome == :sent, do: :delivery_sent, else: :delivery_failed),
    %{
      conversation_id: message.conversation_id,
      template_id: Map.get(message.metadata || %{}, "template_id"),
      bulk_envelope_id: Map.get(args, "bulk_envelope_id"),
      actor_id: nil,
      outcome: outcome
    }
  )
end
```

### Example 3: Failed-bubble subhead in `conversation_live.ex` (Wave 3)

```elixir
# Patch the message-card render block at conversation_live.ex:768-778.
# Existing chip render stays untouched; the subhead is purely additive.

<div class={["message-card", "role-#{msg.role}"]}>
  <div class="message-card-header">
    <span class="message-role-label"><%= message_role_label(msg.role) %></span>
    <%= if outbound_status = outbound_status_label(msg) do %>
      <span class={["message-status-chip", outbound_status_class(msg)]}>
        <%= outbound_status %>
      </span>
    <% end %>
  </div>
  <p class="message-content"><%= msg.content %></p>
  <%!-- Phase 26 D-09: calm reason-forward subhead on :failed delivery only. --%>
  <%= if outbound_status_label(msg) == "Failed" do %>
    <p
      class="outbound-failed-subhead"
      style="margin: 6px 0 0; font-size: 14px; line-height: 1.4; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));"
    >
      Delivery did not complete. Try again from the Outbound recovery card.
    </p>
  <% end %>
</div>
```

### Example 4: Inbox empty state + modal close-button (Wave 3)

```elixir
# Patch lib/cairnloop/web/inbox_live.ex render/1.
# Empty state: insert AFTER <h1>Inbox</h1> at line 116, conditional on @conversations == [].

<h1>Inbox</h1>

<%= if @conversations == [] do %>
  <%!-- Phase 26 D-08: empty inbox state. Calm, reason-forward, brand-aligned. --%>
  <p
    class="inbox-empty-state"
    style="margin-top: 12px; font-size: 14px; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));"
  >
    No conversations yet.
  </p>
<% else %>
  <%!-- bulk header, list, sticky bar, etc. — existing render tree --%>
<% end %>

# Modal close-button: insert as the FIRST child of <div class="bulk-confirm-dialog">
# (currently at inbox_live.ex:188-191). Add `position: relative;` to the dialog inline
# style so the absolute-positioned button anchors to the dialog box.

<div
  class="bulk-confirm-dialog"
  style="position: relative; background: var(--cl-surface, #FBF7EE); ...existing styles..."
>
  <%!-- Phase 26 D-08: visible close affordance. Esc already works; this is discoverability. --%>
  <button
    type="button"
    phx-click="cancel_bulk_confirm"
    aria-label="Close"
    style="position: absolute; top: 12px; right: 12px; min-width: 44px; min-height: 44px; border: none; background: transparent; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62)); font-size: 24px; line-height: 1; cursor: pointer; padding: 0;"
  >
    ×
  </button>

  <%!-- existing modal content: refusal banner OR confirm view --%>
</div>
```

### Pre-existing telemetry inventory (do NOT duplicate)

| Event path | Where emitted | Already shipped in |
|---|---|---|
| `[:cairnloop, :outbound, :triggered, :start \| :stop \| :exception]` | `outbound.ex:91` via `Cairnloop.Telemetry.span/3` | Phase 22 (enum-only since Phase 25) |
| `[:cairnloop, :outbound, :bulk, :triggered, :start \| :stop \| :exception]` | `outbound.ex:325` via `Cairnloop.Telemetry.span/3` (submit lane) | Phase 25 plan 02 |
| `[:cairnloop, :outbound, :bulk, :triggered]` (point-in-time) | `outbound.ex:254-289` via `Cairnloop.Telemetry.execute/3` (refused lane, 3 outcomes: `:refused_cap_exceeded`, `:refused_cap_exceeded_audit_failed` × 2) | Phase 25 plan 02 |

Phase 26 adds:
- `[:cairnloop, :outbound, :delivery, :sent]` (Wave 1, D-02 — point-in-time)
- `[:cairnloop, :outbound, :delivery, :failed]` (Wave 1, D-02 — point-in-time)
- `[:cairnloop, :outbound, :trace, :trigger_started]` (Wave 1, D-03 — point-in-time)
- `[:cairnloop, :outbound, :trace, :trigger_completed]` (Wave 1, D-03 — point-in-time)
- `[:cairnloop, :outbound, :trace, :trigger_failed]` (Wave 1, D-03 — point-in-time)
- `[:cairnloop, :outbound, :trace, :bulk_submitted]` (Wave 1, D-03 — point-in-time)
- `[:cairnloop, :outbound, :trace, :bulk_refused]` (Wave 1, D-03 — point-in-time)
- `[:cairnloop, :outbound, :trace, :delivery_sent]` (Wave 1, D-03 — point-in-time)
- `[:cairnloop, :outbound, :trace, :delivery_failed]` (Wave 1, D-03 — point-in-time)

## Runtime State Inventory

Phase 26 is not a rename/refactor/migration phase. **Section intentionally omitted per execution flow Step 2.5.**

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir compiler | All waves | ✓ | (project default per `.tool-versions`) | — |
| `:telemetry` lib | OBS-01 emission + tests | ✓ (already in deps) | ~> 1.0 | — |
| `Ecto.Query` | OBS-02 facade reads | ✓ (already imported at `governance.ex:60`) | — | — |
| `Phoenix.LiveView` + `Phoenix.LiveViewTest` | Wave 3 polish tests | ✓ (already in deps; used in `inbox_live_test.exs:3`) | — | — |
| `Cairnloop.Repo` (Postgres) | Wave 2 integration assertions ONLY | ✗ (per CLAUDE.md REPO-UNAVAILABLE) | — | Headless tests with local `MockRepo`; integration assertions tagged `@tag :integration` + `# REPO-UNAVAILABLE` for operator to run on a Postgres host (mirrors the Phase 25 BLOCKING handoff pattern). |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** `Cairnloop.Repo` — handled via the established headless / `# REPO-UNAVAILABLE` integration split per CLAUDE.md and Phase 25 precedent. The headless test layer fully covers Phase 26's behavior; integration assertions are captured for the operator and tagged with `@tag :integration`.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (Elixir stdlib) |
| Config file | `test/test_helper.exs` (in-tree; default suite excludes `:integration` tag — see lines 11-12) |
| Quick run command | `mix test` (the headless suite — REPO-UNAVAILABLE-safe) |
| Full suite command | `mix test` (headless) — `mix test.integration` would add the DB-backed lane but is REPO-UNAVAILABLE in this workspace per CLAUDE.md |
| Build gate | `mix compile --warnings-as-errors` MUST be clean (CLAUDE.md mandatory) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| OBS-01 | `Cairnloop.Outbound.Telemetry.Traces.emit/2` accepts the 7 listed atoms; unknown atoms silently dropped | unit | `mix test test/cairnloop/outbound/telemetry/traces_test.exs` | ❌ Wave 1 (new file — mirrors `test/cairnloop/governance/telemetry/traces_test.exs`) |
| OBS-01 | Trace events carry `"openinference.span.kind"` = `"TOOL"` for `:delivery_*`, `"GUARDRAIL"` otherwise | unit | `mix test test/cairnloop/outbound/telemetry/traces_test.exs` | ❌ Wave 1 |
| OBS-01 | Trace metadata excludes `:content`, `:rendered_body`, `:refused_reason` | unit | `mix test test/cairnloop/outbound/telemetry/traces_test.exs` | ❌ Wave 1 |
| OBS-01 | Trace namespace isolation: emitting to `[:cairnloop, :outbound, :trace, :delivery_sent]` does NOT fire handlers on `[:cairnloop, :outbound, :delivery, :sent]` | unit | `mix test test/cairnloop/outbound/telemetry/traces_test.exs` | ❌ Wave 1 |
| OBS-01 | `OutboundWorker.perform/1` emits `[:cairnloop, :outbound, :delivery, :sent]` on all three success arms with correct `reason` (`:notifier_ok` × 2 + `:no_notifier_configured`) | unit | `mix test test/cairnloop/workers/outbound_worker_test.exs` | ✓ existing file — Wave 1 adds 4 tests (one per arm) |
| OBS-01 | `OutboundWorker.perform/1` emits `[:cairnloop, :outbound, :delivery, :failed]` with `reason: :notifier_returned_error` on the error arm | unit | `mix test test/cairnloop/workers/outbound_worker_test.exs` | ✓ existing file — Wave 1 |
| OBS-01 | `OutboundWorker.perform/1` also emits OI trace event `:delivery_sent` / `:delivery_failed` alongside the bounded-metrics event | unit | `mix test test/cairnloop/workers/outbound_worker_test.exs` | ✓ existing file — Wave 1 |
| OBS-01 | `Outbound.trigger/2` emits OI trace events `:trigger_started` + `:trigger_completed` alongside the existing bounded-metrics span | unit | `mix test test/cairnloop/outbound_test.exs` | ✓ existing file — Wave 1 |
| OBS-01 | `Outbound.bulk_trigger/2` submit path emits OI trace `:bulk_submitted`; refused path emits OI trace `:bulk_refused` on all three terminal arms | unit | `mix test test/cairnloop/outbound_test.exs` | ✓ existing file — Wave 1 |
| OBS-01 | `Cairnloop.Telemetry` `@moduledoc` includes the new "Outbound Events" block documenting both vocabularies | unit | `mix test test/cairnloop/telemetry_test.exs` (or a new headless `_moduledoc_test.exs`) | ❓ may need new test — or pinned via inline source grep in an existing test |
| OBS-02 | `Outbound.trigger/2` calls `auditor.audit(:outbound_trigger, actor, %{conversation_id, template_id})` with exact metadata shape | unit | `mix test test/cairnloop/outbound_test.exs` | ✓ existing file — Wave 2 adds shape regression |
| OBS-02 | `Outbound.bulk_trigger/2` submit path calls `auditor.audit(:bulk_outbound_trigger, actor, %{bulk_envelope_id, count, template_id})` with exact metadata shape | unit | `mix test test/cairnloop/outbound_test.exs` | ✓ existing file — Wave 2 |
| OBS-02 | `Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1` returns rows ordered `requested_at desc`, default limit 50, accepts `:status` filter | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✓ existing file — Wave 2 |
| OBS-02 | `list_recent_bulk_outbound_envelopes/1` raises `ArgumentError` when `:limit > 500` | unit (no Repo needed — the guard fires before the query) | `mix test test/cairnloop/governance_test.exs` | ✓ existing file — Wave 2 |
| OBS-02 | `Cairnloop.Governance.get_bulk_outbound_envelope/1` returns `nil` on miss (does not raise) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✓ existing file — Wave 2 |
| OBS-02 | Integration: facade reads return real envelope rows after `bulk_trigger/2` has persisted submit + refused lanes | integration (`# REPO-UNAVAILABLE`) | `mix test.integration --only integration` (operator host) | ❓ Wave 2 — new `@tag :integration` cases |
| Polish (D-08) | InboxLive renders "No conversations yet." when `@conversations == []`; no bulk header, no toolbar | unit | `mix test test/cairnloop/web/inbox_live_test.exs` | ✓ existing file — Wave 3 |
| Polish (D-08) | InboxLive renders top-right `×` close button inside the confirm dialog with `aria-label="Close"`, 44px tap target, calls `cancel_bulk_confirm` | unit | `mix test test/cairnloop/web/inbox_live_test.exs` | ✓ existing file — Wave 3 |
| Polish (D-08) | When `@conversations != []` but `visible_eligible_ids/1` is empty, the bulk header does NOT render (regression on Phase 25 `has_visible_eligible?/1`) | unit | `mix test test/cairnloop/web/inbox_live_test.exs` | ✓ existing file — Wave 3 (regression gate) |
| Polish (D-09) | ConversationLive renders the `Delivery did not complete. Try again from the Outbound recovery card.` subhead when `metadata["status"] == "failed"`; does NOT render it for `"sent"`/`"pending"` | unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ✓ existing file — Wave 3 |
| Polish (D-09) | `outbound_recovery_card/1` has `<section aria-label="Outbound recovery">` (a11y verification — likely already passes) | unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ✓ existing file — Wave 3 (verification gate) |

### Sampling Rate

- **Per task commit:** `mix compile --warnings-as-errors && mix test test/cairnloop/outbound/telemetry/traces_test.exs` (or whichever single file the task touched).
- **Per wave merge:** `mix compile --warnings-as-errors && mix test` (full headless suite — must be 100% green per CLAUDE.md, modulo the documented Phase 25 BLOCKING gates and the known baseline `Automation.DraftTest` pre-existing failure from MEMORY).
- **Phase gate:** `mix compile --warnings-as-errors` clean + `mix test` green (headless) before `/gsd:verify-work`; `# REPO-UNAVAILABLE` integration assertions captured for operator and tagged `@tag :integration` to run on a Postgres host.

### Wave 0 Gaps

- [ ] `test/cairnloop/outbound/telemetry/traces_test.exs` — covers OBS-01 OI trace module (new file; mirror `test/cairnloop/governance/telemetry/traces_test.exs` verbatim, swap namespace + event atoms + attribution refs).
- [ ] Confirm `mix test test/cairnloop/telemetry_test.exs` runs against an existing file or whether a new `telemetry_test.exs` needs to be created at `test/cairnloop/`. (The existing pattern keeps moduledoc copy under `@moduledoc` + source-grep tests if a moduledoc invariant gate is wanted; or skip a formal test and rely on planner-time review of the appended block.)
- [ ] No framework install needed — ExUnit is stdlib; `:telemetry` is already a dep.

## Project Constraints (from CLAUDE.md)

| Directive | Source | Phase 26 application |
|---|---|---|
| **Decide-and-proceed, don't surface gray-area questions** | "Decision policy (shift-left)" | Researcher decided: use plain `:telemetry.attach/4` (not `:telemetry_test`); use `:telemetry.execute/3` directly for OI lane (not centralizer); place `Traces.emit/2` AFTER bounded-metrics emission (matches Phase 17). Owner-veto items flagged in CONTEXT.md (D-03 = OI trace lane; D-07 = no first-party admin UI). |
| **Warnings-clean builds mandatory: `mix compile --warnings-as-errors`** | "Build / test conventions" | All planner tasks must run this command and pass before marking work done. |
| **`mix test` before declaring work done; report failures honestly** | "Build / test conventions" | Headless suite is the gate; the one known baseline `Automation.DraftTest` failure is NOT a Phase 26 regression (per MEMORY). |
| **`Cairnloop.Repo` may be unavailable** | "Build / test conventions" | All facade tests use `MockRepo`; integration assertions tagged `# REPO-UNAVAILABLE` + `@tag :integration` per Phase 25 BLOCKING precedent. |
| **Durable Ecto records + events are workflow truth; telemetry is observability only** | "Architecture posture" | Phase 26 telemetry events are observability ONLY; the durable `BulkEnvelope` row + `Message.metadata["status"]` are the truth. UI does NOT read from telemetry. |
| **New reads through narrow `Cairnloop.Governance` facade** | "Architecture posture" | OBS-02 reads land in `Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`. No direct Ecto queries from the web layer. |
| **Snapshot trust facts at decision time; never re-read live config at render time** | "Architecture posture" | `BulkEnvelope.rendered_body` + `:effective_cap` + `:requested_at` are the snapshot. Facade reads return them as-is. |
| **Seal completed phases — don't churn sealed code paths** | "Architecture posture" | `Outbound.trigger/2` + `bulk_trigger/2` public signatures are sealed (D-12 from Phase 25). Phase 26 ADDS OI trace emissions ALONGSIDE existing bounded-metrics; does NOT replace or restructure the sealed `:telemetry.span/3` blocks. |
| **Operator copy: calm, fail-closed, reason-forward; no emoji; no exclamation marks; never raw Elixir terms** | "Architecture posture" + brand book §7.5 | Empty-state copy: "No conversations yet." Failed-bubble subhead: "Delivery did not complete. Try again from the Outbound recovery card." Modal close button: `×` (plain glyph). No emoji, no `inspect/1` output anywhere in rendered HTML. |
| **Never state-by-color-alone (§7.5)** | brand book | Failed-bubble already has `.status-failed` class + `"Failed"` chip TEXT + new reason-forward subhead — three non-color signals. Modal refusal banner already passes (SVG icon + text + danger token). |
| **Brand tokens over hardcoded hex: `var(--cl-primary, #A94F30)`** | "Architecture posture" | New empty-state paragraph uses `var(--cl-text-muted, rgba(47, 36, 29, 0.62))`. New failed-bubble subhead uses the same. New close-button uses `var(--cl-text-muted, …)`. All fallback hex values are inline so headless tests can assert against the brand vocabulary in rendered HTML. |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Single `Cairnloop.Telemetry` umbrella for both bounded-metrics + traces | Sibling modules (`Cairnloop.Governance.Telemetry` + `Cairnloop.Governance.Telemetry.Traces`); disjoint namespaces | Phase 17 (sealed) | Phase 26 mirrors this posture for outbound — no merger of bounded-metrics + OI traces under a single module (CONTEXT.md "Deferred Ideas"). |
| Direct `Cairnloop.Repo.all/1` calls from LiveView | Narrow `Cairnloop.Governance` facade with `repo()` indirection | Phase 25 plan 01 (D-14) | Phase 26 OBS-02 read facade follows. New consumer-side reads land here, not on `BulkEnvelope` or `Cairnloop.Repo`. |
| High-cardinality telemetry labels (`conversation_id`, `template_id`, `actor` in metadata) | Enum-only labels (`outcome`, `count`, `reason`) | Phase 25 plan 02 (D-B / WR-04) | Phase 26 carries forward (D-01). Attribution refs (`conversation_id`, etc.) live in the OI trace lane (sampled span-tree observability), NOT the bounded-metrics aggregator. |
| Per-recipient `OutboundWorker` jobs without dedup keys | Oban `unique:` declaration with `(conversation_id, template_id, bulk_envelope_id)` tuple | Phase 25 plan 02 (D-11) | Phase 26 leaves this sealed; the unique-clause regression test from `outbound_worker_test.exs:75-131` is the gate. |

**Deprecated/outdated:** none in Phase 26. All patterns are current.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | `Application.fetch_env!(:cairnloop, :repo)` indirection is the universal pattern across the codebase (governance, outbound, workers all use it) — VERIFIED in `outbound.ex:31`, `outbound_worker.ex:71`, `governance.ex:81`. | Pattern 3 facade read | Low — verified in three call sites. |
| A2 | `:telemetry.attach/4` (process-global) is the test pattern used in the in-tree Traces test — VERIFIED at `traces_test.exs:26-33`. CONTEXT.md D-12's mention of `:telemetry_test.attach_event_handlers/2` is NOT in deps — GREP confirmed zero hits. | Common Pitfalls — Pitfall 5 | Low — researcher applied decide-and-proceed per CLAUDE.md shift-left; matches the actual codebase pattern. If owner specifically wants `:telemetry_test`, that's a dep-addition decision (slopcheck would be needed). |
| A3 | The Phase 17 OI trace lane is fully sealed and its module + tests are intact — VERIFIED by reading both files end-to-end (`governance/telemetry/traces.ex` + `governance/telemetry/traces_test.exs`). | Standard Stack + Pattern 1 | Very low — files exist and reference Phase 17 explicitly. |
| A4 | The current `OutboundWorker.perform/1` has exactly FOUR delivery arms (A/B happy, C error, D no-notifier) — VERIFIED at `outbound_worker.ex:75-92`. | Common Pitfalls — Pitfall 1 | Low — verified by direct read. |
| A5 | `BulkEnvelope` primary key is `:binary_id` requiring a UUID string for `get_bulk_outbound_envelope/1` — VERIFIED at `bulk_envelope.ex:51`. | Common Pitfalls — Pitfall 4 | Low — verified by direct read of the schema. |
| A6 | The bounded-metrics + OI trace lanes can safely co-emit from the same call site because the namespaces are disjoint by construction (`[:cairnloop, :outbound, :delivery, :sent]` vs `[:cairnloop, :outbound, :trace, :delivery_sent]`) — VERIFIED conceptually by Phase 17 precedent and by the `traces_test.exs:163-188` namespace-isolation test which proves the property for the governance lane. | Pattern 2 + Pitfall 5 | Low — same isolation guarantee holds for the outbound namespace by the same logic. |
| A7 | The exact granularity of the `@events` enum (7 atoms) is correct as listed in CONTEXT.md D-03. CONTEXT.md "Claude's Discretion" explicitly allows ±1 atom if a finer split emerges — researcher recommends keeping the 7 atoms as listed; no refinement justified by the code as-of-today. | Pattern 1 + Validation Architecture | Low — discretion-allowed; planner can revisit. |
| A8 | The modal close-button placement (`position: absolute; top: 12px; right: 12px` inside the dialog, with `position: relative` added to the dialog) is correct affordance per existing brand-token usage in `inbox_live.ex` — VERIFIED against the existing button pattern at `inbox_live.ex:159-172` (44px min-height, brand tokens, no border for ghost-style). The close button is intentionally smaller/quieter than the primary `Confirm send` button. | Common Pitfalls — Pitfall 6 + Code Examples — Example 4 | Low — pattern is consistent with existing inline-style vocabulary in the file. |

**If this table is empty:** Not applicable — all assumptions above are explicitly listed.

## Open Questions

1. **Should the `Cairnloop.Telemetry` "Outbound Events" moduledoc block have a pinning test, or is planner-time inline review sufficient?**
   - What we know: existing moduledoc blocks (Conversation, Feedback, Retrieval, Knowledge-Maintenance) at `telemetry.ex:8-46` have NO pinning test — they are pure doc.
   - What's unclear: whether Phase 26 wants a regression to prevent moduledoc drift.
   - Recommendation: **Decide-and-proceed: no pinning test.** Follow the existing precedent (no pinning) — moduledoc is doc, not contract. Planner reviews diff at task-commit time. If the owner wants stricter doc-gating, that's a project-wide decision out of scope for this phase.

2. **Should the OI trace `actor_id` for delivery events come from `Message.metadata["actor"]` or from a new job-args field?**
   - What we know: `OutboundWorker.perform/1` does NOT currently extract actor from anywhere; the message is rendered and delivered without an actor context at worker-run time. The trigger-time actor lives in the auditor metadata (`outbound.ex:97`).
   - What's unclear: whether the OI trace at delivery time should attribute to the trigger-time actor (would require a new job-args key) or leave `actor_id: nil` for delivery events.
   - Recommendation: **Decide-and-proceed: `actor_id: nil` for delivery events.** The Phase 17 precedent uses `actor_id: "system"` for `:execution_started` because execution is system-initiated. Outbound delivery is the same — the trigger-time actor is captured at the trigger event; delivery is system-initiated. Use `actor_id: nil` (or `"system"` — either is acceptable; `nil` matches the Phase 17 default at `governance/telemetry/traces.ex:117`).

3. **For bulk-refused traces, should the OI metadata carry `effective_cap` (since this is an attribution ref, not free-text)?**
   - What we know: `BulkEnvelope.effective_cap` is an integer (the cap-of-the-moment); D-03 says attribution refs are OK, free-text is not.
   - What's unclear: whether bare-integer cap is "attribution ref" (OK) or "outcome detail" (also OK, but `outcome: :refused_cap_exceeded` already captures the lane).
   - Recommendation: **Decide-and-proceed: yes, include `effective_cap` in OI metadata for `:bulk_refused` events only.** It's an integer enum (one of `25` or whatever the host has configured) — low cardinality, useful for OI consumers who want to correlate refusals against policy changes. Add it to the metadata-build branch for `:bulk_refused` only; omit for other events.

## Sources

### Primary (HIGH confidence — in-tree, verified by direct read)

- `/Users/jon/projects/cairnloop/lib/cairnloop/governance/telemetry/traces.ex` — canonical OI trace pattern (Phase 17).
- `/Users/jon/projects/cairnloop/test/cairnloop/governance/telemetry/traces_test.exs` — canonical OI trace test pattern.
- `/Users/jon/projects/cairnloop/lib/cairnloop/telemetry.ex` — centralizer module + moduledoc structure for D-04.
- `/Users/jon/projects/cairnloop/lib/cairnloop/outbound.ex` — `trigger/2` and `bulk_trigger/2` call sites (lines 91, 254, 325 confirmed).
- `/Users/jon/projects/cairnloop/lib/cairnloop/workers/outbound_worker.ex` — `perform/1` 4-arm `case` block (lines 70-93 confirmed).
- `/Users/jon/projects/cairnloop/lib/cairnloop/governance.ex` lines 1021-1082 — `list_eligible_conversation_ids_for_bulk_recovery/1` + `preview_bulk_recovery_cohort/1`, the existing narrow-facade pattern for outbound-domain reads.
- `/Users/jon/projects/cairnloop/lib/cairnloop/governance.ex` lines 380-392 + 946-952 — the canonical `Traces.emit/2` call shape (AFTER bounded-metrics, with the `"OI trace event — additive, fire-and-forget, after bounded-metrics (Phase 17)"` comment).
- `/Users/jon/projects/cairnloop/lib/cairnloop/outbound/bulk_envelope.ex` — schema with `binary_id` PK and column inventory.
- `/Users/jon/projects/cairnloop/lib/cairnloop/web/inbox_live.ex` lines 113-291 — render tree for empty-state + modal close-button polish targets.
- `/Users/jon/projects/cairnloop/lib/cairnloop/web/conversation_live.ex` lines 768-820 + 990-1014 — failed-bubble template + `outbound_status_label/1` and `outbound_status_class/1` definitions.
- `/Users/jon/projects/cairnloop/test/cairnloop/workers/outbound_worker_test.exs` — `MockRepo` + `MockNotifier` + `ErrorNotifier` patterns + `@tag :integration` REPO-UNAVAILABLE example.
- `/Users/jon/projects/cairnloop/test/cairnloop/web/inbox_live_test.exs` lines 1-80 — `render_html/1` headless assertion pattern + `EmptyRepo` mount-test pattern.
- `/Users/jon/projects/cairnloop/test/test_helper.exs` — confirms `ExUnit.start(exclude: [:integration])` is the default suite filter.
- `/Users/jon/projects/cairnloop/.planning/STATE.md` — accumulated Phase 25 decisions and the two BLOCKING handoff gates.
- `/Users/jon/projects/cairnloop/.planning/REQUIREMENTS.md` lines 43-44 — OBS-01 + OBS-02 exact wording.
- `/Users/jon/projects/cairnloop/.planning/phases/26-observability-polish/26-CONTEXT.md` — full Phase 26 decision substrate.
- `/Users/jon/projects/cairnloop/CLAUDE.md` — project shift-left + build/test + architecture posture.

### Secondary (MEDIUM confidence)

- OpenInference span-kind taxonomy (`"TOOL"` vs `"GUARDRAIL"`): grounded in the in-tree Phase 17 implementation; the canonical OpenInference spec lives outside this repo but the in-tree usage IS the project's authoritative interpretation per Phase 17 D17-03.

### Tertiary (LOW confidence)

- None. Every claim in this research is grounded in either CONTEXT.md (locked decisions) or direct code reads.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every library is already in the project's `mix.exs`; no new deps; the patterns are in-tree.
- Architecture: HIGH — Phase 17 + Phase 25 set the precedents and they are in-tree, reviewed end-to-end.
- Pitfalls: HIGH — every pitfall is grounded in a specific line of code or a verified absence (e.g., grep for `:telemetry_test` returns zero hits).

**Research date:** 2026-05-27
**Valid until:** 2026-06-26 (30 days — patterns are stable; outbound substrate is sealed)
