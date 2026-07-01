---
phase: 37-component-primitives
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/cairnloop/web/components.ex
  - lib/cairnloop/web/audit_log_live.ex
  - lib/cairnloop/web/knowledge_base_live/index.ex
  - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
  - lib/cairnloop/web/settings_live.ex
  - priv/static/cairnloop.css
  - test/cairnloop/web/components_test.exs
  - test/cairnloop/web/cairnloop_css_test.exs
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
warnings_resolved: 3
warnings_resolved_at: 2026-06-03
warnings_resolved_note: >-
  WR-01, WR-02, WR-03 fixed via /gsd:code-review --fix (commits 66e59bc,
  6ba7fa1). Only Info-tier (IN-01..IN-04) findings remain unaddressed.
---

# Phase 37: Code Review Report

**Reviewed:** 2026-06-03
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 37 ships eight new stateless `Phoenix.Component` primitives (`cl_page`, `cl_hero`,
`cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch`, plus the
`cl_stat` narrowing) with matching token-only CSS and adopts `.cl-table-scroll` wrappers in four
LiveViews. Build is warnings-clean (`mix compile --warnings-as-errors` exits 0) and all 42 new
tests pass.

The accessibility-critical primitives are mostly well-built: `cl_switch` is a real
`role="switch"` with a string `aria-checked` and an always-visible label; `cl_disclosure` is a
native `<details>` with `phx-update="ignore"` + required stable `id` and never binds `open` to a
server assign; CSS is fully token-driven (zero hardcoded hex in the Phase-37 block). The
"never color alone" contract holds — the switch pairs color with thumb *position* (shape) plus
`aria-checked` for AT, which satisfies brand §7.5.

Three issues degrade correctness/robustness and should be fixed:

1. The `.cl-table-scroll` adoption renders an **empty focusable region** in all four LiveViews
   when the underlying collection is empty (the wrapper `<div>` is unconditional; only the inner
   `<table>` is guarded by `:if`).
2. `cl_hero` declares an `inner_block` slot, documents it as the winning CTA path, but **never
   renders it** — any inner-block content passed to `cl_hero` is silently dropped.
3. The `cl_hero` moduledoc contradicts the implementation (`inner_block` vs `cta_slot`).

The remaining items are API-consistency nits across the new primitives.

## Warnings

### WR-01: `.cl-table-scroll` renders an empty focusable region in the empty state

**File:** `lib/cairnloop/web/audit_log_live.ex:129`, `lib/cairnloop/web/knowledge_base_live/index.ex:78`, `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:220`, `lib/cairnloop/web/settings_live.ex:246`

**Issue:** In all four adopting LiveViews the wrapper

```heex
<div class="cl-table-scroll" role="region" tabindex="0" aria-label="Audit log">
  <table :if={@visible_events != []} class="cl-table"> ... </table>
</div>
```

renders the `<div>` **unconditionally**, but the `<table>` inside it is guarded by `:if={... != []}`.
When the collection is empty, the page shows the `cl_empty` state AND an empty `role="region"`
element that is still keyboard-focusable (`tabindex="0"`) and announced by screen readers (e.g.
"Policies, region" / "Audit log, region") with no content inside. This is a real a11y defect: an
empty named landmark region plus a focus stop that lands on nothing. It also means the focus-ring
(`.cl-table-scroll:focus-visible`) can appear around a zero-height box.

**Fix:** Move the `:if` guard onto the wrapper `div` so the region only exists when there is a
table to scroll. Apply to all four sites:

```heex
<div :if={@visible_events != []} class="cl-table-scroll" role="region" tabindex="0" aria-label="Audit log">
  <table class="cl-table">
    ...
  </table>
</div>
```

(For `settings_live.ex` use `@policies != []`; for `index.ex` `@articles != []`; for
`suggestion_review.ex` `@review_tasks != []`.) Consider extracting this into a small
`cl_table_scroll` component so the guarded-wrapper pattern can't drift per call site.

### WR-02: `cl_hero` silently drops its declared `inner_block` slot

**File:** `lib/cairnloop/web/components.ex:159-180`

**Issue:** `cl_hero` declares `slot(:inner_block)` (line 166) and the moduledoc (lines 151-158)
states: *"when an `:inner_block` CTA slot is provided it wins; otherwise when `@cta` is set,
renders `<.cl_button variant="primary">`."* But the render body never calls
`render_slot(@inner_block)` — it only renders `@detail`, `@cta_slot`, and the `@cta`/`@href`
fallback. Any content a caller passes as the default inner block of `cl_hero` is parsed,
allocated, and then silently discarded. This is a dead slot and a correctness trap: a caller
following the documented "inner block wins" contract will see their CTA vanish with no error.

**Fix:** Either remove the unused `inner_block` slot declaration (if `cta_slot` is the intended
CTA-override mechanism), or render it and make the precedence real. If `cta_slot` is canonical:

