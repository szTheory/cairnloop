defmodule Cairnloop.Repo.Migrations.AddRetrievalCorpusSupport do
  use Ecto.Migration

  def up do
    alter table(:cairnloop_chunks) do
      add :chunk_index, :integer, null: false, default: 0
      add :heading, :text
      add :search_vector, :tsvector
    end

    execute("""
    UPDATE cairnloop_chunks
    SET search_vector =
      to_tsvector('english', coalesce(heading, '') || ' ' || coalesce(content, ''))
    """)

    execute("""
    CREATE FUNCTION cairnloop_chunks_search_vector_update()
    RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        to_tsvector('english', coalesce(NEW.heading, '') || ' ' || coalesce(NEW.content, ''));
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER cairnloop_chunks_search_vector_trigger
    BEFORE INSERT OR UPDATE ON cairnloop_chunks
    FOR EACH ROW EXECUTE FUNCTION cairnloop_chunks_search_vector_update()
    """)

    create unique_index(:cairnloop_chunks, [:revision_id, :chunk_index])
    create index(:cairnloop_chunks, [:search_vector], using: :gin)

    create table(:cairnloop_resolved_case_evidences) do
      add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all), null: false
      add :subject, :text, null: false
      add :issue_summary, :text, null: false
      add :resolution_note, :text, null: false
      add :actions_taken, {:array, :text}, null: false, default: []
      add :outcome, :text, null: false
      add :resolved_at, :utc_datetime_usec, null: false
      add :host_user_id, :string
      add :metadata, :map, null: false, default: %{}
      add :citation_backreferences, {:array, :map}, null: false, default: []
      timestamps()
    end

    create unique_index(:cairnloop_resolved_case_evidences, [:conversation_id])
    create index(:cairnloop_resolved_case_evidences, [:resolved_at])
    create index(:cairnloop_resolved_case_evidences, [:host_user_id])

    create table(:cairnloop_resolved_case_chunks) do
      add :resolved_case_evidence_id,
          references(:cairnloop_resolved_case_evidences, on_delete: :delete_all),
          null: false

      add :chunk_index, :integer, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 1536
      add :search_vector, :tsvector
      timestamps()
    end

    execute("""
    CREATE FUNCTION cairnloop_resolved_case_chunks_search_vector_update()
    RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', coalesce(NEW.content, ''));
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER cairnloop_resolved_case_chunks_search_vector_trigger
    BEFORE INSERT OR UPDATE ON cairnloop_resolved_case_chunks
    FOR EACH ROW EXECUTE FUNCTION cairnloop_resolved_case_chunks_search_vector_update()
    """)

    create unique_index(:cairnloop_resolved_case_chunks, [:resolved_case_evidence_id, :chunk_index])
    create index(:cairnloop_resolved_case_chunks, [:search_vector], using: :gin)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS cairnloop_resolved_case_chunks_search_vector_trigger ON cairnloop_resolved_case_chunks")
    execute("DROP FUNCTION IF EXISTS cairnloop_resolved_case_chunks_search_vector_update()")
    drop table(:cairnloop_resolved_case_chunks)

    drop table(:cairnloop_resolved_case_evidences)

    drop_if_exists unique_index(:cairnloop_chunks, [:revision_id, :chunk_index])
    drop_if_exists index(:cairnloop_chunks, [:search_vector])
    execute("DROP TRIGGER IF EXISTS cairnloop_chunks_search_vector_trigger ON cairnloop_chunks")
    execute("DROP FUNCTION IF EXISTS cairnloop_chunks_search_vector_update()")

    alter table(:cairnloop_chunks) do
      remove :search_vector
      remove :heading
      remove :chunk_index
    end
  end
end
