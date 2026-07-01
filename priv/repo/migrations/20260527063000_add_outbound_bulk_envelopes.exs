defmodule Cairnloop.Repo.Migrations.AddOutboundBulkEnvelopes do
  @moduledoc """
  Creates `cairnloop_outbound_bulk_envelopes` — the durable audit row per bulk outbound
  action (D-13). One row per bulk attempt: snapshots template, rendered body, and the
  recipient cohort at confirmation time so per-recipient delivery (handled via the sealed
  `Outbound.trigger/2` lane) can correlate back to a single audit envelope (OBS-02).

  Refused attempts (cap exceeded) also persist on this table with
  `status = "refused_cap_exceeded"` and a populated `refused_reason` so OBS-02 reads
  see both submitted and refused lanes from one table.

  No FK from `recipient_conversation_ids` to `cairnloop_conversations`: it's an integer
  array, not a single id (research A6); array FKs are awkward, and the join is purely
  audit-time, not a runtime read.
  """
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_outbound_bulk_envelopes, primary_key: false, prefix: prefix) do
      add(:id, :binary_id, primary_key: true)
      add(:template_id, :string, null: false)
      # Snapshotted rendered body — never re-rendered at worker run time (CLAUDE.md).
      add(:rendered_body, :text, null: false)
      # bigint matches the cairnloop_conversations PK type.
      add(:recipient_conversation_ids, {:array, :bigint}, null: false)
      add(:count, :integer, null: false)
      # WR-05: snapshot the cap that was in effect at decision time so OBS-02
      # readers can compare `count` against the policy of the moment. If ops
      # tune `:cairnloop, :max_batch_size` between two bulk attempts, an
      # auditor looking at two envelopes both with `count: 20` cannot tell
      # whether each was below or above the cap at the time unless the cap
      # itself is snapshotted on the row. Populated on BOTH submitted AND
      # refused paths. NOT NULL is safe because both call sites in
      # `Outbound.bulk_trigger/2` always read `cap = max_batch_size()` at
      # entry; no pre-existing rows exist (migration not yet applied per
      # STATE.md blocker, so backfill is unnecessary).
      add(:effective_cap, :integer, null: false)
      # Nullable: actor may be "system" for non-operator-initiated bulk actions.
      add(:requested_by, :string)
      add(:requested_at, :utc_datetime_usec, null: false)
      # "submitted" (fan-out enqueued) | "refused_cap_exceeded" (cap-exceeded attempt persisted).
      add(:status, :string, null: false, default: "submitted")
      # Nullable: only set on refusal.
      add(:refused_reason, :string)

      timestamps()
    end

    # Indexes support OBS-02 queries: "show me bulk attempts ordered by time" and
    # "show me bulk attempts for template X".
    create(index(:cairnloop_outbound_bulk_envelopes, [:requested_at], prefix: prefix))
    create(index(:cairnloop_outbound_bulk_envelopes, [:template_id], prefix: prefix))
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end
end
