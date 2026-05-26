defmodule Cairnloop.Repo.Migrations.CreateCairnloopMcpTokens do
  use Ecto.Migration

  def change do
    create table(:cairnloop_mcp_tokens, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:name, :string, null: false)
      add(:token_hash, :binary, null: false)
      add(:expires_at, :utc_datetime_usec)
      add(:revoked_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    # Unique index for token hashes
    create(unique_index(:cairnloop_mcp_tokens, [:token_hash]))
  end
end
