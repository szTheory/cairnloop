# Roadmap: Cairnloop

## Milestones

- ACTIVE **vM016 Operator UI/UX Iteration** - Phases 37-45 (resumed 2026-06-26 after vM017 brand closeout)
- SHIPPED **vM017 Brand Identity System, Token Evolution & HTML Brand Book** - Phases 46-52 (shipped 2026-06-26; archived in `.planning/milestones/vM017-ROADMAP.md`)
- SHIPPED **vM015 Operator Polish + Maintenance Gates** - Phases 33-36 (shipped 2026-05-30, v0.2.0-v0.2.2)
- SHIPPED **vM014 Adoption Proof** - Phases 27-32.1 (shipped 2026-05-29)
- SHIPPED **vM013 Support-Triggered Outbound Lifecycle** - Phases 22-26 (shipped 2026-05-27)
- SHIPPED **vM012 Public Release & MCP Write Surface** - Phases 18-21 (shipped 2026-05-26)
- SHIPPED **vM011 AI Tool Governance & MCP Integration** - Phases 13-17 (shipped 2026-05-25)
- SHIPPED **vM003-vM010** - foundational milestones (archived)

> vM017 is complete and archived. vM016 is resumed because Phase 45 must consume the final vM017 brand
> before screenshots and visual proof are regenerated. Current published package remains `cairnloop`
> v0.5.1 on Hex.pm.

## Phases

### vM016 Operator UI/UX Iteration (Phases 37-45) - ACTIVE

- [x] **Phase 37: Component Primitives** - `cl_page`, `cl_hero`/`cl_stat`, `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch`, layout tokens, and table scroll wrappers (completed 2026-06-03)
- [x] **Phase 38: Shared Page-Shell Migration** - Operator screens migrated through `cl_page`; breadcrumb path wired for deep KB flows (completed 2026-06-04)
- [x] **Phase 39: Home Primacy Redesign (D1)** - Queue-first home hero, calmer secondary band, scoped counts, and resolved-filter CTA fix (completed 2026-06-04)
- [x] **Phase 40: Drift Remediation + Brand-Token Gate Hardening** - render-file token cleanup and gate hardening against inline hex/raw color drift (completed 2026-06-04)
- [x] **Phase 41: Conversation Rail Progressive Disclosure (D2)** - safety-pinned native-disclosure rail with density controls (completed 2026-06-04)
- [x] **Phase 42: Cross-Screen Threading** - next-in-queue, audit subject links, governed-action audit links, and KB origin links (completed 2026-06-04)
- [x] **Phase 43: Responsive Desktop-First Cockpit (D3)** - mobile-first CSS normalization, accessible table scrollers, stacked conversation layout, and tap-target guards (completed 2026-06-04)
- [x] **Phase 44: Motion** - restrained CSS-only motion for hero count, evidence rail, state chips, list stagger, and toasts; reduced motion honored live (completed 2026-06-26)
- [x] **Phase 45: Seed Enrichment + Screenshot Regen + Verification Sweep** - final-brand fixture, screenshot, visual QA, and full verification sweep (completed 2026-06-26)

### Archived Current-Brand Milestone

<details>
<summary>SHIPPED vM017 Brand Identity System, Token Evolution & HTML Brand Book (Phases 46-52) - 2026-06-26</summary>

vM017 delivered the final brand foundation that vM016 Phase 45 must consume:

- canonical token-source audit and contrast baseline
- owner-selected C3.6 crowning-loop logo direction
- refined token evolution and derivative propagation
- production SVG logo family, favicon, and OG assets
- offline HTML brand book with derived token artifacts
- README/example-app/favicon/OG collateral wiring
- gated browser/package/SVG/raster QA proof

Full archive:

- `.planning/milestones/vM017-ROADMAP.md`
- `.planning/milestones/vM017-REQUIREMENTS.md`
- `.planning/milestones/vM017-MILESTONE-AUDIT.md`
- `.planning/milestones/vM017-phases/`

</details>

<details>
<summary>SHIPPED vM003-vM015 - archived</summary>

Earlier milestone roadmaps are archived under `.planning/milestones/`. See `.planning/MILESTONES.md`
for shipped summaries and `.planning/PROJECT.md` for cumulative product state.

