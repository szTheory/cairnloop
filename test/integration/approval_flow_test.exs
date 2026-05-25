defmodule Cairnloop.Integration.ApprovalFlowTest do
  @moduledoc """
  Integration coverage for Phase 15 manual item 3 (APRV-01/02/03): the end-to-end async
  approval flow against real Postgres. We verify the correct Oban jobs are scheduled (via a
  capturing enqueue_fn — the codebase's injection idiom), execute the resume worker exactly
  as Oban would (perform/1), and assert the full append-only event trail and the
  scheduled-expiry flip.

  Cairnloop ships no Oban migration (the host owns oban_jobs), so we exercise the workers
  directly rather than through a running Oban instance — the DB transitions are real.
  """
  use Cairnloop.DataCase, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.ToolApproval
  alias Cairnloop.Workers.{ApprovalExpiryWorker, ApprovalResumeWorker}

  import Cairnloop.Fixtures

  defmodule PassTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Pass Tool",
      description: "No scope required; passes re-validation."

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

  setup do
    Application.put_env(:cairnloop, :tools, [PassTool])
    on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
    :ok
  end

  test "request → approve → resume yields :execution_pending with the full append-only event trail" do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(PassTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []}
      })

    # 1. request_approval opens the lane and schedules the expiry worker.
    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, expiry_job}
    assert expiry_job.changes.worker == "Cairnloop.Workers.ApprovalExpiryWorker"
    assert expiry_job.changes.args == %{"approval_id" => approval.id}

    # 2. approve persists the decision and enqueues the resume worker (record before enqueue).
    assert {:ok, _approved} = Governance.approve(approval.id, "operator_1", enqueue_fn: capture)
    assert_received {:enqueued, resume_job}
    assert resume_job.changes.worker == "Cairnloop.Workers.ApprovalResumeWorker"
    assert resume_job.changes.args == %{"approval_id" => approval.id}

    # 3. the resume worker re-validates and transitions to :execution_pending (never run/3).
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})
    assert Repo.get!(ToolApproval, approval.id).status == :execution_pending

    trail = proposal.id |> Governance.list_events() |> Enum.map(& &1.event_type)
    assert trail == [:approval_requested, :approved, :revalidation_passed]
  end

  test "scheduled expiry flips :pending → :expired with an :expired event" do
    proposal =
      proposal_fixture(%{tool_ref: Atom.to_string(PassTool), approval_mode: :requires_approval})

    approval =
      approval_fixture(proposal, %{
        status: :pending,
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      })

    assert :ok = ApprovalExpiryWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    assert Repo.get!(ToolApproval, approval.id).status == :expired

    event_types = proposal.id |> Governance.list_events() |> Enum.map(& &1.event_type)
    assert :expired in event_types
  end
end
