# Phase 43: Responsive Desktop-First Cockpit (D3) - Research

**Researched:** 2026-06-04
**Domain:** CSS responsive normalization (mobile-first `min-width`) + accessible markup, on a BEM + `.cl-` utility design system (no Tailwind, no build step). Pure CSS + HEEx markup; no DB reads.
**Confidence:** HIGH (all findings grounded in the actual current code at cited line numbers)

## Summary

This phase is **mostly verification + small mechanical normalization**, not net-new work. The hard parts the brief feared are already done by Phase 37: all four `.cl-table` call sites are already wrapped with `role="region"` / `tabindex="0"` / `aria-label`; the conversation two-column layout already stacks to single-column below 1024px; layout tokens already exist; tap-target rules already exist for `.cl-modal-close`, `.cl-button--lg`, `.cl-switch`, and `.cl-rail-controls .cl-button`. The actual remaining work is narrow: convert two `max-width` blocks to `min-width`, add a standardized breakpoint comment block, introduce the new 768 tablet breakpoint where it adds value, fix the two **raw `<input type="checkbox">`** controls in the inbox (the only confirmed sub-44px interactive controls in scope), ensure the sticky bulk-bar has bottom clearance, and add a cheap CSS-presence + markup-attribute drift-proofing test.

The brand-token gate (`brand_token_gate_test.exs`) scans **only `.ex` render files** — `.css` is excluded structurally — so editing `cairnloop.css` cannot trip it. The gate allows inline `style="…var(--cl-*)…"` (token-valued) and flags only bare hex / raw `rgba()`/`hsl()`. The scoped inline styles are already token-valued, so any D3-08 inline→class migration is gate-safe; the **only** caution is that four integration tests assert the literal string `var(--cl-primary)` appears in rendered HTML, so do not migrate the inbox bulk-bar primary button's `var(--cl-primary)` away without preserving that token somewhere the test still sees it.

**Primary recommendation:** Treat this phase as "verify-and-normalize." Decompose into (1) CSS mobile-first normalization + breakpoint comment block + 768 tablet, (2) tap-target + bulk-bar clearance fixes (the two raw checkboxes are the real gap), (3) drift-proofing test mirroring the existing `cairnloop_css_test.exs` + `inbox_live_test.exs` patterns. Do NOT re-wrap tables or re-stack the conversation layout — assert they are already correct.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Mobile-first breakpoint authoring | Browser / Client (CSS) | — | Pure presentation; `priv/static/cairnloop.css` |
| Accessible table scroll region | Browser / Client (CSS + HEEx markup) | — | `.cl-table-scroll` class + `role`/`tabindex`/`aria-label` attrs at call sites |
| Conversation two-column stacking | Browser / Client (CSS) | — | `.conversation-layout` flex-direction media query |
| Sticky bulk-bar clearance | Browser / Client (CSS) | — | `.cl-inbox-bulk-bar` + list bottom spacing |
| ≥44px tap targets | Browser / Client (CSS) + HEEx markup | — | Control sizing tokens + class application to raw inputs |
| Drift-proofing assertion | Test tier (ExUnit, pure file read) | — | DB-free `File.read!` string scan + LiveViewTest render |

This is a single-tier (presentation) phase. No API, data, or auth surface is touched.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D3-01 — Mobile-first `min-width` methodology (RESP-01).** CSS is authored mobile-first. The two existing `max-width:640` blocks (`priv/static/cairnloop.css` ~L263 `.cl-main` padding; ~L516 block) are converted to `min-width` equivalents. Base (unqualified) rules target the smallest viewport; `min-width` queries layer on larger-screen enhancements. Optimization target remains **desktop** — mobile-first is the authoring methodology, not a phone-first product pivot.

**D3-02 — Standardized breakpoints as literal constants (RESP-01).** Exactly three breakpoints: **640 / 768 / 1024**, documented as literal pixel constants in ONE CSS comment block at the top of the breakpoint section. 768 is the new tablet breakpoint introduced this phase.

**D3-03 — Breakpoints are NEVER tokenized (RESP-01, footgun-locked).** `var()` is illegal inside `@media`/`@container` conditions and silently no-ops. Breakpoint values MUST be hardcoded literals in `@media` conditions. *Layout* values (max-widths, rail widths, gutters) remain real tokens; only the breakpoint *conditions* are literals.

**D3-04 — Accessible `.cl-table` scrollers (RESP-02, non-optional).** Every `.cl-table` gets an accessible `overflow-x:auto` wrapper carrying `role="region"`, `tabindex="0"`, and a descriptive `aria-label`. Known sites: `audit_log_live.ex`, `settings_live.ex`, `knowledge_base_live/index.ex`, `knowledge_base_live/suggestion_review.ex`. This phase **verifies completeness** and that the `min-width` re-author does not regress them.

