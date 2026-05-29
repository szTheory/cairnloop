defmodule Cairnloop.OutboundTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Outbound

  defmodule MockRepo do
    # Direct insert/1 path used by bulk_trigger/2's refusal lane (persists the
    # :refused_cap_exceeded BulkEnvelope row outside the Multi transaction so an
    # operator-facing audit row exists even if the caller has no telemetry handler).
    # We also record the inserted row in the process dictionary so tests can
    # assert on the refused envelope shape without needing a real DB.
    def insert(changeset_or_struct) do
      # CR-02 regression hook: tests can force the next `insert/1` call to
      # fail with a synthetic `{:error, %Ecto.Changeset{}}` to exercise the
      # refusal-audit-failure observability lane (telemetry outcome
      # `:refused_cap_exceeded_audit_failed` + Logger.error).
      #
      # Phase 26 D-03 regression hook (`:mock_repo_force_insert_unexpected_shape`):
      # tests can force the next `insert/1` call to return an arbitrary non-`{:ok, _}`,
      # non-`{:error, %Ecto.Changeset{}}` shape so the `other ->` arm of
      # `bulk_trigger_refused/6`'s `case repo().insert(...)` block can be exercised
      # for OI trace coverage.
      cond do
        forced = Process.get(:mock_repo_force_insert_failure) ->
          Process.delete(:mock_repo_force_insert_failure)
          {:error, forced}

        forced = Process.get(:mock_repo_force_insert_unexpected_shape) ->
          Process.delete(:mock_repo_force_insert_unexpected_shape)
          forced

        true ->
          result =
            case changeset_or_struct do
              %Ecto.Changeset{} = cs ->
                if cs.valid? do
                  applied = Ecto.Changeset.apply_changes(cs)
                  # BulkEnvelope :id is caller-supplied (binary_id,
                  # autogenerate: false) so we don't synthesize one here.
                  {:ok, applied}
                else
                  {:error, cs}
                end

              struct ->
                {:ok, struct}
            end

          case result do
            {:ok, applied} ->
              existing = Process.get(:mock_repo_inserts, [])
              Process.put(:mock_repo_inserts, existing ++ [applied])
              {:ok, applied}

            other ->
              other
          end
      end
    end

    def transaction(multi) do
      cond do
        Process.get(:mock_repo_force_transaction_raise) ->
          Process.delete(:mock_repo_force_transaction_raise)
          raise "boom"

        forced = Process.get(:mock_repo_force_transaction_failure) ->
          Process.delete(:mock_repo_force_transaction_failure)
          forced

        true ->
          execute_multi(multi, %{})
      end
    end

    defp execute_multi(multi, acc) do
      operations = Ecto.Multi.to_list(multi)

      Enum.reduce_while(operations, {:ok, acc}, fn
        {name, {:insert, changeset, _}}, {:ok, results} ->
          if changeset.valid? do
            applied = Ecto.Changeset.apply_changes(changeset)
            # Per-recipient :message_* rows still need a synthesized id (the
            # BulkEnvelope :id is caller-supplied via Ecto.UUID.generate and is
            # already present on the changeset, so Map.put with 999 would clobber
            # it — only synthesize when :id is nil).
            result =
              case Map.get(applied, :id) do
                nil -> Map.put(applied, :id, 999)
                _ -> applied
              end

            existing = Process.get(:mock_repo_inserts, [])
            Process.put(:mock_repo_inserts, existing ++ [result])
            {:cont, {:ok, Map.put(results, name, result)}}
          else
            {:halt, {:error, name, changeset, results}}
          end

        {name, %Oban.Job{} = job}, {:ok, results} ->
          {:cont, {:ok, Map.put(results, name, job)}}

        {name, {:run, run_fn}}, {:ok, results} ->
          case run_fn.(__MODULE__, results) do
            {:ok, result} -> {:cont, {:ok, Map.put(results, name, result)}}
            {:error, error} -> {:halt, {:error, name, error, results}}
          end

        {_name, {:merge, merge_fn}}, {:ok, results} ->
          merged_multi = merge_fn.(results)

          case execute_multi(merged_multi, results) do
            {:ok, new_results} -> {:cont, {:ok, new_results}}
            error -> {:halt, error}
          end
      end)
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.put(:mock_repo_inserts, [])

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      # Pitfall 7: max_batch_size env tweaks must not leak across tests.
      Application.delete_env(:cairnloop, :max_batch_size)
      Process.delete(:mock_repo_inserts)
      # CR-02 regression hook: never leak the forced-failure stub across tests.
      Process.delete(:mock_repo_force_insert_failure)
      # Phase 26 D-03 regression hooks: never leak forced shapes across tests.
      Process.delete(:mock_repo_force_insert_unexpected_shape)
      Process.delete(:mock_repo_force_transaction_failure)
      Process.delete(:mock_repo_force_transaction_raise)
    end)

    :ok
  end

  describe "trigger/2" do
    test "inserts a system_outbound message with template_id and enqueues delivery job" do
      assert {:ok, results} = Outbound.trigger(1, template_id: "recovery_v1")
      assert message = results.message
      assert message.role == :system_outbound
      assert message.conversation_id == 1
      assert message.metadata["template_id"] == "recovery_v1"
      assert message.metadata["status"] == "pending"

      assert job = results.delivery_job
      assert job.worker == "Cairnloop.Workers.OutboundWorker"
      # Phase 25 (D-11) additively requires `conversation_id` + `template_id` in args
      # so the Oban `unique:` dedup tuple is well-formed. Phase 24 callers do not pass
      # `:bulk_envelope_id`, so its arg value is `nil` (Oban treats nil as a valid
      # dedup key value — research Open Question 2).
      assert job.args["message_id"] == 999
      assert job.args["conversation_id"] == 1
      assert job.args["template_id"] == "recovery_v1"
      assert Map.get(job.args, "bulk_envelope_id") == nil
    end

    test "supports schedule_in option" do
      assert {:ok, results} = Outbound.trigger(1, template_id: "recovery_v1", schedule_in: 3600)
      assert job = results.delivery_job
      # In MockRepo, we'd need to check if schedule_in was passed correctly if we mocked Oban.Job better,
      # but for now we just check it exists.
      assert job.worker == "Cairnloop.Workers.OutboundWorker"
    end

    test "fails if template_id is missing" do
      assert_raise KeyError, fn ->
        Outbound.trigger(1, [])
      end
    end

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
      # WR-04: telemetry metadata is enum-only — `conversation_id`, `template_id`,
      # `actor`, and `schedule_in` MUST NOT leak into telemetry labels (those
      # are PII / high-cardinality and would explode Prometheus/Datadog labels).
      # The per-recipient durable Message row, the OutboundWorker job args, and
      # the auditor metadata carry those facts instead.
      assert metadata.outcome == :triggered
      refute Map.has_key?(metadata, :conversation_id)
      refute Map.has_key?(metadata, :template_id)
      refute Map.has_key?(metadata, :actor)
      refute Map.has_key?(metadata, :schedule_in)

      :telemetry.detach("test-outbound-handler")
    end

    test "integrates with auditor" do
      defmodule TestAuditor do
  @impl true
  def list_events(_opts), do: []

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
  end

  describe "trigger/2 with :bulk_envelope_id (Phase 25 additive opt)" do
    test "without :bulk_envelope_id, Phase 24 behavior is unchanged (additive-opt seal — D-12)" do
      assert {:ok, results} = Outbound.trigger(1, template_id: "recovery_v1")

      # Public observable shape is unchanged: :message + :delivery_job keys still emerge.
      assert results.message.role == :system_outbound
      assert results.message.conversation_id == 1
      assert results.message.metadata["template_id"] == "recovery_v1"
      assert results.delivery_job.worker == "Cairnloop.Workers.OutboundWorker"

      # Worker args now carry the Task 1 dedup keys (conversation_id + template_id);
      # bulk_envelope_id is either absent OR nil — both are acceptable Phase 24 shapes.
      args = results.delivery_job.args
      assert args["message_id"] == 999
      assert args["conversation_id"] == 1
      assert args["template_id"] == "recovery_v1"
      assert Map.get(args, "bulk_envelope_id") == nil
    end

    test "with :bulk_envelope_id, worker args carry all three dedup keys" do
      assert {:ok, results} =
               Outbound.trigger(1,
                 template_id: "recovery_v1",
                 bulk_envelope_id: "envelope-uuid"
               )

      args = results.delivery_job.args
      assert args["message_id"] == 999
      assert args["conversation_id"] == 1
      assert args["template_id"] == "recovery_v1"
      assert args["bulk_envelope_id"] == "envelope-uuid"
    end

    test "with :bulk_envelope_id, Message.metadata records the envelope correlation key" do
      assert {:ok, results} =
               Outbound.trigger(1,
                 template_id: "recovery_v1",
                 bulk_envelope_id: "envelope-uuid"
               )

      # Conversation timeline can correlate per-recipient cards back to the envelope row.
      assert results.message.metadata["bulk_envelope_id"] == "envelope-uuid"
      assert results.message.metadata["template_id"] == "recovery_v1"
      assert results.message.metadata["status"] == "pending"
    end

    test "without :bulk_envelope_id, Message.metadata does not assert a specific bulk_envelope_id" do
      assert {:ok, results} = Outbound.trigger(1, template_id: "recovery_v1")

      # Accept either absent OR nil — both shapes are acceptable per the plan.
      bulk_id = Map.get(results.message.metadata, "bulk_envelope_id")
      assert is_nil(bulk_id)
    end
  end

  describe "bulk_trigger/2" do
    alias Cairnloop.Outbound.BulkEnvelope

    test "happy path: returns {:ok, results} with envelope + N per-recipient inserts" do
      assert {:ok, results} =
               Outbound.bulk_trigger([1, 2, 3],
                 template_id: "recovery_v1",
                 rendered_body: "Hi, just checking in.",
                 actor: "agent_1"
               )

      # Envelope step
      env = results.envelope
      assert %BulkEnvelope{} = env
      assert env.count == 3
      assert env.recipient_conversation_ids == [1, 2, 3]
      assert env.rendered_body == "Hi, just checking in."
      assert env.template_id == "recovery_v1"
      assert env.status == :submitted
      assert is_binary(env.id)
      # UUID v4 shape: 36 chars with dashes at positions 8, 13, 18, 23.
      assert String.length(env.id) == 36
      assert String.at(env.id, 8) == "-"
      # WR-05: cap-at-decision-time snapshotted on the submitted row too,
      # so OBS-02 readers see the policy of the moment on both lanes.
      assert env.effective_cap == 25

      # Per-recipient steps — keys are :"message_<cid>" and :"delivery_job_<cid>".
      for cid <- [1, 2, 3] do
        assert msg = Map.get(results, :"message_#{cid}")
        assert msg.conversation_id == cid
        assert msg.metadata["bulk_envelope_id"] == env.id
        assert msg.metadata["template_id"] == "recovery_v1"

        assert job = Map.get(results, :"delivery_job_#{cid}")
        assert job.worker == "Cairnloop.Workers.OutboundWorker"
        assert job.args["conversation_id"] == cid
        assert job.args["template_id"] == "recovery_v1"
        assert job.args["bulk_envelope_id"] == env.id
      end
    end

    test "cap refusal at cap+1: returns {:error, :batch_too_large} and persists refusal envelope" do
      cap = 25
      ids = Enum.to_list(1..(cap + 1))

      assert {:error, :batch_too_large} =
               Outbound.bulk_trigger(ids,
                 template_id: "recovery_v1",
                 rendered_body: "Hi",
                 actor: "agent_1"
               )

      # The refusal envelope IS persisted (research Open Question 5; mirrors
      # Governance.propose_blocked posture so OBS-02 reads see both lanes).
      inserts = Process.get(:mock_repo_inserts, [])
      assert envelope = Enum.find(inserts, &match?(%BulkEnvelope{}, &1))
      assert envelope.status == :refused_cap_exceeded
      assert envelope.count == cap + 1
      assert envelope.recipient_conversation_ids == ids
      assert envelope.refused_reason == "batch_size #{cap + 1} exceeds cap #{cap}"
      # WR-05: cap-at-decision-time snapshotted on the refused row.
      assert envelope.effective_cap == cap

      # And NO per-recipient Message rows were inserted.
      messages = Enum.filter(inserts, &match?(%Cairnloop.Message{}, &1))
      assert messages == []
    end

    test "cap boundary OK at exactly cap=25" do
      ids = Enum.to_list(1..25)

      assert {:ok, results} =
               Outbound.bulk_trigger(ids,
                 template_id: "recovery_v1",
                 rendered_body: "Hi",
                 actor: "agent_1"
               )

      assert results.envelope.status == :submitted
      assert results.envelope.count == 25

      # 25 per-recipient message keys exist.
      for cid <- ids do
        assert Map.has_key?(results, :"message_#{cid}")
        assert Map.has_key?(results, :"delivery_job_#{cid}")
      end
    end

    test "snapshot persistence: rendered_body is exactly what the caller passed, no re-resolution" do
      Application.put_env(:cairnloop, :outbound_recovery_template_id, "v1")

      assert {:ok, results} =
               Outbound.bulk_trigger([1, 2],
                 template_id: "recovery_v1",
                 rendered_body: "Snapshotted body v1",
                 actor: "agent_1"
               )

      # Even after a config flip, the persisted envelope body MUST NOT change —
      # mirrors research Pitfall 2 regression test (snapshot at decision time).
      Application.put_env(:cairnloop, :outbound_recovery_template_id, "v2")

      assert results.envelope.rendered_body == "Snapshotted body v1"
    end

    test "envelope id threaded to per-recipient triggers" do
      assert {:ok, results} =
               Outbound.bulk_trigger([10, 20],
                 template_id: "recovery_v1",
                 rendered_body: "Hi",
                 actor: "agent_1"
               )

      env_id = results.envelope.id
      assert results[:delivery_job_10].args["bulk_envelope_id"] == env_id
      assert results[:delivery_job_20].args["bulk_envelope_id"] == env_id
      assert results[:message_10].metadata["bulk_envelope_id"] == env_id
      assert results[:message_20].metadata["bulk_envelope_id"] == env_id
    end

    test "configurable cap via :cairnloop, :max_batch_size env" do
      Application.put_env(:cairnloop, :max_batch_size, 3)

      # cap+1 → refused
      assert {:error, :batch_too_large} =
               Outbound.bulk_trigger([1, 2, 3, 4],
                 template_id: "recovery_v1",
                 rendered_body: "Hi",
                 actor: "agent_1"
               )

      # at cap → submitted
      assert {:ok, results} =
               Outbound.bulk_trigger([10, 20, 30],
                 template_id: "recovery_v1",
                 rendered_body: "Hi",
                 actor: "agent_1"
               )

      assert results.envelope.status == :submitted
      assert results.envelope.count == 3
      # WR-05: the snapshot tracks the cap that was tuned to 3 above, NOT the
      # v1 default of 25.
      assert results.envelope.effective_cap == 3
    end

    test "telemetry emits enum-only labels (D-B) on submitted happy path" do
      :telemetry.attach(
        "test-bulk-triggered-stop",
        [:cairnloop, :outbound, :bulk, :triggered, :stop],
        fn _event, measurements, metadata, _config ->
          send(self(), {:bulk_telemetry, measurements, metadata})
        end,
        nil
      )

      Outbound.bulk_trigger([1, 2, 3],
        template_id: "recovery_v1",
        rendered_body: "Hi",
        actor: "agent_1"
      )

      assert_receive {:bulk_telemetry, _measurements, metadata}
      assert metadata.outcome == :submitted
      assert metadata.count == 3

      # D-B: NO high-cardinality fields leak into telemetry labels.
      refute Map.has_key?(metadata, :template_id)
      refute Map.has_key?(metadata, :conversation_id)
      refute Map.has_key?(metadata, :actor)
      refute Map.has_key?(metadata, :recipient_conversation_ids)
      refute Map.has_key?(metadata, :bulk_envelope_id)

      :telemetry.detach("test-bulk-triggered-stop")
    end

    test "telemetry emits :refused_cap_exceeded outcome on cap refusal" do
      :telemetry.attach(
        "test-bulk-refused",
        [:cairnloop, :outbound, :bulk, :triggered],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:bulk_refused_telemetry, metadata})
        end,
        nil
      )

      Outbound.bulk_trigger(Enum.to_list(1..26),
        template_id: "recovery_v1",
        rendered_body: "Hi",
        actor: "agent_1"
      )

      assert_receive {:bulk_refused_telemetry, metadata}
      assert metadata.outcome == :refused_cap_exceeded
      assert metadata.count == 26
      # Same enum-only invariant on refusal.
      refute Map.has_key?(metadata, :template_id)
      refute Map.has_key?(metadata, :actor)

      :telemetry.detach("test-bulk-refused")
    end

    test "CR-02: refusal-envelope insert failure surfaces as :refused_cap_exceeded_audit_failed telemetry, still returns {:error, :batch_too_large}" do
      # Reproduces the CR-02 regression: previously
      # `_ = repo().insert(...)` in the refusal lane silently discarded the
      # insert result, so a Postgres outage or changeset error broke the
      # OBS-02 "refused attempts persist" guarantee with no observable
      # signal. Now the failure must:
      #   1. still return {:error, :batch_too_large} (operator copy unchanged),
      #   2. emit telemetry with outcome :refused_cap_exceeded_audit_failed
      #      so attached handlers can alert.
      :telemetry.attach(
        "test-bulk-refused-audit-failed",
        [:cairnloop, :outbound, :bulk, :triggered],
        fn _event, _measurements, metadata, _config ->
          send(self(), {:bulk_refused_audit_failed_telemetry, metadata})
        end,
        nil
      )

      # Force the next `repo().insert/1` (the refusal envelope) to fail.
      forced_changeset =
        BulkEnvelope.changeset(%BulkEnvelope{}, %{})
        |> Ecto.Changeset.add_error(:base, "forced failure for CR-02 test")

      Process.put(:mock_repo_force_insert_failure, forced_changeset)

      # cap+1 trips the refusal lane.
      assert {:error, :batch_too_large} =
               Outbound.bulk_trigger(Enum.to_list(1..26),
                 template_id: "recovery_v1",
                 rendered_body: "Hi",
                 actor: "agent_1"
               )

      assert_receive {:bulk_refused_audit_failed_telemetry, metadata}
      # Audit-failure path: distinct outcome so attached handlers can alert
      # on a broken OBS-02 invariant.
      assert metadata.outcome == :refused_cap_exceeded_audit_failed
      assert metadata.count == 26
      # Enum-only invariant still holds for the failure path (D-B).
      refute Map.has_key?(metadata, :template_id)
      refute Map.has_key?(metadata, :actor)

      # No BulkEnvelope row landed (the insert failed); the MockRepo records
      # nothing because the forced-failure short-circuits before the inserts
      # list mutation.
      inserts = Process.get(:mock_repo_inserts, [])
      assert Enum.all?(inserts, fn x -> not match?(%BulkEnvelope{}, x) end)

      :telemetry.detach("test-bulk-refused-audit-failed")
    end
  end

  describe "OI trace lane (Phase 26 D-03)" do
    alias Cairnloop.Outbound.BulkEnvelope

    # Phase 26 D-03: disjoint 4-segment trace path
    # [:cairnloop, :outbound, :trace, <event_atom>]. The bounded-metrics spans on
    # [:cairnloop, :outbound, :triggered, :start|:stop|:exception] and
    # [:cairnloop, :outbound, :bulk, :triggered, ...] are sealed (Phase 22/25
    # D-12 / D-14). This describe block proves the OI lane fires ALONGSIDE — never
    # replacing — those sealed spans across trigger/2, bulk_trigger_submit/6, and
    # all 3 arms of bulk_trigger_refused/6.

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

    test "trigger/2 happy path — :trigger_started fires GUARDRAIL with attribution refs",
         %{test: test_id} do
      attach_trace_handler(test_id, :trigger_started)

      Outbound.trigger(1, template_id: "test", actor: "operator_42")

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:conversation_id] == 1
      assert meta[:template_id] == "test"
      assert meta[:actor_id] == "operator_42"
      assert meta[:outcome] == :triggered
    end

    test "trigger/2 happy path — :trigger_completed fires GUARDRAIL after the sealed span",
         %{test: test_id} do
      attach_trace_handler(test_id, :trigger_completed)

      Outbound.trigger(1, template_id: "test", actor: "operator_42")

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:outcome] == :triggered
    end

    test "trigger/2 transaction failure — :trigger_failed fires GUARDRAIL with outcome :failed",
         %{test: test_id} do
      attach_trace_handler(test_id, :trigger_failed)

      # Force the MockRepo's transaction/1 to return {:error, _} so the inner span
      # observes a failure result without raising. This exercises the after-span
      # branch on {:error, _} → Traces.emit(:trigger_failed, outcome: :failed).
      Process.put(
        :mock_repo_force_transaction_failure,
        {:error, :message, :synthetic_failure, %{}}
      )

      _ = Outbound.trigger(1, template_id: "test", actor: "operator_42")

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:outcome] == :failed
    end

    test "trigger/2 rescue path — :trigger_failed fires GUARDRAIL with outcome :exception and reraises",
         %{test: test_id} do
      attach_trace_handler(test_id, :trigger_failed)

      # Force the MockRepo's transaction/1 to raise so the rescue path fires.
      Process.put(:mock_repo_force_transaction_raise, true)

      assert_raise RuntimeError, "boom", fn ->
        Outbound.trigger(1, template_id: "test", actor: "operator_42")
      end

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:outcome] == :exception,
             "rescue branch must emit outcome: :exception so the OI lane reflects the raise"
    end

    test "bulk_trigger submit path — :bulk_submitted fires GUARDRAIL inside the sealed span",
         %{test: test_id} do
      attach_trace_handler(test_id, :bulk_submitted)

      assert {:ok, _} =
               Outbound.bulk_trigger([1, 2],
                 template_id: "recovery_v1",
                 rendered_body: "Body",
                 actor: "op_99"
               )

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert is_binary(meta[:bulk_envelope_id])
      assert meta[:template_id] == "recovery_v1"
      assert meta[:actor_id] == "op_99"
      assert meta[:outcome] == :submitted
      # Bulk envelope is the unit of work; per-recipient OI traces fire from the worker.
      assert meta[:conversation_id] == nil

      # OI lane carries attribution refs only — `:count` is bounded-metrics' concern.
      refute Map.has_key?(meta, :count)
    end

    test "bulk_trigger refused arm A {:ok, _envelope} — :bulk_refused fires GUARDRAIL with :effective_cap",
         %{test: test_id} do
      attach_trace_handler(test_id, :bulk_refused)

      # cap+1 trips the refusal lane; default MockRepo.insert/1 returns {:ok, _envelope}.
      assert {:error, :batch_too_large} =
               Outbound.bulk_trigger(Enum.to_list(1..26),
                 template_id: "recovery_v1",
                 rendered_body: "Body",
                 actor: "op_99"
               )

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:outcome] == :refused_cap_exceeded
      assert meta[:effective_cap] == 25,
             ":effective_cap must be on :bulk_refused metadata (RESEARCH OQ3)"
      assert is_binary(meta[:bulk_envelope_id])
      assert meta[:template_id] == "recovery_v1"
      assert meta[:actor_id] == "op_99"
    end

    test "bulk_trigger refused arm B {:error, %Ecto.Changeset{}} — :bulk_refused fires GUARDRAIL with audit-failed outcome",
         %{test: test_id} do
      attach_trace_handler(test_id, :bulk_refused)

      # Force MockRepo.insert/1 to fail the refusal-envelope insert with a changeset.
      forced_changeset =
        BulkEnvelope.changeset(%BulkEnvelope{}, %{})
        |> Ecto.Changeset.add_error(:base, "forced changeset failure for D-03 arm B")

      Process.put(:mock_repo_force_insert_failure, forced_changeset)

      assert {:error, :batch_too_large} =
               Outbound.bulk_trigger(Enum.to_list(1..26),
                 template_id: "recovery_v1",
                 rendered_body: "Body",
                 actor: "op_99"
               )

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:outcome] == :refused_cap_exceeded_audit_failed
      assert meta[:effective_cap] == 25
    end

    test "bulk_trigger refused arm C `other` shape — :bulk_refused fires GUARDRAIL with audit-failed outcome",
         %{test: test_id} do
      attach_trace_handler(test_id, :bulk_refused)

      # Force MockRepo.insert/1 to return an unexpected shape — exercises the
      # `other ->` arm of the case repo().insert(...) block.
      Process.put(:mock_repo_force_insert_unexpected_shape, {:foo, :bar})

      assert {:error, :batch_too_large} =
               Outbound.bulk_trigger(Enum.to_list(1..26),
                 template_id: "recovery_v1",
                 rendered_body: "Body",
                 actor: "op_99"
               )

      assert_receive {:trace_metadata, meta}, 500
      assert meta["openinference.span.kind"] == "GUARDRAIL"
      assert meta[:outcome] == :refused_cap_exceeded_audit_failed
      assert meta[:effective_cap] == 25
    end
  end

  # ----------------------------------------------------------------------------
  # Phase 26 OBS-02 D-05 — auditor metadata shape regression.
  #
  # The audit-WRITE substrate already exists: `Outbound.trigger/2` line 95-98
  # calls `auditor.audit(:outbound_trigger, actor, %{conversation_id,
  # template_id})` and `bulk_trigger_submit/6` line 339-343 calls
  # `auditor.audit(:bulk_outbound_trigger, actor, %{bulk_envelope_id, count,
  # template_id})`. This describe block PINS the exact metadata key SET on
  # both lanes via `Map.keys |> Enum.sort()` equality + negative `refute
  # Map.has_key?` for PII-rich keys so a future refactor that drifts the
  # contract (e.g. accidentally adding `:rendered_body` or
  # `:recipient_conversation_ids` to the auditor metadata) fails loudly.
  #
  # Mitigates T-26-07 (audit-metadata drift / information-disclosure).
  # ----------------------------------------------------------------------------
  describe "auditor metadata shape regression (Phase 26 OBS-02 D-05)" do
    # MapShapeAuditor sends every audit call into the test process mailbox so
    # `assert_receive` can pin the metadata key set. Distinct from the Phase 22
    # `TestAuditor` block above (which is a positive integration probe via
    # `assert results.audit.metadata == ...`); this auditor's purpose is the
    # negative `refute Map.has_key?` assertion + sorted-key-set equality.
    #
    # The `Ecto.Multi.run/3` callback fires inside the test process (the
    # MockRepo's `execute_multi/2` runs the Multi synchronously in-process), so
    # `send(self(), ...)` lands in the test's mailbox. Mirrors the
    # `MockNotifier.on_outbound_triggered/2` pattern in
    # `test/cairnloop/workers/outbound_worker_test.exs`.
    defmodule MapShapeAuditor do
  @impl true
  def list_events(_opts), do: []

      @behaviour Cairnloop.Auditor
      def audit(multi, action, actor, metadata) do
        send(self(), {:audited, %{action: action, actor: actor, metadata: metadata}})

        Ecto.Multi.run(multi, :audit, fn _repo, _changes ->
          {:ok, :captured}
        end)
      end
    end

    test ":outbound_trigger metadata key set is exactly [:conversation_id, :template_id]" do
      assert {:ok, _results} =
               Outbound.trigger(1,
                 template_id: "test",
                 actor: "system",
                 auditor: MapShapeAuditor
               )

      assert_receive {:audited, %{action: :outbound_trigger, actor: "system", metadata: metadata}},
                     500

      assert Map.keys(metadata) |> Enum.sort() == [:conversation_id, :template_id]
      # Pinning the exact values too — defense against subtle drift.
      assert metadata == %{conversation_id: 1, template_id: "test"}
    end

    test ":bulk_outbound_trigger metadata key set is exactly [:bulk_envelope_id, :count, :template_id]" do
      assert {:ok, _results} =
               Outbound.bulk_trigger([1, 2],
                 template_id: "test",
                 rendered_body: "Body",
                 actor: "system",
                 auditor: MapShapeAuditor
               )

      assert_receive {:audited,
                      %{action: :bulk_outbound_trigger, actor: "system", metadata: metadata}},
                     500

      assert Map.keys(metadata) |> Enum.sort() == [:bulk_envelope_id, :count, :template_id]
      # The :bulk_envelope_id value is a UUID generated at runtime — check shape, not
      # exact equality.
      assert metadata.count == 2
      assert metadata.template_id == "test"
      assert is_binary(metadata.bulk_envelope_id)
    end

    test ":outbound_trigger metadata refutes PII-rich extras (T-26-07 mitigation)" do
      assert {:ok, _results} =
               Outbound.trigger(1,
                 template_id: "test",
                 actor: "system",
                 auditor: MapShapeAuditor
               )

      assert_receive {:audited, %{action: :outbound_trigger, metadata: metadata}}, 500

      # The narrow auditor metadata MUST NOT leak any of these keys — they
      # belong on the durable Message row, the worker job args, the
      # BulkEnvelope row, or telemetry (depending on the fact), NOT in the
      # auditor metadata which crosses the library boundary into the host's
      # audit log.
      refute Map.has_key?(metadata, :actor)
      refute Map.has_key?(metadata, :rendered_body)
      refute Map.has_key?(metadata, :bulk_envelope_id)
      refute Map.has_key?(metadata, :recipient_conversation_ids)
      refute Map.has_key?(metadata, :count)
    end

    test ":bulk_outbound_trigger metadata refutes PII-rich extras (T-26-07 mitigation)" do
      assert {:ok, _results} =
               Outbound.bulk_trigger([1, 2, 3],
                 template_id: "test",
                 rendered_body: "Body",
                 actor: "system",
                 auditor: MapShapeAuditor
               )

      assert_receive {:audited, %{action: :bulk_outbound_trigger, metadata: metadata}}, 500

      # Same narrow-metadata invariant on the bulk lane. The rendered body and
      # the recipient ids live on the durable BulkEnvelope row (D-13); they
      # MUST NOT leak through the auditor callback into the host's audit log.
      refute Map.has_key?(metadata, :rendered_body)
      refute Map.has_key?(metadata, :recipient_conversation_ids)
      refute Map.has_key?(metadata, :actor)
      refute Map.has_key?(metadata, :effective_cap)
    end
  end

  # Note: bulk_trigger/2's atomicity under transaction rollback (Ecto.Multi
  # guarantee — envelope row + N Message rows roll back together when any step
  # fails) is covered by the integration suite at
  # test/integration/bulk_trigger_atomicity_test.exs, which runs against real
  # Postgres in CI via `mix test.integration`.
end
