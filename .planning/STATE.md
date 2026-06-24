---
gsd_state_version: 1.0
milestone: vM017
milestone_name: Brand Identity System, Token Evolution & HTML Brand Book
status: planning
last_updated: "2026-06-24T12:47:53.715Z"
last_activity: 2026-06-24 — Phase 47 context gathered (selection gate complete)
progress:
  total_phases: 7
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
  percent: 14
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-06-23 — vM017 active)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Phase 47 — brand-direction-exploration-selection-gate

## Current Position

Phase: 47 — Brand Direction Exploration [SELECTION GATE]
Plan: Not started — context gathered, ready for `/gsd-plan-phase 47`
Status: Selection gate COMPLETE — owner locked logo C3·6 (crowning-loop cairn) + Refined palette + current type stack (Atkinson/Fraunces/Martian)
Last activity: 2026-06-24 — Phase 47 context + discussion log captured

Progress: ░░░░░░░░░░ 0% (0/7 phases · 0/? plans)

## Accumulated Context

### Decisions (carried — project-level)

5 patterns are project-level architectural invariants (see `PROJECT.md` "## Architectural
Invariants"): (1) sealed-contract + additive-opts, (2) snapshot-at-decision, (3) fail-closed
envelope-boundary cap, (4) three-layer at-most-once, (5) Governance-facade reads from the web
layer. Subagents read these from `PROJECT.md`.

vM015 additions (see PROJECT.md Key Decisions): release-please release pipeline; audit-against-
live-source as the milestone gate (move it before the release tag); test-only security closure
for already-correct domain code; `release_gate` gates on the green integration suite.

vM016 ratified decisions (do not re-litigate; vM016 is PARKED — resume after vM017 ships):

- **D1 (Home):** two-tier primacy — hero "Work the queue" + secondary "Tend the trail" band;
  `cl_stat` de-polymorphized to numeric-only; `cl_hero` for the primary count; health as `cl_chip`;
  copper = route marker (70/20/10 palette); `safe/2` fail-closed counts retained; scoped count
  queries + throttle to avoid per-PubSub-tick re-query.

- **D2 (Rail):** native `<details>`/`<summary>` for all per-card progressive disclosure (no
  server assigns for open state — PubSub reloads must not snap panels shut); Tier 1 (safety
  quartet + pending footer) never collapses; `Phoenix.LiveView.JS` only for rail-level controls
  and localStorage density toggle.

- **D3 (Responsive):** mobile-first `min-width` authoring; breakpoints 640/768/1024 as literal
  constants in one CSS comment block — NOT tokenized as `var()` (silent no-op in `@media`);
  `--cl-content-max`/`--cl-rail-width`/`--cl-page-gutter` layout tokens added; CSS architecture
  stays BEM + `.cl-` utilities, no Tailwind, no build step.

- **Gate hardening:** brand-token gate extended to catch inline `style="…#hex…"`, raw `rgba()/hsl()`,
  and helper-returned hex in render `.ex` files; magic-comment allowlist; `.css` file stays unscanned;
  complementary Credo check is dev-time only — ExUnit gate is CI truth.

- **Motion:** transform + opacity only; `prefers-reduced-motion` honored live; never on reply-send,
  keystrokes, count ticks, or layout properties.

- **Verification policy — rendered-behavior checkpoints are GATED E2E, never human-verify
  (ratified 2026-06-04, owner directive "automate the world / 0 human UAT"):** Any phase check that
  needs a real browser (rendered geometry, tap-target hit area, sticky/scroll occlusion, animation,
  client-only JS) MUST be authored as a Playwright E2E in
  `examples/cairnloop_example/test/e2e/*_test.exs` (`PhoenixTest.Playwright.Case`, `@moduletag :e2e`,
  `evaluate/3` for `getBoundingClientRect()`/`getComputedStyle()`; set viewport via
  `browser_context_opts: [viewport: %{...}]`). The gated `e2e` release-gate job runs them on every
  push (`mix test.e2e` auto-discovers the file — no CI-config change). Do NOT plan `autonomous:
  false` human-verify tasks for these. Precedent: Phase 41 (`rail_disclosure_test.exs`), Phase 42
  (`thread_navigation_test.exs`), Phase 43 (`inbox_geometry_test.exs`). Phases 44 (Motion) / 45
  inherit this default.

**vM017 locked decisions (D-A / D-B / D-C — from approved plan `~/.claude/plans/brand-book-pressure-test-abundant-dragonfly.md`):**

- **D-A — Core system REOPENED:** shipped `--cl-` palette and Atkinson/Fraunces/Martian type stack
  are treated as a seed, not gospel. The milestone may re-explore core hues and the UI font stack
  and propagate the chosen evolution across the canonical source + mirrors + example app, with full
  re-verification. Evolution is additive (value-changes + new tokens, never renames that break the
  sealed brand-token gate). Done once, carefully.

- **D-B — Collateral WIRED IN:** final phase replaces the example-app logo
  (`examples/cairnloop_example/priv/static/images/logo.svg`), updates favicon + `og:image` in
  `root.html.heex`, and adds an SVG logo header to `README.md` (repo-relative path, GitHub-renderable).

- **D-C — 4 logo directions** authored for selection; one is the mandatory fully-integrated custom
  typemark (the `oo`→loop motif worked into the wordmark).

- **Logo constraints (non-negotiable):** no rectangular background cage (transparent /
  boundary-breaking marks are default); logomark + logotype visually **unified** and close (NOT
  "icon left of plain text"); primary lockup has **no subtitle/tagline** (separate optional tagline
  lockup allowed); hand-authored SVG, not clipart.

- **Two human selection gates:**
  1. **Brand-direction gate** (end of Phase 47): owner selects logo direction, palette variant, and
     type direction. Subjective — never auto-selected or E2E'd.

  2. **Logo-family sign-off** (implicit, before Phase 52 wiring): owner reviews finalized asset
     family before it is wired into live surfaces.

- **Repo hygiene:** `brandbook/` self-contained; SVG/HTML/CSS/JSON/MD only; raster permitted **only**
  for favicon `.ico`/PNG + one OG `.png` (total raster budget ≤~150KB); rejected directions deleted
  after selection; `brandbook/` stays git-tracked but **out of the hex package** (`mix.exs` `files`
  unchanged).

- **Token evolution discipline:** `priv/static/cairnloop.css` `:root` is the single canonical
  source; `brandbook/assets/css/tokens.css` is derived (not forked); `examples/cairnloop_example/
  assets/css/app.css` `@theme` and `prompts/cairnloop.tokens.json` are documented derivatives.
  Never create a 4th palette copy.

- **Phase dependencies:**
  46→47→{48, 49} (both 48 and 49 depend on Phase 47 selection)
  48→50 (token derivation requires evolved tokens locked)
  {49, 50}→51 (brand book assembly requires logo assets + scaffold)
  {49, 51}→52 (wiring requires logo assets + brand book complete)

### Pending Todos

- None outstanding. vM016 PARKED cleanly at 54% (7/13 phases). Phase 44 is planned and ready;
  Phase 45 is unplanned and must consume vM017's final brand. See
  `.planning/milestones/vM016-PARKED.md` for resume steps.

### Blockers/Concerns

- Phase 47 ends in a subjective human selection gate — the milestone deliberately pauses there.
  This is by design, not a blocker.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| ~~Verification~~ | ~~Phases 33/34/35 missing VERIFICATION/VALIDATION~~ | Resolved — backfilled at vM015 close | — |
| ~~Process~~ | ~~vM014 missing MILESTONES/RETROSPECTIVE entry~~ | Resolved — record backfilled at vM015 close | — |
| UAT (vM014) | Phase 27 `27-HUMAN-UAT.md` — 2 pending scenarios | Acknowledged/deferred (SATD: archived, not reconstructed) | vM015 close |
| Verification (vM014) | Phase 28 `28-VERIFICATION.md` — human_needed | Acknowledged/deferred | vM015 close |
| Verification (vM014) | Phase 30 `30-VERIFICATION.md` — human_needed | Acknowledged/deferred | vM015 close |
| Scope | Epic 13 Privacy-First Local AI (Nx/Bumblebee) | Deferred to vM016+ | vM015 planning |
| Scope | Epic 12 Advanced Routing & Team Collaboration | Deferred to vM016+ | vM015 planning |
| Scope | Epic 14 Mobile SDK Surface | Deferred to vM016+ | vM015 planning |
| Tech Debt | Centralize duplicated fail-closed search guards | Open | vM009 retrospective |
| v2 (vM016) | PHONE-01..04 phone-optimized patterns (tabbed layout, card-transform tables, off-canvas nav, container queries) | Deferred to v2 | vM016 planning |
| v2 (vM016) | AMOTION-01..02 advanced motion motifs (route-line draw, FLIP list reorder) | Deferred to v2 | vM016 planning |
| vM017 (Brand) | Animated/interactive brand book (motion specimens, live token playground) | Deferred | vM017 planning |
| vM017 (Brand) | Marketing landing-page build-out (beyond README header + OG card) | Separate effort | vM017 planning |
| vM017 (Brand) | Self-hosted web-font subsetting for true offline specimens | Defer unless chosen type direction requires it | vM017 planning |
| vM017 (Brand) | Logo motion/lottie variants, presentation/slide templates, sticker/swag assets | Out of this milestone | vM017 planning |

## Session Continuity

**vM017 Brand Identity System, Token Evolution & HTML Brand Book is active** (phases 46–52).
Roadmap defined 2026-06-23 from the ratified
`~/.claude/plans/brand-book-pressure-test-abundant-dragonfly.md`. Latest published release:
**v0.5.1** on Hex.pm. Product remains "done enough for stated scope."

**Roadmap:** 7 phases (46–52), 24 v1 requirements, all mapped:

- FIDELITY-01, FIDELITY-02, FIDELITY-03 → Phase 46
- LOGO-01, LOGO-02, LOGO-03, TOKEN-01 → Phase 47
- TOKEN-02, TOKEN-03, TOKEN-04 → Phase 48
- LOGO-04, LOGO-05, LOGO-06 → Phase 49
- BOOK-01, BOOK-02 → Phase 50
- BOOK-03, BOOK-04, BOOK-05 → Phase 51
- WIRE-01, WIRE-02, WIRE-03, HYGIENE-01, HYGIENE-02, HYGIENE-03 → Phase 52

**Phase ordering rationale:** audit-first (46) → explore/select (47, GATE) → evolve tokens (48) +
finalize logo (49, parallel after gate) → brandbook scaffold (50, after 48) → full book (51, after
49+50) → wire+QA (52, after 49+51). The milestone pauses at Phase 47 for the owner's pick.

**vM016 PARKED at 54%** — phases 37–43 complete, Phase 44 (motion) planned and ready to execute,
Phase 45 unplanned (must consume vM017's final brand). Resume via
`.planning/milestones/vM016-PARKED.md` after vM017 ships.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| (vM017 phases not yet started) | | | |
| Phase 46 P01 | 8min | 3 tasks | 2 files |

## Decisions

(vM017 decisions will be recorded here as phases execute)

- [Phase ?]: Phase 46 audit decisions
- [Phase ?]: Phase 46 brand fidelity audit complete
- [Phase ?]: 46-D02: priv/static/cairnloop.css :root is the single canonical token source; derivatives documented with provenance notes
- [Phase ?]: 46-Open-Q: dark --cl-warning == dark --cl-primary (#D98A4A) — Phase 47 must sign off
