# Thread: Admin UI — Design-System + IA Elevation (ad-hoc)

**Branch:** `ui/design-system-ia-elevation` · **Started:** 2026-06-02 · **Type:** ad-hoc (NOT a GSD milestone)
**Plan:** `~/.claude/plans/do-we-have-a-nested-kettle.md`

## Goal
Raise the operator/admin UI to a high, consistent, brand-distinct baseline that pays reuse
dividends: codified token scales + shared component library + shipped themeable `cairnloop.css`,
a task-oriented Cockpit Home + persistent nav + cross-threading, restrained purposeful motion, and
seed data that fully expresses every screen. Repeatable/resumable so future passes compound.

## Locked decisions
1. **Ship `priv/static/cairnloop.css`** — hand-authored, self-contained (no adopter Tailwind/daisyUI
   needed), token-driven, themeable via `--cl-*` overrides. `priv` already ships in the hex package.
2. **Cockpit Home (`/`) + persistent nav shell** on every screen; Inbox moves to `/inbox`.
3. **Do NOT switch CSS architecture.** Keep the `--cl-*` token system; add a `.cl-*` component layer;
   replace ad-hoc daisyUI usage with `.cl-*` so the shipped CSS is self-contained.
4. **Motion: restrained + purposeful** (brand §15 motifs only; `prefers-reduced-motion` aware).
5. Honor guardrails: warnings-clean build, `mix test`, brand gate (bare `var(--cl-*)`,
   never-color-alone), don't churn sealed paths.

## Grounded current-state facts (from exploration)
- CSS: Tailwind v4 `@theme` + `--cl-*` tokens + daisyUI; templates use ZERO utility classes —
  instead ~160 inline `style=` + ~99 hardcoded hex vs 58 token refs. Color+type tokens mature;
  **missing scales: spacing, z-index, motion, full radius/shadow.** No shared component module.
- Canonical token source today: `prompts/cairnloop.css` (85 lines: tokens + 4 starter `.cl-*`),
  hand-copied into `examples/cairnloop_example/assets/css/app.css` (`@theme`+`:root`).
- 8 admin screens, no app shell / no persistent nav / no home. Routes in `lib/cairnloop/router.ex`
  `cairnloop_dashboard/2` (inbox at `/`, conversation at `/:id`).
- Toolchain OK here: Erlang OTP 28, `mix compile --warnings-as-errors` passes. DB likely
  unavailable (Repo caveat) → screenshot loop (Pass 6) may defer.

## Pass status
- [x] Pass 0 — research (3 bg agents: animation, GDS/IA, tokens+components) — DONE (synthesized below)
- [x] Pass 1 — design-system foundation — DONE: `priv/static/cairnloop.css` (full token system +
      `.cl-*` components + motion + reduced-motion, self-contained/themeable); `Cairnloop.Web.Components`
      (button/card/chip/banner/empty/stat/shell/breadcrumb/icon, inline-SVG, never-color-alone);
      example `app.css` `@import`s the shipped file; `prompts/cairnloop.css`→pointer; gate docstring
      updated. 7 render+gate tests green. TODO(docs): adopter `<link>` include in quickstart.
- [~] Pass 2 — IA shell — Cockpit Home (`HomeLive`, 5 task-cards, DB-defensive live counts,
      calm zero-states) + `Nav` destinations + `cl_shell` nav + route move (Home `/`, Inbox `/inbox`)
      + back-link fix. 4 headless Home tests green; full suite clean (only 2 PRE-EXISTING baseline
      failures, unrelated — see below). Cross-threading affordances (gap→convos, action→audit, etc.)
      folded into Pass 3 (done while editing each screen — avoids touching screens twice).
- [ ] Pass 3 — per-screen polish (Settings→Audit→KB Suggestions→Editor→Gaps→Index→Inbox→Conversation):
      wrap each in `cl_shell` nav + replace inline styles/daisyUI with `.cl-*` components + empty/error
      states + cross-thread links + brand microcopy.
- [ ] Pass 4 — motion layer
- [ ] Pass 5 — seed enrichment
- [ ] Pass 6 — visual-QA loop (DB-gated)

## Decisions log

### Motion tokens (research: Emil Kowalski great-animations) — ADOPTED
Durations: instant 100 / micro 140 / ui 180 / panel 260 / exit 160 (exits faster than entrances) /
route 600 (deliberate line-draw motif only). Easings (custom curves, NOT keyword ease/ease-in-out):
out `cubic-bezier(.23,1,.32,1)` (default enter/exit), in-out `cubic-bezier(.77,0,.175,1)` (on-screen
move), drawer `cubic-bezier(.32,.72,0,1)`, linear (line-draw/marker/progress). Stagger 50ms (lists).
Rules: ease-out default; never ease-in/keyword-ease; transitions (retargetable) not @keyframes for
re-triggerable UI; animate only transform+opacity (never width/height/top); never animate
keyboard-repeat actions; don't replay enter on LiveView patch (guard in `updated()`); reduced-motion
kills movement but keeps comprehension cross-fades. LiveView: CSS transition + `phx-mounted`/
`@starting-style`/`JS.transition` covers ~90%; reserve `phx-hook`+WAAPI for the 4 brand motifs
(route-draw, marker-travel, source-card stack, gate-flip) + FLIP reorder.

