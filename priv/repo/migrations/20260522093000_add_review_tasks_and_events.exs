defmodule Cairnloop.Repo.Migrations.AddReviewTasksAndEvents do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_review_tasks, prefix: prefix) do
      add(
        :article_suggestion_id,
        references(:cairnloop_article_suggestions, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      add(:status, :string, null: false, default: "pending_review")
      add(:tenant_scope, :string, null: false)
      add(:host_user_id, :string)
      add(:last_decision, :string)
      add(:last_reason, :string)
      add(:last_actor_id, :string)
      add(:last_decided_at, :utc_datetime_usec)
      add(:notes, :text)

      add(
        :staged_article_id,
        references(:cairnloop_articles, prefix: prefix, on_delete: :nilify_all)
      )

      add(
        :staged_revision_id,
        references(:cairnloop_revisions, prefix: prefix, on_delete: :nilify_all)
      )

      add(
        :published_revision_id,
        references(:cairnloop_revisions, prefix: prefix, on_delete: :nilify_all)
      )

      add(:published_at, :utc_datetime_usec)
      add(:publish_status, :string, null: false, default: "not_started")
      add(:reindex_status, :string, null: false, default: "not_started")
      add(:needs_re_review, :boolean, null: false, default: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:cairnloop_review_tasks, [:status, :inserted_at], prefix: prefix))
    create(index(:cairnloop_review_tasks, [:article_suggestion_id], prefix: prefix))
    create(index(:cairnloop_review_tasks, [:host_user_id, :status], prefix: prefix))
    create(index(:cairnloop_review_tasks, [:staged_article_id], prefix: prefix))
    create(index(:cairnloop_review_tasks, [:staged_revision_id], prefix: prefix))
    create(index(:cairnloop_review_tasks, [:published_revision_id], prefix: prefix))

    create(
      unique_index(
        :cairnloop_review_tasks,
        [:article_suggestion_id],
        name: :cairnloop_review_tasks_one_active_task_per_suggestion_index,
        where:
          "status IN ('pending_review', 'review_needed', 'approved_ready_to_publish', 'deferred')",
        prefix: prefix
      )
    )

    create table(:cairnloop_review_task_events, prefix: prefix) do
      add(
        :review_task_id,
        references(:cairnloop_review_tasks, prefix: prefix, on_delete: :delete_all), null: false)

      add(:event_type, :string, null: false)
      add(:from_status, :string)
      add(:to_status, :string, null: false)
      add(:decision, :string)
      add(:reason, :string)
      add(:actor_id, :string, null: false)
      add(:notes, :text)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:cairnloop_review_task_events, [:review_task_id, :inserted_at], prefix: prefix))
    create(index(:cairnloop_review_task_events, [:event_type, :inserted_at], prefix: prefix))
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end
end
