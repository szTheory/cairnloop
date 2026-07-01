# Phase 52: Collateral Wiring + QA/Validation Sweep - Research

**Researched:** 2026-06-26
**Domain:** Phoenix static collateral wiring, README/logo assets, SVG/raster/package hygiene, gated Playwright E2E
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

### Locked Decisions

### Logo Sign-Off And Phase Entry

- **D-52-01:** Treat logo-family sign-off as the only subjective precondition. Planning may prepare
  the implementation path, but execution must not wire assets unless sign-off is already recorded or
  is recorded before the first collateral edit. After sign-off, all remaining verification is
  automated.
- **D-52-02:** Do not create new human UAT tasks for favicon/logo/metadata rendering. The owner gate
  is about subjective asset approval, not whether implementation worked.

### README Header Treatment

- **D-52-03:** Use a restrained OSS-library README header: first visible line is the approved
  horizontal SVG logo from `logo/cairnloop-lockup-horizontal.svg`, with alt text exactly
  `Cairnloop`; existing badges remain immediately below it.
- **D-52-04:** Remove or demote the current text/emoji H1 (`# Cairnloop 🏔️`) so the README does not
  duplicate the accessible brand name or mix the new mark with the old emoji identity. Keep install
  and guide content close to the top; do not turn the README into a marketing hero.
- **D-52-05:** The README logo path is for GitHub/repo rendering. Because `logo/` remains outside the
  Hex package allowlist, planners must not assume that packaged HexDocs can render that relative
  image unless they deliberately add a separate docs/package-safe strategy in a later phase.

### Example App Metadata And Static Wiring

- **D-52-06:** Use approved collateral only. Copy the approved favicon/OG assets into
  `examples/cairnloop_example/priv/static` as needed and reference them with Phoenix static paths
  from `root.html.heex`; do not serve library-owned branding assets from a new Plug or package
  surface.
- **D-52-07:** Keep the example app branded as a credible Cairnloop demo surface, not as a standalone
  SaaS product. Recommended document title posture: `Cairnloop` or `Cairnloop Example`, without the
  generated Phoenix suffix. Avoid exposing implementation trivia in browser chrome.
- **D-52-08:** Root metadata must use the approved copy from the UI spec:
  `og:title` = `Cairnloop`, `og:description` = `Embedded support automation for Phoenix apps.`,
  `og:type` = `website`, `og:image` points to the local copied `cairnloop-og.png`, and
  `og:image:alt` = `Cairnloop — Support that leaves a trail.` exactly as specified.
- **D-52-09:** Replace only the existing example static logo file and metadata/static references
  needed for this phase. Do not rework the example app header/navigation beyond making the approved
  logo render without distortion, clipping, cage, or low-contrast background.

### QA Gate Shape

- **D-52-10:** Use a hybrid gate. Put deterministic source/package/asset rules in fast ExUnit tests
  under the normal `mix test` lane; put browser-only static-path/rendering facts in one focused
  `examples/cairnloop_example/test/e2e/*_test.exs` module using
  `PhoenixTest.Playwright.Case` and `@moduletag :e2e`.
- **D-52-11:** Static tests should cover at minimum: README starts with a repo-relative approved SVG
  path and `alt="Cairnloop"`; approved logo inventory exists; SVGs are well-formed with `xmlns` and
  valid `viewBox`; SVGs contain no `<image>`, script, `foreignObject`, external/data hrefs, embedded
  raster, or editor metadata; `du -ck logo/*.png logo/*.ico` plus copied raster outputs stays within
  the 150KB budget; no PNG logo fallbacks are introduced; `mix.exs` package `files` remains
  `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`; `brandbook/`, `logo/`, and `scripts/`
  remain unshipped.
- **D-52-12:** E2E must prove real browser behavior, not just source strings: page loads with the
  new logo visible and nonzero natural dimensions; favicon link(s) resolve to local static paths;
  OG image/title/description/type/image-alt meta tags exist; copied static asset URLs return
  successful responses; no collateral-caused console/page/request failures occur.
- **D-52-13:** Avoid false-pass tests. Browser assertions must include preconditions such as
  connected page, selector exists, bounding boxes/natural sizes are nonzero, and asset URL fetches
  succeeded. Static checks should prefer structured/XML parsing where practical and use explicit
  failure messages naming the path and next action.
- **D-52-14:** A final QA report or phase summary should include command evidence (`mix test`,
  `mix test.e2e`, SVG/raster/package/diff checks), but the report is evidence, not the gate. Tests
  and scripts must fail before the report can claim pass.

### Design, Accessibility, And DX Posture

- **D-52-15:** Use the brandbook's restrained operator-grade direction: calm, precise, OSS-native,
  no launch-copy, no AI-agent hype, no chat-bubble/headset/robot tropes, no decorative overuse of
  copper, and no new visual motifs.
- **D-52-16:** Accessibility semantics are simple: the sole README logo image and the example app
  logo image use `alt="Cairnloop"`; redundant duplicate logos near visible `Cairnloop` text may be
  decorative, but do not make the only brand identifier decorative. Favicon has no alt; OG metadata
  uses `og:image:alt`.
- **D-52-17:** Preserve developer ergonomics. Use idiomatic Phoenix `priv/static` assets and
  verified/static paths already available in the example app. Do not add dependencies, global build
  tooling, runtime asset services, or a custom branded asset delivery API for this phase.

### the agent's Discretion

Planner/executor may choose exact filenames for copied example-app assets, the exact ExUnit module
boundary, whether to extend existing brandbook source guards or create a Phase 52-specific test
module, and exact Playwright selectors. Keep the write set narrow, failure messages actionable, and
assertions tied directly to Phase 52 requirements.

### Deferred Ideas (OUT OF SCOPE)

- A full marketing landing page, broader public docs homepage, or screenshot-led launch treatment
  belongs in a later phase.
