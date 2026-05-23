defmodule Cairnloop.Repo.Migrations.CreateKnowledgeBase do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create table(:cairnloop_articles) do
      add :title, :string, null: false
      add :status, :string, null: false, default: "draft"
      timestamps()
    end

    create table(:cairnloop_revisions) do
      add :article_id, references(:cairnloop_articles, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :version, :integer, null: false, default: 1
      add :state, :string, null: false, default: "draft"
      timestamps()
    end

    create index(:cairnloop_revisions, [:article_id])
    create index(:cairnloop_revisions, [:state])

    create table(:cairnloop_chunks) do
      add :revision_id, references(:cairnloop_revisions, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 1536
      timestamps()
    end

    create index(:cairnloop_chunks, [:revision_id])
  end

  def down do
    drop table(:cairnloop_chunks)
    drop table(:cairnloop_revisions)
    drop table(:cairnloop_articles)
    execute "DROP EXTENSION IF EXISTS vector"
  end
end
