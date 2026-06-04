# Roadmap: Cairnloop

## Milestones

- ð **vM016 Operator UI/UX Iteration** â Phases 37â45 (active, started 2026-06-03)
- â **vM015 Operator Polish + Maintenance Gates** â Phases 33â36 (shipped 2026-05-30, v0.2.0âv0.2.2)
- â **vM014 Adoption Proof** â Phases 27â32.1 (shipped 2026-05-29)
- â **vM013 Support-Triggered Outbound Lifecycle** â Phases 22â26 (shipped 2026-05-27)
- â **vM012 Public Release & MCP Write Surface** â Phases 18â21 (shipped 2026-05-26)
- â **vM011 AI Tool Governance & MCP Integration** â Phases 13â17 (shipped 2026-05-25)
- â **vM010 KB AI Maintenance** â (shipped 2026-05-23)
- â **vM009 Retrieval-First Support Answers & Search Ops** â (shipped 2026-05-21)
- â **vM003âvM008** â foundational milestones (archived)

> **Release history:** v0.4.0 (operator design system: `cairnloop.css` + `Cairnloop.Web.Components`
> + Cockpit Home/nav), v0.5.0 (`Automation.DraftGenerator` seam + Anthropic adapter â draft path
> no longer a mock), v0.5.1 (operator-identity `host_user_id` fix + installer fix) all shipped
> outside formal GSD milestone numbering since vM015 close. **Current published version: cairnloop
> v0.5.1 on Hex.pm.** vM016 iterates the already-shipped operator surface (consistency, IA
> threading, drift-proofing); product remains "done enough for stated scope." Epics 12/13/14 stay
> opt-in only.

## Phases

### vM016 Operator UI/UX Iteration (Phases 37â45) â ACTIVE

- [x] **Phase 37 â Component Primitives** â `cl_page`, `cl_hero`/`cl_stat` split, `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch` + layout tokens + inert-utility and `.cl-table` scroll-wrapper fixes (completed 2026-06-03)
- [x] **Phase 38 â Shared Page-Shell Migration** â All operator screens (Home/Inbox/Audit/Settings/KB) rendered through `cl_page`; `cl_breadcrumb` wired on the deep KB-from-conversation path (4 plans, 2 waves) (completed 2026-06-04)
- [x] **Phase 39 â Home Primacy Redesign (D1)** â Two-tier hero + calmer secondary band; health-as-chip; count-color semantics fix; Recover-resolved filter CTA fix; zero-state; count queries + throttle (completed 2026-06-04)
- [x] **Phase 40 â Drift Remediation + Brand-Token Gate Hardening** â hexâtoken in `conversation_live`/`search_modal`; hardened gate fails on inline `style="â¦#hexâ¦"`, raw `rgba()`, helper-returned hex; complementary Credo check
- [x] **Phase 41 â Conversation Rail Progressive Disclosure (D2)** â Safety-pinned native-`<details>` accordion (decisions first; Tier 1 never collapses; Tier 2/3 collapsible; auto-expand blocking; density toggle) (completed 2026-06-04)
- [x] **Phase 42 â Cross-Screen Threading** â Next-in-queue; audit-rowâconversation; governed-actionâaudit; articleâoriginating-conversation (completed 2026-06-04)
- [x] **Phase 43 â Responsive Desktop-First Cockpit (D3)** â Mobile-first normalization; 768 tablet breakpoint; accessible table scrollers; conversation stacking; tap targets â¥44px (completed 2026-06-04)
- [ ] **Phase 44 â Motion** â Restrained brand motion (Â§15); `prefers-reduced-motion` honored live; transform+opacity only
- [ ] **Phase 45 â Seed Enrichment + Screenshot Regen + Verification Sweep** â Full-state seed; light+dark screenshots; `mix test` green (hardened gate + golden path)

<details>
<summary>â vM015 Operator Polish + Maintenance Gates (Phases 33â36) â SHIPPED 2026-05-30</summary>

- [x] Phase 33: Security Domain Closure (1/1 plans) â completed 2026-05-29
- [x] Phase 34: Operator Settings Surface (2/2 plans) â completed 2026-05-29
- [x] Phase 35: Audit & Operations Support (2/2 plans) â completed 2026-05-29
- [x] Phase 36: Documentation & v0.2.0 Release (1/1 plan) â completed 2026-05-29

