defmodule Cairnloop.MigrationsTest do
  use ExUnit.Case, async: true

  @phase_59_prefix_migrations Path.wildcard("priv/repo/migrations/*.exs") |> Enum.sort()
  @test_host_migrations Path.wildcard("priv/test_host/migrations/*.exs") |> Enum.sort()
  @test_host_oban_migration "priv/test_host/migrations/20260101000001_add_oban_jobs.exs"
  @example_config "examples/cairnloop_example/config/config.exs"
  @example_migrations Path.wildcard("examples/cairnloop_example/priv/repo/migrations/*.exs")
                      |> Enum.sort()
  @example_oban_migration "examples/cairnloop_example/priv/repo/migrations/20260525201621_add_oban.exs"
  @example_vector_migration "examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs"

  test "library migrations do not drop shared pgvector extension" do
    migration_sources =
      migration_sources()

    assert migration_sources != []

    for {path, source} <- migration_sources do
      refute source =~ ~r/DROP\s+EXTENSION\s+(?:IF\s+EXISTS\s+)?vector/i,
             "expected #{path} not to drop the shared vector extension"
    end
  end

  test "Phase 59 library migrations use explicit Cairnloop schema prefixes" do
    for {path, source} <- phase_59_prefix_sources() do
      assert source =~ "prefix = Cairnloop.SchemaPrefix.configured()",
             "expected #{path} to resolve the configured Cairnloop schema prefix"

      refute source =~ ~r/SET\s+search_path/i,
             "expected #{path} not to rely on SET search_path for prefix correctness"

      unprefixed_lines =
        source
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_no} -> unprefixed_cairnloop_ddl?(line) end)

      assert unprefixed_lines == [],
             "expected #{path} DDL helpers to include prefix: prefix, offending lines: #{inspect(unprefixed_lines)}"
    end
  end

  test "raw SQL in library migrations does not hardcode public-style Cairnloop table names" do
    for {path, source} <- migration_sources() do
      refute source =~ ~r/\bUPDATE\s+cairnloop_/i,
             "expected #{path} raw UPDATE statements to use Cairnloop.SchemaPrefix.quoted_table/1"

      refute source =~ ~r/\bON\s+cairnloop_/i,
             "expected #{path} raw trigger/table references to use Cairnloop.SchemaPrefix.quoted_table/1"

      refute source =~ ~r/\bFUNCTION\s+cairnloop_/i,
             "expected #{path} raw function references to use Cairnloop.SchemaPrefix.quoted_table/1"
    end
  end

  test "test-host support migrations use explicit Cairnloop schema prefixes" do
    for {path, source} <- test_host_support_sources() do
      if support_domain_ddl?(source) do
        assert source =~ "prefix = Cairnloop.SchemaPrefix.configured()",
               "expected #{path} to resolve the configured Cairnloop schema prefix"
      end

      unprefixed_lines =
        source
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_no} -> unprefixed_cairnloop_ddl?(line) end)

      assert unprefixed_lines == [],
             "expected #{path} test-host DDL helpers to include prefix: prefix, offending lines: #{inspect(unprefixed_lines)}"
    end
  end

  test "test-host Oban migration remains host-owned and unprefixed" do
    source = File.read!(@test_host_oban_migration)

    assert source =~ "Oban.Migration.up()"
    assert source =~ "Oban.Migration.down()"
    refute source =~ "Cairnloop.SchemaPrefix"
    refute source =~ "prefix: prefix"
  end

  test "example app config uses the dedicated Cairnloop schema prefix by default" do
    source = File.read!(@example_config)

    assert source =~ ~s(schema_prefix: "cairnloop")
  end

  test "example support migrations use explicit Cairnloop schema prefixes" do
    for {path, source} <- example_support_sources() do
      if support_domain_ddl?(source) do
        assert source =~ "prefix = Cairnloop.SchemaPrefix.configured()",
               "expected #{path} to resolve the configured Cairnloop schema prefix"
      end

      unprefixed_lines =
        source
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_no} -> unprefixed_cairnloop_ddl?(line) end)

      assert unprefixed_lines == [],
             "expected #{path} example DDL helpers to include prefix: prefix, offending lines: #{inspect(unprefixed_lines)}"
    end
  end

  test "example Oban migration remains host-owned and unprefixed" do
    source = File.read!(@example_oban_migration)

    assert source =~ "Oban.Migration.up()"
    assert source =~ "Oban.Migration.down(version: 1)"
    refute source =~ "Cairnloop.SchemaPrefix"
    refute source =~ "prefix: prefix"
  end

  test "example vector rollback does not drop the shared vector extension" do
    source = File.read!(@example_vector_migration)

    refute source =~ ~r/DROP\s+EXTENSION\s+(?:IF\s+EXISTS\s+)?vector/i
  end

  defp phase_59_prefix_sources do
    Enum.map(@phase_59_prefix_migrations, &{&1, File.read!(&1)})
  end

  defp test_host_support_sources do
    @test_host_migrations
    |> Enum.reject(&(&1 == @test_host_oban_migration))
    |> Enum.map(&{&1, File.read!(&1)})
  end

  defp example_support_sources do
    @example_migrations
    |> Enum.reject(&(&1 in [@example_oban_migration, @example_vector_migration]))
    |> Enum.map(&{&1, File.read!(&1)})
  end

  defp migration_sources do
    "priv/repo/migrations/*.exs"
    |> Path.wildcard()
    |> Enum.map(&{&1, File.read!(&1)})
  end

  defp unprefixed_cairnloop_ddl?(line) do
    ddl_helper? =
      line =~
        ~r/\b(?:create|alter|drop|drop_if_exists)\s*\(?\s*(?:table|index|unique_index)\(:cairnloop_/ or
        line =~ ~r/\breferences\(:cairnloop_/

    ddl_helper? and not String.contains?(line, "prefix: prefix")
  end

  defp support_domain_ddl?(source) do
    source
    |> String.split("\n")
    |> Enum.any?(&unprefixed_or_prefixed_support_ddl?/1)
  end

  defp unprefixed_or_prefixed_support_ddl?(line) do
    line =~
      ~r/\b(?:create|alter|drop|drop_if_exists)\s*\(?\s*(?:table|index|unique_index)\(:cairnloop_/ or
      line =~ ~r/\breferences\(:cairnloop_/
  end
end
