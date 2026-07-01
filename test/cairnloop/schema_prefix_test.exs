defmodule Cairnloop.SchemaPrefixTest do
  use ExUnit.Case, async: false

  @schema_files Path.wildcard("lib/cairnloop/**/*.ex") ++ Path.wildcard("lib/cairnloop/*.ex")

  setup do
    original = Application.get_env(:cairnloop, :schema_prefix)

    on_exit(fn ->
      restore_env(:schema_prefix, original)
    end)

    :ok
  end

  test "new installs default to the cairnloop schema prefix" do
    Application.delete_env(:cairnloop, :schema_prefix)

    assert Cairnloop.SchemaPrefix.default() == "cairnloop"
    assert Cairnloop.SchemaPrefix.configured() == "cairnloop"
    assert Cairnloop.SchemaPrefix.repo_opts() == [prefix: "cairnloop"]

    assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks") ==
             ~s("cairnloop"."cairnloop_chunks")
  end

  test "public compatibility prefers explicit public schema" do
    assert Cairnloop.SchemaPrefix.configured(schema_prefix: "public") == "public"

    repo_opts = Cairnloop.SchemaPrefix.repo_opts(timeout: 1_000, schema_prefix: "public")
    assert Keyword.get(repo_opts, :prefix) == "public"
    assert Keyword.get(repo_opts, :timeout) == 1_000
    refute Keyword.has_key?(repo_opts, :schema_prefix)

    assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks", schema_prefix: "public") ==
             ~s("public"."cairnloop_chunks")
  end

  test "legacy nil and empty-string compatibility still target unqualified public tables" do
    Application.put_env(:cairnloop, :schema_prefix, nil)

    assert Cairnloop.SchemaPrefix.configured() == nil
    assert Cairnloop.SchemaPrefix.repo_opts(timeout: 1_000) == [timeout: 1_000]
    assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks") == ~s("cairnloop_chunks")

    assert Cairnloop.SchemaPrefix.configured(schema_prefix: "") == nil
  end

  test "schema prefix rejects unsafe identifiers" do
    unsafe_values = [
      "bad; DROP SCHEMA public",
      "bad prefix",
      "cairnloop,public",
      "cairnloop.public",
      "cairnloop-tenant"
    ]

    for unsafe <- unsafe_values do
      Application.put_env(:cairnloop, :schema_prefix, unsafe)

      assert_raise ArgumentError, fn ->
        Cairnloop.SchemaPrefix.configured()
      end

      assert_raise ArgumentError, fn ->
        Cairnloop.SchemaPrefix.quote_identifier!(unsafe)
      end
    end
  end

  test "test config compiles dedicated by default with explicit public override" do
    source = File.read!("config/test.exs")

    assert source =~ ~S|System.get_env("CAIRNLOOP_SCHEMA_PREFIX", "cairnloop")|
    assert source =~ ~s(config :cairnloop, :schema_prefix, schema_prefix)
    refute source =~ ~s(config :cairnloop, :schema_prefix, nil)
  end

  test "every Cairnloop Ecto schema declares the configured schema prefix" do
    schema_files =
      @schema_files
      |> Enum.filter(fn path -> File.read!(path) =~ ~s(schema "cairnloop_) end)

    assert schema_files != []

    for path <- schema_files do
      source = File.read!(path)

      expected =
        ~s|@schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")|

      assert source =~ expected, "expected #{path} to declare Cairnloop schema prefix"
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
end
