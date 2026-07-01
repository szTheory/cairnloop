defmodule Cairnloop.Repo.Migrations.AddGapCandidatesAndMemberships do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_gap_candidates, prefix: prefix) do
      add(:stable_key, :string, null: false)
      add(:status, :string, null: false, default: "open")
      add(:candidate_type, :string, null: false, default: "mixed")
      add(:title, :text, null: false)
      add(:seed_excerpt, :text, null: false)
      add(:tenant_scope, :string, null: false)
      add(:host_user_id, :string)
      add(:ui_surface, :string, null: false, default: "unspecified")
      add(:first_seen_at, :utc_datetime_usec, null: false)
      add(:last_seen_at, :utc_datetime_usec, null: false)
      add(:evidence_count, :integer, null: false, default: 0)
      add(:manual_case_count, :integer, null: false, default: 0)
      add(:weak_grounding_count, :integer, null: false, default: 0)
      add(:no_hit_count, :integer, null: false, default: 0)
      add(:score, :float, null: false, default: 0.0)
      add(:score_components, :map, null: false, default: %{})
      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:cairnloop_gap_candidates, [:stable_key], prefix: prefix))
    create(index(:cairnloop_gap_candidates, [:status], prefix: prefix))
    create(index(:cairnloop_gap_candidates, [:last_seen_at], prefix: prefix))

    create table(:cairnloop_gap_candidate_memberships, prefix: prefix) do
      add(
        :gap_candidate_id,
        references(:cairnloop_gap_candidates, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      add(:source_type, :string, null: false)
      add(:source_id, :integer, null: false)
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(
      unique_index(
        :cairnloop_gap_candidate_memberships,
        [:gap_candidate_id, :source_type, :source_id],
        name: :cairnloop_gap_candidate_memberships_source_unique_index,
        prefix: prefix
      )
    )
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end
end
