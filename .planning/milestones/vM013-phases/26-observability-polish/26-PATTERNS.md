# Phase 26: Observability & Polish - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 12 (3 NEW + 9 ADD/touch)
**Analogs found:** 12 / 12

## File Classification

| New / Modified File | Wave | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `lib/cairnloop/outbound/telemetry/traces.ex` | 1 | telemetry module (OI traces) | event-driven (point-in-time emit) | `lib/cairnloop/governance/telemetry/traces.ex` | exact — verbatim copy-modify |
| `test/cairnloop/outbound/telemetry/traces_test.exs` | 1 | unit test | event-driven (attach + assert_receive) | `test/cairnloop/governance/telemetry/traces_test.exs` | exact — verbatim copy-modify |
| `lib/cairnloop/workers/outbound_worker.ex` (ADD) | 1 | Oban worker | request-response → event-driven emit | `lib/cairnloop/outbound.ex` `bulk_trigger_refused/6` (multi-arm `case` with per-arm `Cairnloop.Telemetry.execute/3`) | role+flow match |
| `lib/cairnloop/outbound.ex` `trigger/2` (ADD OI emit) | 1 | facade public API | request-response | `lib/cairnloop/governance.ex` `propose/3` lines 380–392 (Telemetry + Traces side-by-side) | exact — same pattern, same module family |
| `lib/cairnloop/outbound.ex` `bulk_trigger_submit/6` (ADD OI emit) | 1 | facade public API | request-response (inside span) | `governance.ex` lines 946–952 / 380–392 (Traces.emit AFTER bounded-metrics inside same lexical scope) | exact |
| `lib/cairnloop/outbound.ex` `bulk_trigger_refused/6` (ADD OI emit) | 1 | facade public API | request-response (3-arm case) | `outbound.ex` self lines 252–290 (3-arm `case repo().insert(…)` already emits bounded-metrics per arm — mirror with Traces.emit) | exact — self-analog |
| `lib/cairnloop/telemetry.ex` `@moduledoc` (ADD) | 1 | documentation block | doc-only | `lib/cairnloop/telemetry.ex` self lines 8–46 (existing Conversation / Feedback / Retrieval / Knowledge-Maintenance sections) | exact — self-analog |
| `test/cairnloop/workers/outbound_worker_test.exs` (ADD) | 1 | unit test | event-driven attach | `test/cairnloop/governance/telemetry/traces_test.exs` lines 23–37 (attach helper) + existing `test/cairnloop/workers/outbound_worker_test.exs` lines 7–58 (MockRepo + MockNotifier + setup) | exact — two analogs to combine |
| `test/cairnloop/outbound_test.exs` (ADD OI trace tests) | 1 | unit test | event-driven attach | `test/cairnloop/outbound_test.exs` self lines 149–175 (existing telemetry attach pattern in same file) + `traces_test.exs:23–37` | exact — self-analog |
| `lib/cairnloop/governance.ex` (ADD 2 read funcs) | 2 | narrow facade reader | CRUD (read-only) | `lib/cairnloop/governance.ex` self lines 1021–1072 (`list_eligible_conversation_ids_for_bulk_recovery/1` + `preview_bulk_recovery_cohort/1`) | exact — self-analog, adjacent insertion point |
| `test/cairnloop/governance_test.exs` (ADD facade tests) | 2 | unit test | MockRepo dispatch + filter | `test/cairnloop/governance_test.exs` self lines 13–96 (MockRepo with `all/1` dispatching on `query.from.source`) | exact — self-analog |
| `test/cairnloop/outbound_test.exs` (ADD auditor-shape regression) | 2 | unit test | request-response + audit assert | `test/cairnloop/outbound_test.exs` self lines 177–191 (existing `TestAuditor` defmodule + `assert results.audit.metadata == …`) | exact — self-analog |
| `lib/cairnloop/web/inbox_live.ex` (ADD empty state + modal `×`) | 3 | LiveView render | request-response (template) | `lib/cairnloop/web/inbox_live.ex` self lines 113–290 (existing `render/1` with brand-token inline styles) | exact — self-analog |
| `lib/cairnloop/web/conversation_live.ex` (ADD failed subhead) | 3 | LiveView render | request-response (template) | `lib/cairnloop/web/conversation_live.ex` self lines 767–778 (existing `message-card` + chip render) | exact — self-analog |
| `test/cairnloop/web/inbox_live_test.exs` (ADD polish tests) | 3 | unit test | render_html assertion | `test/cairnloop/web/inbox_live_test.exs` self lines 10–29 + 614–642 (`render_html/1` + `build_assigns/1` helpers) | exact — self-analog |
| `test/cairnloop/web/conversation_live_test.exs` (ADD subhead test) | 3 | unit test | render_html assertion | `test/cairnloop/web/conversation_live_test.exs` self lines 629–659 (existing `system_outbound` + chip render test) + 1461–1463 | exact — self-analog |

---

## Pattern Assignments

### Wave 1, Plan 01 — `lib/cairnloop/outbound/telemetry/traces.ex` (NEW)

**Analog:** `lib/cairnloop/governance/telemetry/traces.ex` (130 lines — copy-modify verbatim)

**Module header pattern** (analog lines 1–52 — `@moduledoc` shape):
```elixir
defmodule Cairnloop.Governance.Telemetry.Traces do
  @moduledoc """
  Optional OpenInference-conformant trace event module for the Cairnloop governed-action
  evidence lane (Phase 17, D17-01, D17-03).

  ## Namespace separation (D17-01)

  This module is SEPARATE from `Cairnloop.Governance.Telemetry` (the bounded-metrics
  module). It emits to a disjoint 4-segment event namespace:

      [:cairnloop, :governance, :trace, <event_atom>]
  ...
  ## Zero Scoria dependency

  This module calls `:telemetry.execute/3` directly. ...

  ## OI span kinds

  Trace events carry `"openinference.span.kind"` (string key per OI spec) in metadata:

  - Execution events (`:execution_started`, `:execution_succeeded`, `:execution_failed`):
    `"TOOL"`
  - All other governed-action events: `"GUARDRAIL"`
  ...
  """
```
**Swap:** `Governance` → `Outbound`; Phase 17 / D17-01 / D17-03 → Phase 26 / D-03; event list per CONTEXT.md D-03 (`:trigger_started, :trigger_completed, :trigger_failed, :bulk_submitted, :bulk_refused, :delivery_sent, :delivery_failed`).

