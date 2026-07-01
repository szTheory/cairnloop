defmodule Cairnloop.Workers.ApprovalExpiryWorkerTest do
  use ExUnit.Case, async: false

  # ---------------------------------------------------------------------------
  # Module-under-test reference
  # ---------------------------------------------------------------------------

  alias Cairnloop.Workers.ApprovalExpiryWorker

  # ---------------------------------------------------------------------------
  # MockRepo — mirrors sla_countdown_worker_test.exs pattern
  #
  # Approval fixtures:
  #   1 → :pending   (should be flipped to :expired)
  #   2 → :approved  (already resolved — no-op)
  #   3 → nil        (deleted — no-op)
  # ---------------------------------------------------------------------------

  defmodule MockRepo do
    # Approval id 1: :pending — should flip to :expired
    def get(tool_approval_module, 1)
        when tool_approval_module == Cairnloop.Governance.ToolApproval do
      record_repo_call(:get, tool_approval_module, [])

      struct(tool_approval_module, %{
        id: 1,
        status: :pending,
        tool_proposal_id: 10,
        expires_at: ~U[2020-01-01 00:00:00Z]
      })
    end

    # Approval id 2: :approved — already resolved
    def get(tool_approval_module, 2)
        when tool_approval_module == Cairnloop.Governance.ToolApproval do
      record_repo_call(:get, tool_approval_module, [])

      struct(tool_approval_module, %{
        id: 2,
        status: :approved,
        tool_proposal_id: 10,
        expires_at: ~U[2020-01-01 00:00:00Z]
      })
    end

    # Approval id 3: nil — deleted
    def get(tool_approval_module, 3)
        when tool_approval_module == Cairnloop.Governance.ToolApproval do
      record_repo_call(:get, tool_approval_module, [])
      _ = tool_approval_module
      nil
    end

    def get(schema, id, opts) do
      record_repo_call(:get, schema, opts)
      get(schema, id)
    end

    def update(changeset, opts \\ []) do
      record_repo_call(:update, schema_from_changeset(changeset), opts)
      send(self(), {:repo_update, changeset})
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

    def insert(changeset, opts \\ []) do
      record_repo_call(:insert, schema_from_changeset(changeset), opts)
      send(self(), {:repo_insert, changeset})
      {:ok, Ecto.Changeset.apply_changes(changeset)}
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

  defp assert_prefixed_repo_call!(schema, operation) do
    assert Enum.any?(Process.get(:repo_calls, []), fn call ->
             call.schema == schema and call.operation == operation and
               Keyword.get(call.opts, :prefix) == "cairnloop"
           end),
           "expected #{inspect(operation)} #{inspect(schema)} call to use prefix: \"cairnloop\"; got #{inspect(Process.get(:repo_calls, []))}"
  end

  # ---------------------------------------------------------------------------
  # describe: :pending → :expired flip + event (15-VALIDATION row 15-03-e)
  #
  # Mirrors SlaCountdownWorker :active → :breached flip idiom (D15-12).
  # ---------------------------------------------------------------------------

  describe "perform/1 — :pending → :expired flip (15-03-e)" do
    test "flips :pending approval to :expired" do
      assert :ok = ApprovalExpiryWorker.perform(%Oban.Job{args: %{"approval_id" => 1}})
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :expired

      assert_prefixed_repo_call!(Cairnloop.Governance.ToolApproval, :get)
      assert_prefixed_repo_call!(Cairnloop.Governance.ToolApproval, :update)
    end

    test "inserts a :expired ToolActionEvent after flipping status" do
      assert :ok = ApprovalExpiryWorker.perform(%Oban.Job{args: %{"approval_id" => 1}})
      assert_receive {:repo_insert, event_changeset}
      event = Ecto.Changeset.apply_changes(event_changeset)
      assert event.event_type == :expired

      assert_prefixed_repo_call!(Cairnloop.Governance.ToolActionEvent, :insert)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: already-resolved and deleted approvals → :ok no-op
  # (mirrors SlaCountdownWorker catch-all behavior)
  # ---------------------------------------------------------------------------

  describe "perform/1 — already-resolved or deleted approval → :ok no-op" do
    test "no-ops gracefully for already-resolved approval (status :approved)" do
      assert :ok = ApprovalExpiryWorker.perform(%Oban.Job{args: %{"approval_id" => 2}})
      refute_receive {:repo_update, _}
    end

    test "no-ops gracefully for missing approval (nil — deleted)" do
      assert :ok = ApprovalExpiryWorker.perform(%Oban.Job{args: %{"approval_id" => 3}})
      refute_receive {:repo_update, _}
    end
  end
end
