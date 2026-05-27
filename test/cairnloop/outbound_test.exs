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
      case Process.get(:mock_repo_force_insert_failure) do
        %Ecto.Changeset{} = forced ->
          Process.delete(:mock_repo_force_insert_failure)
          {:error, forced}

        _ ->
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
      execute_multi(multi, %{})
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

    test "emits telemetry on trigger" do
      :telemetry.attach(
        "test-outbound-handler",
        [:cairnloop, :outbound, :triggered, :stop],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )

      Outbound.trigger(1, template_id: "test")

      assert_receive {:telemetry_event, measurements, metadata}
      assert Map.has_key?(measurements, :duration)
      assert metadata.conversation_id == 1
      assert metadata.template_id == "test"

      :telemetry.detach("test-outbound-handler")
    end

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

  # ----------------------------------------------------------------------------
  # REPO-UNAVAILABLE — requires Cairnloop.Repo + Postgres. These tests genuinely
  # require Postgres round-trips and cannot run in this workspace (CLAUDE.md
  # D-16). Authored so they pass on a Postgres-available host via
  # `mix test.integration`.
  # ----------------------------------------------------------------------------
  describe "bulk_trigger/2 — Postgres integration" do
    @tag :integration
    # REPO-UNAVAILABLE
    test "bulk_trigger writes BulkEnvelope + N Message rows atomically (rollback on FK violation)" do
      # On a Postgres-available host:
      # 1. count_before = Repo.aggregate(BulkEnvelope, :count, :id)
      # 2. Call bulk_trigger with a list of conversation_ids where one id is
      #    intentionally non-existent so the per-recipient Message insert raises
      #    an FK violation against cairnloop_conversations.
      # 3. Assert the call returns {:error, _} and that
      #    Repo.aggregate(BulkEnvelope, :count, :id) == count_before
      #    (i.e., the envelope row was rolled back atomically with the failed
      #    Message inserts — Ecto.Multi atomicity guarantee).
      flunk("integration-only: requires Cairnloop.Repo + cairnloop_conversations FK")
    end
  end
end
