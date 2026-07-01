defmodule Cairnloop.Repo.Migrations.AddArticleSuggestions do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_article_suggestions, prefix: prefix) do
      add(:stable_key, :string, null: false)
      add(:suggestion_type, :string, null: false)
      add(:status, :string, null: false, default: "pending_generation")
      add(:tenant_scope, :string, null: false)
      add(:host_user_id, :string)
      add(:entrypoint_type, :string, null: false)
      add(:entrypoint_id, :integer, null: false)
      add(:article_id, references(:cairnloop_articles, prefix: prefix, on_delete: :nilify_all))

      add(
        :base_revision_id,
        references(:cairnloop_revisions, prefix: prefix, on_delete: :nilify_all)
      )

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

    create(unique_index(:cairnloop_article_suggestions, [:stable_key], prefix: prefix))
    create(index(:cairnloop_article_suggestions, [:status], prefix: prefix))

    create(
      index(:cairnloop_article_suggestions, [:entrypoint_type, :entrypoint_id], prefix: prefix)
    )

    create(index(:cairnloop_article_suggestions, [:evidence_digest], prefix: prefix))
    create(index(:cairnloop_article_suggestions, [:base_revision_id], prefix: prefix))
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end
end
