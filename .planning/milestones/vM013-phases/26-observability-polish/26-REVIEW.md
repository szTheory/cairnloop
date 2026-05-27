---
phase: 26-observability-polish
reviewed: 2026-05-27T18:30:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/cairnloop/governance.ex
  - lib/cairnloop/outbound.ex
  - lib/cairnloop/outbound/telemetry/traces.ex
  - lib/cairnloop/telemetry.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/workers/outbound_worker.ex
  - test/cairnloop/governance_test.exs
  - test/cairnloop/outbound/telemetry/traces_test.exs
  - test/cairnloop/outbound_test.exs
  - test/cairnloop/web/conversation_live_test.exs
  - test/cairnloop/web/inbox_live_test.exs
  - test/cairnloop/workers/outbound_worker_test.exs
findings:
  critical: 0
  warning: 7
  info: 4
  total: 11
status: issues_found
---

# Phase 26: Code Review Report

**Reviewed:** 2026-05-27T18:30:00Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 26 delivers the OBS-01 OpenInference trace lane, OBS-02 audit READ facade, and
the final UI polish on `InboxLive` + `ConversationLive`. The substrate work is
architecturally sound — the OI Traces module mirrors the Phase 17 Governance lane
verbatim, the bulk-envelope reads go through the narrow `Cairnloop.Governance`
facade per D-14, the auditor metadata regression block is well-scoped, and the
template-only polish work touches no event handlers or assigns.

The review uncovered **no critical blockers** but did surface **seven warnings**
that affect observability fidelity, robustness, and test-gate trustworthiness.
The most consequential is that the bulk-trigger submit lane fires
`Traces.emit(:bulk_submitted, outcome: :submitted)` and reports
`outcome: :submitted` on the bounded-metrics `:stop` event UNCONDITIONALLY — even
when `repo().transaction(multi)` fails. The OI lane and the metrics aggregator
will both report "submitted" when the transaction actually failed. Compare with
the symmetric `trigger/2` lane that correctly branches on `span_result`. There is
also no `:bulk_failed` atom in the `@events` whitelist, so bulk transaction
failures are entirely opaque on the OI lane. This contradicts the
"telemetry is observability" posture: an observability lane that under-reports
failures is worse than no lane at all.

Two related warnings (W-02 and W-03) extend the same pattern: both the
`bulk_trigger_submit/6` and `trigger/2` bounded-metrics `:stop` metadata always
report success regardless of the transaction result. This is pre-existing from
Phase 22/25 but is now flagrant because the OI lane (which Phase 26 just added)
correctly distinguishes `:trigger_completed` from `:trigger_failed` — the two
lanes will disagree.

A fourth telemetry-semantics warning (W-04) is the OutboundWorker
`:no_notifier_configured` arm reporting `outcome: :sent` when no message was
actually delivered.

The remaining warnings cover a circumventable D-14 grep gate, an empty-body
edge case in the bulk-recovery renderer, missing assigns in a test fixture,
and a double-invocation render smell. None are blockers; all are addressable
without re-opening sealed contracts.

## Structural Findings (fallow)

_No `<structural_findings>` block was provided for this review; no fallow items
to list._

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: `bulk_trigger_submit/6` emits OI `:bulk_submitted` trace unconditionally — even when transaction fails

**File:** `lib/cairnloop/outbound.ex:405-419`
**Issue:** After `result = repo().transaction(multi)` the code unconditionally
calls `Traces.emit(:bulk_submitted, %{… outcome: :submitted})` regardless of
`result`. When the transaction returns `{:error, failed_op, value, changes}`
(Ecto.Multi failure on a per-recipient `Message` insert, FK violation, auditor
step failure, etc.), the OI trace lane still emits a successful "bulk_submitted"
event. The OI consumer (Scoria, Phoenix.Tracer, OpenTelemetry exporter) sees a
GUARDRAIL span declaring submission succeeded when it actually failed.

Compare with `trigger/2` (`lib/cairnloop/outbound.ex:120-131`) which correctly
branches on `span_result` and emits `:trigger_completed` vs `:trigger_failed`.
The `bulk_trigger_submit/6` lane has no such branching, and the
`Cairnloop.Outbound.Telemetry.Traces.@events` enum has no `:bulk_failed` atom,
so even an attempted fix would require an enum extension.

This violates CLAUDE.md "telemetry is observability only" — observability that
lies about workflow outcomes is anti-observability. It also breaks D-03's
"OI consumers can reconstruct the span tree" promise: a host whose bulk
transaction failed will see a successful `:bulk_submitted` and no failure
indicator on the OI lane.

