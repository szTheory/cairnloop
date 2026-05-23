defmodule Cairnloop.Governance.Telemetry do
  @moduledoc """
  Bounded telemetry for governed tool proposal events.

  Metadata is constrained to allow-listed low-cardinality values so telemetry remains
  safe for observability and never becomes a durable workflow record (D-29).

  Telemetry is emitted **alongside**, never instead of, `ToolActionEvent` inserts.
  Emit calls belong AFTER a successful `with` pipeline — not inside the `with` clause
  list (mirrors `emit_review_task_event` from `KnowledgeAutomation`).

  ## Events

  * `[:cairnloop, :governance, :proposal_created]` — new proposal co-committed
  * `[:cairnloop, :governance, :proposal_blocked]` — proposal blocked (and persisted)
  * `[:cairnloop, :governance, :proposal_duplicate]` — idempotent duplicate returned
  """

  alias Cairnloop.Telemetry

  @events [:proposal_created, :proposal_blocked, :proposal_duplicate]

  @allowed_outcomes [
    :proposed,
    :needs_input,
    :scope_invalid,
    :policy_denied,
    :unsupported,
    :duplicate
  ]

  @allowed_risk_tiers [:read_only, :low_write, :high_write, :destructive, :unknown]
  @allowed_approval_modes [:auto, :requires_approval, :always_block, :unknown]

  @doc """
  Emits a governance telemetry event.

  Only accepts events in `@events`. Unknown events are silently dropped (guard clause).
  All outcome/tier/mode values are normalized against allow-lists before emission to
  prevent high-cardinality label leakage.
  """
  def emit(event, measurements, metadata) when event in @events do
    Telemetry.execute(
      [:governance, event],
      normalize_measurements(measurements),
      metadata(event, metadata)
    )
  end

  @doc false
  def metadata(_event, metadata) when is_map(metadata) do
    %{
      outcome: normalize_outcome(Map.get(metadata, :outcome)),
      risk_tier: normalize_risk_tier(Map.get(metadata, :risk_tier)),
      approval_mode: normalize_approval_mode(Map.get(metadata, :approval_mode)),
      count: normalize_count(Map.get(metadata, :count))
    }
  end

  def metadata(event, metadata) when is_list(metadata), do: metadata(event, Map.new(metadata))
  def metadata(_event, _metadata), do: metadata(nil, %{})

  defp normalize_measurements(measurements) do
    %{
      duration_ms: measurements[:duration_ms] || 0,
      count: normalize_count(measurements[:count] || 1)
    }
  end

  defp normalize_outcome(value) when value in @allowed_outcomes, do: value
  defp normalize_outcome(_), do: :unsupported

  defp normalize_risk_tier(value) when value in @allowed_risk_tiers, do: value
  defp normalize_risk_tier(_), do: :unknown

  defp normalize_approval_mode(value) when value in @allowed_approval_modes, do: value
  defp normalize_approval_mode(_), do: :unknown

  defp normalize_count(value) when is_integer(value) and value >= 0, do: min(value, 99)
  defp normalize_count(_), do: 0
end