```elixir
attr(:count, :integer, required: true)
attr(:job, :string, required: true)
attr(:href, :string, default: nil)
attr(:cta, :string, default: nil)
attr(:calm?, :boolean, default: false)
slot(:detail)
slot(:cta_slot)
# remove: slot(:inner_block)
```

Then update the moduledoc to describe `:cta_slot` (not `:inner_block`) as the override slot — see
WR-03.

### WR-03: `cl_hero` moduledoc contradicts the implementation

**File:** `lib/cairnloop/web/components.ex:151-158` (doc) vs `168-180` (code)

**Issue:** The moduledoc describes CTA precedence in terms of an `:inner_block` CTA slot, but the
code keys precedence off `@cta_slot` (`<div :if={@cta_slot != []}>` then
`<div :if={@cta_slot == [] && @cta}>`). The documented slot name and the implemented slot name do
not match, so a reader following the docstring will pass content into the wrong (and, per WR-02,
non-rendered) slot. Misleading docs on a public library component are a maintainability hazard.

**Fix:** Rewrite the precedence paragraph to reference `:cta_slot`:

```
CTA precedence: when a `:cta_slot` is provided it wins; otherwise when `@cta` is set,
renders `<.link class="cl-button cl-button--primary">`. Both are optional.
```

(Note the fallback renders a `<.link>` styled as a button, not `<.cl_button>` as the current doc
claims — align the doc to the actual markup at line 176.)

## Info

### IN-01: `cl_source_card` uses bracket access where sibling components use dot access

**File:** `lib/cairnloop/web/components.ex:278` (`assigns[:icon]`)

**Issue:** `cl_source_card` resolves its icon via `assigns[:icon] || status_icon(...)`, while the
parallel `cl_chip` (line 78) and `cl_banner` (line 97) use `assigns.icon || status_icon(...)`.
Because `:icon` has a declared default of `nil`, dot access is safe and is the established
convention in this module. The bracket form is harmless but inconsistent and invites a reader to
assume `:icon` might be absent (it never is). Prefer `assigns.icon` for consistency.

**Fix:** `assigns.icon || status_icon(assigns.source_variant)`.

### IN-02: New primitives omit the `:class` / `:rest` escape hatches every other primitive carries

**File:** `lib/cairnloop/web/components.ex` — `cl_hero` (159-180), `cl_fact_list` (215-228), `cl_source_card` (269-291), `cl_status_cell` (302-312), `cl_page` (322-347)

**Issue:** Almost every pre-existing primitive (`cl_button`, `cl_card`, `cl_chip`, `cl_banner`,
`cl_empty`, `cl_icon`) exposes a `:class` passthrough and/or a `:rest` global so callers can add a
test hook, a margin utility, or a `phx-*` binding. The five new container primitives expose
neither, so a caller cannot, e.g., add `class="cl-mb-7"` to a `cl_source_card` or a `data-*`
hook to a `cl_page` without wrapping it. This limits composability of a library component and
breaks the otherwise-uniform API surface. Low risk, but worth aligning before adopters build on
these.

**Fix:** Add `attr(:class, :string, default: nil)` and `attr(:rest, :global)` to the container
primitives and thread them into the root element's `class={[...]}` / `{@rest}`, mirroring
`cl_card`.

### IN-03: `cl_fact_list` `:facts` accepts an untyped `:list` with no shape validation

**File:** `lib/cairnloop/web/components.ex:215, 221-224`

**Issue:** `attr(:facts, :list, default: [])` then `{fact.label}` / `{fact.value}` assumes every
element is a map exposing `:label` and `:value`. A caller passing a keyword list, a tuple list, or
a map missing `:value` gets a `KeyError`/`BadMapError` at render time rather than a clear contract
error. The moduledoc documents the shape but nothing enforces it. (Auto-escaping via `{...}` is
correctly used — no `raw/1` — so this is a robustness nit, not an XSS issue.)

**Fix:** Document the required `%{label, value}` shape in the `attr ... doc:` string (as
`cl_breadcrumb` does for its `:items`), and optionally guard with
`Map.get(fact, :label)` / `Map.get(fact, :value)` so a malformed entry degrades to blank rather
than crashing the LiveView.

### IN-04: `.cl-table-scroll` has no visual affordance that content is scrollable

**File:** `priv/static/cairnloop.css:448-449`

**Issue:** `.cl-table-scroll { overflow-x: auto; }` provides the scroll behavior and a
focus-visible ring, but there is no edge fade / shadow cue indicating horizontally-clipped
content exists. On a narrow viewport a wide audit table can clip columns with no visible "more to
the right" signal; sighted keyboard/mouse users may not realize the region scrolls. This is a UX
polish gap, not a correctness bug (the region is keyboard-scrollable and AT-labeled). Noting it so
it isn't mistaken for complete responsive coverage — the plan itself defers breakpoint work to P43.

**Fix:** Optionally add a right-edge scroll-shadow (e.g. a `background` linear-gradient mask on
`.cl-table-scroll`) in the P43 responsive pass; no change required this phase.

---

_Reviewed: 2026-06-03_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
