defmodule Cairnloop.TestHost.Migrations.AddConversationSlas do
  @moduledoc """
  Creates the host-owned `cairnloop_conversation_slas` table that `Cairnloop.Chat.resolve_conversation/2`
  queries via `Ecto.Multi.merge`. The table is installed in real host apps via
  `mix cairnloop.add_sla_table`; this migration stands in for that host so the integration
  suite has a complete schema. Lives in `priv/test_host/migrations` (not shipped with the library).
  """
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()

    create table(:cairnloop_conversation_slas, prefix: prefix) do
      add(:target_type, :string, null: false)
      add(:status, :string, null: false)
      add(:target_at, :utc_datetime_usec, null: false)
      add(:completed_at, :utc_datetime_usec)

      add(
        :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(index(:cairnloop_conversation_slas, [:conversation_id], prefix: prefix))
    create(index(:cairnloop_conversation_slas, [:conversation_id, :status], prefix: prefix))
  end
end
