# Phase 47: brand-direction-exploration-selection-gate - Research

**Researched:** 2026-06-24
**Domain:** Static brand direction boards, hand-authored SVG logo exploration, durable selection record
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

### Locked Decisions

## Implementation Decisions

### A. The locked owner selection (the gate - LOGO-03 / TOKEN-01)

- **D-47-LOGO (owner-selected): Crowning-loop cairn, "ring is the top stone," wider & flatter stones
  with a compact ring** (tournament id **C3.6**). A stacked cairn whose topmost element is an open
  copper waymark ring - the loop *is* the crown, structural to the mark, not a line hung behind it.
  The loop reads as feedback / routing / "the trail returns" - **never** an infinity symbol, **never**
  a chat bubble, **never** a rectangular cage. Base stone widest & calm; asymmetric stones; the
  copper ring is the single accent.
  - *Rationale:* survives to favicon size (proven at 16px in the tournament), is unmistakably one
    cairn (most resolved read), and carries the loop meaning without futurist cliches. Chosen over
    the open-arch alternative (C10) for its stronger small-size legibility and single-object unity.
  - *Reference geometry* (throwaway 48x48 SVG - Phase 49 hand-authors the optimized production mark
    from this; it is a concept reference, not the shipped asset): ring `cx24 cy15 r5.4` stroke-width
    2.8; mid stone `x12 y25 w24 h7 rx3.5`; base stone `x7 y34 w34 h8 rx4`. Full source embedded in
    `47-DISCUSSION-LOG.md`.

- **D-47-PALETTE (owner-selected): "Refined."** Keep the basalt / trailpaper / copper identity but
  tune it and fix every Phase-46 AA failure. Illustrative shifts (Phase 48 finalizes exact values):
  basalt `#18211F->#141B19`, paper `#F5F0E6->#F4EEE2`, **copper `#A94F30->#A8492A`** (AA-safe for white
  text), muted `#677066->#5E665D`, dark-danger `#E18C7D->#C96A55`. The chosen mark's copper accent is
  `#A8492A` (light) / `#D98A4A` (dark). **Hard constraint:** the evolved palette MUST zero out the
  Phase-46 contrast failures (see canonical refs).
  - *Rationale:* evolves the feel without changing brand identity; best match for the calm, durable
    mark. Chosen over "Conservative" (too static) and "Bolder" (risks the quiet/durable thesis).

- **D-47-TYPE (owner-selected): keep the current stack** - **Atkinson Hyperlegible** (UI workhorse)
  + **Fraunces** (display / wordmark) + **Martian Mono** (code/IDs). No alternative explored;
  Fraunces was confirmed for the wordmark in round 1.
  - *Rationale:* Fraunces is the owner's pick; the workhorse + mono are well-suited, and leaving the
    workhorse unchanged means **no font-binary-budget work in Phase 48**.

