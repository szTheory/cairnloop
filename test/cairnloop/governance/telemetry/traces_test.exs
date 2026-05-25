defmodule Cairnloop.Governance.Telemetry.TracesTest do
  @moduledoc """
  Headless (pure, no DB) proof of `Cairnloop.Governance.Telemetry.Traces` OI-conformant
  trace event module.

  Covers:
  - OI span kind assignment per event atom (TOOL vs GUARDRAIL)
  - Attribution field presence (tool_proposal_id, actor_id)
  - Payload content exclusion (D17-02: no :content, :input_snapshot keys)
  - Guard-clause no-op for unknown events (D17-05)
  - Namespace isolation from the bounded-metrics `Cairnloop.Governance.Telemetry` module (D17-01):
    emitting to the 4-segment trace path does NOT fire handlers on the 3-segment bounded-metrics path.
  """
  use ExUnit.Case, async: false

  alias Cairnloop.Governance.Telemetry.Traces

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Attach a handler to the 4-segment trace event path.
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

  # ---------------------------------------------------------------------------
  # emit/2 — accepted trace events
  # ---------------------------------------------------------------------------

  describe "emit/2 — accepted trace events" do
    test ":execution_succeeded fires with span kind TOOL", %{test: test_id} do
      attach_trace_handler(test_id, :execution_succeeded)

      Traces.emit(:execution_succeeded, @attrs)

      assert_receive {:trace_metadata, meta},
                     500,
                     "expected [:cairnloop, :governance, :trace, :execution_succeeded] to fire"

      assert meta["openinference.span.kind"] == "TOOL",
             "execution events must carry TOOL span kind"
    end

    test ":approval_requested fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :approval_requested)

      Traces.emit(:approval_requested, @attrs)

      assert_receive {:trace_metadata, meta},
                     500,
                     "expected [:cairnloop, :governance, :trace, :approval_requested] to fire"

      assert meta["openinference.span.kind"] == "GUARDRAIL",
             "approval events must carry GUARDRAIL span kind"
    end

    test ":proposal_created fires with span kind GUARDRAIL", %{test: test_id} do
      attach_trace_handler(test_id, :proposal_created)

      Traces.emit(:proposal_created, @attrs)

      assert_receive {:trace_metadata, meta},
                     500,
                     "expected [:cairnloop, :governance, :trace, :proposal_created] to fire"

      assert meta["openinference.span.kind"] == "GUARDRAIL",
             "proposal events must carry GUARDRAIL span kind"
    end

    test "emitted metadata contains tool_proposal_id and actor_id", %{test: test_id} do
      attach_trace_handler(test_id, :execution_succeeded)

      Traces.emit(:execution_succeeded, @attrs)

      assert_receive {:trace_metadata, meta}, 500

      assert meta[:tool_proposal_id] == "p-1",
             "metadata must carry tool_proposal_id"

      assert meta[:actor_id] == "actor-1",
             "metadata must carry actor_id"
    end
  end

  # ---------------------------------------------------------------------------
  # emit/2 — payload content exclusion (D17-02)
  # ---------------------------------------------------------------------------

  describe "emit/2 — payload content exclusion (D17-02)" do
    test "metadata does not carry :content key", %{test: test_id} do
      attach_trace_handler(test_id, :execution_succeeded)

      # Pass an attrs map that has a :content key — it must not appear in metadata
      attrs_with_content = Map.put(@attrs, :content, "some sensitive content")
      Traces.emit(:execution_succeeded, attrs_with_content)

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :content),
             ":content must never appear in trace metadata (D17-02)"
    end

    test "metadata does not carry :input_snapshot key", %{test: test_id} do
      attach_trace_handler(test_id, :execution_succeeded)

      # Pass attrs with an :input_snapshot key — it must not appear in metadata
      attrs_with_snapshot = Map.put(@attrs, :input_snapshot, %{param: "value"})
      Traces.emit(:execution_succeeded, attrs_with_snapshot)

      assert_receive {:trace_metadata, meta}, 500

      refute Map.has_key?(meta, :input_snapshot),
             ":input_snapshot must never appear in trace metadata (D17-02)"
    end
  end

  # ---------------------------------------------------------------------------
  # emit/2 — guard-clause no-op (D17-05)
  # ---------------------------------------------------------------------------

  describe "emit/2 — guard-clause no-op (D17-05)" do
    test "unknown event :not_a_trace_event is silently dropped", %{test: test_id} do
      handler_id = "test-trace-handler-#{test_id}-not_a_trace_event"

      :telemetry.attach(
        handler_id,
        [:cairnloop, :governance, :trace, :not_a_trace_event],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:trace_metadata, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Traces.emit(:not_a_trace_event, @attrs)

      refute_receive {:trace_metadata, _},
                     100,
                     "unknown event must be silently dropped — guard clause (D17-05)"
    end
  end

  # ---------------------------------------------------------------------------
  # Namespace isolation from Governance.Telemetry (D17-01)
  # ---------------------------------------------------------------------------

  describe "namespace isolation from Governance.Telemetry (D17-01)" do
    test "attaching to [:cairnloop, :governance, :proposal_created] does NOT fire when Traces.emit(:proposal_created) is called",
         %{test: test_id} do
      # Attach a handler to the 3-segment BOUNDED-METRICS path (NOT the trace path).
      bounded_handler_id = "test-bounded-metrics-#{test_id}"

      :telemetry.attach(
        bounded_handler_id,
        [:cairnloop, :governance, :proposal_created],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:bounded_metadata, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(bounded_handler_id) end)

      # Emit via Traces — this fires [:cairnloop, :governance, :trace, :proposal_created]
      # (4-segment), NOT [:cairnloop, :governance, :proposal_created] (3-segment).
      Traces.emit(:proposal_created, @attrs)

      # The bounded-metrics handler on the 3-segment path must NOT receive anything.
      refute_receive {:bounded_metadata, _},
                     100,
                     "Traces.emit must NOT fire the bounded-metrics 3-segment event (D17-01 namespace isolation)"
    end
  end
end
