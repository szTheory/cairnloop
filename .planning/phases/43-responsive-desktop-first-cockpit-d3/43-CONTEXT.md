# Phase 43: Responsive Desktop-First Cockpit (D3) - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning
**Source:** Synthesized from ratified D3 decision (`.planning/vM016-UI-ITERATION-BRIEF.md` §D3 + STATE.md "vM016 ratified decisions" + ROADMAP Phase 43). Directions are ratified — do not re-litigate; refine into plans.

<domain>
## Phase Boundary

This phase normalizes the operator cockpit's CSS to a **mobile-first (`min-width`) architecture optimized for desktop**, makes it **tablet-complete** and **phone-graceful** — without switching CSS architecture (stays BEM + `.cl-` utilities, no Tailwind, no build step).

**What this phase delivers:**
- The two `max-width:640` media-query blocks in `priv/static/cairnloop.css` are converted to `min-width` equivalents (mobile-first authoring).
- Breakpoints standardized at **640 / 768 (new tablet) / 1024**, documented as **literal constants in one CSS comment block** at the top of the breakpoint section.
- Every `.cl-table` is wrapped in an accessible `overflow-x:auto` scroller (`role="region"`, `tabindex="0"`, `aria-label`).
- The conversation two-column layout stacks to single-column below the `lg` (1024) breakpoint; the evidence rail wraps.
- The sticky inbox bulk-bar wraps / clears the last row (does not occlude it).
- All interactive controls (buttons, checkboxes, links — especially in the bulk-bar) have a rendered tap target of **≥44×44px**.
- Responsive-relevant inline `style=` attributes migrate to `.cl-` utilities.

**What this phase is NOT:** net-new visual design, new components, motion (Phase 44), or phone-optimized layout patterns (deferred to v2 — see Deferred Ideas).
</domain>

<decisions>
## Implementation Decisions

### D3-01 — Mobile-first `min-width` methodology (RESP-01)
CSS is authored mobile-first. The two existing `max-width:640` blocks (`priv/static/cairnloop.css` ~L263 `.cl-main` padding; ~L516 modal block) are converted to `min-width` equivalents. Base (unqualified) rules target the smallest viewport; `min-width` queries layer on larger-screen enhancements. Optimization target remains **desktop** (B2B operator-tool norm: Zendesk/Front/Intercom; Oban Web/LiveDashboard are desktop+scroll) — mobile-first is the *authoring methodology*, not a phone-first product pivot.

### D3-02 — Standardized breakpoints as literal constants (RESP-01)
Exactly three breakpoints: **640 / 768 / 1024**. They are documented as **literal pixel constants in ONE CSS comment block** at the top of the breakpoint section. 768 is the new tablet breakpoint introduced this phase.

### D3-03 — Breakpoints are NEVER tokenized (RESP-01, footgun-locked)
`var()` is **illegal inside `@media`/`@container` conditions** and silently no-ops. Breakpoint values MUST be hardcoded literals in `@media` conditions — they are NOT custom properties. *Layout* values (max-widths, rail widths, gutters) remain real tokens (`--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter` — already defined in Phase 37); only the breakpoint *conditions* are literals.

### D3-04 — Accessible `.cl-table` scrollers (RESP-02, non-optional)
Every `.cl-table` gets an accessible `overflow-x:auto` scroll wrapper carrying `role="region"`, `tabindex="0"`, and a descriptive `aria-label`. Known `.cl-table` call sites: `audit_log_live.ex`, `settings_live.ex`, `knowledge_base_live/index.ex`, `knowledge_base_live/suggestion_review.ex`. (Phase 37 introduced a `.cl-table-scroll` wrapper pattern + wrapped 4 sites — this phase verifies completeness and the `min-width` re-author does not regress them.)

### D3-05 — Conversation layout stacks below `lg` (RESP-02)
The conversation two-column layout (main column + `.evidence-rail`, width `--cl-rail-width`) collapses to single-column below the `lg` (1024) breakpoint; the rail wraps below the conversation header rather than being clipped.

### D3-06 — Sticky bulk-bar clears the last row (RESP-02)
The sticky inbox bulk-bar (`.cl-inbox-bulk-bar`, `position: sticky; bottom: 0`) wraps / clears the last table row so it never occludes selectable content. Use `.cl-row--wrap` (already applied) + appropriate bottom spacing.

### D3-07 — ≥44px tap targets (RESP-02)
All interactive controls (buttons, checkboxes, links in the bulk-bar and elsewhere touched this phase) have a rendered tap target of at least 44×44px. (`.cl-modal-close` and `.cl-button` already set `min-width/min-height: 44px` — extend the guarantee to bulk-bar controls and any sub-44px interactive element in scope.)

### D3-08 — Inline styles → utilities (RESP-02)
Responsive-relevant inline `style=` attributes in touched render files migrate to `.cl-` utility classes. This composes with the Phase 40 hardened brand-token gate (inline `style=` with hex is already flagged) — do not re-introduce drift.

