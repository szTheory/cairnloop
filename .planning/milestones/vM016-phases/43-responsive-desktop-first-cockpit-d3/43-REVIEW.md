---
phase: 43-responsive-desktop-first-cockpit-d3
reviewed: 2026-06-04T21:07:17Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/cairnloop/web/inbox_live.ex
  - priv/static/cairnloop.css
  - test/cairnloop/web/cairnloop_css_test.exs
  - test/cairnloop/web/responsive_markup_test.exs
  - examples/cairnloop_example/test/e2e/inbox_geometry_test.exs
  - examples/cairnloop_example/test/support/rail_fixtures.ex
findings:
  critical: 0
  warning: 6
  info: 5
  total: 11
status: resolved
resolved: 2026-06-04T21:30:00Z
disposition:
  fixed: [WR-01, WR-02, WR-04, WR-05, "WR-06.1", IN-01, IN-02, IN-03, IN-05]
  accepted: ["WR-03", "WR-06.2", IN-04]
---

## Disposition (orchestrator, 2026-06-04)

**Fixed (commit follows this report):**
- **WR-01** — `.cl-inbox-list--bulk-clearance` now reserves the full bar height
  `calc(var(--cl-control-h-lg, 44px) + var(--cl-space-7, 24px))` (≈68px); source-scan expectation in
  `responsive_markup_test.exs` updated to match.
- **WR-02** — occlusion E2E now asserts the scroll actually overflowed and the last row is on-screen
  (`0 < lastBottom ≤ innerHeight`) BEFORE comparing to the bar — kills the trivial false-pass.
- **WR-04** — 768 regression guard now asserts `padLeft ≥ 32` (isolates the min-width:768 step; the
  640 step at 24px no longer satisfies it).
- **WR-05** — seed decoupled from the cap (30 rows, not 25=`max_batch_size`); tests select two rows
  (under cap) instead of select-all; occlusion test asserts `scrollHeight > innerHeight`.
- **WR-06.1** — added a lib-suite wiring guard (`responsive_markup_test.exs`) asserting the E2E file
  exists, carries `@moduletag :e2e`, and measures `getBoundingClientRect` — so a tag typo / deleted
  file can't silently re-open the human-verify gap.
- **IN-01/02/03/05** — moduledoc `:if`→`<%= if %>`; occlusion selector scoped to
  `li:has(input.cl-checkbox)`; thresholds hoisted to `@min_tap/@subpixel_tol/@tablet_pad_min`;
  fixture ids now used (two-row selection).

**Accepted (with rationale):**
- **WR-03** (native checkbox `min-width/height`) — CI runs Chromium, where the approach is honored,
  and the E2E measures the *real* rendered box (so a Chromium regression is caught). A label-wrap
  would churn the sealed bulk-select markup + four integration-test selectors for a benefit that
  only manifests on non-CI browsers. Tracked as a follow-up if a multi-browser matrix is added.
- **WR-06.2** (`host_user_id` nil on confirm) — latent only; these geometry tests never open the
  confirm modal. If a confirm-flow assertion is later added here, seed `host_user_id` via
  `LiveAcceptance`.
- **IN-04** (duplicated breakpoint comment) — cosmetic; the `cairnloop_css_test` already pins the
  authoritative BREAKPOINTS banner.


# Phase 43: Code Review Report

**Reviewed:** 2026-06-04T21:07:17Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 43 normalizes `cairnloop.css` to mobile-first (`min-width`) breakpoints, adds a
`.cl-checkbox` 44px tap-target utility and a `.cl-inbox-list--bulk-clearance` reserve, and
introduces a new Playwright E2E (`inbox_geometry_test.exs`) that measures rendered geometry at a
768px viewport. The CSS mobile-first contract is correctly enforced: no `max-width` width media
conditions survive (verified — the former `@media (max-width: 640px)` blocks were converted), and
no `var()` appears inside any `@media` condition. The `var(--cl-primary)` inline literal that four
integration tests depend on is preserved on the primary bulk-bar button.

