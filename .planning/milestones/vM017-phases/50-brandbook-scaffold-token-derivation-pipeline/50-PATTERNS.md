# Phase 50: Brandbook Scaffold & Token-Derivation Pipeline - Pattern Map

**Mapped:** 2026-06-25
**Files analyzed:** 10
**Analogs found:** 9 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/derive_brandbook_tokens.exs` | utility | transform + file-I/O | `test/cairnloop/web/token_drift_test.exs` | role-match |
| `scripts/verify_brandbook_file_load.mjs` | utility | file-I/O + request-response | `examples/cairnloop_example/screenshots/capture.mjs` | role-match |
| `test/cairnloop/web/brandbook_scaffold_test.exs` | test | file-I/O + transform | `test/cairnloop/web/token_drift_test.exs` | exact |
| `brandbook/index.html` | static component | request-response | `priv/static/cairnloop.css` | partial |
| `brandbook/assets/css/tokens.css` | static config | transform | `priv/static/cairnloop.css` | exact |
| `brandbook/assets/css/brandbook.css` | static component | request-response | `priv/static/cairnloop.css` | exact |
| `brandbook/color/swatches.json` | static data | transform | `prompts/cairnloop.tokens.json` | role-match |
| `brandbook/TOKENS.md` | documentation | file-I/O | `logo/USAGE.md` | role-match |
| `brandbook/logo/` | static asset directory | file-I/O | `logo/` + `logo/USAGE.md` | role-match |
| `brandbook/raster/` | static asset directory | file-I/O | `logo/` + `logo/USAGE.md` | role-match |

## Pattern Assignments

### `scripts/derive_brandbook_tokens.exs` (utility, transform + file-I/O)

**Analog:** `test/cairnloop/web/token_drift_test.exs`

**Imports / dependency pattern** (lines 7-12):
```elixir
use ExUnit.Case, async: true

@canonical_path "priv/static/cairnloop.css"
@app_path "examples/cairnloop_example/assets/css/app.css"
@tokens_path "prompts/cairnloop.tokens.json"
```

Apply the same repo-relative path style, but as a script use `Path.join(File.cwd!(), path)` and `File.read!/1`. Use existing `Jason` from `mix.exs` lines 113-121, not a new JSON dependency:
```elixir
defp deps do
  [
    {:phoenix_live_view, "~> 1.0"},
    {:jason, "~> 1.2"},
    {:nimble_options, "~> 1.0"},
```

**Core CSS block extraction pattern** (lines 304-328):
```elixir
defp canonical_css, do: File.read!(Path.join(File.cwd!(), @canonical_path))
defp app_css, do: File.read!(Path.join(File.cwd!(), @app_path))

defp canonical_root_tokens, do: canonical_css() |> css_block(":root") |> declarations()

defp canonical_dark_tokens,
  do: canonical_css() |> css_block(~s([data-theme="dark"])) |> declarations()

defp css_block(css, selector) do
  pattern = ~r/#{Regex.escape(selector)}\s*\{(?<block>.*?)^\s*\}/ms

  captures = Regex.named_captures(pattern, css) || flunk("Missing CSS block #{selector}")

  Map.fetch!(captures, "block")
end

defp declarations(block) do
  ~r/(--(?:cl|color-cl)-[a-z0-9-]+)\s*:\s*([^;]+);/
  |> Regex.scan(block)
  |> Map.new(fn [_match, token, value] -> {token, String.trim(value)} end)
end
```

For the script, replace `flunk/1` with `raise/1`, restrict declarations to `--cl-*`, and fail if `:root` or `[data-theme="dark"]` is missing.

**Alias resolution pattern** (lines 330-346):
```elixir
defp resolved(tokens, token), do: resolved(tokens, token, MapSet.new())

defp resolved(tokens, token, seen) do
  value = Map.fetch!(tokens, token)

  case Regex.run(~r/^var\((--cl-[a-z0-9-]+)\)$/, value) do
    [_, alias_token] ->
      if MapSet.member?(seen, alias_token) do
        flunk("Circular token alias while resolving #{token}: #{inspect(MapSet.to_list(seen))}")
      else
        resolved(tokens, alias_token, MapSet.put(seen, token))
      end

    _ ->
      value
  end
end
```

Use this for JSON display values only. Preserve raw CSS values in `tokens.css`.

**Drift/error message pattern** (lines 378-386):
```elixir
defp mismatch(kind, file, token, expected, actual) do
  """
  #{kind}
  File: #{file}
  Token/key: #{token}
  Expected: #{inspect(expected)}
  Actual:   #{inspect(actual)}
  Next action: update the derivative or canonical token so Phase 48 has zero drift.
  """
end
```

For `--check`, generate expected bytes in memory, compare to committed files, and raise with file, expected action, and rerun command.

---

### `scripts/verify_brandbook_file_load.mjs` (utility, file-I/O + request-response)

**Analog:** `examples/cairnloop_example/screenshots/capture.mjs`

**Imports pattern** (lines 17-24):
```javascript
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdir } from "node:fs/promises";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "..", "..", "..", "guides", "assets");
const BASE_URL = (process.env.BASE_URL || "http://localhost:4000").replace(/\/$/, "");
```

For Phase 50, use `fileURLToPath`, `dirname`, `join`, and `pathToFileURL` from `node:url`/`node:path`. Do not depend on `BASE_URL`; the target is the absolute `file://` URL for `brandbook/index.html`.

