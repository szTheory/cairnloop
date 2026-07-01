# Phase 52: Collateral Wiring + QA/Validation Sweep - Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 11 planned or guarded files
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `README.md` | documentation / static collateral | transform | `README.md` + `logo/USAGE.md` | role-match |
| `examples/cairnloop_example/priv/static/images/logo.svg` | static asset | file-I/O + transform | `logo/cairnloop-lockup-horizontal.svg` | exact |
| `examples/cairnloop_example/priv/static/favicon.ico` | static asset | file-I/O | `logo/favicon.ico` | exact |
| `examples/cairnloop_example/priv/static/images/cairnloop-og.png` | static asset | file-I/O | `logo/cairnloop-og.png` | exact |
| `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex` | layout template | request-response | same file + `CairnloopExampleWeb.static_paths/0` | exact |
| `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex` | component / layout | request-response | same file | exact |
| `test/cairnloop/web/collateral_wiring_test.exs` | test / source guard | file-I/O + batch | `test/cairnloop/web/brandbook_scaffold_test.exs` | exact |
| `examples/cairnloop_example/test/e2e/collateral_wiring_test.exs` | test / browser E2E | request-response | `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs` | exact |
| `mix.exs` (guarded unchanged) | config / package | batch | `mix.exs` + `test/cairnloop/web/brandbook_scaffold_test.exs` | exact |
| `examples/cairnloop_example/mix.exs` (guarded unchanged) | config / test alias | batch | `examples/cairnloop_example/mix.exs` | exact |
| `.github/workflows/ci.yml` (guarded unchanged) | config / CI | batch | `.github/workflows/ci.yml` | exact |

## Pattern Assignments

### `README.md` (documentation, transform)

**Analog:** `README.md` and `logo/USAGE.md`

**Current header to replace/demote** (`README.md` lines 1-7):
```markdown
# Cairnloop 🏔️

[![Hex.pm Version](https://img.shields.io/hexpm/v/cairnloop.svg)](https://hex.pm/packages/cairnloop)
[![HexDocs](https://img.shields.io/badge/hexdocs-online-blue.svg)](https://hexdocs.pm/cairnloop)
[![GitHub Actions CI](https://github.com/szTheory/cairnloop/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/cairnloop/actions)

An embedded, Phoenix-native customer support automation layer for Elixir applications.
```

**Approved README logo source** (`logo/USAGE.md` lines 7-20):
```markdown
| `cairnloop-lockup-horizontal.svg` | Default public logo for README, docs headers, package surfaces, and broad brand identification. | Primary lockup. No subtitle. Use first unless the surface is square or size-constrained. |
| `favicon.ico` | Browser ICO fallback with 16px and 32px entries. | Generated from the approved favicon rasters. |
| `cairnloop-og.png` | 1200x630 OG/social preview raster. | Use for GitHub/social metadata after Phase 52 wiring. |
```

**Planner instruction:** keep the badge block from `README.md` lines 3-5 immediately below a repo-relative image header using `logo/cairnloop-lockup-horizontal.svg` and `alt="Cairnloop"`. Do not claim HexDocs/package rendering for `logo/` assets because `logo/` is intentionally excluded from package files.

---

### `examples/cairnloop_example/priv/static/images/logo.svg` (static asset, file-I/O + transform)

**Analog:** `logo/cairnloop-lockup-horizontal.svg`

**Current placeholder to replace** (`examples/cairnloop_example/priv/static/images/logo.svg` lines 1-6):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 71 48" fill="currentColor" aria-hidden="true">
```

**Approved SVG geometry/header pattern** (`logo/cairnloop-lockup-horizontal.svg` lines 1-9):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 260 64" role="img" aria-labelledby="cairnloop-horizontal-title cairnloop-horizontal-desc">
  <title id="cairnloop-horizontal-title">cairnloop horizontal lockup</title>
  <desc id="cairnloop-horizontal-desc">Default Cairnloop horizontal logo lockup with the C3.6 cairn mark and plain lowercase cairnloop wordmark.</desc>
  <g id="cairnloop-horizontal-c3-6-cairn-mark" transform="translate(8 8)">
    <circle cx="24" cy="14.8" r="5.4" fill="none" stroke="#A8492A" stroke-width="2.8"/>
    <rect x="12" y="25" width="24" height="7" rx="3.5" fill="#1E2A24"/>
    <rect x="7" y="34" width="34" height="8" rx="4" fill="#141B19"/>
  </g>
```

