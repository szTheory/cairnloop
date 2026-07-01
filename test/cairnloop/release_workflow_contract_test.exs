defmodule Cairnloop.ReleaseWorkflowContractTest do
  @moduledoc """
  DB-free source contract for the release-please and Hex publish workflow.

  The test reads workflow source only. It never publishes packages, starts Repo,
  calls GitHub Actions, or performs network release verification.
  """

  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/release-please.yml"

  test "workflow runs only from trusted refs and defaults to read-only permissions" do
    source = workflow_source()

    for expected <- [
          "on:\n  push:",
          "branches:\n      - main",
          "\n  workflow_dispatch:",
          "permissions:\n  contents: read",
          ~s(FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"),
          "concurrency:",
          "cancel-in-progress: false"
        ] do
      assert_contains(source, expected)
    end

    refute source =~ "\n  pull_request:",
           "Expected release workflow not to run from pull_request"

    refute source =~ "pull_request_target",
           "Expected release workflow not to run untrusted PR code with trusted permissions"
  end

  test "release-please write permissions are scoped to release PR automation" do
    source = workflow_source()
    release_job = job_block!(source, "release-please")
    publish_job = job_block!(source, "publish-hex")

    for expected <- [
          "permissions:\n      contents: write\n      pull-requests: write",
          "uses: actions/checkout@v7",
          "fetch-depth: 0",
          "persist-credentials: false",
          "uses: googleapis/release-please-action@v5",
          "config-file: release-please-config.json",
          "manifest-file: .release-please-manifest.json",
          "gh pr merge --auto --merge"
        ] do
      assert_contains(release_job, expected)
    end

    assert_contains(publish_job, "permissions:\n      contents: read")
    refute publish_job =~ "pull-requests: write"
    refute publish_job =~ "contents: write"
  end

  test "publish job checks out exact release sha and keeps credentials unpersisted" do
    source = workflow_source()
    publish_job = job_block!(source, "publish-hex")

    for expected <- [
          "needs: [release-please]",
          "if: ${{ needs.release-please.outputs.release_created == 'true' }}",
          "HEX_API_KEY: ${{ secrets.HEX_API_KEY }}",
          ~s(ELIXIR_VERSION: "1.19.5"),
          ~s(OTP_VERSION: "27.2"),
          ~s(MIX_CACHE_VERSION: "v1"),
          "uses: actions/checkout@v7",
          "ref: ${{ needs.release-please.outputs.sha }}",
          "persist-credentials: false",
          "uses: erlef/setup-beam@v1",
          "uses: actions/cache@v6"
        ] do
      assert_contains(publish_job, expected)
    end

    refute source =~ "ACTIONS_RUNNER_NODE_VERSION",
           "Expected release workflow to avoid the stale Node transition variable"

    refute source =~ "ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION",
           "Expected release workflow not to opt out of Node 24"
  end

  test "publish job preflights token and verifies package before irreversible publish" do
    source = workflow_source()
    publish_job = job_block!(source, "publish-hex")

    for expected <- [
          "name: Preflight Hex token",
          ~s(if [ -z "$HEX_API_KEY" ]; then),
          "mix deps.get --check-locked",
          "name: Release quality preflight",
          "mix ci.quality",
          "quality preflight seconds",
          "mix hex.publish --dry-run",
          "publish dry-run seconds",
          "mix hex.build",
          "tarball=\"$(ls cairnloop-*.tar | head -1)\"",
          "for expected in lib priv guides mix.exs README.md LICENSE CHANGELOG.md; do",
          "package inspection seconds",
          "mix hex.publish --yes",
          "hex publish seconds",
          "mix hex.info cairnloop \"${{ needs.release-please.outputs.version }}\"",
          "hex info seconds",
          "mix hex.docs fetch cairnloop \"${{ needs.release-please.outputs.version }}\"",
          "hexdocs verification seconds"
        ] do
      assert_contains(publish_job, expected)
    end

    assert ordered?(publish_job, "Preflight Hex token", "Publish dry run")
    assert ordered?(publish_job, "Install dependencies", "Release quality preflight")
    assert ordered?(publish_job, "Release quality preflight", "Publish dry run")
    assert ordered?(publish_job, "Publish dry run", "Verify packaged artifact contents")
    assert ordered?(publish_job, "Verify packaged artifact contents", "Publish package")
    assert ordered?(publish_job, "Publish package", "Verify Hex package release")
    assert ordered?(publish_job, "Verify Hex package release", "Verify HexDocs release")

    assert ordered?(publish_job, "Release quality preflight", "Publish package")
  end

  test "publish job writes bounded release summary evidence without secrets" do
    source = workflow_source()
    publish_job = job_block!(source, "publish-hex")

    for expected <- [
          "name: Release publish summary",
          "## Release publish",
          "version: ${{ needs.release-please.outputs.version }}",
          "tag: ${{ needs.release-please.outputs.tag_name }}",
          "release SHA: ${{ needs.release-please.outputs.sha }}",
          "Elixir/OTP:",
          "deps cache hit: ${{ steps.mix-deps-cache.outputs.cache-hit }}",
          "build cache hit: ${{ steps.mix-build-cache.outputs.cache-hit }}"
        ] do
      assert_contains(publish_job, expected)
    end

    refute publish_job =~ ~s(echo "$HEX_API_KEY"),
           "Expected release summary not to print HEX_API_KEY"

    refute publish_job =~ ~r/curl .*echo/,
           "Expected release workflow not to echo long curl output into summaries"
  end

  test "release workflow does not expose publish credentials to untrusted code" do
    source = workflow_source()

    for forbidden <- [
          "pull_request",
          "pull_request_target",
          "issue_comment",
          "workflow_run"
        ] do
      refute source =~ forbidden,
             "Expected release workflow not to include untrusted trigger #{inspect(forbidden)}"
    end

    assert step_block!(source, "Preflight Hex token") =~ "$HEX_API_KEY"
    refute step_block!(source, "Preflight Hex token") =~ "echo $HEX_API_KEY"
  end

  def workflow_source, do: File.read!(@workflow_path)

  def assert_contains(source, expected) do
    assert source =~ expected, "Expected workflow source to include #{inspect(expected)}"
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

  def step_block!(source, step_name) do
    needle = "\n      - name: #{step_name}\n"
    start = position!(source, needle, @workflow_path) + byte_size(needle)
    rest = binary_part(source, start, byte_size(source) - start)

    case Regex.run(~r/\n      - (?:name|uses): /, rest, return: :index) do
      [{stop, _length}] -> binary_part(rest, 0, stop)
      nil -> rest
    end
  end

  def ordered?(source, first, second) do
    case {:binary.match(source, first), :binary.match(source, second)} do
      {{first_pos, _}, {second_pos, _}} -> first_pos < second_pos
      _ -> false
    end
  end

  defp position!(source, needle, label) do
    case :binary.match(source, needle) do
      {position, _length} -> position
      :nomatch -> flunk("Expected #{label} to include #{inspect(needle)}")
    end
  end
end