**`@events` + span-kind constants** (analog lines 54–71):
```elixir
@events [
  :proposal_created,
  :proposal_blocked,
  :approval_requested,
  ...
  :execution_started,
  :execution_succeeded,
  :execution_failed
]

# OI span kind string constants (string keys per OpenInference spec)
@span_kind_tool "TOOL"
@span_kind_guardrail "GUARDRAIL"
```
**Swap:** replace with the 7 atoms enumerated in D-03 — `:trigger_started, :trigger_completed, :trigger_failed, :bulk_submitted, :bulk_refused, :delivery_sent, :delivery_failed`.

**`emit/2` head + guard-clause no-op** (analog lines 73–94 — copy verbatim, swap namespace):
```elixir
def emit(event, attrs) when event in @events do
  :telemetry.execute(
    [:cairnloop, :governance, :trace, event],
    %{count: 1},
    build_metadata(event, attrs)
  )
end

# Guard-clause no-op: unknown events are silently dropped (D17-05).
def emit(_event, _attrs), do: :ok
```
**Swap:** `:governance` → `:outbound`.

**`build_metadata/2` shape** (analog lines 100–120 — copy structure, swap attribution refs):
```elixir
defp build_metadata(event, attrs) do
  %{
    "openinference.span.kind" => span_kind_for(event),
    tool_proposal_id: attrs[:tool_proposal_id],
    actor_id: attrs[:actor_id],
    policy_snapshot_ref: attrs[:tool_proposal_id],
    decided_by: attrs[:decided_by],
    attempt: attrs[:attempt]
  }
end
```
**Swap:** outbound attribution refs per CONTEXT.md D-03 — `:bulk_envelope_id, :conversation_id, :template_id, :actor_id, :outcome`. Per RESEARCH Open Question 3, conditionally add `:effective_cap` to the `:bulk_refused` branch only.

**`span_kind_for/1` pattern** (analog lines 122–128 — copy structure, swap atom set):
```elixir
defp span_kind_for(event)
     when event in [:execution_started, :execution_succeeded, :execution_failed],
     do: @span_kind_tool

defp span_kind_for(_event), do: @span_kind_guardrail
```
**Swap:** outbound execution atoms are `:delivery_sent, :delivery_failed` (D-03 — execution-events-are-TOOL).

---

### Wave 1, Plan 01 — `test/cairnloop/outbound/telemetry/traces_test.exs` (NEW)

**Analog:** `test/cairnloop/governance/telemetry/traces_test.exs` (190 lines — copy-modify verbatim)

**Test module header** (analog lines 1–17 — copy structure):
```elixir
defmodule Cairnloop.Governance.Telemetry.TracesTest do
  @moduledoc """
  Headless (pure, no DB) proof of `Cairnloop.Governance.Telemetry.Traces` OI-conformant
  trace event module.

  Covers:
  - OI span kind assignment per event atom (TOOL vs GUARDRAIL)
  - Attribution field presence (tool_proposal_id, actor_id)
  - Payload content exclusion (D17-02: no :content, :input_snapshot keys)
  - Guard-clause no-op for unknown events (D17-05)
  - Namespace isolation from the bounded-metrics ... module (D17-01)
  """
  use ExUnit.Case, async: false

  alias Cairnloop.Governance.Telemetry.Traces
```
**Swap:** `Governance` → `Outbound`; Phase 17 D-codes → Phase 26 D-03; attribution refs.

**Handler-attach helper** (analog lines 23–37 — copy verbatim, swap namespace):
```elixir
defp attach_trace_handler(test_id, event_atom) do
  handler_id = "test-trace-handler-#{test_id}-#{event_atom}"

  :telemetry.attach(
    handler_id,
    [:cairnloop, :governance, :trace, event_atom],
    fn _event, _measurements, metadata, _config ->
      send(self(), {:trace_metadata, metadata})
    end,
    nil
  )

  on_exit(fn -> :telemetry.detach(handler_id) end)
  handler_id
end

@attrs %{tool_proposal_id: "p-1", actor_id: "actor-1", decided_by: nil, attempt: nil}
```
**Swap:** `:governance` → `:outbound` in the event path; `@attrs` swap to outbound attribution refs.

**Span-kind assertion test** (analog lines 46–57 — copy structure, swap event atom):
```elixir
test ":execution_succeeded fires with span kind TOOL", %{test: test_id} do
  attach_trace_handler(test_id, :execution_succeeded)
  Traces.emit(:execution_succeeded, @attrs)
  assert_receive {:trace_metadata, meta}, 500
  assert meta["openinference.span.kind"] == "TOOL"
end
```
**Swap:** `:delivery_sent` / `:delivery_failed` for TOOL; `:trigger_started` / `:bulk_submitted` for GUARDRAIL.

**Payload exclusion test** (analog lines 104–129 — copy verbatim, swap key set):
```elixir
test "metadata does not carry :content key", %{test: test_id} do
  attach_trace_handler(test_id, :execution_succeeded)
  attrs_with_content = Map.put(@attrs, :content, "some sensitive content")
  Traces.emit(:execution_succeeded, attrs_with_content)
  assert_receive {:trace_metadata, meta}, 500
  refute Map.has_key?(meta, :content), ":content must never appear in trace metadata (D17-02)"
end
```
**Swap:** test atoms; check additionally for `:rendered_body` and `:refused_reason` exclusion (D-03 outbound-specific).