Released as `cairnloop` v0.2.0 â v0.2.1 â v0.2.2 on Hex.pm. Full detail:
`.planning/milestones/vM015-ROADMAP.md`.

</details>

<details>
<summary>â vM003âvM014 â SHIPPED (archived)</summary>

Earlier milestone roadmaps are archived under `.planning/milestones/` (e.g.
`vM014-ROADMAP.md`, `vM013-ROADMAP.md`, â¦). See `.planning/MILESTONES.md` for the shipped
summary of every milestone and `.planning/PROJECT.md` for the cumulative product state.

</details>

## Phase Details

### Phase 37: Component Primitives
**Goal**: The component library has all primitives required by the iteration â `cl_page`, `cl_hero`/`cl_stat` (de-polymorphized), `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch` â plus the layout tokens, inert-utility CSS definitions, and `.cl-table` scroll-wrappers that blocked earlier screens.
**Depends on**: Nothing (first vM016 phase; purely additive to `components.ex` + `cairnloop.css`)
**Requirements**: UIC-01, UIC-02, UIC-03, UIC-04, UIC-05
**Success Criteria** (what must be TRUE):
  1. An operator screen can render a full page via `<.cl_page title="â¦">` with breadcrumb, actions slot, and both `:wide`/`:reading` width variants producing visibly different inner framing.
  2. `cl_stat` accepts only a numeric count; a `cl_hero` (or `variant="hero"`) renders at visually ~2â3Ã the weight of a standard stat with a `:detail` slot available.
  3. `<.cl_disclosure>` wraps native `<details>`/`<summary>` with no server assigns for open state â a LiveView PubSub reload does not snap the panel shut.
  4. `cl_fact_list`, `cl_source_card` (with `source_variant`), `cl_status_cell`, and `cl_switch` (with `role="switch"`) each render in a test template with no inline hex â token-only output confirmed by reading rendered HTML.
  5. `mix compile --warnings-as-errors` passes; `cl-gap-2`/`cl-align-center`/`cl-justify-between` are defined in `cairnloop.css`; every `.cl-table` has an `overflow-x:auto` wrapper with `role="region"`.
**Plans**: 5 plans (3 waves)
  - [x] 37-01-PLAN.md â CSS foundation: layout tokens, inert utilities, .cl-table-scroll, all primitive visual CSS + CSS-presence test (wave 1)
  - [x] 37-02-PLAN.md â cl_page + cl_hero + cl_stat numeric narrowing (wave 1)
  - [x] 37-03-PLAN.md â cl_disclosure (patch-safe) + cl_fact_list (wave 2)
  - [x] 37-04-PLAN.md â cl_source_card + cl_status_cell + cl_switch (wave 3)
  - [x] 37-05-PLAN.md â wrap 4 .cl-table call sites in accessible cl-table-scroll regions (wave 2)
**UI hint**: yes

### Phase 38: Shared Page-Shell Migration
**Goal**: Every operator-facing screen (Home, Inbox, Audit Log, Settings, and all KB sub-screens) renders through `cl_page`, eliminating the bespoke per-screen header/width hand-rolling that makes the cockpit feel like different apps; `cl_breadcrumb` is wired on the KB-from-conversation deep path so operators always know where they are.
**Depends on**: Phase 37 (requires `cl_page` and `cl_breadcrumb` primitives)
**Requirements**: SHELL-01, SHELL-02
**Success Criteria** (what must be TRUE):
  1. Navigating to Home, Inbox, `/audit-log`, Settings, and each KB sub-screen (index, editor, suggestion review) produces consistent header height, inner content width, and page title â visually verifiable against the screenshot pipeline.
  2. Opening a conversation from the Audit Log and then navigating into the KB editor from that conversation displays a rendered `cl_breadcrumb` with at least two crumbs and a back link â it is no longer defined-but-orphaned.
  3. `mix compile --warnings-as-errors` passes and `mix test` remains green (no regressions from shell migration).
