defmodule Cairnloop.Repo.Migrations.AddArticleSuggestions do
  use Ecto.Migration

  def change do
    create table(:cairnloop_article_suggestions) do
      add(:stable_key, :string, null: false)
      add(:suggestion_type, :string, null: false)
      add(:status, :string, null: false, default: "pending_generation")
      add(:tenant_scope, :string, null: false)
      add(:host_user_id, :string)
      add(:entrypoint_type, :string, null: false)
      add(:entrypoint_id, :integer, null: false)
      add(:article_id, references(:cairnloop_articles, on_delete: :nilify_all))
      add(:base_revision_id, references(:cairnloop_revisions, on_delete: :nilify_all))
      add(:title, :text)
      add(:change_summary, :text)
      add(:operator_summary, :text)
      add(:proposed_markdown, :text, null: false)
      add(:evidence_snapshot, {:array, :map}, null: false, default: [])
      add(:grounding_metadata, :map, null: false, default: %{})
      add(:evidence_digest, :string)
      add(:generated_at, :utc_datetime_usec)
      add(:dismissed_at, :utc_datetime_usec)
      add(:manual_edit_opened_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:cairnloop_article_suggestions, [:stable_key]))
    create(index(:cairnloop_article_suggestions, [:status]))
    create(index(:cairnloop_article_suggestions, [:entrypoint_type, :entrypoint_id]))
    create(index(:cairnloop_article_suggestions, [:evidence_digest]))
    create(index(:cairnloop_article_suggestions, [:base_revision_id]))
  end
end
