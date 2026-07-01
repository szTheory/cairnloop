defmodule Cairnloop.MCP do
  @moduledoc """
  Public facade for the MCP token management and validation.
  """

  require Logger
  import Ecto.Query

  alias Cairnloop.MCP.Token

  defp support_prefix, do: Cairnloop.SchemaPrefix.configured()
  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  defp prefixed(queryable),
    do: queryable |> Ecto.Queryable.to_query() |> put_query_prefix(support_prefix())

  @doc """
  Issues a new token.
  Returns `{:ok, token_record, raw_token_string}` on success.
  """
  def issue_token(attrs \\ %{}) do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    token_hash = :crypto.hash(:sha256, raw_token)

    attrs = Map.put(attrs, :token_hash, token_hash)
    attrs = Map.put_new(attrs, :name, "MCP Token")

    %Token{}
    |> Token.changeset(attrs)
    |> repo().insert(repo_opts())
    |> case do
      {:ok, token} -> {:ok, token, raw_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Validates a given raw token string.
  Returns `{:ok, token}` if valid, or `{:error, :unauthorized}`.
  """
  def validate_token(raw_token) when is_binary(raw_token) do
    token_hash = :crypto.hash(:sha256, raw_token)

    query =
      from(t in prefixed(Token),
        where: t.token_hash == ^token_hash,
        where: is_nil(t.revoked_at),
        where: is_nil(t.expires_at) or t.expires_at > ^DateTime.utc_now()
      )

    case repo().one(query) do
      nil -> {:error, :unauthorized}
      token -> {:ok, token}
    end
  end

  def validate_token(_), do: {:error, :unauthorized}

  @doc """
  Updates an existing token.
  """
  def update_token(%Token{} = token, attrs) do
    token
    |> Token.changeset(attrs)
    |> repo().update(repo_opts())
  end

  @doc """
  Revokes an active token.
  """
  def revoke_token(%Token{} = token) do
    token
    |> Token.changeset(%{revoked_at: DateTime.utc_now()})
    |> repo().update(repo_opts())
  end

  @doc """
  Lists all active tokens.
  """
  def list_active_tokens do
    repo().all(
      from(t in prefixed(Token),
        where: is_nil(t.revoked_at),
        order_by: [desc: t.inserted_at]
      )
    )
  end

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end
end