**Guard-clause no-op test** (analog lines 136–156 — copy verbatim).

**Namespace isolation test** (analog lines 163–188 — copy structure, swap namespace):
```elixir
test "attaching to [:cairnloop, :governance, :proposal_created] does NOT fire when Traces.emit(:proposal_created) is called",
     %{test: test_id} do
  bounded_handler_id = "test-bounded-metrics-#{test_id}"
  :telemetry.attach(bounded_handler_id, [:cairnloop, :governance, :proposal_created], ...)
  on_exit(fn -> :telemetry.detach(bounded_handler_id) end)
  Traces.emit(:proposal_created, @attrs)
  refute_receive {:bounded_metadata, _}, 100,
                 "Traces.emit must NOT fire the bounded-metrics 3-segment event (D17-01)"
end
```
**Swap:** isolation target becomes `[:cairnloop, :outbound, :delivery, :sent]` (4-segment bounded-metrics path) vs `[:cairnloop, :outbound, :trace, :delivery_sent]` (4-segment trace path) — the two namespaces ARE disjoint by `:trace` segment, not by length, so the test phrasing changes slightly per RESEARCH lines 666–680.

---

### Wave 1, Plan 01 — `lib/cairnloop/workers/outbound_worker.ex` (ADD)

**Analog (within-file pattern):** existing `perform/1` 4-arm `case` block at lines 70–93 of `lib/cairnloop/workers/outbound_worker.ex`.

**Insertion target — the existing 4-arm case block** (lines 70–93):
```elixir
def perform(%Oban.Job{args: %{"message_id" => message_id}}) do
  repo = Application.fetch_env!(:cairnloop, :repo)
  message = repo.get!(Message, message_id)
  conversation = Chat.get_conversation!(message.conversation_id)

  case Application.get_env(:cairnloop, :notifier) do
    notifier when is_atom(notifier) and not is_nil(notifier) ->
      case notifier.on_outbound_triggered(message, conversation) do
        :ok ->
          update_message_status(message, "sent")        # arm A — :notifier_ok

        {:ok, _} ->
          update_message_status(message, "sent")        # arm B — :notifier_ok

        error ->
          update_message_status(message, "failed")      # arm C — :notifier_returned_error
          {:error, error}
      end

    _ ->
      update_message_status(message, "sent")            # arm D — :no_notifier_configured
      :ok
  end
end
```

**Auxiliary analog — side-by-side bounded-metrics + Traces emit:** `lib/cairnloop/governance.ex` lines 380–392 (the canonical "Telemetry then Traces" pair in the same lexical scope):
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

**Pattern to apply** (per RESEARCH Pitfall 1 + Code Example 2): introduce a single `emit_delivery/4` private helper that emits BOTH the bounded-metrics event AND the OI trace event, called once per arm. Sample shape (also from RESEARCH lines 736–755):
```elixir
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

**Arm-by-arm enum-only labels (per D-01 / D-02):**
- Arm A (`:ok`) → `emit_delivery(:sent, :notifier_ok, message, args)`
- Arm B (`{:ok, _}`) → `emit_delivery(:sent, :notifier_ok, message, args)`
- Arm C (`error`) → `emit_delivery(:failed, :notifier_returned_error, message, args)`
- Arm D (`_` no notifier) → `emit_delivery(:sent, :no_notifier_configured, message, args)`

**`perform/1` signature note:** the current head is `def perform(%Oban.Job{args: %{"message_id" => message_id}})`. To access `bulk_envelope_id` inside `emit_delivery/4`, change to `def perform(%Oban.Job{args: %{"message_id" => message_id} = args})` — `args` then flows into `emit_delivery/4`. This is purely additive (Phase 25 already documented the args shape — see lines 1–62 moduledoc).

---

### Wave 1, Plan 01 — `lib/cairnloop/outbound.ex` `trigger/2` (ADD OI emit)

**Analog (cross-module):** `lib/cairnloop/governance.ex` lines 380–392 (Telemetry + Traces side-by-side INSIDE the same function scope, AFTER the bounded-metrics emit).

**Insertion target — the existing `trigger/2` body** (lines 71–103):
```elixir
def trigger(conversation_id, opts) do
  template_id = Keyword.fetch!(opts, :template_id)
  _schedule_in = Keyword.get(opts, :schedule_in)
  actor = Keyword.get(opts, :actor)
  auditor = Keyword.get(opts, :auditor, default_auditor())

  telemetry_meta = %{outcome: :triggered}

  Cairnloop.Telemetry.span([:outbound, :triggered], telemetry_meta, fn ->
    multi =
      conversation_id
      |> build_trigger_multi(opts)
      |> auditor.audit(:outbound_trigger, actor, %{
        conversation_id: conversation_id,
        template_id: template_id
      })

    result = repo().transaction(multi)
    {result, telemetry_meta}
  end)
end
```

**Pattern to apply** (per RESEARCH Pattern 2 lines 354–356):
- BEFORE the `Cairnloop.Telemetry.span(...)` block: `Traces.emit(:trigger_started, %{conversation_id: ..., template_id: ..., actor_id: actor, outcome: :triggered})`.
- AFTER the span returns, branching on `result`: `Traces.emit(:trigger_completed, ...)` on `{:ok, _}`, `Traces.emit(:trigger_failed, ...)` on `{:error, _}`.
- Add `alias Cairnloop.Outbound.Telemetry.Traces` to the alias block at line 28 (next to existing `alias Cairnloop.Message` / `alias Cairnloop.Outbound.BulkEnvelope`).

**Do NOT** restructure the sealed `:telemetry.span/3` semantics (CLAUDE.md: seal completed phases). The emits go AROUND the span, not INSIDE it.

---

### Wave 1, Plan 01 — `lib/cairnloop/outbound.ex` `bulk_trigger_submit/6` (ADD OI emit)

**Analog (within-file):** existing `bulk_trigger_submit/6` at `outbound.ex` lines 298–349.

**Insertion target** (lines 325–348 — the existing `Cairnloop.Telemetry.span` block):
```elixir
Cairnloop.Telemetry.span([:outbound, :bulk, :triggered], %{outcome: :submitted, count: count}, fn ->
  multi =
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:envelope, BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs))
    |> Ecto.Multi.merge(fn %{envelope: env} -> ... end)
    |> auditor.audit(:bulk_outbound_trigger, actor, %{
      bulk_envelope_id: envelope_id,
      count: count,
      template_id: template_id
    })

  result = repo().transaction(multi)
  {result, %{outcome: :submitted, count: count}}
