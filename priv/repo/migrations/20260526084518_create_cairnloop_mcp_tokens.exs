defmodule Cairnloop.Repo.Migrations.CreateCairnloopMcpTokens do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()
    ensure_schema(prefix)

    create table(:cairnloop_mcp_tokens, primary_key: false, prefix: prefix) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:name, :string, null: false)
      add(:token_hash, :binary, null: false)
      add(:expires_at, :utc_datetime_usec)
      add(:revoked_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    # Unique index for token hashes
    create(unique_index(:cairnloop_mcp_tokens, [:token_hash], prefix: prefix))
  end

  defp ensure_schema(nil), do: :ok

  defp ensure_schema(prefix) do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end
end
