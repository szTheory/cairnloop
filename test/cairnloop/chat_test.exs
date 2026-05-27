defmodule Cairnloop.ChatTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Chat
  alias Cairnloop.Conversations.SLA

  defmodule MockRepo do
    def get!(Cairnloop.Conversation, id) do
      if id in [1, 2] do
        %Cairnloop.Conversation{
          id: id,
          status: :open,
          subject: "Billing issue",
          host_user_id: 10,
          inserted_at: DateTime.utc_now() |> DateTime.add(-100, :second)
        }
      else
        raise Ecto.NoResultsError, queryable: Cairnloop.Conversation
      end
    end

    def transaction(multi) do
      execute_multi(multi, %{})
    end

    defp execute_multi(multi, acc) do
      operations = Ecto.Multi.to_list(multi)

      Enum.reduce_while(operations, {:ok, acc}, fn
        {name, {:insert, changeset, _}}, {:ok, results} ->
          result = Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)
          {:cont, {:ok, Map.put(results, name, result)}}

        {name, {:update, changeset, _}}, {:ok, results} ->
          result = Ecto.Changeset.apply_changes(changeset)
          {:cont, {:ok, Map.put(results, name, result)}}

        {name, %Oban.Job{} = job}, {:ok, results} ->
          {:cont, {:ok, Map.put(results, name, job)}}

        {name, {:run, run_fn}}, {:ok, results} ->
          {:ok, result} = run_fn.(__MODULE__, results)
          {:cont, {:ok, Map.put(results, name, result)}}

        {_name, {:merge, merge_fn}}, {:ok, results} ->
          merged_multi = merge_fn.(results)

          case execute_multi(merged_multi, results) do
            {:ok, new_results} -> {:cont, {:ok, new_results}}
            error -> {:halt, error}
          end
      end)
    end

    # Phase 28: top-level insert/1 for new single-row facade functions (create_customer_conversation/1
    # and ingest_widget_message/2). These do NOT go through Multi, so the Multi reducer above
    # doesn't cover them. Shape mirrors the inside-Multi :insert case.
    def insert(changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)}
    end

    # Phase 28 Plan 03: get/2 for tolerant message lookup (NOT get!/2).
    # Used by Chat.get_message/1 in the ChatLive role-dedup branch (Pitfall 7).
    def get(Cairnloop.Message, 1),
      do: %Cairnloop.Message{id: 1, role: :agent, content: "operator reply", conversation_id: 1}

    def get(Cairnloop.Message, 2),
      do: %Cairnloop.Message{id: 2, role: :user, content: "customer message", conversation_id: 1}

    def get(Cairnloop.Message, _id), do: nil

    def update(changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

    def one(%Ecto.Query{}) do
      Process.get(:mock_sla)
    end

    def preload(%Cairnloop.Conversation{} = conversation, :messages) do
      messages =
        Process.get(:mock_messages, [
          %Cairnloop.Message{id: 1, role: :user, content: "The billing export failed."},
          %Cairnloop.Message{
            id: 2,
            role: :agent,
            content: "We regenerated the export and confirmed it works now."
          }
        ])

      %{conversation | messages: messages}
    end
  end

  # Phase 28: ensure Cairnloop.PubSub is available for the new broadcast tests.
  # test_helper.exs only starts Cairnloop.PubSub under :integration; the headless suite
  # needs a per-suite instance via start_supervised! (tolerates already_started gracefully).
  setup_all do
    case start_supervised({Phoenix.PubSub, name: Cairnloop.PubSub}) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.delete(:mock_sla)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  describe "reply_to_conversation/3" do
    test "inserts message and job when role is :user" do
      assert {:ok, results} = Chat.reply_to_conversation(1, "hello", :user)
      assert %{content: "hello", role: :user, conversation_id: 1} = results.message
      assert %{status: :open, resolved_at: nil} = results.conversation

      assert job = results.draft_job
      assert job.worker == "Cairnloop.Automation.Workers.DraftWorker"
      assert job.args == %{"conversation_id" => 1}

      assert sla = results.new_sla
      assert sla.target_type == :first_response
      assert sla.status == :active

      assert sla_job = results.sla_job
      assert sla_job.worker == "Cairnloop.Workers.SlaCountdownWorker"
      assert sla_job.args == %{"sla_id" => 999}
    end

    test "user message does not create duplicate SLA if one is active" do
      Process.put(:mock_sla, %SLA{id: 5, conversation_id: 2, status: :active})

      assert {:ok, results} = Chat.reply_to_conversation(2, "hello again", :user)
      refute Map.has_key?(results, :new_sla)
      refute Map.has_key?(results, :sla_job)
    end

    test "inserts message but no draft job when role is :agent, fulfills active SLA and creates resolution SLA" do
      Process.put(:mock_sla, %SLA{id: 5, conversation_id: 1, status: :active})

      assert {:ok, results} = Chat.reply_to_conversation(1, "hello again", :agent)
      assert %{content: "hello again", role: :agent, conversation_id: 1} = results.message

      refute Map.has_key?(results, :draft_job)

      assert fulfilled_sla = results.fulfill_sla
      assert fulfilled_sla.status == :fulfilled
      assert fulfilled_sla.completed_at != nil

      assert new_sla = results.new_sla
      assert new_sla.target_type == :resolution
      assert new_sla.status == :active

      assert sla_job = results.sla_job
      assert sla_job.worker == "Cairnloop.Workers.SlaCountdownWorker"
      assert sla_job.args == %{"sla_id" => 999}
    end
  end

  describe "resolve_conversation/2" do
    test "sets status to :resolved, fulfills any active SLA, and inserts system message" do
      Process.put(:mock_sla, %SLA{id: 5, conversation_id: 1, status: :active})

      actor = %{type: "user", id: 1}
      assert {:ok, results} = Chat.resolve_conversation(1, resolved_by: actor)
      conversation = results.conversation
      assert conversation.status == :resolved
      assert conversation.resolved_at != nil
      assert %DateTime{} = conversation.resolved_at

      assert fulfilled_sla = results.fulfill_sla
      assert fulfilled_sla.status == :fulfilled
      assert fulfilled_sla.completed_at != nil

      assert %{
               content: "Please rate your experience.",
               role: :system,
               conversation_id: 1,
               metadata: %{"type" => "csat_request"}
             } = results.system_message
    end

    test "requires resolved_by in options and emits telemetry" do
      actor = %{type: "system", id: "system"}

      :telemetry.attach(
        "test-resolve-handler",
        [:cairnloop, :conversation, :resolve, :stop],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )

      :telemetry.attach(
        "test-resolved-domain-handler",
        [:cairnloop, :conversation, :resolved],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_domain_event, measurements, metadata})
        end,
        nil
      )

      assert {:ok, _} = Chat.resolve_conversation(1, resolved_by: actor, custom_meta: "foo")

      assert_receive {:telemetry_event, measurements, metadata}
      assert Map.has_key?(measurements, :duration)
      assert metadata.actor == actor
      assert metadata.metadata[:custom_meta] == "foo"
      assert metadata.conversation_id == 1

      assert_receive {:telemetry_domain_event, domain_measurements, domain_metadata}
      assert domain_measurements.duration_seconds >= 100
      assert domain_measurements.count == 1
      assert domain_metadata.actor == actor
      assert domain_metadata.metadata[:custom_meta] == "foo"
      assert domain_metadata.conversation_id == 1
      assert %Cairnloop.Conversation{id: 1, status: :resolved} = domain_metadata.conversation

      :telemetry.detach("test-resolve-handler")
      :telemetry.detach("test-resolved-domain-handler")
    end

    test "enqueues the NotifyResolvedWorker job" do
      actor = %{type: "user", id: 2}
      assert {:ok, results} = Chat.resolve_conversation(1, resolved_by: actor, custom_meta: "foo")

      assert job = results.notify_job
      assert job.worker == "Cairnloop.Workers.NotifyResolvedWorker"
      assert job.args == %{"conversation_id" => 1, "metadata" => %{custom_meta: "foo"}}
    end

    test "enqueues the resolved-case retrieval indexing job" do
      actor = %{type: "user", id: 2}
      assert {:ok, results} = Chat.resolve_conversation(1, resolved_by: actor, custom_meta: "foo")

      assert job = results.resolved_case_index_job
      assert job.worker == "Cairnloop.Retrieval.Workers.IndexResolvedConversation"
      assert job.args == %{"conversation_id" => 1, "metadata" => %{custom_meta: "foo"}}
    end
  end

  describe "submit_csat/2" do
    test "updates csat_rating and emits telemetry" do
      :telemetry.attach(
        "test-csat-handler",
        [:cairnloop, :feedback, :csat, :stop],
        fn _event, measurements, metadata, _config ->
          send(self(), {:csat_telemetry, measurements, metadata})
        end,
        nil
      )

      assert {:ok, conversation} = Chat.submit_csat(1, "positive")
      assert conversation.csat_rating == :positive

      assert_receive {:csat_telemetry, measurements, metadata}
      assert Map.has_key?(measurements, :duration)
      assert metadata.conversation_id == 1
      assert metadata.rating == "positive"

      :telemetry.detach("test-csat-handler")
    end
  end

  describe "auditor integration" do
    defmodule TestAuditor do
      @behaviour Cairnloop.Auditor

      @impl true
      def audit(multi, action, actor, metadata) do
        Ecto.Multi.run(multi, :audit, fn _repo, _changes ->
          {:ok, %{action: action, actor: actor, metadata: metadata}}
        end)
      end
    end

    test "reply_to_conversation/4 injects auditor" do
      assert {:ok, results} =
               Chat.reply_to_conversation(1, "hello", :agent,
                 actor: "agent_smith",
                 auditor: TestAuditor
               )

      assert %{
               action: :reply_to_conversation,
               actor: "agent_smith",
               metadata: %{conversation_id: 1}
             } = results.audit
    end

    test "resolve_conversation/2 injects auditor" do
      assert {:ok, results} =
               Chat.resolve_conversation(1, resolved_by: "agent_smith", auditor: TestAuditor)

      assert %{
               action: :resolve_conversation,
               actor: "agent_smith",
               metadata: %{conversation_id: 1}
             } = results.audit
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 28 D-05: create_customer_conversation/1
  # ---------------------------------------------------------------------------

  describe "create_customer_conversation/1" do
    test "inserts conversation with status :open, subject default \"Customer chat\", and host_user_id from attrs" do
      assert {:ok, %Cairnloop.Conversation{status: :open, subject: "Customer chat", host_user_id: "demo_customer"}} =
               Chat.create_customer_conversation(%{host_user_id: "demo_customer"})
    end

    test "broadcasts {:conversations_changed} on \"conversations\" topic" do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
      {:ok, _conversation} = Chat.create_customer_conversation(%{host_user_id: "demo_customer"})
      assert_receive {:conversations_changed}, 200
    end

    test "accepts a custom subject when provided" do
      assert {:ok, %Cairnloop.Conversation{subject: "Help me"}} =
               Chat.create_customer_conversation(%{host_user_id: "demo_customer", subject: "Help me"})
    end

    # Test 3 (error branch) not implemented in headless suite: would require
    # MockRepo.insert/1 to return {:error, changeset} on demand, which requires
    # significant process-dictionary plumbing. The error branch is identical in
    # shape to existing facade functions — omitted per plan guidance.
    # # REPO-UNAVAILABLE: error path not exercised in headless suite
  end

  # ---------------------------------------------------------------------------
  # Phase 28 D-06: ingest_widget_message/2
  # ---------------------------------------------------------------------------

  describe "ingest_widget_message/2" do
    test "inserts :user-role message via the Message changeset (NOT reply_to_conversation)" do
      assert {:ok, result} = Chat.ingest_widget_message(1, "hi")
      assert %Cairnloop.Message{role: :user, content: "hi", conversation_id: 1} = result
      # Negative assertion: the return value does NOT contain a :draft_job key —
      # proves we are NOT on the reply_to_conversation/4 :user path (which enqueues DraftWorker).
      refute Map.has_key?(result, :draft_job)
    end

    test "broadcasts {:message_created, id} on conversation topic" do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:1")
      {:ok, _message} = Chat.ingest_widget_message(1, "hi")
      assert_receive {:message_created, _msg_id}, 200
    end

    test "also broadcasts {:conversations_changed} on conversations topic" do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
      {:ok, _message} = Chat.ingest_widget_message(1, "hi")
      assert_receive {:conversations_changed}, 200
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 28 Plan 03: get_message/1 read-side facade
  # ---------------------------------------------------------------------------

  describe "get_message/1" do
    test "returns the message struct for a known id" do
      assert %Cairnloop.Message{id: 1, role: :agent} = Chat.get_message(1)
    end

    test "returns a :user-role message for a known id" do
      assert %Cairnloop.Message{id: 2, role: :user} = Chat.get_message(2)
    end

    test "returns nil for an unknown id" do
      assert nil == Chat.get_message(999)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 28 OQ-1: reply_to_conversation/4 additive broadcast
  # ---------------------------------------------------------------------------

  describe "reply_to_conversation/4 broadcast (OQ-1)" do
    test "post-commit broadcasts {:message_created, msg_id} on conversation topic" do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:1")
      {:ok, _results} = Chat.reply_to_conversation(1, "operator reply", :agent)
      assert_receive {:message_created, msg_id}, 200
      # MockRepo.insert/1 (inside Multi) always sets id: 999
      assert msg_id == 999
    end

    test "does not change the sealed :user role + DraftWorker insertion semantics" do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:1")
      assert {:ok, results} = Chat.reply_to_conversation(1, "user message", :user)

      # Sealed contract: DraftWorker is still enqueued for :user branch
      assert results.draft_job.worker == "Cairnloop.Automation.Workers.DraftWorker"
      assert results.message.role == :user

      # OQ-1 broadcast fires for :user branch too (broadcast is outside the if role == :user block)
      assert_receive {:message_created, _msg_id}, 200
    end

    test "the additive broadcast does NOT change the function's return shape" do
      # Trailing-expression invariant guard: if the OQ-1 case accidentally became the
      # Telemetry.span lambda's last expression, the function would return :ok (from
      # broadcast_safely/2) instead of the {:ok, results} tuple. This test locks it.
      assert {:ok, results} = Chat.reply_to_conversation(1, "operator reply", :agent)
      assert %Cairnloop.Message{} = results.message
      # Return is {:ok, map_with_message}, NOT :ok from the broadcast helper
    end
  end
end
