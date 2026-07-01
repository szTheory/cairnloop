defmodule Cairnloop.Workers.SlaCountdownWorkerTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Workers.SlaCountdownWorker
  alias Cairnloop.Conversations.SLA

  defmodule MockRepo do
    def get(SLA, 1) do
      record_repo_call(:get, SLA, [])

      %SLA{id: 1, status: :active, target_type: :first_response, target_at: DateTime.utc_now()}
    end

    def get(SLA, 2) do
      record_repo_call(:get, SLA, [])

      %SLA{
        id: 2,
        status: :fulfilled,
        target_type: :first_response,
        target_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      }
    end

    def get(SLA, 3) do
      record_repo_call(:get, SLA, [])
      nil
    end

    def get(schema, id, opts) do
      record_repo_call(:get, schema, opts)
      get(schema, id)
    end

    def update!(changeset, opts \\ []) do
      record_repo_call(:update!, schema_from_changeset(changeset), opts)
      send(self(), {:repo_update, changeset})
      Ecto.Changeset.apply_changes(changeset)
    end

    defp schema_from_changeset(%Ecto.Changeset{data: %{__struct__: schema}}), do: schema

    defp record_repo_call(operation, schema, opts) do
      calls = Process.get(:repo_calls, [])
      Process.put(:repo_calls, calls ++ [%{operation: operation, schema: schema, opts: opts}])
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.put(:repo_calls, [])

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Process.delete(:repo_calls)
    end)

    :ok
  end

  test "marks an :active SLA as :breached and sets completed_at to now" do
    assert :ok = SlaCountdownWorker.perform(%Oban.Job{args: %{"sla_id" => 1}})

    assert_receive {:repo_update, changeset}
    assert Ecto.Changeset.get_change(changeset, :status) == :breached
    assert Ecto.Changeset.get_change(changeset, :completed_at) != nil

    assert Enum.any?(Process.get(:repo_calls, []), fn call ->
             call.schema == SLA and call.operation == :get and
               Keyword.get(call.opts, :prefix) == "cairnloop"
           end)

    assert Enum.any?(Process.get(:repo_calls, []), fn call ->
             call.schema == SLA and call.operation == :update! and
               Keyword.get(call.opts, :prefix) == "cairnloop"
           end)
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
