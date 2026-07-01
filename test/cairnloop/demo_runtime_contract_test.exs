defmodule Cairnloop.DemoRuntimeContractTest do
  @moduledoc """
  DB-free source contract for the Phase 53 demo runtime promises.

  The test reads source and docs only. It never starts Docker, Phoenix, Repo,
  browser tooling, or `./bin/demo smoke`.
  """

  use ExUnit.Case, async: true

  @root_mix_path "mix.exs"
  @example_mix_path "examples/cairnloop_example/mix.exs"
  @config_path "examples/cairnloop_example/config/config.exs"
  @dev_config_path "examples/cairnloop_example/config/dev.exs"
  @test_config_path "examples/cairnloop_example/config/test.exs"
  @runtime_config_path "examples/cairnloop_example/config/runtime.exs"
  @notifier_path "examples/cairnloop_example/lib/cairnloop_example/demo_notifier.ex"
  @router_path "examples/cairnloop_example/lib/cairnloop_example_web/router.ex"
  @compose_path "examples/cairnloop_example/compose.demo.yml"
  @dockerfile_path "examples/cairnloop_example/Dockerfile.demo"
  @seed_path "examples/cairnloop_example/priv/repo/seeds.exs"
  @seed_test_path "examples/cairnloop_example/test/cairnloop_example/seeds_test.exs"
  @readme_path "README.md"
  @quickstart_path "guides/01-quickstart.md"
  @troubleshooting_path "guides/04-troubleshooting.md"
  @example_readme_path "examples/cairnloop_example/README.md"

  test "example setup keeps host-before-library migrations and setup-owned seeds" do
    source = read!(@example_mix_path)

    assert_contains(source, ~s({:cairnloop, path: "../.."}))
    assert_contains(source, "deps/cairnloop/priv/repo/migrations")
    assert_contains(source, "../../priv/repo/migrations")
    assert_contains(source, ~S[reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end])

    setup_block = alias_block!(source, ~s("ecto.setup"))
    assert_order(setup_block, ~s("ecto.migrate"), "reenable_migrate", "ecto.setup")
    assert_order(setup_block, "reenable_migrate", "ecto.migrate --migrations-path", "ecto.setup")
    assert_contains(setup_block, ~s("run priv/repo/seeds.exs"))

    for {alias_name, label} <- [{":test", "test"}, {~s("test.e2e"), "test.e2e"}] do
      block = alias_block!(source, alias_name)
      assert_order(block, ~s("ecto.migrate --quiet"), "reenable_migrate", label)
      assert_order(block, "reenable_migrate", "ecto.migrate --migrations-path", label)
    end
  end

  test "runtime config stays quiet, bounded, and demo-only" do
    config = read!(@config_path)
    notifier = read!(@notifier_path)
    dev = read!(@dev_config_path)
    test_config = read!(@test_config_path)
    runtime = read!(@runtime_config_path)

    assert_contains(config, "config :cairnloop, :notifier, CairnloopExample.DemoNotifier")

    for expected <- [
          "@behaviour Cairnloop.Notifier",
          "def on_conversation_resolved(_conversation, _metadata), do: :ok",
          "def on_sla_breach(_conversation, _sla, _metadata), do: :ok",
          "def on_outbound_triggered(_message, _conversation), do: :ok"
        ] do
      assert_contains(notifier, expected)
    end

    refute notifier =~ "Logger"
    refute notifier =~ ~r/\bdeliver\s*\(/
    refute notifier =~ "Cairnloop.Notifier.Chimeway"

    for source <- [dev, runtime] do
      assert_contains(source, ~S[System.get_env("PHX_BIND") || "127.0.0.1"])
      assert_contains(source, ~s("0.0.0.0" -> {0, 0, 0, 0}))
      assert_contains(source, ~s("127.0.0.1" -> {127, 0, 0, 1}))
      assert_contains(source, "Unsupported PHX_BIND=")
    end

    assert_contains(dev, "config :chimeway, Chimeway.Repo")
    assert_contains(test_config, "config :chimeway, Chimeway.Repo")
    assert_contains(test_config, ~S[System.get_env("PHX_TEST_PORT") || "4002"])

    assert_order(
      runtime,
      "if config_env() != :test do",
      "if config_env() == :prod do",
      @runtime_config_path
    )

    assert_order(runtime, "if config_env() == :prod do", "DATABASE_URL", @runtime_config_path)
  end

  test "health and Docker readiness remain infrastructure friendly" do
    router = read!(@router_path)
    compose = read!(@compose_path)
    dockerfile = read!(@dockerfile_path)

    operations_scope = operations_scope!(router)
    assert_contains(operations_scope, "Cairnloop.Router.cairnloop_operations()")
    refute operations_scope =~ "pipe_through :browser"

    db_block = db_service_block(compose)
    assert_contains(db_block, "image: pgvector/pgvector:pg16")
    assert_contains(db_block, "pg_isready -U postgres -d cairnloop_example_dev")
    refute db_block =~ ~r/^\s+ports:/m

    for expected <- [
          "condition: service_healthy",
          "PGHOST: db",
          ~s(PGPORT: "5432"),
          "PHX_BIND: 0.0.0.0",
          ~s(host_ip: "${CAIRNLOOP_BIND_HOST:-127.0.0.1}"),
          ~s(published: "${CAIRNLOOP_WEB_PORT:-4100-4199}"),
          "curl -fsS http://127.0.0.1:4000/health"
        ] do
      assert_contains(compose, expected)
    end

    for expected <- [
          "curl",
          "postgresql-client",
          "EXPOSE 4000",
          ~s(CMD ["sh", "-lc", "mix setup && exec mix phx.server"])
        ] do
      assert_contains(dockerfile, expected)
    end
  end

  test "docs preserve dependency split, migration order, and printed URL boundary" do
    version = project_version()
    readme = read!(@readme_path)
    quickstart = read!(@quickstart_path)
    troubleshooting = read!(@troubleshooting_path)
    example_readme = read!(@example_readme_path)

    for source <- [readme, quickstart] do
      assert_contains(source, ~s({:cairnloop, "~> #{version}"}))
    end

    assert_contains(readme, ~s({:cairnloop, path: "../.."}))
    assert_contains(readme, "Adopter apps should use the Hex dependency form above.")
    assert_contains(quickstart, "Run host migrations")
    assert_contains(quickstart, "Run the Cairnloop library's own migrations")

    for source <- [quickstart, troubleshooting] do
      assert_contains(source, ~S[Mix.Task.reenable("ecto.migrate")])
      refute source =~ "--migrations-path priv/repo/migrations --migrations-path deps/cairnloop"
    end

    for source <- [readme, quickstart, example_readme] do
      assert_contains(source, "Trailmark")
    end

    assert_contains(
      example_readme,
      "With Docker, start at the demo index URL printed by `./bin/demo`."
    )

    assert_localhost_only_manual(example_readme, @example_readme_path)
  end

  test "Trailmark seed data remains setup-owned and DB-backed coverage exists" do
    mix_source = read!(@example_mix_path)
    seeds = read!(@seed_path)
    seed_test = read!(@seed_test_path)

    assert_contains(alias_block!(mix_source, ~s("ecto.setup")), ~s("run priv/repo/seeds.exs"))

    for expected <- [
          "KnowledgeBase.save_draft",
          "KnowledgeBase.publish_revision",
          "KnowledgeAutomation.ensure_review_task_for_suggestion",
          "Governance.propose",
          "MCP.issue_token",
          "Oban.drain_queue(queue: :default, with_recursion: true)"
        ] do
      assert_contains(seeds, expected)
    end

    for expected <- [
          "use CairnloopExample.DataCase, async: false",
          "@moduletag :requires_postgres",
          ~S[Path.expand("../../priv/repo/seeds.exs", __DIR__)],
          "Code.eval_file(seed_path)",
          "running the seed twice produces stable row counts"
        ] do
      assert_contains(seed_test, expected)
    end
  end

  defp read!(path), do: File.read!(path)

  defp project_version do
    @root_mix_path
    |> read!()
    |> then(fn source ->
      case Regex.run(~r/version:\s+"([^"]+)"/, source, capture: :all_but_first) do
        [version] -> version
        nil -> flunk("Could not find project version in #{@root_mix_path}")
      end
    end)
  end

  defp alias_block!(source, alias_name) do
    pattern =
      case alias_name do
        ":test" ->
          ~r/\n\s+test:\s+\[(?<block>.*?)\n\s+\]/s

        quoted ->
          Regex.compile!("" <> Regex.escape(quoted) <> ~S|:\s+\[(?<block>.*?)\n\s+\]|, "s")
      end

    case Regex.run(pattern, source, capture: ["block"]) do
      [block] -> block
      nil -> flunk("Could not find alias block #{alias_name}")
    end
  end

  defp operations_scope!(router) do
    case Regex.run(
           ~r/# Operations endpoints.*?(scope "\/" do\s+(?<block>.*?)\n\s+end)/s,
           router,
           capture: ["block"]
         ) do
      [block] -> block
      nil -> flunk("Could not find the operations route scope")
    end
  end

  defp db_service_block(compose) do
    case Regex.run(~r/\n  db:\n(?<block>.*?)(?=\n  web:\n)/s, compose, capture: ["block"]) do
      [block] -> block
      nil -> flunk("Expected #{@compose_path} to contain a db service before web")
    end
  end

  defp assert_contains(source, expected) do
    assert source =~ expected, "Expected source to include #{inspect(expected)}"
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

  defp assert_localhost_only_manual(source, label) do
    lines = String.split(source, "\n")

    violations =
      lines
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _line_no} -> String.contains?(line, "localhost:4000") end)
      |> Enum.reject(fn {_line, line_no} -> manual_local_context?(lines, line_no) end)

    assert violations == [],
           """
           Expected every localhost:4000 mention in #{label} to be scoped to manual local Phoenix.

           Violations:
           #{Enum.map_join(violations, "\n", fn {line, line_no} -> "  #{line_no}: #{line}" end)}
           """
  end

  defp manual_local_context?(lines, line_no) do
    start = max(line_no - 10, 1)
    stop = min(line_no + 2, length(lines))

    context =
      lines
      |> Enum.slice((start - 1)..(stop - 1))
      |> Enum.join("\n")

    context =~ "manual local" or context =~ "mix setup && mix phx.server" or
      context =~ "mix phx.server" or context =~ "Manual boot"
  end
end