**Plans**: 4 plans (2 waves)
  - [x] 38-01-PLAN.md â Migrate Home, Inbox, Audit Log, Settings into cl_page (SHELL-01, wave 1)
  - [x] 38-02-PLAN.md â Migrate KB Index, Editor, Gaps, Suggestion review into cl_page (SHELL-01, wave 1)
  - [x] 38-03-PLAN.md â BreadcrumbPresenter: pure origin-label + crumb-items presenter (SHELL-02, wave 1)
  - [x] 38-04-PLAN.md â Wire origin-aware breadcrumb into editor + new lane crumb on suggestion_review (SHELL-02, wave 2)
**UI hint**: yes

### Phase 39: Home Primacy Redesign (D1)
**Goal**: Home honestly represents the operator's primary job â "Work the queue" â with a full-width hero that draws the eye first, Recover-resolved folded in as a quiet sub-line (and linking to the filtered inbox correctly), a calmer secondary "Tend the trail" band with neutral counts, system health expressed as a chip, the dead sixth grid cell removed, and a calm all-caught-up zero state.
**Depends on**: Phase 38 (Home rendered through `cl_page`; Phase 37 `cl_hero`, `cl_chip`, `cl_stat` de-polymorphized)
**Requirements**: HOME-01, HOME-02, HOME-03, HOME-04, HOME-05
**Success Criteria** (what must be TRUE):
  1. The Home page leads with a full-width copper count hero and a primary `cl_button` CTA; the Recover-resolved sub-line is visible only when the count is non-zero and clicking it navigates to `/inbox` with the resolved filter applied (not the raw inbox).
  2. The secondary band shows Tend knowledge, Audit, and System health with neutral (non-copper) counts; System health renders as a `cl_chip` labeled "Healthy" or "Degraded" â never as a numeric count slot.
  3. When the queue is empty, Home shows a calm success state (icon + text); there is no confetti and no dead sixth grid cell in the layout.
  4. The brand-token gate (`mix test`) passes â Home markup contains no hardcoded hex colors.
  5. Count queries are scoped (not a full `assign_counts/1` re-query per PubSub tick), and the `safe/2` fail-closed count behavior is preserved â a simulated error returns `0`, not an exception.
**Plans**: 3 plans (2 waves)
  - [x] 39-01-PLAN.md â Chat facade scoped queries (list_conversations/1 + count_conversations/1 + scope_status/2) [HOME-02, HOME-05] (wave 1)
  - [x] 39-02-PLAN.md â InboxLive resolved filter: handle_params/3 + fail-closed normalize_status/1 + filter-aware PubSub + applied-filter row [HOME-02] (wave 2)
  - [x] 39-03-PLAN.md â HomeLive two-tier restructure: hero + 3-up band + zero-state; scoped/throttled fail-closed counts [HOME-01..05] (wave 2)
**UI hint**: yes

### Phase 40: Drift Remediation + Brand-Token Gate Hardening
**Goal**: The two largest drift surfaces (`conversation_live.ex` and `search_modal_component.ex`) are fully on-palette, and the brand-token gate is hardened so drift cannot re-enter silently â the gate now catches inline `style="â¦#hexâ¦"`, raw `rgba()`/`hsl()`, and helper-returned hex, with a complementary dev-time Credo check.
**Depends on**: Phase 37 (new primitives `cl_source_card`, `cl_button` variants, `cl_disclosure` absorb the drift patterns); Phase 39 (gate hardening directly after Home migration so the gate spans all operator screens)
**Requirements**: DRIFT-01, DRIFT-02, GATE-01, GATE-02
**Success Criteria** (what must be TRUE):
  1. `conversation_live.ex` and `search_modal_component.ex` contain zero off-palette hardcoded hex â the documented hexâtoken map (`#e5e7eb`â`--cl-border`; `#8b7355`â`--cl-text-muted`; maroonâ`--cl-danger-*`; cream/oliveâ`--cl-warning-*`; etc.) is fully applied; `grep -rn '#[0-9a-fA-F]\{3,6\}' lib/cairnloop/web/*.ex` returns no matches in these files.
  2. The hand-rolled approve/reject/defer footer is rebuilt with `cl_button` variants and a shared textarea class; bespoke inline layout `style=` attributes have migrated to `.cl-` utilities.
  3. The brand-token ExUnit gate (`mix test`) fails when a test render `.ex` file contains an inline `style="color:#abc"`, a raw `rgba(0,0,0,0.5)`, or a helper function returning a hex string â and passes when those are replaced with tokens.
  4. A Credo check exists that flags hardcoded color literals in render files at dev time; the ExUnit gate remains the CI source of truth.
  5. `mix compile --warnings-as-errors` and `mix test` both pass; dark-mode manual verification confirms the remediated strings themed correctly (tokens respond; off-palette hex does not).