**D3-05 — Conversation layout stacks below `lg` (RESP-02).** The conversation two-column layout (main column + `.evidence-rail`) collapses to single-column below 1024px; the rail wraps below the conversation header rather than being clipped.

**D3-06 — Sticky bulk-bar clears the last row (RESP-02).** The sticky inbox bulk-bar (`.cl-inbox-bulk-bar`, `position: sticky; bottom: 0`) wraps / clears the last table row so it never occludes selectable content. Use `.cl-row--wrap` (already applied) + appropriate bottom spacing.

**D3-07 — ≥44px tap targets (RESP-02).** All interactive controls (buttons, checkboxes, links in the bulk-bar and elsewhere touched this phase) have a rendered tap target of ≥44×44px. (`.cl-modal-close` and `.cl-button` already set this — extend the guarantee to bulk-bar controls and any sub-44px interactive element in scope.)

**D3-08 — Inline styles → utilities (RESP-02).** Responsive-relevant inline `style=` attributes in touched render files migrate to `.cl-` utility classes. This composes with the Phase 40 hardened brand-token gate — do not re-introduce drift.

**Architecture posture (carried — do not violate):** No Tailwind, no build step — BEM + `.cl-` utilities in `priv/static/cairnloop.css`. `mix compile --warnings-as-errors` and `mix test` (incl. hardened brand-token gate) must stay green. Brand tokens over hardcoded hex; calm fail-closed copy; never state-by-color-alone. Governance-facade reads from web layer (this phase is CSS + markup, not data reads).

### Claude's Discretion

- Exact `aria-label` strings per table (e.g. "Audit log table, scrollable"). **Note: these already exist — see findings; discretion is whether to refine them.**
- Whether the breakpoint comment block lives at the top of the responsive section or in a dedicated `/* === BREAKPOINTS === */` band — pick the most discoverable single location.
- Wave/plan decomposition (CSS normalization vs table-scroller verification vs conversation/bulk-bar/tap-target fixes).
- Whether to add a small ExUnit/markup assertion test for table `role="region"` presence (**recommended** for drift-proofing) vs manual verification only.

### Deferred Ideas (OUT OF SCOPE)

Per the ratified brief and STATE.md "Deferred Items":
- **PHONE-01..04** phone-optimized patterns: tabbed Timeline↔Detail layout, card-transform tables, off-canvas nav, CSS container queries. (Sticky hazard + arbitrary host containers make viewport media queries the v1 choice.)
- **Motion (Phase 44)** — no transitions/animations added here.
- Net-new visual design, new components, phone-optimized layout patterns.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RESP-01 | CSS normalized mobile-first (`min-width`); the two `max-width:640` blocks converted; breakpoints standardized at 640/768/1024 and documented as literal constants in ONE CSS comment block; breakpoints NOT tokenized | Exact before/after for both blocks below (the L516 block is `.cl-nav`, NOT a modal — see Pitfall 1); two existing `min-width` queries (`.cl-home-grid` L426/427) already conform and only need alignment to the documented constants. CSS-presence assertions feasible via existing `cairnloop_css_test.exs` pattern. |
| RESP-02 | Every `.cl-table` scrolls accessibly (`role="region"`, `tabindex=0`, aria-label); conversation 2-col stacks below `lg`; sticky bulk-bar wraps/clears last row; tap targets ≥44px | All 4 tables already wrapped (verified, line-cited). Conversation stacking already correct (L528-533). Bulk-bar `.cl-row--wrap` already applied; needs bottom clearance. Two raw `<input type="checkbox">` (inbox L193, L207) are the only confirmed sub-44px controls. Markup-attribute assertions feasible via LiveViewTest. |
</phase_requirements>

## Standard Stack

No external packages. This phase uses only what is already in the repo:

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Plain CSS3 media queries | — | `@media (min-width: …)` responsive rules | No build step; BEM + `.cl-` utility architecture is the locked house style |
| Phoenix.LiveViewTest | (from deps) | Render markup assertions for `role="region"` etc. | Already the project's CI-truth render test tool |
| ExUnit `File.read!` string scan | stdlib | CSS-presence assertions | Already used by `cairnloop_css_test.exs` — DB-free, Repo-independent |

**No `npm install` / `mix deps` changes.** No Package Legitimacy Audit required (zero external packages installed this phase).

## Architecture Patterns

### Current responsive architecture (verified)

