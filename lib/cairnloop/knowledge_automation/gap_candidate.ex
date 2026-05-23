defmodule Cairnloop.KnowledgeAutomation.GapCandidate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.KnowledgeAutomation.GapCandidateMembership

  @status_values [:open, :accepted, :dismissed]
  @candidate_type_values [:no_hit, :weak_grounding, :manual_handling, :mixed]
  @tenant_scope_values [:host_user_scoped, :public_only, :system_unscoped]
  @ui_surface_values [:conversation, :inbox, :settings, :unspecified]

  schema "cairnloop_gap_candidates" do
    field :stable_key, :string
    field :status, Ecto.Enum, values: @status_values, default: :open
    field :candidate_type, Ecto.Enum, values: @candidate_type_values, default: :mixed
    field :title, :string
    field :seed_excerpt, :string
    field :tenant_scope, Ecto.Enum, values: @tenant_scope_values
    field :host_user_id, :string
    field :ui_surface, Ecto.Enum, values: @ui_surface_values, default: :unspecified
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :evidence_count, :integer, default: 0
    field :manual_case_count, :integer, default: 0
    field :weak_grounding_count, :integer, default: 0
    field :no_hit_count, :integer, default: 0
    field :score, :float, default: 0.0
    field :score_components, :map, default: %{}

    field :retrieval_gap_events, {:array, :map}, virtual: true, default: []
    field :manual_handling_evidence, {:array, :map}, virtual: true, default: []

    has_many :memberships, GapCandidateMembership

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(gap_candidate, attrs) do
    gap_candidate
    |> cast(attrs, [
      :stable_key,
      :status,
      :candidate_type,
      :title,
      :seed_excerpt,
      :tenant_scope,
      :host_user_id,
      :ui_surface,
      :first_seen_at,
      :last_seen_at,
      :evidence_count,
      :manual_case_count,
      :weak_grounding_count,
      :no_hit_count,
      :score,
      :score_components
    ])
    |> validate_required([
      :stable_key,
      :status,
      :candidate_type,
      :title,
      :seed_excerpt,
      :tenant_scope,
      :ui_surface,
      :first_seen_at,
      :last_seen_at
    ])
    |> validate_length(:stable_key, min: 8, max: 128)
    |> validate_number(:evidence_count, greater_than_or_equal_to: 0)
    |> validate_number(:manual_case_count, greater_than_or_equal_to: 0)
    |> validate_number(:weak_grounding_count, greater_than_or_equal_to: 0)
    |> validate_number(:no_hit_count, greater_than_or_equal_to: 0)
    |> validate_host_scope()
  end

  defp validate_host_scope(changeset) do
    case {get_field(changeset, :tenant_scope), get_field(changeset, :host_user_id)} do
      {:host_user_scoped, value} when value in [nil, ""] ->
        add_error(changeset, :host_user_id, "must be present for host_user_scoped candidates")

      _ ->
        changeset
    end
  end
end
