defmodule Cairnloop.Governance.TelemetryTest do
  @moduledoc """
  Headless (pure, no DB) proof of `Cairnloop.Governance.Telemetry` bounded execution events.

  OBS-01 requirements verified here:
  - `emit/3` accepts `:action_executed` and `:action_failed`; unknown events are silently dropped.
  - Emitted metadata for execution events contains ONLY the four bounded enum keys:
    `risk_tier`, `approval_mode`, `result_state`, `tool_ref`.
  - No high-cardinality keys (`actor_id`, `conversation_id`, `account_id`, `reason`,
    `content`) are ever present in emitted metadata.
  - `normalize_tool_ref/1` maps an unregistered tool ref to `:unknown`.
  - `normalize_tool_ref/1` passes through a registered tool ref unchanged.
  - `normalize_result_state/1` maps allowed values and falls back to `:unknown`.
  """
  use ExUnit.Case, async: false

  alias Cairnloop.Governance.Telemetry

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Register a telemetry handler that captures emitted metadata into the caller's mailbox.
  defp attach_handler(test_id, event_name) do
    handler_id = "test-handler-#{test_id}-#{event_name}"

    :telemetry.attach(
      handler_id,
      [:cairnloop, :governance, event_name],
      fn _event, _measurements, metadata, _config ->
        send(self(), {:telemetry_metadata, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    handler_id
  end

  # ---------------------------------------------------------------------------
  # @events allow-list: :action_executed and :action_failed are accepted
  # ---------------------------------------------------------------------------

  describe "emit/3 — accepted execution events" do
    test ":action_executed is accepted and fires [:cairnloop, :governance, :action_executed]",
         %{test: test_id} do
      attach_handler(test_id, :action_executed)

      Telemetry.emit(:action_executed, %{count: 1, duration_ms: 12}, %{
        risk_tier: :low_write,
        approval_mode: :requires_approval,
        result_state: :succeeded,
        tool_ref: :unknown
      })

      assert_receive {:telemetry_metadata, _meta},
                     500,
                     "expected [:cairnloop, :governance, :action_executed] to fire"
    end

    test ":action_failed is accepted and fires [:cairnloop, :governance, :action_failed]",
         %{test: test_id} do
      attach_handler(test_id, :action_failed)

      Telemetry.emit(:action_failed, %{count: 1}, %{
        risk_tier: :low_write,
        approval_mode: :requires_approval,
        result_state: :failed,
        tool_ref: :unknown
      })

      assert_receive {:telemetry_metadata, _meta},
                     500,
                     "expected [:cairnloop, :governance, :action_failed] to fire"
    end

    test "unknown event is silently dropped (no telemetry event fired)", %{test: test_id} do
      handler_id = "test-handler-#{test_id}-unknown"

      :telemetry.attach(
        handler_id,
        [:cairnloop, :governance, :not_a_real_event],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:telemetry_metadata, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      # Should be silently dropped — no function clause matches the guard
      # We call emit; it returns nil/nothing (guard clause drops it)
      Telemetry.emit(:not_a_real_event, %{count: 1}, %{})

      refute_receive {:telemetry_metadata, _},
                     100,
                     "unknown event must be silently dropped (guard clause)"
    end
  end

  # ---------------------------------------------------------------------------
  # OBS-01: execution event metadata contains ONLY the four bounded enum keys
  # ---------------------------------------------------------------------------

  describe "metadata — :action_executed emits only bounded enum labels" do
    test "emitted metadata contains exactly risk_tier, approval_mode, result_state, tool_ref",
         %{test: test_id} do
      attach_handler(test_id, :action_executed)

      Telemetry.emit(:action_executed, %{count: 1, duration_ms: 42}, %{
        risk_tier: :low_write,
        approval_mode: :requires_approval,
        result_state: :succeeded,
        tool_ref: :unknown,
        # Inject high-cardinality fields — must NOT appear in emitted metadata
        actor_id: "user-123",
        conversation_id: "conv-abc",
        account_id: "acct-xyz",
        reason: "some reason",
        content: "some note content"
      })

      assert_receive {:telemetry_metadata, meta}, 500

      # Required bounded keys MUST be present
      assert Map.has_key?(meta, :risk_tier)
      assert Map.has_key?(meta, :approval_mode)
      assert Map.has_key?(meta, :result_state)
      assert Map.has_key?(meta, :tool_ref)

      # High-cardinality keys MUST NOT be present (OBS-01)
      refute Map.has_key?(meta, :actor_id),
             "actor_id must never appear in execution telemetry metadata"

      refute Map.has_key?(meta, :conversation_id),
             "conversation_id must never appear in execution telemetry metadata"

      refute Map.has_key?(meta, :account_id),
             "account_id must never appear in execution telemetry metadata"

      refute Map.has_key?(meta, :reason),
             "reason must never appear in execution telemetry metadata"

      refute Map.has_key?(meta, :content),
             "content must never appear in execution telemetry metadata"
    end

    test "emitted metadata for :action_failed also excludes high-cardinality keys",
         %{test: test_id} do
      attach_handler(test_id, :action_failed)

      Telemetry.emit(:action_failed, %{count: 1}, %{
        risk_tier: :high_write,
        approval_mode: :always_block,
        result_state: :failed,
        tool_ref: :unknown,
        actor_id: "actor-leak-attempt",
        conversation_id: "conv-leak-attempt"
      })

      assert_receive {:telemetry_metadata, meta}, 500

      refute Map.has_key?(meta, :actor_id)
      refute Map.has_key?(meta, :conversation_id)
    end
  end

  # ---------------------------------------------------------------------------
  # OBS-01: normalize_tool_ref/1 — registry-validated cardinality bound
  # ---------------------------------------------------------------------------

  describe "normalize_tool_ref/1 — registry cardinality bound" do
    setup do
      # Reset tools env for each test
      Application.delete_env(:cairnloop, :tools)
      on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
      :ok
    end

    test "returns :unknown for an unregistered tool ref (no tools configured)" do
      # When no tools are configured the registry is empty → any ref is :unknown
      Application.put_env(:cairnloop, :tools, [])

      # Verify via emitting — the metadata will carry :unknown for an unregistered ref
      # We test via emit so the test matches the actual emission path.
      # The direct private function can't be called; we verify through the public contract.
      assert_via_emit(:action_executed, %{tool_ref: "Elixir.UnregisteredTool"}, fn meta ->
        assert meta.tool_ref == :unknown,
               "unregistered tool ref must normalize to :unknown (OBS-01 cardinality bound)"
      end)
    end

    test "returns the ref string when the tool IS in the registry" do
      defmodule RegisteredForTest do
        use Cairnloop.Tool,
          risk_tier: :read_only,
          title: "T",
          description: "D"

        embedded_schema do
          field(:x, :string)
        end

        def changeset(s, a), do: Ecto.Changeset.cast(s, a, [:x])
        def scope, do: []
        def authorize(_a, _c), do: :ok
        def run(_t, _a, _c), do: {:ok, %{}}
      end

      Application.put_env(:cairnloop, :tools, [RegisteredForTest])

      assert_via_emit(:action_executed, %{tool_ref: Atom.to_string(RegisteredForTest)}, fn meta ->
        assert meta.tool_ref == Atom.to_string(RegisteredForTest),
               "registered tool ref must pass through unchanged"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_result_state/1 — allow-list → :unknown fallback
  # ---------------------------------------------------------------------------

  describe "result_state normalization" do
    test ":not_executed, :succeeded, :failed are allowed" do
      for result_state <- [:not_executed, :succeeded, :failed] do
        assert_via_emit(:action_executed, %{result_state: result_state}, fn meta ->
          assert meta.result_state == result_state,
                 "expected #{result_state} to pass through; got #{meta.result_state}"
        end)
      end
    end

    test "unknown result_state normalizes to :unknown" do
      assert_via_emit(:action_executed, %{result_state: :totally_made_up}, fn meta ->
        assert meta.result_state == :unknown,
               "unknown result_state must normalize to :unknown"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Emits an event, waits for the handler, and calls assertion_fn with the metadata.
  defp assert_via_emit(event, extra_meta, assertion_fn) do
    handler_id = "assert-via-emit-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:cairnloop, :governance, event],
      fn _ev, _measurements, metadata, _cfg ->
        send(self(), {:assert_metadata, metadata})
      end,
      nil
    )

    base = %{
      risk_tier: :low_write,
      approval_mode: :requires_approval,
      result_state: :succeeded,
      tool_ref: :unknown
    }

    Telemetry.emit(event, %{count: 1}, Map.merge(base, extra_meta))

    assert_receive {:assert_metadata, meta}, 500, "telemetry handler did not fire for #{event}"

    :telemetry.detach(handler_id)
    assertion_fn.(meta)
  end
end
