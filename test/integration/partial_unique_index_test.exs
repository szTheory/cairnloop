defmodule Cairnloop.Integration.PartialUniqueIndexTest do
  @moduledoc """
  Integration coverage for Phase 15 manual item 1 (APRV-04): the partial unique index
  `cairnloop_tool_approvals_one_active_lane_index WHERE status = 'pending'` actually
  rejects a second active approval lane on a real Postgres INSERT.
  """
  use Cairnloop.DataCase, async: true

  alias Cairnloop.Governance
  alias Cairnloop.Governance.ToolApproval

  import Cairnloop.Fixtures

  describe "one-active-lane partial unique index (APRV-04)" do
    test "rejects a second :pending approval for the same proposal" do
      proposal = proposal_fixture()

      assert {:ok, _first} =
               %ToolApproval{}
               |> ToolApproval.changeset(%{tool_proposal_id: proposal.id, status: :pending})
               |> Repo.insert()

      assert {:error, changeset} =
               %ToolApproval{}
               |> ToolApproval.changeset(%{tool_proposal_id: proposal.id, status: :pending})
               |> Repo.insert()

      assert errors_on(changeset)[:tool_proposal_id]

      pending_count =
        ToolApproval
        |> where([a], a.tool_proposal_id == ^proposal.id and a.status == :pending)
        |> Repo.aggregate(:count)

      assert pending_count == 1
    end

    test "allows a second non-:pending approval for the same proposal (proves WHERE status='pending')" do
      proposal = proposal_fixture()

      assert {:ok, _pending} =
               %ToolApproval{}
               |> ToolApproval.changeset(%{tool_proposal_id: proposal.id, status: :pending})
               |> Repo.insert()

      # The index is partial — a resolved lane in any non-:pending status is permitted.
      assert {:ok, _resolved} =
               %ToolApproval{}
               |> ToolApproval.changeset(%{tool_proposal_id: proposal.id, status: :approved})
               |> Repo.insert()
    end

    test "Governance.request_approval/2 returns {:error, changeset} on a second active lane" do
      proposal = proposal_fixture(%{approval_mode: :requires_approval})
      noop = fn _job -> :ok end

      assert {:ok, _approval} = Governance.request_approval(proposal, enqueue_fn: noop)
      assert {:error, %Ecto.Changeset{}} = Governance.request_approval(proposal, enqueue_fn: noop)
    end
  end
end
