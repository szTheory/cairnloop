# Phase 51: Full HTML Brand Book Assembly - Pattern Map

**Mapped:** 2026-06-25
**Files analyzed:** 8
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `brandbook/index.html` | static document / generated output | transform | `brandbook/index.html` | exact |
| `brandbook/assets/css/brandbook.css` | stylesheet / component styling | transform | `brandbook/assets/css/brandbook.css` | exact |
| `scripts/assemble_brandbook.exs` or equivalent repo-local Phase 51 script | utility / generator | file-I/O + transform | `scripts/derive_brandbook_tokens.exs` | exact |
| `scripts/derive_brandbook_tokens.exs` | utility / generator | file-I/O + transform | `scripts/derive_brandbook_tokens.exs` | exact |
| `brandbook/assets/css/tokens.css` | generated config / token mirror | transform | `brandbook/assets/css/tokens.css` | exact |
| `brandbook/color/swatches.json` | generated data / token mirror | transform | `brandbook/color/swatches.json` | exact |
| `scripts/verify_brandbook_file_load.mjs` | browser verification utility | request-response + file-I/O | `scripts/verify_brandbook_file_load.mjs` | exact |
| `test/cairnloop/web/brandbook_scaffold_test.exs` | test / source guard | file-I/O + transform | `test/cairnloop/web/brandbook_scaffold_test.exs` | exact |

## Pattern Assignments

### `brandbook/index.html` (static document, transform)

**Analog:** `brandbook/index.html`

**Imports / asset loading pattern** (lines 1-9):
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Cairnloop brand book</title>
    <link rel="stylesheet" href="./assets/css/tokens.css">
    <link rel="stylesheet" href="./assets/css/brandbook.css">
  </head>
```

**Header / provenance pattern** (lines 11-19):
```html
<main class="brandbook-shell">
  <header class="brandbook-header">
    <div class="brandbook-kicker">Canonical source: priv/static/cairnloop.css :root</div>
    <h1 class="brandbook-title">Cairnloop brand book</h1>
    <p class="brandbook-copy">
      Brand book scaffold ready. Core structure and derived tokens are in place.
      Phase 51 adds the full logo, color, type, and usage sections.
    </p>
  </header>
```

**Live token/specimen section pattern** (lines 39-70):
```html
<section class="brandbook-section" aria-labelledby="tokens-heading">
  <h2 id="tokens-heading">Live token preview</h2>
  <div class="brandbook-token-grid">
    <div class="brandbook-token">
      <div class="brandbook-swatch brandbook-swatch--primary"></div>
      <code>--cl-primary</code>
    </div>
  </div>
</section>

<section class="brandbook-section" aria-labelledby="type-heading">
  <h2 id="type-heading">Type proof</h2>
  <div class="brandbook-type-specimen">
    <p class="brandbook-display">Support that leaves a trail.</p>
    <p class="brandbook-mono">Martian Mono / Atkinson Hyperlegible Mono: --cl-font-mono</p>
  </div>
</section>
```

**Theme proof pattern** (lines 73-84):
```html
<section class="brandbook-section" aria-labelledby="theme-heading">
  <h2 id="theme-heading">Light and dark token proof</h2>
  <div class="brandbook-theme-proof">
    <div class="brandbook-theme-box">
      <strong>Light tokens</strong>
      <span>Canvas, text, border, and copper are read from :root.</span>
    </div>
    <div class="brandbook-theme-box" data-theme="dark">
      <strong>Dark tokens</strong>
      <span>Semantic overrides are read from [data-theme="dark"].</span>
    </div>
  </div>
</section>
```

**Phase 51 adaptation:** Replace scaffold copy with complete generated or checked long-form content. Keep relative stylesheet paths, semantic `section` + `aria-labelledby`, visible provenance, and exact required labels from `51-UI-SPEC.md`.

---

### `brandbook/assets/css/brandbook.css` (stylesheet, transform)

**Analog:** `brandbook/assets/css/brandbook.css`

**Token-first base pattern** (lines 1-22):
```css
body {
  margin: 0;
  background: var(--cl-bg);
  color: var(--cl-text);
  font-family: var(--cl-font-sans);
  font-size: 15px;
  line-height: 1.6;
}

