---
gsd_state_version: 1.0
milestone: vM019
milestone_name: OSS Trust Baseline
status: Awaiting next milestone
stopped_at: Phase 61 context gathered
last_updated: "2026-07-01T14:37:00.314Z"
last_activity: 2026-07-01
last_activity_desc: Milestone vM019 completed and archived
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 27
  completed_plans: 27
  percent: 100
current_phase: null
current_phase_name: none
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-07-01 — vM019 OSS Trust Baseline closed)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Awaiting next milestone.

## Current Position

Phase: None
Plan: —
Status: Awaiting next milestone
Last activity: 2026-07-01 — Milestone vM019 completed and archived

## Accumulated Context

### Decisions (carried — project-level)

vM019 OSS Trust Baseline decisions (2026-06-29 kickoff):

- **Weakest dimension focus:** Treat host-app compatibility/adoption trust as the primary risk, not
  raw feature count. Cairnloop must behave like a respectful guest in a Phoenix/Ecto app before new
  product-surface work resumes.

- **Dedicated schema default:** New installs default Cairnloop support-domain tables to the Postgres
  schema prefix `cairnloop`. Existing public-schema installs remain supported only through explicit
  compatibility config and upgrade docs. Oban remains host-owned and is not moved by Cairnloop.

- **No `mix ecto.migrate --prefix` shortcut:** Prefix support must be implemented in Cairnloop's
  generated migrations/runtime helpers so `schema_migrations` and host tables are not accidentally
  redirected.

- **Side effects opt-in:** Optional external/Scrypath automation must be inert unless explicitly
  enabled by the host app.

- **Docs are quality surface:** README, ExDoc, installer output, SECURITY, UPGRADING, examples, and
  troubleshooting are first-class quality gates for this milestone.

- **CI changes must be evidence-backed:** Optimize CI for deterministic signal and maintainer DX
  before clever speedups. Do not remove slow checks unless their risk/value is understood.