### Web idiom (recon) — confirmed
LiveViews `use Phoenix.LiveView` directly + `~H` in `def render/1`; NO shared web base module.
Presenters already isolate humanization (audit_log_presenter, tool_proposal_presenter, etc.).
→ New `Cairnloop.Web.Components` (Phoenix.Component, attr/slot) that screens `import`. Pure
presentational; presenters keep owning copy. conversation_live.ex is 1793 lines (touch last/light).

### Token scale (research: tokens+components) — ADOPTED with brand override
3 tiers: primitives → semantic aliases → minimal component tokens. Component CSS refs semantic
tokens only; CSS file uses baked `var(--cl-x, #hex)` fallbacks for self-containment (brand gate only
scans `.ex`, so fallbacks in `.css` are fine — templates use bare `var()`/`.cl-*`).
- Spacing: `--cl-space-0..11` = 0/2/4/8/12/16/20/24/32/40/48/64 (+ gutter/stack/inline aliases).
- Type: paired size+leading tokens — title 28/36, panel 18/26, body 15/24, small 13/20, micro 12/18,
  code 13/22; weights 400/500/600 (no 700 — too loud for operator UI).
- **Radius: KEEP existing brand-tuned sm6/md10/lg14** (brand §10.2 cards ~10-12px, NOT research's
  4/6/8). ADD `xs 4` (nested inputs/tags) + `full 9999`. Don't churn existing values.
- Shadow: keep `--cl-shadow-raised`; ADD ramp `--cl-shadow-1..4` + aliases card/overlay/modal.
  Borders-first; shadow only for lifted/overlay surfaces.
- Z-index: NAMED layers, 100-gaps — base0 / dropdown1000 / sticky1100 / overlay1200 / modal1300 /
  popover1400 / toast1500. Never raw z-index in `.cl-*`.
- Control sizes: sm28 / md36(default) / lg44 height; px 10/14/20. Inputs+buttons share heights.
- Focus ring token (2px offset halo). Status = color+icon+text triplets (surface/border/text per
  status); never color-alone (§7.5). a11y per WAI-ARIA APG (dialog focus-trap/Esc/restore, roving
  tabindex menus/tabs, real `<button>`/`<table>`).
- Component selection (least-surprise): inline-expand default → modal only when blocking → drawer
  for record detail → page when it deserves a URL; table for operator data; tabs ≤6; pagination not
  infinite scroll; banners for actionable errors, toasts for transient confirmations only.

### IA / Cockpit Home (research: GDS) — ADOPTED
Frame each persona block as an explicit user-need (`As a [persona] I need [X] so that [outcome]`).
Home = router not data-wall: ~5 verb-led job cards, each = verb headline + ONE actionable
"needs-you"-scoped live count (passes the Decision Test) + primary CTA; signed-in persona first.
Counts actionable only (no vanity totals; ≤12 metrics). Empty = calm success ("all caught up").
Persistent nav shell, ~5-7 destinations (Home/Inbox/Knowledge/Audit/Settings), 3-cue "you are here"
(active item + matching page heading + breadcrumbs), user's-words labels + count badges (no
mystery-meat). Progressive disclosure: ONE surface, guided default ("needs you" pre-applied) +
quiet first-class power paths (keyboard, deep-links, bulk); never a novice/expert mode split; never
hide safety/governance counts. Thread the causal graph (gap→causing conversations, action→audit,
detail views end with next-step; bi-directional). No dead-ends, no modal traps.

## Baseline test failures (PRE-EXISTING, not mine — do not count as regressions)
Full `mix test` shows 2 failures, both in files untouched by this work:
1. `Cairnloop.Automation.DraftTest` — the documented M005-drift baseline (per memory).
2. `Cairnloop.Workers.OutboundWorkerTest:93` — static source-grep test for D-11 `unique:` keys;
   independent of UI. (Memory only recorded #1; #2 is also pre-existing — UI diff can't affect it.)
My changes are isolated to web/CSS/router; all web + new tests pass.

## Open questions / risks
- CSS delivery to adopter runtime: ship at `priv/static/cairnloop.css`; document host serving
  (Plug.Static from dep priv, or bundler import, or Igniter copy). Decide in Pass 1.
- Single-source-of-truth for tokens vs the example app's Tailwind `@theme` block (avoid drift).