a:focus-visible {
  outline: none;
  box-shadow: var(--cl-focus-ring);
}
```

**Shell/header sizing pattern** (lines 24-57):
```css
.brandbook-shell {
  width: min(1120px, calc(100% - 32px));
  margin: 0 auto;
  padding: 48px 0;
}

.brandbook-title {
  margin: 0;
  font-family: var(--cl-font-display);
  font-size: 28px;
  font-weight: var(--cl-weight-semibold);
  line-height: 1.29;
}
```

**Cards/grids pattern** (lines 77-103):
```css
.brandbook-status-grid,
.brandbook-proof-grid,
.brandbook-token-grid {
  display: grid;
  gap: 16px;
}

.brandbook-cell,
.brandbook-panel,
.brandbook-token {
  background: var(--cl-surface);
  border: 1px solid var(--cl-border);
  border-radius: var(--cl-radius-sm);
  padding: 16px;
}
```

**Responsive and reduced-motion pattern** (lines 208-236):
```css
@media (min-width: 768px) {
  .brandbook-shell {
    width: min(1120px, calc(100% - 64px));
    padding: 64px 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

**Phase 51 adaptation:** Expand this file for sticky desktop navigation, mobile static contents, responsive table wrappers, logo galleries, diagrams, badge states, theme toggle, focus states, and local CSS imagery. Keep UI sizes aligned with the UI spec: 12px, 15px, 18px, 28px.

---

### `scripts/assemble_brandbook.exs` or equivalent (utility, file-I/O + transform)

**Analog:** `scripts/derive_brandbook_tokens.exs`

**Module + path constants pattern** (lines 1-8):
```elixir
defmodule Cairnloop.BrandbookTokens do
  @moduledoc false

  @source_path "priv/static/cairnloop.css"
  @tokens_path "brandbook/assets/css/tokens.css"
  @swatches_path "brandbook/color/swatches.json"
  @generate_command "mix run scripts/derive_brandbook_tokens.exs"
  @check_command "mix run scripts/derive_brandbook_tokens.exs --check"
```

**Run/check/write split pattern** (lines 85-94):
```elixir
def run(argv) do
  check? = "--check" in argv
  outputs = build_outputs()

  if check? do
    check_outputs!(outputs)
  else
    write_outputs!(outputs)
  end
end
```

**Local source parsing pattern** (lines 96-110):
```elixir
def build_outputs do
  css = File.read!(repo_path(@source_path))
  root_entries = css |> css_block(":root") |> declarations()
  dark_entries = css |> css_block(~s([data-theme="dark"])) |> declarations()

  root_tokens = Map.new(root_entries)
  dark_tokens = Map.new(dark_entries)
  merged_tokens = Map.merge(root_tokens, dark_tokens)

  validate_groups!(root_entries, dark_entries, root_tokens, dark_tokens)

  %{
    @tokens_path => tokens_css(root_entries, dark_entries),
    @swatches_path => swatches_json(root_entries, dark_entries, root_tokens, merged_tokens)
  }
end
```

**Validation/error pattern** (lines 113-144):
```elixir
defp css_block(css, selector) do
  pattern = ~r/#{Regex.escape(selector)}\s*\{(?<block>.*?)^\s*\}/ms

  case Regex.named_captures(pattern, css) do
    %{"block" => block} -> block
    _ -> raise "Missing required CSS block #{selector} in #{@source_path}"
  end
end

defp validate_groups!(root_entries, dark_entries, root_tokens, dark_tokens) do
  primitive = Enum.filter(root_entries, fn {token, _value} -> String.starts_with?(token, "--cl-color-") end)
  semantic_light = Enum.filter(root_entries, fn {token, _value} -> token in @semantic_tokens end)
  semantic_dark = Enum.filter(dark_entries, fn {token, _value} -> token in @semantic_tokens end)

  if primitive == [], do: raise("No primitive --cl-color-* tokens found in #{@source_path} :root")
  if semantic_light == [], do: raise("No required semantic --cl-* tokens found in #{@source_path} :root")
  if semantic_dark == [], do: raise(~s(No required semantic --cl-* tokens found in #{@source_path} [data-theme="dark"]))
end
```

**Deterministic check failure pattern** (lines 254-277):
```elixir
defp check_outputs!(outputs) do
  for {path, expected} <- outputs do
    full_path = repo_path(path)

    unless File.exists?(full_path) do
      raise """
      Missing generated output: #{path}
      Next action: run #{@generate_command}, then rerun #{@check_command}.
      """
    end

    actual = File.read!(full_path)

    unless actual == expected do
      raise """
      Generated output drift: #{path}
      Expected bytes do not match committed bytes.
      Next action: run #{@generate_command}, review the diff, then rerun #{@check_command}.
      """
    end
  end

  Mix.shell().info("brandbook token outputs are current")
end
```

**Phase 51 adaptation:** Use this pattern for an assembly/check script that reads `brandbook/color/swatches.json`, `brandbook/assets/css/tokens.css`, `logo/USAGE.md`, `logo/*`, Phase 48 contrast evidence, and `prompts/cairnloop_brand_book.md`, then writes/checks deterministic `brandbook/index.html`. Keep the script repo-local under `scripts/`; do not add a public Mix task.

---

### `scripts/derive_brandbook_tokens.exs` (utility, file-I/O + transform)

**Analog:** `scripts/derive_brandbook_tokens.exs`

**Generated file provenance pattern** (lines 146-163):
```elixir
defp tokens_css(root_entries, dark_entries) do
  """
  /*
    Generated from #{@source_path}.
    Regenerate with: #{@generate_command}
    Check drift with: #{@check_command}
    Do not edit by hand.
  */

  :root {
  #{format_declarations(root_entries)}
  }

  [data-theme="dark"] {
  #{format_declarations(dark_entries)}
  }
  """
end
```

**Swatch data shape pattern** (lines 192-204):
```elixir
%{
  schema_version: 1,
  source_file: @source_path,
  generated_by: @generate_command,
  check_command: @check_command,
  groups: %{
    primitive: primitive,
    semantic_light: semantic_light,
    semantic_dark: semantic_dark
  }
}
|> Jason.encode!(pretty: true)
|> Kernel.<>("\n")
```

**Phase 51 adaptation:** Prefer extending only if Phase 51 needs more generated token metadata. Otherwise leave token generation intact and call it as a precondition from tests/check commands. Do not put contrast matrices into `swatches.json`.

---

### `brandbook/assets/css/tokens.css` (generated config, transform)

**Analog:** `brandbook/assets/css/tokens.css`

**Generated header pattern** (lines 1-6):
```css
/*
  Generated from priv/static/cairnloop.css.
  Regenerate with: mix run scripts/derive_brandbook_tokens.exs
  Check drift with: mix run scripts/derive_brandbook_tokens.exs --check
  Do not edit by hand.
*/
```

**Token groups to render from** (lines 65-139):
```css
--cl-font-sans:            "Atkinson Hyperlegible Next", "Atkinson Hyperlegible", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
--cl-font-display:         "Fraunces", "Atkinson Hyperlegible Next", Georgia, serif;
--cl-font-mono:            "Martian Mono", "Atkinson Hyperlegible Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
--cl-font-title:           28px;
--cl-leading-title:        36px;
--cl-space-5:              16px;
--cl-radius-sm:            6px;
--cl-shadow-1:             0 1px 2px rgba(24, 33, 31, 0.06);
--cl-dur-ui:               180ms;
--cl-ease-out:             cubic-bezier(0.23, 1, 0.32, 1);
--cl-focus-ring:           0 0 0 2px var(--cl-surface, #FBF7EE), 0 0 0 4px var(--cl-focus, #A94F30);
```

**Dark theme override pattern** (lines 142-187):
```css
[data-theme="dark"] {
  --cl-bg:                   #101614;
  --cl-surface:              #141B19;
  --cl-surface-raised:       #1F2C28;
  --cl-text:                 #F5F0E6;
  --cl-text-muted:           #B7C0B2;
  --cl-primary:              #D98A4A;
  --cl-focus:                #D98A4A;
  --cl-shadow-1:             0 1px 2px rgba(0, 0, 0, 0.30);
}
```

**Phase 51 adaptation:** Read and verify this file. Do not hand-edit it. Render typography, spacing, radius, shadow, and motion tables from these token names and values.

---

### `brandbook/color/swatches.json` (generated data, transform)

**Analog:** `brandbook/color/swatches.json`

**Metadata and group shape pattern** (lines 1-12):
```json
{
  "check_command": "mix run scripts/derive_brandbook_tokens.exs --check",
  "groups": {
    "primitive": [
      {
        "value": "#141B19",
        "group": "primitive",
        "token": "--cl-color-basalt",
        "role": "core text / dark surface",
        "theme": "light",
        "display_hex": "#141B19"
      }
```

**Semantic row pattern** (lines 126-140):
```json
"semantic_light": [
  {
    "value": "var(--cl-color-trailpaper)",
    "group": "semantic_light",
    "token": "--cl-bg",
    "role": "page canvas",
    "theme": "light",
    "display_hex": "#F4EEE2"
  }
```

**Phase 51 adaptation:** Use as lean swatch input only. Add WCAG badge labels in generated HTML from Phase 48 contrast evidence, not by expanding this JSON into a contrast authority.

---

### `scripts/verify_brandbook_file_load.mjs` (browser verification, request-response + file-I/O)

**Analog:** `scripts/verify_brandbook_file_load.mjs`

**Local Playwright import pattern** (lines 1-12):
```javascript
import { pathToFileURL } from "node:url";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");
const brandbookPath = join(projectRoot, "brandbook", "index.html");
const brandbookUrl = pathToFileURL(brandbookPath).href;
const playwrightPath = join(projectRoot, "examples", "cairnloop_example", "assets", "node_modules", "playwright", "index.mjs");

const { chromium } = await import(pathToFileURL(playwrightPath).href);
```

**Required text pattern** (lines 13-20):
```javascript
const requiredText = [
  "Cairnloop brand book",
  "Canonical source: priv/static/cairnloop.css :root",
  "Token status: derived from canonical CSS",
  "Network dependency: none",
  "Full brand book assembly is Phase 51",
  "Brandbook is git-tracked and unshipped",
];
```

**Browser context and event collection pattern** (lines 28-54):
```javascript
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 1280, height: 900 },
  deviceScaleFactor: 1,
  reducedMotion: "reduce",
  colorScheme: "light",
});

const page = await context.newPage();

page.on("console", (message) => {
  if (message.type() === "error") {
    consoleMessages.push(`${message.type()}: ${message.text()}`);
  }
});

page.on("pageerror", (error) => {
  pageErrors.push(error.message);
});

page.on("request", (request) => {
  requests.push(request.url());
});

page.on("requestfailed", (request) => {
  failedRequests.push(`${request.url()} ${request.failure()?.errorText || "request failed"}`);
});
```

**Failure aggregation pattern** (lines 78-93):
```javascript
const remoteRequests = requests.filter((url) => /^https?:\/\//.test(url));
const nonLocalRequests = requests.filter((url) => !url.startsWith("file://"));

if (consoleMessages.length) failures.push(`Console errors:\n${consoleMessages.join("\n")}`);
if (pageErrors.length) failures.push(`Page errors:\n${pageErrors.join("\n")}`);
if (failedRequests.length) failures.push(`Failed requests:\n${failedRequests.join("\n")}`);
if (remoteRequests.length) failures.push(`Remote requests:\n${remoteRequests.join("\n")}`);
if (nonLocalRequests.length) failures.push(`Non-local requests:\n${nonLocalRequests.join("\n")}`);

if (failures.length) {
  console.error(`brandbook file-url verification failed for ${brandbookUrl}`);
  console.error(failures.join("\n\n"));
  process.exit(1);
}
```

**Phase 51 adaptation:** Extend with multiple viewport contexts, theme toggle assertions, keyboard focus-visible checks, table/geometry sanity, blank-page checks, local asset load/failure-copy checks, and relative download link checks. Keep independent from Phoenix routing.

---

### `test/cairnloop/web/brandbook_scaffold_test.exs` (test, file-I/O + transform)

**Analog:** `test/cairnloop/web/brandbook_scaffold_test.exs`

**DB-free source guard pattern** (lines 1-8):
```elixir
defmodule Cairnloop.Web.BrandbookScaffoldTest do
  @moduledoc """
  Pure source, package, and derivation guard for the Phase 50 brandbook scaffold.

  The test reads static files only: no Repo, no Endpoint, no Phoenix server.
  """
  use ExUnit.Case, async: true
```

**Required files/labels pattern** (lines 9-28):
```elixir
@required_files ~w(
  brandbook/index.html
  brandbook/TOKENS.md
  brandbook/assets/css/tokens.css
  brandbook/assets/css/brandbook.css
  brandbook/color/swatches.json
  scripts/derive_brandbook_tokens.exs
  scripts/verify_brandbook_file_load.mjs
)

@required_index_labels [
  "Cairnloop brand book",
  "Canonical source: priv/static/cairnloop.css :root",
  "Token status: derived from canonical CSS",
  "Network dependency: none",
  "Full brand book assembly is Phase 51",
  "Brandbook is git-tracked and unshipped"
]
```

**Forbidden dependency scan pattern** (lines 87-108):
```elixir
test "brandbook source has no remote, import, iframe, beacon, or root-relative dependencies" do
  files =
    Path.wildcard("brandbook/**/*")
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
```

**Package boundary and drift check pattern** (lines 110-121):
```elixir
test "brandbook remains outside the Hex package files allowlist" do
  mix_exs = File.read!("mix.exs")

  assert mix_exs =~ ~r/files:\s*~w\(lib priv guides mix\.exs README\.md LICENSE CHANGELOG\.md\)/
  refute mix_exs =~ ~r/files:.*brandbook/
end

test "generated token outputs are current" do
  {output, exit_code} = System.cmd("mix", ["run", "scripts/derive_brandbook_tokens.exs", "--check"], stderr_to_stdout: true)

  assert exit_code == 0, output
end
```

**Phase 51 adaptation:** Extend this same test module for required sections, exact labels, contrast badge text (`AA pass`, `UI pass`, `Decorative exempt`), logo/download inventory, `logo/USAGE.md` facts, no runtime `fetch` for required content, and any new Phase 51 assembly script `--check`.

---

### Optional `.github/workflows/ci.yml` update (config, batch)

**Analog:** `.github/workflows/ci.yml`

**Existing Playwright install pattern** (lines 224-228):
```yaml
- name: Install Playwright CLI (in assets/) + Chromium
  run: |
    npm --prefix assets ci
    npx --prefix assets playwright install --with-deps chromium
```

**Existing release gate pattern** (lines 247-271):
```yaml
release_gate:
  name: release_gate
  runs-on: ubuntu-latest
  needs: [phase-12-shift-left, integration, quality, e2e]
  if: ${{ always() }}
  steps:
    - name: Gate on required jobs
      run: |
        if [ "${{ needs.e2e.result }}" != "success" ]; then
          echo "Required job 'e2e' did not succeed (got: ${{ needs.e2e.result }})."
          exit 1
        fi
        echo "All required jobs passed."
```

**Phase 51 adaptation:** CI is optional. If touched, add a small explicit brandbook verification lane using existing Elixir setup plus the existing example-app Playwright install pattern; avoid serving through Phoenix and avoid slowing unrelated lanes without a planner decision.

## Shared Patterns

### Source Of Truth And Generated Derivatives

**Sources:** `scripts/derive_brandbook_tokens.exs`, `brandbook/assets/css/tokens.css`, `test/cairnloop/web/brandbook_scaffold_test.exs`

**Apply to:** `brandbook/index.html`, `brandbook/assets/css/tokens.css`, `brandbook/color/swatches.json`, any Phase 51 assembly script.

```elixir
@source_path "priv/static/cairnloop.css"
@tokens_path "brandbook/assets/css/tokens.css"
@swatches_path "brandbook/color/swatches.json"
@generate_command "mix run scripts/derive_brandbook_tokens.exs"
@check_command "mix run scripts/derive_brandbook_tokens.exs --check"
```

Keep `priv/static/cairnloop.css` canonical. Phase 51 HTML, token CSS, and swatch JSON are derivatives/rendered references.

### Contrast Badge Source

**Source:** `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md`

**Apply to:** color swatch rendering, badge labels, test assertions.

```markdown
| Row 29 | Focus ring on surface | `--cl-focus` | `#A8492A` | `--cl-surface` | `#FAF5EB` | Light | 5.29 | 3.0 | Meaningful focus indicator | PASS |
| Row 28a | Success chip border on success surface | `--cl-success-border` | `#C9D3A6` | `--cl-success-surface` | `#EDF1E2` | Light | 1.37 | 3.0 | Decorative status-chip outline | EXEMPT |
| CU-L-3 | Copper route-marker on canvas — UI/large role | `--cl-color-path-copper` | `#A8492A` | `--cl-bg` | `#F4EEE2` | Light | 4.98 | 3.0 | PASS |
```

Render badge text as `AA pass`, `UI pass`, or `Decorative exempt`. Do not place contrast matrices in `swatches.json`.

### Logo Facts And Download Inventory

**Source:** `logo/USAGE.md`

**Apply to:** logo gallery, clearspace diagram, min-size table, do/don't panels, download links, tests.

```markdown
| `cairnloop-lockup-horizontal.svg` | Default public logo for README, docs headers, package surfaces, and broad brand identification. | Primary lockup. No subtitle. Use first unless the surface is square or size-constrained. |
| `cairnloop-mark.svg` | Icon-only placements, small badges, and brand-book mark specimens. | C3.6 mark only: copper ring is the top stone. |
| `favicon-16.png` | 16px raster favicon fallback. | Generated from `favicon.svg`. |
```

```markdown
Minimum clearspace equals the height of the top stone/ring unit.
Phase 51 diagram note: label the exclusion zone as `1x`, where `x = top stone/ring height`.
```

```markdown
- Use no rectangular cage around the logo or mark.
- Use no loose icon-left-of-plain-text spacing.
- Recreate the wordmark with live text or a different font.
```

### Voice, Microcopy, Imagery, Motion Source

**Source:** `prompts/cairnloop_brand_book.md`

**Apply to:** Voice/Microcopy, Imagery, Motion sections in `brandbook/index.html`.

```markdown
**Grounded.** Say what the library does, what it does not do, and what the operator controls. Do not overpromise.
**Explicit.** Make hidden decisions visible: source coverage, confidence, policy, risk, handoff, trace, audit.
**Practical.** Prefer installable examples and next steps over abstract product poetry.
```

```markdown
1. **Trail markers and cairns** - close crops, lichen, basalt, granite, soft weather, low saturation.
2. **Topographic and route imagery** - contour lines, route marks, path overlays, hand-drawn wayfinding.
6. **Abstract support loops** - small markers connected by route lines, not glowing AI networks.
```

```markdown
- Motion should clarify route, state, or progress.
- Keep transitions under 180 ms for UI state changes.
- Prefer opacity + small translate. Avoid elastic motion.
- Respect reduced-motion preferences.
```

### DB-Free Static Tests

**Source:** `test/cairnloop/web/brandbook_scaffold_test.exs`

**Apply to:** all Phase 51 ExUnit coverage.

```elixir
use ExUnit.Case, async: true

test "required brandbook files and directories exist" do
  for path <- @required_files do
    assert File.exists?(path), "Expected #{path} to exist"
  end
end
```

Keep tests pure: no Repo, no Endpoint, no Phoenix server.

### Browser-Only Facts Stay In Playwright

**Source:** `scripts/verify_brandbook_file_load.mjs`

**Apply to:** file-url load, console/page/network assertions, focus, viewport geometry, theme toggle.

```javascript
await page.goto(brandbookUrl, { waitUntil: "load", timeout: 15000 });

const bodyText = await page.locator("body").innerText();

for (const text of requiredText) {
  if (!bodyText.includes(text)) failures.push(`Missing required text: ${text}`);
}
```

Use ExUnit for source/package/content guards; use Playwright for rendered browser behavior.

## No Analog Found

None. Phase 51 can be planned entirely from existing local analogs. The only inferred new file is a Phase 51 assembly/check script; its pattern is an exact match to `scripts/derive_brandbook_tokens.exs`.

## Metadata

**Analog search scope:** `brandbook/`, `scripts/`, `test/cairnloop/web/`, `logo/`, `.planning/phases/48-token-evolution-lock-propagate/`, `prompts/`, `mix.exs`, `.github/workflows/ci.yml`

**Files scanned:** 34 direct candidate files plus phase context/research/UI contract

**Pattern extraction date:** 2026-06-25

**Local project guidance:** `CLAUDE.md` read; no `AGENTS.md` found; no repo-local `.codex/skills/` or `.agents/skills/` directories found.