**Core pattern:** copy the approved SVG file content, do not redraw or rewrite geometry. The static guard should fail if the example logo still contains `viewBox="0 0 71 48"`.

---

### `examples/cairnloop_example/priv/static/favicon.ico` (static asset, file-I/O)

**Analog:** `logo/favicon.ico`

**Approved favicon inventory** (`logo/USAGE.md` lines 15-18):
```markdown
| `favicon.svg` | SVG favicon source and small browser icon source. | Separately authored simplified cut. Do not substitute the full mark at 16px. |
| `favicon-16.png` | 16px raster favicon fallback. | Generated from `favicon.svg`. |
| `favicon-32.png` | 32px raster favicon fallback. | Generated from `favicon.svg`. |
| `favicon.ico` | Browser ICO fallback with 16px and 32px entries. | Generated from the approved favicon rasters. |
```

**Current target problem:** `examples/cairnloop_example/priv/static/favicon.ico` currently identifies as a stock 64x64 PNG-like file, while `logo/favicon.ico` is an ICO resource with 16x16 and 32x32 entries. Copy the approved binary exactly; no source-code analog applies to binary content.

---

### `examples/cairnloop_example/priv/static/images/cairnloop-og.png` (static asset, file-I/O)

**Analog:** `logo/cairnloop-og.png` and `logo/cairnloop-og.svg`

**Approved OG source semantics** (`logo/cairnloop-og.svg` lines 1-11):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" role="img" aria-label="cairnloop - Embedded support automation for Phoenix apps. Support that leaves a trail.">
  <rect width="1200" height="630" fill="#F4EEE2"/>
  <path d="M0 550H1200V630H0Z" fill="#EFE9DC"/>
  <path d="M930 122C980 104 1040 106 1095 128" fill="none" stroke="#8E8068" stroke-width="4" stroke-linecap="round" opacity=".45"/>
  <path d="M942 159C990 142 1041 145 1085 166" fill="none" stroke="#8E8068" stroke-width="4" stroke-linecap="round" opacity=".32"/>
  <path d="M954 196C1000 181 1038 184 1076 204" fill="none" stroke="#8E8068" stroke-width="4" stroke-linecap="round" opacity=".24"/>
  <path fill="#A8492A" fill-rule="evenodd" d="M228 162a43 43 0 1 1 0 86 43 43 0 0 1 0-86Zm0 15a28 28 0 1 0 0 56 28 28 0 0 0 0-56Z"/>
  <rect x="170" y="270" width="116" height="36" rx="18" fill="#1E2A24"/>
  <rect x="140" y="326" width="176" height="42" rx="21" fill="#141B19"/>
  <rect x="116" y="402" width="132" height="8" rx="4" fill="#A8492A"/>
  <g id="cairnloop-og-wordmark" aria-label="cairnloop" fill="#141B19" transform="translate(362 158) scale(2.3)">
```

**Core pattern:** copy `logo/cairnloop-og.png` to the example app static images directory. Do not regenerate or edit the OG geometry in Phase 52.

---

### `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex` (layout template, request-response)

**Analog:** same file plus `CairnloopExampleWeb.static_paths/0`

**Existing head/static pattern** (`root.html.heex` lines 1-10):
```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title default="CairnloopExample" suffix=" · Phoenix Framework" phx-no-format>{assigns[:page_title]}</.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
```

**Verified static path support** (`examples/cairnloop_example/lib/cairnloop_example_web.ex` lines 20, 94-100):
```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

def verified_routes do
  quote do
    use Phoenix.VerifiedRoutes,
      endpoint: CairnloopExampleWeb.Endpoint,
      router: CairnloopExampleWeb.Router,
      statics: CairnloopExampleWeb.static_paths()
  end