**Fix:**

```elixir
# Add :bulk_failed to traces.ex @events whitelist:
@events [
  :trigger_started, :trigger_completed, :trigger_failed,
  :bulk_submitted, :bulk_failed, :bulk_refused,
  :delivery_sent, :delivery_failed
]

# Then in bulk_trigger_submit/6:
result = repo().transaction(multi)

case result do
  {:ok, _changes} ->
    Traces.emit(:bulk_submitted, %{
      bulk_envelope_id: envelope_id,
      template_id: template_id,
      actor_id: actor,
      outcome: :submitted,
      conversation_id: nil
    })

  _failure ->
    Traces.emit(:bulk_failed, %{
      bulk_envelope_id: envelope_id,
      template_id: template_id,
      actor_id: actor,
      outcome: :failed,
      conversation_id: nil
    })
end

{result, %{outcome: telemetry_outcome_for(result), count: count}}
```

### WR-02: `bulk_trigger_submit/6` bounded-metrics `:stop` reports `outcome: :submitted` regardless of transaction result

**File:** `lib/cairnloop/outbound.ex:419`
**Issue:** Line 419 returns `{result, %{outcome: :submitted, count: count}}` as
the span's metadata override. The `:telemetry.span/3` machinery merges this
into the `:stop` event metadata. When `result` is `{:error, _, _, _}` (Ecto.Multi
failure), Prometheus / StatsD / Datadog handlers attached to
`[:cairnloop, :outbound, :bulk, :triggered, :stop]` will count the failed
transaction as a successful submit. This silently inflates the success rate
that operators rely on for SLOs and alerting.

**Fix:** Derive the outcome from `result`:

```elixir
result = repo().transaction(multi)

stop_outcome =
  case result do
    {:ok, _} -> :submitted
    _ -> :failed
  end

# Trace lane (see WR-01) ...

{result, %{outcome: stop_outcome, count: count}}
```

### WR-03: `trigger/2` bounded-metrics `:stop` reports `outcome: :triggered` regardless of transaction result

**File:** `lib/cairnloop/outbound.ex:90, 117`
**Issue:** `telemetry_meta = %{outcome: :triggered}` (line 90) is the same map
returned on line 117 as the span's metadata override. When the wrapped function
returns `{:error, name, value, changes}` (the Ecto.Multi 4-tuple failure shape),
the bounded-metrics `[:cairnloop, :outbound, :triggered, :stop]` event still
reports `outcome: :triggered`. The OI lane (added in this phase) correctly
distinguishes `:trigger_completed` from `:trigger_failed`, so the two lanes
will now actively disagree on the outcome of the same operation.

This is pre-existing from Phase 22, but Phase 26's addition of the OI lane
elevates the visibility of the inconsistency. Hosts that attach to both lanes
will see contradictory observability.

**Fix:** Same pattern as WR-02 — derive the `:stop` metadata outcome from
`span_result`:

```elixir
span_result =
  Cairnloop.Telemetry.span([:outbound, :triggered], telemetry_meta, fn ->
    multi = ...
    result = repo().transaction(multi)
    outcome =
      case result do
        {:ok, _} -> :triggered
        _ -> :failed
      end
    {result, %{outcome: outcome}}
  end)
```

### WR-04: `OutboundWorker` reports `outcome: :sent` when no notifier is configured

**File:** `lib/cairnloop/workers/outbound_worker.ex:95-98`
**Issue:** The `_` arm of the notifier case handles "no notifier configured"
by setting message status to `"sent"` and emitting
`emit_delivery(:sent, :no_notifier_configured, message, args)`. The bounded-
metrics event reports `outcome: :sent`. Operators looking at success counts
on `[:cairnloop, :outbound, :delivery, :sent]` will see this as a successful
delivery, but no message was actually delivered — the system has no notifier
to deliver it through. The `:reason` field differentiates, but a typical
Prometheus dashboard aggregates by `outcome` only.

The same false-success appears on the OI lane (`:delivery_sent` TOOL span)
with `outcome: :sent` — an OI consumer sees a successful execution span where
none happened.

**Fix:** Introduce a distinct outcome for the no-notifier case:

```elixir
_ ->
  update_message_status(message, "sent")  # or reconsider this status too
  emit_delivery(:no_op, :no_notifier_configured, message, args)
  :ok

# And extend emit_delivery's guard:
defp emit_delivery(outcome, reason, message, args)
     when outcome in [:sent, :failed, :no_op] do
  ...
end
```

Alternatively, treat the no-notifier case as a configuration error and
either log-and-skip or refuse the perform/1 entirely (more drastic; weigh
against backward compat).

