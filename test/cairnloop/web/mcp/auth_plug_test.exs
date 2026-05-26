defmodule Cairnloop.Web.MCP.AuthPlugTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias Cairnloop.Web.MCP.AuthPlug
  alias Cairnloop.MCP

  defmodule MockRepo do
    def insert(changeset) do
      struct =
        changeset
        |> Ecto.Changeset.apply_changes()
        |> Map.put(:id, Ecto.UUID.generate())

      Process.put(:mcp_tokens, [struct | Process.get(:mcp_tokens, [])])
      {:ok, struct}
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
        t.token_hash == token_hash and is_nil(t.revoked_at) and is_nil(t.expires_at)
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

  test "assigns mcp_token if Bearer is valid" do
    {:ok, token, raw} = MCP.issue_token(%{name: "Test"})

    conn =
      conn(:post, "/")
      |> put_req_header("authorization", "Bearer #{raw}")
      |> AuthPlug.call([])

    assert conn.assigns.mcp_token.id == token.id
    refute conn.halted
  end

  test "leaves mcp_token unset and does not halt if Bearer is invalid" do
    conn =
      conn(:post, "/")
      |> put_req_header("authorization", "Bearer invalid")
      |> AuthPlug.call([])

    refute Map.has_key?(conn.assigns, :mcp_token)
    refute conn.halted
  end

  test "leaves mcp_token unset and does not halt if no header" do
    conn =
      conn(:post, "/")
      |> AuthPlug.call([])

    refute Map.has_key?(conn.assigns, :mcp_token)
    refute conn.halted
  end
end
