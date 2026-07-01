defmodule Cairnloop.TestHost.Migrations.CreateHostOwnedTables do
  @moduledoc """
  Creates the HOST-OWNED tables that Cairnloop's schemas map to but its own migrations
  do NOT create (`cairnloop_conversations`, `cairnloop_messages`, `cairnloop_drafts`).
  A real host application owns these; this migration stands in for that host so the
  integration suite has a complete schema. Lives outside `priv/repo/migrations` (run via
  `--migrations-path priv/test_host/migrations`) so it never ships with the library.
  """
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()

    if prefix do
      execute(
        "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
        "SELECT 1"
      )
    end

    create table(:cairnloop_conversations, prefix: prefix) do
      add(:status, :string, null: false, default: "open")
      add(:subject, :string)
      add(:host_user_id, :string)
      add(:customer_ref, :string)
      add(:resolved_at, :utc_datetime_usec)
      add(:csat_rating, :string)

      timestamps()
    end

    create table(:cairnloop_messages, prefix: prefix) do
      add(:content, :text)
      add(:role, :string, null: false, default: "user")
      add(:metadata, :map, default: %{})

      add(
        :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all)
      )

      timestamps()
    end

    create(index(:cairnloop_messages, [:conversation_id], prefix: prefix))

    create table(:cairnloop_drafts, prefix: prefix) do
      add(:content, :text)
      add(:proposal_type, :string, null: false, default: "reply")
      add(:operator_summary, :text)
      add(:customer_reply, :text)
      add(:evidence_snapshot, :map, default: %{})
      add(:grounding_metadata, :map, default: %{})
      add(:clarification_attempts, :integer, default: 0)
      add(:status, :string, null: false, default: "pending")

      add(
        :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all)
      )

      timestamps()
    end

    create(index(:cairnloop_drafts, [:conversation_id], prefix: prefix))
  end
end