No BLOCKER-class defects (no injection, no data-loss, no crash path introduced). However the new
E2E and the clearance CSS carry several robustness gaps that can cause **false-passes** (the test
asserting a property that is trivially true regardless of the real behavior) or **flakes**, plus
an arithmetic mismatch between the documented bulk-bar height and the reserved clearance. Because
this E2E is the *automated replacement for a deleted human-verify checkpoint*, a false-passing
assertion is materially worse than no assertion — it manufactures false confidence in the exact
geometry the human was previously checking. Those are filed as WARNINGs below.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Bulk-bar clearance (48px) is smaller than the documented bulk-bar height (~68px)

**File:** `priv/static/cairnloop.css:549-553`
**Issue:** The clearance rule reserves `padding-bottom: var(--cl-space-10, 48px)` but its own
comment computes the sticky bar height as "≈ 44px button + 12px×2 padding = 68px". 48px < 68px, so
the reserved space is ~20px short of the bar it is meant to clear. The `.cl-inbox-bulk-bar` button
is now `size="lg"` (44px) plus `padding: var(--cl-space-4, 12px)` top+bottom = ~68px tall. On a
fully-scrolled list the sticky bar can still overlap the last row by ~20px — exactly the occlusion
the clearance is supposed to prevent. The comment admits `--cl-space-10` was chosen only because
it is "the largest available token step that ships today," i.e. the value was picked for token
availability, not to satisfy the geometry. This is the genuinely browser-only fact the new E2E
(WR-02) is meant to guard, so the two defects compound.
**Fix:** Reserve clearance ≥ the real bar height. Either add/use a larger spacing token, or compose
two existing steps, e.g.:
```css
/* 68px ≈ 44px control + 12px×2 bar padding + a little breathing room */
.cl-inbox-list--bulk-clearance { padding-bottom: calc(var(--cl-control-h-lg, 44px) + var(--cl-space-7, 24px)); }
```
Then update the responsive_markup_test assertion (`padding-bottom: var(--cl-space-10`) to match the
new expression so the source-scan contract stays in sync.

### WR-02: Occlusion E2E can false-pass when the last row scrolls above the viewport

**File:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs:113-137`
**Issue:** The occlusion test scrolls to `document.body.scrollHeight`, then asserts
`last_bottom <= bar_top + 1`. The assertion only proves "the last row's bottom is at/above the
bar's top." It never verifies the last row is actually **within the viewport**. If the page is
short enough that scrolling to the bottom puts the last `<li>` partially or fully *above* the
viewport (negative or small `bottom`), the inequality holds trivially and the test passes even if a
real user would see the bar covering the row in a differently-sized list. The test also does not
assert `last_bottom > 0` (row is on-screen) or that the bar is actually stuck to the viewport
bottom (`bar.getBoundingClientRect().bottom ≈ innerHeight`). Because this E2E *replaces* the deleted
43-03 human-verify checkpoint, a trivially-true assertion is a false-confidence regression.
**Fix:** Pin the bar to the viewport and pin the row on-screen before comparing:
```elixir
fn %{"lastBottom" => last_bottom, "barTop" => bar_top, "barBottom" => bar_bottom, "innerHeight" => inner_h} ->
  assert last_bottom > 0, "last row scrolled off the top of the viewport (#{last_bottom}px) — test cannot prove non-occlusion"
  assert_in_delta bar_bottom, inner_h, 1, "sticky bar is not pinned to the viewport bottom (#{bar_bottom} vs #{inner_h})"
  assert last_bottom <= bar_top + 1, "last row (#{last_bottom}px) occluded by sticky bar (top #{bar_top}px)"
