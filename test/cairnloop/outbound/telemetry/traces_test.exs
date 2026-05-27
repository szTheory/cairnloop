defmodule Cairnloop.Outbound.Telemetry.TracesTest do
  @moduledoc """
  Headless (pure, no DB) proof of `Cairnloop.Outbound.Telemetry.Traces` OI-conformant
  trace event module (Phase 26, D-03).

  Mirrors `Cairnloop.Governance.Telemetry.TracesTest` (Phase 17) verbatim, swapping
  the namespace + event atoms + attribution refs for the outbound lane.

  Covers:

  - OI span kind assignment per event atom (TOOL for `:delivery_*`, GUARDRAIL for the
    lifecycle / bulk events)
  - Attribution field presence (`:bulk_envelope_id`, `:conversation_id`, `:template_id`,
    `:actor_id`, `:outcome`)
  - Payload content exclusion (D-03: no `:content`, no `:rendered_body`, no
    `:refused_reason` keys)
  - Guard-clause no-op for unknown events (mirrors D17-05)
  - Namespace isolation from the bounded-metrics 4-segment path
    `[:cairnloop, :outbound, :delivery, :sent]` (D-03 / mirrors D17-01)
  - `:effective_cap` is included ONLY on `:bulk_refused` (per RESEARCH OQ3)
  """
  use ExUnit.Case, async: false

  alias Cairnloop.Outbound.Telemetry.Traces

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Attach a handler to the 4-segment trace event path.
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
    handler_id
  end

  @attrs %{
    bulk_envelope_id: "env-1",
    conversation_id: 42,
    template_id: "recovery_v1",
    actor_id: "actor-1",
    outcome: :triggered,
    effective_cap: 25
  }

  # ---------------------------------------------------------------------------
  # emit/2 — span kind mapping (D-03)
  # ---------------------------------------------------------------------------

  describe "emit/2 — span kind mapping (D-03)" do
    test ":delivery_sent fires with span kind TOOL", %{test: test_id} do
      attach_trace_handler(test_id, :delivery_sent)

      Traces.emit(:delivery_sent, Map.put(@attrs, :outcome, :sent))

      assert_receive {:trace_metadata, meta},
                     500,
                     "expected [:cairnloop, :outbound, :trace, :delivery_sent] to fire"

      assert meta["openinference.span.kind"] == "TOOL",
             "delivery events must carry TOOL span kind"
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

    test ":trigger_completed fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :trigger_completed)

      Traces.emit(:trigger_completed, @attrs)

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
    end

    test ":trigger_failed fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :trigger_failed)

      Traces.emit(:trigger_failed, Map.put(@attrs, :outcome, :failed))

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
    end

    test ":bulk_submitted fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :bulk_submitted)

      Traces.emit(:bulk_submitted, Map.put(@attrs, :outcome, :submitted))

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
    end

    test ":bulk_refused fires with span kind GUARDRAIL and carries :effective_cap (RESEARCH OQ3)",
         %{test: test_id} do
      attach_trace_handler(test_id, :bulk_refused)

      Traces.emit(
        :bulk_refused,
        Map.put(@attrs, :outcome, :refused_cap_exceeded)
      )

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"

      assert meta[:effective_cap] == 25,
             ":effective_cap must be present on :bulk_refused metadata (RESEARCH OQ3)"
    end
  end

  # ---------------------------------------------------------------------------
  # emit/2 — attribution refs always present (D-03)
  # ---------------------------------------------------------------------------

  describe "emit/2 — attribution refs (D-03)" do
    test "metadata carries bulk_envelope_id, conversation_id, template_id, actor_id, outcome",
         %{test: test_id} do
      attach_trace_handler(test_id, :trigger_started)

      Traces.emit(:trigger_started, @attrs)

      assert_receive {:trace_metadata, meta}, 500

      assert meta[:bulk_envelope_id] == "env-1"
      assert meta[:conversation_id] == 42
      assert meta[:template_id] == "recovery_v1"
      assert meta[:actor_id] == "actor-1"
      assert meta[:outcome] == :triggered
    end
  end

  # ---------------------------------------------------------------------------
  # emit/2 — payload content exclusion (D-03 / mirrors D17-02)
  # ---------------------------------------------------------------------------

  describe "emit/2 — payload content exclusion (D-03)" do
    test "metadata does not carry :content key", %{test: test_id} do
      attach_trace_handler(test_id, :delivery_sent)

      attrs_with_content = Map.put(@attrs, :content, "secret body")
      Traces.emit(:delivery_sent, attrs_with_content)

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :content),
             ":content must never appear in trace metadata (D-03)"
    end

    test "metadata does not carry :rendered_body key", %{test: test_id} do
      attach_trace_handler(test_id, :bulk_submitted)

      attrs_with_body = Map.put(@attrs, :rendered_body, "secret body")
      Traces.emit(:bulk_submitted, attrs_with_body)

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :rendered_body),
             ":rendered_body must never appear in trace metadata (D-03)"
    end

    test "metadata does not carry :refused_reason key", %{test: test_id} do
      attach_trace_handler(test_id, :bulk_refused)

      attrs_with_reason =
        @attrs
        |> Map.put(:outcome, :refused_cap_exceeded)
        |> Map.put(:refused_reason, "batch_size 26 exceeds cap 25")

      Traces.emit(:bulk_refused, attrs_with_reason)

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :refused_reason),
             ":refused_reason free-text must never appear in trace metadata (D-03)"
    end
  end

  # ---------------------------------------------------------------------------
  # emit/2 — guard-clause no-op (D-03 / mirrors D17-05)
  # ---------------------------------------------------------------------------

  describe "emit/2 — guard-clause no-op (D-03)" do
    test "unknown event is silently dropped and returns :ok", %{test: test_id} do
      handler_id = "outbound-trace-#{test_id}-bogus"

      :telemetry.attach(
        handler_id,
        [:cairnloop, :outbound, :trace, :not_a_real_event],
        fn _event, _measurements, _metadata, _config ->
          send(self(), :should_not_fire)
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert Traces.emit(:not_a_real_event, @attrs) == :ok

      refute_receive :should_not_fire,
                     100,
                     "unknown event must be silently dropped — fail-closed guard clause (D-03)"
    end
  end

  # ---------------------------------------------------------------------------
  # Namespace isolation from bounded-metrics (D-03 / mirrors D17-01)
  # ---------------------------------------------------------------------------

  describe "namespace isolation from bounded-metrics (D-03)" do
    test "attaching to [:cairnloop, :outbound, :delivery, :sent] does NOT fire when Traces.emit(:delivery_sent) is called",
         %{test: test_id} do
      # Attach a handler to the 4-segment BOUNDED-METRICS delivery path (NOT the trace path).
      bounded_handler_id = "outbound-bounded-isolation-#{test_id}"

      :telemetry.attach(
        bounded_handler_id,
        [:cairnloop, :outbound, :delivery, :sent],
        fn _event, _measurements, _metadata, _config ->
          send(self(), :leaked)
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(bounded_handler_id) end)

      # Emit via Traces — this fires [:cairnloop, :outbound, :trace, :delivery_sent]
      # (4-segment with :trace in pos 3), NOT [:cairnloop, :outbound, :delivery, :sent]
      # (4-segment with :delivery in pos 3). The two namespaces are disjoint by D-03.
      Traces.emit(:delivery_sent, Map.put(@attrs, :outcome, :sent))

      refute_receive :leaked,
                     100,
                     "Traces.emit must NOT fire the bounded-metrics 4-segment delivery event (D-03)"
    end
  end

  # ---------------------------------------------------------------------------
  # :effective_cap is included only on :bulk_refused (RESEARCH OQ3)
  # ---------------------------------------------------------------------------

  describe ":effective_cap inclusion is :bulk_refused-only (RESEARCH OQ3)" do
    test ":bulk_submitted does NOT carry :effective_cap even when passed in attrs",
         %{test: test_id} do
      attach_trace_handler(test_id, :bulk_submitted)

      Traces.emit(
        :bulk_submitted,
        Map.put(@attrs, :outcome, :submitted)
      )

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :effective_cap),
             ":effective_cap belongs only on :bulk_refused metadata (RESEARCH OQ3)"
    end

    test ":delivery_sent does NOT carry :effective_cap even when passed in attrs",
         %{test: test_id} do
      attach_trace_handler(test_id, :delivery_sent)

      Traces.emit(
        :delivery_sent,
        Map.put(@attrs, :outcome, :sent)
      )

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :effective_cap),
             ":effective_cap belongs only on :bulk_refused metadata (RESEARCH OQ3)"
    end
  end
end
