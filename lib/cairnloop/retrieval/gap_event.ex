defmodule Cairnloop.Retrieval.GapEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.Retrieval.GapEventSnapshot

  @surface_values [:draft_generation, :search_modal, :api, :unspecified]
  @outcome_values [:empty_recall, :retrieval_error, :weak_grounding, :policy_limit]
  @reason_values [
    :canonical_results,
    :mixed_results,
    :assistive_only_results,
    :no_canonical_results,
    :canonical_insufficient_detail,
    :clarification_limit_reached,
    :provider_timeout,
    :index_unavailable,
    :unexpected_error
  ]
  @max_excerpt_length 160
  @max_snapshots 5

  schema "cairnloop_retrieval_gap_events" do
    field(:occurred_at, :utc_datetime_usec)
    field(:surface, Ecto.Enum, values: @surface_values)
    field(:outcome_class, Ecto.Enum, values: @outcome_values)
    field(:reason, Ecto.Enum, values: @reason_values)
    field(:host_user_id, :string)
    field(:tenant_scope, :string)
    field(:query_fingerprint, :string)
    field(:sanitized_query_excerpt, :string)
    field(:canonical_hit_count, :integer, default: 0)
    field(:assistive_hit_count, :integer, default: 0)
    field(:clarification_attempts, :integer, default: 0)

    embeds_many(:attempted_evidence_snapshots, GapEventSnapshot, on_replace: :delete)

    timestamps(updated_at: false)
  end

  def changeset(gap_event, attrs) do
    gap_event
    |> cast(attrs, [
      :occurred_at,
      :surface,
      :outcome_class,
      :reason,
      :host_user_id,
      :tenant_scope,
      :query_fingerprint,
      :sanitized_query_excerpt,
      :canonical_hit_count,
      :assistive_hit_count,
      :clarification_attempts
    ])
    |> cast_embed(:attempted_evidence_snapshots)
    |> validate_required([
      :occurred_at,
      :surface,
      :outcome_class,
      :reason,
      :query_fingerprint,
      :sanitized_query_excerpt
    ])
    |> validate_length(:query_fingerprint, is: 64)
    |> validate_length(:sanitized_query_excerpt, max: @max_excerpt_length)
    |> validate_number(:canonical_hit_count, greater_than_or_equal_to: 0)
    |> validate_number(:assistive_hit_count, greater_than_or_equal_to: 0)
    |> validate_number(:clarification_attempts, greater_than_or_equal_to: 0)
    |> validate_change(:attempted_evidence_snapshots, fn :attempted_evidence_snapshots,
                                                         snapshots ->
      if length(snapshots || []) <= @max_snapshots do
        []
      else
        [attempted_evidence_snapshots: "must contain at most #{@max_snapshots} snapshots"]
      end
    end)
  end
end