end
```

### WR-03: `.cl-checkbox` sizing relies on min-width/min-height on a native replaced element

**File:** `priv/static/cairnloop.css:538-546` and assertion at `inbox_geometry_test.exs:59-77`
**Issue:** The 44px tap-target utility is applied directly to `<input type="checkbox">` (a *replaced*
form element) via `display: inline-flex; min-width: 44px; min-height: 44px`. `display`,
`min-width`, and `min-height` on replaced form controls are honored inconsistently across engines —
several browsers clamp a checkbox to its intrinsic ~13px box and ignore `min-width/min-height`,
yielding a `getBoundingClientRect()` well under 44px. The E2E (`box(sel)` measuring the input's own
rect) would then **fail** in those engines, or — worse — pass only on the specific Playwright
Chromium build in CI while real Safari/Firefox users get a sub-44px target. The brand convention
established elsewhere (`.cl-modal-close`, `.cl-switch`) puts the 44px box on a *wrapping button*,
not on the raw input; this utility breaks that precedent.
**Fix:** Either wrap each checkbox in a `<label class="cl-checkbox">` that contains the input and
sizes the label (the label is the hit area), or verify in the target browser matrix that the input
itself measures ≥44px. If keeping it on the input, prefer explicit `width`/`height` plus
`appearance` control rather than `min-*` on a replaced element.

### WR-04: 768px padding E2E does not isolate which breakpoint fired (≥24 also passes the 640px step)

**File:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs:149-165`
**Issue:** The RESP-01 regression guard runs at a 768px viewport and asserts `padLeft >= 24`. But the
`@media (min-width: 640px)` rule already sets `.cl-main` padding to 24px, and the `@media
(min-width: 768px)` rule sets it to 32px. At 768px both rules match and the 768 rule wins (32px),
so the *intended* assertion is "768 step fired." `>= 24` passes even if the 768px rule silently
regressed and only the 640px rule applied (24px). The test name claims it proves the 768 conversion
is live, but the threshold only proves the 640 conversion is live. This weakens the very regression
it is named for.
**Fix:** Assert the 768-specific value: `assert pad_left >= 32` (the `--cl-space-8` step). Keep a
separate, weaker `>= 24` only if you also add a distinct assertion at a 700px viewport to exercise
the 640 step independently.

### WR-05: E2E selects exactly `max_batch_size` (25) rows — boundary coupling makes the suite fragile

**File:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs:42-46` (fixture call) and
`lib/cairnloop/web/inbox_live.ex:73-75`
**Issue:** The fixture seeds exactly 25 resolved rows and select-all selects all 25.
`max_batch_size` defaults to 25 (`inbox_live.ex:73`). The geometry tests only ever surface the
bulk-bar (`MapSet.size > 0`), which is fine — but the suite is one config change away from a
confusing failure: if a future config lowers `:max_batch_size` below 25, nothing in *these* tests
breaks (they never open the confirm modal), yet the "25 rows overflow a 720px viewport" comment
implies a hard dependency on the count. The brittle part is the hidden coupling: the row count (25)
equals the cap (25) by coincidence, and the test relies on "25 rows overflow 720px" without
asserting the list actually scrolled (no `scrollHeight > innerHeight` precondition). If a future
denser row style fits 25 rows in 720px, the occlusion test silently stops exercising a real scroll.
**Fix:** Decouple from the cap (seed e.g. 30 rows, unrelated to `max_batch_size`) and add an
explicit precondition in the occlusion test:
`assert document.body.scrollHeight > window.innerHeight` before asserting clearance, so a
non-scrolling list fails loudly instead of false-passing.

### WR-06: `inbox_geometry_test.exs` is not registered in any `@table_files`/test-tag CI lane assertion here, and depends on `host_user_id` session never being asserted

**File:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs:24-28, 42-46`
**Issue:** Two coupled robustness gaps. (1) The suite is tagged `:e2e` and relies on the gated `e2e`
lane; per project memory `mix test` excludes integration/e2e, so a green local `mix test` says
nothing about this file — there is no in-repo guard that this new file is actually wired into the
e2e lane (a typo in the tag or a missing `test.e2e` include would silently skip it, re-opening the
human-verify gap it was meant to close). (2) The fixture sets `host_user_id: "e2e_operator"` on
every row, and the moduledoc/fixture both note "the inbox does not scope by host_user_id, so the
value here is cosmetic" — correct today, but `InboxLive.mount/3` reads `host_user_id` from session
(`inbox_live.ex:100`) and the example never seeds it, so `@host_user_id` is `nil` and
`do_confirm_bulk_send/1` would send `actor: nil`. The geometry tests never exercise confirm, so
this is latent, but any future addition of a confirm-flow assertion to this file would silently send
with a `nil` actor.
**Fix:** (1) Add a cheap source-scan/registration assertion (or CI lane manifest check) that
`inbox_geometry_test.exs` carries `@moduletag :e2e` and is picked up by `mix test.e2e`. (2) If/when
this file grows a confirm-send assertion, seed `host_user_id` into the session via the example
`LiveAcceptance` on_mount so `actor` is non-nil and the audit trail is meaningful.

