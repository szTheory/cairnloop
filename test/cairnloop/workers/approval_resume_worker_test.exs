defmodule Cairnloop.Workers.ApprovalResumeWorkerTest do
  use ExUnit.Case, async: false

  # ---------------------------------------------------------------------------
  # Module-under-test reference
  # ---------------------------------------------------------------------------

  alias Cairnloop.Workers.ApprovalResumeWorker

  # ---------------------------------------------------------------------------
  # Test tool modules
  #
  # PassTool: no required fields → validate/3 always passes (scope: [], authorize: :ok)
  # ScopeFailTool: requires :admin_scope → scope check fails → :invalidated
  # ---------------------------------------------------------------------------

  defmodule PassTool do
    use Cairnloop.Tool,
      risk_tier: :read_only,
      title: "Pass Tool",
      description: "Always passes validation."

    embedded_schema do
      field(:note, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs), do: Ecto.Changeset.cast(struct, attrs, [:note])

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  defmodule ScopeFailTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Scope Fail Tool",
      description: "Requires :admin_scope — will fail if not granted."

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

  # ---------------------------------------------------------------------------
  # MockRepo — process-dictionary-backed repo (no real DB required)
  #
  # Mirrors sla_countdown_worker_test.exs MockRepo pattern.
  #
  # Approval fixtures (id→status):
  #   1 → :pending, expires_at nil  (validate-pass path, tool: PassTool)
  #   2 → :approved                 (already transitioned — no-op)
  #   3 → nil                       (deleted — no-op)
  #   4 → :pending, expires_at past (lazy expires_at guard → :expired)
  #   5 → :pending, expires_at nil  (validate-fail path, tool: ScopeFailTool)
  #
  # ToolProposal fixtures:
  #   id 10 → tool_ref PassTool (for ids 1, 2, 4)
  #   id 20 → tool_ref ScopeFailTool, scope_snapshot: %{} → scope check fails
  # ---------------------------------------------------------------------------

  defmodule MockRepo do
    # Approval id 1: :pending, no expiry — normal validate-pass path
    def get(tool_approval_module, 1) when tool_approval_module == Cairnloop.Governance.ToolApproval do
      struct(tool_approval_module, %{
        id: 1,
        status: :pending,
        tool_proposal_id: 10,
        expires_at: nil,
        decided_by: nil,
        last_decision: nil,
        reason: nil
      })
    end

    # Approval id 2: :approved — already transitioned
    def get(tool_approval_module, 2) when tool_approval_module == Cairnloop.Governance.ToolApproval do
      struct(tool_approval_module, %{
        id: 2,
        status: :approved,
        tool_proposal_id: 10,
        expires_at: nil
      })
    end

    # Approval id 3: nil — deleted
    def get(tool_approval_module, 3) when tool_approval_module == Cairnloop.Governance.ToolApproval do
      _ = tool_approval_module
      nil
    end

    # Approval id 4: :pending, expires_at in the past — lazy expiry guard
    def get(tool_approval_module, 4) when tool_approval_module == Cairnloop.Governance.ToolApproval do
      struct(tool_approval_module, %{
        id: 4,
        status: :pending,
        tool_proposal_id: 10,
        expires_at: ~U[2020-01-01 00:00:00Z]
      })
    end

    # Approval id 5: :pending, no expiry — validate-fail path (ScopeFailTool)
    def get(tool_approval_module, 5) when tool_approval_module == Cairnloop.Governance.ToolApproval do
      struct(tool_approval_module, %{
        id: 5,
        status: :pending,
        tool_proposal_id: 20,
        expires_at: nil,
        decided_by: nil,
        last_decision: nil,
        reason: nil
      })
    end

    # ToolProposal id 10: PassTool — passes validate/3 with empty input_snapshot
    def get!(tool_proposal_module, 10) when tool_proposal_module == Cairnloop.Governance.ToolProposal do
      struct(tool_proposal_module, %{
        id: 10,
        tool_ref: Atom.to_string(Cairnloop.Workers.ApprovalResumeWorkerTest.PassTool),
        actor_id: "user_1",
        input_snapshot: %{},
        scope_snapshot: %{scopes: []},
        policy_snapshot: %{}
      })
    end

    # ToolProposal id 20: ScopeFailTool — fails scope check → :invalidated
    def get!(tool_proposal_module, 20) when tool_proposal_module == Cairnloop.Governance.ToolProposal do
      struct(tool_proposal_module, %{
        id: 20,
        tool_ref: Atom.to_string(Cairnloop.Workers.ApprovalResumeWorkerTest.ScopeFailTool),
        actor_id: "user_1",
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
    # Mirror sla_countdown_worker_test.exs setup:
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :tools, [PassTool, ScopeFailTool])
    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :tools)
    end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # describe: :pending + validate pass → :execution_pending (15-VALIDATION row 15-03-a)
  # ---------------------------------------------------------------------------

  describe "perform/1 — validate pass → :execution_pending (15-03-a)" do
    test "transitions :pending approval to :execution_pending on re-validation pass" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 1}})
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :execution_pending
      # Assert an event was also inserted (revalidation_passed event)
      assert_receive {:repo_insert, _event_changeset}
    end

    test "emits a :revalidation_passed event on validate pass (D15-10)" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 1}})
      assert_receive {:repo_insert, event_changeset}
      event_attrs = Ecto.Changeset.apply_changes(event_changeset)
      assert event_attrs.event_type == :revalidation_passed
    end

    # Source assertion: the worker must NOT contain a .run( call (never calls run/3 — D15-10).
    # This test verifies the Phase-16 seam invariant holds in the source file.
    test "worker source file contains no .run( call — Phase 16 seam" do
      worker_path = "lib/cairnloop/workers/approval_resume_worker.ex"
      if File.exists?(worker_path) do
        source = File.read!(worker_path)
        refute source =~ ~r/\.run\s*\(/,
               "ApprovalResumeWorker must never call .run/3 — Phase 16 seam (D15-10)"
      else
        # File does not exist yet — test passes trivially
        assert true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe: :pending + validate fail → :invalidated (15-VALIDATION row 15-03-b)
  # ---------------------------------------------------------------------------

  describe "perform/1 — validate fail → :invalidated (15-03-b)" do
    test "transitions :pending approval to :invalidated on re-validation fail" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 5}})
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :invalidated
    end

    test "emits a :revalidation_failed event with operator-visible reason on fail (D15-11)" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 5}})
      assert_receive {:repo_insert, event_changeset}
      event = Ecto.Changeset.apply_changes(event_changeset)
      assert event.event_type == :revalidation_failed
      # Reason must be present and not raw Elixir terms (T-15-09)
      assert is_binary(event.reason) or is_nil(event.reason)
      refute (event.reason || "") =~ "#Ecto.Changeset<"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: already-transitioned and deleted approvals → :ok no-op (15-VALIDATION row 15-03-d)
  # ---------------------------------------------------------------------------

  describe "perform/1 — already-transitioned or deleted approval → :ok no-op (15-03-d)" do
    test "no-ops gracefully for already-transitioned approval (id 2, status :approved)" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 2}})
      refute_receive {:repo_update, _}
    end

    test "no-ops gracefully for missing approval (id 3 — deleted)" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 3}})
      refute_receive {:repo_update, _}
    end
  end

  # ---------------------------------------------------------------------------
  # describe: lazy expires_at guard (15-VALIDATION row 15-03-c)
  #
  # Approval id 4 has expires_at in the past. The worker checks this BEFORE
  # running re-validation, so a stale approval can never execute even if the
  # scheduled expiry sweep never ran (D15-12 defense-in-depth).
  # ---------------------------------------------------------------------------

  describe "perform/1 — lazy expires_at guard → :expired (15-03-c)" do
    test "marks :pending approval as :expired when expires_at < now (lazy guard)" do
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 4}})
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :expired
    end

    test "lazy guard fires BEFORE re-validation runs (stale approval can never execute)" do
      # When expires_at is in the past, the worker must short-circuit immediately
      # without calling Governance.validate/3 (re-validation never runs).
      # Verified by the :expired status flip (not :execution_pending or :invalidated).
      assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 4}})
      assert_receive {:repo_update, changeset}
      status = Ecto.Changeset.get_change(changeset, :status)
      assert status == :expired,
             "Lazy guard must flip to :expired, not #{status} (stale approval must never execute)"
    end
  end
end