```
priv/static/cairnloop.css
├─ :root tokens (L130-156)
│   ├─ --cl-control-h-lg: 44px            ← the 44px tap-target token (L133)
│   └─ --cl-content-max / --cl-rail-width / --cl-page-gutter (L138-140)  ← layout tokens (Phase 37)
│
├─ .cl-main { max-width:1200px; padding: space-7 }   (L261)
│   └─ @media (max-width:640px) { padding: space-5 }  (L263)  ← CONVERT to min-width
│
├─ .cl-home-grid { 1fr }                              (L425)  ← already mobile-first
│   ├─ @media (min-width:640px)  { 2 cols }           (L426)  ← conforms; align to constants
│   └─ @media (min-width:1024px) { 3 cols }           (L427)  ← conforms; align to constants
│
├─ .cl-table-scroll { overflow-x:auto }               (L448)  ← wrapper class exists
│   └─ :focus-visible { box-shadow: focus-ring }       (L449)  ← keyboard a11y exists
│
├─ @media (max-width:640px) { .cl-nav { … } }          (L516-519)  ← CONVERT to min-width (NOT a modal)
│
├─ .cl-inbox-bulk-bar { position:sticky; bottom:0 }    (L525)  ← needs last-row clearance
│
├─ .conversation-layout { flex-direction:column }      (L528)  ← BASE = stacked (mobile-first ✓)
│   └─ @media (min-width:1024px) { flex-direction:row } (L529-533)  ← D3-05 ALREADY SATISFIED
│
└─ tap-target rules: .cl-modal-close (L524), .cl-button--lg (L324),
   .cl-rail-controls .cl-button (L549), .cl-switch (L801)       ← already ≥44px
```

### Pattern 1: Mobile-first conversion (max-width → min-width inversion)

**What:** A `max-width` query is the small-screen override of a desktop base. To author mobile-first, swap so the small-screen value becomes the *unqualified base* and the desktop value moves into a `min-width` query.

**When to use:** For the two `max-width` blocks (L263 and L516).

**Concrete before/after — Block A (`.cl-main` padding, L261/263):**

```css
/* BEFORE (desktop base + max-width override) */
.cl-main { flex: 1; width: 100%; max-width: 1200px; margin: 0 auto; padding: var(--cl-space-7, 24px); }
@media (max-width: 640px) { .cl-main { padding: var(--cl-space-5, 16px); } }

/* AFTER (mobile-first: small padding is the base, desktop padding layers on) */
.cl-main { flex: 1; width: 100%; max-width: 1200px; margin: 0 auto; padding: var(--cl-space-5, 16px); }
@media (min-width: 640px) { .cl-main { padding: var(--cl-space-7, 24px); } }
```
*Behavioral equivalence:* at <640px both render 16px; at ≥640px both render 24px. Identical at every viewport — no visual regression. (`max-width:640` = "≤640"; `min-width:640` = "≥640" — the 640px boundary itself flips from "small" to "large," a 1px edge that does not matter for padding.)

**Concrete before/after — Block B (`.cl-nav`, L516-519) — NOTE this is the nav, NOT the modal:**

```css
/* BEFORE */
.cl-nav { gap: var(--cl-space-5, 16px); padding: 0 var(--cl-space-7, 24px); height: 56px; … }
.cl-nav__link { padding: var(--cl-space-2, 4px) var(--cl-space-4, 12px); … }
@media (max-width: 640px) {
  .cl-nav { gap: var(--cl-space-3, 8px); padding: 0 var(--cl-space-4, 12px); }
  .cl-nav__link { padding: var(--cl-space-2, 4px) var(--cl-space-3, 8px); }
}

/* AFTER (small values become the base on .cl-nav/.cl-nav__link; desktop values layer on at ≥640) */
.cl-nav { gap: var(--cl-space-3, 8px); padding: 0 var(--cl-space-4, 12px); height: 56px; … }
.cl-nav__link { padding: var(--cl-space-2, 4px) var(--cl-space-3, 8px); … }
@media (min-width: 640px) {
  .cl-nav { gap: var(--cl-space-5, 16px); padding: 0 var(--cl-space-7, 24px); }
  .cl-nav__link { padding: var(--cl-space-2, 4px) var(--cl-space-4, 12px); }
}
```
*Note:* `.cl-nav` (L264-270) and `.cl-nav__link` (L278-287) are defined far above the L516 media query. The mechanically-cleanest move is to edit the **base** rule values at L264/L278 to the small values and convert L516 to a `min-width:640` block carrying the desktop values. Keep all non-overridden properties (height, background, border) untouched on the base rule.