- **D-47-LOCKUP (defaults; finalized in Phase 49):** horizontal primary lockup (mark + `cairnloop`,
  **tight kern**, mark optically centered to the wordmark's cap height - round-3's wide gap was
  rejected); vertical / stacked lockup; mono one-color cut for print; favicon proven at 16px.
  **The `oo`-ring echo / integrated-typemark wordmark treatment was explored and REJECTED by the
  owner** - the mark stands alone, plain `cairnloop` wordmark. (D-C's "explore one integrated
  typemark direction" was satisfied by the exploration; shipping it was not required.)

### B. Auto-decided implementation choices (shift-left - recorded, not owner-surfaced)

- **D-47-BOARDS:** the direction-boards artifact is `logo/_contest/direction-boards.html`; opens from
  `file://` with **relative paths only**, no network/console errors; renders all four directions at
  **16 / 24 / 48 / 256px**, in **horizontal + vertical** lockups, on **light AND dark** surfaces,
  with explicit **no-cage proof** rows and **16px-legibility proof** rows; palette and type variants
  shown alongside each direction so choices read cohesively.
- **D-47-ROSTER:** the four directions are the milestone-plan starting set - (A) stacked-cairn +
  wrapping loop, (B) negative-space loop, (C) integrated typemark, (D) waymark/contour glyph - with
  the *chosen* direction being the C3.6 crowning-loop refinement that emerged from exploring (A)/(C).
- **D-47-HYGIENE:** `logo/_contest/` is git-tracked but **out of the hex package** (`mix.exs` `files`
  unchanged); rejected directions are deleted in **Phase 49** (not here); the selection + rationale
  live in `47-DISCUSSION-LOG.md` (durable human record, not an automated check).

### Scoping note for the planner
The owner pre-selected during discussion. Scope Phase 47 execution to **formalize** the boards page
as documentation of the four directions + the chosen C3.6 mark, plus the recorded selection - not as
a fresh open-ended exploration. The heavy creative search is already done.

### the agent's Discretion

Exact boards-page layout/markup, how the proof rows are arranged, and the precise reference-SVG
redraw are planner/executor discretion within the constraints above.

### Deferred Ideas (OUT OF SCOPE)

- **Production optimized-SVG asset family** (primary/vertical/icon/mono lockups), **favicon** (16/32
  + `.ico`/PNG), **OG card** - **Phase 49**.
- **Apply the Refined palette to canonical `:root`** + propagate to `app.css` `@theme` and
  `cairnloop.tokens.json`, then re-verify gates/contrast - **Phase 48**.
- **`brandbook/` scaffold + token-derivation pipeline + full HTML assembly** - **Phases 50-51**.
- **Replace example-app logo/favicon + README SVG header** - **Phase 52**.
- **"Bolder" palette** and **alternate display-type (e.g. Spectral)** - explored/offered, not chosen;
  not revisited unless the owner reopens.
- The open-arch logo direction (**C10**) and the other round-2/round-3 marks - rejected; deleted
  from the contest in Phase 49.
- The **`oo`-ring echo / integrated typemark** - explored and initially liked, **dropped by the owner
  at finalization**; the wordmark stays plain `cairnloop`.

## Summary

Phase 47 should be planned as a static artifact formalization phase, not a live selection or production-logo phase. The owner already selected C3.6 / LOGO-03, the Refined palette / TOKEN-01, and the current Atkinson + Fraunces + Martian type stack in `47-DISCUSSION-LOG.md`. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]

The implementation target is `logo/_contest/direction-boards.html` plus supporting same-folder SVG/CSS only if useful. The page must open directly from `file://`, use relative/local resources only, render four hand-authored directions at 16/24/48/256px, show horizontal and vertical lockups on light and dark surfaces, and include explicit no-cage and 16px proof rows. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

Do not edit `priv/static/cairnloop.css`, `examples/cairnloop_example/assets/css/app.css`, `prompts/cairnloop.tokens.json`, README, example-app logo/favicon, `brandbook/`, or `mix.exs` in this phase. Those are owned by Phases 48, 49, 50-52, and packaging hygiene respectively. [CITED: .planning/ROADMAP.md]