</details>

## Phase Details

### Phase 37: Component Primitives

**Goal**: The component library has all primitives required by the iteration: `cl_page`, `cl_hero`/`cl_stat`, `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch`, layout tokens, inert utilities, and `.cl-table` scroll wrappers.
**Depends on**: Nothing.
**Requirements**: UIC-01, UIC-02, UIC-03, UIC-04, UIC-05
**Plans**: 5/5 plans complete

- [x] 37-01-PLAN.md - CSS foundation: layout tokens, utilities, table scroll wrapper, primitive visual CSS
- [x] 37-02-PLAN.md - `cl_page`, `cl_hero`, and numeric-only `cl_stat`
- [x] 37-03-PLAN.md - `cl_disclosure` and `cl_fact_list`
- [x] 37-04-PLAN.md - `cl_source_card`, `cl_status_cell`, and `cl_switch`
- [x] 37-05-PLAN.md - accessible table scroll wrappers

### Phase 38: Shared Page-Shell Migration

**Goal**: Every operator-facing screen renders through `cl_page`, and breadcrumbs give orientation on nested KB paths.
**Depends on**: Phase 37
**Requirements**: SHELL-01, SHELL-02
**Plans**: 4/4 plans complete

- [x] 38-01-PLAN.md - migrate Home, Inbox, Audit Log, and Settings
- [x] 38-02-PLAN.md - migrate KB index, editor, gaps, and suggestion review
- [x] 38-03-PLAN.md - pure breadcrumb presenter
- [x] 38-04-PLAN.md - origin-aware breadcrumb wiring

### Phase 39: Home Primacy Redesign (D1)

**Goal**: Home represents the operator's primary job, "Work the queue", with a full-width hero, filtered resolved recovery, calmer secondary band, health chip, and scoped fail-closed counts.
**Depends on**: Phase 38
**Requirements**: HOME-01, HOME-02, HOME-03, HOME-04, HOME-05
**Plans**: 3/3 plans complete

- [x] 39-01-PLAN.md - scoped Chat count/query facade
- [x] 39-02-PLAN.md - Inbox resolved filter
- [x] 39-03-PLAN.md - Home two-tier restructure and throttled counts

### Phase 40: Drift Remediation + Brand-Token Gate Hardening

**Goal**: The largest render-file drift surfaces are on tokens, and the brand-token gate prevents inline hex/raw color regressions.
**Depends on**: Phase 37, Phase 39
**Requirements**: DRIFT-01, DRIFT-02, GATE-01, GATE-02
**Plans**: 3/3 plans complete

- [x] 40-01-PLAN.md - conversation token cleanup and footer component rebuild
- [x] 40-02-PLAN.md - search modal token cleanup
- [x] 40-03-PLAN.md - ExUnit gate hardening plus advisory Credo check

### Phase 41: Conversation Rail Progressive Disclosure (D2)

**Goal**: The conversation rail keeps safety facts and decision footer visible while lower-priority detail lives in patch-safe native disclosure groups.
**Depends on**: Phase 37, Phase 40, Phase 38
**Requirements**: RAIL-01, RAIL-02, RAIL-03
**Plans**: 4/4 plans complete

- [x] 41-01-PLAN.md - RED rail-disclosure and passthrough tests
- [x] 41-02-PLAN.md - `cl_disclosure` global passthrough
- [x] 41-03-PLAN.md - governed action card rail restructure
- [x] 41-04-PLAN.md - expand/collapse controls and density persistence

### Phase 42: Cross-Screen Threading

**Goal**: Operators can move naturally among related cockpit screens without dead-end leaves.
**Depends on**: Phase 38, Phase 41
**Requirements**: THREAD-01, THREAD-02, THREAD-03
**Plans**: 6/6 plans complete

- [x] 42-01-PLAN.md - audit subject-link backend
- [x] 42-02-PLAN.md - queue and article-origin backend
- [x] 42-03-PLAN.md - Audit Log subject links and proposal filter
- [x] 42-04-PLAN.md - Conversation next-in-queue and governed-action audit link
- [x] 42-05-PLAN.md - KB editor originating-conversation crumb
- [x] 42-06-PLAN.md - E2E thread-navigation proof

