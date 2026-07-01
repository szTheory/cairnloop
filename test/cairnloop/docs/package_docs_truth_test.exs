defmodule Cairnloop.Docs.PackageDocsTruthTest do
  @moduledoc """
  DB-free source scan for Hex package, ExDoc, version, changelog, and guide asset truth.

  The test reads source files and uses `git ls-files` for tracked Markdown/asset lists. It never
  starts Repo, Phoenix, browser tooling, Docker, or external network clients.
  """

  use ExUnit.Case, async: true

  @mix_path "mix.exs"
  @root_module_path "lib/cairnloop.ex"
  @readme_path "README.md"
  @changelog_path "CHANGELOG.md"
  @quickstart_path "guides/01-quickstart.md"
  @jtbd_walkthrough_path "guides/02-jtbd-walkthrough.md"
  @guides_assets_path "guides/assets"

  @public_docs ~w(
    README.md
    LICENSE
    SECURITY.md
    UPGRADING.md
    CHANGELOG.md
    guides/01-quickstart.md
    guides/02-jtbd-walkthrough.md
    guides/03-host-integration.md
    guides/04-troubleshooting.md
    guides/05-mcp-clients.md
    guides/06-extending.md
    guides/07-auth-and-operator-identity.md
  )

  @guide_extras [
    {"guides/01-quickstart.md", "Quickstart"},
    {"guides/02-jtbd-walkthrough.md", "JTBD Walkthrough"},
    {"guides/03-host-integration.md", "Host Integration"},
    {"guides/07-auth-and-operator-identity.md", "Auth & Operator Identity"},
    {"guides/04-troubleshooting.md", "Troubleshooting"},
    {"guides/05-mcp-clients.md", "MCP Clients"},
    {"guides/06-extending.md", "Extending Cairnloop"}
  ]

  @stale_dependency_snippets [
    ~s({:cairnloop, "~> 0.1.0"}),
    ~s({:cairnloop, "~> 0.2.0"}),
    ~s({:cairnloop, "~> 0.3.0"}),
    ~s({:cairnloop, "~> 0.4.0"})
  ]

  test "Hex package files include public docs and all shipped guides" do
    package_files = package_files()

    for expected <- [
          "lib",
          "priv",
          "mix.exs",
          "logo/cairnloop-lockup-horizontal.svg" | @public_docs
        ] do
      assert expected in package_files,
             "Expected mix.exs package files to include #{inspect(expected)}"
    end

    assert Enum.filter(package_files, &String.starts_with?(&1, "guides/")) ==
             Enum.filter(@public_docs, &String.starts_with?(&1, "guides/"))

    refute Enum.any?(package_files, &String.starts_with?(&1, "guides/assets")),
           "Guide assets should be routed through ExDoc assets, not package[:files]"

    assert Enum.filter(package_files, &String.starts_with?(&1, "logo/")) == [
             "logo/cairnloop-lockup-horizontal.svg"
           ],
           "Only the README header logo should be included from logo/"
  end

  test "ExDoc extras include README, trust docs, changelog, and every public guide" do
    mix_exs = read!(@mix_path)

    for {path, title} <- @guide_extras do
      assert mix_exs =~ ~s({"#{path}", title: "#{title}"}),
             "Expected docs[:extras] to include #{path} titled #{title}"
    end

    for expected <- ["UPGRADING.md", "README.md", "SECURITY.md", "CHANGELOG.md"] do
      assert docs_extras_block(mix_exs) =~ ~s("#{expected}"),
             "Expected docs[:extras] to include #{expected}"
    end

    assert mix_exs =~ ~r/groups_for_extras:\s*\[\s*Guides:\s*~r\/\^guides\\\//s
  end

  test "ExDoc assets route guide images and README logo through assets directories" do
    mix_exs = read!(@mix_path)

    assert mix_exs =~ ~s("guides/assets" => "assets")
    assert mix_exs =~ ~s("logo" => "logo")
    assert File.exists?(@guides_assets_path)
    assert File.exists?("logo/cairnloop-lockup-horizontal.svg")
  end

  test "dependency snippets match the project version and reject stale pre-v0.5 snippets" do
    version = project_version()

    for path <- [@readme_path, @quickstart_path] do
      assert read!(path) =~ ~s({:cairnloop, "~> #{version}"}),
             "Expected #{path} dependency snippet to use project version #{version}"
    end

    scanned_docs =
      ["README.md", "CHANGELOG.md" | tracked_files("guides/*.md")]
      |> Enum.map(&{&1, read!(&1)})

    for {path, source} <- scanned_docs,
        stale <- @stale_dependency_snippets do
      refute source =~ stale, "Expected #{path} not to contain stale dependency snippet #{stale}"
    end
  end

  test "all local Markdown and HTML asset references resolve and are package-visible when needed" do
    missing =
      ["README.md" | tracked_files("guides/*.md")]
      |> Enum.flat_map(fn path ->
        path
        |> local_asset_refs()
        |> Enum.reject(&asset_ref_visible?(path, &1))
        |> Enum.map(fn asset_ref -> "#{path} -> #{asset_ref}" end)
      end)

    assert missing == [],
           """
           Every local Markdown/HTML asset reference in README.md and guides/*.md must resolve on disk
           and be visible to package/ExDoc output when needed.
           Missing:
           #{Enum.join(missing, "\n")}
           """
  end

  test "JTBD walkthrough uses the existing operator inbox asset target" do
    walkthrough = read!(@jtbd_walkthrough_path)

    assert walkthrough =~ "assets/02b-operator-inbox.png"
    refute walkthrough =~ "assets/02-operator-inbox.png"
  end

  test "changelog Unreleased comparison is anchored to the current release" do
    version = project_version()
    changelog = read!(@changelog_path)

    assert changelog =~
             "[Unreleased]: https://github.com/szTheory/cairnloop/compare/v#{version}...HEAD"
  end

  test "root module docs point to the public adoption and trust surfaces" do
    root_docs = read!(@root_module_path)

    for expected <- [
          "README.md",
          "guides/01-quickstart.md",
          "guides/03-host-integration.md",
          "guides/04-troubleshooting.md",
          "guides/05-mcp-clients.md",
          "guides/06-extending.md",
          "guides/07-auth-and-operator-identity.md",
          "UPGRADING.md",
          "SECURITY.md",
          "CHANGELOG.md"
        ] do
      assert root_docs =~ expected, "Expected root module docs to mention #{expected}"
    end

    refute root_docs =~ "Hello world"
    refute root_docs =~ "def hello"
    refute root_docs =~ ":world"
  end

  defp package_files do
    @mix_path
    |> read!()
    |> then(fn source ->
      case Regex.run(~r/files:\s*~w\(([^)]*)\)/, source, capture: :all_but_first) do
        [files] -> String.split(files)
        nil -> flunk("Could not find package files allowlist in #{@mix_path}")
      end
    end)
  end

  defp docs_extras_block(mix_exs) do
    case Regex.run(~r/extras:\s*\[(?<block>.*?)\n\s+\],\n\s+groups_for_extras:/s, mix_exs,
           capture: ["block"]
         ) do
      [block] -> block
      nil -> flunk("Could not find docs[:extras] block in #{@mix_path}")
    end
  end

  defp local_asset_refs(path) do
    path
    |> read!()
    |> then(fn source ->
      markdown_refs =
        Regex.scan(~r/!\[[^\]]*\]\(([^)#\s]+)\)/, source, capture: :all_but_first)

      html_refs =
        Regex.scan(~r/<img\b[^>]*\bsrc=["']([^"']+)["']/i, source, capture: :all_but_first)

      markdown_refs ++ html_refs
    end)
    |> List.flatten()
    |> Enum.reject(&remote_or_anchor?/1)
    |> Enum.sort()
  end

  defp asset_ref_visible?("README.md", "logo/" <> _ = asset_ref) do
    File.exists?(asset_ref) and asset_ref in package_files()
  end

  defp asset_ref_visible?(path, asset_ref) do
    path
    |> Path.dirname()
    |> Path.join(asset_ref)
    |> File.exists?()
  end

  defp remote_or_anchor?(ref) do
    ref =~ ~r/^(?:https?:|mailto:|#|\/)/i
  end

  defp tracked_files(pattern) do
    {output, 0} = System.cmd("git", ["ls-files", pattern], stderr_to_stdout: true)

    output
    |> String.split("\n", trim: true)
    |> Enum.sort()
  end

  defp read!(path), do: File.read!(path)

  defp project_version do
    Mix.Project.config()[:version] || flunk("Could not derive project version from Mix.Project")
  end
end