end)
```

**Pattern to apply:** AFTER the `repo().transaction(multi)` call (inside the `fn` body) but BEFORE the `{result, ...}` return tuple, emit `Traces.emit(:bulk_submitted, %{bulk_envelope_id: envelope_id, template_id: template_id, actor_id: actor, outcome: :submitted, conversation_id: nil})` — `conversation_id: nil` because the bulk envelope is the unit of work; per-recipient traces fire from `OutboundWorker.perform/1`.

---

### Wave 1, Plan 01 — `lib/cairnloop/outbound.ex` `bulk_trigger_refused/6` (ADD OI emit)

**Analog (within-file, self-analog):** the existing 3-arm `case repo().insert(...)` at `outbound.ex` lines 252–290 — already emits `Cairnloop.Telemetry.execute/3` on each arm with distinct outcomes (`:refused_cap_exceeded` vs `:refused_cap_exceeded_audit_failed`).

**Insertion target — the 3-arm case (lines 252–290):**
```elixir
case repo().insert(BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs)) do
  {:ok, _envelope} ->
    Cairnloop.Telemetry.execute(
      [:outbound, :bulk, :triggered],
      %{count: count},
      %{outcome: :refused_cap_exceeded, count: count}
    )

  {:error, %Ecto.Changeset{} = changeset} ->
    require Logger
    Logger.error("BulkEnvelope refusal insert failed: #{inspect(changeset.errors)}")
    Cairnloop.Telemetry.execute(
      [:outbound, :bulk, :triggered],
      %{count: count},
      %{outcome: :refused_cap_exceeded_audit_failed, count: count}
    )

  other ->
    require Logger
    Logger.error("BulkEnvelope refusal insert returned unexpected shape: #{inspect(other)}")
    Cairnloop.Telemetry.execute(
      [:outbound, :bulk, :triggered],
      %{count: count},
      %{outcome: :refused_cap_exceeded_audit_failed, count: count}
    )
end
```

**Pattern to apply** (per RESEARCH Pitfall 3): on ALL THREE arms, immediately AFTER the existing `Cairnloop.Telemetry.execute/3` call, add:
```elixir
Traces.emit(:bulk_refused, %{
  bulk_envelope_id: envelope_id,
  template_id: template_id,
  actor_id: actor,
  outcome: :refused_cap_exceeded,         # or :refused_cap_exceeded_audit_failed on the two error arms
  conversation_id: nil,
  effective_cap: cap                       # per RESEARCH OQ3: include cap on :bulk_refused only
})
```

---

### Wave 1, Plan 01 — `lib/cairnloop/telemetry.ex` `@moduledoc` (ADD)

**Analog (self-analog):** existing `@moduledoc` sections at `telemetry.ex` lines 8–46.

**Existing structure** (lines 8–18):
```elixir
## Conversation Events

The following events are emitted using `:telemetry.span/3`:

* `[:cairnloop, :conversation, :resolve, :start]`
* `[:cairnloop, :conversation, :resolve, :stop]` - Metadata includes `:business_duration_seconds`
* `[:cairnloop, :conversation, :resolve, :exception]`
...
```

**Pattern to apply:** append a new `## Outbound Events` block after line 45 (before the closing `"""` at line 46). Document BOTH vocabularies — the bounded-metrics events (`[:cairnloop, :outbound, :triggered, :start|:stop|:exception]`, `[:cairnloop, :outbound, :bulk, :triggered, :start|:stop|:exception]`, `[:cairnloop, :outbound, :bulk, :triggered]` point-in-time, `[:cairnloop, :outbound, :delivery, :sent|:failed]`) AND the new OI trace lane (`[:cairnloop, :outbound, :trace, :trigger_started|:trigger_completed|:trigger_failed|:bulk_submitted|:bulk_refused|:delivery_sent|:delivery_failed]`). Cross-reference `Cairnloop.Outbound.Telemetry.Traces`. Cardinality-safe metadata note matches the existing Conversation / Retrieval blocks.

Doc-only — no compile-time pinning test (RESEARCH OQ1 decision: follow existing precedent, no pinning).

---

### Wave 1, Plan 01 — `test/cairnloop/workers/outbound_worker_test.exs` (ADD)

**Analog 1 (telemetry attach):** `test/cairnloop/governance/telemetry/traces_test.exs` lines 23–37 (`attach_trace_handler/2` helper + `on_exit/1` detach).

**Analog 2 (in-file MockRepo + MockNotifier):** `test/cairnloop/workers/outbound_worker_test.exs` self lines 7–58.

**Existing setup** (lines 7–58):
```elixir
defmodule MockRepo do
  def get!(Message, 1) do
    %Message{id: 1, conversation_id: 10, content: "Hello", role: :system_outbound,
             metadata: %{"template_id" => "test", "status" => "pending"}}
  end
  def get!(Conversation, 10), do: %Conversation{id: 10, host_user_id: "user_123"}
  def update(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  def preload(struct, _), do: struct
end

defmodule MockNotifier do
  @behaviour Cairnloop.Notifier
  def on_conversation_resolved(_, _), do: :ok
  def on_sla_breach(_, _, _), do: :ok
  def on_outbound_triggered(message, conversation) do
    send(self(), {:notified, message.id, conversation.id})
    :ok
  end
end

defmodule ErrorNotifier do
  @behaviour Cairnloop.Notifier
  def on_conversation_resolved(_, _), do: :ok
  def on_sla_breach(_, _, _), do: :ok
  def on_outbound_triggered(_, _), do: {:error, :delivery_failed}
end

setup do
  Application.put_env(:cairnloop, :repo, MockRepo)
  Application.put_env(:cairnloop, :notifier, MockNotifier)
  on_exit(fn ->
    Application.delete_env(:cairnloop, :repo)
    Application.delete_env(:cairnloop, :notifier)
  end)
  :ok
end
```