### Phase 43: Responsive Desktop-First Cockpit (D3)

**Goal**: CSS is normalized mobile-first, table scrollers are accessible, the conversation layout stacks cleanly, sticky bulk actions clear rows, and tap targets are at least 44px.
**Depends on**: Phase 40, Phase 37
**Requirements**: RESP-01, RESP-02
**Plans**: 3/3 plans complete

- [x] 43-01-PLAN.md - mobile-first CSS normalization and breakpoint comment block
- [x] 43-02-PLAN.md - table scroller and conversation stacking source guards
- [x] 43-03-PLAN.md - tap targets and bulk-bar clearance

### Phase 44: Motion

**Goal**: Restrained, brand-aligned motion is applied across the operator cockpit using only transform and opacity, never on reply-send, keystrokes/search open, count ticks, or layout properties; reduced motion removes movement while preserving the gate cross-fade.
**Depends on**: Phase 43, Phase 40, Phase 41
**Requirements**: MOTION-01, MOTION-02
**Success Criteria**:

1. Hero count entrance, rail reveal, gate state-flip, list-item enter, and toast enter/exit animate using transform and opacity only.
2. `prefers-reduced-motion: reduce` removes transform/translate movement while preserving `.cl-motion-state` as the meaning-bearing cross-fade.
3. Reply-send, search-open, and count ticks receive no new motion class or transition.
4. `mix test` passes and the brand-token gate does not flag motion classes.

**Plans**: 4/4 plans complete

- [x] 44-01-PLAN.md - Wave 0 Nyquist tests: CSS scan and Playwright motion E2E
- [x] 44-02-PLAN.md - motion CSS foundation and example import guard
- [x] 44-03-PLAN.md - hero entrance and reusable `cl_flash`
- [x] 44-04-PLAN.md - inbox stagger, evidence rail reveal, status chip state motion

### Phase 45: Seed Enrichment + Screenshot Regen + Verification Sweep

**Goal**: The example seed and screenshot/verification proof fully exercise the final-brand operator UI across happy, empty, error, dense, and boundary states.
**Depends on**: Phases 37-44 and vM017 final brand
**Requirements**: SEED-01, VERIFY-01, VERIFY-02
**Success Criteria**:

1. The demo seed exercises varied audit events, rejected/deferred/published KB suggestions, draft article state, masked MCP tokens, and at least one higher-risk governed-action tool type.
2. Playwright screenshots are regenerated for touched screens in light and dark modes using the final vM017 brand.
3. `mix test`, integration, E2E, quality, and brand-token gates are green before claiming the milestone complete.

**Plans**: 4 plans
**Wave 1**

- [x] 45-01-PLAN.md - deterministic seed enrichment and seed contract tests
- [x] 45-02-PLAN.md - dual-theme screenshot capture pipeline

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 45-03-PLAN.md - regenerated light/dark screenshots and visual acceptance ledger

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 45-04-PLAN.md - full verification sweep and release-gate review

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 37. Component Primitives | vM016 | 5/5 | Complete | 2026-06-03 |
| 38. Shared Page-Shell Migration | vM016 | 4/4 | Complete | 2026-06-04 |
| 39. Home Primacy Redesign (D1) | vM016 | 3/3 | Complete | 2026-06-04 |
| 40. Drift Remediation + Brand-Token Gate Hardening | vM016 | 3/3 | Complete | 2026-06-04 |
| 41. Conversation Rail Progressive Disclosure (D2) | vM016 | 4/4 | Complete | 2026-06-04 |
| 42. Cross-Screen Threading | vM016 | 6/6 | Complete | 2026-06-04 |
| 43. Responsive Desktop-First Cockpit (D3) | vM016 | 3/3 | Complete | 2026-06-04 |
| 44. Motion | vM016 | 4/4 | Complete | 2026-06-26 |
| 45. Seed Enrichment + Screenshot Regen + Verification Sweep | vM016 | 4/4 | Complete    | 2026-06-26 |
| 46-52. Brand Identity System, Token Evolution & HTML Brand Book | vM017 | 15/15 | Shipped | 2026-06-26 |

_Archived milestones and full prior phase details live under `.planning/milestones/`._
