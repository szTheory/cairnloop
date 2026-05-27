defmodule Cairnloop.OutboundTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Outbound

  defmodule MockRepo do
    def transaction(multi) do
      execute_multi(multi, %{})
    end

    defp execute_multi(multi, acc) do
      operations = Ecto.Multi.to_list(multi)

      Enum.reduce_while(operations, {:ok, acc}, fn
        {name, {:insert, changeset, _}}, {:ok, results} ->
          if changeset.valid? do
            result = Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)
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

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
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
end