### Verification ratification (2026-06-04, owner directive — supersedes the D3-06/D3-07 manual gate)
The rendered-geometry facts of D3-06 (bulk-bar occlusion) and D3-07 (tap-target hit area), plus the D3-01/02/03 768px non-regression, are verified by a **gated Playwright E2E** (`examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`), NOT a human-verify checkpoint. Owner directive: automate the world, zero human UAT, shift left onto the gated CI `e2e` lane (recurring drift-proofing value). This is now a project-level convention — see STATE.md "Verification policy". Phase 43 carries no `autonomous: false` task.

### Architecture posture (carried — do not violate)
- No Tailwind, no build step — BEM + `.cl-` utilities in `priv/static/cairnloop.css`.
- `mix compile --warnings-as-errors` and `mix test` (incl. hardened brand-token gate) must stay green.
- Brand tokens over hardcoded hex; calm fail-closed operator copy; never state-by-color-alone.
- Governance-facade reads from the web layer (no new direct `Cairnloop.Repo` queries) — though this phase is largely CSS + markup attributes, not data reads.

### Claude's Discretion
- Exact `aria-label` strings per table (e.g. "Audit log table, scrollable").
- Whether the breakpoint comment block lives at the top of the file's responsive section or a dedicated `/* === BREAKPOINTS === */` band — pick the most discoverable single location.
- Wave/plan decomposition (CSS normalization vs table-scroller verification vs conversation/bulk-bar/tap-target fixes).
- Whether to add a small ExUnit/markup assertion test for table `role="region"` presence (recommended for drift-proofing) vs manual verification only.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The CSS being normalized
- `priv/static/cairnloop.css` — media queries (~L263 `.cl-main` max-width:640; ~L426/427 `.cl-home-grid` min-width; ~L516 modal max-width:640; ~L529 min-width:1024), layout tokens (L136–140 `--cl-content-max`/`--cl-rail-width`/`--cl-page-gutter` + the existing "var() illegal in @media" note marking this as P43 work), `.cl-page--wide`/`--reading` (L712–713), `.cl-inbox-bulk-bar` (L525), tap-target rules (L524, L801).

### Render files in scope
- `lib/cairnloop/web/conversation_live.ex` — two-column layout + `.evidence-rail` (L485) + `.cl-rail-controls` (D3-05 stacking).
- `lib/cairnloop/web/inbox_live.ex` — sticky bulk-bar (L224–228, `.cl-inbox-bulk-bar cl-row cl-row--wrap`) (D3-06, D3-07).
- `lib/cairnloop/web/audit_log_live.ex`, `lib/cairnloop/web/settings_live.ex`, `lib/cairnloop/web/knowledge_base_live/index.ex`, `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — `.cl-table` call sites (D3-04).

### Decision sources (ratified)
- `.planning/vM016-UI-ITERATION-BRIEF.md` §D3 (L128–140) — the ratified responsive direction + footgun + in-scope/deferred list.
- `.planning/ROADMAP.md` Phase 43 success criteria (3 numbered criteria).
- `.planning/REQUIREMENTS.md` — RESP-01 (L57), RESP-02 (L58).
- `.planning/STATE.md` — vM016 ratified D3 decision.
- `prompts/cairnloop_brand_book.md` — layout/rail/color rules (brand voice unchanged; ensure no color regressions).
</canonical_refs>

<specifics>
## Specific Ideas

- The "two `max-width:640` blocks" are concretely: `priv/static/cairnloop.css:263` (`.cl-main` padding) and `:516` (modal block). Converting to `min-width` means base rules carry the small-screen padding and a `min-width` query restores the desktop padding (and vice-versa for the modal). Verify nothing else uses `max-width` media conditions after conversion.
- Layout tokens already exist (Phase 37); this phase consumes them in responsive rules — it does not need to define them.
- Existing `min-width` queries (`.cl-home-grid` at 640/1024) are already mobile-first and standard-conformant; align them to the documented constants and leave the architecture intact.
- A markup-level assertion that each `.cl-table` is wrapped with `role="region"` + `tabindex="0"` + `aria-label` is the cheapest drift-proofing (mirrors the Phase 40 gate philosophy).
</specifics>

<deferred>
## Deferred Ideas

Per the ratified brief and STATE.md "Deferred Items" — explicitly OUT of this phase (v2):
- **PHONE-01..04** phone-optimized patterns: tabbed Timeline↔Detail layout, card-transform tables, off-canvas nav, CSS container queries. (Sticky hazard + arbitrary host containers make viewport media queries the v1 choice.)
- Motion (Phase 44) — no transitions/animations added here.
</deferred>

---

*Phase: 43-responsive-desktop-first-cockpit-d3*
*Context synthesized 2026-06-04 from ratified D3 decision (shift-left: directions ratified, no operator gray-area decisions outstanding)*
