defmodule Cairnloop.KnowledgeAutomation.GapCandidateMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.KnowledgeAutomation.GapCandidate

  @source_type_values [:retrieval_gap_event, :manual_handling_case]

  schema "cairnloop_gap_candidate_memberships" do
    field :source_type, Ecto.Enum, values: @source_type_values
    field :source_id, :integer

    belongs_to :gap_candidate, GapCandidate

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:gap_candidate_id, :source_type, :source_id])
    |> validate_required([:source_type, :source_id])
    |> validate_number(:source_id, greater_than: 0)
    |> unique_constraint([:gap_candidate_id, :source_type, :source_id],
      name: :cairnloop_gap_candidate_memberships_gap_candidate_id_source_type_sour_index
    )
  end
end