### Pattern 2: Standardized breakpoint comment block (D3-02)

**What:** One discoverable comment block declaring the three literal constants, placed at the top of the responsive section (the natural home is just above L513's `Responsive — mobile-first` band header, or replacing/extending it).

**Example:**
```css
/* ============================================================================
   BREAKPOINTS — mobile-first (min-width). Literal pixel constants ONLY.
   var() is ILLEGAL inside @media conditions (silent no-op) — never tokenize these.
     sm  = 640px   (small → medium handoff; 1→2 col)
     md  = 768px   (tablet; introduced Phase 43)
     lg  = 1024px  (desktop; rail row layout, 3 col, conversation 2-col)
   Layout VALUES (max-width, rail width, gutters) stay tokens: --cl-content-max,
   --cl-rail-width, --cl-page-gutter. Only the @media CONDITION numbers are literals.
   ============================================================================ */
```

### Pattern 3: 768 tablet breakpoint (D3-02, new this phase)

**What:** 768 is introduced this phase. It must appear as a real `@media (min-width: 768px)` rule somewhere meaningful, not merely in the comment, to honor "introduced this phase." Candidate: a tablet refinement on `.cl-main` padding or a 2→ wider layout step. The plan should pick ONE genuine consumer of 768 (do not add an empty/no-op rule). The most defensible consumer is `.cl-main` gutter or a `.cl-home-grid` intermediate — but verify it produces a real visual improvement at 768 before adding; an unused breakpoint is itself drift.

### Anti-Patterns to Avoid

- **Tokenizing breakpoints:** `@media (min-width: var(--cl-bp-md))` silently no-ops. NEVER do this (D3-03). The comment block must say so.
- **Re-wrapping already-wrapped tables:** all 4 are wrapped; blindly adding another wrapper would double-nest. VERIFY, don't re-apply.
- **Re-stacking the conversation layout:** L528-533 already stacks below 1024. Do not add a second media query.
- **Adding an unused 768 rule** just to "use" the breakpoint — that is drift. Make it earn its place.
- **Migrating `var(--cl-primary)` out of the inbox bulk-bar button** without preserving the literal token string — four integration tests assert it (see Pitfall 3).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Table horizontal scroll | A custom JS scroller | Existing `.cl-table-scroll` { overflow-x:auto } (L448) | Native overflow + `:focus-visible` keyboard scroll already implemented |
| 44px tap target | Per-element ad-hoc padding | `--cl-control-h-lg: 44px` token / `min-height/min-width:44px` pattern (L524, L801) | Token-consistent; matches existing `.cl-modal-close`/`.cl-switch` |
| Breakpoint constants | A Sass/PostCSS variable system | Literal numbers + one comment block | No build step exists; var() is illegal in @media |
| CSS-presence test | A new framework | `cairnloop_css_test.exs` `File.read!` + `=~` pattern | Already proven DB-free; just add cases |
| Markup-attribute test | A browser/Playwright test | `Phoenix.LiveViewTest` render + `=~` on HTML | DB-light render assertions already used in `inbox_live_test.exs` |

**Key insight:** Nearly every mechanism this phase needs already exists in the codebase. The work is *applying and asserting* existing primitives, not building new ones.

## Common Pitfalls

### Pitfall 1: The "modal block" at L516 is actually the nav block
**What goes wrong:** CONTEXT.md / the brief describe "~L516 modal block" as the second `max-width:640` to convert. The actual code at L516-519 is a **`.cl-nav` / `.cl-nav__link`** block, not a modal. The modal selectors (`.cl-modal-backdrop` L522, `.cl-modal-dialog` L523, `.cl-modal-close` L524) have NO media query and use `width: min(640px, 92vw)` for responsiveness.
**Why it happens:** The blocks are adjacent (the nav `@media` immediately precedes the `Modals & Inbox Specific` comment at L521), and the brief's line estimates drifted.
**How to avoid:** Convert the `.cl-nav` block (the real second `max-width:640`). Do not look for a modal media query — there isn't one. After conversion, confirm via `grep -n "max-width" priv/static/cairnloop.css` that ONLY `prefers-reduced-motion` (L197, which has no width condition) and zero `max-width` width-conditions remain.
**Warning signs:** Searching for a `.cl-modal` media query and finding none.

### Pitfall 2: D3-05 and D3-04 are already satisfied — risk of redundant work
**What goes wrong:** The plan re-stacks the conversation layout or re-wraps tables, creating double-nesting or a duplicate media query.
**Why it happens:** The brief frames these as work items; Phase 37 already delivered them.
**How to avoid:** The conversation layout base is `flex-direction: column` (L528, stacked) with `@media (min-width:1024px) { flex-direction: row }` (L529-533) — already mobile-first and stacks below `lg`. All 4 tables already carry `role="region" tabindex="0" aria-label`. Plan these as VERIFY (assertion test) + "do not regress during normalization," not BUILD.
**Warning signs:** A task that says "add stacking media query" or "wrap table in `.cl-table-scroll`."

### Pitfall 3: Migrating inline `var(--cl-primary)` styles breaks integration tests
**What goes wrong:** D3-08 says migrate inline styles to utilities. The inbox bulk-bar primary button has `style="background: var(--cl-primary);"` (inbox_live.ex L236). Four tests assert the literal string `var(--cl-primary)` appears in rendered HTML (`bulk_recovery_live_test.exs:99`, `approval_footer_live_test.exs:52`, `tool_execution_outcome_live_test.exs:319/398/448`). Moving the token into the CSS file would remove it from rendered HTML and fail those tests.
**Why it happens:** The brand §7.5 "never color alone" rule is enforced by asserting the token is literally present in the rendered markup, not in the stylesheet.
**How to avoid:** For D3-08, scope inline→class migration to **purely layout** styles (margins, widths, flex) — NOT the `var(--cl-primary)`/`var(--cl-danger)` color affordances that tests assert. The brief's D3-08 says "responsive-relevant inline styles"; the color-token inline styles are NOT responsive-relevant. Leave them. (If the planner wants to migrate them anyway, the utility class itself would still not put the token string in rendered HTML — so those specific styles must stay inline or the tests must change. Recommend: leave them.)
**Warning signs:** A task touching inbox_live.ex L236, L267 or conversation_live.ex color-token inline styles.

### Pitfall 4: The two raw checkboxes are the real tap-target gap
**What goes wrong:** The plan focuses on bulk-bar *buttons* (already `cl_button`, but default 36px) and misses the **raw `<input type="checkbox">`** at inbox_live.ex L193-197 (select-all) and L207-213 (per-row select). Native checkboxes render ~13-16px — well below 44px.
**Why it happens:** They're plain HTML inputs, not `.cl-`-classed controls, so they're easy to overlook.
**How to avoid:** Either add a `.cl-checkbox` utility (min 44×44 hit area via padding or a sized label wrapper) or give the inputs a `min-width/min-height: 44px` style via a new class. Also evaluate: the bulk-bar `cl_button` controls default to 36px (`--cl-control-h-md`); to meet D3-07 they should use `size="lg"` (`.cl-button--lg` = 44px, L324) or a bulk-bar-scoped `min-height:44px` rule. The `cl_button` component supports `size="lg"` (components.ex L31).
**Warning signs:** No mention of `<input type="checkbox">` or `size="lg"` in the plan.

### Pitfall 5: Sticky bulk-bar last-row clearance — no spacer currently exists
**What goes wrong:** `.cl-inbox-bulk-bar` is `position: sticky; bottom: 0` (L525). When selections exist, the bar overlays the bottom of the scroll area; the last `<li>` row can sit underneath it. There is NO `padding-bottom` on the inbox `<ul class="cl-stack">` (L203) or any bottom spacer.
**Why it happens:** Sticky bottom bars occlude trailing content unless the scroll container reserves bottom space equal to the bar's height.
**How to avoid:** The fix is layout-context dependent. Because the bulk-bar renders as a sibling AFTER the `<ul>` inside the same `.cl-main` flow (inbox_live.ex L223-239, bar is after the list), and the page scrolls at the document level (no inner overflow container on the list), the sticky bar sticks to the viewport bottom while content scrolls behind it. The concrete fix: add `padding-bottom` to the list container (or a bottom spacer) ≥ the bar's rendered height (bar padding `space-4`=12px×2 + control height ~36-44px ≈ 60-68px → reserve `var(--cl-space-10, 48px)` to `space-12`). VERIFY at 768px viewport that the last selectable row is fully visible above the bar. This is the one item that genuinely needs manual viewport verification.
**Warning signs:** A "fixed" claim with no padding/spacer change and no manual 768px check.

## Code Examples

### Verifying remaining max-width conditions are gone (post-conversion)
```bash
# Should return ONLY the prefers-reduced-motion line (which has no width condition),
# and the layout-token comment at L136 mentioning max-width in prose.
grep -n "max-width" priv/static/cairnloop.css
# Expect: NO "@media (max-width:" width-condition lines remain after conversion.
```

### CSS-presence drift-proofing test (extend existing cairnloop_css_test.exs)
```elixir
# Source: pattern mirrors test/cairnloop/web/cairnloop_css_test.exs (existing, DB-free)
describe "responsive normalization (D3 / RESP-01)" do
  test "no max-width width media conditions remain (mobile-first)", %{css: css} do
    refute css =~ ~r/@media\s*\(\s*max-width/, "all media queries must be min-width (mobile-first)"
  end

  test "documents the three standardized breakpoints as literal constants", %{css: css} do
    assert css =~ "640px"
    assert css =~ "768px"   # tablet breakpoint introduced Phase 43
    assert css =~ "1024px"
  end

  test "breakpoints are NOT tokenized (var() illegal in @media)", %{css: css} do
    refute css =~ ~r/@media\s*\([^)]*var\(/, "var() in @media silently no-ops"
  end

  test ".cl-table-scroll still defined (no regression)", %{css: css} do
    assert css =~ ".cl-table-scroll"
  end
end
```

### Markup-attribute drift-proofing test (per-table, pure render)
```elixir
# Source: pattern mirrors test/cairnloop/web/inbox_live_test.exs (LiveViewTest render + =~)
# Asserts each .cl-table is wrapped with the accessible region attributes.
# These render with data present; some need a seeded row to pass the :if guard.
test "audit log table is wrapped in an accessible scroll region" do
  {:ok, _view, html} = live(conn, "/audit")   # adjust route + seed as needed
  assert html =~ ~s(class="cl-table-scroll")
  assert html =~ ~s(role="region")
  assert html =~ ~s(tabindex="0")
  assert html =~ ~r/aria-label="[^"]*[Aa]udit/
end
```
*Caveat:* the wrappers render behind `:if={@... != []}` guards (audit L170, settings L246, KB index L77, suggestion_review L222). A pure render with empty data will NOT emit them. Tests must seed at least one row OR — cheaper and Repo-independent — assert the wrapper attributes via a **source-file string scan** of the `.ex` render files (mirroring `brand_token_gate_test.exs`'s `File.read!` approach), which needs no DB at all. The source-scan approach is the recommended drift-proofing given "Repo may be unavailable."

### Source-scan table-wrapper assertion (Repo-independent, recommended)
```elixir
# Source: pattern mirrors test/cairnloop/web/brand_token_gate_test.exs (File.read! scan, DB-free)
@table_files ~w(
  audit_log_live.ex settings_live.ex
  knowledge_base_live/index.ex knowledge_base_live/suggestion_review.ex
)
for file <- @table_files do
  test "#{file}: every cl-table is preceded by an accessible cl-table-scroll wrapper" do
    src = File.read!(Path.join(@web_dir, unquote(file)))
    # Every `class="cl-table` occurrence must be inside a cl-table-scroll region block.
    assert src =~ ~s(class="cl-table-scroll"), unquote(file) <> " missing scroll wrapper"
    assert src =~ ~s(role="region"), unquote(file) <> " missing role=region"
    assert src =~ ~s(tabindex="0"), unquote(file) <> " missing tabindex"
    assert src =~ "aria-label", unquote(file) <> " missing aria-label"
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `max-width` desktop-base overrides | `min-width` mobile-first authoring | This phase (D3-01) | Standard CSS methodology; better cascade predictability |
| Tables overflow / clip in narrow containers | `.cl-table-scroll` accessible region | Phase 37 (already shipped) | Verified done; this phase asserts it |
| Conversation 2-col always-on | Stacks below 1024 via `min-width` query | Phase 37/earlier (already shipped) | Verified done (L528-533) |

**Deprecated/outdated in the brief vs reality:**
- The brief/CONTEXT describe the L516 block as a "modal block" — it is the `.cl-nav` block. Corrected here.
- D3-04 and D3-05 are described as work items but are already implemented; reframe as verification.

## Runtime State Inventory

This is a CSS + markup phase, not a rename/refactor/migration. No runtime state categories apply.
- **Stored data:** None — no DB writes or key/collection renames.
- **Live service config:** None — no external service config.
- **OS-registered state:** None.
- **Secrets/env vars:** None.
- **Build artifacts:** None — no build step exists (single static `cairnloop.css`, served as-is). `prompts/cairnloop.css` is an 11-line snippet/reference, NOT a duplicate stylesheet that needs syncing (verified: 11 lines vs 826; not referenced by any served asset path).

## Common Pitfalls (cross-check)

Verified: there are exactly **two** width-conditioned `@media` blocks using `max-width` (L263, L516) plus `prefers-reduced-motion` (L197, no width). Two existing `min-width` blocks (L426, L427) plus the conversation `min-width:1024` (L529) are already mobile-first and conform. After this phase, every width-conditioned `@media` must be `min-width`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / mix | compile + test | ✓ (project standard) | 1.19.5 (CI pin) | — |
| Postgres | NOT required this phase (CSS/markup only) | partial (may be unavailable per CLAUDE.md) | — | Use pure file-scan tests (recommended); mark Repo-dependent render tests `# REPO-UNAVAILABLE` |
| Browser (manual 768px check) | Pitfall 5 bulk-bar clearance verification | human | — | Visual acceptance via existing screenshot pipeline (`examples/cairnloop_example/screenshots/capture.mjs`) or manual resize |

**Missing dependencies with no fallback:** None — the phase is fully implementable with CSS edits + file-scan tests; only the bulk-bar clearance benefits from a human/visual viewport check.

## Validation Architecture

> nyquist_validation: enabled (no `workflow.nyquist_validation` key in `.planning/config.json` → treat as enabled).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) + Phoenix.LiveViewTest |
| Config file | `test/test_helper.exs` (standard) |
| Quick run command | `mix test test/cairnloop/web/cairnloop_css_test.exs test/cairnloop/web/inbox_live_test.exs` |
| Full suite command | `mix test` (excludes `:integration`); integration: `PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RESP-01 | No `max-width` width media conditions remain | unit (CSS file scan) | `mix test test/cairnloop/web/cairnloop_css_test.exs` | ✅ extend existing |
| RESP-01 | Breakpoints 640/768/1024 present as literals | unit (CSS file scan) | same | ✅ extend |
| RESP-01 | No `var()` inside `@media` | unit (CSS file scan) | same | ✅ extend |
| RESP-02 | Each `.cl-table` wrapped w/ role/tabindex/aria-label | unit (source `.ex` scan, Repo-free) | `mix test test/cairnloop/web/cairnloop_css_test.exs` (or new `responsive_markup_test.exs`) | ❌ Wave 0 (recommended new test) |
| RESP-02 | Conversation layout stacked base + min-width:1024 row | unit (CSS file scan) | `assert css =~ ".conversation-layout"` + min-width:1024 | ❌ Wave 0 (cheap add) |
| RESP-02 | Bulk-bar wraps (`.cl-row--wrap`) + tap targets ≥44px present | unit (CSS scan + markup) | assert `.cl-button--lg`/min-height:44px on bulk controls; assert checkboxes sized | ❌ Wave 0 |
| RESP-02 | Bulk-bar clears last row at 768px | **manual / visual** | screenshot pipeline or manual resize | human-needed |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/cairnloop_css_test.exs` (+ the new markup test) — sub-second, DB-free.
- **Per wave merge:** `mix compile --warnings-as-errors` + `mix test` (incl. brand-token gate).
- **Phase gate:** Full suite green + manual 768px viewport verification of (a) bulk-bar last-row clearance, (b) tap targets, (c) no visual regression from the two min-width conversions.

### Wave 0 Gaps
- [ ] `test/cairnloop/web/cairnloop_css_test.exs` — extend with RESP-01 CSS-presence cases (no max-width, three breakpoints, no var() in @media). Reuse existing `setup_all` css read.
- [ ] `test/cairnloop/web/responsive_markup_test.exs` (or add to existing) — source-scan that all 4 table files carry `cl-table-scroll`/`role="region"`/`tabindex="0"`/`aria-label`; mirror `brand_token_gate_test.exs` `File.read!` approach (Repo-free).
- [ ] No framework install needed — ExUnit + LiveViewTest already present.

*(The only verification that is genuinely human-needed is the bulk-bar last-row clearance and the visual no-regression check of the two min-width conversions at 768px.)*

## Security Domain

> security_enforcement: no key in config → treat as enabled, but this is a presentation-only phase.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface touched |
| V3 Session Management | no | None |
| V4 Access Control | no | None |
| V5 Input Validation | no | No new inputs; existing checkboxes unchanged in behavior |
| V6 Cryptography | no | None |
| V14 Configuration | minimal | CSS served as static asset; no config change |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| CSS injection via inline style | Tampering | All styles are static / token-valued; no user-controlled style strings introduced |
| A11y regression (not security but governance-adjacent) | — | `role`/`tabindex`/`aria-label` preserved + asserted; `:focus-visible` ring on scroll region |

No new attack surface. The phase strictly improves accessibility and layout; it does not handle data, auth, or untrusted input.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 768 must appear as a real `@media (min-width:768px)` consumer (not just a comment) to honor "introduced this phase" | Pattern 3 | Low — if a no-op comment-only mention is acceptable to the owner, the plan can skip a 768 rule. Recommend confirming during planning whether a genuine 768 layout step exists. |
| A2 | The inbox page scrolls at document level (no inner overflow container on the list), so the sticky bar's clearance fix is `padding-bottom` on the list | Pitfall 5 | Medium — if a host embeds the cockpit in a constrained overflow container, the spacer location may differ. Manual 768px verification resolves this. |
| A3 | D3-08 should NOT migrate the color-token inline styles (`var(--cl-primary)` etc.) because integration tests assert their literal presence in HTML | Pitfall 3 | Medium — if the owner wants them migrated, the four integration tests must be updated; recommend leaving them (calm, additive). |

## Open Questions

1. **Does a genuine 768 tablet layout improvement exist, or is 768 documentation-only?**
   - What we know: D3-02 mandates 768 as a documented constant and calls it "the new tablet breakpoint introduced this phase."
   - What's unclear: Whether any rule meaningfully changes at 768 (vs only 640/1024). An empty 768 rule would be drift.
   - Recommendation: During planning, identify ONE real consumer (e.g., `.cl-main` gutter step, or an inbox/table density tweak) that visibly improves the tablet experience; if none is justified, document 768 in the comment block as the tablet constant and add a single small, real rule (e.g., slightly larger `.cl-main` gutter at ≥768) rather than a no-op.

2. **Should the two raw checkboxes get a shared `.cl-checkbox` utility or per-input sizing?**
   - What we know: Both raw inputs (L193, L207) are sub-44px; a `.cl-switch` 44px pattern already exists as precedent.
   - Recommendation: Add a small `.cl-checkbox` utility (44×44 hit area, e.g. via padding on a label wrapper or `min-height/min-width` + accessible label) and apply at both sites — consistent, testable, reusable. Avoid changing checkbox semantics/behavior (sealed inbox bulk-select logic).

## Sources

### Primary (HIGH confidence) — direct code reads this session
- `priv/static/cairnloop.css` — L130-156 (tokens incl. `--cl-control-h-lg:44px`, layout tokens), L261/263 (`.cl-main` + max-width:640), L390-398 (`.cl-table`), L425-427 (`.cl-home-grid` min-width), L448-449 (`.cl-table-scroll`), L516-525 (`.cl-nav` max-width:640 + `.cl-modal-*` + `.cl-inbox-bulk-bar`), L528-549 (`.conversation-layout` stacking + `.cl-rail-controls`), L799-817 (`.cl-switch` 44px), L324 (`.cl-button--lg`).
- `lib/cairnloop/web/audit_log_live.ex` L170-171, `settings_live.ex` L246-247, `knowledge_base_live/index.ex` L77-78, `knowledge_base_live/suggestion_review.ex` L222-223 — all 4 tables verified wrapped.
- `lib/cairnloop/web/inbox_live.ex` L193-213 (raw checkboxes), L223-239 (bulk-bar markup, `var(--cl-primary)` inline).
- `lib/cairnloop/web/conversation_live.ex` L443-485, L507 (rail + inline styles).
- `lib/cairnloop/web/components.ex` L30-43 (cl_button variant/size), L439-443 (helpers).
- `test/cairnloop/web/cairnloop_css_test.exs` (CSS-presence test model), `brand_token_gate_test.exs` (source-scan model, gate scope = `.ex` only, `.css` excluded), `inbox_live_test.exs` L157-205 (bulk-bar render assertions), integration tests asserting `var(--cl-primary)`.
- `.planning/REQUIREMENTS.md` L57-58, 125-126 (RESP-01/02).
- `.planning/config.json` (no nyquist_validation key → enabled; no security_enforcement key).

### Secondary (MEDIUM confidence)
- `.planning/vM016-UI-ITERATION-BRIEF.md` §D3 (L128-140) — ratified direction (note: contains the "modal block" mislabel corrected here).
- `.planning/phases/43-.../43-CONTEXT.md` — locked decisions D3-01..08.

### Tertiary (LOW confidence)
- None — all claims grounded in direct code reads.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero external packages; all primitives exist in-repo.
- Architecture / before-after CSS: HIGH — exact line numbers and behavioral-equivalence reasoning verified against the actual file.
- Pitfalls: HIGH — each corroborated by a code read (the L516-is-nav-not-modal correction, the raw checkboxes, the integration-test token assertions, the absent bulk-bar spacer).
- 768 consumer / bulk-bar scroll context: MEDIUM — flagged as open questions / assumptions for planning + manual verification.

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stable — internal CSS/markup; only invalidated by edits to the cited files before planning).
