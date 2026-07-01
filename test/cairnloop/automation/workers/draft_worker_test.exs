defmodule Cairnloop.Automation.Workers.DraftWorkerTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Automation.Workers.DraftWorker

  defmodule MockRepo do
    def one(_query), do: Process.get(:latest_draft)
    def one(query, _opts), do: one(query)

    def transaction(multi) do
      # Simulate a successful transaction
      operations = Ecto.Multi.to_list(multi)

      results =
        Enum.into(operations, %{}, fn
          {name, {:insert, changeset, _}} ->
            {name, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)}

          {name, {:update, changeset, _}} ->
            {name, Ecto.Changeset.apply_changes(changeset)}
        end)

      {:ok, results}
    end

    def transaction(multi, _opts), do: transaction(multi)
  end

  defmodule RetrievalMock do
    def ground_for_draft(%{clarification_attempts: attempts} = context, opts)
        when attempts >= 1 do
      send(self(), {:ground_for_draft, context, opts})

      %{
        query: "Conversation",
        canonical_results: [],
        assistive_results: [%{source_type: :resolved_case, trust_level: :assistive}],
        evidence: [%{source_type: :resolved_case, trust_level: :assistive}],
        clarification_attempts: attempts,
        diagnostic: %{
          class: :policy_limit,
          reason: :clarification_limit_reached,
          canonical_hit_count: 0,
          assistive_hit_count: 1
        },
        grounding_assessment: %{status: :escalation, reason: :clarification_limit_reached}
      }
    end

    def ground_for_draft(context, opts) do
      send(self(), {:ground_for_draft, context, opts})

      %{
        query: "Conversation",
        canonical_results: [%{content: "Canonical answer"}],
        assistive_results: [],
        evidence: [%{source_type: :knowledge_base, trust_level: :canonical}],
        clarification_attempts: 0,
        diagnostic: %{
          class: :grounded,
          reason: :canonical_results,
          canonical_hit_count: 1,
          assistive_hit_count: 0
        },
        grounding_assessment: %{status: :strong, reason: :canonical_grounding}
      }
    end
  end

  defmodule ConversationLookupMock do
    def get!(conversation_id) do
      %Cairnloop.Conversation{id: conversation_id, host_user_id: "user_42"}
    end
  end

  defmodule GapRecorderMock do
    def record(attrs) do
      send(self(), {:gap_recorded, attrs})
      {:ok, attrs}
    end
  end

  defmodule StubGenerator do
    @behaviour Cairnloop.Automation.DraftGenerator
    @impl true
    def generate_draft(conversation_id, grounding_bundle) do
      send(self(), {:stub_generator_called, conversation_id})

      {:ok,
       %{
         proposal_type: :reply,
         operator_summary: "stub summary",
         customer_reply: "stub reply",
         content: "stub reply",
         evidence: Map.get(grounding_bundle, :evidence, []),
         grounding_metadata: %{grounding_status: :strong, reason: :stub, query: "q"},
         clarification_attempts: 0,
         conversation_id: conversation_id
       }}
    end
  end

  defmodule DraftOnlyPolicy do
    @behaviour Cairnloop.AutomationPolicy
    def decide(_proposal, _opts), do: :draft_only
  end

  defmodule DenyPolicy do
    @behaviour Cairnloop.AutomationPolicy
    def decide(_proposal, _opts), do: :deny
  end

  defmodule AllowPolicy do
    @behaviour Cairnloop.AutomationPolicy
    def decide(_proposal, _opts), do: :allow
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :retrieval_module, RetrievalMock)
    Application.put_env(:cairnloop, :conversation_lookup, &ConversationLookupMock.get!/1)
    Application.put_env(:cairnloop, :gap_recorder, GapRecorderMock)

    # Start PubSub for testing if not already started
    start_supervised({Phoenix.PubSub, name: Cairnloop.PubSub})

    handler_id = "draft-worker-test-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      [
        [:openinference, :span, :start],
        [:openinference, :span, :stop]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :automation_policy)
      Application.delete_env(:cairnloop, :retrieval_module)
      Application.delete_env(:cairnloop, :conversation_lookup)
      Application.delete_env(:cairnloop, :gap_recorder)
      Application.delete_env(:cairnloop, :draft_generator)
      Process.delete(:latest_draft)
      :telemetry.detach(handler_id)
    end)

    :ok
  end

  test "Worker executes :telemetry start and stop events with :openinference keys" do
    Application.put_env(:cairnloop, :automation_policy, DraftOnlyPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:123")

    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 123}})

    assert_receive {:telemetry_event, [:openinference, :span, :start], %{system_time: _},
                    %{trace_id: _, span_name: "DraftWorker", span_kind: "AGENT"}},
                   1000

    assert_receive {:telemetry_event, [:openinference, :span, :stop], %{duration: _},
                    %{status: :ok}},
                   1000
  end

  test "Worker queries AutomationPolicy and respects :draft_only by inserting a draft" do
    Application.put_env(:cairnloop, :automation_policy, DraftOnlyPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:124")

    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 124}})

    assert_received {:ground_for_draft, %{host_surface: "conversation", host_user_id: "user_42"},
                     [
                       surface: :draft_generation,
                       host_surface: "conversation",
                       host_user_id: "user_42"
                     ]}

    assert_receive {:draft_created, 999}, 1000
  end

  test "Worker respects :deny by NOT inserting a draft" do
    Application.put_env(:cairnloop, :automation_policy, DenyPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:125")

    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 125}})

    refute_receive {:draft_created, _}, 500
  end

  test "Worker queries AutomationPolicy and respects :allow by inserting an approved draft" do
    Application.put_env(:cairnloop, :automation_policy, AllowPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:126")

    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 126}})

    assert_receive {:draft_created, 999}, 1000
  end

  test "Worker uses the configured :draft_generator seam (defaults to ScoriaEngine)" do
    Application.put_env(:cairnloop, :automation_policy, DraftOnlyPolicy)
    Application.put_env(:cairnloop, :draft_generator, StubGenerator)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:128")

    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 128}})

    # The configured generator was invoked for this conversation, not the hardcoded engine.
    assert_received {:stub_generator_called, 128}
    assert_receive {:draft_created, 999}, 1000
  end

  test "Worker escalates after one failed clarification turn instead of looping" do
    Application.put_env(:cairnloop, :automation_policy, DraftOnlyPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:127")

    Process.put(:latest_draft, %Cairnloop.Automation.Draft{
      id: 50,
      proposal_type: :clarification,
      clarification_attempts: 1,
      conversation_id: 127
    })

    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 127}})

    assert_received {:gap_recorded,
                     %{
                       surface: :draft_generation,
                       outcome_class: :policy_limit,
                       reason: :clarification_limit_reached,
                       host_user_id: "user_42",
                       tenant_scope: :host_user_scoped,
                       ui_surface: "conversation",
                       assistive_hit_count: 1
                     }}

    assert_receive {:draft_created, 999}, 1000
  end
end