**Plans**: 3 plans (2 waves)
  - [x] 40-01-PLAN.md â conversation_live.ex hex→token + footer rebuilt with cl_button/.cl-textarea (DRIFT-01, DRIFT-02, wave 1)
  - [x] 40-02-PLAN.md â search_modal_component.ex rgba→token snap + cl_chip source/trust badges (DRIFT-01, wave 1)
  - [x] 40-03-PLAN.md â harden ExUnit gate (inline hex/rgba/hsl + allowlist) + advisory Credo check (GATE-01, GATE-02, wave 2)
**UI hint**: yes

### Phase 41: Conversation Rail Progressive Disclosure (D2)
**Goal**: The conversation rail is reordered so the safety quartet and the pending decision footer are always visible (Tier 1 never collapses), Tier 2/3 detail lives in native `<details>`/`<summary>` that survive PubSub reloads without snapping shut, blocking cards auto-expand, and a rail-level expand-all/collapse-all plus a remembered density toggle work via `Phoenix.LiveView.JS`.
**Depends on**: Phase 37 (`cl_disclosure` primitive); Phase 40 (drift remediation reduces hand-rolled markup that would conflict with rail restructuring); Phase 38 (`cl_page` `:reading` width used by the conversation view)
**Requirements**: RAIL-01, RAIL-02, RAIL-03
**Success Criteria** (what must be TRUE):
  1. The risk tier, confidence/grounding chip, policy outcome, and approval mode are always visible in the rail regardless of `<details>` open state; the Approve/Reject/Defer footer for a pending card is never inside a `<details>` element.
  2. Inputs & scope, History, and Policy explanation are each in a separate native `<details>` group; a PubSub-triggered re-render (simulated by a test event) does not reset any manually-opened `<details>` element to closed.
  3. A blocking/pending card auto-expands its Tier-2 group on first render; clicking "Expand all" opens all Tier-2 `<details>` without touching Tier 1; the density toggle preference persists in `localStorage` across a page refresh.
  4. `mix test` passes; the `cl_disclosure` component has a unit test confirming no server assigns control `open` state.
**Plans**: 4 plans (4 waves)
  - [x] 41-01-PLAN.md — Wave 0 RED test scaffold: rail-disclosure describe block + cl_disclosure data-tier passthrough test [RAIL-01/02/03] (wave 1)
  - [x] 41-02-PLAN.md — cl_disclosure/1 additive :global passthrough (unblocks data-tier scoping) [RAIL-03] (wave 2)
  - [x] 41-03-PLAN.md — governed_action_card restructure: Tier-1 pin + 3 Tier-2 groups + standalone Trace group + static auto-expand [RAIL-01, RAIL-02] (wave 3)
  - [x] 41-04-PLAN.md — rail control bar (Expand/Collapse-all via JS) + density CSS + colocated localStorage hook + example app.js wiring [RAIL-03] (wave 4)
**UI hint**: yes

### Phase 42: Cross-Screen Threading
**Goal**: The operator can move naturally between related screens â advancing to the next conversation after resolving one, jumping from an audit row to the subject conversation or governed action, following a governed-action card to its audit entry, and tracing a KB article back to its originating conversation â so the cockpit stops being a set of isolated dead-end leaves.
**Depends on**: Phase 38 (breadcrumb/shell provides the orientation layer for deep links); Phase 41 (conversation rail is restructured before adding next-in-queue affordance that appears in that rail)
**Requirements**: THREAD-01, THREAD-02, THREAD-03
**Success Criteria** (what must be TRUE):
  1. After an operator marks a conversation as handled or resolved, a "Next in queue" affordance is visible; clicking it navigates to the next open conversation without returning to the inbox first.
  2. Every row in the Audit Log links to its subject (conversation or governed action); clicking the link navigates to the correct record, and the audit log is no longer a navigation dead end.
  3. A governed-action card in the conversation rail contains a link to its corresponding audit log entry; a KB article detail view contains a link back to the originating conversation where the gap was first surfaced.
  4. `mix test` passes; no direct `Cairnloop.Repo` queries are introduced in LiveViews for threading reads â all reads route through the `Cairnloop.Governance` facade.