end
```

**Plug.Static serving pattern** (`endpoint.ex` lines 31-41):
```elixir
plug Plug.Static,
  at: "/",
  from: :cairnloop_example,
  gzip: not code_reloading?,
  only: CairnloopExampleWeb.static_paths(),
  raise_on_missing_only: code_reloading?
```

**Planner instruction:** add local favicon and OG metadata in the `<head>` using `~p` paths already verified by `CairnloopExampleWeb.static_paths/0`. Use `url(~p"/images/cairnloop-og.png")` for absolute OG image content if needed. Replace generated title posture with `Cairnloop` or `Cairnloop Example`; avoid the Phoenix suffix.

---

### `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex` (component/layout, request-response)

**Analog:** same file

**Imports/template pattern** (`layouts.ex` lines 1-12):
```elixir
defmodule CairnloopExampleWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CairnloopExampleWeb, :html

  # Embed all files in layouts/* within this module.
  embed_templates "layouts/*"
```

**Logo markup to minimally update** (`layouts.ex` lines 36-43):
```heex
def app(assigns) do
  ~H"""
  <header class="navbar px-4 sm:px-6 lg:px-8">
    <div class="flex-1">
      <a href="/" class="flex-1 flex w-fit items-center gap-2">
        <img src={~p"/images/logo.svg"} width="36" />
        <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
      </a>
```

**Planner instruction:** preserve the existing app layout shape, but make the visible logo accessible with `alt="Cairnloop"` and remove/demote Phoenix-generated brand trivia only as needed for the Phase 52 contract. Do not redesign the example shell.

---

### `test/cairnloop/web/collateral_wiring_test.exs` (test, file-I/O + batch)

**Analog:** `test/cairnloop/web/brandbook_scaffold_test.exs` plus `test/cairnloop/web/responsive_markup_test.exs`

**DB-free imports/purpose pattern** (`brandbook_scaffold_test.exs` lines 1-8):
```elixir
defmodule Cairnloop.Web.BrandbookScaffoldTest do
  @moduledoc """
  Pure source, package, and derivation guard for the Phase 51 brandbook.

  The test reads static files only: no Repo, no Endpoint, no Phoenix server.
  """
  use ExUnit.Case, async: true
```

**Approved logo inventory pattern** (`brandbook_scaffold_test.exs` lines 52-65):
```elixir
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
```

**File existence and usage scan pattern** (`brandbook_scaffold_test.exs` lines 145-155):
```elixir
html = File.read!("brandbook/index.html")
usage = File.read!("logo/USAGE.md")

for asset <- @approved_logo_assets do
  assert File.exists?("logo/#{asset}"), "Expected logo/#{asset} to exist"
  assert usage =~ "`#{asset}`", "Expected logo/USAGE.md to inventory #{asset}"

  assert html =~ ~s(href="../logo/#{asset}"),
         "Expected brandbook/index.html to link ../logo/#{asset}"
end
```

**Forbidden dependency/error-message pattern** (`brandbook_scaffold_test.exs` lines 191-213):
```elixir
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
```

**Package allowlist pattern** (`brandbook_scaffold_test.exs` lines 215-220 and `mix.exs` lines 22-25):
```elixir
mix_exs = File.read!("mix.exs")

assert mix_exs =~ ~r/files:\s*~w\(lib priv guides mix\.exs README\.md LICENSE CHANGELOG\.md\)/
refute mix_exs =~ ~r/files:.*brandbook/
```

```elixir
package: [
  name: "cairnloop",
  files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md),
```

**System command pattern** (`brandbook_scaffold_test.exs` lines 222-238):
```elixir
{output, exit_code} =
  System.cmd("mix", ["run", "scripts/derive_brandbook_tokens.exs", "--check"],
    stderr_to_stdout: true
  )

assert exit_code == 0, output
```

**E2E source guard pattern** (`responsive_markup_test.exs` lines 131-154):
```elixir
test "inbox_geometry_test.exs exists, is tagged :e2e, and measures rendered geometry" do
  assert File.exists?(@geometry_e2e),
         "the inbox geometry E2E must exist at examples/cairnloop_example/test/e2e/inbox_geometry_test.exs " <>
           "(it is the automated replacement for the former 43-03 human-verify checkpoint)"

  src = File.read!(@geometry_e2e)

  assert src =~ "@moduletag :e2e",
         "inbox_geometry_test.exs must carry @moduletag :e2e so the gated `mix test.e2e` lane picks it up"

  assert src =~ "getBoundingClientRect",
         "inbox_geometry_test.exs must measure rendered geometry (getBoundingClientRect) — a source scan cannot prove pixel sizes"
end
```

**Planner instruction:** create a new DB-free guard rather than expanding browser E2E. Cover README header, approved inventory, all tracked SVG XML/safe-subset checks, raster budget, copied runtime assets, no PNG logo fallbacks, package allowlist, and collateral E2E existence/tag/real-geometry assertions.

---

### `examples/cairnloop_example/test/e2e/collateral_wiring_test.exs` (test, request-response)

**Analog:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`, with request-failure concepts from `scripts/verify_brandbook_file_load.mjs`

**Imports and E2E tag pattern** (`inbox_geometry_test.exs` lines 22-30):
```elixir
The Ecto sandbox is managed by PhoenixTest.Playwright.Case; the dashboard live_session joins it
via CairnloopExampleWeb.LiveAcceptance (test-only on_mount), so the fixture's resolved rows are
visible to the rendered (library-owned) InboxLive at `/support/inbox`.
"""
use PhoenixTest.Playwright.Case,
  async: false,
  browser_context_opts: [viewport: %{width: 768, height: 720}]