**Pattern to apply:** add a new `describe "delivery telemetry (Phase 26 OBS-01 D-02)"` block. Each test attaches a handler to `[:cairnloop, :outbound, :delivery, :sent]` or `[:cairnloop, :outbound, :delivery, :failed]` (3- → 4-segment) using the `attach_trace_handler`-style helper, runs `OutboundWorker.perform/1`, and asserts on the `reason` enum:
- Test 1: Default `MockNotifier` (returns `:ok`) → `[:cairnloop, :outbound, :delivery, :sent]` fires with `metadata.reason == :notifier_ok`.
- Test 2: New `OkTupleNotifier` (returns `{:ok, _}`) → same event, same reason.
- Test 3: `ErrorNotifier` (returns `{:error, _}`) → `[:cairnloop, :outbound, :delivery, :failed]` fires with `metadata.reason == :notifier_returned_error`.
- Test 4: No notifier configured (`Application.delete_env(:cairnloop, :notifier)`) → `[:cairnloop, :outbound, :delivery, :sent]` fires with `metadata.reason == :no_notifier_configured`.
- Test 5: OI trace lane parity — attach to `[:cairnloop, :outbound, :trace, :delivery_sent]`, run `MockNotifier`, assert `meta["openinference.span.kind"] == "TOOL"` and `meta[:conversation_id] == 10`.

---

### Wave 1, Plan 01 — `test/cairnloop/outbound_test.exs` (ADD OI trace tests)

**Analog (self-analog):** existing telemetry-attach test at `test/cairnloop/outbound_test.exs` lines 149–175.

**Existing pattern** (lines 149–175):
```elixir
test "emits telemetry on trigger with enum-only labels (WR-04 / D-B)" do
  :telemetry.attach(
    "test-outbound-handler",
    [:cairnloop, :outbound, :triggered, :stop],
    fn _event, measurements, metadata, _config ->
      send(self(), {:telemetry_event, measurements, metadata})
    end,
    nil
  )

  Outbound.trigger(1, template_id: "test", actor: "operator_42")

  assert_receive {:telemetry_event, measurements, metadata}
  assert Map.has_key?(measurements, :duration)
  assert metadata.outcome == :triggered
  refute Map.has_key?(metadata, :conversation_id)
  ...
  :telemetry.detach("test-outbound-handler")
end
```

**Pattern to apply:** add tests in a new `describe "OI trace lane (Phase 26 D-03)"` block. Each test attaches to `[:cairnloop, :outbound, :trace, <atom>]` and asserts the metadata carries the attribution refs AND the OI `"openinference.span.kind"` key:
- `trigger/2` happy path → `:trigger_started` then `:trigger_completed`, both GUARDRAIL.
- `trigger/2` failure path (force MockRepo failure via `Process.put(:mock_repo_force_insert_failure, ...)`) → `:trigger_failed`, GUARDRAIL.
- `bulk_trigger/2` submit path → `:bulk_submitted`, GUARDRAIL.
- `bulk_trigger/2` refused path (3 arms — use `Process.put(:mock_repo_force_insert_failure, ...)` for two of them) → `:bulk_refused` fires on all three arms.

Use the per-test handler-id pattern from `traces_test.exs:24` (`"outbound-trace-#{test_id}-#{event_atom}"`) — `%{test: test_id} = context` — to avoid the process-global pollution called out in RESEARCH Pitfall 2.

---

### Wave 2, Plan 01 — `lib/cairnloop/governance.ex` (ADD 2 facade reads)

**Analog (within-file, self-analog):** `lib/cairnloop/governance.ex` lines 1021–1072 — the existing `list_eligible_conversation_ids_for_bulk_recovery/1` + `preview_bulk_recovery_cohort/1` pair.

**Existing pattern** (lines 1021–1027 — the canonical narrow-facade read):
```elixir
def list_eligible_conversation_ids_for_bulk_recovery(candidate_ids)
    when is_list(candidate_ids) do
  Conversation
  |> where([c], c.id in ^candidate_ids and c.status == :resolved)
  |> select([c], c.id)
  |> repo().all()
end
```

**Existing `@doc` style** (lines 1005–1019):
```elixir
@doc """
Returns the subset of `candidate_ids` whose conversations are currently eligible
to be targets of a bulk recovery follow-up.

v1 eligibility is `status == :resolved` (D-01). The caller MUST pre-filter ...

Reads through the narrow facade per D-14: the web layer (InboxLive) is forbidden
from running a direct `Cairnloop.Conversation` query. Goes through `repo().all/1`
— never `Cairnloop.Repo` directly.
"""
```

**Alias block insertion target** (lines 62–75):
```elixir
alias Cairnloop.Governance.{Policy, Preview, Telemetry, ToolActionEvent, ToolApproval, ToolProposal}
alias Cairnloop.Governance.Telemetry.Traces
alias Cairnloop.Workers.{ApprovalExpiryWorker, ApprovalResumeWorker, ToolExecutionWorker}

# Phase 25 plan 01 (D-14): cohort-eligibility reads target the Conversation schema.
alias Cairnloop.Conversation
```
**Add:** `alias Cairnloop.Outbound.BulkEnvelope` (the schema is at `lib/cairnloop/outbound/bulk_envelope.ex` — `binary_id` PK per RESEARCH Pitfall 4).

**Pattern to apply** — append AFTER `preview_bulk_recovery_cohort/1` (after line 1081). Two functions following the same `@doc` + `repo().all/1` shape:

