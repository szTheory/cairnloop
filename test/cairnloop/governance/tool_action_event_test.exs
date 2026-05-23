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
end