**Browser setup pattern** (lines 119-132):
```javascript
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: VIEWPORT,
  deviceScaleFactor: DEVICE_SCALE,
  reducedMotion: "reduce",
  colorScheme: "light",
});
await context.addInitScript((css) => {
  const style = document.createElement("style");
  style.textContent = css;
  document.documentElement.appendChild(style);
}, STABILIZE_CSS);

const page = await context.newPage();
```

Keep deterministic viewport/reduced-motion setup. Omit screenshot output unless a later plan asks for it.

**Failure aggregation pattern** (lines 136-163):
```javascript
for (const shot of SHOTS) {
  const url = `${BASE_URL}${shot.path}`;
  try {
    await page.goto(url, { waitUntil: "networkidle", timeout: 20000 });
    await waitForLiveViewConnected(page);
    if (shot.waitFor) {
      await page.locator(shot.waitFor).first().waitFor({ state: "visible", timeout: 8000 });
    }
    if (shot.prepare) await shot.prepare(page);
    await page.waitForTimeout(150); // settle layout after any interaction
    await page.screenshot({
      path: join(OUT_DIR, shot.file),
      fullPage: Boolean(shot.fullPage),
    });
    ok += 1;
    console.log(`  ✓ ${shot.file.padEnd(30)} ${shot.path}`);
  } catch (err) {
    failures.push({ shot, err });
    console.error(`  ✗ ${shot.file.padEnd(30)} ${shot.path}  — ${err.message.split("\n")[0]}`);
  }
}

await browser.close();
console.log(`\n${ok}/${SHOTS.length} screenshots written to guides/assets/`);
if (failures.length) {
  console.error(`${failures.length} failed. Is the seeded demo running at ${BASE_URL}? (mix ecto.reset && mix phx.server)`);
  process.exit(1);
}
```

Adapt to collect `console` errors, `pageerror`, `request`, and `requestfailed` events before `page.goto(fileUrl)`. Fail if any request URL is `http:`, `https:`, protocol-relative, or failed.

