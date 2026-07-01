defmodule Cairnloop.Web.CollateralWiringTest do
  @moduledoc """
  Pure source, package, SVG, and raster guard for Phase 52 collateral wiring.

  The test reads static files only: no Repo, no Endpoint, no Phoenix server.
  """
  use ExUnit.Case, async: true

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

  @approved_logo_pngs ~w(favicon-16.png favicon-32.png cairnloop-og.png)
  @approved_logo_icos ~w(favicon.ico)
  @runtime_rasters ~w(
    examples/cairnloop_example/priv/static/favicon.ico
    examples/cairnloop_example/priv/static/images/cairnloop-og.png
  )
  @raster_budget_kb 150
  @package_files ~w(
    lib
    priv
    mix.exs
    README.md
    logo/cairnloop-lockup-horizontal.svg
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

  @forbidden_svg_patterns [
    {:script, ~r/<script\b/i},
    {:inline_event_handler, ~r/\son[a-z]+\s*=/i},
    {:foreign_object, ~r/<foreignObject\b/i},
    {:embedded_raster, ~r/<image\b/i},
    {:external_or_active_href,
     ~r/(?:href|xlink:href)\s*=\s*["']\s*(?:https?:|\/\/|data:|javascript:|vbscript:)/i},
    {:editor_metadata, ~r/<metadata\b|\b(?:sodipodi|inkscape):/i}
  ]

  test "README starts with approved repo-relative logo and keeps badges below" do
    readme = File.read!("README.md")
    visible_lines = readme |> String.split("\n") |> Enum.reject(&(String.trim(&1) == ""))

    first_visible = List.first(visible_lines)
    badge_block = visible_lines |> Enum.slice(1, 4) |> Enum.join("\n")

    assert first_visible =~ ~s(src="logo/cairnloop-lockup-horizontal.svg"),
           "README.md first visible line must use repo-relative logo/cairnloop-lockup-horizontal.svg"

    assert first_visible =~ ~s(alt="Cairnloop"),
           "README.md first visible line must use exact alt text Cairnloop"

    refute first_visible =~ ~r/src=["'](?:\/|https?:|file:|data:)/i,
           "README.md logo source must not be root-relative, remote, file://, or data URL"

    assert badge_block =~ "img.shields.io/hexpm/v/cairnloop.svg",
           "README.md badges must remain immediately below the logo"

    assert badge_block =~ "hexdocs-online-blue.svg",
           "README.md HexDocs badge must remain immediately below the logo"

    assert badge_block =~ "GitHub Actions CI",
           "README.md CI badge must remain immediately below the logo"

    refute readme =~ "🏔️", "README.md must not retain the old emoji identity"
  end

  test "approved logo inventory exists and rejected contest artifact stays absent" do
    usage = File.read!("logo/USAGE.md")

    for asset <- @approved_logo_assets do
      assert File.exists?("logo/#{asset}"), "Expected approved logo asset logo/#{asset} to exist"
      assert usage =~ "`#{asset}`", "Expected logo/USAGE.md to inventory #{asset}"
    end

    refute File.exists?("logo/_contest/direction-boards.html"),
           "Rejected contest board must stay deleted after final asset selection"
  end

  test "example app collateral copies approved assets and uses existing static paths" do
    assert File.read!("examples/cairnloop_example/priv/static/images/logo.svg") ==
             File.read!("logo/cairnloop-lockup-horizontal.svg"),
           "Expected example app logo.svg to be a byte-for-byte copy of the approved horizontal lockup"

    assert File.read!("examples/cairnloop_example/priv/static/favicon.ico") ==
             File.read!("logo/favicon.ico"),
           "Expected example app favicon.ico to be a byte-for-byte copy of the approved favicon"

    assert File.read!("examples/cairnloop_example/priv/static/images/favicon.svg") ==
             File.read!("logo/favicon.svg"),
           "Expected example app favicon.svg to be a byte-for-byte copy of the approved SVG favicon"

    assert File.read!("examples/cairnloop_example/priv/static/images/cairnloop-og.png") ==
             File.read!("logo/cairnloop-og.png"),
           "Expected example app cairnloop-og.png to be a byte-for-byte copy of the approved OG raster"

    web_ex = File.read!("examples/cairnloop_example/lib/cairnloop_example_web.ex")
    endpoint = File.read!("examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex")

    assert web_ex =~ "def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)",
           "Expected CairnloopExampleWeb.static_paths/0 to keep the existing static path allowlist"

    assert endpoint =~ "only: CairnloopExampleWeb.static_paths()",
           "Expected Plug.Static to keep serving the existing static_paths/0 allowlist"
  end

  test "example app root metadata and accessible logo use local Phoenix static paths" do
    root =
      File.read!(
        "examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex"
      )

    layouts =
      File.read!("examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex")

    for expected <- [
          ~s|default="Cairnloop Example"|,
          ~s|href={~p"/favicon.ico"}|,
          ~s|href={~p"/images/favicon.svg"}|,
          ~s|property="og:title" content="Cairnloop"|,
          ~s|property="og:description" content="Embedded support automation for Phoenix apps."|,
          ~s|property="og:type" content="website"|,
          ~s|property="og:image" content={url(~p"/images/cairnloop-og.png")}|,
          ~s|property="og:image:alt" content="Cairnloop — Support that leaves a trail."|
        ] do
      assert root =~ expected, "Expected root.html.heex to include #{inspect(expected)}"
    end

    assert layouts =~ ~s(src={~p"/images/logo.svg"}),
           "Expected example app logo image to use the local verified static path"

    assert layouts =~ ~s(alt="Cairnloop"),
           "Expected example app logo image to use exact alt text Cairnloop"

    refute layouts =~ "Application.spec(:phoenix, :vsn)",
           "Expected example app logo cluster to remove Phoenix version trivia"
  end

  test "SVG safe subset rejects active content and spacing-obfuscated hrefs" do
    unsafe_snippets = [
      {:inline_event_handler,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1" onload="alert(1)"></svg>|},
      {:inline_event_handler,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><circle onclick="alert(1)" cx="0" cy="0" r="1"/></svg>|},
      {:external_or_active_href,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><a href="javascript:alert(1)"><path d="M0 0"/></a></svg>|},
      {:external_or_active_href,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><a href=" javascript:alert(1)"><path d="M0 0"/></a></svg>|},
      {:external_or_active_href,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><a href="&#106;avascript:alert(1)"><path d="M0 0"/></a></svg>|},
      {:external_or_active_href,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><a href="&#x6a;avascript:alert(1)"><path d="M0 0"/></a></svg>|},
      {:external_or_active_href,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><a href = "https://example.com"><path d="M0 0"/></a></svg>|},
      {:external_or_active_href,
       ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><a xlink:href="vbscript:msgbox(1)"><path d="M0 0"/></a></svg>|}
    ]

    for {expected_violation, svg} <- unsafe_snippets do
      assert expected_violation in svg_safe_subset_violations(svg),
             "Expected unsafe SVG snippet to trigger #{expected_violation}: #{svg}"
    end
  end

  test "all tracked SVGs are well formed and stay within the safe subset" do
    svg_paths = tracked_files("*.svg")
    refute svg_paths == [], "Expected git ls-files '*.svg' to find committed SVGs"

    for path <- svg_paths do
      svg = File.read!(path)

      assert xml_well_formed?(svg),
             "Expected #{path} to be XML well-formed"

      assert svg =~ ~r/<svg\b[^>]*\bxmlns=["']http:\/\/www\.w3\.org\/2000\/svg["']/,
             "Expected #{path} root <svg> to declare the SVG xmlns"

      assert viewbox_valid?(svg),
             "Expected #{path} root <svg> viewBox to parse as four numbers with positive width and height"

      violations = svg_safe_subset_violations(svg)

      assert violations == [],
             "Forbidden SVG constructs in #{path}: #{Enum.join(violations, ", ")}. Remove scripts, foreignObject, embedded rasters, external/data hrefs, and editor metadata."
    end
  end

  test "source and runtime raster policy stays under budget and avoids PNG logo fallbacks" do
    raster_paths = Path.wildcard("logo/*.png") ++ Path.wildcard("logo/*.ico") ++ @runtime_rasters
    refute raster_paths == [], "Expected source logo rasters to exist"

    unexpected_pngs =
      Path.wildcard("logo/*.png")
      |> Enum.map(&Path.basename/1)
      |> Enum.reject(&(&1 in @approved_logo_pngs))

    assert unexpected_pngs == [],
           "Unexpected logo PNG fallback(s): #{Enum.join(unexpected_pngs, ", ")}. Only favicon PNGs and cairnloop-og.png are approved."

    unexpected_icos =
      Path.wildcard("logo/*.ico")
      |> Enum.map(&Path.basename/1)
      |> Enum.reject(&(&1 in @approved_logo_icos))

    assert unexpected_icos == [],
           "Unexpected ICO file(s): #{Enum.join(unexpected_icos, ", ")}. Only favicon.ico is approved."

    {du_output, du_exit} = System.cmd("du", ["-ck" | raster_paths], stderr_to_stdout: true)
    assert du_exit == 0, du_output

    total_kb = total_kb_from_du!(du_output)

    assert total_kb <= @raster_budget_kb,
           "Raster budget exceeded: #{total_kb}KB > #{@raster_budget_kb}KB for #{Enum.join(raster_paths, ", ")}"
  end

  test "collateral E2E source proves browser rendering and asset fetches" do
    path = "examples/cairnloop_example/test/e2e/collateral_wiring_test.exs"
    assert File.exists?(path), "Expected #{path} to exist"

    source = File.read!(path)

    for expected <- [
          "defmodule CairnloopExampleWeb.CollateralWiringE2ETest",
          "use PhoenixTest.Playwright.Case",
          "@moduletag :e2e",
          ~s|visit("/")|,
          ~s(body .phx-connected),
          "getBoundingClientRect",
          "naturalWidth",
          "naturalHeight",
          "fetch(",
          "/images/logo.svg",
          "/favicon.ico",
          "/images/favicon.svg",
          "/images/cairnloop-og.png",
          "og:image:alt"
        ] do
      assert source =~ expected, "Expected collateral E2E source to include #{inspect(expected)}"
    end
  end

  test "Hex package files allowlist keeps brand collateral unshipped" do
    mix_exs = File.read!("mix.exs")
    expected = Enum.join(@package_files, " ")

    assert mix_exs =~ ~r/files:\s*~w\([^)]*guides\/01-quickstart\.md[^)]*\)/,
           "Expected mix.exs package files allowlist to remain files: ~w(#{expected})"

    [_, files] = Regex.run(~r/files:\s*~w\(([^)]*)\)/, mix_exs)
    package_files = String.split(files)

    assert package_files == @package_files,
           "Expected package files #{inspect(@package_files)}, got #{inspect(package_files)}"

    for forbidden <- ~w(brandbook scripts guides/assets) do
      refute Enum.any?(package_files, &String.starts_with?(&1, forbidden)),
             "Expected #{forbidden}/ to remain outside the Hex package files allowlist"
    end

    assert Enum.filter(package_files, &String.starts_with?(&1, "logo/")) == [
             "logo/cairnloop-lockup-horizontal.svg"
           ],
           "Expected only the README header logo to ship in the Hex package"
  end

  defp tracked_files(pattern) do
    {output, 0} = System.cmd("git", ["ls-files", pattern], stderr_to_stdout: true)

    output
    |> String.split("\n", trim: true)
    |> Enum.sort()
  end

  defp viewbox_valid?(svg) do
    case Regex.run(~r/<svg\b[^>]*\bviewBox=["']([^"']+)["']/, svg) do
      [_, value] ->
        numbers =
          value
          |> String.split(~r/[\s,]+/, trim: true)
          |> Enum.map(&Float.parse/1)

        match?(
          [{_, ""}, {_, ""}, {width, ""}, {height, ""}] when width > 0 and height > 0,
          numbers
        )

      _ ->
        false
    end
  end

  defp xml_well_formed?(xml) do
    xml
    |> String.to_charlist()
    |> :xmerl_scan.string(quiet: true)
    |> elem(0)
    |> elem(0)
    |> Kernel.==(:xmlElement)
  rescue
    _ -> false
  catch
    :exit, _reason -> false
  end

  defp svg_safe_subset_violations(svg) do
    normalized = decode_xml_entities_for_scan(svg)

    for {label, pattern} <- @forbidden_svg_patterns,
        Regex.match?(pattern, normalized),
        do: label
  end

  defp decode_xml_entities_for_scan(svg) do
    svg = Regex.replace(~r/&#x([0-9a-f]+);?/i, svg, fn _, hex -> codepoint_to_string(hex, 16) end)
    Regex.replace(~r/&#([0-9]+);?/, svg, fn _, decimal -> codepoint_to_string(decimal, 10) end)
  end

  defp codepoint_to_string(value, base) do
    <<String.to_integer(value, base)::utf8>>
  rescue
    ArgumentError -> ""
  end

  defp total_kb_from_du!(du_output) do
    du_output
    |> String.split("\n", trim: true)
    |> List.last()
    |> String.split()
    |> List.first()
    |> String.to_integer()
  end
end
