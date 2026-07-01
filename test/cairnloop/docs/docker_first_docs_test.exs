defmodule Cairnloop.Docs.DockerFirstDocsTest do
  @moduledoc """
  DB-free source scan for the Docker-first adopter docs.

  The test reads documentation and wrapper source only. It never starts Docker, Phoenix, Repo,
  browser tooling, or `./bin/demo smoke`.
  """

  use ExUnit.Case, async: true

  @readme_path "README.md"
  @quickstart_path "guides/01-quickstart.md"
  @troubleshooting_path "guides/04-troubleshooting.md"
  @example_readme_path "examples/cairnloop_example/README.md"
  @wrapper_path "bin/demo"

  @wrapper_commands ~w(
    ./bin/demo
    start
    up
    urls
    logs
    status
    ps
    stop
    down
    reset
    smoke
    help
  )

  @smoke_routes ~w(
    /
    /support
    /support/inbox
    /chat
    /support/knowledge-base
    /support/knowledge-base/gaps
    /support/knowledge-base/suggestions
    /support/audit-log
    /support/settings
  )

  test "README and Quickstart lead with Docker demo" do
    readme = File.read!(@readme_path)
    quickstart = File.read!(@quickstart_path)
    help = help_output()

    assert_order(readme, "### Try the live demo first", "### Install in your app", @readme_path)
    assert_order(quickstart, "## Fastest path: Docker demo", "## Prerequisites", @quickstart_path)

    for source <- [readme, quickstart] do
      assert_contains(source, "./bin/demo")
      assert_contains(source, "printed")
      assert_contains(source, "private pgvector Postgres")
      refute source =~ "~> 0.1.0", "Expected touched docs to avoid stale ~> 0.1.0 dependency text"
    end

    for command <- @wrapper_commands do
      assert_contains(help, command)
    end

    for command <- @wrapper_commands -- ["./bin/demo"] do
      assert_contains(quickstart, command)
    end

    assert_localhost_only_manual(quickstart, @quickstart_path)
  end

  test "example README keeps Docker URLs dynamic" do
    example = File.read!(@example_readme_path)

    assert_contains(example, "./bin/demo")
    assert_contains(example, "printed base URL")
    assert_contains(example, "dynamic port range")

    for route <- ["/support", "/chat"] do
      assert_contains(example, "printed base URL plus `#{route}`")
    end

    assert_localhost_only_manual(example, @example_readme_path)

    for forbidden <- [
          "**Operator inbox:** http://localhost:4000/support",
          "**Customer chat:** http://localhost:4000/chat",
          "Visit [`localhost:4000/support`",
          "Visit [`localhost:4000/chat`"
        ] do
      refute example =~ forbidden,
             "Expected Docker-facing example README copy not to hard-code #{inspect(forbidden)}"
    end
  end

  test "troubleshooting covers Docker demo failure taxonomy" do
    troubleshooting = File.read!(@troubleshooting_path)

    assert_order(
      troubleshooting,
      "## Docker Demo",
      "## `mix cairnloop.install` Prerequisites",
      @troubleshooting_path
    )

    for expected <- [
          "Docker is not installed or not on PATH",
          "Docker Compose v2",
          "No available localhost port",
          "CAIRNLOOP_WEB_PORT",
          "never becomes healthy",
          "./bin/demo logs",
          "./bin/demo status",
          "./bin/demo reset",
          "failing route URL",
          "/health",
          "reset",
          "reseed",
          "pgvector/pgvector:pg16",
          "manual local Postgres 16 plus pgvector",
          "OPENAI_API_KEY",
          "first-run boot",
          "route smoke",
          "seeded click-through"
        ] do
      assert_contains(troubleshooting, expected)
    end

    assert_order(
      troubleshooting,
      "./bin/demo logs",
      "docker compose up -d db",
      @troubleshooting_path
    )

    refute troubleshooting =~ "docker compose logs",
           "Expected troubleshooting to point users to bounded wrapper logs, not raw Compose logs"
  end

  test "OpenAI and smoke docs stay credential-free and scoped" do
    readme = File.read!(@readme_path)
    quickstart = File.read!(@quickstart_path)
    troubleshooting = File.read!(@troubleshooting_path)
    example = File.read!(@example_readme_path)
    wrapper = File.read!(@wrapper_path)
    help = help_output()

    assert_contains(help, "OPENAI_API_KEY=<key>")
    assert_contains(help, "Optional semantic embeddings in seeded data")

    for expected <- ["first-run boot", "route smoke", "seeded click-through"] do
      assert_contains(troubleshooting, expected)
    end

    assert_contains(troubleshooting, "Provider configuration can still matter")
    assert_contains(troubleshooting, "production host-app AI")

    for source <- [readme, quickstart, troubleshooting, example] do
      assert_contains(source, "./bin/demo smoke")
    end

    for route <- @smoke_routes do
      assert_contains(wrapper, ~s(smoke_route "$url" "#{route}"))
      assert_contains(troubleshooting, route)
      assert_contains(example, route)
    end

    assert_contains(troubleshooting, "not a browser E2E suite")
    assert_contains(troubleshooting, "does not replace the CI workflow")
  end

  defp help_output do
    {output, exit} = System.cmd("bash", [@wrapper_path, "help"], stderr_to_stdout: true)
    assert exit == 0, "Expected ./bin/demo help to exit 0:\n#{output}"
    output
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