**Anti-false-pass assertion style** (from `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`, lines 165-177):
```elixir
assert m["scrollHeight"] > m["innerHeight"],
       "inbox list did not overflow the viewport (scrollHeight #{m["scrollHeight"]} ≤ innerHeight #{m["innerHeight"]}) — occlusion test cannot exercise a real scroll"

assert m["lastBottom"] > 0 and m["lastBottom"] <= m["innerHeight"] + @subpixel_tol,
       "last inbox row is not within the viewport (bottom #{m["lastBottom"]}px, innerHeight #{m["innerHeight"]}px) — cannot prove non-occlusion"

assert m["lastBottom"] <= m["barTop"] + @subpixel_tol,
       "last inbox row (bottom #{m["lastBottom"]}px) is occluded by the sticky bulk-bar (top #{m["barTop"]}px)"
```

Mirror the same structure in JS: first assert the page loaded required text and linked stylesheets, then assert no console/network/page errors.

---

### `test/cairnloop/web/brandbook_scaffold_test.exs` (test, file-I/O + transform)

**Analog:** `test/cairnloop/web/token_drift_test.exs`

**Pure ExUnit/static-file pattern** (lines 1-7):
```elixir
defmodule Cairnloop.Web.TokenDriftTest do
  @moduledoc """
  Pure token drift and contrast verifier for Phase 48.

  The test reads static files only: no Repo, no Phoenix endpoint, no DB.
  """
  use ExUnit.Case, async: true
```

Use `Cairnloop.Web.BrandbookScaffoldTest`, keep it pure and async, and avoid Repo/Phoenix endpoint setup.

**Static file scan pattern** (from `test/cairnloop/web/brand_token_gate_test.exs`, lines 164-192):
```elixir
test "no hex-fallback strings remain in lib/cairnloop/web/ or examples/cairnloop_example/lib/cairnloop_example_web/live/ (BRAND-04, Phase 29 D-10 closure)" do
  files =
    Path.wildcard(Path.join(@web_dir, "**/*.ex")) ++
      Path.wildcard(Path.join(@example_live_dir, "**/*.ex"))

  refute files == [],
         "Expected to find .ex files in both #{@web_dir} and #{@example_live_dir}; got empty list — check path resolution"

  violations =
    for file <- files,
        {line, line_no} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
        Regex.match?(@hex_fallback_pattern, line) do
      {Path.basename(file), line_no, String.trim(line)}
    end

  assert violations == [],
         """
         BRAND-04 contract violated — hex fallbacks found in sealed render files.
```

Apply this to `brandbook/**/*.{html,css,json,md}` with explicit checks for required files, forbidden remote/root paths, package exclusion, and required copy labels.

**Package allowlist source** (from `mix.exs`, lines 22-25):
```elixir
package: [
  name: "cairnloop",
  files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md),
  licenses: ["MIT"],
```

Test should assert `brandbook` is absent from the package `files` list.

---

### `brandbook/index.html` (static component, request-response)

**Analog:** `priv/static/cairnloop.css`

**Source comments and no-build posture** (lines 1-16):
```css
/* ============================================================================
   Cairnloop Design System — cairnloop.css  (v1)
   ----------------------------------------------------------------------------
   Shipped, self-contained operator-UI stylesheet. No Tailwind / daisyUI needed.
   Adopters include this one file and (optionally) override `--cl-*` tokens to
   theme. All `.cl-*` rules read semantic tokens with a baked fallback, so the
   file renders correctly even before the host defines any token.

     <link rel="stylesheet" href="/cairnloop.css" />   (served from priv/static)

   Brand: "Support that leaves a trail." Calm, grounded, operator-grade. Color
   proportion 70% neutral / 20% text+border / 10% semantic state. Never
   state-by-color-alone — status always pairs color + icon + text.

   Layers:  tokens (:root) → dark theme → reduced-motion → base → components.
   ============================================================================ */
```

Index should be static and self-contained, with relative links:
```html
<link rel="stylesheet" href="./assets/css/tokens.css">
<link rel="stylesheet" href="./assets/css/brandbook.css">
```

Do not copy the root-relative `/cairnloop.css` path shown in the canonical CSS comment.