## Info

### IN-01: `responsive_markup_test.exs` moduledoc claims `:if={...}` guards but inbox uses `<%= if %>`

**File:** `test/cairnloop/web/responsive_markup_test.exs:18-21`
**Issue:** The moduledoc justifies the source-scan approach by saying "the wrappers render behind
`:if={@... != []}` guards." The actual inbox markup uses `<%= if ... do %>` HEEx blocks
(`inbox_live.ex:191, 225, 244`), not the `:if` attribute. The reasoning (LiveViewTest with empty
data won't emit them) is still valid, but the comment misdescribes the code, which can mislead a
future maintainer into grepping for `:if`.
**Fix:** Reword to "behind `<%= if ... do %>` guards" or generically "behind emptiness guards."

### IN-02: Occlusion-test selector assumes the last `<li>` is a selectable row

**File:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs:119-121`
**Issue:** `rows[rows.length - 1]` grabs the last `<li>` in the list. Every `<li>` in the inbox is a
row, so this is correct today — but it silently assumes no non-row `<li>` is ever appended to the
`<ul>` (e.g. a future "load more" sentinel li). If that happens the test measures the wrong element.
**Fix:** Scope to actual selectable rows, e.g. `li:has(input.cl-checkbox)` or add a row class and
select on it, so the assertion remains pinned to a real conversation row.

### IN-03: Magic threshold `+ 1` tolerance is undocumented as a constant

**File:** `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs:133`
**Issue:** The `bar_top + 1` sub-pixel tolerance is a bare magic number inline. It is explained in the
adjacent comment, but repeated bare `+ 1`/`>= 44`/`>= 24` thresholds across the file invite drift.
**Fix:** Hoist viewport/threshold constants (`@min_tap 44`, `@subpixel_tol 1`,
`@tablet_pad_min 32`) to module attributes so all three describe-blocks share one source of truth.

### IN-04: CSS comment block re-documents breakpoints in two places (drift risk)

**File:** `priv/static/cairnloop.css:135-138` and `priv/static/cairnloop.css:514-522`
**Issue:** The "var() is illegal in @media" warning and the breakpoint list are documented both in
the `:root` layout-tokens block and again in the BREAKPOINTS banner. Two copies of the same
invariant can drift; the cairnloop_css_test only asserts the string `BREAKPOINTS` and the three
literals exist, not that the two comment blocks agree.
**Fix:** Keep the authoritative breakpoint legend in one place (the BREAKPOINTS banner) and have the
`:root` comment point to it rather than restating values.

### IN-05: `resolved_inbox_rows/1` return value (ids) is unused by the geometry suite

**File:** `examples/cairnloop_example/test/support/rail_fixtures.ex:132-143` and
`inbox_geometry_test.exs:45`
**Issue:** `setup` stashes `%{ids: resolved_inbox_rows(25)}` but no test reads `ids` — the geometry
assertions only need the rows to exist, not their ids. The fixture builds and returns a 25-element
list purely for its insert side-effect. Harmless, but the unused binding obscures intent.
**Fix:** Either drop the `%{ids: ...}` wrapping (call the fixture for effect: `resolved_inbox_rows(25)`
and return `:ok`), or add a comment that `ids` is intentionally unused by this suite and retained for
parity with the other rail fixtures' return shape.

---

_Reviewed: 2026-06-04T21:07:17Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