- Shipping brand assets from the library package, a reusable branded asset Plug, or a HexDocs-safe
  packaged logo strategy is deferred unless package policy changes.
- Full PWA/apple-touch/android icon pack remains out of scope.
- Brandbook public hosting or Phoenix routing remains out of scope.

## Summary

Phase 52 should wire the already-approved Phase 49 logo family into four committed surfaces: the README header, example app static logo, example app favicon, and example app OG metadata. The current repo still has `README.md` beginning with `# Cairnloop 🏔️`, `examples/cairnloop_example/priv/static/images/logo.svg` using the placeholder `viewBox="0 0 71 48"`, `examples/cairnloop_example/priv/static/favicon.ico` identifying as a stock 64x64 PNG-like icon, and `root.html.heex` using the generated title `CairnloopExample · Phoenix Framework` with no favicon or OG metadata. [VERIFIED: codebase grep] [VERIFIED: local `file` and `rg` probes]

The implementation should not add dependencies or a new asset pipeline. Use the committed `logo/cairnloop-lockup-horizontal.svg`, `logo/favicon.svg`, `logo/favicon-16.png`, `logo/favicon-32.png`, `logo/favicon.ico`, and `logo/cairnloop-og.png`; copy only the browser-facing assets that the example app must serve from `priv/static`; reference them with Phoenix `~p` static paths in HEEx. Phoenix VerifiedRoutes supports configured static directories through `:statics`, and Phoenix Endpoint static helpers generate routes to files in `priv/static`. [VERIFIED: logo/USAGE.md] [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html] [CITED: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html]

The QA sweep should be layered: DB-free ExUnit for README/source/package/SVG/raster checks under `mix test`, and one focused `PhoenixTest.Playwright.Case` module under `examples/cairnloop_example/test/e2e/` for browser-only proof. The existing project already has this split: `test/cairnloop/web/brandbook_scaffold_test.exs` is the closest static guard pattern, and the example app already has `mix test.e2e`, PhoenixTest Playwright 0.14.0, Playwright 1.60.0, and CI support. [VERIFIED: codebase grep] [VERIFIED: mix.lock and package-lock.json]