**Primary recommendation:** Create a self-contained `logo/_contest/direction-boards.html` documenting the four explored directions and visibly marking C3.6 / Refined / current type as the locked owner selection; validate statically with grep/XML checks and manually/browser-open the local file without automating the subjective choice. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Direction-board rendering | Static file / Browser | - | The artifact is a local HTML page opened from `file://`, not a Phoenix route or server-rendered page. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| Hand-authored SVG logo directions | Static assets | Browser | SVG geometry is authored as static markup and rendered by the browser board. [CITED: prompts/cairnloop_brand_book.md] |
| Selection record | Planning docs | Static board annotation | `47-DISCUSSION-LOG.md` is already the durable human gate record; the board should display the selection but not replace the record. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |
| Palette/type preview | Static board | Phase 48 token source | Phase 47 previews Refined/current type; Phase 48 applies token values to canonical `:root`. [CITED: .planning/ROADMAP.md] |
| Package hygiene | Mix package metadata | Git status / diff review | Root `mix.exs` packages only `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`, so `logo/_contest/` remains out of Hex as long as `mix.exs` is unchanged. [VERIFIED: codebase grep] |

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOGO-01 | Four genuinely distinct, hand-authored SVG logo directions exist, including one integrated typemark, each transparent and no-cage. | Use the D-47 roster A/B/C/D; annotate C3.6 as the selected refinement and preserve transparent SVG backgrounds. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| LOGO-02 | Local HTML direction boards render all directions at 16/24/48/256px, horizontal + vertical, light + dark, no-cage and 16px proof rows. | Implement `logo/_contest/direction-boards.html` exactly for these proof rows and verify via local browser/file checks. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| LOGO-03 | Owner selects one logo direction; choice and rationale recorded durably. | Do not create an automated chooser; cite and optionally cross-link the existing `47-DISCUSSION-LOG.md` locked C3.6 selection. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |
| TOKEN-01 | Palette and type variants are presented alongside logo directions; owner selects palette + type. | Show current/conservative/refined/bolder or compact variant chips only as documentation; mark Refined and current type stack as selected. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |

## Project Constraints (from CLAUDE.md)

- Make discretionary decisions without asking the owner unless the decision is very impactful. [CITED: CLAUDE.md]
- Warnings-clean builds are mandatory when code is touched: `mix compile --warnings-as-errors`. [CITED: CLAUDE.md]
- Run `mix test` before declaring implementation done, while reporting baseline Repo caveats honestly. [CITED: CLAUDE.md]
- Use brand tokens over hardcoded hex in product code; Phase 47 contest SVG/HTML is a static brand artifact, but the planner should still keep hex values confined to the contest artifact and discussion references. [CITED: CLAUDE.md]
- Operator copy must be calm, reason-forward, and never state-by-color-alone. [CITED: CLAUDE.md]
- No project skills were found under `.claude/skills/` or `.agents/skills/`. [VERIFIED: codebase grep]

## Standard Stack

### Core