@moduletag :e2e
```

**False-pass prevention preconditions** (`inbox_geometry_test.exs` lines 78-83):
```elixir
conn =
  conn
  |> visit("/support/inbox")
  |> assert_has("body .phx-connected")
  |> assert_has(@select_all)
  |> assert_has(@row_checkbox)
```

**Browser evaluate pattern** (`inbox_geometry_test.exs` lines 87-105):
```elixir
evaluate(
  conn,
  """
  (() => {
    const box = (sel) => {
      const b = document.querySelector(sel).getBoundingClientRect();
      return {w: b.width, h: b.height};
    };
    return {all: box('#{@select_all}'), row: box('#{@row_checkbox}')};
  })()
  """,
  fn %{"all" => all, "row" => row} ->
    assert all["w"] >= @min_tap and all["h"] >= @min_tap,
           "select-all checkbox hit area is #{all["w"]}×#{all["h"]}px (need ≥#{@min_tap}×#{@min_tap})"
  end
)
```

**Explicit precondition/error-message pattern** (`inbox_geometry_test.exs` lines 165-177):
```elixir
assert m["scrollHeight"] > m["innerHeight"],
       "inbox list did not overflow the viewport (scrollHeight #{m["scrollHeight"]} ≤ innerHeight #{m["innerHeight"]}) — occlusion test cannot exercise a real scroll"

assert m["lastBottom"] > 0 and m["lastBottom"] <= m["innerHeight"] + @subpixel_tol,
       "last inbox row is not within the viewport (bottom #{m["lastBottom"]}px, innerHeight #{m["innerHeight"]}px) — cannot prove non-occlusion"

assert m["lastBottom"] <= m["barTop"] + @subpixel_tol,
       "last inbox row (bottom #{m["lastBottom"]}px) is occluded by the sticky bulk-bar (top #{m["barTop"]}px)"
```

**Browser failure collection concept** (`scripts/verify_brandbook_file_load.mjs` lines 106-122, 216-223):
```javascript
page.on("console", (message) => {
  if (message.type() === "error") {
    consoleMessages.push(`${viewport.name}: ${message.type()}: ${message.text()}`);
  }
});

page.on("pageerror", (error) => {
  pageErrors.push(`${viewport.name}: ${error.message}`);
});

