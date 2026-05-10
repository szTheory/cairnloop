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

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    
    # Start PubSub for testing if not already started
    start_supervised({Phoenix.PubSub, name: Cairnloop.PubSub})
    
    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)
    
    :ok
  end

  test "performs successfully and broadcasts event" do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:123")
    
    assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 123}})
    
    assert_receive {:draft_created, 999}, 2000
  end
end