| Library / Format | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| HTML | Browser-native | Self-contained direction board opened from `file://`. | Required by Phase 47 board success criteria; avoids Phoenix/server coupling. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| SVG | SVG 2 / browser-native | Hand-authored mark, lockup, and proof-strip rendering. | Brand requirements mandate hand-authored SVG directions and no raster logo fallbacks. [CITED: .planning/REQUIREMENTS.md] |
| CSS | Browser-native | Board layout, surface previews, type samples, and responsive proof rows. | No build step or package install is needed for a static `file://` artifact. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| Markdown | Project docs | Durable selection and planning records. | `47-DISCUSSION-LOG.md` is the durable human selection record. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Elixir / Mix | Elixir 1.19.5, Mix 1.19.5 | Run compile/tests and keep package metadata unchanged. | Use for final repo checks even though Phase 47 is static-document heavy. [VERIFIED: command output] |
| ripgrep | 15.1.0 | Verify files, forbidden edits, hardcoded references, and package file list. | Use for fast static checks. [VERIFIED: command output] |
| Browser devtools / Playwright optional | Existing example app uses PhoenixTest Playwright | Confirm local board loads without console/network errors if planner wants automated browser proof. | Do not use E2E to choose the subjective direction. [CITED: .planning/STATE.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static `logo/_contest/direction-boards.html` | Phoenix LiveView route | Wrong tier and adds runtime coupling for a local selection artifact. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| Inline/self-contained SVG | PNG exports | Raster logo fallbacks are prohibited until favicon/OG work in later phases. [CITED: .planning/REQUIREMENTS.md] |
| Existing package managers | New npm SVG tooling | No external packages are needed; package hygiene says keep `mix.exs` files unchanged. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |

**Installation:**

```bash
# No packages should be installed for Phase 47.
```

## Package Legitimacy Audit

No external packages should be installed in Phase 47. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | - | - | - | - | OK | No install required. [VERIFIED: codebase grep] |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
47-DISCUSSION-LOG.md locked selection
        |
        v
logo/_contest/direction-boards.html
        |
        +--> Four direction panels (A/B/C/D roster)
        |        |
        |        +--> selected C3.6 panel annotated as LOCKED
        |
        +--> Proof rows: 16/24/48/256px, horizontal/vertical, light/dark, no-cage
        |
        +--> Palette/type preview: Refined + current stack selected
        |
        v
Phase 48 consumes selected palette/type; Phase 49 consumes selected logo geometry
```

This flow is document/static-asset only; no Phoenix endpoint, database, runtime state, or package dependency participates. [CITED: .planning/ROADMAP.md]

### Recommended Project Structure

```text
logo/
└── _contest/
    ├── direction-boards.html     # required local file:// board
    └── assets/                   # optional same-folder relative assets only, if splitting helps
```

Keep `brandbook/` absent until Phase 50 and keep production logo assets absent until Phase 49. [CITED: .planning/ROADMAP.md]

### Pattern 1: Static Board With Visible Selection

**What:** Render every direction as an inline SVG preview and add a visible selected state to the C3.6 / Refined / current-type combination. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]

**When to use:** Use for all Phase 47 visual deliverables. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**Example:**

```html
<!-- Source: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md -->
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cairnloop selected crowning-loop cairn mark">
  <circle cx="24" cy="15" r="5.4" fill="none" stroke="#A8492A" stroke-width="2.8"></circle>
  <rect x="12" y="25" width="24" height="7" rx="3.5" fill="#1E2A24"></rect>
  <rect x="7" y="34" width="34" height="8" rx="4" fill="#141B19"></rect>
</svg>
```

MDN documents that `viewBox` maps a defined user-space rectangle into the SVG viewport, and MDN ARIA guidance recommends `role="img"` with a label for embedded SVG images. [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/viewBox] [CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/img_role]

### Pattern 2: File-Local Resource Discipline

**What:** Keep all board CSS/SVG inline or referenced by relative same-directory paths. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**When to use:** Use for every board dependency so `file://` open has no network or failed-resource noise. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**Example:**

```html
<!-- Source: Phase 47 context file:// requirement -->
<link rel="stylesheet" href="./assets/direction-boards.css">
<img src="./assets/direction-a.svg" alt="Direction A stacked cairn loop">
```

### Anti-Patterns to Avoid

- **Reopening selection:** Do not ask the owner to choose again or make an automated selector; `47-DISCUSSION-LOG.md` already closes LOGO-03/TOKEN-01. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]
- **Editing canonical tokens:** Do not change `priv/static/cairnloop.css`, `app.css`, or `cairnloop.tokens.json`; Phase 48 owns token propagation. [CITED: .planning/ROADMAP.md]
- **Shipping production logo assets early:** Do not create favicon, OG card, README header, example-app replacement logo, or optimized logo family; Phases 49 and 52 own those. [CITED: .planning/ROADMAP.md]
- **Adding package/build dependencies:** Do not add npm tooling, Mix deps, or generated asset pipelines for a static contest board. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]
- **Rectangular cage / chat bubble / infinity read:** The selected mark must avoid all three. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subjective selection gate | Automated scoring, E2E winner selection, or vote logic | Existing `47-DISCUSSION-LOG.md` human record | The requirement says selection is subjective and already complete. [CITED: .planning/REQUIREMENTS.md] |
| Production SVG optimization | Custom optimizer or final asset pipeline | Defer to Phase 49 | Phase 49 owns production optimized SVG asset family. [CITED: .planning/ROADMAP.md] |
| Contrast engine | Committed contrast calculator | Phase 46 baseline + Phase 48 re-verification | Phase 46 used a throwaway script and Phase 48 owns re-checking the matrix. [CITED: .planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md] |
| Static site bundling | Vite/esbuild/npm workflow | Plain HTML/CSS/SVG | The board must open from `file://`; no new package is needed. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |

**Key insight:** Phase 47 is a gate artifact, not an application feature; planning should minimize machinery and maximize durable visual evidence. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Treating The Gate As Still Open

**What goes wrong:** The plan creates a human-verify task or tries to generate new alternatives for owner selection. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**Why it happens:** The roadmap wording predates the discussion outcome, while the phase context says the owner already selected C3.6 / Refined / current type. [CITED: .planning/ROADMAP.md] [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**How to avoid:** Make the board a formal record of explored directions and selected outcome. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]

**Warning signs:** Plan mentions "ask owner to choose", "run selection E2E", or "compare finalists" as active execution. [CITED: .planning/REQUIREMENTS.md]

### Pitfall 2: Mutating Phase 48/49 Files

**What goes wrong:** The executor edits canonical tokens, production logos, README, favicon, or example-app assets. [CITED: .planning/ROADMAP.md]

**Why it happens:** The board previews exact-looking colors and logo geometry, but those are concept references until Phase 48/49. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]

**How to avoid:** Restrict edits to `logo/_contest/` and planning docs if needed. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**Warning signs:** `git diff --name-only` includes `priv/static/cairnloop.css`, `prompts/cairnloop.tokens.json`, `examples/`, `README.md`, `brandbook/`, or `mix.exs`. [VERIFIED: codebase grep]

### Pitfall 3: SVG Hygiene Regressions

**What goes wrong:** SVGs include external references, raster `<image>` embeds, missing `viewBox`, clipped geometry, non-transparent backgrounds, or inaccessible labels. [CITED: .planning/REQUIREMENTS.md]

**Why it happens:** Contest boards are visual scratch artifacts, but this one is git-tracked and becomes planning input for Phase 49. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

**How to avoid:** Require `xmlns`, `viewBox`, no `<image>`, no external `href`, no background rect cage, and accessible labels/titles. [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/viewBox] [CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/img_role]

**Warning signs:** Grep finds `<image`, `http://`, `https://`, `data:`, `xlink:href`, a full-canvas background rect, or SVGs without `viewBox`. [VERIFIED: codebase grep]

### Pitfall 4: Misreading Contrast Scope

**What goes wrong:** Phase 47 tries to "fix" contrast in canonical tokens or ignores the Phase 46 failures when presenting Refined. [CITED: .planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md]

**Why it happens:** Refined values are illustrative in Phase 47 and exact values are finalized in Phase 48. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]

**How to avoid:** Show Refined as selected and carry the contrast constraints forward; do not mutate token sources. [CITED: .planning/ROADMAP.md]

**Warning signs:** Plan includes a committed contrast script, token rewrites, or claims all AA issues are fixed in Phase 47. [CITED: .planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md]

## Code Examples

### Minimal Direction Panel

```html
<!-- Source: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md -->
<section class="direction-card direction-card--selected" aria-labelledby="direction-c36-title">
  <h2 id="direction-c36-title">Selected: C3.6 crowning-loop cairn</h2>
  <div class="proof-strip" aria-label="Size proof: 16, 24, 48, and 256 pixels">
    <svg width="16" height="16" viewBox="0 0 48 48" role="img" aria-label="C3.6 at 16px">
      <circle cx="24" cy="15" r="5.4" fill="none" stroke="#A8492A" stroke-width="2.8"></circle>
      <rect x="12" y="25" width="24" height="7" rx="3.5" fill="#1E2A24"></rect>
      <rect x="7" y="34" width="34" height="8" rx="4" fill="#141B19"></rect>
    </svg>
  </div>
</section>
```

### Static Verification Commands

