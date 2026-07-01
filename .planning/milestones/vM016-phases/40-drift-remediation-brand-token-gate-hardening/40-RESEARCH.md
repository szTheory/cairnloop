# Phase 40: Drift Remediation + Brand-Token Gate Hardening - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView render-layer refactor (inline-style → token/utility migration) + ExUnit/Credo lint-gate hardening
**Confidence:** HIGH (all claims verified against live files in this workspace)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (rgba strategy):** Snap translucent values to nearest existing **solid** tokens. Do NOT expand the shipped palette (stays at 140 tokens). White-alpha panels → `--cl-surface-raised`/`--cl-surface`/`--cl-surface-sunken` per nesting; 5 basalt text-opacity steps → 3-tier `--cl-text`/`--cl-text-muted`/`--cl-text-soft`; olive chip tint → success/info semantic surface; slate-blue chip tint → `--cl-info-*`; primary tints → primary semantic surface/border; border hairlines → `--cl-border`. Prefer routing result/source chips through `cl_source_card source_variant`. Glass aesthetic is intentionally dropped. Owner can veto cheaply.
- **D-02 (hex→token map):** `#e5e7eb`→`--cl-border`; `#8b7355`→`--cl-text-muted`; `#4c4033`→`--cl-text` (body) / `--cl-text-soft` where clearly secondary; maroon reject (`#8b1a1a` border/text, `#fdecea` fill)→`--cl-danger-{text,border,surface}`; olive/cream defer (`#7a5c00`,`#fef9e5`)→`--cl-warning-{text,border,surface}`; tan textarea border `#c38f57`→`--cl-border-strong` (or `--cl-border`); near-white-on-primary `#fffdf8`→the on-primary token the primary button already uses. Stay within existing palette — no new tokens.
- **D-03 (footer rebuild):** Replace hand-rolled approve/reject/defer footer with `cl_button` variants (primary=approve; danger=reject; default/warning=defer) and the two `<textarea style="…">` with `.cl-textarea`. Migrate bespoke inline-layout `style=` to existing `.cl-` utilities (`.cl-row`, `.cl-stack`, spacing utils). Do not invent new utility classes if an existing one fits.
- **D-04 (gate extension):** Extend existing `test/cairnloop/web/brand_token_gate_test.exs` (don't fork). Add detection for (a) inline `style="…#hex…"`, (b) raw `rgba(`/`hsl(`, (c) helper-returned hex (via full-source `#`-anchored scan).
- **D-05 (allowlist):** Magic-comment allowlist IS required. Inline escape-hatch (e.g. `# cl-allow-color`). Anchor on `#`+color context to avoid false positives (URLs/anchors, `phx-*` ids, comments without color). `.css` stays unscanned. No legitimate exceptions exist today.
- **D-06 (scope):** Gate scope = `lib/cairnloop/web/**/*.ex` + the example app live dir. ExUnit gate is CI source of truth.
- **D-07 (Credo):** Custom `Credo.Check` module wired into `.credo.exs`, complementary/advisory. Duplicate coverage acceptable. ExUnit gate remains authoritative.

### Claude's Discretion
- Exact `.cl-` utility selection per migrated inline-layout `style=`.
- Precise text-tier assignment (`--cl-text` vs `--cl-text-muted` vs `--cl-text-soft`) per snapped rgba text value.
- Regex/AST mechanics of the hardened gate + magic-comment sentinel spelling.
- Credo check module name, category, exit/priority config.

### Deferred Ideas (OUT OF SCOPE)
- Alpha/tint token family (`--cl-*-translucent`, `--cl-text-faint`, `--cl-*-tint`) — rejected for this phase (D-01).
- Remediating drift in render files **other than** the two named surfaces — out of scope; hardened gate will surface them for a follow-up sweep.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DRIFT-01 | Both files carry zero off-palette hardcoded hex; documented hex→token map applied (border/text/danger/warning, info+success via `cl_source_card source_variant`). | §B hex/rgba inventory + token map; §A confirms `cl_source_card` attrs exist (`source_variant` ~w(success info neutral warning danger ai)). |
| DRIFT-02 | Hand-rolled approve/reject/defer footer rebuilt with `cl_button` variants + shared textarea class; bespoke inline-layout `style=` → `.cl-` utilities. | §A inline-style→utility map; §F gap-flags (no `warning` button variant; no `--cl-text` color utility class). |
| GATE-01 | ExUnit gate fails on inline `style="…#hex…"`, raw `rgba()`/`hsl()`, helper-returned hex; `#`+color anchoring; magic-comment allowlist; `.css` unscanned. | §C gate mechanics, exact patterns, sentinel, false-positive anchoring, fixtures. |
| GATE-02 | Complementary dev-time Credo check flags hardcoded color in render files; ExUnit gate remains CI source of truth. | §D custom `Credo.Check` mechanics for Credo 1.7.18. |
</phase_requirements>

## Summary

This is a **render-layer refactor + lint-gate hardening** phase with no new product surface, no DB, and no new tokens. All decisions are locked (D-01..D-07); the research job was to (1) re-grep the two drift files because they have **drifted past CONTEXT.md's cited line numbers** (conversation_live is now 1456 lines, search_modal 636 lines), (2) produce the concrete inline-style→`.cl-`-utility map and hex/rgba→token map keyed to *current* line numbers, and (3) nail the gate-regex and Credo-check mechanics against the *actual* test harness and Credo 1.7.18.

Two structural gaps surfaced that the planner MUST resolve, because the obvious reading of D-03 would break the warnings-clean build:

1. **`cl_button` has no `warning` variant.** Its `attr :variant` is `values: ~w(default primary danger ghost)` — passing `"warning"` raises a compile-time attribute error (fails `--warnings-as-errors`). The defer button must use `variant="default"` (D-03 itself allows "default/warning = defer"). The *danger/warning color* of the footer's reject/defer affordances therefore comes from the surrounding **container token classes** (or `cl_chip`/`cl_source_card`), not from a button color variant.
2. **There is no token-color utility class for body text.** The CSS exposes `.cl-text-muted`, `.cl-text-small`, `.cl-text-micro` — but **no `.cl-text`** that sets `color: var(--cl-text)`. Migrating `color: #4c4033` (body) to a token therefore needs either (a) `style="color: var(--cl-text)"` — a token-valued inline style the hardened gate explicitly PASSES (it only flags `#hex`/`rgba`/`hsl`, not `var(--cl-…)`), or (b) the planner electing to add a small inert `.cl-text` utility class (a CSS *class*, not a new *token* — does not violate D-01's "no new tokens", but DOES touch shipped `cairnloop.css`, which D-01/posture discourages). **Recommendation: prefer token-valued inline `style="color: var(--cl-token)"`** — it satisfies the gate, adds zero CSS surface, and is the lowest-churn path. Flag to owner only if they'd rather grow the utility layer.

**Primary recommendation:** Apply the §A and §B tables verbatim; rebuild the footer with `cl_button variant="primary|danger|default"` + `.cl-textarea` + `.cl-stack`/`.cl-row`; replace search_modal chip-style helpers with `cl_source_card source_variant`; migrate remaining text colors to token-valued inline `style="color: var(--cl-…)"`; extend the existing gate test with three new line-regex patterns + a `# cl-allow-color` sentinel; add one `Credo.Check.Warning`-category custom check.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hex→token / rgba→token snapping in `.heex` render | Frontend Server (LiveView render fn) | CDN/Static (`cairnloop.css` tokens) | Markup lives in `.ex` render; token values live in shipped CSS, which stays untouched (D-01). |
| Footer affordance rebuild | Frontend Server (components.ex primitives) | — | `cl_button`/`cl_textarea`/`cl_source_card` are server-rendered function components. |
| Brand-token gate (CI source of truth) | Build/CI (ExUnit `File.read!` test) | — | Pure static text scan; no runtime, no DB. |
| Credo advisory check | Build/Dev (Credo `mix credo`) | — | Dev-time lint; complementary to ExUnit gate. |
| Dark-mode verification | Browser (CSS `[data-theme="dark"]` cascade) | — | Manual visual check; tokens respond to theme, off-palette hex does not. |

## Standard Stack

No external packages are installed by this phase. All tooling already present and version-pinned:

| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| ExUnit | bundled with Elixir 1.19.5 | Brand-token gate test harness | `[VERIFIED: mix test runs it today]` |
| Credo | 1.7.18 | Dev-time advisory check host | `[VERIFIED: mix.lock]` |
| Phoenix.Component | (project dep) | `cl_button`/`cl_source_card`/`cl_textarea` primitives | `[VERIFIED: lib/cairnloop/web/components.ex]` |

**No installation step. No Package Legitimacy Audit required** (zero external packages added).

## A. Inline-style → `.cl-` Utility Map (DRIFT-02 + D-03)

> Verified against live files at the current line numbers below. "Current `style=`" is abbreviated to the load-bearing layout properties.

### `conversation_live.ex` — footer + surrounding action blocks

| Line | Current `style=` (abbrev) | Target | Notes |
|------|---------------------------|--------|-------|
| 1070 | `display:flex; flex-direction:column; gap:12px` | `class="cl-stack"` (gap default 8px) or `cl-stack cl-stack--lg` if 16px reads better; 12px has no exact util | `.cl-stack` gap is `--cl-space-3` (8px); 12px = `--cl-space-4`. **No exact 12px stack util — flag**: planner picks 8 or 16, or accepts inline `gap` token `style="gap:var(--cl-space-4)"` (token-valued, gate-PASS). |
| 1071 | `font-size:0.85rem; color:#4c4033; font-weight:600` | label text — `.cl-text-small` (font) + token color | Body color → `style="color:var(--cl-text)"` (see §F gap #2). `font-weight:600` has no util — keep inline (non-color, gate-PASS) or rely on element. |
| 1073 | `display:flex; flex-wrap:wrap; gap:8px; align-items:flex-start` | `class="cl-row cl-row--wrap"` | `.cl-row` = flex+align-center+gap-8px. **align-items differs**: `.cl-row` centers, this wants `flex-start`. **Flag**: either accept center, or add `style="align-items:flex-start"` (non-color, gate-PASS). |
| 1077 | hand-rolled approve button inline style incl. `color:#fffdf8` | **Delete** — replace with `<.cl_button variant="primary" phx-click="approve_action" phx-value-approval-id={…}>Approve</.cl_button>` | `#fffdf8`→ handled by `.cl-button--primary` (`color:var(--cl-primary-text)`=`#FFFFFF`). |
| 1082 | reject `<form>` `display:flex; flex-direction:column; gap:6px` | `class="cl-stack"` | 6px≈`--cl-space-2`(4px) or 8px default; `.cl-stack` 8px acceptable. |
| 1084–1089 | reject `<textarea style="…border:#c38f57…">` | `class="cl-textarea"` | `.cl-textarea` (cairnloop.css:384). Drop all inline style. |
| 1090–1095 | reject `<button style="…#8b1a1a…#fdecea…">` | `<.cl_button variant="danger" type="submit">Reject</.cl_button>` | `.cl-button--danger` carries danger surface/text from tokens. |
| 1098 | defer `<form>` (same as reject form) | `class="cl-stack"` | — |
| 1100–1105 | defer `<textarea style="…#c38f57…">` | `class="cl-textarea"` | — |
| 1106–1111 | defer `<button style="…#7a5c00…#fef9e5…">` | `<.cl_button variant="default" type="submit" class="cl-button--?warning?">Defer</.cl_button>` | **No `warning` button variant exists (§F gap #1).** Use `variant="default"`; warning tone must come from a wrapping `cl_chip variant="warning"`/`cl_source_card` or accept neutral default. **Planner decides** — D-03 sanctions "default/warning". |
| 1114 | `font-size:0.75rem; color:#8b7355; font-style:italic` helper text | `.cl-text-muted .cl-text-small` (or `.cl-text-micro`) | `.cl-text-muted`=`color:var(--cl-text-muted)`. `font-style:italic` has no util — keep inline (non-color, gate-PASS). |
| 792 | `margin-top:12px; padding-top:12px; border-top:1px solid #e5e7eb` | border color → `var(--cl-border)`; spacing → token | No combined util fits; use `class="cl-divider"`-adjacent or `style="…border-top:1px solid var(--cl-border)"` (token-valued, gate-PASS). **Flag: no exact util.** |
| 1001,1018,1048 | `<details style="margin-top:Npx">` | spacing util — none exact (4/8px) | `.cl-mt-5` is 16px only. **No 4/8px margin-top util — flag**; accept token-valued inline `style="margin-top:var(--cl-space-3)"`. |
| 1002,1019,1033,1049 | `<summary>/<p> … color:#8b7355` | `.cl-text-muted` (+`.cl-text-small`) | — |
| 1020 | `color:#4c4033` (event detail body) | `style="color:var(--cl-text)"` | §F gap #2. |
| 1040,1046 | `color:#4c4033` (scope/policy prose) | `style="color:var(--cl-text)"` | §F gap #2. |

### `search_modal_component.ex` — render + chip helpers

| Line | Current `style=` (abbrev) | Target | Notes |
|------|---------------------------|--------|-------|
| 56 | `<form style="…border-bottom:1px solid rgba(64,51,43,0.08)">` | border → `var(--cl-border)`; keep token-valued inline | No util; `style="…border-bottom:1px solid var(--cl-border)"`. |
| 73,74 | `search-modal-body` / `search-results-pane` flex layout | keep (these are **layout-only, no color** → gate-PASS) | Already on bespoke classes; no color literal. Optional `.cl-row`/grid migration is discretionary; **not required by gate**. |
| 97 | `overflow-y:auto; padding-right:8px` | layout-only, no color | gate-PASS; leave or tokenize padding. |
| 100,101,128,136 | layout-only flex/grid styles | no color literal → gate-PASS | Leave; optional `.cl-row`/`.cl-stack`. |
| 105,145,175,198 | `color:rgba(47,36,29,0.62)` | `--cl-text-muted` (0.62 tier) → `style="color:var(--cl-text-muted)"` or `.cl-text-muted` | Snap per D-01. |
| 111 | `background:rgba(255,255,255,0.72); color:rgba(47,36,29,0.68)` (empty-state panel) | bg→`var(--cl-surface-raised)`; text→`var(--cl-text-muted)` | — |
| 141,207 | `color:rgba(47,36,29,0.76)` | `--cl-text-muted` (high end of muted) | D-01 muted band 0.62–0.76. |
| 149 | `color:var(--cl-primary)` | **already a token — gate-PASS, no change** | — |
| 162 | preview-pane `background:rgba(255,255,255,0.76); border:1px solid rgba(64,51,43,0.08)` | bg→`var(--cl-surface-raised)`; border→`var(--cl-border)` | — |
| 181 | `color:rgba(47,36,29,0.84)` | `--cl-text` (≥0.82 tier) → `style="color:var(--cl-text)"` | §F gap #2. |
| 193 | open button `background:var(--cl-primary); color:white` | **`color:white` keyword + token bg — gate-PASS**; optionally migrate to `<.cl_button variant="primary">` | `white` is a CSS keyword, not hex/rgba → gate does NOT flag. Migration optional (consistency). |
| 614/617/618 (`result_row_style/1`) | helper returns string with `rgba(169,79,48,0.22/0.08)` (active) and `rgba(64,51,43,0.08)`+`rgba(255,255,255,0.9)` (inactive) | active: border→primary semantic border, bg→primary semantic surface; inactive: border→`--cl-border`, bg→`--cl-surface-raised` | **Helper-returned literals — caught by gate (D-04c).** Rewrite helper to return token-valued string, OR route the active/inactive surface through a `.cl-` class + `aria-selected` CSS. **Planner's call**; simplest is token-valued return strings. |
| 621/622, 625/626 (`source_badge_style/1`) | helper returns `rgba(74,98,56,0.12); color:#4A6238` (KB) / `rgba(63,111,128,0.12); color:#3F6F80` (case) | **Replace caller (lines 129,165) with `<.cl_source_card source_variant="success">`** (KB→success/olive) **/ `source_variant="info"`** (resolved_case→slate-blue). Delete `source_badge_style/1`. | DRIFT-01 explicit: info+success via `cl_source_card source_variant`. components.ex:264-266 documents exactly this map (`#4A6238`→success, `#3F6F80`→info). **But note**: `cl_source_card` is a *card*, badges here are *inline pills* — `cl_chip variant="success|info"` may be the closer silhouette (`.cl-chip--success/info` exist, cairnloop.css:351-352). **Flag for planner: chip vs source_card** — CONTEXT/DRIFT-01 name `cl_source_card`, but `cl_chip` matches the inline-pill shape better. Either removes the inline rgba/hex. |
| 629/630, 633/634 (`trust_badge_style/1`) | helper returns `rgba(74,98,56,0.08)`/`rgba(63,111,128,0.08)` bg + `color:rgba(47,36,29,0.82)` | Same as source badge — route trust label through `cl_chip`/`cl_source_card` variant; text→`--cl-text`. Delete `trust_badge_style/1`. | trust pills are faint-tint variants of the source pills; collapse to the same chip/card variant + `.cl-text`. |

**No-clean-fit items the planner MUST decide (genuine gaps, per D-03 "don't invent utilities"):**
1. **12px / 6px gaps and 4px/8px margins** — `.cl-stack`/`.cl-row` are fixed at 8px gap; `.cl-mt-5`=16px is the only margin util. Recommend token-valued inline (`style="gap:var(--cl-space-4)"`) which is gate-PASS, OR accept the nearest util's 8/16px.
2. **`align-items:flex-start`** on the footer button row (`.cl-row` centers).
3. **`font-weight:600` / `font-style:italic`** — no util; keep inline (non-color, gate-PASS).
4. **Badge primitive choice** — `cl_chip` (pill, exact shape) vs `cl_source_card` (card, named by DRIFT-01).

## B. Hex / rgba Inventory — Authoritative Current Line Numbers

> CONTEXT.md cited ~792, 1002–1114, 1071–1114 (conversation) and ~56–207, 614–634 (search_modal). **Verified and corrected below** — conversation footer is now **1070–1114** (not 1071–1114); the trailing helper text is at **1114**; search helpers are at **614–634** (still accurate). conversation_live total = 1456 lines; search_modal = 636 lines. `[VERIFIED: grep -nE in this workspace, 2026-06-04]`

### `conversation_live.ex` — all `#hex` (zero `rgba(`/`hsl(`)

| Line | Literal(s) | Target token (D-02) |
|------|-----------|---------------------|
| 792 | `#e5e7eb` (border-top) | `--cl-border` |
| 1002 | `#8b7355` (summary) | `--cl-text-muted` |
| 1019 | `#8b7355` (summary) | `--cl-text-muted` |
| 1020 | `#4c4033` (event detail body) | `--cl-text` |
| 1033 | `#8b7355` (no-history) | `--cl-text-muted` |
| 1040 | `#4c4033` (scope prose) | `--cl-text` (body) |
| 1046 | `#4c4033` (policy prose) | `--cl-text` (body) |
| 1049 | `#8b7355` (summary) | `--cl-text-muted` |
| 1071 | `#4c4033` ("Approval required" label) | `--cl-text` |
| 1077 | `#fffdf8` (approve btn text) | on-primary → `--cl-primary-text` (via `.cl-button--primary`) |
| 1088 | `#c38f57` (reject textarea border) | `--cl-border-strong` (via `.cl-textarea`) |
| 1092 | `#8b1a1a`×2, `#fdecea` (reject btn) | `--cl-danger-{border,text,surface}` (via `.cl-button--danger`) |
| 1104 | `#c38f57` (defer textarea border) | `--cl-border-strong` (via `.cl-textarea`) |
| 1108 | `#7a5c00`×2, `#fef9e5` (defer btn) | `--cl-warning-{border,text,surface}` |
| 1114 | `#8b7355` (helper text) | `--cl-text-muted` |

### `search_modal_component.ex` — `rgba(` (lines) + `#hex` (helper returns)

| Line | Literal(s) | Target (D-01 snap) |
|------|-----------|--------------------|
| 56 | `rgba(64,51,43,0.08)` border-bottom | `--cl-border` |
| 105 | `rgba(47,36,29,0.62)` | `--cl-text-muted` |
| 111 | `rgba(255,255,255,0.72)` bg, `rgba(47,36,29,0.68)` text | `--cl-surface-raised`, `--cl-text-muted` |
| 141 | `rgba(47,36,29,0.76)` | `--cl-text-muted` |
| 145 | `rgba(47,36,29,0.62)` | `--cl-text-muted` |
| 162 | `rgba(255,255,255,0.76)` bg, `rgba(64,51,43,0.08)` border | `--cl-surface-raised`, `--cl-border` |
| 175 | `rgba(47,36,29,0.62)` | `--cl-text-muted` |
| 181 | `rgba(47,36,29,0.84)` | `--cl-text` (≥0.82) |
| 198 | `rgba(47,36,29,0.62)` | `--cl-text-muted` |
| 207 | `rgba(47,36,29,0.76)` | `--cl-text-muted` |
| 614 | `rgba(169,79,48,0.22)` border, `rgba(169,79,48,0.08)` bg (active row) | primary semantic border + surface (route via class or token-valued return) |
| 617/618 | `rgba(64,51,43,0.08)` border, `rgba(255,255,255,0.9)` bg (inactive row) | `--cl-border`, `--cl-surface-raised` |
| 622 | `rgba(74,98,56,0.12)` bg, `#4A6238` text (KB badge) | success variant via `cl_source_card`/`cl_chip` |
| 626 | `rgba(63,111,128,0.12)` bg, `#3F6F80` text (case badge) | info variant via `cl_source_card`/`cl_chip` |
| 630 | `rgba(74,98,56,0.08)` bg, `rgba(47,36,29,0.82)` text (canonical trust) | success-faint variant; text→`--cl-text` |
| 634 | `rgba(63,111,128,0.08)` bg, `rgba(47,36,29,0.82)` text (assistive trust) | info-faint variant; text→`--cl-text` |

**Literals NOT obviously covered by the locked map (planner must resolve tier):**
- **Trust badges (630/634)** are *faint* (0.08 alpha) variants of the source badges (0.12) — the map names success/info but doesn't distinguish the faint trust tier. Recommend: collapse trust badge onto the *same* chip/card variant as the source badge, differentiating by label only (brand §7.5 never-color-alone already satisfied by text). The faint distinction is part of the dropped glass aesthetic (D-01).
- **Active result row primary tint (614)** — `rgba(169,79,48,…)` is primary; the palette has `--cl-primary` but no "primary-surface/primary-border faint" token unless a semantic-primary family exists. **Verify in plan:** grep `--cl-primary-surface`/`--cl-primary-border` in cairnloop.css; if absent, the active-row highlight must come from a `.cl-` selected-state class (e.g. `aria-selected` CSS) rather than an inline primary tint, since D-01 forbids new tokens.

## C. Gate-Hardening Regex Mechanics (GATE-01 + D-04/D-05)

### Current harness shape `[VERIFIED: test/cairnloop/web/brand_token_gate_test.exs]`
- Pure `File.read!` + `String.split("\n")` + **per-line** `Regex.match?`. No DB (Repo-unavailable safe — keep it this way).
- Single pattern today: `@hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/` — catches only `var(--cl-token, #hex)` fallbacks (BRAND-04). Deliberately does NOT match `rgba(`.
- Scope dirs: `@web_dir = lib/cairnloop/web`, `@example_live_dir = examples/cairnloop_example/lib/cairnloop_example_web/live` (wildcard `**/*.ex`). **`.css` is already excluded** (only `.ex` globbed) — D-05 satisfied structurally. Example dir verified to exist (`chat_live.ex`).

### New patterns to ADD (three detections, D-04 a/b/c)

Because helper-returned hex (D-04c) lives in **plain source strings** (e.g. `"…color: #4A6238;"`), all three detections reduce to **scanning every line of `.ex` source** — inline-style attrs and helper return-strings are both just text containing a color literal. Recommended patterns:

```elixir
# (a)+(c) bare hex color literal (3/6 hex digits) anywhere in source.
#   Anchored: '#' followed by exactly 3 or 6 hex digits AND a word boundary,
#   so it won't match phx-ids, #{...} interpolation, or anchor URLs.
@hex_color ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/

# (b) raw rgba()/hsl()/rgb()/hsla() function-color literals in source.
@func_color ~r/\b(?:rgba?|hsla?)\(/
```

**`#`+color-context anchoring to avoid false positives (D-05):** Filter each candidate line before flagging:
1. **Strip `#{...}` interpolation** first (`String.replace(line, ~r/\#\{[^}]*\}/, "")`) so EEx interpolation never trips `#[0-9a-fA-F]{3}`.
2. **Ignore comment-only lines** with no color (lines whose trimmed start is `#` and that contain no `style=`/`color`/`background`/`rgba`/`hsl` token) — but DO still scan inline `#hex` inside `style=`.
3. **Ignore the existing `var(--cl-token, #hex)` form** is already separately flagged — fine to double-flag, or exclude to keep messages clean.
4. The `\b` word boundary after 3/6 hex digits prevents matching `#abcdef0` style IDs longer than 6 or DOM ids; `phx-value-*`, `id={"#{…}"}` are interpolation (stripped in step 1). `href="#section"` anchors have a non-hex char after `#` → no match.

**Magic-comment allowlist (D-05 — REQUIRED):**
- **Sentinel spelling (recommend):** `# cl-allow-color` (kebab, matches `.cl-` namespace; greppable; unambiguous).
- **Suppression semantics (recommend line-or-prev-line):** a violation on line *N* is suppressed if line *N* OR line *N-1* contains `cl-allow-color`. (Trailing same-line comment for one-liners; prev-line comment for multi-attr blocks where the literal isn't on the comment's own line.) Implement by building a set of allowed line numbers per file before filtering violations.
- Today there are **zero** legitimate exceptions — the allowlist exists for future intentional cases, not to grandfather current drift (D-05). Plan should NOT annotate any of the §A/§B literals; they must all be remediated.

**Scope confirmation:** Keep `@web_dir` + `@example_live_dir` exactly as-is (D-06). `.css` stays unscanned (no glob change). `examples/cairnloop_example/lib/cairnloop_example_web/live/` verified present.

### Concrete fixtures (success criterion 3)

These belong as **string fixtures inside the test** (not as on-disk `.ex` files that would themselves get scanned by the real gate). Run the regex+anchor logic against literal strings:

**MUST FAIL the gate:**
- `~s(<div style="color:#abc">)` — inline 3-digit hex
- `~s(<div style="color: #4A6238;">)` — inline 6-digit hex
- `~s(  "background: rgba(0,0,0,0.5);")` — raw rgba in helper return
- `~s(  "color: hsl(20, 50%, 40%);")` — raw hsl
- `~s(  defp badge, do: "#8b1a1a")` — helper-returned hex
- `~s(<div style="border:1px solid rgba(64,51,43,0.08)">)` — raw rgba in attr

**MUST PASS the gate:**
- `~s(<div style="color: var(--cl-text)">)` — token-valued inline style
- `~s(<button class="cl-button cl-button--primary">)` — utility class
- `~s(  phx-value-dom_id={presenter.dom_id})` — `#` only inside `#{}` interpolation (none here) / no color
- `~s(<a href="#supporting-evidence">)` — anchor, non-hex after `#`
- `~s(<div style="color:#abc"> <%!-- cl-allow-color --%>)` *(or prev-line)* — allowlisted
- `~s(    background: var(--cl-primary);)` — token
- `~s(# a comment mentioning issue #1234)` — comment, `#1` is 1 digit (not 3/6) → no match

## D. Custom Credo Check Mechanics (GATE-02 + D-07)

**Credo version:** 1.7.18 `[VERIFIED: mix.lock]`. The `use Credo.Check` API below matches 1.7.x. No built-in color check exists — a project check is required (D-07).

**Module + path (recommend):** `lib/cairnloop/credo_checks/no_hardcoded_color.ex`, module `Cairnloop.CredoChecks.NoHardcodedColor`. No existing custom-check convention in the repo (none found) — placing it under `lib/cairnloop/credo_checks/` keeps it inside the compiled tree (Credo `requires:` can also point at it).

**Boilerplate (1.7.x shape):**
```elixir
defmodule Cairnloop.CredoChecks.NoHardcodedColor do
  use Credo.Check,
    id: "CL_NoHardcodedColor",
    base_priority: :low,           # advisory — guides, doesn't dominate output
    category: :warning,
    explanations: [
      check: """
      Hardcoded color literals (#hex, rgba(), hsl()) must not appear in render
      `.ex` files. Use `var(--cl-<token>)` or a `.cl-` utility class.
      The ExUnit brand-token gate is the authoritative CI source of truth;
      this check is a complementary dev-time signal. Suppress an intentional
      exception with a `# cl-allow-color` comment.
      """
    ]

  alias Credo.Check.Result

  @hex ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/
  @func ~r/\b(?:rgba?|hsla?)\(/

  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    # scan only web render files; mirror the ExUnit gate's anchoring + allowlist
    ...
    |> Enum.map(&issue_for(issue_meta, &1))
  end
end
```

**Wiring into `.credo.exs` `[VERIFIED: .credo.exs]`:**
1. Add the module to the `enabled:` list under `## Warnings`:
   `{Cairnloop.CredoChecks.NoHardcodedColor, [priority: :low]}`
2. Add the source file to top-level `requires:` (currently `requires: []`) so Credo loads it before analysis: `requires: ["lib/cairnloop/credo_checks/no_hardcoded_color.ex"]`. (It's also in `lib/` which is in `included:`, but `requires:` is the documented mechanism for *loading* custom check modules.)
3. **Keep it advisory:** `base_priority: :low` + default `exit_status` means it surfaces under `mix credo --strict` without becoming a second hard gate. Do NOT raise its `exit_status` to a failing code — the ExUnit gate is the CI source of truth (D-07). Duplicate coverage of the same rule is explicitly acceptable/harmless.

**Scope:** The check's `run/2` should restrict to render dirs (filter `source_file.filename =~ "lib/cairnloop/web/"` or the example live dir) so it doesn't flag the canonical `cairnloop.css` (CSS isn't a Credo source anyway) or non-render `.ex`. Reuse the same `# cl-allow-color` sentinel for parity with the ExUnit gate.

**No new deps; survives `--warnings-as-errors`** (the check module is ordinary Elixir). Credo 1.7.18's `use Credo.Check` supports the `id:`/`base_priority:`/`category:`/`explanations:` options shown.

## E. Dark-Mode / Theming Verification Approach (manual)

`[VERIFIED: priv/static/cairnloop.css]` — dark theme is driven by **`[data-theme="dark"]`** (cairnloop.css:160), a layer that *redefines the same `--cl-*` tokens* (e.g. `--cl-text: #F5F0E6`, `--cl-surface-raised: #1F2C28`, `--cl-text-muted: #B7C0B2`). There is no `prefers-color-scheme` auto-switch — it's attribute-driven.

**Cheapest verification that a remediated string actually responds to the token (vs. a hex that wouldn't):**
1. In the running app (or example app), set `<html data-theme="dark">` (devtools: toggle the attribute on `<html>`/root).
2. The remediated footer text, search badges, and panels should **flip to the dark palette** (light text on dark surface). Any string still carrying an off-palette hex (`#4c4033`, `#4A6238`, `rgba(47,36,29,…)`) will **stay locked to the light value** and read wrong on dark — that visual mismatch is the failure signal.
3. Spot-check the four highest-risk surfaces: approve/reject/defer footer, search result badges (KB/case), preview-pane panel, empty-state panel.

This is **manual executor/verifier guidance**, not automated — the gate (§C) proves *no literals remain*; the dark-mode toggle proves the *replacements are live tokens* and not, e.g., a mistyped `var()` that silently falls back.

## F. Structural Gaps the Planner MUST Resolve

| # | Gap | Why it bites | Recommendation |
|---|-----|--------------|----------------|
| 1 | **`cl_button` has no `warning` variant** — `attr :variant values: ~w(default primary danger ghost)` `[VERIFIED: components.ex:30]`. Passing `"warning"` raises a compile-time attr error → fails `--warnings-as-errors`. | D-03 says "default/warning = defer" — taken literally as a button variant it won't compile. | Defer button = `variant="default"`. If warning tone is required, wrap in `cl_chip variant="warning"` or accept neutral default. |
| 2 | **No `.cl-text` color utility** — only `.cl-text-muted`/`.cl-text-small`/`.cl-text-micro` exist `[VERIFIED: cairnloop.css:250-252]`. Body color `#4c4033`→`--cl-text` has no utility class. | The "obvious" `class="cl-text"` migration would silently no-op (class doesn't exist). | Use token-valued inline `style="color:var(--cl-text)"` (gate-PASS, zero CSS churn) — preferred. Adding `.cl-text` class is allowed (not a new *token*) but touches shipped CSS (D-01 posture). |
| 3 | **No exact spacing utilities for 4/6/12px** — `.cl-stack`/`.cl-row` gap fixed at 8px; only `.cl-mt-5`(16) margin util. | D-03 forbids inventing utilities. | Token-valued inline (`gap:var(--cl-space-4)`) is gate-PASS; or snap to nearest util. |
| 4 | **Badge primitive: `cl_chip` vs `cl_source_card`** — DRIFT-01/CONTEXT name `cl_source_card source_variant`, but the search badges are inline pills; `cl_chip variant="success\|info"` matches the silhouette and exists (`.cl-chip--success/info`). | Wrong primitive → visual regression or awkward markup. | Planner picks; both eliminate the inline rgba/hex. `cl_chip` recommended for inline pills. |
| 5 | **Active-row primary tint (search:614)** may have no semantic-primary surface/border token. | D-01 forbids new tokens; an inline primary tint can't be tokenized if no token exists. | Plan must grep `--cl-primary-surface`/`--cl-primary-border`; if absent, use an `aria-selected` `.cl-` selected-state CSS rule instead of an inline tint. |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Approve/reject/defer buttons | Hand-styled `<button style="…hex…">` | `cl_button variant=` | Carries token color, focus ring, sizing; removes 3 hex sources. |
| Styled textareas | `<textarea style="border:#c38f57…">` | `class="cl-textarea"` | Shared token border/hover/invalid states (cairnloop.css:384). |
| Source/trust badges | `source_badge_style/1`/`trust_badge_style/1` rgba helpers | `cl_chip`/`cl_source_card` variant | Removes 4 helper-returned literals; brand §7.5 icon+text built in. |
| Color-literal gate | A second parallel test file | Extend `brand_token_gate_test.exs` | D-04: one gate, one source of truth. |

## Common Pitfalls

### Pitfall 1: Passing `variant="warning"` to `cl_button`
**What goes wrong:** Compile-time `attr` value error → `mix compile --warnings-as-errors` fails the whole phase. **Avoid:** use `variant="default"` for defer.

### Pitfall 2: Migrating body color to a non-existent `.cl-text` class
**What goes wrong:** `class="cl-text"` is inert (class undefined) → text falls back to inherited color, looks unchanged, passes the gate (no literal) but is *not* actually token-bound — and the dark-mode check (§E) catches it late. **Avoid:** token-valued inline `style="color:var(--cl-text)"`.

### Pitfall 3: Gate false-positives from `#{}` interpolation / anchors / phx-ids
**What goes wrong:** Naive `#[0-9a-fA-F]{3}` matches `#{var}` interpolation fragments and 3-hex-looking ids. **Avoid:** strip `#{...}` first, require `\b` after 3/6 hex digits, ignore color-free comment lines (§C anchoring).

### Pitfall 4: Credo check raising a hard exit and becoming a divergent second gate
**What goes wrong:** Setting a failing `exit_status` makes Credo a competing CI gate that can disagree with the ExUnit gate. **Avoid:** `base_priority: :low`, default exit — advisory only (D-07).

### Pitfall 5: Repo-unavailable workspace
**What goes wrong:** Adding a gate assertion that boots `Cairnloop.Repo`. **Avoid:** keep the gate a pure `File.read!`/string-scan ExUnit test (it already is). No proposed test here needs Postgres.

## Validation Architecture (Nyquist)

> `workflow.nyquist_validation` assumed enabled (no config disabling it found). Gate test runs in default `mix test`; no DB needed.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5) + Credo 1.7.18 |
| Config file | `test/test_helper.exs`, `.credo.exs` |
| Quick run command | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| Full suite command | `mix test` then `mix credo --strict` |

### Phase Requirements → Observable Signal Map
| Req ID | Behavior | Test Type | Automated Command | Signal proving it's met |
|--------|----------|-----------|-------------------|-------------------------|
| DRIFT-01 | Zero off-palette hex/rgba in both files | grep / gate | `grep -rnE '#[0-9a-fA-F]{3,6}\|rgba\(\|hsl\(' lib/cairnloop/web/conversation_live.ex lib/cairnloop/web/search_modal_component.ex` | Command returns **empty** (only `var(--cl-…)` and CSS keywords remain). |
| DRIFT-02 | Footer uses `cl_button`+`.cl-textarea`; inline-layout→`.cl-`/token | grep + visual | grep footer region for `style="…#`/`rgba` → empty; presence of `<.cl_button`/`class="cl-textarea"` | No color-literal `style=` in footer; primitives present; `mix compile --warnings-as-errors` passes. |
| GATE-01 | Gate fails on `#hex`/`rgba`/`hsl`/helper-hex; passes on tokens; allowlist works | ExUnit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | Fixture asserts: FAIL-set strings flagged, PASS-set strings clean, `# cl-allow-color` suppresses. Real render files scan clean. |
| GATE-02 | Credo check surfaces hardcoded color advisorily | Credo | `mix credo --strict` (or `mix credo list --only Cairnloop.CredoChecks.NoHardcodedColor`) | Check appears in output; flags a seeded literal; does NOT hard-fail CI on its own. |
| (gate) | Build clean | compile | `mix compile --warnings-as-errors` | Exit 0. |
| (theme) | Replacements are live tokens | manual | toggle `data-theme="dark"` on root | Remediated text/surfaces flip to dark palette; no string stays light-locked. |

### Wave 0 Gaps
- [ ] Extend `test/cairnloop/web/brand_token_gate_test.exs` with the two new patterns + allowlist + FAIL/PASS string fixtures (GATE-01). No new file (D-04).
- [ ] `lib/cairnloop/credo_checks/no_hardcoded_color.ex` — new custom check (GATE-02).
- [ ] `.credo.exs` — add `requires:` entry + `enabled:` tuple (GATE-02).
- [ ] No framework install needed (ExUnit + Credo present).

## Security Domain

Render-layer/CSS + lint-gate phase. No auth, session, crypto, input-validation, or data-handling surface introduced or modified. **No ASVS category applies** beyond the existing posture. The one adjacent concern — brand §7.5 "never state-by-color-alone" (accessibility) — is *preserved* by routing status through `cl_chip`/`cl_source_card`, which carry icon+text, not color alone. No new threat surface.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/mix | compile + test | ✓ | 1.19.5 (CI pin) | — |
| ExUnit | gate test | ✓ | bundled | — |
| Credo | advisory check | ✓ | 1.7.18 | — |
| Cairnloop.Repo (Postgres) | NOT required by this phase | ✗ (may be unavailable) | — | Gate test is pure `File.read!` — no DB needed |

**No blocking dependencies.** The Repo-unavailable caveat does not affect any proposed work (all tests are static-text scans).

## Runtime State Inventory

> This phase renames/migrates *style strings*, not stored data, service config, or OS state. Inventory for completeness:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB keys/IDs touched. Verified: changes are render-template + helper-fn + test/config only. | None |
| Live service config | None — no external service holds these style strings. | None |
| OS-registered state | None. | None |
| Secrets/env vars | None. | None |
| Build artifacts | New `lib/cairnloop/credo_checks/no_hardcoded_color.ex` compiles into `_build`; `.credo.exs requires:` loads it. No stale artifact risk. | Standard recompile |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `#fffdf8`→`--cl-primary-text` (via `.cl-button--primary` `color:var(--cl-primary-text)`=`#FFFFFF`) is the intended on-primary token. | §A/§B | Low — D-02 says "the on-primary token the primary button already uses elsewhere"; `.cl-button--primary` is exactly that. |
| A2 | `cl_chip` is acceptable in place of `cl_source_card` for inline search badges. | §A gap #4 | Medium — DRIFT-01 names `cl_source_card`; planner/owner may prefer the card. Either removes the literal. |
| A3 | No semantic-primary surface/border token exists (active result row tint). | §B/§F gap #5 | Medium — if it DOES exist, tokenize directly; if not, needs a selected-state CSS class. Plan must grep to confirm. |
| A4 | `# cl-allow-color` sentinel spelling. | §C/§D | Low — discretionary (D-05); any consistent spelling works. |
| A5 | Credo 1.7.18 `use Credo.Check` supports `id:`/`base_priority:`/`category:`/`explanations:` as shown. | §D | Low — standard 1.7.x API; verify against installed `deps/credo` source at plan time. |

## Open Questions

1. **`cl_source_card` vs `cl_chip` for search badges** — DRIFT-01 names source_card; chip matches the inline-pill shape. *Recommendation:* `cl_chip variant="success\|info"` (exact silhouette); escalate to owner only if the card form is wanted.
2. **Active-result-row primary tint** — does a `--cl-primary-surface`/`--cl-primary-border` token exist? *Recommendation:* plan greps cairnloop.css; if absent, use `aria-selected` `.cl-` state CSS (no new token, D-01-safe).
3. **`.cl-text` body-color path** — token-valued inline style (preferred, zero CSS churn) vs adding a `.cl-text` utility class. *Recommendation:* inline `style="color:var(--cl-text)"`; flag to owner only if they want the utility layer grown.

## Sources

### Primary (HIGH confidence)
- `lib/cairnloop/web/conversation_live.ex` (lines 785-799, 995-1120) — footer + style audit
- `lib/cairnloop/web/search_modal_component.ex` (lines 50-214, 600-636) — render + chip helpers
- `test/cairnloop/web/brand_token_gate_test.exs` — current gate harness
- `.credo.exs`, `mix.lock` (credo 1.7.18) — Credo config + version
- `lib/cairnloop/web/components.ex` (lines 20-63, 255-311, 435-439) — `cl_button`/`cl_source_card`/`cl_chip` attrs + variant mapping
- `priv/static/cairnloop.css` (lines 18-186 tokens incl. dark theme; 250-252 text utils; 297-386 button/chip/input; 430-475 layout/spacing) — token + utility inventory
- `.planning/REQUIREMENTS.md` §DRIFT-01/02, GATE-01/02 — scope
- `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` — example dir existence

### Secondary (MEDIUM confidence)
- Credo 1.7.x `use Credo.Check` API shape (training knowledge; verify against `deps/credo` at plan time — A5).

## Metadata

**Confidence breakdown:**
- Inline-style/hex inventory (§A/§B): HIGH — grepped + read live files this session.
- Gate mechanics (§C): HIGH — read actual harness; patterns are standard regex.
- Credo mechanics (§D): MEDIUM-HIGH — version pinned (1.7.18); API shape standard but verify at plan time.
- Structural gaps (§F): HIGH — confirmed against components.ex attrs and CSS class list.

**Research date:** 2026-06-04
**Valid until:** ~2026-07-04 (stable; re-grep line numbers if files change before planning)
