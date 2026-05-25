defmodule Cairnloop.Integration.JsonbRoundtripTest do
  @moduledoc """
  Integration coverage for Phase 15 manual item 2 (APRV-02 / WR-04): the atom→string
  JSONB round-trip on the proposal snapshot maps. A proposal inserted with atom-keyed
  snapshots comes back from Postgres with string keys; the resume worker must rehydrate
  scope atoms via String.to_existing_atom/1 and re-validate correctly.
  """
  use Cairnloop.DataCase, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.{ToolApproval, ToolProposal}
  alias Cairnloop.Workers.ApprovalResumeWorker

  import Cairnloop.Fixtures

  defmodule PassTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Pass Tool",
      description: "Requires :read scope; passes validation when granted."

    embedded_schema do
      field(:note, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs), do: Ecto.Changeset.cast(struct, attrs, [:note])

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    # `:read` referenced here exists at compile time → String.to_existing_atom("read") succeeds.
    @impl Cairnloop.Tool
    def scope, do: [:read]

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  setup do
    Application.put_env(:cairnloop, :tools, [PassTool])
    on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
    :ok
  end

  test "atom scopes survive the JSONB round-trip → :execution_pending (not spuriously :invalidated)" do
    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(PassTool),
        approval_mode: :requires_approval,
        input_snapshot: %{note: "hello"},
        scope_snapshot: %{scopes: [:read]},
        policy_snapshot: %{resolution_source: :integration_test}
      })

    approval = approval_fixture(proposal, %{status: :approved})

    # Reloading forces JSONB deserialization — atom keys/values come back as strings.
    reloaded = Repo.get!(ToolProposal, proposal.id)
    assert reloaded.scope_snapshot == %{"scopes" => ["read"]}
    assert reloaded.input_snapshot == %{"note" => "hello"}

    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    assert Repo.get!(ToolApproval, approval.id).status == :execution_pending

    event_types = proposal.id |> Governance.list_events() |> Enum.map(& &1.event_type)
    assert :revalidation_passed in event_types
  end

  test "a snapshot scope with no existing atom is safely dropped → :invalidated (rescue path)" do
    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(PassTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: ["cairnloop_nonexistent_scope_xyz_unique"]}
      })

    approval = approval_fixture(proposal, %{status: :approved})

    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    # The unknown scope string is dropped (ArgumentError rescue) → scope check fails →
    # fail-closed to :invalidated, never :execution_pending.
    assert Repo.get!(ToolApproval, approval.id).status == :invalidated

    event_types = proposal.id |> Governance.list_events() |> Enum.map(& &1.event_type)
    assert :revalidation_failed in event_types
  end
end
