# Roadmap: Cairnloop

## Milestones

- 🚧 **vM017 Brand Identity System, Token Evolution & HTML Brand Book** — Phases 46–52 (active, started 2026-06-23)
- ⏸ **vM016 Operator UI/UX Iteration** — Phases 37–45 (PARKED at 54%; phases 37–43 complete, 44 planned/ready, 45 unplanned; resume after vM017 ships)
- ✅ **vM015 Operator Polish + Maintenance Gates** — Phases 33–36 (shipped 2026-05-30, v0.2.0–v0.2.2)
- ✅ **vM014 Adoption Proof** — Phases 27–32.1 (shipped 2026-05-29)
- ✅ **vM013 Support-Triggered Outbound Lifecycle** — Phases 22–26 (shipped 2026-05-27)
- ✅ **vM012 Public Release & MCP Write Surface** — Phases 18–21 (shipped 2026-05-26)
- ✅ **vM011 AI Tool Governance & MCP Integration** — Phases 13–17 (shipped 2026-05-25)
- ✅ **vM010 KB AI Maintenance** — (shipped 2026-05-23)
- ✅ **vM009 Retrieval-First Support Answers & Search Ops** — (shipped 2026-05-21)
- ✅ **vM003–vM008** — foundational milestones (archived)

> **Release history:** v0.4.0 (operator design system: `cairnloop.css` + `Cairnloop.Web.Components`
> + Cockpit Home/nav), v0.5.0 (`Automation.DraftGenerator` seam + Anthropic adapter — draft path
> no longer a mock), v0.5.1 (operator-identity `host_user_id` fix + installer fix) all shipped
> outside formal GSD milestone numbering since vM015 close. **Current published version: cairnloop
> v0.5.1 on Hex.pm.** vM016 is PARKED mid-flight (54%) to sequence brand work first. vM017
> reopens/evolves core palette + type (D-A) and produces the real logo system + HTML brand book.

## Phases

### 🚧 vM017 Brand Identity System, Token Evolution & HTML Brand Book (Phases 46–52) — ACTIVE

- [ ] **Phase 46: Brand Fidelity Audit & Token Consolidation** - Discrepancy ledger, canonical `:root` source, WCAG-AA contrast baseline
- [ ] **Phase 47: Brand Direction Exploration [SELECTION GATE]** - 4 SVG logo directions + palette/type variants on direction-boards page; owner selects
- [ ] **Phase 48: Token Evolution: Lock & Propagate** - Apply chosen palette/type to canonical `:root`; propagate to example-app + tokens.json; re-verify gates
- [ ] **Phase 49: Chosen-Logo Finalization & Asset Family** - Full optimized-SVG family, favicon, OG card, clearspace/min-size spec
- [ ] **Phase 50: Brandbook Scaffold & Token-Derivation Pipeline** - Self-contained `brandbook/` skeleton; `tokens.css` derived (not forked) from canonical `:root`
- [ ] **Phase 51: Full HTML Brand Book Assembly** - All sections as live HTML: swatches, type specimens, logo system, do/don't, light/dark toggle
- [ ] **Phase 52: Collateral Wiring + QA/Validation Sweep** - Wire logo into README + example app + favicon + OG; SVG/contrast/hygiene QA; gated Playwright E2E

<details>
<summary>⏸ vM016 Operator UI/UX Iteration (Phases 37–45) — PARKED at 54%</summary>

