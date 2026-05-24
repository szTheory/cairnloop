defmodule Cairnloop.Workers.ApprovalResumeWorkerTest do
  use ExUnit.Case, async: false

  # ---------------------------------------------------------------------------
  # Module-under-test reference
  #
  # Cairnloop.Workers.ApprovalResumeWorker does NOT exist until Wave 2.
  # All tests below are tagged :skip so this file compiles and runs now.
  # Remove :skip as the worker is implemented in Wave 2.
  # ---------------------------------------------------------------------------

  @worker_module Cairnloop.Workers.ApprovalResumeWorker

  # ---------------------------------------------------------------------------
  # MockRepo — process-dictionary-backed repo (no real DB required)
  #
  # Mirrors sla_countdown_worker_test.exs MockRepo pattern (L7-24).
  #
  # Approval fixtures (id→status):
  #   1 → :pending, expires_at nil  (validate-pass path)
  #   2 → :approved                 (already transitioned — no-op)
  #   3 → nil                       (deleted — no-op)
  #   4 → :pending, expires_at past (lazy expires_at guard → :expired)
  #
  # ToolProposal fixture (id 10) — re-validates to {:ok, _} against a known tool ref.
  # NOTE: In Wave 2 this fixture will need to reference a real registered tool_ref.
  # For now the MockRepo is defined so the file compiles; live re-validation is
  # # REPO-UNAVAILABLE because the tool ref must be in the registry at test time.
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

    # ToolProposal id 10
    def get!(tool_proposal_module, 10) when tool_proposal_module == Cairnloop.Governance.ToolProposal do
      struct(tool_proposal_module, %{
        id: 10,
        # REPO-UNAVAILABLE: a real registered tool_ref would be used for live re-validation
        tool_ref: "Cairnloop.GovernanceTest.ValidTool",
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
    # Mirror sla_countdown_worker_test.exs L26-29:
    Application.put_env(:cairnloop, :repo, MockRepo)
    on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # describe: :pending + validate pass → :execution_pending (15-VALIDATION row 15-03-a)
  #
  # Wave 2 will implement ApprovalResumeWorker; call it here.
  # REPO-UNAVAILABLE: the live re-validation path requires a registered tool ref
  # so the validate_pass test is skipped until Wave 2 wires in a real tool ref.
  # ---------------------------------------------------------------------------

  describe "perform/1 — validate pass → :execution_pending (15-03-a)" do
    @tag :skip
    test "transitions :pending approval to :execution_pending on re-validation pass" do
      # Wave 2 note: approval id 1 has a tool_ref of "Cairnloop.GovernanceTest.ValidTool"
      # which must be registered in :cairnloop, :tools for validate/3 to pass.
      # Skipped until Wave 2 sets up the tool registry in this test module.
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 1}}])
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :execution_pending
      # Assert an event was also inserted (revalidation_passed event)
      assert_receive {:repo_insert, _event_changeset}
    end

    @tag :skip
    test "emits a :revalidation_passed event on validate pass (D15-10)" do
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 1}}])
      assert_receive {:repo_insert, event_changeset}
      event_attrs = Ecto.Changeset.apply_changes(event_changeset)
      assert event_attrs.event_type == :revalidation_passed
    end

    # Source assertion: the worker must NOT contain a .run( call (never calls run/3 — D15-10).
    # This test runs NOW (no ApprovalResumeWorker needed — checks the source file directly).
    # Once Wave 2 creates the file, this test verifies the Phase-16 seam invariant holds.
    test "worker source file (when created) will contain no .run( call — Phase 16 seam" do
      worker_path = "lib/cairnloop/workers/approval_resume_worker.ex"
      if File.exists?(worker_path) do
        source = File.read!(worker_path)
        refute source =~ ~r/\.run\s*\(/,
               "ApprovalResumeWorker must never call .run/3 — Phase 16 seam (D15-10)"
      else
        # File does not exist yet (Wave 0) — test passes trivially; Wave 2 will make it meaningful
        assert true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe: :pending + validate fail → :invalidated (15-VALIDATION row 15-03-b)
  # ---------------------------------------------------------------------------

  describe "perform/1 — validate fail → :invalidated (15-03-b)" do
    @tag :skip
    test "transitions :pending approval to :invalidated on re-validation fail" do
      # Wave 2: wire in a tool ref that fails re-validation (e.g. scope changes)
      # to exercise this path headlessly.
      # REPO-UNAVAILABLE: requires a live-changing policy context; skipped until Wave 2.
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 1}}])
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :invalidated
    end

    @tag :skip
    test "emits a :revalidation_failed event with operator-visible reason on fail (D15-11)" do
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 1}}])
      assert_receive {:repo_insert, event_changeset}
      event = Ecto.Changeset.apply_changes(event_changeset)
      assert event.event_type == :revalidation_failed
      # Reason must be present and not raw Elixir terms
      assert is_binary(event.reason) or is_nil(event.reason)
      refute (event.reason || "") =~ "#Ecto.Changeset<"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: already-transitioned and deleted approvals → :ok no-op (15-VALIDATION row 15-03-d)
  # ---------------------------------------------------------------------------

  describe "perform/1 — already-transitioned or deleted approval → :ok no-op (15-03-d)" do
    @tag :skip
    test "no-ops gracefully for already-transitioned approval (id 2, status :approved)" do
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 2}}])
      refute_receive {:repo_update, _}
    end

    @tag :skip
    test "no-ops gracefully for missing approval (id 3 — deleted)" do
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 3}}])
      refute_receive {:repo_update, _}
    end
  end

  # ---------------------------------------------------------------------------
  # describe: lazy expires_at guard (15-VALIDATION row 15-03-c)
  #
  # Approval id 4 has expires_at in the past. The worker must check this BEFORE
  # running re-validation, so a stale approval can never execute even if the
  # scheduled expiry sweep never ran (D15-12 defense-in-depth).
  # ---------------------------------------------------------------------------

  describe "perform/1 — lazy expires_at guard → :expired (15-03-c)" do
    @tag :skip
    test "marks :pending approval as :expired when expires_at < now (lazy guard)" do
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 4}}])
      assert_receive {:repo_update, changeset}
      assert Ecto.Changeset.get_change(changeset, :status) == :expired
    end

    @tag :skip
    test "lazy guard fires BEFORE re-validation runs (stale approval can never execute)" do
      # When expires_at is in the past, the worker must short-circuit immediately
      # without calling Governance.validate/3 (re-validation never runs).
      # This is verified by the :expired status flip (not :execution_pending or :invalidated).
      assert :ok = apply(@worker_module, :perform, [%Oban.Job{args: %{"approval_id" => 4}}])
      assert_receive {:repo_update, changeset}
      status = Ecto.Changeset.get_change(changeset, :status)
      assert status == :expired,
             "Lazy guard must flip to :expired, not #{status} (stale approval must never execute)"
    end
  end
end