**Base typography and token consumption pattern** (lines 219-239):
```css
.cl-app {
  background: var(--cl-bg, #F5F0E6);
  color: var(--cl-text, #18211F);
  font-family: var(--cl-font-sans);
  font-size: var(--cl-font-body, 15px);
  line-height: var(--cl-leading-body, 24px);
  -webkit-font-smoothing: antialiased;
  text-rendering: optimizeLegibility;
}
.cl-app *,
.cl-app *::before,
.cl-app *::after { box-sizing: border-box; }

.cl-app h1, .cl-app h2, .cl-app h3 {
  font-weight: var(--cl-weight-semibold, 600);
  color: var(--cl-text, #18211F);
  margin: 0;
}
.cl-app h1 { font-size: var(--cl-font-title, 28px); line-height: var(--cl-leading-title, 36px); }
.cl-app h2 { font-size: var(--cl-font-panel, 18px); line-height: var(--cl-leading-panel, 26px); }
.cl-app h3 { font-size: var(--cl-font-body, 15px);  line-height: var(--cl-leading-body, 24px); }
```

Use these type and token names for the scaffold page. Keep the UI-SPEC required copy exact.

---

### `brandbook/assets/css/tokens.css` (static config, transform)

**Analog:** `priv/static/cairnloop.css`

**Canonical root token source** (lines 18-74):
```css
:root {
  /* ---- Primitive colors (raw, context-free) ------------------------------ */
  --cl-color-basalt:        #141B19;
  --cl-color-moss-ink:      #263A2E;
  --cl-color-trailpaper:    #F4EEE2;
  --cl-color-warm-stone:    #FAF5EB;
  --cl-color-granite:       #8E8068;
  --cl-color-slate-lichen:  #5E665D;
  --cl-color-path-copper:   #A8492A;
  --cl-color-copper-glow:   #C46A3A;
  --cl-color-lichen:        #A8B56C;
  --cl-color-deep-lichen:   #4A6238;
  --cl-color-glacier-mist:  #DDE8E3;
  --cl-color-waypoint-blue: #3F6F80;
  --cl-color-heather:       #7A5D78;
  --cl-color-ember:         #8B531E;
  --cl-color-fault-clay:    #B54C36;

  /* ---- Semantic colors (intent; reference primitives) -------------------- */
  --cl-bg:             var(--cl-color-trailpaper);
  --cl-surface:        var(--cl-color-warm-stone);
  --cl-surface-raised: #FFFFFF;
  --cl-surface-sunken: #EFE9DC;
  --cl-text:           var(--cl-color-basalt);
  --cl-text-muted:     var(--cl-color-slate-lichen);
  --cl-text-soft:      #8A8C82;
  --cl-border:         var(--cl-color-granite);
  --cl-border-strong:  #BFB6A2;
  --cl-primary:        var(--cl-color-path-copper);
```

Generated `tokens.css` should preserve all `--cl-*` declarations from `:root`, not hand-pick only colors.

**Canonical dark token source** (lines 161-197):
```css
/* ---- Dark theme: override semantic tokens only ------------------------- */
[data-theme="dark"] {
  --cl-bg:             #101614;
  --cl-surface:        #141B19;
  --cl-surface-raised: #1F2C28;
  --cl-surface-sunken: #0C110F;
  --cl-text:           #F5F0E6;
  --cl-text-muted:     #B7C0B2;
  --cl-text-soft:      #8A9488;
  --cl-border:         #5B7066;
  --cl-border-strong:  #627A6E;
  --cl-primary:        #D98A4A;
  --cl-primary-hover:  #E69A5C;
  --cl-primary-text:   #18211F;
  --cl-danger-button-text: #141B19;
```

Generated output should include a provenance comment naming `priv/static/cairnloop.css`, then `:root` and `[data-theme="dark"]`.

---

### `brandbook/assets/css/brandbook.css` (static component, request-response)

**Analog:** `priv/static/cairnloop.css`