### WR-05: D-14 narrow-facade test is trivially circumventable

**File:** `test/cairnloop/web/inbox_live_test.exs:766-769`
**Issue:** The "no `Conversation |> where` substring" assertion only catches
the exact pipe syntax `Conversation |> where`. A regression that uses any of
these equivalent forms would silently bypass the gate:

- `from(c in Conversation, where: ...)`
- `Conversation\n|> where(...)` (newline between)
- `query = Conversation; query |> where(...)`
- `Cairnloop.Conversation |> where(...)` (fully qualified)
- `import Ecto.Query; Conversation |> where(...)` on separate lines

The test gives false confidence about D-14 enforcement. The D-14 mitigation
matters because the web layer running its own Ecto query against
`cairnloop_conversations` (or `cairnloop_outbound_bulk_envelopes`, now that
the facade exists) is exactly what the narrow-facade posture is designed to
prevent.

**Fix:** Replace the substring grep with a broader AST or multi-pattern grep:

```elixir
test "no Ecto query construction against Conversation/BulkEnvelope from web layer" do
  source = File.read!("lib/cairnloop/web/inbox_live.ex")
  # Catch all common Ecto query construction forms.
  refute source =~ ~r/(?:Conversation|BulkEnvelope|cairnloop_(?:conversations|outbound_bulk_envelopes))/
  refute source =~ "from("
  refute source =~ "where("
  refute source =~ "Ecto.Query"
end
```

Or — preferable for this codebase — assert that the file has no `import
Ecto.Query` and no `alias Cairnloop.Conversation` / `Cairnloop.Outbound.BulkEnvelope`.

### WR-06: `render_bulk_body/1` silently returns empty string for non-binary template_id

**File:** `lib/cairnloop/web/inbox_live.ex:558-562`
**Issue:** `render_bulk_body/1` has two clauses:

```elixir
defp render_bulk_body(template_id) when is_binary(template_id) do
  "Outbound message using template: #{template_id}"
end

defp render_bulk_body(_), do: ""
```

If `:cairnloop, :outbound_recovery_template_id` is misconfigured to a non-binary
value (atom, integer, nil with `Application.get_env` returning nil), the bulk
rendered body becomes `""`. The `confirm_bulk_send/2` cond at line 412 only
checks `is_nil(recovery_follow_up_template_id())` — an atom-valued template_id
would pass the nil check and the operator would confirm a bulk send with an
empty body to N conversations.

The snapshot mechanism (W-06 in Phase 25 / WR-06 in this LiveView) makes this
worse: the empty body lands on the `BulkEnvelope.rendered_body` column as a
durable record of "we sent an empty message to N customers."

**Fix:** Validate template_id type at the open-modal boundary:

```elixir
def handle_event("open_bulk_confirm", _params, socket) do
  ids = socket.assigns.selected_ids |> MapSet.to_list() |> Enum.sort()
  cap = max_batch_size()
  count = length(ids)
  template_id = recovery_follow_up_template_id()

  cond do
    count > cap ->
      # ... existing refusal branch ...

    not is_binary(template_id) ->
      {:noreply,
       socket
       |> put_flash(:error, "Recovery follow-up template is not configured.")
       |> assign(:bulk_modal_open, false)}

    true ->
      # ... existing happy path ...
  end
end
```

### WR-07: `failed_bubble_assigns/1` fixture omits `quick_fix_card` and `governed_actions` required by render

**File:** `test/cairnloop/web/conversation_live_test.exs:1988-2011`
**Issue:** `ConversationLive.render/1` references `@quick_fix_card` (line 802
of `conversation_live.ex`) and `@governed_actions` (lines 818-823) — both are
populated by `reload_conversation_with_context/2`. The Phase 26 fixture
`failed_bubble_assigns/1` does not seed either assign. Tests pass today
because Phoenix tolerates unbound assigns by yielding `nil`, but this creates
a fragile test scaffold:

- If `quick_fix_card/1` ever pattern-matches on a non-nil card map, the failed-
  bubble tests crash for an unrelated reason.
- If `<%= for proposal <- @governed_actions do %>` is reached without the
  `[] / nil` guard at line 818 being satisfied, the for-loop raises `Protocol.UndefinedError`.

Tests that depend on accidental Phoenix leniency are tomorrow's debugging-by-
flashlight problem.

**Fix:** Reuse the existing `quick_fix_socket/1` fixture pattern or extend
`failed_bubble_assigns/1`:

