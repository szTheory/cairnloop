defmodule Cairnloop.Repo.Migrations.AddRetrievalGapEvents do
  use Ecto.Migration

  def change do
    create table(:cairnloop_retrieval_gap_events) do
      add(:occurred_at, :utc_datetime_usec, null: false)
      add(:surface, :string, null: false)
      add(:outcome_class, :string, null: false)
      add(:reason, :string, null: false)
      add(:host_user_id, :string)
      add(:tenant_scope, :string)
      add(:query_fingerprint, :string, null: false)
      add(:sanitized_query_excerpt, :text, null: false)
      add(:canonical_hit_count, :integer, null: false, default: 0)
      add(:assistive_hit_count, :integer, null: false, default: 0)
      add(:clarification_attempts, :integer, null: false, default: 0)
      add(:attempted_evidence_snapshots, {:array, :map}, null: false, default: [])
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create(index(:cairnloop_retrieval_gap_events, [:occurred_at]))
    create(index(:cairnloop_retrieval_gap_events, [:surface]))
    create(index(:cairnloop_retrieval_gap_events, [:outcome_class]))
    create(index(:cairnloop_retrieval_gap_events, [:reason]))
    create(index(:cairnloop_retrieval_gap_events, [:host_user_id]))
    create(index(:cairnloop_retrieval_gap_events, [:tenant_scope]))
    create(index(:cairnloop_retrieval_gap_events, [:query_fingerprint]))
  end
end
