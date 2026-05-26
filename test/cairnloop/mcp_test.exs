defmodule Cairnloop.MCPTest do
  use ExUnit.Case, async: false

  alias Cairnloop.MCP

  defmodule MockRepo do
    def insert(%Ecto.Changeset{} = changeset) do
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

    def update(%Ecto.Changeset{} = changeset) do
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
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.put(:mcp_tokens, [])

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

  describe "revoke_token/1" do
    test "sets revoked_at timestamp" do
      {:ok, token, _raw} = MCP.issue_token(%{name: "To Revoke"})
      assert is_nil(token.revoked_at)

      assert {:ok, revoked_token} = MCP.revoke_token(token)
      assert not is_nil(revoked_token.revoked_at)

      # Check DB is updated
      [db_token] = Process.get(:mcp_tokens)
      assert not is_nil(db_token.revoked_at)
    end
  end
end
