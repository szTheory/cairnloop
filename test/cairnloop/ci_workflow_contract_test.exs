defmodule Cairnloop.CIWorkflowContractTest do
  @moduledoc """
  DB-free source contract for the main CI workflow.

  The test reads workflow source only. It never starts Docker, Phoenix, Repo,
  browser tooling, or GitHub Actions.
  """

  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"

  test "workflow triggers and top-level permissions stay least privilege" do
    source = workflow_source()

    for expected <- [
          "on:\n  push:",
          "branches:\n      - main\n      - master",
          "\n  pull_request:",
          "\n  workflow_dispatch:",
          "permissions:\n  contents: read",
          "concurrency:",
          "group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}",
          "cancel-in-progress: ${{ github.event_name == 'pull_request' }}"
        ] do
      assert_contains(source, expected)
    end

    refute source =~ "pull_request_target",
           "Expected CI not to run untrusted PR code with trusted-workflow semantics"
  end

  test "workflow uses current Node 24 posture and non-persisted checkout credentials" do
    source = workflow_source()

    for expected <- [
          ~s(FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"),
          ~s(ELIXIR_VERSION: "1.19.5"),
          ~s(OTP_VERSION: "27.2"),
          ~s(MIX_CACHE_VERSION: "v1"),
          "uses: actions/checkout@v7",
          "uses: actions/cache@v6",
          "uses: actions/setup-node@v6",
          "uses: actions/upload-artifact@v7",
          "uses: erlef/setup-beam@v1"
        ] do
      assert_contains(source, expected)
    end

    refute source =~ "ACTIONS_RUNNER_NODE_VERSION",
           "Expected CI to avoid the stale Node transition variable"

    refute source =~ "ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION",
           "Expected CI not to opt out of Node 24"

    checkout_count = ~r/uses: actions\/checkout@v7/ |> Regex.scan(source) |> length()
    credential_opt_out_count = ~r/persist-credentials: false/ |> Regex.scan(source) |> length()

    assert checkout_count == 5,
           "Expected changes, fast, quality, integration, and e2e to use checkout@v7"

    assert credential_opt_out_count == checkout_count,
           "Expected every CI checkout to set persist-credentials: false"
  end

  test "workflow preserves fast quality integration e2e and release gate topology" do
    source = workflow_source()

    for job <- ["changes", "fast", "quality", "integration", "e2e", "release_gate"] do
      assert_contains(source, "\n  #{job}:")
      assert_contains(job_block!(source, job), "name: #{job}")
    end

    for expected <- [
          "mix ci.fast",
          "mix ci.quality",
          "mix ci.integration",
          "mix test --only e2e",
          "needs: [changes, fast, integration, quality, e2e]",
          "if: ${{ always() }}",
          ~s(needs.fast.result),
          ~s(needs.integration.result),
          ~s(needs.quality.result),
          ~s(needs.e2e.result),
          ~s(e2e_required="${{ needs.changes.outputs.e2e_required }}"),
          ~s(e2e_result="${{ needs.e2e.result }}"),
          ~s([ "$e2e_result" = "success" ]),
          ~s([ "$e2e_required" = "false" ] && [ "$e2e_result" = "skipped" ])
        ] do
      assert_contains(source, expected)
    end

    refute source =~ "phase-12-shift-left",
           "Expected the current CI topology to use the fast lane name"

    refute source =~ "./bin/demo smoke",
           "Expected Docker demo smoke to stay out of the default CI workflow"
  end

  test "workflow path-gates PR E2E from fetched base sha to checked out head" do
    source = workflow_source()
    changes_job = job_block!(source, "changes")
    e2e_job = job_block!(source, "e2e")

    for expected <- [
          "outputs:",
          "e2e_required: ${{ steps.e2e-required.outputs.e2e_required }}",
          "id: e2e-required",
          ~s(if [ "${{ github.event_name }}" != "pull_request" ]; then),
          ~s(echo "e2e_required=true" >> "$GITHUB_OUTPUT"),
          ~s(BASE_SHA="${{ github.event.pull_request.base.sha }}"),
          ~s(git fetch --no-tags --depth=1 origin "$BASE_SHA"),
          ~s(git diff --name-only "$BASE_SHA"...HEAD > changed-files.txt),
          "examples/cairnloop_example/*",
          "lib/cairnloop/web/*",
          "priv/static/*",
          "test/cairnloop/web/*",
          "examples/cairnloop_example/test/*",
          ".github/workflows/ci.yml",
          "mix.exs",
          "mix.lock",
          "config/*",
          "examples/cairnloop_example/mix.exs",
          "examples/cairnloop_example/mix.lock",
          "examples/cairnloop_example/assets/package.json",
          "examples/cairnloop_example/assets/package-lock.json"
        ] do
      assert_contains(changes_job, expected)
    end

    assert_contains(e2e_job, "needs: [changes]")
    assert_contains(e2e_job, "if: ${{ needs.changes.outputs.e2e_required == 'true' }}")
  end

  test "workflow exposes bounded timing cache and artifact evidence" do
    source = workflow_source()

    for expected <- [
          "Restore Mix deps cache",
          "Restore Mix build cache",
          "Versions and cache summary",
          "Compile timing profile",
          "MIX_ENV=test mix compile --force --profile time --warnings-as-errors",
          "compile duration seconds",
          "Run fast CI lane",
          "fast lane duration seconds",
          "Slowest headless tests",
          "mix test --exclude integration --slowest 20 --warnings-as-errors",
          "Run quality CI lane",
          "quality lane duration seconds",
          "Run integration suite",
          "integration lane duration seconds",
          "deps cache hit: ${{ steps.mix-deps-cache.outputs.cache-hit }}",
          "build cache hit: ${{ steps.mix-build-cache.outputs.cache-hit }}",
          "example deps cache hit: ${{ steps.example-mix-deps-cache.outputs.cache-hit }}",
          "example build cache hit: ${{ steps.example-mix-build-cache.outputs.cache-hit }}",
          "Playwright cache hit: ${{ steps.playwright-cache.outputs.cache-hit }}",
          ~s(PW_TRACE: "true"),
          ~s(PW_SCREENSHOT: "true"),
          "Upload Playwright traces on failure",
          "if: failure()",
          "if-no-files-found: warn",
          "retention-days: 3"
        ] do
      assert_contains(source, expected)
    end

    refute source =~ "if-no-files-found: ignore",
           "Expected CI artifact uploads not to silently ignore empty trace output"
  end

  test "workflow records split E2E phase timings instead of one opaque e2e alias" do
    source = workflow_source()
    e2e_job = job_block!(source, "e2e")

    for expected <- [
          "mix deps.get --check-locked",
          "Elixir deps seconds",
          "npm --prefix assets ci",
          "npm deps seconds",
          "npx --prefix assets playwright install --with-deps chromium",
          "Playwright Chromium install seconds",
          "Setup, migrate, and build assets",
          "mix assets.setup",
          "mix assets.build",
          "mix ecto.create --quiet",
          "mix ecto.migrate --quiet",
          ~s(mix ecto.migrate --migrations-path "$CAIRNLOOP_MIGRATIONS" --quiet),
          "setup/migrate/assets seconds",
          "mix test --only e2e",
          "browser tests seconds"
        ] do
      assert_contains(e2e_job, expected)
    end

    refute e2e_job =~ "mix test.e2e",
           "Expected CI E2E to expose split setup/browser timings instead of one alias duration"
  end

  test "workflow does not expose release credentials to CI jobs" do
    source = workflow_source()

    for forbidden <- [
          "HEX_API_KEY",
          "RELEASE_PLEASE_TOKEN",
          "RP_PAT",
          "contents: write",
          "pull-requests: write",
          "hex.publish"
        ] do
      refute source =~ forbidden,
             "Expected CI workflow not to include release credential path #{inspect(forbidden)}"
    end
  end

  def workflow_source, do: File.read!(@workflow_path)

  def assert_contains(source, expected) do
    assert source =~ expected, "Expected workflow source to include #{inspect(expected)}"
  end

  def event_block!(source, event) do
    needle = "\n  #{event}:\n"
    start = position!(source, needle, @workflow_path) + byte_size(needle)
    rest = binary_part(source, start, byte_size(source) - start)

    case Regex.run(~r/\n(?:  [a-z_]+:|\S)/, rest, return: :index) do
      [{stop, _length}] -> binary_part(rest, 0, stop)
      nil -> rest
    end
  end

  def job_block!(source, job) do
    needle = "\n  #{job}:\n"
    start = position!(source, needle, @workflow_path) + byte_size(needle)
    rest = binary_part(source, start, byte_size(source) - start)

    case Regex.run(~r/\n  [a-zA-Z0-9_-]+:\n/, rest, return: :index) do
      [{stop, _length}] -> binary_part(rest, 0, stop)
      nil -> rest
    end
  end

  def path_filters(event_block) do
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
