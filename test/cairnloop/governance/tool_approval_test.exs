defmodule Cairnloop.Governance.ToolApprovalTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Module-under-test reference
  #
  # Cairnloop.Governance.ToolApproval does NOT exist until Wave 1.
  # We reference it via a runtime module attribute so this file compiles now.
  # All tests that call ToolApproval functions are tagged :skip until Wave 1 ships.
  # ---------------------------------------------------------------------------

  @tool_approval_module Cairnloop.Governance.ToolApproval

  # ---------------------------------------------------------------------------
  # Inline fixture helpers (no shared factory — existing repo idiom)
  # ---------------------------------------------------------------------------

  defp approval(overrides \\ %{}) do
    %{
      tool_proposal_id: 1,
      status: :pending
    }
    |> Map.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # describe: changeset/2 — valid (15-VALIDATION row 15-01-a/b)
  # ---------------------------------------------------------------------------

  describe "changeset/2 — valid" do
    test "is valid with required fields (tool_proposal_id + status)" do
      changeset = apply(@tool_approval_module, :changeset, [
        struct(@tool_approval_module),
        approval()
      ])
      assert changeset.valid?
    end

    test "defaults status to :pending when status omitted" do
      changeset = apply(@tool_approval_module, :changeset, [
        struct(@tool_approval_module),
        Map.delete(approval(), :status)
      ])
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :pending
    end

    test "accepts all valid status values" do
      for status <- [:pending, :approved, :execution_pending, :rejected, :deferred, :expired, :invalidated] do
        changeset = apply(@tool_approval_module, :changeset, [
          struct(@tool_approval_module),
          approval(%{status: status})
        ])
        assert changeset.valid?, "Expected valid? for status: #{status}"
      end
    end

    test "requires tool_proposal_id" do
      changeset = apply(@tool_approval_module, :changeset, [
        struct(@tool_approval_module),
        %{status: :pending}
      ])
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # describe: changeset/2 — one-active-lane constraint (15-VALIDATION row 15-01-a)
  #
  # The partial unique index is declared on the changeset via unique_constraint.
  # The actual DB-level rejection is a REPO-UNAVAILABLE leg (needs live Postgres).
  # ---------------------------------------------------------------------------

  describe "changeset/2 — one-active-lane unique_constraint" do
    test "declares unique_constraint for :tool_proposal_id with the partial index name" do
      changeset = apply(@tool_approval_module, :changeset, [
        struct(@tool_approval_module),
        approval()
      ])
      # Assert the unique_constraint is registered on the changeset.
      # Ecto stores the constraint name under the :constraint key (a string).
      constraint_names = Enum.map(changeset.constraints, & &1.constraint)
      assert "cairnloop_tool_approvals_one_active_lane_index" in constraint_names
    end

    # REPO-UNAVAILABLE
    # @tag :skip
    # test "partial unique index rejects second :pending approval for same tool_proposal_id" do
    #   # Requires a live Postgres round-trip (partial unique index WHERE status = 'pending').
    #   # When Repo is available: insert two pending approvals for one proposal,
    #   # assert the second raises a unique-constraint error.
    # end
  end

  # ---------------------------------------------------------------------------
  # describe: decision_changeset/6 — FLOW-03 reason requirement (15-VALIDATION row 15-01-b, 15-02-b)
  # ---------------------------------------------------------------------------

  describe "decision_changeset/6 — FLOW-03 reason requirement" do
    test "reject requires reason — refute valid? and assert :reason error" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :rejected,
        "rejected",
        nil,
        "user_1",
        DateTime.utc_now()
      ])
      refute cs.valid?
      assert {:reason, _} = List.keyfind(cs.errors, :reason, 0)
    end

    test "defer requires reason — refute valid?" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :deferred,
        "deferred",
        nil,
        "user_1",
        DateTime.utc_now()
      ])
      refute cs.valid?
      assert {:reason, _} = List.keyfind(cs.errors, :reason, 0)
    end

    test "approve does NOT require reason — assert valid?" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :approved,
        "approved",
        nil,
        "user_1",
        DateTime.utc_now()
      ])
      assert cs.valid?
    end

    test "reject with reason provided is valid" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :rejected,
        "rejected",
        "Risk too high for this account.",
        "user_1",
        DateTime.utc_now()
      ])
      assert cs.valid?
    end

    test "defer with reason provided is valid" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :deferred,
        "deferred",
        "Review after the weekend.",
        "user_1",
        DateTime.utc_now()
      ])
      assert cs.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # describe: decision_changeset/6 — denormalized last-decision fields
  # (mirrors ReviewTask.decision_changeset idiom — 15-VALIDATION row 15-01-b)
  # ---------------------------------------------------------------------------

  describe "decision_changeset/6 — denormalized last-decision fields" do
    test "captures decided_by on the changeset" do
      decided_at = ~U[2026-01-01 12:00:00.000000Z]
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :approved,
        "approved",
        nil,
        "ops_user_1",
        decided_at
      ])
      assert Ecto.Changeset.get_change(cs, :decided_by) == "ops_user_1"
    end

    test "captures decided_at on the changeset" do
      # Use microsecond precision to match :utc_datetime_usec Ecto type normalization
      decided_at = ~U[2026-01-01 12:00:00.000000Z]
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :approved,
        "approved",
        nil,
        "ops_user_1",
        decided_at
      ])
      assert Ecto.Changeset.get_change(cs, :decided_at) == decided_at
    end

    test "captures last_decision on the changeset (denormalized ReviewTask idiom)" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :approved,
        "approved",
        nil,
        "ops_user_1",
        DateTime.utc_now()
      ])
      assert Ecto.Changeset.get_change(cs, :last_decision) == "approved"
    end

    test "captures reason on the changeset when reason is provided" do
      cs = apply(@tool_approval_module, :decision_changeset, [
        struct(@tool_approval_module, %{tool_proposal_id: 1}),
        :rejected,
        "rejected",
        "Scope exceeded allowable risk.",
        "ops_user_2",
        DateTime.utc_now()
      ])
      assert Ecto.Changeset.get_change(cs, :reason) == "Scope exceeded allowable risk."
    end
  end

  # ---------------------------------------------------------------------------
  # describe: append-only invariant (mirrors tool_action_event_test.exs L143-151)
  # ---------------------------------------------------------------------------

  describe "append-only invariant" do
    test "module does not define update/1" do
      refute function_exported?(@tool_approval_module, :update, 1)
    end

    test "module does not define delete/1" do
      refute function_exported?(@tool_approval_module, :delete, 1)
    end
  end
end
