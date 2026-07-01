defmodule CairnloopExample.Repo.Migrations.CreateCairnloopTables do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_conversations, prefix: prefix) do
      add(:status, :string, null: false)
      add(:subject, :string)
      add(:host_user_id, :string)
      add(:customer_ref, :string)
      add(:resolved_at, :utc_datetime_usec)
      add(:csat_rating, :string)

      timestamps()
    end

    create table(:cairnloop_messages, prefix: prefix) do
      add(:content, :text, null: false)
      add(:role, :string, null: false)
      add(:metadata, :map)

      add(
        :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:cairnloop_messages, [:conversation_id], prefix: prefix))
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end
end
