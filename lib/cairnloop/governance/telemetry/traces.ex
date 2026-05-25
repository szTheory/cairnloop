defmodule Cairnloop.Governance.Telemetry.Traces do
  @moduledoc """
  Optional OpenInference-conformant trace event module for the Cairnloop governed-action
  evidence lane (Phase 17, D17-01, D17-03).

  ## Namespace separation (D17-01)

  This module is SEPARATE from `Cairnloop.Governance.Telemetry` (the bounded-metrics
  module). It emits to a disjoint 4-segment event namespace:

      [:cairnloop, :governance, :trace, <event_atom>]

  The bounded-metrics module emits to 3-segment paths:

      [:cairnloop, :governance, <event_atom>]

  No handler attached to the bounded-metrics path will receive trace events, and
  vice versa. This isolation is proven in `Cairnloop.Governance.Telemetry.TracesTest`.

  ## Purpose

  Hosts (and Scoria) can attach to `[:cairnloop, :governance, :trace, ...]` to reconstruct
  a governed-action span tree without duplicating durable record content.

  Trace events are emitted **alongside** existing `ToolActionEvent` co-commits — they are
  observability only, never workflow truth (D-29).

  ## Zero Scoria dependency

  This module calls `:telemetry.execute/3` directly. It imports no Scoria-owned modules.
  No Scoria runtime, no external adapter, no supervisor. If no handler is attached, the
  event is silently dropped by the `:telemetry` library (D17-05 — fail-closed).

  ## OI span kinds

  Trace events carry `"openinference.span.kind"` (string key per OI spec) in metadata:

  - Execution events (`:execution_started`, `:execution_succeeded`, `:execution_failed`):
    `"TOOL"`
  - All other governed-action events: `"GUARDRAIL"`

  ## Payload content exclusion (D17-02)

  Metadata carries only attribution references (IDs, atom enums). No policy snapshot
  content, no input payloads, no note content ever crosses the telemetry boundary.

  ## Guard-clause no-op (D17-05)

  Unknown event atoms are silently dropped — `emit/2` returns `:ok` without calling
  `:telemetry.execute/3`. The caller is never penalised for passing an atom not in
  `@events`.
  """

  @events [
    :proposal_created,
    :proposal_blocked,
    :approval_requested,
    :approved,
    :rejected,
    :deferred,
    :expired,
    :revalidation_passed,
    :revalidation_failed,
    :execution_started,
    :execution_succeeded,
    :execution_failed
  ]

  # OI span kind string constants (string keys per OpenInference spec)
  @span_kind_tool "TOOL"
  @span_kind_guardrail "GUARDRAIL"

  @doc """
  Emits an OI-conformant trace telemetry event.

  Only accepts events in `@events`. Unknown events are silently dropped (guard clause).

  Event path: `[:cairnloop, :governance, :trace, event]` — 4 segments with `:trace` in
  position 3, disjoint from the bounded-metrics 3-segment namespace (D17-01).

  Measurements are always `%{count: 1}` — callers do not supply measurements.

  Metadata is built by `build_metadata/2`: only attribution refs, no payload content (D17-02).
  """
  def emit(event, attrs) when event in @events do
    :telemetry.execute(
      [:cairnloop, :governance, :trace, event],
      %{count: 1},
      build_metadata(event, attrs)
    )
  end

  # Guard-clause no-op: unknown events are silently dropped (D17-05).
  def emit(_event, _attrs), do: :ok

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # build_metadata/2 — OI-conformant metadata shape.
  #
  # Contains exactly:
  #   "openinference.span.kind" — string key per OI spec; value is TOOL or GUARDRAIL
  #   :tool_proposal_id         — attribution ref (proposal identity)
  #   :actor_id                 — attribution ref (who triggered the action)
  #   :policy_snapshot_ref      — ref = tool_proposal_id, NOT policy content (D17-02)
  #   :decided_by               — attribution ref (who made the decision, nil if N/A)
  #   :attempt                  — attempt number for execution events, nil otherwise
  #
  # Specifically excluded: :content, :input_snapshot, :policy_snapshot, :reason.
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

  # span_kind_for/1 — maps event atom to OI span kind string.
  # Execution events are TOOL spans; all governed-action lifecycle events are GUARDRAIL spans.
  defp span_kind_for(event)
       when event in [:execution_started, :execution_succeeded, :execution_failed],
       do: @span_kind_tool

  defp span_kind_for(_event), do: @span_kind_guardrail
end
