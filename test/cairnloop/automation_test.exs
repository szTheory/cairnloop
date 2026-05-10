defmodule Cairnloop.AutomationTest do
  use ExUnit.Case, async: false

  defmodule MockRepo do
    def get!(Cairnloop.Automation.Draft, id) do
      if id == 1 do
        %Cairnloop.Automation.Draft{
          id: 1,
          content: "draft content",
          status: :pending,
          conversation_id: 100
        }
      else
        raise Ecto.NoResultsError, queryable: Cairnloop.Automation.Draft
      end
    end

    def transaction(multi) do
      # Simulate a successful transaction
      # We extract the changes from the multi
      operations = Ecto.Multi.to_list(multi)
      
      # We can just return a dummy map based on what multi contains
      results = Enum.into(operations, %{}, fn 
        {name, {:insert, changeset, _}} -> 
          {name, Ecto.Changeset.apply_changes(changeset)}
        {name, {:update, changeset, _}} -> 
          {name, Ecto.Changeset.apply_changes(changeset)}
      end)
      
      {:ok, results}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    # attach telemetry handler
    parent = self()
    handler_id = "test-automation-#{System.unique_integer()}"
    
    :telemetry.attach_many(
      handler_id,
      [
        [:cairnloop, :automation, :draft, :approved],
        [:cairnloop, :automation, :draft, :discarded],
        [:cairnloop, :automation, :draft, :edited]
      ],
      fn name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, name, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Application.delete_env(:cairnloop, :repo)
    end)
    
    :ok
  end

  describe "approve_draft/1" do
    test "updates draft status to :approved, inserts Message with role :agent, and emits telemetry" do
      assert {:ok, result} = Cairnloop.Automation.approve_draft(1)
      
      assert %{status: :approved} = result.draft
      assert %{content: "draft content", role: :agent, conversation_id: 100} = result.message
      
      assert_receive {:telemetry_event, [:cairnloop, :automation, :draft, :approved], %{count: 1}, %{draft_id: 1}}
    end
  end

  describe "discard_draft/1" do
    test "updates draft status to :discarded and emits telemetry" do
      assert {:ok, result} = Cairnloop.Automation.discard_draft(1)
      
      assert %{status: :discarded} = result.draft
      
      assert_receive {:telemetry_event, [:cairnloop, :automation, :draft, :discarded], %{count: 1}, %{draft_id: 1}}
    end
  end

  describe "mark_draft_edited/1" do
    test "updates draft status to :edited and emits telemetry" do
      assert {:ok, result} = Cairnloop.Automation.mark_draft_edited(1)
      
      assert %{status: :edited} = result.draft
      
      assert_receive {:telemetry_event, [:cairnloop, :automation, :draft, :edited], %{count: 1}, %{draft_id: 1}}
    end
  end
end
