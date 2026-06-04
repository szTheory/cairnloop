# Requirements: Cairnloop — vM016 Operator UI/UX Iteration

**Defined:** 2026-06-03
**Core Value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Source of truth:** `.planning/vM016-UI-ITERATION-BRIEF.md` (ratified directions D1–D3 — refine, do not re-litigate).
**Scope surface:** operator/admin dashboard only (NOT the customer chat widget or demo index).

## v1 Requirements

Requirements for milestone vM016. Each maps to exactly one roadmap phase (37–45).

### Component Primitives (UIC)

- [x] **UIC-01**: A `cl_page` shell component exists with `title`/`subtitle`/`:actions`/`:breadcrumb`/`:subnav` slots and `:wide`/`:reading` width options, rendering consistent inner page framing.
- [x] **UIC-02**: `cl_stat` is de-polymorphized to numeric-only, and a `cl_hero` (or `cl_stat variant="hero"` + `:detail` slot) renders a primary hero count.
- [x] **UIC-03**: A reusable `cl_disclosure`/`cl_details` primitive wraps native `<details>`/`<summary>` for SSR/patch-safe progressive disclosure with no server-assigns open state.
- [x] **UIC-04**: `cl_fact_list`, `cl_source_card` (with `source_variant`), `cl_status_cell`, and `cl_switch` (real `role="switch"`) components exist and are token-pure.
- [x] **UIC-05**: Layout tokens (`--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter`) are added, the previously-inert utilities (`cl-gap-2`/`cl-align-center`/`cl-justify-between`) are defined in CSS, and every `.cl-table` has an accessible `overflow-x:auto` scroll wrapper.

### Shared Page-Shell Migration (SHELL)

- [x] **SHELL-01**: Home, Inbox, Audit Log, Settings, and the KB screens render through `cl_page`, so every operator screen shares consistent header, width, and inner framing.
- [x] **SHELL-02**: `cl_breadcrumb` is wired on the deep KB-from-conversation path (no longer defined-but-orphaned), giving a "you are here" cue on nested routes.

### Home Primacy Redesign — D1 (HOME)

- [x] **HOME-01**: Home leads with a full-width "Work the queue" hero (~2–3× the visual weight of secondary items) showing a single copper count and a primary `cl_button` CTA into the inbox.
- [x] **HOME-02**: Recover-resolved folds into the hero as a quiet sub-line that links to `/inbox` **with the resolved filter applied** (fixing the broken-on-click CTA) and is omitted when the count is zero.
- [x] **HOME-03**: A calmer secondary "Tend the trail" band (Tend knowledge / Audit / System health) uses neutral (non-copper) counts to protect the 70/20/10 palette; system health renders as a `cl_chip` (success "Healthy" / warning "Degraded"), never occupying a numeric count slot.
- [x] **HOME-04**: The dead 6th grid cell is removed and the all-caught-up state is a calm success (icon + text), never confetti.
- [x] **HOME-05**: Home counts use scoped count queries (not a full per-PubSub-tick re-query) and are throttled, while keeping the fail-closed `safe/2` count behavior.

### Drift Remediation (DRIFT)

- [x] **DRIFT-01**: `conversation_live.ex` and `search_modal_component.ex` carry zero off-palette hardcoded hex — the documented hex→token map is applied (border / text / danger / warning, and info+success via `cl_source_card source_variant`).
- [x] **DRIFT-02**: The hand-rolled approve/reject/defer footer is rebuilt with `cl_button` variants + a shared textarea class, and bespoke inline-layout `style=` attributes migrate to `.cl-` utilities.

### Brand-Token Gate Hardening (GATE)

- [x] **GATE-01**: The brand-token ExUnit gate fails on inline `style="…#hex…"`, raw `rgba()`/`hsl()`, and helper-returned hex in render `.ex` files (anchored on `#` + color context to avoid false positives; magic-comment allowlist; the `.css` file stays unscanned).
- [x] **GATE-02**: A complementary dev-time Credo check flags hardcoded color in render files, with the ExUnit gate remaining the CI source of truth.

### Conversation Rail Progressive Disclosure — D2 (RAIL)

- [x] **RAIL-01**: The conversation rail is reordered so Tier 1 — headline + status + the safety quartet (risk tier · confidence/grounding · policy outcome · approval mode) + the pending Approve/Reject/Defer footer — never collapses.
- [x] **RAIL-02**: Tier 2/3 detail (Inputs & scope, History, Policy explanation; raw snapshots, per-event metadata, trace ids) lives in native `<details>`/`<summary>` with no assigns-bound open state, surviving the conversation's PubSub reload handlers.
- [x] **RAIL-03**: Blocking/pending cards auto-expand, and a rail-level Expand-all/Collapse-all plus a remembered density toggle (localStorage) work via `Phoenix.LiveView.JS` without ever touching Tier 1.

### Cross-Screen Threading (THREAD)

- [x] **THREAD-01**: After handling/resolving a conversation, a "next in queue" affordance advances the operator to the next item.
- [x] **THREAD-02**: Audit-log rows link to their subject (conversation / governed action), so the audit log is no longer a dead-end leaf.
- [x] **THREAD-03**: Governed-action cards link to their audit entry, and KB articles link back to their originating conversation (bi-directional causal threading).

### Responsive — D3 (RESP)

