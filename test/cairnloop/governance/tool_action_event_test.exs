defmodule Cairnloop.Governance.ToolActionEventTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Governance.ToolActionEvent

  describe "changeset/2 — valid" do
    test "is valid with required fields (from_status nil for proposal_created)" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_created,
        from_status: nil,
        to_status: :proposed,
        actor_id: "user_1"
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    test "from_status may be nil (no prior status for proposal_created)" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_created,
        to_status: :proposed,
        actor_id: "user_1"
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :from_status) == nil
    end

    test "accepts proposal_blocked event_type with from_status set" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_blocked,
        from_status: :proposed,
        to_status: :scope_invalid,
        actor_id: "user_1",
        reason: "scope mismatch"
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    test "coerces nil metadata to %{}" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_created,
        to_status: :proposed,
        actor_id: "user_1",
        metadata: nil
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :metadata) == %{}
    end

    test "accepts valid map metadata" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_created,
        to_status: :proposed,
        actor_id: "user_1",
        metadata: %{source: "governance"}
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 — invalid" do
    test "rejects non-map metadata (e.g. a string)" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_created,
        to_status: :proposed,
        actor_id: "user_1",
        metadata: "x"
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
      assert {:metadata, _} = List.keyfind(changeset.errors, :metadata, 0)
    end

    test "requires tool_proposal_id" do
      attrs = %{event_type: :proposal_created, to_status: :proposed, actor_id: "user_1"}

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
    end

    test "requires event_type" do
      attrs = %{tool_proposal_id: 1, to_status: :proposed, actor_id: "user_1"}

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
    end

    test "requires to_status" do
      attrs = %{tool_proposal_id: 1, event_type: :proposal_created, actor_id: "user_1"}

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
    end

    test "requires actor_id" do
      attrs = %{tool_proposal_id: 1, event_type: :proposal_created, to_status: :proposed}

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
    end

    test "rejects unknown event_type" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :unknown_event,
        to_status: :proposed,
        actor_id: "user_1"
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
    end

    test "rejects unknown to_status" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :proposal_created,
        to_status: :bogus_status,
        actor_id: "user_1"
      }

      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      refute changeset.valid?
    end
  end

  describe "append-only invariant" do
    test "module does not define update/1" do
      refute function_exported?(ToolActionEvent, :update, 1)
    end

    test "module does not define delete/1" do
      refute function_exported?(ToolActionEvent, :delete, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 15 Wave 0 extension: new approval event_type values (15-VALIDATION row 15-01-c)
  #
  # These describe blocks encode the contract for the 9 new approval event_types.
  # Wave 1 extends @event_type_values with these atoms.
  # All tests are @tag :skip until Wave 1 ships (new atoms are not in @event_type_values yet).
  #
  # Note on to_status: approval events leave from_status and to_status nil (D15-03).
  # The current changeset at L57 requires :to_status for proposal events.
  # Wave 1 will relax validate_required to skip :to_status for approval event_types
  # (or provide a different changeset path for approval events).
  # These tests document this expectation.
  # ---------------------------------------------------------------------------

  describe "new approval event_type values — Phase 15 (15-01-c)" do
    @tag :skip
    test "accepts :approval_requested with from_status nil, to_status nil" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :approval_requested,
        actor_id: "system",
        # Approval events carry nil for from_status/to_status (D15-03)
        metadata: %{approval_status: "pending", new_approval_status: "pending"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      # Wave 1: to_status validation relaxed for approval events — changeset must be valid
      assert changeset.valid?,
             "changeset must be valid for :approval_requested with nil to_status (Wave 1 relaxes required)"
    end

    @tag :skip
    test "accepts :approved with from_status nil, to_status nil" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :approved,
        actor_id: "ops_user_1",
        metadata: %{approval_status: "pending", new_approval_status: "approved"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :rejected with reason (FLOW-03)" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :rejected,
        actor_id: "ops_user_1",
        reason: "Risk exceeds threshold.",
        metadata: %{approval_status: "pending", new_approval_status: "rejected"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :deferred with reason (FLOW-03)" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :deferred,
        actor_id: "ops_user_1",
        reason: "Review after board meeting.",
        metadata: %{approval_status: "pending", new_approval_status: "deferred"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :expired" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :expired,
        actor_id: "system",
        metadata: %{approval_status: "pending", new_approval_status: "expired"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :invalidated with reason" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :invalidated,
        actor_id: "system",
        reason: "Policy changed since approval.",
        metadata: %{approval_status: "pending", new_approval_status: "invalidated"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :resume_scheduled" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :resume_scheduled,
        actor_id: "system",
        metadata: %{approval_status: "approved"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :revalidation_passed" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :revalidation_passed,
        actor_id: "system",
        metadata: %{approval_status: "approved", new_approval_status: "execution_pending"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    @tag :skip
    test "accepts :revalidation_failed with reason" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: :revalidation_failed,
        actor_id: "system",
        reason: "Policy scope changed since approval.",
        metadata: %{approval_status: "approved", new_approval_status: "invalidated"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      assert changeset.valid?
    end

    # This test runs NOW — verifies the current @event_type_values do NOT yet include
    # the approval atoms, documenting that Wave 1 must add them.
    test "approval event_type atoms are NOT in @event_type_values until Wave 1 (Wave 0 state)" do
      approval_atoms = [
        :approval_requested, :approved, :rejected, :deferred,
        :expired, :invalidated, :resume_scheduled, :revalidation_passed, :revalidation_failed
      ]

      for atom <- approval_atoms do
        attrs = %{
          tool_proposal_id: 1,
          event_type: atom,
          to_status: :proposed,
          actor_id: "user_1"
        }
        changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
        # Currently invalid (not in @event_type_values) — Wave 1 makes them valid
        refute changeset.valid?,
               "#{atom} should be invalid in Wave 0 (not yet in @event_type_values)"
      end
    end
  end
end