page.on("requestfailed", (request) => {
  failedRequests.push(`${viewport.name}: ${request.url()} ${request.failure()?.errorText || "request failed"}`);
});
```

```javascript
if (consoleMessages.length) fail(`Console errors:\n${consoleMessages.join("\n")}`);
if (pageErrors.length) fail(`Page errors:\n${pageErrors.join("\n")}`);
if (failedRequests.length) fail(`Failed requests:\n${failedRequests.join("\n")}`);
if (remoteRequests.length) fail(`Remote requests:\n${remoteRequests.join("\n")}`);
if (nonLocalRequests.length) fail(`Non-local requests:\n${nonLocalRequests.join("\n")}`);
```

**Planner instruction:** keep this as one focused E2E module with `@moduletag :e2e`. Assert connected page, accessible logo selector, nonzero rendered box and natural image dimensions, local favicon/OG metadata values, successful fetch status for logo/favicon/OG URLs, and no collateral-caused browser failures where PhoenixTest Playwright exposes the page.

---

### `mix.exs` (config/package, guarded unchanged)

**Analog:** same file and package-boundary guard above

**Package allowlist to preserve** (`mix.exs` lines 22-31):
```elixir
package: [
  name: "cairnloop",
  files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md),
  licenses: ["MIT"],
  links: %{
    "GitHub" => "https://github.com/szTheory/cairnloop",
    "Changelog" => "https://hexdocs.pm/cairnloop/changelog.html"
  },
  maintainers: ["szTheory"]
],
```

**Planner instruction:** do not add `brandbook/`, `logo/`, `scripts/`, or example-app files to the package allowlist. Static tests should assert this exact allowlist and final QA should run `mix hex.build --unpack`.

---

### `examples/cairnloop_example/mix.exs` (config/test alias, guarded unchanged)

**Analog:** same file

**E2E dependency location** (`examples/cairnloop_example/mix.exs` lines 48-53):
```elixir
# Browser E2E for the rail's client-only behaviors (JS expand/collapse, the colocated
# RailDensity localStorage hook, reload-persistence, open-survives-PubSub) that
# Phoenix.LiveViewTest cannot exercise. Scoped to the EXAMPLE APP only (test-only) so the
# published `cairnloop` library keeps its LiveViewTest-only harness — adopters never inherit
# a browser dep. Drives a real Chromium via Playwright from Elixir/ExUnit.
{:phoenix_test_playwright, "~> 0.14", only: :test, runtime: false},
```

**E2E alias pattern** (`examples/cairnloop_example/mix.exs` lines 124-137):
```elixir
# Browser E2E lane. Order matters: `assets.build` runs `compile` FIRST, which is what
# extracts the colocated `RailDensity` hook into _build/.../phoenix-colocated/ before esbuild
# bundles it — build assets before compile and the hook silently never loads.
"test.e2e": [
  "assets.setup",
  "assets.build",
  "ecto.create --quiet",
  "ecto.migrate --quiet",
  reenable_migrate,
  "ecto.migrate --migrations-path #{cairnloop_migrations} --quiet",
  "test --only e2e"
],
```

**Planner instruction:** reuse the existing example-app-only dependency and alias. Do not add Playwright to the root library package.

---

### `.github/workflows/ci.yml` (config/CI, guarded unchanged)

**Analog:** same file

**Package build lane** (`.github/workflows/ci.yml` lines 90-101):
```yaml
- name: Install dependencies
  run: mix deps.get

- name: Credo (strict)
  run: mix credo --strict

- name: Docs (warnings as errors)
  run: mix docs --warnings-as-errors

- name: Package build
  run: mix hex.build
```

**E2E CI lane** (`.github/workflows/ci.yml` lines 224-233):
```yaml
- name: Install Playwright CLI (in assets/) + Chromium
  run: |
    npm --prefix assets ci
    npx --prefix assets playwright install --with-deps chromium

# test.e2e: assets.setup → assets.build (compile FIRST so the colocated RailDensity hook is
# extracted and bundled — else the density tests silently pass-without-testing) → ecto
# create/migrate → test --only e2e.
- name: Run rail E2E suite
  run: PW_TRACE=true mix test.e2e
```

**Planner instruction:** no CI edit is required for Phase 52 unless execution discovers the new tests are not naturally included by existing lanes. Prefer keeping the CI topology unchanged.

## Shared Patterns

### Phoenix Static Assets

**Sources:** `examples/cairnloop_example/lib/cairnloop_example_web.ex`, `endpoint.ex`

**Apply to:** `root.html.heex`, copied favicon/OG/logo assets, E2E static fetch checks.

```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
```

```elixir
plug Plug.Static,
  at: "/",
  from: :cairnloop_example,
  only: CairnloopExampleWeb.static_paths()
