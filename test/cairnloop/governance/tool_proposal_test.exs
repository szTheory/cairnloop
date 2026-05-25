defmodule Cairnloop.Governance.ToolProposalTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Governance.ToolProposal

  describe "status_values/0" do
    test "returns the four locked Phase 13 proposal statuses" do
      assert ToolProposal.status_values() == [
               :proposed,
               :needs_input,
               :scope_invalid,
               :policy_denied
             ]
    end
  end

  describe "changeset/2 — valid" do
    test "is valid with all required fields" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        status: :proposed,
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to :proposed when omitted" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :proposed
    end

    test "accepts all valid status values" do
      for status <- [:proposed, :needs_input, :scope_invalid, :policy_denied] do
        attrs = %{
          tool_ref: "Elixir.MyApp.Tools.LookupOrder",
          idempotency_key: "key_#{status}",
          status: status,
          risk_tier: :read_only,
          approval_mode: :auto,
          actor_id: "user_1"
        }

        changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
        assert changeset.valid?, "Expected valid? for status: #{status}"
      end
    end

    test "accepts all valid risk_tier values" do
      for tier <- [:read_only, :low_write, :high_write, :destructive] do
        attrs = %{
          tool_ref: "Elixir.MyApp.Tools.LookupOrder",
          idempotency_key: "key_#{tier}",
          risk_tier: tier,
          approval_mode: :auto,
          actor_id: "user_1"
        }

        changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
        assert changeset.valid?, "Expected valid? for risk_tier: #{tier}"
      end
    end

    test "accepts all valid approval_mode values" do
      for mode <- [:auto, :requires_approval, :always_block] do
        attrs = %{
          tool_ref: "Elixir.MyApp.Tools.LookupOrder",
          idempotency_key: "key_#{mode}",
          risk_tier: :read_only,
          approval_mode: mode,
          actor_id: "user_1"
        }

        changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
        assert changeset.valid?, "Expected valid? for approval_mode: #{mode}"
      end
    end

    test "snapshot fields default to empty maps" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :input_snapshot) == %{}
      assert Ecto.Changeset.get_field(changeset, :scope_snapshot) == %{}
      assert Ecto.Changeset.get_field(changeset, :policy_snapshot) == %{}
    end
  end

  describe "changeset/2 — invalid" do
    test "rejects an unknown status atom (Ecto.Enum bounds)" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        status: :bogus,
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      refute changeset.valid?
      assert {:status, _} = List.keyfind(changeset.errors, :status, 0)
    end

    test "rejects an unknown risk_tier atom" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        risk_tier: :turbo,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      refute changeset.valid?
    end

    test "rejects an unknown approval_mode atom" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :yolo,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      refute changeset.valid?
    end

    test "requires tool_ref" do
      attrs = %{
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      refute changeset.valid?
    end

    test "requires idempotency_key" do
      attrs = %{
        tool_ref: "SomeTool",
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      refute changeset.valid?
    end

    test "requires actor_id" do
      attrs = %{
        tool_ref: "SomeTool",
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :auto
      }

      changeset = ToolProposal.changeset(%ToolProposal{}, attrs)
      refute changeset.valid?
    end
  end

  describe "Phase 16 reserved columns" do
    test "attempt defaults to 0" do
      changeset =
        ToolProposal.changeset(%ToolProposal{}, %{
          tool_ref: "SomeTool",
          idempotency_key: "key1",
          risk_tier: :read_only,
          approval_mode: :auto,
          actor_id: "user_1"
        })

      assert Ecto.Changeset.get_field(changeset, :attempt) == 0
    end

    test "result_state defaults to :not_executed" do
      changeset =
        ToolProposal.changeset(%ToolProposal{}, %{
          tool_ref: "SomeTool",
          idempotency_key: "key1",
          risk_tier: :read_only,
          approval_mode: :auto,
          actor_id: "user_1"
        })

      assert Ecto.Changeset.get_field(changeset, :result_state) == :not_executed
    end

    test "oban_job_id defaults to nil" do
      changeset =
        ToolProposal.changeset(%ToolProposal{}, %{
          tool_ref: "SomeTool",
          idempotency_key: "key1",
          risk_tier: :read_only,
          approval_mode: :auto,
          actor_id: "user_1"
        })

      assert Ecto.Changeset.get_field(changeset, :oban_job_id) == nil
    end

    test "result_summary defaults to nil" do
      changeset =
        ToolProposal.changeset(%ToolProposal{}, %{
          tool_ref: "SomeTool",
          idempotency_key: "key1",
          risk_tier: :read_only,
          approval_mode: :auto,
          actor_id: "user_1"
        })

      assert Ecto.Changeset.get_field(changeset, :result_summary) == nil
    end
  end

  describe "blocked_changeset/2" do
    test "creates a valid changeset with a blocked status" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1"
      }

      changeset =
        ToolProposal.blocked_changeset(%ToolProposal{}, Map.put(attrs, :status, :scope_invalid))

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :scope_invalid
    end

    test "creates a valid changeset with policy_denied status" do
      attrs = %{
        tool_ref: "Elixir.MyApp.Tools.LookupOrder",
        idempotency_key: "abc123",
        risk_tier: :read_only,
        approval_mode: :auto,
        actor_id: "user_1",
        status: :policy_denied
      }

      changeset = ToolProposal.blocked_changeset(%ToolProposal{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :policy_denied
    end
  end
end