**Reduced motion pattern** (lines 199-214):
```css
@media (prefers-reduced-motion: reduce) {
  .cl-app *,
  .cl-app *::before,
  .cl-app *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
  /* Re-enable meaning-bearing cross-fades (e.g. policy-gate state). */
  .cl-app .cl-motion-state {
    transition-duration: 120ms !important;
    transition-property: opacity, color, background-color, border-color !important;
  }
}
```

If `brandbook.css` uses transitions, scope them to color/border/background/opacity/transform and honor reduced motion.

**Base layout pattern** (lines 219-239):
```css
.cl-app {
  background: var(--cl-bg, #F5F0E6);
  color: var(--cl-text, #18211F);
  font-family: var(--cl-font-sans);
  font-size: var(--cl-font-body, 15px);
  line-height: var(--cl-leading-body, 24px);
  -webkit-font-smoothing: antialiased;
  text-rendering: optimizeLegibility;
}
.cl-app *,
.cl-app *::before,
.cl-app *::after { box-sizing: border-box; }
```

Use brandbook-specific class names, but consume `--cl-*` tokens. Avoid `@import`, remote `url(...)`, Tailwind plugins, and root-relative paths.

---

### `brandbook/color/swatches.json` (static data, transform)

**Analog:** `prompts/cairnloop.tokens.json`

**Grouped primitive schema pattern** (lines 9-71):
```json
"color": {
  "primitive": {
    "basalt": {
      "value": "#141B19",
      "description": "core text / dark surface"
    },
    "moss_ink": {
      "value": "#263A2E",
      "description": "secondary dark / deep UI"
    },
    "trailpaper": {
      "value": "#F4EEE2",
      "description": "main canvas"
    }
  }
}
```

For Phase 50, use a lean generated shape with file-level provenance plus grouped rows. Keep token names and raw values; include resolved display hex where useful.

**Grouped semantic schema pattern** (lines 72-103):
```json
"semantic_light": {
  "bg": "#F4EEE2",
  "surface": "#FAF5EB",
  "surface_raised": "#FFFFFF",
  "text": "#141B19",
  "text_muted": "#5E665D",
  "border": "#8E8068",
  "primary": "#A8492A",
  "primary_text": "#FFFFFF"
},
"semantic_dark": {
  "bg": "#101614",
  "surface": "#141B19",
  "surface_raised": "#1F2C28",
  "text": "#F5F0E6",
  "text_muted": "#B7C0B2",
  "border": "#5B7066",
  "primary": "#D98A4A",
  "primary_text": "#18211F"
}
```

Phase 50 schema should group as `primitive`, `semantic_light`, and `semantic_dark`; do not add pairwise contrast data.

---

### `brandbook/TOKENS.md` (documentation, file-I/O)

**Analog:** `logo/USAGE.md`

**Operational source documentation pattern** (lines 1-4):
```markdown
# Cairnloop Logo Usage

This file is the Phase 51 source for the brand-book logo gallery, clearspace diagram, minimum-size table, and do/don't panels. Use these assets as committed; do not redraw, recolor, or recompose the mark.
```

For `TOKENS.md`, open with the source and authority: `priv/static/cairnloop.css` is canonical, `tokens.css` and `swatches.json` are generated mirrors.

**Approved files table pattern** (lines 5-20):
```markdown
## Approved files

| File | Use when | Notes |
| --- | --- | --- |
| `cairnloop-lockup-horizontal.svg` | Default public logo for README, docs headers, package surfaces, and broad brand identification. | Primary lockup. No subtitle. Use first unless the surface is square or size-constrained. |
| `cairnloop-lockup-stacked.svg` | Square or centered compositions, brand-book specimens, and social/card layouts that need a vertical rhythm. | Secondary lockup. Do not use as the dense docs/package default. |
```

Use the same table style for generated files and commands:
`mix run scripts/derive_brandbook_tokens.exs` and `mix run scripts/derive_brandbook_tokens.exs --check`.

