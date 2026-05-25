defmodule Cairnloop.Workers.ToolExecutionWorkerTest do
  @moduledoc """
  Unit tests for `Cairnloop.Workers.ToolExecutionWorker` (Phase 16 / ACT-01).

  Uses the same MockRepo pattern as `approval_resume_worker_test.exs` — no live
  Postgres required. Integration-level DB-backed proof lives in
  `test/integration/tool_execution_worker_test.exs` (requires `mix test.integration`).

  ## MockRepo fixture map
    - Approval id 10 → :execution_pending, proposal 100 (PassTool, valid input)
    - Approval id 11 → :execution_pending, proposal 100 — result_state already :succeeded (LAYER-2 guard)
    - Approval id 12 → :executed (terminal — no-op)
    - Approval id 13 → nil (deleted — no-op)
    - Approval id 14 → :execution_pending, proposal 110 (ScopeFailTool — re-validation fails)
    - Approval id 15 → :pending (wrong status — no-op)
    - Approval id 16 → :execution_pending, proposal 120 (FailRunTool — run/3 always {:error, _})
  """
  use ExUnit.Case, async: false

  alias Cairnloop.Workers.ToolExecutionWorker

  # ---------------------------------------------------------------------------
  # Test tools
  # ---------------------------------------------------------------------------

  defmodule OkRunTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "OK Run",
      description: "run/3 always returns {:ok, %{message_id: 999}}."

    embedded_schema do
      field(:content, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs), do: Ecto.Changeset.cast(struct, attrs, [:content])

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{message_id: 999}}

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  defmodule ScopeFailTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Scope Fail",
      description: "Requires :admin_scope — will fail scope check."

    embedded_schema do
      field(:data, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs), do: Ecto.Changeset.cast(struct, attrs, [:data])

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    @impl Cairnloop.Tool
    def scope, do: [:admin_scope]

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  defmodule FailRunTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Fail Run",
      description: "run/3 always returns {:error, :db_hiccup}."

    embedded_schema do
      field(:content, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs), do: Ecto.Changeset.cast(struct, attrs, [:content])

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:error, :db_hiccup}

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  # ---------------------------------------------------------------------------
  # MockRepo
  # ---------------------------------------------------------------------------

  alias Cairnloop.Governance.{ToolApproval, ToolProposal}

  defmodule MockRepo do
    alias Cairnloop.Governance.{ToolApproval, ToolProposal}

    # Approval id 10 → :execution_pending (normal happy path, OkRunTool)
    def get(ToolApproval, 10) do
      struct(ToolApproval, %{id: 10, status: :execution_pending, tool_proposal_id: 100, expires_at: nil})
    end

    # Approval id 11 → :execution_pending (but proposal already :succeeded — LAYER-2 terminal guard)
    def get(ToolApproval, 11) do
      struct(ToolApproval, %{id: 11, status: :execution_pending, tool_proposal_id: 101, expires_at: nil})
    end

    # Approval id 12 → :executed (already terminal — no-op)
    def get(ToolApproval, 12) do
      struct(ToolApproval, %{id: 12, status: :executed, tool_proposal_id: 100, expires_at: nil})
    end

    # Approval id 13 → nil (deleted)
    def get(ToolApproval, 13), do: nil

    # Approval id 14 → :execution_pending (ScopeFailTool — re-validation fails)
    def get(ToolApproval, 14) do
      struct(ToolApproval, %{id: 14, status: :execution_pending, tool_proposal_id: 110, expires_at: nil})
    end

    # Approval id 15 → :pending (wrong status — no-op)
    def get(ToolApproval, 15) do
      struct(ToolApproval, %{id: 15, status: :pending, tool_proposal_id: 100, expires_at: nil})
    end

    # Approval id 16 → :execution_pending (FailRunTool — run/3 always {:error, _})
    def get(ToolApproval, 16) do
      struct(ToolApproval, %{id: 16, status: :execution_pending, tool_proposal_id: 120, expires_at: nil})
    end

    # Fallback catch-all
    def get(_, _), do: nil

    # Proposal id 100: OkRunTool, result_state :not_executed
    def get!(ToolProposal, 100) do
      struct(ToolProposal, %{
        id: 100,
        tool_ref: Atom.to_string(Cairnloop.Workers.ToolExecutionWorkerTest.OkRunTool),
        actor_id: "operator_1",
        idempotency_key: "idem-100",
        attempt: 0,
        result_state: :not_executed,
        input_snapshot: %{},
        scope_snapshot: %{scopes: []},
        policy_snapshot: %{}
      })
    end

    # Proposal id 101: OkRunTool, result_state :succeeded — LAYER-2 terminal guard
    def get!(ToolProposal, 101) do
      struct(ToolProposal, %{
        id: 101,
        tool_ref: Atom.to_string(Cairnloop.Workers.ToolExecutionWorkerTest.OkRunTool),
        actor_id: "operator_1",
        idempotency_key: "idem-101",
        attempt: 1,
        result_state: :succeeded,
        input_snapshot: %{},
        scope_snapshot: %{scopes: []},
        policy_snapshot: %{}
      })
    end

    # Proposal id 110: ScopeFailTool — re-validation fails (scope required, not granted)
    def get!(ToolProposal, 110) do
      struct(ToolProposal, %{
        id: 110,
        tool_ref: Atom.to_string(Cairnloop.Workers.ToolExecutionWorkerTest.ScopeFailTool),
        actor_id: "operator_1",
        idempotency_key: "idem-110",
        attempt: 0,
        result_state: :not_executed,
        input_snapshot: %{},
        scope_snapshot: %{scopes: []},
        policy_snapshot: %{}
      })
    end

    # Proposal id 120: FailRunTool — run/3 always {:error, _}
    def get!(ToolProposal, 120) do
      struct(ToolProposal, %{
        id: 120,
        tool_ref: Atom.to_string(Cairnloop.Workers.ToolExecutionWorkerTest.FailRunTool),
        actor_id: "operator_1",
        idempotency_key: "idem-120",
        attempt: 0,
        result_state: :not_executed,
        input_snapshot: %{},
        scope_snapshot: %{scopes: []},
        policy_snapshot: %{}
      })
    end

    def update(changeset) do
      send(self(), {:repo_update, changeset})
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

    def insert(changeset) do
      send(self(), {:repo_insert, changeset})
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :tools, [OkRunTool, ScopeFailTool, FailRunTool])
    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :tools)
    end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Happy path: :execution_pending → calls run/3 → :executed
  # ---------------------------------------------------------------------------

  describe "perform/1 — happy path → :executed" do
    test "transitions :execution_pending to :executed when re-validation passes and run/3 returns {:ok, _}" do
      assert :ok =
               ToolExecutionWorker.perform(%Oban.Job{
                 attempt: 1,
                 max_attempts: 3,
                 args: %{"approval_id" => 10}
               })

      # At least one update (approval status) and inserts (proposal result, event)
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :executed
    end

    test "inserts an :execution_succeeded event on success" do
      assert :ok =
               ToolExecutionWorker.perform(%Oban.Job{
                 attempt: 1,
                 max_attempts: 3,
                 args: %{"approval_id" => 10}
               })

      # Drain update messages
      assert_receive {:repo_update, _}
      # Find the :execution_succeeded event insert
      events = drain_inserts()
      assert Enum.any?(events, fn cs ->
        Ecto.Changeset.apply_changes(cs).event_type == :execution_succeeded
      end), "expected an :execution_succeeded event to be inserted"
    end
  end

  # ---------------------------------------------------------------------------
  # LAYER-2 terminal guard: result_state :succeeded → no-op (T-16-01, D16-05)
  # ---------------------------------------------------------------------------

  describe "perform/1 — LAYER-2 terminal guard" do
    test "no-op when proposal result_state is already :succeeded (replay protection)" do
      assert :ok =
               ToolExecutionWorker.perform(%Oban.Job{
                 attempt: 1,
                 max_attempts: 3,
                 args: %{"approval_id" => 11}
               })

      # No DB writes should occur
      refute_receive {:repo_update, _}
      refute_receive {:repo_insert, _}
    end
  end

  # ---------------------------------------------------------------------------
  # Wrong status / deleted → :ok no-ops
  # ---------------------------------------------------------------------------

  describe "perform/1 — wrong status / deleted → :ok no-op" do
    test "no-ops for :executed approval (already terminal)" do
      assert :ok =
               ToolExecutionWorker.perform(%Oban.Job{
                 attempt: 1,
                 max_attempts: 3,
                 args: %{"approval_id" => 12}
               })

      refute_receive {:repo_update, _}
    end

    test "no-ops for nil approval (deleted)" do
      assert :ok =
               ToolExecutionWorker.perform(%Oban.Job{
                 attempt: 1,
                 max_attempts: 3,
                 args: %{"approval_id" => 13}
               })

      refute_receive {:repo_update, _}
    end

    test "no-ops for :pending approval (wrong status)" do
      assert :ok =
               ToolExecutionWorker.perform(%Oban.Job{
                 attempt: 1,
                 max_attempts: 3,
                 args: %{"approval_id" => 15}
               })

      refute_receive {:repo_update, _}
    end
  end

  # ---------------------------------------------------------------------------
  # Re-validation failure at execution time → :invalidated/:execution_failed (T-16-02)
  # ---------------------------------------------------------------------------

  describe "perform/1 — re-validation fail → :execution_failed / :invalidated" do
    test "transitions to :invalidated/:execution_failed when re-validation fails at execution time" do
      result =
        ToolExecutionWorker.perform(%Oban.Job{
          attempt: 1,
          max_attempts: 3,
          args: %{"approval_id" => 14}
        })

      # On re-validation failure the worker should either return :ok (with recorded terminal)
      # or {:cancel, reason}. Either way the approval must NOT reach :executed.
      assert result in [:ok] or match?({:cancel, _}, result)

      assert_receive {:repo_update, changeset}
      status = Ecto.Changeset.get_change(changeset, :status)
      assert status in [:invalidated, :execution_failed],
             "expected :invalidated or :execution_failed, got #{status}"
    end

    test "emits :revalidation_failed or :execution_failed event on re-validation fail" do
      ToolExecutionWorker.perform(%Oban.Job{
        attempt: 1,
        max_attempts: 3,
        args: %{"approval_id" => 14}
      })

      assert_receive {:repo_update, _}
      events = drain_inserts()
      assert Enum.any?(events, fn cs ->
        Ecto.Changeset.apply_changes(cs).event_type in [:revalidation_failed, :execution_failed]
      end), "expected a failure event to be inserted"
    end
  end

  # ---------------------------------------------------------------------------
  # Transient run/3 error → {:error, reason} so Oban retries (D16-07)
  # ---------------------------------------------------------------------------

  describe "perform/1 — transient run/3 failure (attempt < max) → {:error, _}" do
    test "returns {:error, reason} for a transient failure so Oban retries" do
      result =
        ToolExecutionWorker.perform(%Oban.Job{
          attempt: 1,
          max_attempts: 3,
          args: %{"approval_id" => 16}
        })

      assert match?({:error, _}, result),
             "expected {:error, reason} for transient failure at attempt 1 of 3, got #{inspect(result)}"
    end

    test "inserts an :execution_attempt_failed event on transient failure" do
      ToolExecutionWorker.perform(%Oban.Job{
        attempt: 1,
        max_attempts: 3,
        args: %{"approval_id" => 16}
      })

      events = drain_inserts()
      assert Enum.any?(events, fn cs ->
        Ecto.Changeset.apply_changes(cs).event_type == :execution_attempt_failed
      end), "expected an :execution_attempt_failed event for transient failure"
    end
  end

  # ---------------------------------------------------------------------------
  # Exhausted retries → {:cancel, reason} + :execution_failed (D16-07)
  # ---------------------------------------------------------------------------

  describe "perform/1 — exhausted retries → {:cancel, _} + :execution_failed" do
    test "returns {:cancel, reason} when attempt == max_attempts (retries exhausted)" do
      result =
        ToolExecutionWorker.perform(%Oban.Job{
          attempt: 3,
          max_attempts: 3,
          args: %{"approval_id" => 16}
        })

      assert match?({:cancel, _}, result),
             "expected {:cancel, reason} for last attempt, got #{inspect(result)}"
    end

    test "transitions approval to :execution_failed when retries exhausted" do
      ToolExecutionWorker.perform(%Oban.Job{
        attempt: 3,
        max_attempts: 3,
        args: %{"approval_id" => 16}
      })

      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :execution_failed
    end
  end

  # ---------------------------------------------------------------------------
  # Governance.execute_approved/2 facade — injectable enqueue_fn (D16-13)
  # ---------------------------------------------------------------------------

  describe "Governance.execute_approved/2 facade" do
    test "execute_approved/2 function is exported on Cairnloop.Governance" do
      assert function_exported?(Cairnloop.Governance, :execute_approved, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # Resume worker additive enqueue (D16-04) — sealed contract still no run/3
  # ---------------------------------------------------------------------------

  describe "ApprovalResumeWorker additive enqueue" do
    test "resume worker source contains ToolExecutionWorker.new reference" do
      resume_path = "lib/cairnloop/workers/approval_resume_worker.ex"
      if File.exists?(resume_path) do
        source = File.read!(resume_path)
        assert source =~ "ToolExecutionWorker.new",
               "ApprovalResumeWorker must enqueue ToolExecutionWorker after :execution_pending"
      end
    end

    test "resume worker source still contains no .run( tool invocation (sealed contract)" do
      resume_path = "lib/cairnloop/workers/approval_resume_worker.ex"
      if File.exists?(resume_path) do
        # Strip comment lines then check for tool .run( calls
        non_comment_lines =
          resume_path
          |> File.read!()
          |> String.split("\n")
          |> Enum.reject(&String.match?(&1, ~r/^\s*#/))
          |> Enum.join("\n")

        refute non_comment_lines =~ ~r/\w+\.run\s*\(/,
               "ApprovalResumeWorker must never call tool .run/3 (sealed contract, D15-10)"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp drain_inserts do
    drain_inserts([])
  end

  defp drain_inserts(acc) do
    receive do
      {:repo_insert, cs} -> drain_inserts([cs | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
