defmodule Cairnloop.Automation.Workers.DraftWorkerTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Automation.Workers.DraftWorker

  defmodule MockRepo do
    def transaction(multi) do
      # Simulate a successful transaction
      operations = Ecto.Multi.to_list(multi)
      
      results = Enum.into(operations, %{}, fn 
        {name, {:insert, changeset, _}} -> 
          {name, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)}
        {name, {:update, changeset, _}} -> 
          {name, Ecto.Changeset.apply_changes(changeset)}
      end)
      
      {:ok, results}
    end
  end

  defmodule DraftOnlyPolicy do
    @behaviour SupportOS.AutomationPolicy
    def decide(_proposal, _opts), do: :draft_only
  end

  defmodule DenyPolicy do
    @behaviour SupportOS.AutomationPolicy
    def decide(_proposal, _opts), do: :deny
  end
  
  defmodule AllowPolicy do
    @behaviour SupportOS.AutomationPolicy
    def decide(_proposal, _opts), do: :allow
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    
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
      :telemetry.detach(handler_id)
    end)
    
    :ok
  end

  test "Worker executes :telemetry start and stop events with :openinference keys" do
    Application.put_env(:cairnloop, :automation_policy, DraftOnlyPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:123")
    
    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 123}})
    
    assert_receive {:telemetry_event, [:openinference, :span, :start], %{system_time: _}, %{trace_id: _, span_name: "DraftWorker", span_kind: "AGENT"}}, 1000
    assert_receive {:telemetry_event, [:openinference, :span, :stop], %{duration: _}, %{status: :ok}}, 1000
  end

  test "Worker queries AutomationPolicy and respects :draft_only by inserting a draft" do
    Application.put_env(:cairnloop, :automation_policy, DraftOnlyPolicy)
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:124")
    
    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 124}})
    
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
end