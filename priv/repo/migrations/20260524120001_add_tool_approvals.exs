defmodule Cairnloop.Repo.Migrations.AddToolApprovals do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_tool_approvals, prefix: prefix) do
      add(
        :tool_proposal_id,
        references(:cairnloop_tool_proposals, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      # Enum stored as :string — mirrors review_tasks migration pattern
      add(:status, :string, null: false, default: "pending")
      add(:decided_by, :string)
      add(:last_decision, :string)
      add(:decided_at, :utc_datetime_usec)
      add(:reason, :text)
      add(:expires_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    # Compound index for status-filtered proposal lookups
    create(index(:cairnloop_tool_approvals, [:tool_proposal_id, :status], prefix: prefix))

    # Expiry-sweep predicate index
    create(index(:cairnloop_tool_approvals, [:status, :expires_at], prefix: prefix))

    # One-active-lane constraint (APRV-04):
    # Only one `:pending` approval may exist per tool_proposal_id at any time.
    # Mirrors cairnloop_review_tasks_one_active_task_per_suggestion_index pattern.
    create(
      unique_index(
        :cairnloop_tool_approvals,
        [:tool_proposal_id],
        name: :cairnloop_tool_approvals_one_active_lane_index,
        where: "status = 'pending'",
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
