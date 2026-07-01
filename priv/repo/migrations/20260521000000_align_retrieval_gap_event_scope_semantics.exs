defmodule Cairnloop.Repo.Migrations.AlignRetrievalGapEventScopeSemantics do
  use Ecto.Migration

  def up do
    prefix = Cairnloop.SchemaPrefix.configured()

    gap_events_table =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_retrieval_gap_events",
        schema_prefix: prefix
      )

    alter table(:cairnloop_retrieval_gap_events, prefix: prefix) do
      add(:ui_surface, :string, default: "unspecified", null: false)
    end

    execute("""
    UPDATE #{gap_events_table}
    SET
      ui_surface =
        CASE tenant_scope
          WHEN 'conversation' THEN 'conversation'
          WHEN 'inbox' THEN 'inbox'
          WHEN 'settings' THEN 'settings'
          ELSE 'unspecified'
        END,
      tenant_scope =
        CASE
          WHEN tenant_scope IN ('conversation', 'inbox', 'settings') THEN 'host_user_scoped'
          WHEN tenant_scope IS NULL OR tenant_scope = '' THEN
            CASE
              WHEN host_user_id IS NOT NULL AND host_user_id <> '' THEN 'host_user_scoped'
              ELSE 'system_unscoped'
            END
          ELSE tenant_scope
        END
    """)

    alter table(:cairnloop_retrieval_gap_events, prefix: prefix) do
      modify(:tenant_scope, :string, default: "system_unscoped", null: false)
    end

    create(index(:cairnloop_retrieval_gap_events, [:ui_surface], prefix: prefix))

    create(
      index(
        :cairnloop_retrieval_gap_events,
        [
          :query_fingerprint,
          :tenant_scope,
          :host_user_id,
          :ui_surface,
          :surface,
          :outcome_class,
          :reason,
          :occurred_at
        ], prefix: prefix)
    )
  end

  def down do
    prefix = Cairnloop.SchemaPrefix.configured()

    gap_events_table =
      Cairnloop.SchemaPrefix.quoted_table("cairnloop_retrieval_gap_events",
        schema_prefix: prefix
      )

    drop_if_exists(
      index(
        :cairnloop_retrieval_gap_events,
        [
          :query_fingerprint,
          :tenant_scope,
          :host_user_id,
          :ui_surface,
          :surface,
          :outcome_class,
          :reason,
          :occurred_at
        ], prefix: prefix)
    )

    drop_if_exists(index(:cairnloop_retrieval_gap_events, [:ui_surface], prefix: prefix))

    alter table(:cairnloop_retrieval_gap_events, prefix: prefix) do
      modify(:tenant_scope, :string, null: true, default: nil)
    end

    execute("""
    UPDATE #{gap_events_table}
    SET tenant_scope =
      CASE
        WHEN ui_surface IN ('conversation', 'inbox', 'settings') THEN ui_surface
        WHEN tenant_scope = 'system_unscoped' THEN NULL
        ELSE tenant_scope
      END
    """)

    alter table(:cairnloop_retrieval_gap_events, prefix: prefix) do
      remove(:ui_surface)
    end
  end
end
