defmodule Cairnloop.Repo.Migrations.AddRetrievalCorpusSupport do
  use Ecto.Migration

  def up do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    chunks_table = Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks", schema_prefix: prefix)

    chunks_search_vector_function =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks_search_vector_update",
        schema_prefix: prefix
      )

    resolved_chunks_table =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_resolved_case_chunks", schema_prefix: prefix)

    resolved_chunks_search_vector_function =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_resolved_case_chunks_search_vector_update",
        schema_prefix: prefix
      )

    alter table(:cairnloop_chunks, prefix: prefix) do
      add(:chunk_index, :integer, null: false, default: 0)
      add(:heading, :text)
      add(:search_vector, :tsvector)
    end

    execute("""
    UPDATE #{chunks_table}
    SET search_vector =
      to_tsvector('english', coalesce(heading, '') || ' ' || coalesce(content, ''))
    """)

    execute("""
    CREATE FUNCTION #{chunks_search_vector_function}()
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
    BEFORE INSERT OR UPDATE ON #{chunks_table}
    FOR EACH ROW EXECUTE FUNCTION #{chunks_search_vector_function}()
    """)

    create(unique_index(:cairnloop_chunks, [:revision_id, :chunk_index], prefix: prefix))
    create(index(:cairnloop_chunks, [:search_vector], using: :gin, prefix: prefix))

    create table(:cairnloop_resolved_case_evidences, prefix: prefix) do
      add(
        :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all), null: false)

      add(:subject, :text, null: false)
      add(:issue_summary, :text, null: false)
      add(:resolution_note, :text, null: false)
      add(:actions_taken, {:array, :text}, null: false, default: [])
      add(:outcome, :text, null: false)
      add(:resolved_at, :utc_datetime_usec, null: false)
      add(:host_user_id, :string)
      add(:metadata, :map, null: false, default: %{})
      add(:citation_backreferences, {:array, :map}, null: false, default: [])
      timestamps()
    end

    create(unique_index(:cairnloop_resolved_case_evidences, [:conversation_id], prefix: prefix))
    create(index(:cairnloop_resolved_case_evidences, [:resolved_at], prefix: prefix))
    create(index(:cairnloop_resolved_case_evidences, [:host_user_id], prefix: prefix))

    create table(:cairnloop_resolved_case_chunks, prefix: prefix) do
      add(
        :resolved_case_evidence_id,
        references(:cairnloop_resolved_case_evidences, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      add(:chunk_index, :integer, null: false)
      add(:content, :text, null: false)
      add(:embedding, :vector, size: 1536)
      add(:search_vector, :tsvector)
      timestamps()
    end

    execute("""
    CREATE FUNCTION #{resolved_chunks_search_vector_function}()
    RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', coalesce(NEW.content, ''));
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER cairnloop_resolved_case_chunks_search_vector_trigger
    BEFORE INSERT OR UPDATE ON #{resolved_chunks_table}
    FOR EACH ROW EXECUTE FUNCTION #{resolved_chunks_search_vector_function}()
    """)

    create(
      unique_index(:cairnloop_resolved_case_chunks, [:resolved_case_evidence_id, :chunk_index],
        prefix: prefix
      )
    )

    create(index(:cairnloop_resolved_case_chunks, [:search_vector], using: :gin, prefix: prefix))
  end

  def down do
    prefix = Cairnloop.SchemaPrefix.configured()

    chunks_table = Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks", schema_prefix: prefix)

    chunks_search_vector_function =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks_search_vector_update",
        schema_prefix: prefix
      )

    resolved_chunks_table =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_resolved_case_chunks", schema_prefix: prefix)

    resolved_chunks_search_vector_function =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_resolved_case_chunks_search_vector_update",
        schema_prefix: prefix
      )

    execute(
      "DROP TRIGGER IF EXISTS cairnloop_resolved_case_chunks_search_vector_trigger ON #{resolved_chunks_table}"
    )

    execute("DROP FUNCTION IF EXISTS #{resolved_chunks_search_vector_function}()")
    drop(table(:cairnloop_resolved_case_chunks, prefix: prefix))

    drop(table(:cairnloop_resolved_case_evidences, prefix: prefix))

    drop_if_exists(unique_index(:cairnloop_chunks, [:revision_id, :chunk_index], prefix: prefix))
    drop_if_exists(index(:cairnloop_chunks, [:search_vector], prefix: prefix))
    execute("DROP TRIGGER IF EXISTS cairnloop_chunks_search_vector_trigger ON #{chunks_table}")
    execute("DROP FUNCTION IF EXISTS #{chunks_search_vector_function}()")

    alter table(:cairnloop_chunks, prefix: prefix) do
      remove(:search_vector)
      remove(:heading)
      remove(:chunk_index)
    end
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute("CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}")
  end
end
