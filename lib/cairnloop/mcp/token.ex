defmodule Cairnloop.MCP.Token do
  @moduledoc """
  Durable token record for MCP OAuth Bearer authentication.

  This schema maps to the `cairnloop_mcp_tokens` table.
  """

  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "cairnloop_mcp_tokens" do
    field(:name, :string)
    field(:token_hash, :binary)
    field(:expires_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Standard changeset for creating a Token.
  """
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:name, :token_hash, :expires_at, :revoked_at])
    |> validate_required([:name, :token_hash])
    |> unique_constraint(:token_hash)
  end
end
