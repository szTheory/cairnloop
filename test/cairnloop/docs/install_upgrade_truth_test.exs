defmodule Cairnloop.Docs.InstallUpgradeTruthTest do
  @moduledoc """
  DB-free source scan for installer, install-docs, and upgrade-docs truth.

  The test reads Markdown and installer source only. It never boots Repo, Docker, Phoenix,
  browser tooling, or external network clients.
  """

  use ExUnit.Case, async: true

  @readme_path "README.md"
  @quickstart_path "guides/01-quickstart.md"
  @host_integration_path "guides/03-host-integration.md"
  @troubleshooting_path "guides/04-troubleshooting.md"
  @upgrading_path "UPGRADING.md"
  @example_readme_path "examples/cairnloop_example/README.md"
  @installer_path "lib/mix/tasks/cairnloop/install.ex"
  @mix_path "mix.exs"

  @public_doc_paths [
    @readme_path,
    @quickstart_path,
    @host_integration_path,
    @troubleshooting_path,
    @upgrading_path,
    @example_readme_path
  ]

  @forbidden_dependency_migration_prefix "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop"
  @dependency_migration "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations"

  test "README and Quickstart keep Docker evaluation before host-app install" do
    readme = read!(@readme_path)
    quickstart = read!(@quickstart_path)

    assert_order(readme, "### Try the live demo first", "### Install in your app", @readme_path)
    assert_order(quickstart, "## Fastest path: Docker demo", "## Install", @quickstart_path)

    for {path, source} <- [{@readme_path, readme}, {@quickstart_path, quickstart}] do
      assert_contains(source, "./bin/demo", path)
      assert_contains(source, "printed", path)
      assert_contains(source, "Trailmark", path)
      assert_contains(source, "./bin/demo smoke", path)
    end
  end

  test "public dependency snippets match the project version" do
    version = project_version()

    for path <- [@readme_path, @quickstart_path] do
      source = read!(path)

      assert_contains(source, ~s({:cairnloop, "~> #{version}"}), path)

      for stale <- ["~> 0.1.0", "~> 0.2.0", "~> 0.3.0", "~> 0.4.0"] do
        refute source =~ ~s({:cairnloop, "#{stale}"}),
               "Expected #{path} not to contain stale dependency snippet #{stale}"
      end
    end
  end

  test "fresh install docs use Igniter package installer and direct task only as rerun path" do
    for {path, source} <- [
          {@readme_path, read!(@readme_path)},
          {@quickstart_path, read!(@quickstart_path)}
        ] do
      assert_contains(source, "mix igniter.install cairnloop", path)
      assert_contains(source, "mix cairnloop.install", path)
      assert_order(source, "mix igniter.install cairnloop", "mix cairnloop.install", path)
      assert source =~ ~r/already in `mix\.exs`.*mix cairnloop\.install/s
    end

    troubleshooting = read!(@troubleshooting_path)

    assert_contains(troubleshooting, "mix igniter.install cairnloop", @troubleshooting_path)
    assert_contains(troubleshooting, "already in `mix.exs`", @troubleshooting_path)
    assert_contains(troubleshooting, "first-time setup", @troubleshooting_path)
  end

  test "installer notice remains the host-app install source of truth" do
    installer = read!(@installer_path)
    version = project_version()

    assert_contains(
      installer,
      "@cairnloop_version Mix.Project.config()[:version]",
      @installer_path
    )

    assert_contains(installer, "Igniter.Project.Deps.add_dep({:cairnloop, \"~> ", @installer_path)
    assert_contains(installer, "@cairnloop_version}", @installer_path)
    refute installer =~ ~s({:cairnloop, "~> #{version}"})

    for expected <- [
          "config :cairnloop, :repo, MyApp.Repo",
          ~s(config :cairnloop, :schema_prefix, "cairnloop"),
          ~s(config :cairnloop, :schema_prefix, "public"),
          "Existing installs should add a nullable `customer_ref` column",
          "mix cairnloop.doctor",
          @dependency_migration,
          "Do not use `mix ecto.migrate --prefix cairnloop` as a shortcut"
        ] do
      assert_contains(installer, expected, @installer_path)
    end

    refute installer =~ @forbidden_dependency_migration_prefix
  end

  test "public install docs mirror dedicated schema default and explicit public compatibility" do
    combined = public_docs()

    assert_contains(combined, ~s(config :cairnloop, :schema_prefix, "cairnloop"), "public docs")
    assert_contains(combined, ~s(config :cairnloop, :schema_prefix, "public"), "public docs")
    assert_contains(combined, "Existing public-schema", "public docs")
    assert_contains(combined, "host", "public docs")
    assert_contains(combined, "Oban", "public docs")
    assert_contains(combined, "mix cairnloop.doctor", "public docs")

    stale_nil_lines =
      @public_doc_paths
      |> Enum.flat_map(fn path ->
        path
        |> read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _line_no} -> stale_nil_recommendation_line?(line) end)
        |> Enum.reject(fn {line, _line_no} -> legacy_nil_compatibility_line?(line) end)
        |> Enum.map(fn {line, line_no} -> "#{path}:#{line_no}: #{line}" end)
      end)

    assert stale_nil_lines == [],
           """
           Public docs must not recommend `schema_prefix: nil`.
           Use explicit `schema_prefix: "public"` for existing public-schema compatibility;
           mention nil only as legacy accepted compatibility.

           Violations:
           #{Enum.join(stale_nil_lines, "\n")}
           """
  end

  test "public docs do not teach the dependency migration prefix shortcut" do
    violations =
      for path <- @public_doc_paths,
          String.contains?(read!(path), @forbidden_dependency_migration_prefix),
          do: path

    assert violations == [],
           """
           Public docs must not instruct adopters to run:
             #{@forbidden_dependency_migration_prefix}

           Run host migrations first, then dependency migrations without `--prefix cairnloop`.
           Violations: #{Enum.join(violations, ", ")}
           """
  end

  test "host integration, troubleshooting, and example docs carry host-owned prefix boundaries" do
    host_integration = read!(@host_integration_path)
    troubleshooting = read!(@troubleshooting_path)
    example = read!(@example_readme_path)

    for {path, source} <- [
          {@host_integration_path, host_integration},
          {@troubleshooting_path, troubleshooting},
          {@example_readme_path, example}
        ] do
      assert_contains(source, ~s(config :cairnloop, :schema_prefix, "cairnloop"), path)
      assert_contains(source, ~s(config :cairnloop, :schema_prefix, "public"), path)
    end

    for expected <- [
          "route auth and authorization",
          "repo config",
          "operator identity injection",
          "Oban",
          "secrets",
          "monitoring",
          "deployment"
        ] do
      assert_contains(host_integration, expected, @host_integration_path)
    end

    assert_contains(
      example,
      ~s(dogfoods `schema_prefix: "cairnloop"`),
      @example_readme_path
    )

    assert_contains(
      example,
      ~s(`schema_prefix: "public"` as an intentional existing-install compatibility switch),
      @example_readme_path
    )
  end

  test "public docs state when Cairnloop is the wrong fit" do
    readme = read!(@readme_path)
    quickstart = read!(@quickstart_path)

    for {path, source} <- [{@readme_path, readme}, {@quickstart_path, quickstart}] do
      assert_contains(source, "When not to use Cairnloop", path)
      assert_contains(source, "not a hosted helpdesk", path)
      assert_contains(source, "not a replacement for host auth", path)
      assert_contains(source, "not autonomous customer-visible support", path)
      assert_contains(source, "not a tenant-isolation layer", path)
      assert_contains(source, "not a managed outbound campaign system", path)
    end
  end

  test "UPGRADING keeps prefix migration, rollback, and shared-extension guidance concrete" do
    upgrading = read!(@upgrading_path)

    for expected <- [
          ~s(config :cairnloop, :schema_prefix, "cairnloop"),
          ~s(config :cairnloop, :schema_prefix, "public"),
          "Back up the database",
          "maintenance window",
          "Verify row counts, indexes, constraints, and foreign keys",
          "rollback",
          "must not drop shared database extensions",
          "vector"
        ] do
      assert_contains(upgrading, expected, @upgrading_path)
    end

    assert_contains(upgrading, "Oban remains", @upgrading_path)
    assert_contains(upgrading, "host-owned", @upgrading_path)
  end

  test "UPGRADING states compatibility matrix and manual data-move boundaries" do
    upgrading = read!(@upgrading_path)
    version = project_version()

    for expected <- [
          "## Compatibility Matrix",
          "Elixir",
          "OTP",
          "Phoenix",
          "Ecto",
          "Postgres",
          "pgvector",
          "Oban",
          "Cairnloop package",
          ~s({:cairnloop, "~> #{version}"}),
          "maintenance window",
          "row counts",
          "indexes",
          "constraints",
          "foreign keys",
          "functions",
          "triggers",
          "rollback posture",
          "shared `vector` infrastructure is not dropped"
        ] do
      assert_contains(upgrading, expected, @upgrading_path)
    end

    refute upgrading =~ "automated public-to-dedicated data migration"
    refute upgrading =~ "automatically migrates"
    refute upgrading =~ "Cairnloop moves existing public tables"
  end

  defp public_docs do
    @public_doc_paths
    |> Enum.map(&read!/1)
    |> Enum.join("\n\n")
  end

  defp read!(path), do: File.read!(path)

  defp project_version do
    @mix_path
    |> read!()
    |> then(fn source ->
      case Regex.run(~r/version:\s+"([^"]+)"/, source, capture: :all_but_first) do
        [version] -> version
        nil -> flunk("Could not find project version in #{@mix_path}")
      end
    end)
  end

  defp legacy_nil_compatibility_line?(line) do
    line =~ "legacy" and line =~ "nil" and not String.contains?(line, "pin")
  end

  defp stale_nil_recommendation_line?(line) do
    line =~ "schema_prefix: nil" or line =~ "schema_prefix, nil" or
      line =~ "`schema_prefix` to `nil`" or line =~ "`schema_prefix` to nil"
  end

  defp assert_contains(source, expected, label) do
    assert source =~ expected, "Expected #{label} to include #{inspect(expected)}"
  end

  defp assert_order(source, first, second, label) do
    first_position = position!(source, first, label)
    second_position = position!(source, second, label)

    assert first_position < second_position,
           "Expected #{inspect(first)} to appear before #{inspect(second)} in #{label}"
  end

  defp position!(source, needle, label) do
    case :binary.match(source, needle) do
      {position, _length} -> position
      :nomatch -> flunk("Expected #{label} to include #{inspect(needle)}")
    end
  end
end
