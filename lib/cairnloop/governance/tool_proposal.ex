defmodule Cairnloop.Governance.ToolProposal do
  @moduledoc """
  Durable proposal record capturing a governed tool invocation intent, propose-time
  snapshots, and idempotency key. Mirrors the `ReviewTask` idiom exactly (D-20).

  Status is denormalized onto the proposal for read-your-writes; the full audit timeline
  lives in the append-only `ToolActionEvent` table (D-21).

  Phase 16 reserved columns (`attempt`, `oban_job_id`, `result_state`, `result_summary`)
  are present but unused in Phase 13 — execution is deferred to Phase 16 (D-22).

  Snapshot fields (`input_snapshot`, `scope_snapshot`, `policy_snapshot`) are three
  discrete `:map` fields — no opaque blob mixing trust categories (D-24).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.Governance.ToolActionEvent

  @status_values [:proposed, :needs_input, :scope_invalid, :policy_denied]
  @risk_tier_values [:read_only, :low_write, :high_write, :destructive]
  @approval_mode_values [:auto, :requires_approval, :always_block]
  @result_state_values [:not_executed, :succeeded, :failed]

  schema "cairnloop_tool_proposals" do
    field(:tool_ref, :string)
    field(:tool_version, :string)
    field(:idempotency_key, :string)
    field(:status, Ecto.Enum, values: @status_values, default: :proposed)
    field(:risk_tier, Ecto.Enum, values: @risk_tier_values)
    field(:approval_mode, Ecto.Enum, values: @approval_mode_values)
    field(:actor_id, :string)
    field(:account_id, :string)

    # Three discrete snapshot maps — one trust category per field (D-24)
    field(:input_snapshot, :map, default: %{})
    field(:scope_snapshot, :map, default: %{})
    field(:policy_snapshot, :map, default: %{})

    # Phase 16 reserved columns (D-22) — unused in Phase 13
    field(:attempt, :integer, default: 0)
    field(:oban_job_id, :integer)
    field(:result_state, Ecto.Enum, values: @result_state_values, default: :not_executed)
    field(:result_summary, :string)

    has_many(:events, ToolActionEvent)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Returns the locked Phase 13 proposal status values.
  Referenced by `ToolActionEvent` for cross-schema enum validation.
  """
  def status_values, do: @status_values

  @doc """
  Standard changeset for creating or updating a `ToolProposal`.
  Requires: `tool_ref`, `idempotency_key`, `risk_tier`, `approval_mode`, `actor_id`.
  Status defaults to `:proposed`.
  """
  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, [
      :tool_ref,
      :tool_version,
      :idempotency_key,
      :status,
      :risk_tier,
      :approval_mode,
      :actor_id,
      :account_id,
      :input_snapshot,
      :scope_snapshot,
      :policy_snapshot,
      :attempt,
      :oban_job_id,
      :result_state,
      :result_summary
    ])
    |> validate_required([:tool_ref, :idempotency_key, :risk_tier, :approval_mode, :actor_id])
    |> unique_constraint(:idempotency_key)
  end

  @doc """
  Changeset for persisting a blocked proposal outcome (scope_invalid / policy_denied).
  Sets a non-`:proposed` status while keeping all other validation (D-18, D-23).
  """
  def blocked_changeset(proposal, attrs) do
    changeset(proposal, attrs)
  end
end