**Phase handoff pattern** (lines 62-64):
```markdown
## Phase handoff

Phase 51 renders this Markdown into the HTML brand book: approved-file gallery, clearspace diagram, minimum-size table, and do/don't panels. Phase 52 wires the assets into README, favicon, OG metadata, and the example app only after the future owner logo-family sign-off gate.
```

Use a handoff note that Phase 51 assembles full content and Phase 52 wires package/app surfaces.

---

### `brandbook/logo/` (static asset directory, file-I/O)

**Analog:** `logo/USAGE.md` and `logo/`

**Approved logo inputs** (lines 5-20):
```markdown
| `cairnloop-lockup-horizontal.svg` | Default public logo for README, docs headers, package surfaces, and broad brand identification. | Primary lockup. No subtitle. Use first unless the surface is square or size-constrained. |
| `cairnloop-lockup-stacked.svg` | Square or centered compositions, brand-book specimens, and social/card layouts that need a vertical rhythm. | Secondary lockup. Do not use as the dense docs/package default. |
| `cairnloop-mark.svg` | Icon-only placements, small badges, and brand-book mark specimens. | C3.6 mark only: copper ring is the top stone. |
| `cairnloop-lockup-horizontal-mono.svg` | One-color basalt lockup on trailpaper, white, or similarly light approved surfaces. | Use for print or constrained single-ink contexts. |
| `cairnloop-lockup-horizontal-reverse.svg` | One-color trailpaper lockup on basalt or similarly dark approved surfaces. | Use when the full-color lockup loses contrast. |
| `favicon.svg` | SVG favicon source and small browser icon source. | Separately authored simplified cut. Do not substitute the full mark at 16px. |
```

For Phase 50, create the directory as a relative destination only. Do not copy/render the full gallery unless the plan explicitly includes placeholders.

**Do-not-copy restrictions** (lines 47-60):
```markdown
## Do not

- Use no rectangular cage around the logo or mark.
- Use no chat bubble.
- Use no infinity symbol.
- Use no robot, no headset, and no support-agent trope.
- Use no loose icon-left-of-plain-text spacing.
- Use no subtitle on primary lockup.
- Use no stretching, squeezing, skewing, or rotation.
- Use no arbitrary recoloring outside the approved full-color, mono, and reverse files.
- Use no shadows.
- Use no gradients.
- Place the logo on no low-contrast arbitrary backgrounds.
- Recreate the wordmark with live text or a different font.
```

---

### `brandbook/raster/` (static asset directory, file-I/O)

**Analog:** `logo/USAGE.md` and `logo/`

**Raster asset pattern** (lines 15-20):
```markdown
| `favicon.svg` | SVG favicon source and small browser icon source. | Separately authored simplified cut. Do not substitute the full mark at 16px. |
| `favicon-16.png` | 16px raster favicon fallback. | Generated from `favicon.svg`. |
| `favicon-32.png` | 32px raster favicon fallback. | Generated from `favicon.svg`. |
| `favicon.ico` | Browser ICO fallback with 16px and 32px entries. | Generated from the approved favicon rasters. |
| `cairnloop-og.svg` | 1200x630 OG/social card master. | Source for social preview export. Not a general logo lockup. |
| `cairnloop-og.png` | 1200x630 OG/social preview raster. | Use for GitHub/social metadata after Phase 52 wiring. |
```

For Phase 50, create the directory as a future relative destination. Do not wire favicon or OG metadata.

## Shared Patterns

### Static, DB-Free Tests

**Source:** `test/cairnloop/web/token_drift_test.exs` lines 1-7 and `test/cairnloop/web/brand_token_gate_test.exs` lines 19-23
**Apply to:** `test/cairnloop/web/brandbook_scaffold_test.exs`
```elixir
@moduledoc """
Pure token drift and contrast verifier for Phase 48.

The test reads static files only: no Repo, no Phoenix endpoint, no DB.
"""
use ExUnit.Case, async: true
```

