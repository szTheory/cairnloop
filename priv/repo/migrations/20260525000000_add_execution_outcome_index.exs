defmodule Cairnloop.Repo.Migrations.AddExecutionOutcomeIndex do
  @moduledoc """
  Adds a filtered index on `cairnloop_tool_approvals.status` scoped to the two
  Phase 16 terminal execution statuses (:executed, :execution_failed).

  No `ALTER TABLE` is needed: the status column is stored as `:string` (confirmed in
  `20260524120001_add_tool_approvals.exs`), so new atoms are accepted by Postgres
  without any column or type migration. Adding them to `@status_values` in the Ecto
  schema is sufficient (D16-08).

  The index supports efficient execution-outcome queries, e.g.:
    - "list all executed approvals for an account" (dashboard, audit, OBS-02 attribution)
    - "list failed approvals for retry/escalation flows"

  The partial predicate keeps the index small — the majority of rows will be in
  terminal non-execution statuses (:rejected, :expired, :invalidated) which are excluded.
  """
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()

    create(
      index(:cairnloop_tool_approvals, [:status, :decided_at],
        name: :cairnloop_tool_approvals_execution_outcome_index,
        where: "status IN ('executed', 'execution_failed')",
        prefix: prefix
      )
    )
  end
end
