defmodule Cairnloop.Telemetry do
  @moduledoc """
  Centralizes telemetry event execution and documentation for Cairnloop.

  Cairnloop emits telemetry events for all major operations. You can attach to these
  events to capture metrics, logs, and traces.

  ## Conversation Events

  The following events are emitted using `:telemetry.span/3`:

  * `[:cairnloop, :conversation, :resolve, :start]`
  * `[:cairnloop, :conversation, :resolve, :stop]` - Metadata includes `:business_duration_seconds`
  * `[:cairnloop, :conversation, :resolve, :exception]`

  * `[:cairnloop, :conversation, :reply, :start]`
  * `[:cairnloop, :conversation, :reply, :stop]`
  * `[:cairnloop, :conversation, :reply, :exception]`

  ## Feedback Events

  * `[:cairnloop, :feedback, :csat, :start]`
  * `[:cairnloop, :feedback, :csat, :stop]` - Metadata includes `:rating`
  * `[:cairnloop, :feedback, :csat, :exception]`

  ## Retrieval Events

  * `[:cairnloop, :retrieval, :search]`
  * `[:cairnloop, :retrieval, :draft_grounding]`

  Retrieval metadata is bounded to low-cardinality fields such as `:surface`,
  `:source_mix`, `:result_bucket`, `:grounding_status`, `:diagnostic_class`,
  `:reason`, `:canonical_hit_count`, `:assistive_hit_count`, and `:ranking_outcome`.
  """

  @doc """
  Executes a telemetry span around the given function.
  """
  def span(event_suffix, metadata, fun) when is_list(event_suffix) do
    :telemetry.span([:cairnloop | event_suffix], metadata, fun)
  end

  @doc """
  Executes a point-in-time telemetry event.
  """
  def execute(event_suffix, measurements, metadata) when is_list(event_suffix) do
    :telemetry.execute([:cairnloop | event_suffix], measurements, metadata)
  end
end