### Token Parsing and Alias Resolution

**Source:** `test/cairnloop/web/token_drift_test.exs` lines 316-346
**Apply to:** `scripts/derive_brandbook_tokens.exs`, `test/cairnloop/web/brandbook_scaffold_test.exs`
```elixir
defp css_block(css, selector) do
  pattern = ~r/#{Regex.escape(selector)}\s*\{(?<block>.*?)^\s*\}/ms

  captures = Regex.named_captures(pattern, css) || flunk("Missing CSS block #{selector}")

  Map.fetch!(captures, "block")
end

defp declarations(block) do
  ~r/(--(?:cl|color-cl)-[a-z0-9-]+)\s*:\s*([^;]+);/
  |> Regex.scan(block)
  |> Map.new(fn [_match, token, value] -> {token, String.trim(value)} end)
end
```

### Source Guard / Violation Collection

**Source:** `test/cairnloop/web/brand_token_gate_test.exs` lines 203-227
**Apply to:** `test/cairnloop/web/brandbook_scaffold_test.exs`
```elixir
all_violations =
  for file <- files do
    content = File.read!(file)
    lines = String.split(content, "\n")
    lines_with_index = Enum.with_index(lines, 1)
    allowed = allowed_line_numbers(lines)
    file_violations = collect_violations(lines_with_index, allowed)

    Enum.map(file_violations, fn {line_no, trimmed} ->
      {Path.relative_to(file, File.cwd!()), line_no, trimmed}
    end)
  end
  |> List.flatten()

assert all_violations == [],
       """
       GATE-01 violated — hardcoded color literals found in render files.
```

Adapt the pattern to collect forbidden URLs/imports/root-relative paths, with clear `{file, line_no, line}` output.

### Package Boundary

**Source:** `mix.exs` lines 22-25
**Apply to:** `test/cairnloop/web/brandbook_scaffold_test.exs`, planning verification
```elixir
package: [
  name: "cairnloop",
  files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md),
  licenses: ["MIT"],
```

Assert `brandbook/` is not in the package allowlist.

### Browser Verification

**Source:** `examples/cairnloop_example/screenshots/capture.mjs` lines 119-163
**Apply to:** `scripts/verify_brandbook_file_load.mjs`
```javascript
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: VIEWPORT,
  deviceScaleFactor: DEVICE_SCALE,
  reducedMotion: "reduce",
  colorScheme: "light",
});
const page = await context.newPage();
```

Add event listeners before navigation:
```javascript
page.on("console", msg => {
  if (msg.type() === "error") consoleErrors.push(msg.text());
});
page.on("pageerror", err => pageErrors.push(String(err)));
page.on("request", req => requests.push(req.url()));
page.on("requestfailed", req => failedRequests.push(req.url()));
```

### Generated Mirrors Are Not Authority

**Source:** `prompts/cairnloop.tokens.json` lines 9-103 and `priv/static/cairnloop.css` lines 18-197
**Apply to:** `brandbook/assets/css/tokens.css`, `brandbook/color/swatches.json`, `brandbook/TOKENS.md`

Use `priv/static/cairnloop.css` as canonical source; generated outputs should state provenance and be reproducible through `mix run scripts/derive_brandbook_tokens.exs --check`.

## No Analog Found

Files with no close match in the codebase:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `brandbook/index.html` | static component | request-response | No existing standalone HTML document opens directly from `file://`; use UI-SPEC and token CSS patterns instead. |

## Metadata

**Analog search scope:** `test/cairnloop/web`, `examples/cairnloop_example/test/e2e`, `examples/cairnloop_example/screenshots`, `priv/static`, `prompts`, `logo`, `mix.exs`
**Files scanned:** 12 primary files plus phase artifacts
**Pattern extraction date:** 2026-06-25