1. `list_recent_bulk_outbound_envelopes(opts \\ [])` — default limit 50, hard cap 500 (`ArgumentError` on `:limit > 500`), `:status` filter (`:submitted | :refused_cap_exceeded | :all`), `order_by desc: e.requested_at`. Use `BulkEnvelope` schema in the `from`. RESEARCH Pattern 3 lines 397–428 provides the exact body.

2. `get_bulk_outbound_envelope(id)` — `repo().get(BulkEnvelope, id)`. Returns `nil` on miss (Ecto's default — do NOT use `get!`). Document `id` is a binary UUID string per RESEARCH Pitfall 4.

Module-attribute constants for the limits (mirrors the existing pattern of inline numeric defaults — see `approval_ttl_seconds/0` at line 89):
```elixir
@bulk_envelope_default_limit 50
@bulk_envelope_hard_cap 500
```

---

### Wave 2, Plan 01 — `test/cairnloop/governance_test.exs` (ADD facade tests)

**Analog (within-file, self-analog):** `test/cairnloop/governance_test.exs` lines 13–96 — existing `MockRepo` with `all/1` dispatch on `query.from.source`.

**Existing dispatch pattern** (lines 64–96):
```elixir
def all(%Ecto.Query{from: %{source: {"cairnloop_conversations", _}}} = query) do
  candidate_ids = extract_candidate_ids(query)
  rows =
    Process.get(:conversations, [])
    |> Enum.filter(fn c -> c.id in candidate_ids and c.status == :resolved end)
    |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
  ...
end

def all(%Ecto.Query{} = query) do
  # ToolProposal branch — pre-existing
  ...
end
```

**Pattern to apply:** add a new `from.source` dispatch arm for the bulk envelope table:
```elixir
def all(%Ecto.Query{from: %{source: {"cairnloop_outbound_bulk_envelopes", _}}} = query) do
  rows = Process.get(:bulk_envelopes, [])
  # Apply :status filter from query.wheres if present
  # Apply order_by desc: :requested_at
  # Apply limit from query.limit
  ...
end
```
Also add a `get/2` branch for `BulkEnvelope`:
```elixir
def get(Cairnloop.Outbound.BulkEnvelope, id) do
  Process.get(:bulk_envelopes, []) |> Enum.find(fn e -> e.id == id end)
end
```

**Tests to add** (cover the D-06 contract — RESEARCH "Phase Requirements → Test Map" lines 893–895):
- Default limit returns at most 50.
- `:limit > 500` raises `ArgumentError`.
- `:status: :submitted` filters; `:status: :refused_cap_exceeded` filters; `:status: :all` returns both.
- Order is `requested_at desc`.
- `get_bulk_outbound_envelope("missing-uuid")` returns `nil`, does NOT raise.
- `get_bulk_outbound_envelope(env.id)` returns the matching row.

---

### Wave 2, Plan 01 — `test/cairnloop/outbound_test.exs` (ADD auditor-shape regression)

**Analog (within-file, self-analog):** existing `TestAuditor` pattern at `test/cairnloop/outbound_test.exs` lines 177–191.

**Existing pattern** (lines 177–191):
```elixir
test "integrates with auditor" do
  defmodule TestAuditor do
    @behaviour Cairnloop.Auditor
    def audit(multi, action, actor, metadata) do
      Ecto.Multi.run(multi, :audit, fn _repo, _changes ->
        {:ok, %{action: action, actor: actor, metadata: metadata}}
      end)
    end
  end

  assert {:ok, results} = Outbound.trigger(1, template_id: "test", actor: "system", auditor: TestAuditor)
  assert results.audit.action == :outbound_trigger
  assert results.audit.actor == "system"
  assert results.audit.metadata == %{conversation_id: 1, template_id: "test"}
end
```

**Pattern to apply** (D-05 regression — RESEARCH Test Map lines 891–892): add two `describe "auditor metadata shape regression (D-05)"` tests:
- `trigger/2` calls `auditor.audit(:outbound_trigger, actor, %{conversation_id: ..., template_id: ...})` — **exact** metadata shape, no extra keys.
- `bulk_trigger/2` submit path calls `auditor.audit(:bulk_outbound_trigger, actor, %{bulk_envelope_id: ..., count: ..., template_id: ...})` — exact metadata shape.

Use a `MapShapeAuditor` (similar to `TestAuditor` above) that captures the metadata and asserts on exact key set via `assert Map.keys(results.audit.metadata) |> Enum.sort() == [:bulk_envelope_id, :count, :template_id]` (no `:rendered_body`, no `:recipient_conversation_ids`, etc.).

---

### Wave 3, Plan 01 — `lib/cairnloop/web/inbox_live.ex` (ADD empty state + modal close `×`)

**Analog (within-file, self-analog):** existing render tree at `lib/cairnloop/web/inbox_live.ex` lines 113–290.

**Insertion target 1 — empty state (between line 116 and 118):**
```elixir
def render(assigns) do
  ~H"""
  <div class="cairnloop-inbox">
    <h1>Inbox</h1>

    <%= if has_visible_eligible?(@conversations) do %>
      <div class="cairnloop-inbox-bulk-header" ...>...</div>
    <% end %>

    <ul>...</ul>
```

**Pattern to apply** (D-08, RESEARCH Example 4):
```elixir
<h1>Inbox</h1>

<%= if @conversations == [] do %>
  <%!-- Phase 26 D-08: empty inbox state. Calm, reason-forward, brand-aligned. --%>
  <p
    class="inbox-empty-state"
    style="margin-top: 12px; font-size: 14px; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));"
  >
    No conversations yet.
  </p>
<% end %>
```
Place AFTER `<h1>Inbox</h1>` (line 116) and BEFORE the existing `<%= if has_visible_eligible?(@conversations) do %>` block (line 118). DO NOT touch `has_visible_eligible?/1` — it's a regression-gate only (D-08 sub-bullet 2).

**Insertion target 2 — modal close `×` button** inside `<div class="bulk-confirm-dialog">` (lines 188–191 — currently):
```elixir
<div
  class="bulk-confirm-dialog"
  style="background: var(--cl-surface, #FBF7EE); color: var(--cl-text, #2f241d); border-radius: 18px; width: min(640px, 92vw); max-height: 78vh; box-shadow: 0 24px 60px var(--cl-shadow, rgba(47, 36, 29, 0.18)); overflow: hidden; display: flex; flex-direction: column; padding: 24px;"
>
  <%= if @bulk_refusal do %>
    ...
```

**Pattern to apply** (D-08 + RESEARCH Pitfall 6 + Example 4): mutate the dialog `style` to include `position: relative;` so the absolute-positioned button anchors correctly; then insert as the FIRST child of the dialog div:
```elixir
<div
  class="bulk-confirm-dialog"
  style="position: relative; background: var(--cl-surface, #FBF7EE); color: var(--cl-text, #2f241d); border-radius: 18px; ..."
>
  <%!-- Phase 26 D-08: visible close affordance. Escape already works via phx-window-keydown. --%>
  <button
    type="button"
    phx-click="cancel_bulk_confirm"
    aria-label="Close"
    style="position: absolute; top: 12px; right: 12px; min-width: 44px; min-height: 44px; border: none; background: transparent; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62)); font-size: 24px; line-height: 1; cursor: pointer; padding: 0;"
  >
    ×
  </button>

  <%= if @bulk_refusal do %>
    ...
```
Reuses the existing `cancel_bulk_confirm` event handler — NO new event handler is added.

---

### Wave 3, Plan 01 — `lib/cairnloop/web/conversation_live.ex` (ADD failed-bubble subhead)

**Analog (within-file, self-analog):** existing message-card render at `lib/cairnloop/web/conversation_live.ex` lines 767–778, plus `outbound_status_label/1` definition at lines 993–1003.

**Insertion target** (lines 767–778 — existing chip render):
```elixir
<%= for msg <- @conversation.messages do %>
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
  </div>
<% end %>
```

**Pattern to apply** (D-09, RESEARCH Example 3 + Pitfall 7 — chip MUST stay untouched):
```elixir
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
  <%!-- Phase 26 D-09: calm reason-forward subhead on :failed delivery only. Additive — chip stays as-is. --%>
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

The `outbound_recovery_card/1` (lines 825–847) already has `<section ... aria-label="Outbound recovery">` — D-09 sub-bullet 1 is a verification-only gate; no behavior change.

---

### Wave 3, Plan 01 — `test/cairnloop/web/inbox_live_test.exs` (ADD polish tests)

**Analog (within-file, self-analog):** existing `render_html/1` + `build_assigns/1` helpers at lines 614–642.

**Existing helper pattern** (lines 614–628):
```elixir
defp render_html(assigns) do
  assigns =
    assigns
    |> Map.put_new(:selected_ids, MapSet.new())
    |> Map.put_new(:bulk_modal_open, false)
    |> Map.put_new(:bulk_preview, nil)
    |> Map.put_new(:bulk_refusal, nil)
    |> Map.put_new(:host_user_id, nil)
    |> Map.put_new(:conversations, [])
    |> Map.put_new(:flash, %{})

  render_component(&InboxLive.render/1, assigns)
end
```

**Pattern to apply** (RESEARCH Test Map lines 897–899): add a new `describe "Phase 26 D-08 polish"` block with three tests:
1. Empty inbox state — `build_assigns(conversations: [])` → assert `html =~ "No conversations yet."` AND `refute html =~ "cairnloop-inbox-bulk-header"`.
2. Modal close button — `build_assigns(bulk_modal_open: true, bulk_preview: %{count: 1, sample: [], more: 0, rendered_body: "Body"})` → assert `html =~ ~s(aria-label="Close")` AND `html =~ "phx-click=\"cancel_bulk_confirm\""` (button context — there are now TWO `cancel_bulk_confirm` references: the existing Cancel button and the new × — both must remain). Also assert dialog style includes `position: relative`.
3. has_visible_eligible regression — `build_assigns(conversations: [%Conversation{id: 1, status: :open}])` → `refute html =~ "cairnloop-inbox-bulk-header"`.

---

### Wave 3, Plan 01 — `test/cairnloop/web/conversation_live_test.exs` (ADD subhead test)

**Analog (within-file, self-analog):** existing `system_outbound` chip render test at `test/cairnloop/web/conversation_live_test.exs` lines 629–659.

**Existing pattern** (lines 629–659):
```elixir
assigns = %{
  conversation: %Cairnloop.Conversation{
    id: 1, status: :resolved, subject: "Test",
    messages: [
      %Cairnloop.Message{
        id: 10, role: :system_outbound,
        content: "We wanted to confirm the fix stuck.",
        metadata: %{"template_id" => "recovery_v1", "status" => "sent"}
      }
    ],
    drafts: [], host_user_id: "user_42"
  },
  host_context: %{}, context_error: nil,
  form: Phoenix.Component.to_form(%{"content" => ""}),
  pending_discard_draft_id: nil, socket: %Phoenix.LiveView.Socket{}
}

html = render_html(assigns)

assert html =~ "Outbound recovery"
assert html =~ "We wanted to confirm the fix stuck."
assert html =~ "message-status-chip status-sent"
assert html =~ "Sent"
```

**`render_html/1` helper** (lines 1461–1463):
```elixir
defp render_html(assigns) do
  render_component(&ConversationLive.render/1, assigns)
end
```

**Pattern to apply** (RESEARCH Test Map lines 900–901): add a new `describe "Phase 26 D-09 failed-bubble subhead"` block:
1. Failed → renders subhead — copy the existing assigns shape, change `"status" => "failed"`, assert BOTH `html =~ "message-status-chip status-failed"` AND `html =~ "Delivery did not complete. Try again from the Outbound recovery card."` (Pitfall 7: chip class MUST still appear).
2. Sent → does NOT render subhead — change `"status" => "sent"`, assert `refute html =~ "Delivery did not complete"`.
3. Pending → does NOT render subhead.
4. `outbound_recovery_card/1` a11y — assert `html =~ ~s(aria-label="Outbound recovery")` (verification-gate only, no behavior change).

---

## Shared Patterns

### Telemetry Attach + Detach (process-global API)

**Source:** `test/cairnloop/governance/telemetry/traces_test.exs` lines 23–37
**Apply to:** every Phase 26 test that asserts on telemetry emit (`traces_test.exs`, `outbound_worker_test.exs`, `outbound_test.exs`)

```elixir
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
```
Always paired with `%{test: test_id} = context` from ExUnit to keep handler IDs unique (Pitfall 2 — process-global).

### `repo()` indirection for narrow facade

**Source:** `lib/cairnloop/outbound.ex` lines 31–33 / `lib/cairnloop/governance.ex` lines 81–83
**Apply to:** Wave 2 facade reads in `governance.ex`

```elixir
defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end
```
Goes through `repo().all/1` / `repo().get/2` — never `Cairnloop.Repo` directly (D-14).

### MockRepo dispatch-by-from-source

**Source:** `test/cairnloop/governance_test.exs` lines 64–96
**Apply to:** Wave 2 `governance_test.exs` envelope facade tests

The existing MockRepo dispatches `all/1` on `query.from.source`. Add a new arm for `{"cairnloop_outbound_bulk_envelopes", _}` and a `get/2` branch for `Cairnloop.Outbound.BulkEnvelope`. Seed via `Process.put(:bulk_envelopes, [...])` and clean up in `on_exit`. The pattern is REPO-UNAVAILABLE-safe (no Postgres needed — Pitfall 8).

### `# REPO-UNAVAILABLE` integration tag

**Source:** `test/cairnloop/workers/outbound_worker_test.exs` lines 133–154 — the canonical `@tag :integration` block with the `# REPO-UNAVAILABLE` comment.
**Apply to:** Wave 2 envelope-facade tests that genuinely need a real Postgres round-trip (e.g. "facade returns rows after a real `bulk_trigger/2` submit + refused"). Headless suite covers the function-shape contract; integration suite covers the live-DB roundtrip.

```elixir
@tag :integration
# REPO-UNAVAILABLE
test "facade reads return real envelope rows after bulk_trigger/2 persisted submit + refused lanes" do
  flunk("integration-only: requires Cairnloop.Repo + cairnloop_outbound_bulk_envelopes table")
end
```

### Brand-token inline styles

**Source:** `lib/cairnloop/web/inbox_live.ex` line 126, 156, 169, 199; CLAUDE.md "brand tokens over hardcoded hex"
**Apply to:** Wave 3 polish edits in `inbox_live.ex` + `conversation_live.ex`

Every new inline style MUST use `var(--cl-<token>, <hex-fallback>)`. The fallback hex is required so headless tests can assert against the brand vocabulary in rendered HTML. Examples:
- Muted text: `color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));`
- Surface raised: `background: var(--cl-surface-raised, #FFFFFF);`
- Border: `border-color: var(--cl-border, #D8D0BF);`

### "Telemetry then Traces" emit pattern

**Source:** `lib/cairnloop/governance.ex` lines 380–392 (canonical) + 946–952
**Apply to:** every Phase 26 call site that adds an OI trace alongside an existing bounded-metrics emit (`OutboundWorker.perform/1`, `Outbound.trigger/2`, `Outbound.bulk_trigger_submit/6`, `Outbound.bulk_trigger_refused/6`)

```elixir
# Bounded-metrics first (sealed, untouched)
Cairnloop.Telemetry.execute([...], measurements, metadata)

# OI trace event — additive, fire-and-forget, after bounded-metrics (Phase 26 D-03)
Cairnloop.Outbound.Telemetry.Traces.emit(event_atom, attrs)
```

### Calm operator copy register

**Source:** CLAUDE.md "Architecture posture" + `prompts/cairnloop_brand_book.md` §7.5
**Apply to:** Wave 3 polish copy (empty-state, failed-subhead, close button)

- No emoji, no exclamation marks.
- Reason-forward (state WHY, not WHAT).
- Never state-by-color-alone — always pair color with text or icon (failed-subhead pairs with `.status-failed` chip class + "Failed" text + reason-forward sentence; refusal banner already pairs danger token with SVG icon + text).
- Modal close button is plain `×` (U+00D7) — no custom SVG, no icon library.

---

## No Analog Found

None. Every Phase 26 file has a closest in-tree analog (either Phase 17 `governance/telemetry/traces.ex` family, the self-analog within `outbound.ex` / `governance.ex` / `inbox_live.ex` / `conversation_live.ex`, or the existing `outbound_worker_test.exs` mock-substrate). Phase 26 is a closeout phase on a substrate that's 95% built — patterns reuse is the dominant move.

---

## Metadata

**Analog search scope:**
- `lib/cairnloop/governance/telemetry/` (Phase 17 OI traces precedent)
- `lib/cairnloop/outbound{,_worker,/bulk_envelope}.ex` (sealed write substrate)
- `lib/cairnloop/governance.ex` lines 380–392, 946–952, 1021–1082 (facade reads + Traces.emit call shape)
- `lib/cairnloop/telemetry.ex` (centralizer moduledoc)
- `lib/cairnloop/web/{inbox,conversation}_live.ex` (LiveView polish targets)
- `test/cairnloop/{governance,governance/telemetry,outbound,workers,web}/...` (mock-substrate + render_html patterns)

**Files scanned:** 14 source files, 6 test files — every cited line range was read end-to-end (≤ 2000 lines) or via targeted offset/limit (governance.ex, conversation_live.ex).

**Pattern extraction date:** 2026-05-27
