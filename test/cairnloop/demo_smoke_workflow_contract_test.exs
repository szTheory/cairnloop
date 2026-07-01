defmodule Cairnloop.DemoSmokeWorkflowContractTest do
  @moduledoc """
  DB-free source contract for the Docker demo smoke workflow.

  The test reads workflow source only. It never starts Docker, Phoenix, Repo,
  browser tooling, or `./bin/demo smoke`.
  """

  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/demo-smoke.yml"

  @path_filters [
    ".dockerignore",
    "bin/demo",
    "examples/cairnloop_example/**",
    ".github/workflows/demo-smoke.yml",
    "README.md",
    "CONTRIBUTING.md",
    "guides/**",
    "mix.exs",
    "mix.lock",
    "config/**"
  ]

  test "workflow triggers on every demo-relevant event and path" do
    source = workflow_source()

    for expected <- [
          "\n  workflow_dispatch:",
          "\n  schedule:",
          ~s(cron: "23 10 * * 1"),
          "\n  push:",
          "\n  pull_request:"
        ] do
      assert_contains(source, expected)
    end

    assert_path_filters(event_block!(source, "push"), "push")
    assert_path_filters(event_block!(source, "pull_request"), "pull_request")

    refute source =~ ".planning/**",
           "Expected demo smoke path filters not to include planning-only artifacts"

    refute source =~ "lib/**",
           "Expected broad library changes to be covered by normal CI/E2E, not Docker smoke"

    refute source =~ "priv/**",
           "Expected broad static/library asset changes to be covered by normal CI/E2E, not Docker smoke"
  end

  test "workflow job stays read-only and delegates smoke behavior to bin/demo" do
    source = workflow_source()

    for expected <- [
          "permissions:\n  contents: read",
          ~s(FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"),
          "jobs:\n  demo-smoke:",
          "name: demo-smoke",
          "runs-on: ubuntu-latest",
          "timeout-minutes: 25",
          "uses: actions/checkout@v7",
          "persist-credentials: false",
          "name: Docker versions",
          "docker version",
          "docker compose version",
          "## Demo smoke",
          "Docker version:",
          "Docker Compose version:",
          "event: ${{ github.event_name }}",
          "ref: ${{ github.ref }}",
          "name: Run Docker demo smoke",
          "./bin/demo smoke",
          "demo smoke duration seconds"
        ] do
      assert_contains(source, expected)
    end
  end

  test "workflow cannot mutate release state or duplicate smoke internals" do
    source = workflow_source()

    for forbidden <- [
          "pull_request_target",
          "contents: write",
          "secrets.",
          "HEX_API_KEY",
          "RELEASE_PLEASE",
          "release-please",
          "hex.publish"
        ] do
      refute source =~ forbidden,
             "Expected demo smoke workflow not to include #{inspect(forbidden)}"
    end

    refute source =~ ~r/\bdocker compose up\b/,
           "Expected workflow YAML not to duplicate wrapper-owned Compose smoke logic"

    refute source =~ ~r/\bcurl\b/,
           "Expected workflow YAML not to duplicate wrapper-owned route smoke logic"
  end

  defp workflow_source, do: File.read!(@workflow_path)

  defp assert_contains(source, expected) do
    assert source =~ expected, "Expected workflow source to include #{inspect(expected)}"
  end

  defp assert_path_filters(event_block, event) do
    assert path_filters(event_block) == @path_filters,
           """
           Expected #{event}.paths to match the locked demo-smoke filter list.

           Expected:
           #{Enum.map_join(@path_filters, "\n", &"  - #{&1}")}

           Actual:
           #{Enum.map_join(path_filters(event_block), "\n", &"  - #{&1}")}
           """
  end

  defp event_block!(source, event) do
    needle = "\n  #{event}:\n"
    start = position!(source, needle, @workflow_path) + byte_size(needle)
    rest = binary_part(source, start, byte_size(source) - start)

    case Regex.run(~r/\n(?:  [a-z_]+:|\S)/, rest, return: :index) do
      [{stop, _length}] -> binary_part(rest, 0, stop)
      nil -> rest
    end
  end

  defp path_filters(event_block) do
    event_block
    |> String.split("\n")
    |> Enum.drop_while(&(String.trim(&1) != "paths:"))
    |> Enum.drop(1)
    |> Enum.take_while(&String.starts_with?(&1, "      - "))
    |> Enum.map(fn line ->
      line
      |> String.trim()
      |> String.replace_prefix("- ", "")
      |> unquote_path()
    end)
  end

  defp unquote_path(<<quote, rest::binary>>) when quote in [?\", ?'] do
    suffix = <<quote>>

    if String.ends_with?(rest, suffix) do
      String.trim_trailing(rest, suffix)
    else
      <<quote, rest::binary>>
    end
  end

  defp unquote_path(path), do: path

  defp position!(source, needle, label) do
    case :binary.match(source, needle) do
      {position, _length} -> position
      :nomatch -> flunk("Expected #{label} to include #{inspect(needle)}")
    end
  end
end