```

Use `priv/static/favicon.ico` for `/favicon.ico` and `priv/static/images/*` for `/images/*`. Do not add a Plug, controller, or package asset API.

### DB-Free Source Guards

**Sources:** `test/cairnloop/web/brandbook_scaffold_test.exs`, `test/cairnloop/web/responsive_markup_test.exs`

**Apply to:** root collateral static test.

```elixir
use ExUnit.Case, async: true
```

Keep checks as `File.read!`, `File.exists?`, `Path.wildcard`, `System.cmd`, and string/XML scans. Do not boot Repo, Endpoint, or a Phoenix server from the root static guard.

### Package Boundary

**Sources:** `mix.exs`, `test/cairnloop/web/brandbook_scaffold_test.exs`, Phase 49 summary.

**Apply to:** `mix.exs` guard, final QA evidence.

```elixir
files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md)
```

Phase 49 verification already used `rg -n 'files: ~w\(lib priv guides mix\.exs README\.md LICENSE CHANGELOG\.md\)' mix.exs` and proved `logo/` assets were not wired into package surfaces. Phase 52 should keep that posture and add unpacked-package proof.

### Logo Asset Inventory

**Sources:** `logo/USAGE.md`, Phase 49 summary.

**Apply to:** README logo, copied example logo/favicon/OG assets, static tests.

```markdown
| `cairnloop-lockup-horizontal.svg` | Default public logo for README, docs headers, package surfaces, and broad brand identification. |
| `favicon.svg` | SVG favicon source and small browser icon source. |
| `favicon.ico` | Browser ICO fallback with 16px and 32px entries. |
| `cairnloop-og.png` | 1200x630 OG/social preview raster. |
```

Phase 49 summary lines 113-125 record the prior hygiene gates: `xmllint --noout logo/*.svg`, forbidden SVG reference scan, no live `<text>`, ImageMagick identify, `du -ck logo/*.png logo/*.ico`, package allowlist grep, and no README/example wiring changes.

### Browser E2E Lane

**Sources:** `examples/cairnloop_example/test/test_helper.exs`, `examples/cairnloop_example/mix.exs`, existing E2E modules.

**Apply to:** collateral E2E test.

```elixir
ExUnit.start(exclude: [:e2e])
{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
Application.put_env(:phoenix_test, :base_url, CairnloopExampleWeb.Endpoint.url())
```

```elixir
use PhoenixTest.Playwright.Case, async: false
@moduletag :e2e
```

The new test should live under `examples/cairnloop_example/test/e2e/` and be picked up by `mix test.e2e`.

### Final QA Evidence Shape

**Sources:** Phase 49 summary, Phase 51 summary.

**Apply to:** phase closeout/summary, not as a replacement for failing tests.

Phase summaries record command evidence as short PASS lines, for example Phase 51 lines 90-95:
```markdown
- `mix run scripts/derive_brandbook_tokens.exs --check` - passed.
- `mix run scripts/assemble_brandbook.exs` - passed and wrote `brandbook/index.html`.
- `mix run scripts/assemble_brandbook.exs --check` - passed.
- `mix test test/cairnloop/web/brandbook_scaffold_test.exs` - passed, 10 tests, 0 failures.
```

For Phase 52, record at minimum `mix test`, focused collateral guard, `mix test.e2e`, `xmllint`, `du -ck`, `magick identify`, `mix hex.build --unpack`, and `git diff --stat/name-only`.

## No Analog Found

None. Binary copied assets have exact source files but no meaningful code excerpt; treat them as byte-for-byte copies from `logo/`.

## Metadata

**Analog search scope:** `README.md`, `logo/`, `examples/cairnloop_example/lib`, `examples/cairnloop_example/priv/static`, `examples/cairnloop_example/test/e2e`, `test/cairnloop/web`, `mix.exs`, `examples/cairnloop_example/mix.exs`, `.github/workflows/ci.yml`, Phase 49 and Phase 51 artifacts.

**Files scanned:** 28 local files/artifacts.

**Pattern extraction date:** 2026-06-26