- [x] **RESP-01**: CSS is normalized mobile-first (`min-width`) — the two `max-width:640` blocks are converted, breakpoints are standardized at 640/768/1024 and documented as literal constants in one CSS comment block (breakpoints are NOT tokenized as custom properties).
- [ ] **RESP-02**: Every `.cl-table` scrolls accessibly on narrow / host-constrained widths (`role="region"`, `tabindex=0`, aria-label); the conversation two-column layout stacks below `lg`, the sticky bulk-bar wraps/clears the last row, and interactive tap targets are ≥44px.

### Motion (MOTION)

- [ ] **MOTION-01**: Restrained brand motion is applied (hero count < 180ms; rail/drawer reveal 260ms; gate state-flip 180ms; list enter staggered ≤5; toast enter/exit; route motif) using transform + opacity only — never on reply-send, keystrokes, count ticks, or layout properties.
- [ ] **MOTION-02**: `prefers-reduced-motion` is honored live — movement is removed while comprehension cross-fades are kept.

### Seed Enrichment & Verification (SEED / VERIFY)

- [ ] **SEED-01**: The demo seed fully expresses every screen's states: varied audit timestamps (~14d) with real reasons plus a rejected and a deferred event; rejected/deferred/published KB suggestions; ≥1 draft-state article; 1–2 masked MCP tokens; and a second/higher-risk governed-action tool type.
- [ ] **VERIFY-01**: Light + dark screenshots are regenerated for the touched screens via the Playwright pipeline, per-screen visual acceptance is recorded, and motion is verified live (dark mode is the tell that drift remediation themed correctly).
- [ ] **VERIFY-02**: `mix test` is green including the hardened brand-token gate and `golden_path_test.exs`; the integration suite is validated with `PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration` plus the quality lane before claiming green.

## v2 Requirements

Deferred to a future iteration; acknowledged but not in the vM016 roadmap.

### Phone-Optimized Patterns (PHONE)

- **PHONE-01**: Tabbed Timeline↔Detail layout on phone widths.
- **PHONE-02**: Card-transform tables (row→card) below the table breakpoint.
- **PHONE-03**: Off-canvas navigation drawer on phone widths.
- **PHONE-04**: Container queries for host-arbitrary embed widths (sticky-positioning hazard makes viewport media queries the v1 choice).

### Advanced Motion Motifs (AMOTION)

- **AMOTION-01**: Route-line draw + marker-travel motif via `phx-hook` + WAAPI.
- **AMOTION-02**: Source-card stack reveal and FLIP list reorder.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Customer chat widget / demo index restyle | vM016 is the operator/admin surface only |
| Switching CSS architecture (Tailwind/daisyUI/build step) | Locked: BEM + `.cl-` utilities, one shipped `cairnloop.css`, no build step |
| Re-litigating D1–D3 directions | Ratified in the brief after a deep research pass; per-phase work refines, not re-decides |
| Hardcoded hex in render `.ex` files | Tokens (`--cl-*`) are the single source of truth; the hardened gate enforces this |
| Tokenizing breakpoints as custom properties | `var()` is illegal in `@media`/`@container` conditions — silent no-op |
| New product scope — Epic 12 (advanced routing), Epic 13 (local AI), Epic 14 (mobile SDK) | Diminishing-returns posture; opt-in only until an adopter pulls. vM016 iterates the shipped surface, it does not expand product scope |
| Churning sealed paths (`propose/3`, idempotency, co-commit, approval markup) | Architectural invariant: additive over rewrite |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UIC-01 | Phase 37 | Complete |
| UIC-02 | Phase 37 | Complete |
| UIC-03 | Phase 37 | Complete |
| UIC-04 | Phase 37 | Complete |
| UIC-05 | Phase 37 | Complete |
| SHELL-01 | Phase 38 | Complete |
| SHELL-02 | Phase 38 | Complete |
| HOME-01 | Phase 39 | Complete |
| HOME-02 | Phase 39 | Complete |
| HOME-03 | Phase 39 | Complete |
| HOME-04 | Phase 39 | Complete |
| HOME-05 | Phase 39 | Complete |
| DRIFT-01 | Phase 40 | Complete |
| DRIFT-02 | Phase 40 | Complete |
| GATE-01 | Phase 40 | Complete |
| GATE-02 | Phase 40 | Complete |
| RAIL-01 | Phase 41 | Complete |
| RAIL-02 | Phase 41 | Complete |
| RAIL-03 | Phase 41 | Complete |
| THREAD-01 | Phase 42 | Complete |
| THREAD-02 | Phase 42 | Complete |
| THREAD-03 | Phase 42 | Complete |
| RESP-01 | Phase 43 | Complete |
| RESP-02 | Phase 43 | Pending |
| MOTION-01 | Phase 44 | Pending |
| MOTION-02 | Phase 44 | Pending |
| SEED-01 | Phase 45 | Pending |
| VERIFY-01 | Phase 45 | Pending |
| VERIFY-02 | Phase 45 | Pending |
| PHONE-01 | v2 | Deferred |
| PHONE-02 | v2 | Deferred |
| PHONE-03 | v2 | Deferred |
| PHONE-04 | v2 | Deferred |
| AMOTION-01 | v2 | Deferred |
| AMOTION-02 | v2 | Deferred |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0 ✓
- Deferred to v2 (out of v1 scope): 6 (PHONE-01..04, AMOTION-01..02)

---
*Requirements defined: 2026-06-03 (milestone vM016, from the ratified UI iteration brief)*
*Last updated: 2026-06-04 — Phase 39 complete; v2-deferred reqs added to traceability table*