**Plans**: 6 plans (3 waves)
  - [x] 42-01-PLAN.md — Audit backend: enrich Auditor.Governance map + proposal_id: facade opt + subject_href presenter [THREAD-02, THREAD-03] (wave 1)
  - [x] 42-02-PLAN.md — Queue + article backend: Chat.next_open_conversation/1 + KnowledgeAutomation.originating_conversation_id/2 [THREAD-01, THREAD-03] (wave 1)
  - [x] 42-03-PLAN.md — Audit Log web: handle_params/2 ?proposal filter + per-row subject link [THREAD-02, THREAD-03] (wave 2)
  - [x] 42-04-PLAN.md — Conversation rail web: Next-in-queue/Queue-clear + gov-action→audit deep-link [THREAD-01, THREAD-03] (wave 2)
  - [x] 42-05-PLAN.md — KB editor web: article→originating-conversation breadcrumb crumb [THREAD-03] (wave 2)
  - [x] 42-06-PLAN.md — E2E thread-navigation spec for all four threads [THREAD-01, THREAD-02, THREAD-03] (wave 3)
**UI hint**: yes

### Phase 43: Responsive Desktop-First Cockpit (D3)
**Goal**: The CSS is authored mobile-first (`min-width`) throughout, standardized breakpoints (640/768/1024) are documented as literal constants in one CSS comment block, every `.cl-table` has an accessible scroll wrapper, the conversation two-column layout stacks below `lg`, the sticky bulk-bar clears the last row, and interactive tap targets are at least 44px â making the cockpit genuinely usable on tablet and gracefully functional on phone without switching CSS architecture.
**Depends on**: Phase 40 (drift remediation removes bespoke inline `style=` that would conflict with responsive CSS normalization); Phase 37 (layout tokens `--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter` exist before responsive rules reference them)
**Requirements**: RESP-01, RESP-02
**Success Criteria** (what must be TRUE):
  1. The two `max-width:640` media query blocks in `cairnloop.css` are converted to `min-width` equivalents; a CSS comment block at the top of the breakpoint section documents the three literal constants (640 / 768 / 1024) â no breakpoint is tokenized as a `var()` (which would be a silent no-op in `@media`).
  2. Every `.cl-table` element in the operator screens has `role="region"`, `tabindex="0"`, and an `aria-label` on its scroll wrapper; the conversation two-column layout collapses to single-column below the `lg` breakpoint; all interactive controls (buttons, checkboxes, links in the bulk-bar) have a rendered tap target of at least 44Ã44px.
  3. `mix test` passes; a manual verification at 768px viewport width shows the Inbox table scrolling accessibly and the conversation rail stacking below the conversation header.
**Plans**: 3 plans (3 waves)
  - [x] 43-01-PLAN.md — CSS mobile-first normalization: convert two max-width:640 blocks → min-width, breakpoint comment block (640/768/1024 literals) + real 768 tablet rule, align home-grid constants + RESP-01 CSS-presence test [RESP-01] (wave 1)
  - [x] 43-02-PLAN.md — Verify + drift-proof: assert all four .cl-table accessible scroll wrappers + conversation below-lg stacking via Repo-free source-scan test (no re-wrapping); creates responsive_markup_test.exs [RESP-02] (wave 2)
  - [x] 43-03-PLAN.md — Tap targets + sticky clearance: .cl-checkbox 44px utility on both raw checkboxes, size=lg bulk-bar buttons, bulk-bar last-row clearance; preserve var(--cl-primary); extends responsive_markup_test.exs; human-verify checkpoint [RESP-02] (wave 3, depends on 43-02)
**UI hint**: yes

