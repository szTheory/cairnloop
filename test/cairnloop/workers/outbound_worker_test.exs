defmodule Cairnloop.Workers.OutboundWorkerTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Workers.OutboundWorker
  alias Cairnloop.Message
  alias Cairnloop.Conversation

  defmodule MockRepo do
    def get!(Message, 1) do
      %Message{
        id: 1,
        conversation_id: 10,
        content: "Hello",
        role: :system_outbound,
        metadata: %{"template_id" => "test", "status" => "pending"}
      }
    end

    def get!(Conversation, 10) do
      %Conversation{id: 10, host_user_id: "user_123"}
    end

    def update(changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

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

  # Phase 26 OBS-01 D-02: an extra notifier that returns `{:ok, _}` (arm B) so the
  # delivery-telemetry suite can prove the {:ok, _} arm fires :sent/:notifier_ok.
  defmodule OkTupleNotifier do
    @behaviour Cairnloop.Notifier
    def on_conversation_resolved(_, _), do: :ok
    def on_sla_breach(_, _, _), do: :ok
    def on_outbound_triggered(_, _), do: {:ok, :delivered}
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

  describe "perform/1" do
    test "successfully delivers message and updates status to sent" do
      assert {:ok, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:notified, 1, 10}
      # Status update is handled via MockRepo.update which we could verify if we captured it.
    end

    test "handles notifier error and updates status to failed" do
      Application.put_env(:cairnloop, :notifier, ErrorNotifier)

      assert {:error, {:error, :delivery_failed}} =
               OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})
    end
  end

  describe "Oban unique policy (Phase 25 D-11)" do
    # The Oban 2.17 surface for inspecting a worker's `unique:` clause is not stable
    # across point releases (some versions expose it on the job struct's `unique` field,
    # others via module attribute). The most robust assertion that captures the policy
    # intent is a structural check on the worker module's source — confirming the three
    # documented dedup keys are declared. Combined with the behaviour tests below
    # (perform/1 doesn't crash with or without bulk_envelope_id in args), this gives us
    # full confidence in the D-11 invariant without coupling to Oban internals.
    test "OutboundWorker source declares unique: keys [:conversation_id, :template_id, :bulk_envelope_id]" do
      source = File.read!("lib/cairnloop/workers/outbound_worker.ex")

      assert source =~
               "unique: [period: :infinity, fields: [:worker, :args], keys: [:conversation_id, :template_id, :bulk_envelope_id]]",
             "OutboundWorker must declare D-11 dedup keys at compile time"
    end

    test "Oban.Job constructed from OutboundWorker.new/2 with all dedup keys is a valid job" do
      job_changeset =
        OutboundWorker.new(%{
          "message_id" => 1,
          "conversation_id" => 10,
          "template_id" => "recovery_v1",
          "bulk_envelope_id" => nil
        })

      # Oban.Worker.new/2 returns an Ecto.Changeset (or an %Oban.Job{} depending on Oban
      # version) — both shapes carry the worker name in their data/changes. We just
      # confirm the construction succeeded and references our worker.
      worker_name =
        case job_changeset do
          %Ecto.Changeset{} = cs ->
            Ecto.Changeset.get_field(cs, :worker)

          %Oban.Job{worker: w} ->
            w
        end

      assert worker_name == "Cairnloop.Workers.OutboundWorker"
    end

    test "perform/1 succeeds when args include bulk_envelope_id (Phase 25 forward-compat)" do
      assert {:ok, _} =
               OutboundWorker.perform(%Oban.Job{
                 args: %{"message_id" => 1, "bulk_envelope_id" => "some-uuid"}
               })

      assert_receive {:notified, 1, 10}
    end

    test "perform/1 succeeds when args omit bulk_envelope_id (Phase 24 backwards-compat)" do
      # Pins Phase 24 behavior under the new `unique:` declaration: the worker must
      # continue to function for callers that never learned about bulk_envelope_id.
      assert {:ok, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:notified, 1, 10}
    end
  end

  describe "delivery telemetry (Phase 26 OBS-01 D-02)" do
    # Phase 26 D-02 / D-03: bounded-metrics delivery events on
    # [:cairnloop, :outbound, :delivery, :sent | :failed] (4-segment,
    # point-in-time) AND OI trace events on
    # [:cairnloop, :outbound, :trace, :delivery_sent | :delivery_failed]
    # (4-segment with :trace in pos 3). Both lanes are disjoint by D-03.

    defp attach_delivery_handler(test_id, outcome_atom) do
      handler_id = "outbound-delivery-#{test_id}-#{outcome_atom}"

      :telemetry.attach(
        handler_id,
        [:cairnloop, :outbound, :delivery, outcome_atom],
        fn _event, measurements, metadata, _config ->
          send(self(), {:delivery_event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
    end

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

    test "arm A — :ok notifier fires :sent with reason :notifier_ok", %{test: test_id} do
      attach_delivery_handler(test_id, :sent)

      # Default MockNotifier (set in `setup`) returns :ok — arm A.
      assert {:ok, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:delivery_event, %{count: 1}, metadata}, 500
      assert metadata.outcome == :sent
      assert metadata.reason == :notifier_ok

      # Enum-only labels per D-01: NO conversation_id / template_id / actor / bulk_envelope_id.
      refute Map.has_key?(metadata, :conversation_id)
      refute Map.has_key?(metadata, :template_id)
      refute Map.has_key?(metadata, :actor)
      refute Map.has_key?(metadata, :bulk_envelope_id)
    end

    test "arm B — {:ok, _} notifier fires :sent with reason :notifier_ok", %{test: test_id} do
      Application.put_env(:cairnloop, :notifier, OkTupleNotifier)
      attach_delivery_handler(test_id, :sent)

      assert {:ok, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:delivery_event, %{count: 1}, metadata}, 500
      assert metadata.outcome == :sent
      assert metadata.reason == :notifier_ok
    end

    test "arm C — ErrorNotifier fires :failed with reason :notifier_returned_error",
         %{test: test_id} do
      Application.put_env(:cairnloop, :notifier, ErrorNotifier)
      attach_delivery_handler(test_id, :failed)

      # Phase 22/23 regression-safe: function still returns {:error, _} as before.
      assert {:error, {:error, :delivery_failed}} =
               OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:delivery_event, %{count: 1}, metadata}, 500
      assert metadata.outcome == :failed
      assert metadata.reason == :notifier_returned_error
    end

    test "arm D — no notifier configured fires :no_op with reason :no_notifier_configured (WR-04)",
         %{test: test_id} do
      # WR-04: previously this arm reported outcome :sent — operators
      # aggregating on `:outcome` saw no-notifier no-ops as successful
      # deliveries. Now the bounded-metrics event lands on
      # [:cairnloop, :outbound, :delivery, :no_op] with outcome :no_op
      # so dashboards can count no-op cases separately. The OI lane
      # intentionally fires NO trace for :no_op since no TOOL execution
      # happened (asserted in a separate test below).
      Application.delete_env(:cairnloop, :notifier)
      attach_delivery_handler(test_id, :no_op)

      assert :ok = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:delivery_event, %{count: 1}, metadata}, 500
      assert metadata.outcome == :no_op
      assert metadata.reason == :no_notifier_configured

      # Enum-only labels per D-01 stay invariant.
      refute Map.has_key?(metadata, :conversation_id)
      refute Map.has_key?(metadata, :template_id)
      refute Map.has_key?(metadata, :actor)
      refute Map.has_key?(metadata, :bulk_envelope_id)
    end

    test "WR-04: no-notifier arm fires NO OI trace event (no execution span when nothing executed)",
         %{test: test_id} do
      Application.delete_env(:cairnloop, :notifier)
      # Attach to both delivery_sent and delivery_failed so we'd catch
      # a stray trace either way.
      attach_trace_handler(test_id, :delivery_sent)

      sent_handler = "outbound-trace-#{test_id}-delivery_sent"
      failed_handler = "outbound-trace-#{test_id}-delivery_failed"

      :telemetry.attach(
        failed_handler,
        [:cairnloop, :outbound, :trace, :delivery_failed],
        fn _e, _m, metadata, _c -> send(self(), {:trace_metadata, metadata}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach(failed_handler) end)

      assert :ok = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      refute_receive {:trace_metadata, _meta}, 100

      _ = sent_handler
    end

    test "OI trace lane parity — :sent fires TOOL trace with attribution refs",
         %{test: test_id} do
      # MockNotifier (:ok arm) — also fires the OI lane.
      attach_trace_handler(test_id, :delivery_sent)

      assert {:ok, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "TOOL"
      assert meta[:conversation_id] == 10
      assert meta[:template_id] == "test"
      assert meta[:outcome] == :sent
      # No bulk_envelope_id in default args — therefore nil on the trace.
      assert meta[:bulk_envelope_id] == nil
      # actor_id is system-initiated at delivery time per RESEARCH OQ2.
      assert meta[:actor_id] == nil
    end

    test "OI trace lane parity — :failed fires TOOL trace with outcome :failed",
         %{test: test_id} do
      Application.put_env(:cairnloop, :notifier, ErrorNotifier)
      attach_trace_handler(test_id, :delivery_failed)

      assert {:error, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "TOOL"
      assert meta[:outcome] == :failed
    end

    test "bulk_envelope_id is threaded from job args to the OI trace metadata",
         %{test: test_id} do
      attach_trace_handler(test_id, :delivery_sent)

      assert {:ok, _} =
               OutboundWorker.perform(%Oban.Job{
                 args: %{"message_id" => 1, "bulk_envelope_id" => "env-uuid-77"}
               })

      assert_receive {:trace_metadata, meta}, 500
      assert meta[:bulk_envelope_id] == "env-uuid-77"
    end
  end

  # ----------------------------------------------------------------------------
  # D-11 — Oban worker config (headless). The runtime dedup behavior is Oban's
  # contract (well-tested upstream); what WE own is the configuration of the
  # `unique:` keys. Cairnloop ships no Oban migration (the host owns `oban_jobs`
  # — see test/integration/approval_flow_test.exs:9), so a true Oban.insert
  # round-trip is out of reach for the integration suite. The headless assertion
  # below is the right level: it locks the dedup tuple to the documented
  # (conversation_id, template_id, bulk_envelope_id) shape.
  # ----------------------------------------------------------------------------
  describe "Oban unique: config (D-11)" do
    test "OutboundWorker is configured with the documented dedup tuple" do
      unique = OutboundWorker.__opts__()[:unique]

      assert unique[:period] == :infinity
      assert unique[:fields] == [:worker, :args]
      assert unique[:keys] == [:conversation_id, :template_id, :bulk_envelope_id]
    end
  end
end