5 patterns are project-level architectural invariants (see `PROJECT.md` "## Architectural
Invariants"): (1) sealed-contract + additive-opts, (2) snapshot-at-decision, (3) fail-closed
envelope-boundary cap, (4) three-layer at-most-once, (5) Governance-facade reads from the web
layer. Subagents read these from `PROJECT.md`.

vM015 additions (see PROJECT.md Key Decisions): release-please release pipeline; audit-against-
live-source as the milestone gate (move it before the release tag); test-only security closure
for already-correct domain code; `release_gate` gates on the green integration suite.

vM016 ratified decisions (archived; do not re-litigate when maintaining shipped UI):

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
  keystrokes, count ticks, or layout properties. Phase 44 shipped CSS-only motion for hero count,
  evidence rail, state chips, list stagger, and toasts. Route-line / marker-travel remains v2
  AMOTION-01.

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

- Start the next milestone with `/gsd-new-milestone` before any new phase work.
- Make the pre-milestone repo hygiene pass a repeatable habit before substantial new milestones:
  clean local worktrees, triage GitHub PRs, verify main CI, review `[Unreleased]`, and confirm GSD
  is between milestones. Keep Hex.pm publishing as a separate explicit opt-in.
- Inspect live GitHub Actions branch protection, hosted-runner timing/cache behavior, and release
  artifacts after the next PR/main/release run.

### Blockers/Concerns

- GSD local agent registry reports missing role agents in this environment. Use available subagent
  tools or inline execution, but preserve GSD artifacts and evidence gates.

- The worktree contains pre-existing dirty files. Do not revert unrelated changes; work with them.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| ~~Verification~~ | ~~Phases 33/34/35 missing VERIFICATION/VALIDATION~~ | Resolved — backfilled at vM015 close | — |
| ~~Process~~ | ~~vM014 missing MILESTONES/RETROSPECTIVE entry~~ | Resolved — record backfilled at vM015 close | — |
| UAT (vM014) | Phase 27 `27-HUMAN-UAT.md` — 2 pending scenarios | Acknowledged/deferred (SATD: archived, not reconstructed) | vM015 close |
| Verification (vM014) | Phase 28 `28-VERIFICATION.md` — human_needed | Acknowledged/deferred | vM015 close |
| Verification (vM014) | Phase 30 `30-VERIFICATION.md` — human_needed | Acknowledged/deferred | vM015 close |
| Scope | Epic 13 Privacy-First Local AI (Nx/Bumblebee) | Deferred to future adopter-pulled milestone | vM015 planning |
| Scope | Epic 12 Advanced Routing & Team Collaboration | Deferred to future adopter-pulled milestone | vM015 planning |
| Scope | Epic 14 Mobile SDK Surface | Deferred to future adopter-pulled milestone | vM015 planning |
| Tech Debt | Centralize duplicated fail-closed search guards | Open | vM009 retrospective |
| v2 (vM016) | PHONE-01..04 phone-optimized patterns (tabbed layout, card-transform tables, off-canvas nav, container queries) | Deferred to v2 | vM016 planning |
| v2 (vM016) | AMOTION-01..02 advanced motion motifs (route-line draw, FLIP list reorder) | Deferred to v2 | vM016 planning |
| vM017 (Brand) | Animated/interactive brand book (motion specimens, live token playground) | Deferred | vM017 planning |
| vM017 (Brand) | Marketing landing-page build-out (beyond README header + OG card) | Separate effort | vM017 planning |
| vM017 (Brand) | Self-hosted web-font subsetting for true offline specimens | Defer unless chosen type direction requires it | vM017 planning |
| vM017 (Brand) | Logo motion/lottie variants, presentation/slide templates, sticker/swag assets | Out of this milestone | vM017 planning |

## Session Continuity

**Last session:** 2026-07-01T14:37:00.314Z
**Stopped at:** vM019 milestone archived
**Resume file:** none — start next milestone with `/gsd-new-milestone`

**vM019 OSS Trust Baseline is complete and archived**
(`.planning/milestones/vM019-*`). Latest published release remains **v0.5.1** on Hex.pm.
Product remains "done enough for stated scope."

**vM017 Brand Identity System, Token Evolution & HTML Brand Book is complete and archived**
(`.planning/milestones/vM017-*`). Latest published release: **v0.5.1** on Hex.pm.
Product remains "done enough for stated scope."

**vM016 Operator UI/UX Iteration is complete and archived** (`.planning/milestones/vM016-*`).
No phase is active.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| vM017 | all phases | Complete | phases 46-52 archived and verified |
| vM016 | phases 37-45 | Complete | 36 plans complete; milestone archived |
| Phase 44 | 4 plans | Complete | CSS-only motion + E2E/reduced-motion proof |
| Phase 46 P01 | 8min | 3 tasks | 2 files |
| Phase 47 P01 | 28 min | 3 tasks | 1 files |
| Phase 47 P02 | 23 min | 3 tasks | 3 files |
| Phase 49 P02 | 4min | 3 tasks | 7 files |
| Phase 49 P01 | 6min | 2 tasks | 7 files |
| Phase 49 P03 | 8min | 3 tasks | 5 files |
| Phase 50 P01 | 12min | 3 tasks | 10 files |
| Phase 51 P01 | 8 min | 2 tasks | 3 files |
| Phase 51 P02 | 7 min | 2 tasks | 3 files |
| Phase 51 P03 | 6 min | 2 tasks | 3 files |
| Phase 52 P01 | 3 min | 3 tasks | 3 files |
| Phase 52 P02 | 7 min | 2 tasks | 9 files |
| Phase 52 P03 | 4 min | 2 tasks | 1 files |
| Phase 53 P02 | 8 min | 2 tasks | 5 files |
| Phase 53 P01 | 4 min | 2 tasks | 0 files |
| Phase 53 P03 | 3 min | 2 tasks | 3 files |
| Phase 53 P04 | 5 min | 2 tasks | 0 files |
| Phase 53 P05 | 8 min | 2 tasks | 4 files |
| Phase 54 P01 | 5 min | 2 tasks | 1 files |
| Phase 54 P02 | 16 min | 3 tasks | 2 files |
| Phase 54 P03 | 24 min | 2 tasks | 0 files |
| Phase 56 P01 | 8 min | 2 tasks | 3 files |
| Phase 58 P01 | 10 min | 2 tasks | 8 files |
| Phase 58 P04 | 12 min | 3 tasks | 8 files |
| Phase 58 P05 | 7 min | 3 tasks | 5 files |
| Phase 58 P02 | 9 min | 2 tasks | 11 files |
| Phase 58 P03 | 37min | 3 tasks | 3 files |
| Phase 58 P06 | 6 min | 2 tasks | 7 files |
| Phase 58 P07 | 8 min | 2 tasks | 9 files |
| Phase 59 P01 | 10 min | 2 tasks | 6 files |
| Phase 59 P02 | 6 min | 2 tasks | 8 files |
| Phase 59 P03 | 15 min | 2 tasks | 16 files |
| Phase 59 P08 | 7 min | 2 tasks | 11 files |
| Phase 59 P09 | 8 min | 1 tasks | 9 files |
| Phase 59 P04 | 28 min | 2 tasks | 8 files |
| Phase 59 P05 | 11 min | 3 tasks | 10 files |
| Phase 59 P06 | 8 min | 2 tasks | 9 files |
| Phase 59 P10 | 11 min | 1 tasks | 16 files |
| Phase 59 P07 | 22 min | 3 tasks | 2 files |
| Phase 61 P01 | 20 min | 3 tasks | 2 files |
| Phase 61 P02 | 8 min | 3 tasks | 2 files |
| Phase 61 P03 | 4 min | 3 tasks | 2 files |
| Phase 61 P04 | 6 min | 3 tasks | 2 files |
| Phase 61 P05 | 10 min | 3 tasks | 2 files |

## Decisions

vM017 and vM016 decisions are archived. The vM016 decisions below remain maintenance constraints for the shipped operator UI.

- [Phase 44]: Motion is CSS-only for v1 surfaces: hero count entrance, evidence-rail reveal,
  `.cl-motion-state` status cross-fade, inbox list stagger, and `cl_flash` toast enter/exit.
  Route-line / marker-travel stays deferred to AMOTION-01.

- [Phase 44]: Example app motion CSS is not duplicated; it imports canonical
  `priv/static/cairnloop.css`, and the guardrail rejects a forked motion copy.

- [Phase 44]: Brandbook assembly is archive-aware for vM017 Phase 48 contrast evidence after
  milestone closeout (`.planning/milestones/vM017-phases/...` fallback).

- [Phase ?]: Phase 46 audit decisions
- [Phase ?]: Phase 46 brand fidelity audit complete
- [Phase ?]: 46-D02: priv/static/cairnloop.css :root is the single canonical token source; derivatives documented with provenance notes
- [Phase ?]: 46-Open-Q: dark --cl-warning == dark --cl-primary (#D98A4A) — Phase 47 must sign off
- [Phase 49]: 49-02: Use filled donut path geometry for favicon/OG rings so SVG and ImageMagick raster outputs preserve the C3.6 ring-as-top-stone read. — Stroked SVG circles disappeared in ImageMagick raster output during preview; filled path geometry kept renderer behavior consistent.
- [Phase 49]: 49-02: LOGO-05 raster footprint is 32KB total for favicon PNG/ICO plus OG PNG, under the 150KB milestone budget. — du -ck logo/*.png logo/*.ico reported 32 total after all exports.
- [Phase 49]: 49-01: Use manually approximated Fraunces-like SVG paths for the visible wordmark to avoid font drift in GitHub, HexDocs, and file:// contexts.
- [Phase 49]: 49-01: Keep the primary horizontal lockup subtitle-free; tagline use is isolated to logo/cairnloop-lockup-tagline.svg.
- [Phase 49]: 49-03: Logo-family sign-off remains a future owner gate before Phase 52 wiring, not a Phase 49 blocker.
- [Phase 49]: 49-03: Rejected contest HTML was deleted only after all production assets and logo/USAGE.md existed.
- [Phase 49]: 49-03: OG master uses path-authored wordmark geometry so the final SVG live-text gate passes.
- [Phase 50]: 50-01: Use scripts/derive_brandbook_tokens.exs as repo-local collateral tooling rather than a shipped Mix task.
- [Phase 50]: 50-01: Keep swatches.json lean: grouped primitive/light/dark rows with resolved display hex, no contrast badge matrix.
- [Phase 50]: 50-01: Verify direct file:// loading with the existing locked Playwright install under the example app instead of adding packages or Phoenix routing.
- [Phase 58]: 58-01: Persist browser/customer identity in customer_ref, not host_user_id. — TRUST-01 separates untrusted customer/session identity from signed-in operator/governance identity; legacy create_customer_conversation/1 host_user_id input is treated as customer-token compatibility input and existing installs get a nullable customer_ref upgrade path.
- [Phase 58]: Email webhook auth accepts a host verifier or shared token and fails closed when neither is configured. — TRUST-03 requires spoofed email webhook requests to stop before body parsing and enqueue.
- [Phase 58]: MCP initialize, tools/list, and tools/call are token-required; malformed JSON and unsupported non-token methods keep JSON-RPC error envelopes. — TRUST-04 requires no unauthenticated capability, tool metadata, or governed write exposure while preserving JSON-RPC semantics outside token-required methods.
- [Phase 58]: MCP raw tokens are documented as opaque copy-once values, not values with a fixed public prefix. — OPS-04 docs must match live token generation and avoid stale adopter debugging claims.
- [Phase 58]: Scrypath automation remains disabled unless :scrypath_automation_enabled is true and both API URL and API key are non-placeholder values. — OPS-01/OPS-02 keep optional external side effects inert by default and fail closed under unsafe config.
- [Phase 58]: The conversation-resolved Scrypath bridge enqueues only conversation_id; support content is fetched inside the ready worker path. — Prevents raw support body forwarding through generic telemetry metadata.
- [Phase 58]: Disabled and misconfigured Scrypath worker jobs discard before Req client construction or external HTTP. — Unsafe default URL/key values never reach Req.post/2.
- [Phase 58]: 58-02: Widget ingress uses an explicit :widget_token_verifier module or {module, opts}; absent or invalid config fails closed through FailClosed. — TRUST-02 requires production widget ingress to reject unverified browser tokens while preserving host-owned customer auth.
- [Phase 58]: 58-02: Cairnloop.Widget.Verifier.Demo is only active through explicit demo/test config. — Demo acceptance must remain intentional and never become an implicit accept-any-token production path.
- [Phase 58]: 58-02: WidgetChannel joins use socket.assigns.customer_ref as browser/customer identity and never copy widget identity into host_user_id. — TRUST-01 keeps host_user_id reserved for operator/governance identity while preserving customer conversation creation.
- [Phase 58]: 58-03: ConversationLive operator actions use dashboard session host_user_id only; missing actor withholds side effects with persistent trust-state UI.
- [Phase 58]: 58-06: Conversation resolve telemetry carries conversation_id plus bounded lifecycle labels, not actor/customer/operator IDs, raw metadata, support bodies, payloads, secrets, or full structs. — TRUST-05 requires default telemetry to exclude support content and unsafe metadata while preserving the durable pointer required by the ready Scrypath bridge.
- [Phase 58]: 58-06: The Scrypath bridge continues to rely on conversation_id as a durable pointer; support content is fetched inside the enabled worker path. — Phase 58-05 established ready-only Scrypath side effects and worker-side durable content fetches, so generic telemetry must not become a content transport.
- [Phase 58]: 58-06: The default unhandled-email worker log is static diagnostic text and never interpolates inbound content or raw payload details. — D-07 and D-09 require default logs to avoid support message bodies and raw provider payloads while still telling operators that email ingress is unhandled.
- [Phase 58]: 58-07: /health remains liveness-only; doctor and docs carry richer readiness/trust truth. — D-13 keeps /health shallow while D-14 makes doctor the operational trust surface.
- [Phase 58]: 58-07: Doctor reports only what it can prove locally and labels DB, Oban queue, pgvector index, Scrypath reachability, and stored MCP token rows as not checked here. — Doctor must not claim dependency checks it did not run.
- [Phase 58]: 58-07: Public docs use bounded telemetry examples with conversation_id and no support bodies, secrets, raw payloads, full conversation structs, or actor/customer IDs. — TRUST-05 requires default telemetry/docs to avoid support content and unsafe identity metadata.

## Operator Next Steps

- Run a pre-milestone repo hygiene pass before substantial new milestone work.
- Start the next milestone with /gsd-new-milestone
