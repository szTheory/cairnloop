defmodule Cairnloop.MCPTest do
  use ExUnit.Case, async: false

  alias Cairnloop.MCP

  defmodule MockRepo do
    def insert(%Ecto.Changeset{} = changeset, opts \\ []) do
      Process.put(:mcp_insert_opts, opts)

      if changeset.valid? do
        struct =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:id, Ecto.UUID.generate())
          |> Map.put(:inserted_at, DateTime.utc_now())
          |> Map.put(:updated_at, DateTime.utc_now())

        Process.put(:mcp_tokens, [struct | Process.get(:mcp_tokens, [])])
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def update(%Ecto.Changeset{} = changeset, opts \\ []) do
      Process.put(:mcp_update_opts, opts)

      if changeset.valid? do
        updated =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:updated_at, DateTime.utc_now())

        existing = Process.get(:mcp_tokens, [])
        updated_list = Enum.map(existing, fn t -> if t.id == updated.id, do: updated, else: t end)
        Process.put(:mcp_tokens, updated_list)
        {:ok, updated}
      else
        {:error, changeset}
      end
    end

    def one(%Ecto.Query{} = query) do
      Process.put(:mcp_one_query, query)

      token_hash =
        Enum.find_value(query.wheres, fn clause ->
          Enum.find_value(clause.params, fn
            {hash, {_, :token_hash}} -> hash
            _ -> nil
          end)
        end)

      Process.get(:mcp_tokens, [])
      |> Enum.find(fn t ->
        t.token_hash == token_hash and
          is_nil(t.revoked_at) and
          (is_nil(t.expires_at) or DateTime.compare(t.expires_at, DateTime.utc_now()) == :gt)
      end)
    end

    def all(%Ecto.Query{} = query) do
      Process.put(:mcp_all_query, query)
      Process.get(:mcp_tokens, [])
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.put(:mcp_tokens, [])
    Process.delete(:mcp_insert_opts)
    Process.delete(:mcp_update_opts)
    Process.delete(:mcp_one_query)
    Process.delete(:mcp_all_query)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  describe "issue_token/1" do
    test "returns a raw token and saves a hashed token record" do
      assert {:ok, token, raw} = MCP.issue_token(%{name: "Test Token"})

      assert is_binary(raw)
      assert token.name == "Test Token"
      assert token.token_hash == :crypto.hash(:sha256, raw)
      assert Keyword.get(Process.get(:mcp_insert_opts), :prefix) == "cairnloop"

      # Check it's in the DB
      assert length(Process.get(:mcp_tokens, [])) == 1
    end

    test "defaults name if not provided" do
      assert {:ok, token, _raw} = MCP.issue_token()
      assert token.name == "MCP Token"
    end
  end

  describe "validate_token/1" do
    test "returns {:ok, token} for a valid raw token" do
      {:ok, token, raw} = MCP.issue_token(%{name: "Test Token"})

      assert {:ok, valid_token} = MCP.validate_token(raw)
      assert valid_token.id == token.id
      assert Process.get(:mcp_one_query).prefix == "cairnloop"
    end

    test "returns {:error, :unauthorized} for an invalid raw token" do
      assert {:error, :unauthorized} = MCP.validate_token("invalid_token_string")
    end

    test "returns {:error, :unauthorized} for a revoked token" do
      {:ok, token, raw} = MCP.issue_token(%{name: "Revoked"})
      {:ok, _} = MCP.revoke_token(token)

      assert {:error, :unauthorized} = MCP.validate_token(raw)
    end

    test "returns {:error, :unauthorized} for an expired token" do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second)
      {:ok, _token, raw} = MCP.issue_token(%{name: "Expired", expires_at: past})

      assert {:error, :unauthorized} = MCP.validate_token(raw)
    end
  end

  describe "update_token/2" do
    test "updates the token name" do
      {:ok, token, _raw} = MCP.issue_token(%{name: "Old Name"})
      assert {:ok, updated_token} = MCP.update_token(token, %{name: "New Name"})
      assert updated_token.name == "New Name"
      assert Keyword.get(Process.get(:mcp_update_opts), :prefix) == "cairnloop"

      [db_token] = Process.get(:mcp_tokens)
      assert db_token.name == "New Name"
    end
  end

  describe "revoke_token/1" do
    test "sets revoked_at timestamp" do
      {:ok, token, _raw} = MCP.issue_token(%{name: "To Revoke"})
      assert is_nil(token.revoked_at)

      assert {:ok, revoked_token} = MCP.revoke_token(token)
      assert not is_nil(revoked_token.revoked_at)
      assert Keyword.get(Process.get(:mcp_update_opts), :prefix) == "cairnloop"

      # Check DB is updated
      [db_token] = Process.get(:mcp_tokens)
      assert not is_nil(db_token.revoked_at)
    end
  end

  describe "list_active_tokens/0" do
    test "queries active tokens through the configured prefix" do
      assert [] = MCP.list_active_tokens()
      assert Process.get(:mcp_all_query).prefix == "cairnloop"
    end
  end
end
