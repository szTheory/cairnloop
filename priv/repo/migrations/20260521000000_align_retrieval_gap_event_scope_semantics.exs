defmodule Cairnloop.Repo.Migrations.AlignRetrievalGapEventScopeSemantics do
  use Ecto.Migration

  def up do
    alter table(:cairnloop_retrieval_gap_events) do
      add(:ui_surface, :string, default: "unspecified", null: false)
    end

    execute("""
    UPDATE cairnloop_retrieval_gap_events
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

    alter table(:cairnloop_retrieval_gap_events) do
      modify(:tenant_scope, :string, default: "system_unscoped", null: false)
    end

    create(index(:cairnloop_retrieval_gap_events, [:ui_surface]))
    create(
      index(:cairnloop_retrieval_gap_events, [
        :query_fingerprint,
        :tenant_scope,
        :host_user_id,
        :ui_surface,
        :surface,
        :outcome_class,
        :reason,
        :occurred_at
      ])
    )
  end

  def down do
    drop_if_exists(
      index(:cairnloop_retrieval_gap_events, [
        :query_fingerprint,
        :tenant_scope,
        :host_user_id,
        :ui_surface,
        :surface,
        :outcome_class,
        :reason,
        :occurred_at
      ])
    )

    drop_if_exists(index(:cairnloop_retrieval_gap_events, [:ui_surface]))

    alter table(:cairnloop_retrieval_gap_events) do
      modify(:tenant_scope, :string, null: true, default: nil)
    end

    execute("""
    UPDATE cairnloop_retrieval_gap_events
    SET tenant_scope =
      CASE
        WHEN ui_surface IN ('conversation', 'inbox', 'settings') THEN ui_surface
        WHEN tenant_scope = 'system_unscoped' THEN NULL
        ELSE tenant_scope
      END
    """)

    alter table(:cairnloop_retrieval_gap_events) do
      remove(:ui_surface)
    end
  end
end
