defmodule Cairnloop.Repo.Migrations.CreateKnowledgeBase do
  use Ecto.Migration

  def up do
    prefix = Cairnloop.SchemaPrefix.configured()

    execute("CREATE EXTENSION IF NOT EXISTS vector")
    ensure_schema(prefix)

    create table(:cairnloop_articles, prefix: prefix) do
      add(:title, :string, null: false)
      add(:status, :string, null: false, default: "draft")
      timestamps()
    end

    create table(:cairnloop_revisions, prefix: prefix) do
      add(:article_id, references(:cairnloop_articles, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      add(:content, :text, null: false)
      add(:version, :integer, null: false, default: 1)
      add(:state, :string, null: false, default: "draft")
      timestamps()
    end

    create(index(:cairnloop_revisions, [:article_id], prefix: prefix))
    create(index(:cairnloop_revisions, [:state], prefix: prefix))

    create table(:cairnloop_chunks, prefix: prefix) do
      add(:revision_id, references(:cairnloop_revisions, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      add(:content, :text, null: false)
      add(:embedding, :vector, size: 1536)
      timestamps()
    end

    create(index(:cairnloop_chunks, [:revision_id], prefix: prefix))
  end

  def down do
    prefix = Cairnloop.SchemaPrefix.configured()

    drop(table(:cairnloop_chunks, prefix: prefix))
    drop(table(:cairnloop_revisions, prefix: prefix))
    drop(table(:cairnloop_articles, prefix: prefix))
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute("CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}")
  end
end