```bash
# Source: repo conventions and Phase 47 hygiene
test -f logo/_contest/direction-boards.html
rg -n '<svg' logo/_contest/direction-boards.html
rg -n 'viewBox=' logo/_contest/direction-boards.html
! rg -n '<image|xlink:href|href=\"https?://|data:' logo/_contest
git diff --name-only -- mix.exs priv/static/cairnloop.css prompts/cairnloop.tokens.json examples README.md brandbook
mix compile --warnings-as-errors
mix test test/cairnloop/web/brand_token_gate_test.exs
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Open Phase 47 selection gate | Formalize already-selected C3.6 / Refined / current stack | 2026-06-24 discussion | Planner should not schedule a new selection. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |
| Current palette as gospel | Current palette as seed; Refined selected for Phase 48 | vM017 D-A | Phase 47 previews, Phase 48 applies. [CITED: .planning/STATE.md] |
| Integrated `oo` typemark as candidate | Plain `cairnloop` wordmark with separate mark | 2026-06-24 discussion | Board should show integrated typemark as explored/rejected, not selected. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |

**Deprecated/outdated:**

- Planning an owner choice checkpoint for Phase 47 is outdated because the discussion log already records the owner selection. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]
- Treating the `oo`-ring echo as selected is outdated because the owner dropped it at finalization. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A human browser check is acceptable for `file://` console/network verification if no automated browser harness is added for this static artifact. [ASSUMED] | Validation Architecture | Planner may need to add a lightweight Playwright/static browser check instead. |

## Open Questions (RESOLVED)

1. **RESOLVED: rejected direction SVGs remain committed through Phase 47.**
   - What we know: Phase 47 context says `logo/_contest/` is git-tracked and rejected directions are deleted in Phase 49. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]
   - Resolution: Keep rejected directions in `logo/_contest/` for Phase 47 and schedule no deletion before Phase 49. Phase 49 may decide whether to delete all non-selected contest assets or keep screenshot/archive evidence. [CITED: .planning/ROADMAP.md]

2. **RESOLVED: board verification uses static checks plus browser/file-open evidence.**
   - What we know: Rendered-behavior checks generally use Playwright E2E, but subjective selection is never E2E'd. [CITED: .planning/STATE.md] [CITED: .planning/REQUIREMENTS.md]
   - Resolution: Use static grep/XML checks plus a browser/devtools or browser-automation file-open check for no network/console errors. Do not add app E2E and do not automate subjective selection. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Compile/test verification | yes | 1.19.5 | - |
| Mix | Compile/test verification | yes | 1.19.5 | - |
| Node.js | Optional browser/static helper scripts | yes | v22.14.0 | Avoid scripts; use shell/rg |
| npm | Should not be used for installs | yes | 11.1.0 | No install required |
| ripgrep | Static verification | yes | 15.1.0 | `grep` if unavailable |

**Missing dependencies with no fallback:** none. [VERIFIED: command output]

