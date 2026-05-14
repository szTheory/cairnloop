defmodule Cairnloop.Workers.SlaCountdownWorkerTest do
  use ExUnit.Case, async: false
  
  alias Cairnloop.Workers.SlaCountdownWorker
  alias Cairnloop.Conversations.SLA

  defmodule MockRepo do
    def get(SLA, 1) do
      %SLA{id: 1, status: :active, target_type: :first_response, target_at: DateTime.utc_now()}
    end
    
    def get(SLA, 2) do
      %SLA{id: 2, status: :fulfilled, target_type: :first_response, target_at: DateTime.utc_now(), completed_at: DateTime.utc_now()}
    end
    
    def get(SLA, 3) do
      nil
    end

    def update!(changeset) do
      send(self(), {:repo_update, changeset})
      Ecto.Changeset.apply_changes(changeset)
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
    :ok
  end

  test "marks an :active SLA as :breached and sets completed_at to now" do
    assert :ok = SlaCountdownWorker.perform(%Oban.Job{args: %{"sla_id" => 1}})
    
    assert_receive {:repo_update, changeset}
    assert Ecto.Changeset.get_change(changeset, :status) == :breached
    assert Ecto.Changeset.get_change(changeset, :completed_at) != nil
  end

  test "returns :ok without modifications if the SLA is already :fulfilled or :breached" do
    assert :ok = SlaCountdownWorker.perform(%Oban.Job{args: %{"sla_id" => 2}})
    refute_receive {:repo_update, _}
  end

  test "gracefully handles missing SLA records (no-op)" do
    assert :ok = SlaCountdownWorker.perform(%Oban.Job{args: %{"sla_id" => 3}})
    refute_receive {:repo_update, _}
  end
end
