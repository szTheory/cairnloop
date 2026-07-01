defmodule Cairnloop.Web.BrandbookScaffoldTest do
  @moduledoc """
  Pure source, package, and derivation guard for the Phase 51 brandbook.

  The test reads static files only: no Repo, no Endpoint, no Phoenix server.
  """
  use ExUnit.Case, async: true

  @required_files ~w(
    brandbook/index.html
    brandbook/TOKENS.md
    brandbook/assets/css/tokens.css
    brandbook/assets/css/brandbook.css
    brandbook/color/swatches.json
    brandbook/logo/.gitkeep
    brandbook/raster/.gitkeep
    scripts/derive_brandbook_tokens.exs
    scripts/assemble_brandbook.exs
    scripts/verify_brandbook_file_load.mjs
  )

  @required_index_labels [
    "Cairnloop brand book",
    "Support that leaves a trail.",
    "Canonical source: priv/static/cairnloop.css :root",
    "Token status: derived from canonical CSS",
    "Network dependency: none",
    "Brandbook is git-tracked and unshipped",
    "Logo-family sign-off remains before Phase 52 wiring",
    "Color",
    "Typography",
    "Spacing, Radius, Shadow, Motion tokens",
    "Logo system",
    "Voice and Microcopy",
    "Microcopy",
    "Imagery",
    "Motion guidance",
    "Downloads",
    "Brandbook asset failed to load. Check relative paths, regenerate tokens from priv/static/cairnloop.css, and rerun the file-load verification."
  ]

  @required_status_labels [
    "AA pass",
    "UI pass",
    "Decorative exempt",
    "Do",
    "Do not",
    "Light",
    "Dark"
  ]

  @approved_logo_assets ~w(
    cairnloop-lockup-horizontal.svg
    cairnloop-lockup-stacked.svg
    cairnloop-mark.svg
    cairnloop-lockup-horizontal-mono.svg
    cairnloop-lockup-horizontal-reverse.svg
    cairnloop-lockup-tagline.svg
    favicon.svg
    favicon-16.png
    favicon-32.png
    favicon.ico
    cairnloop-og.svg
    cairnloop-og.png
  )

  @assembly_source_labels [
    "defmodule Cairnloop.BrandbookAssembly",
    "def run(argv)",
    ~s(@index_path "brandbook/index.html"),
    ~s(@check_command "mix run scripts/assemble_brandbook.exs --check")
  ]

  @browser_verifier_source_labels [
    "examples",
    "cairnloop_example",
    "node_modules",
    "playwright",
    "index.mjs",
    ~s({ name: "mobile", width: 390, height: 844 }),
    ~s({ name: "tablet", width: 768, height: 1024 }),
    ~s({ name: "desktop", width: 1280, height: 900 }),
    ~s(html[data-theme="dark"]),
    "aria-pressed",
    "boxShadow",
    "../logo/cairnloop-lockup-horizontal.svg",
    "../logo/cairnloop-mark.svg",
    "../logo/favicon.ico",
    "../logo/cairnloop-og.png"
  ]

  @required_token_notes [
    "priv/static/cairnloop.css",
    "mix run scripts/derive_brandbook_tokens.exs",
    "mix run scripts/derive_brandbook_tokens.exs --check",
    "brandbook/assets/css/tokens.css",
    "brandbook/color/swatches.json"
  ]

  @forbidden_dependency_pattern ~r/https?:\/\/|(^|[^:])\/\/|@import|<iframe|\bsendBeacon\b|url\((['"]?)https?:|url\((['"]?)\//i

  test "required brandbook files and directories exist" do
    for path <- @required_files do
      assert File.exists?(path), "Expected #{path} to exist"
    end
  end

  test "assembly script exposes deterministic entrypoint and check command" do
    script = File.read!("scripts/assemble_brandbook.exs")

    for label <- @assembly_source_labels do
      assert script =~ label, "Expected assemble_brandbook.exs to include #{inspect(label)}"
    end
  end

  test "index carries required Phase 51 labels and relative stylesheets" do
    html = File.read!("brandbook/index.html")

    for label <- @required_index_labels do
      assert html =~ label, "Expected brandbook/index.html to include #{inspect(label)}"
    end

    for label <- @required_status_labels do
      assert html =~ label,
             "Expected brandbook/index.html to include visible status label #{inspect(label)}"
    end

    assert html =~ ~s(href="./assets/css/tokens.css")
    assert html =~ ~s(href="./assets/css/brandbook.css")
    assert html =~ ~s(data-theme-choice="light")
    assert html =~ ~s(data-theme-choice="dark")
    assert html =~ ~s(class="brandbook-table-wrap")
    refute html =~ "fetch("
  end

  test "browser verifier covers final file-url behavior contract" do
    verifier = File.read!("scripts/verify_brandbook_file_load.mjs")

    for label <- @browser_verifier_source_labels do
      assert verifier =~ label,
             "Expected verify_brandbook_file_load.mjs to include #{inspect(label)}"
    end
  end

  test "approved logo inventory has relative downloads and no live-text wordmark recreation" do
    html = File.read!("brandbook/index.html")
    usage = File.read!("logo/USAGE.md")

    for asset <- @approved_logo_assets do
      assert File.exists?("logo/#{asset}"), "Expected logo/#{asset} to exist"
      assert usage =~ "`#{asset}`", "Expected logo/USAGE.md to inventory #{asset}"

      assert html =~ ~s(href="../logo/#{asset}"),
             "Expected brandbook/index.html to link ../logo/#{asset}"
    end

    assert html =~ "no live-text wordmark recreation" or
             html =~ "No live-text wordmark recreation"
  end

  test "token documentation names source, outputs, generation, and check commands" do
    docs = File.read!("brandbook/TOKENS.md")

    for note <- @required_token_notes do
      assert docs =~ note, "Expected TOKENS.md to include #{inspect(note)}"
    end
  end

  test "generated token outputs have provenance and no contrast matrices" do
    tokens_css = File.read!("brandbook/assets/css/tokens.css")
    swatches = File.read!("brandbook/color/swatches.json") |> Jason.decode!()

    assert tokens_css =~ "Generated from priv/static/cairnloop.css"
    assert tokens_css =~ "Regenerate with: mix run scripts/derive_brandbook_tokens.exs"
    assert tokens_css =~ "Check drift with: mix run scripts/derive_brandbook_tokens.exs --check"
    assert tokens_css =~ ":root {"
    assert tokens_css =~ ~s([data-theme="dark"] {)
    refute tokens_css =~ ~r/^\s*\.(cl|brandbook)-/m
    refute tokens_css =~ ~r/^\s*@media/m

    assert swatches["schema_version"]
    assert swatches["source_file"] == "priv/static/cairnloop.css"
    assert swatches["generated_by"] == "mix run scripts/derive_brandbook_tokens.exs"
    assert swatches["check_command"] == "mix run scripts/derive_brandbook_tokens.exs --check"
    assert is_list(swatches["groups"]["primitive"])
    assert is_list(swatches["groups"]["semantic_light"])
    assert is_list(swatches["groups"]["semantic_dark"])
    refute inspect(swatches) =~ "contrast"
  end

  test "brandbook source has no remote, import, iframe, beacon, or root-relative dependencies" do
    files =
      Path.wildcard("brandbook/**/*")
      |> Kernel.++(["scripts/assemble_brandbook.exs"])
      |> Enum.filter(&File.regular?/1)

    refute files == [], "Expected brandbook files to scan"

    violations =
      for file <- files,
          {line, line_no} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(@forbidden_dependency_pattern, line) do
        {file, line_no, String.trim(line)}
      end

    assert violations == [],
           """
           Forbidden brandbook dependency/path found.

           Violations:
           #{Enum.map_join(violations, "\n", fn {file, line_no, line} -> "  #{file}:#{line_no} - #{line}" end)}
           """
  end

  test "brandbook remains outside the Hex package files allowlist" do
    mix_exs = File.read!("mix.exs")
    [_, files] = Regex.run(~r/files:\s*~w\(([^)]*)\)/, mix_exs)
    package_files = String.split(files)

    assert mix_exs =~ ~r/files:\s*~w\([^)]*guides\/01-quickstart\.md[^)]*\)/
    refute Enum.any?(package_files, &String.starts_with?(&1, "brandbook"))
    refute Enum.any?(package_files, &String.starts_with?(&1, "guides/assets"))
  end

  test "generated token outputs are current" do
    {output, exit_code} =
      System.cmd("mix", ["run", "scripts/derive_brandbook_tokens.exs", "--check"],
        stderr_to_stdout: true
      )

    assert exit_code == 0, output
  end

  test "assembled brandbook output is current" do
    {output, exit_code} =
      System.cmd("mix", ["run", "scripts/assemble_brandbook.exs", "--check"],
        stderr_to_stdout: true
      )

    assert exit_code == 0, output
  end
end