**Primary recommendation:** Plan one static QA guard plus one collateral E2E, then wire only README, example static files, `root.html.heex`, and the existing app logo markup in `layouts.ex`; do not alter logo geometry, package files, CI topology, or add human-verify tasks. [VERIFIED: 52-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| README logo header | Static / Repository Collateral | — | GitHub renders `README.md` and supports relative image paths in rendered repository files. [CITED: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes] |
| Example static logo, favicon, OG image | CDN / Static | Frontend Server (Phoenix Endpoint) | Files belong under `examples/cairnloop_example/priv/static`; `Plug.Static` serves configured static paths. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex] |
| Root document title and metadata | Frontend Server (Phoenix HEEx root layout) | Browser / Client | `root.html.heex` owns `<head>` tags and can reference static assets with `~p`. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex] |
| Rendered behavior validation | Browser / Client | API / Backend for E2E server lifecycle | Logo dimensions, favicon links, metadata, console errors, and static asset fetches need a real browser. [VERIFIED: existing e2e tests] |
| SVG/raster/package hygiene | Static / Build Tooling | — | These checks read committed files and `mix.exs`; no DB, Endpoint, or browser is needed. [VERIFIED: test/cairnloop/web/brandbook_scaffold_test.exs] |
| Package boundary | Build / Release Tooling | Static / Repository Collateral | Hex package inclusion is governed by `mix.exs` package `:files`; `mix hex.build --unpack` can inspect contents. [CITED: https://hex.pm/docs/publish] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WIRE-01 | Replace example placeholder logo and update favicon + `og:image` metadata in example root layout. | Use approved `logo/*` assets; update `priv/static/images/logo.svg`, `priv/static/favicon.ico`, copy `cairnloop-og.png`, and edit `root.html.heex`. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: codebase grep] |
| WIRE-02 | `README.md` leads with chosen SVG logo header using a repo-relative GitHub-renderable path. | GitHub docs support relative image paths; current README starts with text/emoji H1 and should be changed to an image header with `alt="Cairnloop"`. [CITED: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes] [VERIFIED: README.md] |
| WIRE-03 | Rendered logo + favicon behavior is covered by gated Playwright E2E, not human verify. | Example app already has `PhoenixTest.Playwright.Case` E2E modules and `mix test.e2e`; new collateral E2E should follow those patterns. [VERIFIED: examples/cairnloop_example/test/e2e] |
| HYGIENE-01 | Every committed SVG is valid, has valid `viewBox`, and avoids external refs/raster/editor cruft. | `xmllint --noout $(git ls-files '*.svg')` currently passes, and forbidden scan found no image/script/foreignObject/external/data/editor metadata in tracked SVGs. [VERIFIED: local command] |
| HYGIENE-02 | Raster footprint stays <=~150KB, only favicon + OG raster, no logo PNG fallbacks, rejected directions deleted. | Tracked raster set for Phase 49 is only favicon PNG/ICO and OG PNG; `logo/_contest` is absent; current `du -ck logo/*.png logo/*.ico examples/.../favicon.ico` was 72KB before Phase 52 copies. [VERIFIED: local command] |
| HYGIENE-03 | `brandbook/` is excluded from Hex package; QA records repo-size delta and diff scope. | `mix.exs` package files are `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`; `mix hex.build --unpack` output did not include `brandbook/`, `logo/`, or `scripts/`. [VERIFIED: mix.exs] [VERIFIED: local `mix hex.build --unpack`] |

## Project Constraints (from CLAUDE.md and AGENTS.md)

- Make reasonable technical decisions without asking the owner unless the decision is very impactful; Phase 52 already locks the only owner gate as logo-family sign-off before wiring. [VERIFIED: CLAUDE.md] [VERIFIED: 52-CONTEXT.md]
- Builds must be warnings-clean, and completed work must run `mix test`; example app work should use `mix precommit` when appropriate. [VERIFIED: CLAUDE.md] [VERIFIED: examples/cairnloop_example/AGENTS.md]
- Prefer headless/pure tests where possible because `Cairnloop.Repo` can be unavailable; Phase 52 static QA should remain DB-free, while E2E can use the example app sandbox because the existing lane already does. [VERIFIED: CLAUDE.md] [VERIFIED: examples/cairnloop_example/test/e2e]
- Use Phoenix v1.8 HEEx conventions: root layout changes stay in `.html.heex`, use `~p` static paths, avoid inline custom scripts beyond existing generated root script unless required, and use existing components/patterns. [VERIFIED: examples/cairnloop_example/AGENTS.md]
- Use Tailwind classes and existing Phoenix example app shell conventions for any necessary layout/logo markup; do not initialize shadcn, React, or a new design system. [VERIFIED: examples/cairnloop_example/AGENTS.md] [VERIFIED: 52-UI-SPEC.md]
- Operator-facing copy should be calm, fail-closed, reason-forward, and not state-by-color-alone. [VERIFIED: CLAUDE.md] [VERIFIED: 52-UI-SPEC.md]
- Use brand tokens rather than hardcoded hex when editing UI/CSS; this phase should mostly avoid new CSS and use committed SVG colors as assets. [VERIFIED: CLAUDE.md] [VERIFIED: logo/USAGE.md]

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Phoenix static assets + VerifiedRoutes | Phoenix 1.8.7 locked locally; docs opened at 1.8.8 | Reference example app favicon, logo, and OG image with `~p` paths from HEEx. | Existing example app uses `CairnloopExampleWeb.static_paths()` with `assets fonts images favicon.ico robots.txt`, and Phoenix docs support verified static paths via `:statics`. [VERIFIED: examples/cairnloop_example/mix.lock] [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html] |
| Phoenix Endpoint / Plug.Static | Phoenix 1.8.7 locked locally | Serve copied files from `examples/cairnloop_example/priv/static`. | The endpoint already serves `priv/static` at `/` through `Plug.Static` using `CairnloopExampleWeb.static_paths()`. [VERIFIED: endpoint.ex] [CITED: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html] |
| PhoenixTest Playwright | 0.14.0 locked in example app | Real-browser E2E for logo visibility, favicon links, metadata, asset fetches, and console/request failures. | Existing E2E modules use `PhoenixTest.Playwright.Case`; docs state it runs PhoenixTest cases in a real browser and exposes `evaluate`. [VERIFIED: examples/cairnloop_example/mix.lock] [CITED: https://hexdocs.pm/phoenix_test_playwright/PhoenixTest.Playwright.html] |
| Playwright | 1.60.0 in example app assets | Browser engine and page-level checks. | Existing CI installs Chromium; local `assets/node_modules/.bin/playwright --version` reports 1.60.0. [VERIFIED: examples/cairnloop_example/assets/package-lock.json] |
| ExUnit + Mix | Mix/Elixir 1.19.5 local | DB-free static QA and phase gate commands. | Root project is Elixir 1.19 and existing static tests are ExUnit file scans. [VERIFIED: local `mix --version`] [VERIFIED: test/cairnloop/web/brandbook_scaffold_test.exs] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `xmllint` | libxml 2.9.13 local | Well-formed XML validation for all tracked SVG files. | Run inside static ExUnit via `System.cmd/3` or as explicit phase evidence. [VERIFIED: local `xmllint --version`] |
| ImageMagick `magick identify` | 7.1.1-44 local | Verify PNG/ICO dimensions and catch incorrect copied favicon/OG assets. | Run after copying favicon/OG assets and in final QA evidence. [VERIFIED: local `magick -version`] |
| `du -ck` | system tool | Enforce <=150KB raster budget. | Include `logo/*.png`, `logo/*.ico`, and copied example app raster outputs. [VERIFIED: 52-CONTEXT.md] |
| `mix hex.build --unpack` | Hex task available locally | Inspect package contents and prove `brandbook/`, `logo/`, and `scripts/` remain unshipped. | Use after package allowlist assertions before final summary. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] [VERIFIED: local command] |
| `git diff --stat` / `git diff --name-only` | git local | Prove write set is confined to intended files. | Use as final QA evidence; static tests can assert source/package facts, but diff scope is best recorded from git. [VERIFIED: 52-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `~p"/images/cairnloop-og.png"` | Handwritten `"/images/cairnloop-og.png"` | `~p` gets compile-time static path verification for configured static directories; handwritten paths can drift silently. [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html] |
| `PhoenixTest.Playwright.Case` | Source-only HEEx assertions | Source checks cannot prove natural image dimensions, real favicon link resolution, metadata fetches, or browser console/request failures. [VERIFIED: 52-CONTEXT.md] |
| `mix hex.build --unpack` | Regex-only `mix.exs` check | Regex confirms policy text; unpacked build proves package output. Use both. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
| ImageMagick dimension checks | Trust file names | Phase 49 already had renderer-specific raster issues; dimensions and type should be checked from actual files. [VERIFIED: 49-02-SUMMARY.md] |

**Installation:**
```bash
# No new dependencies. Reuse existing root and example app deps. [VERIFIED: 52-CONTEXT.md]
mix deps.get
cd examples/cairnloop_example && mix deps.get && npm --prefix assets ci
```

## Package Legitimacy Audit

No new external packages should be installed for Phase 52. [VERIFIED: 52-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | OK | No package install planned. [VERIFIED: 52-CONTEXT.md] |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

Existing `phoenix_test_playwright` is already locked in the example app at 0.14.0, so the planner should reuse it rather than running a new legitimacy/install gate. [VERIFIED: examples/cairnloop_example/mix.lock]

## Architecture Patterns

### System Architecture Diagram

```text
Approved Phase 49 assets in logo/
  |-- cairnloop-lockup-horizontal.svg
  |-- favicon.svg / favicon-16.png / favicon-32.png / favicon.ico
  `-- cairnloop-og.png / cairnloop-og.svg
        |
        v
Phase 52 wiring decisions
  |-- README.md first visible line -> repo-relative SVG image
  |-- example priv/static/images/logo.svg -> approved SVG geometry
  |-- example priv/static/favicon.ico -> approved favicon.ico
  |-- example priv/static/images/cairnloop-og.png -> approved OG PNG copy
  `-- root.html.heex -> title + favicon + OG tags via ~p static paths
        |
        v
Validation gates
  |-- root mix test -> DB-free README/SVG/raster/package/source guards
  |-- example mix test.e2e -> browser logo/favicon/metadata/static fetch proof
  |-- mix hex.build --unpack -> package boundary proof
  `-- git diff --stat/name-only -> intended write-set proof
        |
        v
Phase close evidence: no human-verify tasks outstanding
```

### Recommended Project Structure

```text
README.md
logo/
├── cairnloop-lockup-horizontal.svg      # README and example logo source [VERIFIED: logo/USAGE.md]
├── favicon.svg / favicon-16.png / favicon-32.png / favicon.ico
└── cairnloop-og.svg / cairnloop-og.png
examples/cairnloop_example/
├── priv/static/favicon.ico              # copied approved browser favicon [VERIFIED: 52-UI-SPEC.md]
├── priv/static/images/logo.svg          # replaced approved logo SVG [VERIFIED: 52-UI-SPEC.md]
├── priv/static/images/cairnloop-og.png  # copied approved OG raster [VERIFIED: 52-UI-SPEC.md]
├── lib/cairnloop_example_web/components/layouts/root.html.heex
├── lib/cairnloop_example_web/components/layouts.ex
└── test/e2e/collateral_wiring_test.exs  # new browser proof [VERIFIED: 52-CONTEXT.md]
test/cairnloop/web/
└── collateral_wiring_test.exs           # recommended new DB-free guard [VERIFIED: existing test patterns]
```

### Pattern 1: DB-Free Static Collateral Guard

**What:** Use ExUnit to read files, parse/validate SVGs with `xmllint`, scan forbidden SVG constructs, check README header, package allowlist, raster budget, and copied asset dimensions. [VERIFIED: test/cairnloop/web/brandbook_scaffold_test.exs]

**When to use:** Every Phase 52 fact that can be proven from committed files without booting Phoenix. [VERIFIED: 52-CONTEXT.md]

**Example:**
```elixir
# Source: test/cairnloop/web/brandbook_scaffold_test.exs pattern [VERIFIED: codebase grep]
defmodule Cairnloop.Web.CollateralWiringTest do
  use ExUnit.Case, async: true

  @svg_files System.cmd("git", ["ls-files", "*.svg"]) |> elem(0) |> String.split("\n", trim: true)

  test "tracked SVG files are well formed and avoid unsafe constructs" do
    {output, code} = System.cmd("xmllint", ["--noout" | @svg_files], stderr_to_stdout: true)
    assert code == 0, output

    forbidden = ~r/(<image|<script|<foreignObject|href="https?:|href="data:|xlink:href|data:image|base64|<metadata|sodipodi:|inkscape:)/i

    violations =
      for path <- @svg_files,
          {line, no} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(forbidden, line),
          do: "#{path}:#{no}: #{String.trim(line)}"

    assert violations == [], "Forbidden SVG content:\n#{Enum.join(violations, "\n")}"
  end
end
```

### Pattern 2: Browser-Only Collateral Proof

**What:** Add one `PhoenixTest.Playwright.Case` module with `@moduletag :e2e`; assert page connection, visible logo selector, nonzero bounding box, image natural dimensions, favicon link(s), OG meta tags, and static URL fetch status. [VERIFIED: examples/cairnloop_example/test/e2e] [CITED: https://hexdocs.pm/phoenix_test_playwright/PhoenixTest.Playwright.html]

**When to use:** Logo/favicon/metadata behavior that can false-pass in source tests. [VERIFIED: 52-CONTEXT.md]

**Example:**
```elixir
# Source: PhoenixTest.Playwright docs + existing E2E style [CITED: https://hexdocs.pm/phoenix_test_playwright/PhoenixTest.Playwright.html]
defmodule CairnloopExampleWeb.CollateralWiringE2ETest do
  use PhoenixTest.Playwright.Case, async: false

  @moduletag :e2e

  test "example app renders Cairnloop logo, favicon, and OG metadata", %{conn: conn} do
    conn =
      conn
      |> visit("/")
      |> assert_has("body .phx-connected")
      |> assert_has("img[alt='Cairnloop']")

    evaluate(conn, """
    (() => {
      const logo = document.querySelector("img[alt='Cairnloop']");
      const box = logo.getBoundingClientRect();
      const favicon = document.querySelector("link[rel~='icon']");
      const meta = (name) => document.querySelector(`meta[property="${name}"]`)?.content;

      return {
        logoComplete: logo.complete,
        logoNaturalWidth: logo.naturalWidth,
        logoNaturalHeight: logo.naturalHeight,
        logoWidth: box.width,
        logoHeight: box.height,
        faviconHref: favicon && new URL(favicon.getAttribute("href"), location.href).pathname,
        ogTitle: meta("og:title"),
        ogDescription: meta("og:description"),
        ogType: meta("og:type"),
        ogImage: meta("og:image"),
        ogImageAlt: meta("og:image:alt")
      };
    })()
    """, fn state ->
      assert state["logoComplete"] and state["logoNaturalWidth"] > 0
      assert state["logoWidth"] > 0 and state["logoHeight"] > 0
      assert state["faviconHref"] in ["/favicon.ico", "/images/favicon.svg", "/images/favicon-32.png"]
      assert state["ogTitle"] == "Cairnloop"
      assert state["ogDescription"] == "Embedded support automation for Phoenix apps."
      assert state["ogType"] == "website"
      assert state["ogImage"] =~ "/images/cairnloop-og.png"
      assert state["ogImageAlt"] == "Cairnloop — Support that leaves a trail."
    end)
  end
end
```

### Pattern 3: Package Boundary Proof

**What:** Assert `mix.exs` package files stay exact, then run `mix hex.build --unpack` and scan the unpacked directory for forbidden `brandbook/`, `logo/`, and `scripts/` entries. [VERIFIED: mix.exs] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]

**When to use:** HYGIENE-03 final gate and release confidence. [VERIFIED: .planning/REQUIREMENTS.md]

### Anti-Patterns to Avoid

- **Human-verifying rendered behavior:** Phase 52 explicitly requires gated Playwright E2E for browser facts. [VERIFIED: 52-CONTEXT.md]
- **Adding a branded asset Plug/API:** Static `priv/static` files already solve the example app use case. [VERIFIED: endpoint.ex]
- **Shipping `logo/` or `brandbook/` through Hex:** `logo/` is for repo/GitHub collateral and is intentionally outside package files. [VERIFIED: 52-CONTEXT.md]
- **Using PNG logo fallbacks:** Raster is allowed for favicon and OG only; logos remain SVG-first. [VERIFIED: .planning/REQUIREMENTS.md]
- **Changing logo geometry or brandbook content:** Phase 52 is wiring and QA only. [VERIFIED: 52-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SVG XML validity | Custom XML parser | `xmllint --noout` | Existing system tool validates well-formed XML reliably. [VERIFIED: local tool probe] |
| Browser rendering checks | Human screenshot/UAT checklist | `PhoenixTest.Playwright.Case` + `evaluate` | Existing policy and E2E harness automate browser-required facts. [VERIFIED: STATE.md] [CITED: https://hexdocs.pm/phoenix_test_playwright/PhoenixTest.Playwright.html] |
| Static path generation | Handwritten absolute URLs | Phoenix `~p` static paths | Phoenix verifies configured static paths at compile time. [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html] |
| Raster metadata/dimensions | Filename conventions | `magick identify` | Actual files can drift from names; Phase 49 already caught renderer-specific raster behavior. [VERIFIED: 49-02-SUMMARY.md] |
| Package contents | Mental model of `mix.exs` | `mix hex.build --unpack` | Hex docs recommend unpacking to inspect package contents before publishing. [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |
| Diff-scope QA | Manual file list in prose | `git diff --stat` and `git diff --name-only` | HYGIENE-03 asks for a diff report, and git is the source of truth for changed files. [VERIFIED: .planning/REQUIREMENTS.md] |

**Key insight:** Phase 52 is not asset creation; it is trust-building through narrow wiring plus automated proof. The highest-risk failures are false passes: source strings that look correct while the browser fails to load the file, package regexes that pass while tarball contents drift, and SVG checks that skip dangerous embedded references. [VERIFIED: 52-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: README Works On GitHub But Not HexDocs

**What goes wrong:** `README.md` uses `logo/cairnloop-lockup-horizontal.svg`, which GitHub can transform as a repo-relative image path, but `logo/` is not in the Hex package. [CITED: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes] [VERIFIED: mix.exs]

**Why it happens:** GitHub renders from the repository checkout, while HexDocs renders from package/doc artifacts. [VERIFIED: 52-CONTEXT.md]

**How to avoid:** Keep Phase 52 README image repo-relative for GitHub and do not claim packaged HexDocs logo rendering unless a later phase changes package/docs asset policy. [VERIFIED: 52-CONTEXT.md]

**Warning signs:** Tests that assert only `README.md =~ "logo/cairnloop-lockup-horizontal.svg"` but do not assert package exclusion and do not document the HexDocs limitation. [VERIFIED: 52-CONTEXT.md]

### Pitfall 2: Source Metadata Tags Pass While Static URLs 404

**What goes wrong:** `root.html.heex` contains `og:image`, but the referenced file is not under a served static path or was copied to the wrong directory. [VERIFIED: endpoint.ex]

**Why it happens:** The example app serves only `assets fonts images favicon.ico robots.txt`. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web.ex]

**How to avoid:** Put OG assets under `priv/static/images/` and use `~p"/images/cairnloop-og.png"`; keep root favicon at `priv/static/favicon.ico` or add explicit served path if using `images/favicon.svg`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html]

**Warning signs:** `~p` compile warnings or E2E `fetch()` status failures for copied asset URLs. [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html]

### Pitfall 3: The Visible App Logo Markup Still Has Placeholder Semantics

**What goes wrong:** The SVG file is replaced, but `layouts.ex` still renders a tiny stock image with no `alt`, next to Phoenix version text and Phoenix links. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex]

**Why it happens:** The requirement names the static file and root layout, but the visible logo is rendered from `layouts.ex`. [VERIFIED: codebase grep]

**How to avoid:** Include `layouts.ex` in the write set for minimal semantic cleanup: `img src={~p"/images/logo.svg"} alt="Cairnloop"` and remove or demote generated Phoenix brand trivia where necessary. [VERIFIED: 52-UI-SPEC.md]

**Warning signs:** E2E can find `/images/logo.svg` but cannot find an accessible logo name. [VERIFIED: 52-UI-SPEC.md]

### Pitfall 4: SVG Hygiene Only Checks `logo/`

**What goes wrong:** The QA gate passes `logo/*.svg` while `examples/cairnloop_example/priv/static/images/logo.svg` or other tracked SVGs remain unsafe or invalid. [VERIFIED: local `git ls-files '*.svg'`]

**Why it happens:** Earlier phase commands scoped to Phase 49 assets; Phase 52 requires every committed SVG. [VERIFIED: .planning/REQUIREMENTS.md]

**How to avoid:** Build SVG file list with `git ls-files '*.svg'`, then check XML, `xmlns`, four-number positive `viewBox`, and forbidden references across all tracked SVGs. [VERIFIED: local command]

**Warning signs:** Test fixtures hardcode `logo/*.svg` only. [VERIFIED: 52-CONTEXT.md]

### Pitfall 5: Raster Budget Double Counts Or Under Counts

**What goes wrong:** Copied example app favicon/OG files push the total over budget, or checks ignore copied outputs. [VERIFIED: 52-CONTEXT.md]

**Why it happens:** Phase 49 budget was scoped to `logo/*.png logo/*.ico`; Phase 52 adds copied runtime files. [VERIFIED: 49-02-SUMMARY.md] [VERIFIED: 52-CONTEXT.md]

**How to avoid:** Count source and copied outputs explicitly, e.g. `du -ck logo/*.png logo/*.ico examples/cairnloop_example/priv/static/favicon.ico examples/cairnloop_example/priv/static/images/cairnloop-og.png`. [VERIFIED: 52-CONTEXT.md]

**Warning signs:** `du` command omits `examples/cairnloop_example/priv/static`. [VERIFIED: 52-CONTEXT.md]

### Pitfall 6: Request Failure Monitoring Is Too Narrow

**What goes wrong:** E2E asserts the logo element exists but ignores console errors, page errors, failed requests, and HTTP status for static assets. [VERIFIED: scripts/verify_brandbook_file_load.mjs]

**Why it happens:** A browser can render fallback UI or cached DOM while an asset request fails. [CITED: https://playwright.dev/docs/api/class-page]

**How to avoid:** In E2E, use `evaluate` to fetch or inspect asset URLs and, where possible with PhoenixTest Playwright `unwrap`, subscribe to Playwright page events; at minimum assert `fetch(url).status` for logo/favicon/OG. [CITED: https://playwright.dev/docs/evaluating] [VERIFIED: existing E2E patterns]

**Warning signs:** E2E has no preconditions for `body .phx-connected`, selector count, image completion, or nonzero natural dimensions. [VERIFIED: examples/cairnloop_example/test/e2e/inbox_geometry_test.exs]

## Code Examples

Verified patterns from official and local sources:

### Root Layout Static Metadata

```heex
<%!-- Source: Phoenix VerifiedRoutes static path docs and existing root layout [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html] [VERIFIED: root.html.heex] --%>
<.live_title default="Cairnloop" phx-no-format>{assigns[:page_title]}</.live_title>
<link rel="icon" href={~p"/favicon.ico"} />
<link rel="icon" type="image/svg+xml" href={~p"/images/favicon.svg"} />
<meta property="og:title" content="Cairnloop" />
<meta property="og:description" content="Embedded support automation for Phoenix apps." />
<meta property="og:type" content="website" />
<meta property="og:image" content={url(~p"/images/cairnloop-og.png")} />
<meta property="og:image:alt" content="Cairnloop — Support that leaves a trail." />
```

### README Header Shape

```markdown
<!-- Source: 52-CONTEXT.md and GitHub README relative image docs [VERIFIED: 52-CONTEXT.md] [CITED: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes] -->
<img src="logo/cairnloop-lockup-horizontal.svg" alt="Cairnloop" width="260">

[![Hex.pm Version](https://img.shields.io/hexpm/v/cairnloop.svg)](https://hex.pm/packages/cairnloop)
```

### Raster Budget Command

```bash
# Source: 52-CONTEXT.md and local Phase 49 command pattern [VERIFIED: 52-CONTEXT.md]
du -ck \
  logo/*.png \
  logo/*.ico \
  examples/cairnloop_example/priv/static/favicon.ico \
  examples/cairnloop_example/priv/static/images/cairnloop-og.png
```

### Package Boundary Command

```bash
# Source: Hex publish docs and local successful command [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] [VERIFIED: local command]
mix hex.build --unpack
test ! -e cairnloop-0.5.1/brandbook
test ! -e cairnloop-0.5.1/logo
test ! -e cairnloop-0.5.1/scripts
rm -rf cairnloop-0.5.1
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual/human rendered checks | Gated Playwright E2E for browser-required facts | Project policy recorded before Phase 52 | Planner must not create human-verify tasks for logo/favicon/metadata rendering. [VERIFIED: STATE.md] |
| Stock Phoenix example branding | Cairnloop demo surface with approved collateral | Phase 52 scope | Replace placeholder static logo/favicon/title/metadata without redesigning the whole app. [VERIFIED: 52-UI-SPEC.md] |
| Phase 49 asset-scoped hygiene | All committed SVG/raster/package hygiene | Phase 52 scope | Expand checks from `logo/` to `git ls-files '*.svg'` and copied runtime rasters. [VERIFIED: .planning/REQUIREMENTS.md] |
| Package allowlist by memory | Package allowlist plus unpacked build proof | Existing quality lane uses `mix hex.build` | HYGIENE-03 should prove package output, not only source policy. [VERIFIED: .github/workflows/ci.yml] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html] |

**Deprecated/outdated:**
- Human UAT for rendered logo/favicon behavior is out of date for this project; browser facts are automated. [VERIFIED: STATE.md]
- The generated Phoenix suffix ` · Phoenix Framework` in the example app title conflicts with Phase 52's title posture. [VERIFIED: root.html.heex] [VERIFIED: 52-CONTEXT.md]
- The stock Phoenix 64x64 favicon and `viewBox="0 0 71 48"` logo are placeholders to replace. [VERIFIED: local `file` and `rg` probes]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub's current SVG sanitizer behavior for README internals is not documented in the official README-relative-path docs; local SVG hygiene is the planned proxy for "SVG sanitization validated." [ASSUMED] | Pitfalls / Validation | If GitHub changes sanitizer behavior or blocks SVG image rendering, a repo-local check may pass while GitHub display fails. |

## Open Questions (RESOLVED)

1. **RESOLVED: Is logo-family sign-off already recorded before execution starts?**
   - What we know: Phase 52 context says sign-off is the only subjective precondition and execution must not wire collateral until it is recorded. [VERIFIED: 52-CONTEXT.md]
   - What's unclear: This research did not find a completed Phase 52 sign-off artifact; it found the sign-off requirement and discussion choice. [VERIFIED: codebase grep]
   - Resolution: `52-01-PLAN.md` Task 1 records or verifies logo-family sign-off before any collateral file edit, then keeps all later verification automated. [VERIFIED: 52-CONTEXT.md]

2. **RESOLVED: Should the example root include only `favicon.ico`, or also SVG/PNG favicon links?**
   - What we know: `static_paths` already serves root `favicon.ico` and `images`; approved assets include SVG, 16 PNG, 32 PNG, and ICO. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web.ex] [VERIFIED: logo/USAGE.md]
   - What's unclear: The UI spec permits optional favicon PNG/SVG copies as needed; it does not force a full favicon pack. [VERIFIED: 52-UI-SPEC.md]
   - Resolution: `52-02-PLAN.md` Task 1 uses root `favicon.ico` plus `images/favicon.svg`, and does not add apple-touch/PWA icons. [VERIFIED: 52-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | root tests, package build | ✓ | Elixir/Mix 1.19.5 | — [VERIFIED: local command] |
| Node/npm | example app assets and Playwright install | ✓ | Node 22.14.0, npm 11.1.0 | CI also installs Node 22. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| Playwright Node package | `mix test.e2e` browser automation | ✓ | 1.60.0 | Run `npm --prefix examples/cairnloop_example/assets ci` if missing. [VERIFIED: local command] |
| PostgreSQL | example app E2E DB setup | ✓ | `pg_isready` accepting on `/tmp:5432` | Docker pgvector service in CI. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| Docker | CI-parity DB fallback | ✓ | Docker client 29.5.2 | Use local Postgres if Docker unavailable. [VERIFIED: local command] |
| `xmllint` | SVG XML validity | ✓ | libxml 2.9.13 | ExUnit can fail with install guidance if missing. [VERIFIED: local command] |
| ImageMagick `magick` | raster dimensions | ✓ | 7.1.1-44 | `file` can partially verify type/dimensions, but use ImageMagick when available. [VERIFIED: local command] |
| Hex build task | package boundary proof | ✓ | Hex task available via `mix hex.build --unpack` | Regex package allowlist is a weaker fallback. [VERIFIED: local command] |

**Missing dependencies with no fallback:** none found. [VERIFIED: local command]

**Missing dependencies with fallback:** none blocking. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit for source/package/SVG/raster guards; PhoenixTest Playwright 0.14.0 for browser E2E. [VERIFIED: mix.lock] |
| Config file | Root `mix.exs`; example `examples/cairnloop_example/mix.exs`; example `test/test_helper.exs` excludes `:e2e` by default. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/cairnloop/web/collateral_wiring_test.exs` after creating the static guard. [VERIFIED: existing ExUnit pattern] |
| Full suite command | `mix test && (cd examples/cairnloop_example && PW_TRACE=true mix test.e2e)` plus `mix hex.build --unpack` package proof. [VERIFIED: 52-CONTEXT.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WIRE-01 | Example static logo replaced; favicon and OG files copied/wired in root layout. | unit/source + e2e | `mix test test/cairnloop/web/collateral_wiring_test.exs && (cd examples/cairnloop_example && mix test.e2e test/e2e/collateral_wiring_test.exs)` | ❌ Wave 0 |
| WIRE-02 | README begins with repo-relative approved SVG path and `alt="Cairnloop"`. | unit/source | `mix test test/cairnloop/web/collateral_wiring_test.exs` | ❌ Wave 0 |
| WIRE-03 | Browser proves logo, favicon, and metadata render/resolve. | e2e | `cd examples/cairnloop_example && PW_TRACE=true mix test.e2e test/e2e/collateral_wiring_test.exs` | ❌ Wave 0 |
| HYGIENE-01 | All committed SVGs are XML-valid and safe subset. | unit/source + system tool | `mix test test/cairnloop/web/collateral_wiring_test.exs` | ❌ Wave 0 |
| HYGIENE-02 | Raster footprint <=150KB; only favicon/OG rasters; no logo PNG fallbacks; rejected directions absent. | unit/source + system tool | `mix test test/cairnloop/web/collateral_wiring_test.exs` | ❌ Wave 0 |
| HYGIENE-03 | Package files exclude `brandbook/`, `logo/`, `scripts/`; diff scope recorded. | unit/source + package build + git evidence | `mix test test/cairnloop/web/collateral_wiring_test.exs && mix hex.build --unpack && git diff --stat` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/cairnloop/web/collateral_wiring_test.exs` for static changes; `cd examples/cairnloop_example && mix test.e2e test/e2e/collateral_wiring_test.exs` after E2E file lands. [VERIFIED: existing test lanes]
- **Per wave merge:** `mix test && cd examples/cairnloop_example && PW_TRACE=true mix test.e2e`. [VERIFIED: 52-CONTEXT.md]
- **Phase gate:** `mix test`, `cd examples/cairnloop_example && PW_TRACE=true mix test.e2e`, `mix hex.build --unpack`, `xmllint --noout $(git ls-files '*.svg')`, `magick identify ...`, `du -ck ...`, and `git diff --stat`. [VERIFIED: 52-CONTEXT.md]

### Wave 0 Gaps

- [ ] `test/cairnloop/web/collateral_wiring_test.exs` — covers WIRE-01, WIRE-02, HYGIENE-01, HYGIENE-02, HYGIENE-03. [VERIFIED: no existing file]
- [ ] `examples/cairnloop_example/test/e2e/collateral_wiring_test.exs` — covers WIRE-03 and browser side of WIRE-01. [VERIFIED: no existing file]
- [ ] Minimal app markup update in `layouts.ex` for `alt="Cairnloop"` if E2E uses accessible logo selector. [VERIFIED: layouts.ex]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 52 touches public static/documentation surfaces only; no auth behavior changes. [VERIFIED: 52-CONTEXT.md] |
| V3 Session Management | no | Existing browser pipeline and session setup stay unchanged. [VERIFIED: router.ex] |
| V4 Access Control | no | No new routes, controllers, or protected resources are introduced. [VERIFIED: 52-CONTEXT.md] |
| V5 Input Validation | yes | Treat committed SVG/metadata paths as input to browsers and GitHub; validate XML, `viewBox`, and block external/data/script/raster references. [VERIFIED: .planning/REQUIREMENTS.md] |
| V6 Cryptography | no | No cryptographic operations or secrets are introduced. [VERIFIED: 52-CONTEXT.md] |
| V10 Server-Side Request Forgery | low/no | No remote URLs should be added; static guard should reject remote references in SVG/root metadata where Phase 52 owns them. [VERIFIED: 52-UI-SPEC.md] |

### Known Threat Patterns for Static Collateral

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SVG script/foreignObject/external href | Tampering / Information Disclosure | Block `<script>`, `<foreignObject>`, `<image>`, `xlink:href`, external/data hrefs, `base64`, and editor metadata in all tracked SVGs. [VERIFIED: 52-CONTEXT.md] |
| Remote OG/favicon/logo URL | Information Disclosure | Use local Phoenix static paths only; E2E fetches local URLs and static tests reject remote URLs in owned metadata. [VERIFIED: 52-UI-SPEC.md] |
| Package boundary leak | Information Disclosure / Supply Chain | Keep `brandbook/`, `logo/`, and `scripts/` outside `mix.exs` files and verify unpacked package contents. [VERIFIED: mix.exs] [CITED: https://hex.pm/docs/publish] |
| Misleading brand spoof through wrong asset | Spoofing | Static tests assert approved asset inventory and exact file paths; E2E asserts accessible logo name and expected metadata copy. [VERIFIED: logo/USAGE.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/52-collateral-wiring-qa-validation-sweep/52-CONTEXT.md` - locked Phase 52 decisions, scope, QA gate shape, canonical refs. [VERIFIED: codebase grep]
- `.planning/phases/52-collateral-wiring-qa-validation-sweep/52-UI-SPEC.md` - approved UI/collateral contract and exact copy. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` - WIRE/HYGIENE requirement text. [VERIFIED: codebase grep]
- `.planning/STATE.md` and `.planning/ROADMAP.md` - milestone sequencing, owner gate, no human rendered-behavior checks. [VERIFIED: codebase grep]
- `logo/USAGE.md`, `logo/*` - approved asset inventory and usage rules. [VERIFIED: codebase grep]
- `README.md`, `mix.exs`, `examples/cairnloop_example/*`, `test/cairnloop/web/brandbook_scaffold_test.exs`, existing E2E files, `.github/workflows/ci.yml` - current implementation and test patterns. [VERIFIED: codebase grep]
- Local commands: `xmllint --noout $(git ls-files '*.svg')`, `magick identify ...`, `du -ck ...`, `mix hex.build --unpack`, `pg_isready`, `playwright --version`. [VERIFIED: local command]

### Secondary (MEDIUM confidence)

- Phoenix VerifiedRoutes docs - static path verification and `~p`. [CITED: https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html]
- Phoenix Endpoint docs - static file path helpers for `priv/static`. [CITED: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html]
- PhoenixTest Playwright docs - real-browser PhoenixTest driver and `evaluate` helpers. [CITED: https://hexdocs.pm/phoenix_test_playwright/PhoenixTest.Playwright.html]
- Playwright docs - page `evaluate` and page events for request/page errors. [CITED: https://playwright.dev/docs/evaluating] [CITED: https://playwright.dev/docs/api/class-page]
- Hex publish/task docs - package `:files`, publish/build/unpack behavior. [CITED: https://hex.pm/docs/publish] [CITED: https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html]
- GitHub README docs - relative links and image paths in rendered repository files. [CITED: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes]

### Tertiary (LOW confidence)

- GitHub SVG sanitizer internals for README SVG rendering were not found in current official docs during this pass; rely on local safe-subset validation and mark sanitizer-specific behavior as assumed. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools and packages are already in the repo or local environment; no new installs are recommended. [VERIFIED: codebase grep]
- Architecture: HIGH - Phase 52 scope maps directly to existing README, Phoenix static, HEEx root layout, ExUnit, and E2E seams. [VERIFIED: 52-CONTEXT.md]
- Pitfalls: HIGH for codebase/package/test pitfalls; LOW only for GitHub SVG sanitizer internals. [VERIFIED: local command] [ASSUMED]

**Research date:** 2026-06-26
**Valid until:** 2026-07-26 for local codebase findings; re-check docs/package versions if planning happens after dependency changes. [ASSUMED]

**Research seam note:** `gsd_run query research-plan --input /tmp/phase52-research-plan-input.json` failed because this installed `gsd-tools.cjs` shim does not expose `research-plan`; official docs were fetched directly and claims are tagged as cited. [VERIFIED: local command]
