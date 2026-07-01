defmodule Mix.Tasks.Cairnloop.InstallTest do
  use ExUnit.Case, async: true

  @source_path "lib/mix/tasks/cairnloop/install.ex"
  @test_host_migration_path "priv/test_host/migrations/20260101000000_create_host_owned_tables.exs"
  @example_migration_path "examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs"

  test "installer dependency version is derived from mix project version" do
    source = File.read!(@source_path)

    refute source =~ "~> 0.3"
    assert source =~ "@cairnloop_version Mix.Project.config()[:version]"
    assert source =~ "Igniter.Project.Deps.add_dep({:cairnloop, \"~> "
    assert source =~ "@cairnloop_version}"
  end

  test "installer notice includes required repo config and dependency migrations" do
    source = File.read!(@source_path)

    assert source =~ "config :cairnloop, :repo, MyApp.Repo"
    assert source =~ ~s(config :cairnloop, :schema_prefix, "cairnloop")
    assert source =~ ~s(config :cairnloop, :schema_prefix, "public")
    assert source =~ "legacy `nil`"

    assert source =~
             "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations"

    refute source =~
             "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop"

    refute source =~ "omit `--prefix cairnloop`"
    assert source =~ "Do not use `mix ecto.migrate --prefix cairnloop` as a shortcut"
    assert source =~ "mix cairnloop.doctor"
  end

  test "installer-generated migration is schema-prefix aware" do
    source = File.read!(@source_path)

    assert source =~ "prefix = Cairnloop.SchemaPrefix.configured()"
    assert source =~ "CREATE SCHEMA IF NOT EXISTS"
    assert source =~ "create table(:cairnloop_conversations, prefix: prefix)"
    assert source =~ "create table(:cairnloop_messages, prefix: prefix)"
    assert source =~ "references(:cairnloop_conversations, prefix: prefix"
    assert source =~ "create index(:cairnloop_messages, [:conversation_id], prefix: prefix)"
  end

  test "installer-generated conversation migration includes nullable customer_ref" do
    source = File.read!(@source_path)

    assert source =~ ~r/add\s+:host_user_id,\s+:string/
    assert_nullable_customer_ref(source)
  end

  test "test host and example migrations include nullable customer_ref" do
    for path <- [@test_host_migration_path, @example_migration_path] do
      source = File.read!(path)

      assert source =~ ~r/add\(?\s*:host_user_id,\s+:string/
      assert_nullable_customer_ref(source)
    end
  end

  test "installer notice includes additive existing-install customer_ref upgrade guidance" do
    source = File.read!(@source_path)

    assert source =~ "Existing installs should add a nullable `customer_ref` column"
    assert source =~ "before enabling the Phase 58 widget verifier path"
  end

  defp assert_nullable_customer_ref(source) do
    assert source =~ ~r/add\(?\s*:customer_ref,\s+:string/
    refute source =~ ~r/add\(?\s*:customer_ref,\s+:string,\s+null:\s+false/
  end
end