- [x] **Phase 37 — Component Primitives** — `cl_page`, `cl_hero`/`cl_stat` split, `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch` + layout tokens + inert-utility and `.cl-table` scroll-wrapper fixes (completed 2026-06-03)
- [x] **Phase 38 — Shared Page-Shell Migration** — All operator screens (Home/Inbox/Audit/Settings/KB) rendered through `cl_page`; `cl_breadcrumb` wired on the deep KB-from-conversation path (4 plans, 2 waves) (completed 2026-06-04)
- [x] **Phase 39 — Home Primacy Redesign (D1)** — Two-tier hero + calmer secondary band; health-as-chip; count-color semantics fix; Recover-resolved filter CTA fix; zero-state; count queries + throttle (completed 2026-06-04)
- [x] **Phase 40 — Drift Remediation + Brand-Token Gate Hardening** — hex→token in `conversation_live`/`search_modal`; hardened gate fails on inline `style="…#hex…"`, raw `rgba()`, helper-returned hex; complementary Credo check
- [x] **Phase 41 — Conversation Rail Progressive Disclosure (D2)** — Safety-pinned native-`<details>` accordion (decisions first; Tier 1 never collapses; Tier 2/3 collapsible; auto-expand blocking; density toggle) (completed 2026-06-04)
- [x] **Phase 42 — Cross-Screen Threading** — Next-in-queue; audit-row→conversation; governed-action→audit; article→originating-conversation (completed 2026-06-04)
- [x] **Phase 43 — Responsive Desktop-First Cockpit (D3)** — Mobile-first normalization; 768 tablet breakpoint; accessible table scrollers; conversation stacking; tap targets ≥44px (completed 2026-06-04)
- [ ] **Phase 44 — Motion** — Restrained brand motion (§15); `prefers-reduced-motion` honored live; transform+opacity only (PLANNED & READY — 4 plans / 3 waves)
- [ ] **Phase 45 — Seed Enrichment + Screenshot Regen + Verification Sweep** — Full-state seed; light+dark screenshots; `mix test` green (NOT YET PLANNED — must consume vM017's final brand)

See `.planning/milestones/vM016-PARKED.md` for resume instructions.

</details>

<details>
<summary>✅ vM015 Operator Polish + Maintenance Gates (Phases 33–36) — SHIPPED 2026-05-30</summary>

- [x] Phase 33: Security Domain Closure (1/1 plans) — completed 2026-05-29
- [x] Phase 34: Operator Settings Surface (2/2 plans) — completed 2026-05-29
- [x] Phase 35: Audit & Operations Support (2/2 plans) — completed 2026-05-29
- [x] Phase 36: Documentation & v0.2.0 Release (1/1 plan) — completed 2026-05-29

Released as `cairnloop` v0.2.0 → v0.2.1 → v0.2.2 on Hex.pm. Full detail:
`.planning/milestones/vM015-ROADMAP.md`.

</details>

<details>
<summary>✅ vM003–vM014 — SHIPPED (archived)</summary>

Earlier milestone roadmaps are archived under `.planning/milestones/` (e.g.
`vM014-ROADMAP.md`, `vM013-ROADMAP.md`, …). See `.planning/MILESTONES.md` for the shipped
summary of every milestone and `.planning/PROJECT.md` for the cumulative product state.

</details>

## Phase Details

### Phase 46: Brand Fidelity Audit & Token Consolidation
**Goal**: The shipped brand system is pressure-tested against the text seed and all palette copies collapse into one canonical source — making token evolution safe to run once and right
**Depends on**: Nothing (first vM017 phase; pure analysis + file reconciliation)
**Requirements**: FIDELITY-01, FIDELITY-02, FIDELITY-03
**Success Criteria** (what must be TRUE):
  1. A written discrepancy ledger exists documenting every drift between `prompts/cairnloop_brand_book.md`, `prompts/cairnloop.tokens.json`, and the live `--cl-*` values in `priv/static/cairnloop.css` — nothing is left as a mental note.
  2. `priv/static/cairnloop.css` `:root` is established as the single canonical token source; the example-app `assets/css/app.css` `@theme` block and `cairnloop.tokens.json` are documented as derivatives of it (not independent sources).
  3. A WCAG-AA contrast baseline table covers every foreground/background brand pairing used in the operator UI and brand book, with any failures explicitly flagged — this table is reused as brand-book content in Phase 51.
**Plans**: TBD

### Phase 47: Brand Direction Exploration [SELECTION GATE]
**Goal**: The owner has concrete, rendered visual options — 4 hand-authored SVG logo directions plus palette and type variants — and makes a recorded subjective selection that unlocks Phases 48 and 49
**Depends on**: Phase 46 (canonical token source established before exploring palette evolution)
**Requirements**: LOGO-01, LOGO-02, LOGO-03, TOKEN-01
**Success Criteria** (what must be TRUE):
  1. Four genuinely distinct, hand-authored SVG logo directions exist — including one fully-integrated custom typemark (the `oo`→loop motif worked into the wordmark) — each with a transparent background, no rectangular cage, and mark + logotype visually unified.
  2. A local HTML "direction boards" page opens from `file://` and renders all four directions at 16/24/48/256px, in horizontal and vertical lockups, on light and dark surfaces — with explicit no-cage proof rows and 16px-legibility proof rows.
  3. Palette variants (current vs. 1–2 evolved tunings) and type direction alternatives are rendered alongside each logo direction on the direction boards page so choices read cohesively.
  4. The owner completes the selection gate: one logo direction, one palette variant, and one type direction are chosen; the selection and rationale are recorded durably in the phase DISCUSSION-LOG (this is a human decision, not an automated check).
**Plans**: TBD
**UI hint**: yes

### Phase 48: Token Evolution: Lock & Propagate
**Goal**: The chosen palette and type direction are applied once to the canonical `:root` and propagated cleanly to all derivative sources — with zero drift and full gate re-verification — so the brand system is evolution-complete and drift-proof
**Depends on**: Phase 47 (owner selection completed and recorded)
**Requirements**: TOKEN-02, TOKEN-03, TOKEN-04
**Success Criteria** (what must be TRUE):
  1. The chosen palette/type is applied to `priv/static/cairnloop.css` `:root` using value-changes and additive new tokens only — no `--cl-*` token is renamed (the sealed brand-token gate contract is unbroken).
  2. The evolved tokens are propagated to `examples/cairnloop_example/assets/css/app.css` `@theme` and `prompts/cairnloop.tokens.json` with zero drift — a diff confirms the values match the canonical `:root` exactly.
  3. The brand-token gate (`mix test`), the golden-path smoke test (`mix test.integration`), and the gated Playwright E2E (`mix test.e2e`) are all green after propagation.
  4. The WCAG-AA contrast baseline table from Phase 46 is re-verified against the evolved palette — all foreground/background pairings pass AA, or failures are explicitly documented with remediation.
**Plans**: TBD
**UI hint**: yes

### Phase 49: Chosen-Logo Finalization & Asset Family
**Goal**: The selected logo direction is production-ready as a complete, optimized SVG asset family — lockups, mono variants, icon, favicon, and OG card — with a written usage spec that prevents misuse
**Depends on**: Phase 47 (owner selection completed and recorded)
**Requirements**: LOGO-04, LOGO-05, LOGO-06
**Success Criteria** (what must be TRUE):
  1. The full optimized-SVG asset family exists: primary horizontal lockup (no subtitle), vertical/stacked lockup, icon-only mark, mono basalt-on-paper, mono paper-on-basalt, and a separate optional tagline lockup — all with mark and logotype visually unified on a shared grid.
  2. A separately-authored, simplified favicon (not a scaled-down master) exists in 16px and 32px SVG, with raster exports (`.ico` and PNG), plus an OG/social card (1200×630 SVG master and one rasterized PNG) — all within the ≤~150KB total raster budget.
  3. Logo usage rules (clearspace, minimum sizes, do/don't panels including no-cage and no-icon-left-of-text) are documented and ready to be rendered in the brand book.
  4. Rejected logo directions are deleted from the repo; the deletion and rationale are noted in the phase SUMMARY.
**Plans**: TBD

### Phase 50: Brandbook Scaffold & Token-Derivation Pipeline
**Goal**: A self-contained `brandbook/` folder skeleton opens from `file://` with no network dependency, and its `tokens.css` is provably derived from (not a fork of) the canonical `cairnloop.css` `:root`
**Depends on**: Phase 48 (evolved tokens locked in canonical `:root` before derivation)
**Requirements**: BOOK-01, BOOK-02
**Success Criteria** (what must be TRUE):
  1. `brandbook/index.html` opens from `file://` in a browser with no console errors and no failed-network requests — all paths are relative, fonts have graceful fallbacks.
  2. `brandbook/assets/css/tokens.css` is generated from (or documented as a mirror of) the canonical `priv/static/cairnloop.css` `:root`; `brandbook/TOKENS.md` explains the derivation and includes a regeneration note so a future maintainer can update it without forking.
  3. The `brandbook/` folder structure follows the approved layout (`index.html`, `assets/css/tokens.css`, `assets/css/brandbook.css`, `logo/`, `raster/`, `color/swatches.json`) and `brandbook/` does not appear in `mix.exs` `files` — it is git-tracked but unshipped.
**Plans**: TBD
**UI hint**: yes

### Phase 51: Full HTML Brand Book Assembly
**Goal**: The brand book is a complete, professional, standalone reference document that renders all brand identity content as live HTML — usable by any future contributor or designer without network access
**Depends on**: Phase 49 (logo asset family complete); Phase 50 (scaffold and token derivation in place)
**Requirements**: BOOK-03, BOOK-04, BOOK-05
**Success Criteria** (what must be TRUE):
  1. The brand book renders all token sections as live HTML — color swatches displaying hex value + token name + WCAG-AA contrast badges, real-font type specimens at each scale step, and spacing/radius/shadow/motion token tables reading from `tokens.css`.
  2. The brand book presents the chosen logo system: a lockup gallery at multiple sizes, clearspace and minimum-size diagrams, and explicit do/don't panels (including no-cage and no-icon-left-of-text) with download links to the committed SVG assets.
  3. Voice, microcopy, imagery, and motion guidance sections are rendered as live HTML (not prose-only stubs).
  4. A light/dark toggle works without network dependency; the brand book never communicates state by color alone — every status indicator pairs color with icon or text label.
**Plans**: TBD
**UI hint**: yes

### Phase 52: Collateral Wiring + QA/Validation Sweep
**Goal**: The chosen logo is wired into every committed real-world surface (README, example app, favicon, OG), and the full milestone QA sweep confirms SVG validity, contrast, hygiene, and rendered behavior via gated E2E — leaving no human-verify tasks outstanding
**Depends on**: Phase 49 (finalized SVG asset family); Phase 51 (brand book complete with logo system rendered)
**Requirements**: WIRE-01, WIRE-02, WIRE-03, HYGIENE-01, HYGIENE-02, HYGIENE-03
**Success Criteria** (what must be TRUE):
  1. The example app's placeholder logo is replaced with the chosen mark; favicon and `og:image` meta tags in `examples/cairnloop_example/priv/static` and `root.html.heex` are updated to use the new assets.
  2. `README.md` leads with the chosen SVG logo using a repo-relative path that renders correctly on GitHub (SVG sanitization validated).
  3. A gated Playwright E2E test (`mix test.e2e`) confirms the example app renders the new logo and favicon — this is not a human-verify task.
  4. Every committed SVG passes validity linting (well-formed XML, valid `viewBox`, no external references, no embedded raster, no editor metadata cruft) and total raster footprint (favicon + OG only) is within ≤~150KB.
  5. `brandbook/` is confirmed absent from `mix.exs` `files`; a `git diff --stat` report confirms changes are confined to `brandbook/` plus the intended wiring files; `mix test` is green.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 46. Brand Fidelity Audit & Token Consolidation | vM017 | 0/? | Not started | - |
| 47. Brand Direction Exploration [SELECTION GATE] | vM017 | 0/? | Not started | - |
| 48. Token Evolution: Lock & Propagate | vM017 | 0/? | Not started | - |
| 49. Chosen-Logo Finalization & Asset Family | vM017 | 0/? | Not started | - |
| 50. Brandbook Scaffold & Token-Derivation Pipeline | vM017 | 0/? | Not started | - |
| 51. Full HTML Brand Book Assembly | vM017 | 0/? | Not started | - |
| 52. Collateral Wiring + QA/Validation Sweep | vM017 | 0/? | Not started | - |
| 37. Component Primitives | vM016 | 5/5 | Complete | 2026-06-03 |
| 38. Shared Page-Shell Migration | vM016 | 4/4 | Complete | 2026-06-04 |
| 39. Home Primacy Redesign (D1) | vM016 | 3/3 | Complete | 2026-06-04 |
| 40. Drift Remediation + Brand-Token Gate Hardening | vM016 | 3/3 | Complete | 2026-06-04 |
| 41. Conversation Rail Progressive Disclosure (D2) | vM016 | 4/4 | Complete | 2026-06-04 |
| 42. Cross-Screen Threading | vM016 | 6/6 | Complete | 2026-06-04 |
| 43. Responsive Desktop-First Cockpit (D3) | vM016 | 3/3 | Complete | 2026-06-04 |
| 44. Motion | vM016 | 0/? | Not started | - |
| 45. Seed Enrichment + Screenshot Regen + Verification Sweep | vM016 | 0/? | Not started | - |
| 33. Security Domain Closure | vM015 | 1/1 | Complete | 2026-05-29 |
| 34. Operator Settings Surface | vM015 | 2/2 | Complete | 2026-05-29 |
| 35. Audit & Operations Support | vM015 | 2/2 | Complete | 2026-05-29 |
| 36. Documentation & v0.2.0 Release | vM015 | 1/1 | Complete | 2026-05-29 |

_Phases 1–32.1 (vM001–vM014) are complete and archived — see `.planning/milestones/`._