### Phase 44: Motion
**Goal**: Restrained, brand-aligned motion (Â§15) is applied across the operator cockpit â hero count, rail/drawer reveal, gate state-flip, list enter staggered, toast enter/exit â using only `transform` + `opacity`, never on reply-send, keystrokes, count ticks, or layout properties; `prefers-reduced-motion` removes movement while preserving cross-fade comprehension aids.
**Depends on**: Phase 43 (responsive layout stable before motion layered on top); Phase 40 (gate hardening stable â motion classes are not mistaken for inline-style drift); Phase 41 (rail structure finalized before rail-reveal motion applied)
**Requirements**: MOTION-01, MOTION-02
**Success Criteria** (what must be TRUE):
  1. The hero count entrance, rail/drawer reveal (260ms `--cl-ease-drawer`), gate state-flip (180ms `.cl-motion-state`), list-item enter (staggered, â¤5 items), and toast enter/exit all animate using only `transition: transform, opacity` â no `width`, `height`, `top`, `left`, or `max-height` transitions exist in the motion rules.
  2. With `prefers-reduced-motion: reduce` active in the browser, all transform/translate animations are removed; cross-fade (opacity-only) transitions for comprehension aids remain.
  3. The reply-send flow, `âK` search open, and count tick updates produce no CSS transitions on their triggering elements.
  4. `mix test` passes; the brand-token gate does not flag any motion class definitions.
**Plans**: TBD
**UI hint**: yes

### Phase 45: Seed Enrichment + Screenshot Regen + Verification Sweep
**Goal**: The demo seed fully expresses every operator screen's states (varied audit events, rejected/deferred/published KB suggestions, masked MCP tokens, draft-state article, second governed-action tool type); light and dark screenshots are regenerated for every touched screen; and `mix test` is green including the hardened brand-token gate and `golden_path_test.exs`.
**Depends on**: All prior phases (37â44) â this is the verification sweep that confirms everything landed correctly end-to-end.
**Requirements**: SEED-01, VERIFY-01, VERIFY-02
**Success Criteria** (what must be TRUE):
  1. The demo seed (`seeds.exs`) produces: audit events with varied timestamps (~14d span) and real reason strings, at least one rejected and one deferred audit event, rejected/deferred/published KB suggestion examples, a draft-state KB article, 1â2 masked MCP tokens (token list/mask UI is exercised), and a second governed-action tool type at a higher risk tier.
  2. Running the Playwright screenshot pipeline regenerates light and dark captures for all touched screens; the dark-mode captures show correct theming (token-based colors respond to dark mode; any residual off-palette hex would not â this is the visual proof that drift remediation landed).
  3. `mix test` is green including the hardened brand-token gate test; `PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration` including `golden_path_test.exs` passes; the quality lane (`mix credo --strict`, `mix hex.audit`) is clean.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 37. Component Primitives | vM016 | 5/5 | Complete    | 2026-06-03 |
| 38. Shared Page-Shell Migration | vM016 | 4/4 | Complete    | 2026-06-04 |
| 39. Home Primacy Redesign (D1) | vM016 | 3/3 | Complete    | 2026-06-04 |
| 40. Drift Remediation + Brand-Token Gate Hardening | vM016 | 3/3 | Complete   | 2026-06-04 |
| 41. Conversation Rail Progressive Disclosure (D2) | vM016 | 4/4 | Complete    | 2026-06-04 |
| 42. Cross-Screen Threading | vM016 | 6/6 | Complete    | 2026-06-04 |
| 43. Responsive Desktop-First Cockpit (D3) | vM016 | 3/3 | Complete    | 2026-06-04 |
| 44. Motion | vM016 | 0/? | Not started | â |
| 45. Seed Enrichment + Screenshot Regen + Verification Sweep | vM016 | 0/? | Not started | â |
| 33. Security Domain Closure | vM015 | 1/1 | Complete | 2026-05-29 |
| 34. Operator Settings Surface | vM015 | 2/2 | Complete | 2026-05-29 |
| 35. Audit & Operations Support | vM015 | 2/2 | Complete | 2026-05-29 |
| 36. Documentation & v0.2.0 Release | vM015 | 1/1 | Complete | 2026-05-29 |

_Phases 1â32.1 (vM001âvM014) are complete and archived â see `.planning/milestones/`._