```elixir
defp failed_bubble_assigns(status) do
  %{
    conversation: %Cairnloop.Conversation{...},
    host_context: %{},
    context_error: nil,
    form: Phoenix.Component.to_form(%{"content" => ""}),
    pending_discard_draft_id: nil,
    socket: %Phoenix.LiveView.Socket{},
    # Add the required assigns explicitly:
    quick_fix_card: %{status: :idle, summary: "", layers: [], reason: nil,
                     primary_action: %{event: "noop", label: ""},
                     secondary_action: nil, status_rail: []},
    governed_actions: []
  }
end
```

## Info

### IN-01: `outbound_status_label/1` called twice per `:system_outbound` message in render

**File:** `lib/cairnloop/web/conversation_live.ex:771, 779`
**Issue:** Line 771 binds `outbound_status = outbound_status_label(msg)` inside
the chip-render `if`. Line 779 makes a SECOND call to `outbound_status_label(msg)`
to gate the subhead. Because the line 771 binding is scoped to its own `if`
block, the line 779 call cannot reuse it. Negligible performance cost, but
a maintainability smell — if the helper ever becomes non-pure or expensive,
the duplicate cost doubles silently. A `case` or hoisted `let` would be cleaner.

**Fix:** Hoist the call once per message:

```elixir
<%= for msg <- @conversation.messages do %>
  <% outbound_status = outbound_status_label(msg) %>
  <div class={["message-card", "role-#{msg.role}"]}>
    <div class="message-card-header">
      <span class="message-role-label"><%= message_role_label(msg.role) %></span>
      <%= if outbound_status do %>
        <span class={["message-status-chip", outbound_status_class(msg)]}>
          <%= outbound_status %>
        </span>
      <% end %>
    </div>
    <p class="message-content"><%= msg.content %></p>
    <%= if outbound_status == "Failed" do %>
      <p class="outbound-failed-subhead" style="...">
        Delivery did not complete. Try again from the Outbound recovery card.
      </p>
    <% end %>
  </div>
<% end %>
```

### IN-02: `bulk_trigger/2` docstring under-documents telemetry outcomes

**File:** `lib/cairnloop/outbound.ex:228-233`
**Issue:** The docstring lists outcomes as `:submitted | :refused_cap_exceeded`,
but the implementation actually emits `:refused_cap_exceeded_audit_failed` from
both `:bulk_refused` arms B and C (lines 322-323, 343). The `Cairnloop.Telemetry`
moduledoc at lines 62-64 correctly enumerates all three outcomes; the inline
`bulk_trigger/2` docstring is incomplete.

**Fix:** Update the docstring:

```elixir
## Telemetry (D-B enum-only labels)

`[:cairnloop, :outbound, :bulk, :triggered]` is emitted with metadata
containing ONLY `outcome :: :submitted | :refused_cap_exceeded |
:refused_cap_exceeded_audit_failed` and `count`. ...
```

### IN-03: `Cairnloop.Outbound.Telemetry.Traces` lacks `@spec` declarations

**File:** `lib/cairnloop/outbound/telemetry/traces.ex` (entire module)
**Issue:** The public `emit/2` function (lines 109-118) has no `@spec`. This is
infrastructure that hosts will attach to and (per the moduledoc) integrate
with Scoria, Phoenix.Tracer, and OpenTelemetry exporters. Type specs would
both document the contract and let host code use Dialyzer to catch shape
mismatches at the integration boundary.

**Fix:**

```elixir
@type event ::
        :trigger_started | :trigger_completed | :trigger_failed
        | :bulk_submitted | :bulk_refused
        | :delivery_sent | :delivery_failed

@type attrs :: %{
        optional(:bulk_envelope_id) => binary() | nil,
        optional(:conversation_id) => integer() | nil,
        optional(:template_id) => binary() | nil,
        optional(:actor_id) => binary() | nil,
        optional(:outcome) => atom(),
        optional(:effective_cap) => non_neg_integer()
      }

@spec emit(event() | atom(), attrs()) :: :ok
def emit(event, attrs) when event in @events do
  ...
end
```

### IN-04: `emit_delivery/4` uses inline `if/3` for atom mapping

**File:** `lib/cairnloop/workers/outbound_worker.ex:130`
**Issue:** `if(outcome == :sent, do: :delivery_sent, else: :delivery_failed)` —
inline `if` works for binary mappings but obscures intent. A `case` is
clearer and extends naturally if a third outcome lands (see WR-04).

**Fix:**

```elixir
trace_event =
  case outcome do
    :sent -> :delivery_sent
    :failed -> :delivery_failed
  end

Traces.emit(trace_event, %{...})
```

---

_Reviewed: 2026-05-27T18:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