**Missing dependencies with fallback:** none. [VERIFIED: command output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix; optional browser checks only if planner adds them. [VERIFIED: codebase grep] |
| Config file | Root `mix.exs` aliases; example app has `mix test.e2e` for existing Playwright E2E. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| LOGO-01 | Four hand-authored SVG directions, transparent/no-cage | static grep/review | `rg -n '<svg|viewBox|rect|circle|path' logo/_contest` | no, Wave 0 |
| LOGO-02 | Board renders size, lockup, theme, no-cage proof rows | static + browser smoke | `test -f logo/_contest/direction-boards.html && rg -n '16px|24px|48px|256px|no-cage|dark|light' logo/_contest/direction-boards.html` | no, Wave 0 |
| LOGO-03 | Selection/rationale recorded durably | doc check | `rg -n 'C3|Refined|Keep current|locked' .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md logo/_contest/direction-boards.html` | discussion log yes; board no |
| TOKEN-01 | Palette/type variants shown and selected | static grep/review | `rg -n 'Refined|Atkinson|Fraunces|Martian|Conservative|Bolder|Spectral' logo/_contest/direction-boards.html` | no, Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/cairnloop/web/brand_token_gate_test.exs` plus static `rg` board checks. [VERIFIED: codebase grep]
- **Per wave merge:** `mix compile --warnings-as-errors` and `mix test` if implementation touches more than static contest assets. [CITED: CLAUDE.md]
- **Phase gate:** `git diff --name-only` confirms changes are limited to `logo/_contest/` and phase docs, with `mix.exs` unchanged. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]

### Wave 0 Gaps

- [ ] `logo/_contest/direction-boards.html` - covers LOGO-01, LOGO-02, LOGO-03, TOKEN-01. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]
- [ ] Optional `logo/_contest/assets/` - only if splitting CSS/SVG improves maintainability; paths must remain relative. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]
- [ ] Optional XML/SVG static check command in the plan - no committed dependency required. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth surface in static contest board. [CITED: .planning/ROADMAP.md] |
| V3 Session Management | no | No session surface in static contest board. [CITED: .planning/ROADMAP.md] |
| V4 Access Control | no | No protected runtime endpoint in Phase 47. [CITED: .planning/ROADMAP.md] |
| V5 Input Validation | yes | Treat SVG/HTML as source code: no external hrefs, no embedded raster, no scripts unless strictly needed. [CITED: .planning/REQUIREMENTS.md] |
| V6 Cryptography | no | No cryptographic operations in Phase 47. [CITED: .planning/ROADMAP.md] |

### Known Threat Patterns for Static SVG/HTML Brand Artifacts

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| External resource leakage from SVG/HTML | Information Disclosure | Use inline SVG or same-folder relative paths; grep for `http://`, `https://`, `data:`, `xlink:href`, and `<image`. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] |
| Script execution in local artifact | Tampering | Avoid scripts; if any script is added, keep it inline, deterministic, and unnecessary for core rendering. [ASSUMED] |
| Confusing artifact as production asset | Spoofing / Integrity | Label C3.6 SVG as concept reference and defer production asset family to Phase 49. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md` - locked Phase 47 scope, D-47 decisions, file/path/hygiene constraints. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md]
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md` - owner-selected logo/palette/type and C3.6 reference SVG. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md]
- `.planning/REQUIREMENTS.md` - LOGO-01, LOGO-02, LOGO-03, TOKEN-01 and hygiene requirements. [CITED: .planning/REQUIREMENTS.md]
- `.planning/ROADMAP.md` - Phase 47/48/49/50/51/52 boundaries. [CITED: .planning/ROADMAP.md]
- `.planning/STATE.md` - vM017 D-A/D-B/D-C and verification policy. [CITED: .planning/STATE.md]
- `prompts/cairnloop_brand_book.md` - visual identity, color, typography, accessibility rules. [CITED: prompts/cairnloop_brand_book.md]
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md` - contrast failures and remediation inputs. [CITED: .planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md]
- `CLAUDE.md` - project decision, build/test, and brand-token constraints. [CITED: CLAUDE.md]
- `mix.exs` - package `files` list excludes `logo/` and `brandbook/`. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- MDN SVG `viewBox` reference - SVG viewport/user-space definition. https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/viewBox [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/viewBox]
- MDN ARIA `img` role - accessible label pattern for embedded SVG images. https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/img_role [CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/img_role]
- W3C WAI WCAG 2.2 Understanding SC 1.4.3 - text contrast thresholds and logo-text exemption. https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum [CITED: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum]
- W3C WAI WCAG Understanding SC 1.4.11 - 3:1 non-text contrast for required UI/graphic information. https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html [CITED: https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html]

### Tertiary (LOW confidence)

- None used for implementation recommendations. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Phase context mandates static HTML/SVG and no packages; repo packaging confirms no `logo/` inclusion. [CITED: .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md] [VERIFIED: codebase grep]
- Architecture: HIGH - Phase boundaries clearly assign board to static artifact and token/logo production to later phases. [CITED: .planning/ROADMAP.md]
- Pitfalls: HIGH - Pitfalls come from locked context, Phase 46 contrast baseline, and verified repo/package layout. [CITED: .planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md] [VERIFIED: codebase grep]

**Research date:** 2026-06-24
**Valid until:** 2026-07-24 for repo-local planning constraints; re-check external SVG/WCAG docs if implementation slips beyond that. [ASSUMED]
