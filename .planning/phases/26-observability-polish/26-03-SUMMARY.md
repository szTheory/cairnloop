---
phase: 26-observability-polish
plan: 03
subsystem: web-polish
tags: [liveview, polish, brand-tokens, a11y, empty-state, modal, failed-bubble, elixir, phoenix]

# Dependency graph
requires:
  - phase: 25-bulk-selection-fan-out
    provides: "InboxLive bulk-confirm modal substrate (D-07 / D-08 / D-10) including `<.focus_wrap id=\"bulk-confirm-wrap\">`, `cancel_bulk_confirm` event handler, `phx-window-keydown=\"cancel_bulk_confirm\"` Escape wiring, `has_visible_eligible?/1` gate, and the existing refusal banner with text + SVG icon + var(--cl-danger) accent."
  - phase: 24-conversation-outbound-recovery
    provides: "ConversationLive `outbound_recovery_card/1` (lines 825-847) with sealed `<section aria-label=\"Outbound recovery\">` on :resolved conversations; `outbound_status_label/1` + `outbound_status_class/1` (lines 993-1014) returning the chip text + class for :system_outbound messages."
  - phase: 26-observability-polish, plan 01
    provides: "Wave 1 OBS-01 OI trace substrate (independent of this plan but closes the OBS half of the phase so this polish lands on a stable substrate)."
  - phase: 26-observability-polish, plan 02
    provides: "Wave 2 OBS-02 audit READ facade (independent of this plan)."
provides:
  - "InboxLive empty-state branch: calm 'No conversations yet.' paragraph under <h1>Inbox</h1> when @conversations == [] (var(--cl-text-muted) token, no emoji, no exclamation marks, brand book §7.5)."
  - "InboxLive modal × close button affordance: top-right button inside the focus-wrapped dialog with aria-label=\"Close\", 44px tap target, calm muted color (not red), phx-click=\"cancel_bulk_confirm\" (reuses sealed handler), anchored by `position: relative` on the dialog div, placed as the FIRST child so focus_wrap lands focus there on modal-open (Pitfall 6)."
  - "ConversationLive failed-bubble calm reason-forward subhead: 'Delivery did not complete. Try again from the Outbound recovery card.' rendered below <p class=\"message-content\"> when outbound_status_label(msg) == \"Failed\" — additive only, sealed chip + outbound_recovery_card + outbound_status_label/1 byte-for-byte unchanged (Pitfall 7)."
  - "Verification-gate tests pinning Phase 24/25 sealed surfaces: outbound_recovery_card aria-label, has_visible_eligible?/1 regression on non-resolved cohorts, chip + class names on sent/pending/failed."
affects:
  - phase 26 roadmap success criterion 3 ("tightens empty/error states and outbound affordance polish") — CLOSED.
  - threat register T-26-10/T-26-11/T-26-12/T-26-13/T-26-14 — all `mitigate` dispositions discharged (no inspect/1 in operator copy; aria-label + focus_wrap on modal close; sealed-surface byte-grep on outbound_recovery_card, outbound_status_label/1, has_visible_eligible?/1).
  - threat register T-26-15 — `accept` on D-10 (brand-token CSS class extraction explicitly deferred this phase; the inline var(--cl-…) string is the headless-test contract).
  - future operators: visible × affordance on bulk-confirm modal supplements the existing Escape-key close (discoverability polish, not new behavior).

# Tech tracking
tech-stack:
  added: []  # No new dependencies — pure template patch.
  patterns:
    - "Mutually-exclusive sibling conditionals over `@conversations == []` vs `has_visible_eligible?/1` in inbox_live.ex — empty-state branch is additive; existing Phase 25 gate untouched and verified by Tests 7 + 8."
    - "Modal close-affordance pattern: `position: relative` on the dialog + first-child absolute-positioned <button> inside `<.focus_wrap>` so focus order lands on the close glyph first; aria-label is mandatory since the button has no visible text."
    - "Plain × (U+00D7 MULTIPLICATION SIGN) glyph as the close icon — no SVG, no icon library, matches the calm-no-decoration brand register and adds zero asset weight."
    - "Failed-bubble subhead conditional keyed off `outbound_status_label(msg) == \"Failed\"` (the string-returning private function), not the raw `metadata[\"status\"]`, so the new render path travels through the same gate as the existing chip — single source of truth for the failure signal."
    - "ConversationLive embedded-stylesheet test gotcha: render/1 emits a <style> block at the top that contains CSS rules referencing the same class names used as render-attribute values (e.g., `.outbound-action-card`, `.message-status-chip`). Headless test assertions MUST pin the actual rendered class ATTRIBUTE string (e.g., `class=\"rail-card outbound-action-card\"`) rather than the bare class name — the bare name appears in the stylesheet regardless of which messages render. Documented as Deviation 2 below."

key-files:
  created: []
  modified:
    - lib/cairnloop/web/inbox_live.ex
    - test/cairnloop/web/inbox_live_test.exs
    - lib/cairnloop/web/conversation_live.ex
    - test/cairnloop/web/conversation_live_test.exs

key-decisions:
  - "D-08 empty-inbox copy adopted verbatim from RESEARCH Specific Ideas: 'No conversations yet.' — short, reason-forward, brand-aligned, no emoji, no exclamation marks (planner discretion within CONTEXT.md was exercised in research; executor confirmed the copy passes brand book §7.5 then shipped it)."
  - "D-08 close button placed as the FIRST child of the dialog div (not after the title) per RESEARCH Pitfall 6: <.focus_wrap> traps focus inside the dialog and the first focusable element receives focus on modal-open; placing the × first means Escape-equivalent dismissal is one key away from the moment the modal appears, matching screen-reader expectations for a close-first affordance."
  - "D-08 close button uses calm var(--cl-text-muted) — NOT var(--cl-danger). Per brand book §7.5 + CLAUDE.md operator-copy register, dismissal is a routine action, not a destructive one; red would signal danger/warning where none exists."
  - "D-09 subhead conditional travels through outbound_status_label(msg) == \"Failed\" — NOT a direct match on metadata[\"status\"] == \"failed\". The sealed private function is the single source of truth for the failure signal (chip render already uses it); routing the new subhead through the same gate keeps the two render paths in lockstep against any future status-label refactor."
  - "D-10 (brand-token CSS extraction) explicitly NOT addressed this phase. The inline var(--cl-<token>, <hex>) fallback pattern in inbox_live.ex is the headless-test contract — extracting to a class would break the asserts on inline `var(--cl-text-muted` strings in rendered HTML (Tests 1 + 2 + 6 of D-08 polish all gate on the inline token strings). Deferred per CONTEXT.md D-10 / RESEARCH 'Deferred Ideas' / threat register T-26-15."
  - "ConversationLive test assertions intentionally pin the rendered class ATTRIBUTE string rather than the bare class name (e.g., `class=\"rail-card outbound-action-card\"`, not `\"outbound-action-card\"`) because the embedded <style> block at the top of render/1 contains CSS rules for the same class names — bare matches would always pass regardless of which render branch fired. This is the new pattern for any future ConversationLive headless polish test."

patterns-established:
  - "Empty-state + modal-close-button additive polish pass on a LiveView with sealed event handlers — pure template patch, no new state, no new handlers, no new assigns. The Phase 25 cancel_bulk_confirm handler stays exactly as-shipped; the × button is a discoverability affordance only."
  - "Reason-forward subhead as the third non-color signal on a stateful chip (brand §7.5 belt-and-suspenders): existing class + chip text + new short prose sentence; failure state now has three independent signals so a color-blind operator, a screen-reader user, AND a glance-style operator all read 'failed' from at least one signal."
  - "Pinning a sealed sub-component's a11y contract via a verification-only render test — Test 5 (outbound_recovery_card aria-label) asserts the existing Phase 24 attribute is present in the rendered HTML so future refactors cannot silently drift it. The test is a regression gate, not new work."

requirements-completed: []  # No REQUIREMENTS.md row maps to D-08/D-09 polish — these are roadmap success-criterion #3 deliverables, not numbered requirements.

# Metrics
duration: 25min
completed: 2026-05-27
---

# Phase 26 Plan 03: Final UI Polish (D-08 InboxLive + D-09 ConversationLive)

**Pure template-patch polish pass on `InboxLive` and `ConversationLive` — closes the Phase 26 roadmap success criterion 3 ("tightens empty/error states and outbound affordance polish") by adding (a) the calm "No conversations yet." empty-state paragraph under `<h1>Inbox</h1>`, (b) the top-right × close button affordance inside the bulk-confirm dialog (aria-label="Close", 44px tap target, muted-color glyph anchored by `position: relative` on the dialog, placed as the FIRST child of the dialog so `<.focus_wrap>` lands focus there on modal-open per Pitfall 6), and (c) the calm reason-forward subhead "Delivery did not complete. Try again from the Outbound recovery card." below the failed-delivery chip on `:system_outbound` messages with `metadata["status"] == "failed"` — additive only, sealed chip + `outbound_recovery_card/1` + `outbound_status_label/1` byte-for-byte unchanged per Pitfall 7. D-10 (brand-token CSS extraction) explicitly deferred — the inline `var(--cl-<token>, <hex>)` strings are the headless-test contract.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-27T05:44Z (approximate; ratified at first commit)
- **Completed:** 2026-05-27T05:53Z
- **Tasks:** 2 (both TDD — RED → GREEN cycles, no REFACTOR)
- **Files modified:** 4 (0 created, 4 modified)
- **Total source lines added:** ~190 (12 inbox_live.ex template, 9 conversation_live.ex template, 167 inbox_live_test.exs + 151 conversation_live_test.exs test blocks)

## Accomplishments

- **InboxLive empty-state branch landed (D-08 sub-bullet 1)** — when `@conversations == []`, a calm `<p class="inbox-empty-state">No conversations yet.</p>` renders under `<h1>Inbox</h1>` with `var(--cl-text-muted, rgba(47, 36, 29, 0.62))` color, 14px font, no toolbar, no bulk header, no emoji, no exclamation marks. Mutually-exclusive sibling to the existing `<%= if has_visible_eligible?(@conversations) do %>` branch; both branches stay independent (Test 8 pins the resolved-cohort behavior; Test 1 pins the empty-cohort behavior).
- **InboxLive modal × close button landed (D-08 sub-bullet 3)** — top-right `<button aria-label="Close" phx-click="cancel_bulk_confirm">×</button>` (U+00D7 MULTIPLICATION SIGN, plain glyph, no SVG, no icon library) inserted as the FIRST child of the `<div class="bulk-confirm-dialog">`. Inline style enforces `min-width: 44px; min-height: 44px; position: absolute; top: 12px; right: 12px;` with calm `var(--cl-text-muted)` color (not red — dismissal is routine, not destructive). The dialog `style=` was mutated to PREPEND `position: relative;` so the absolute-positioned close button anchors to the dialog box rather than the page (Pitfall 6). Escape-key dismissal already works via `phx-window-keydown="cancel_bulk_confirm"`; the × is a visible discoverability affordance.
- **has_visible_eligible regression preserved (D-08 sub-bullet 2)** — Test 7 explicitly pins the Phase 25 D-14 gate: a non-resolved cohort renders neither the bulk header nor the empty-state paragraph. Test 8 confirms the resolved-cohort branch still renders the bulk header (the gate isn't broken by the new empty-state branch).
- **Refusal banner copy review complete (D-08 sub-bullet 4)** — Test 6 pins the existing banner copy ("Batch too large." + "Narrow your selection and try again.") with the existing `var(--cl-danger)` token + inline SVG icon combination. Brand book §7.5 satisfied: three independent signals (icon + text + color), never color-alone. Verification-only — the existing copy was already correct; this is a regression gate, not new work.
- **ConversationLive failed-bubble subhead landed (D-09 sub-bullet 2)** — `<p class="outbound-failed-subhead">Delivery did not complete. Try again from the Outbound recovery card.</p>` inserted AFTER `<p class="message-content">` and BEFORE the closing `</div>` of the `.message-card` div. Conditional gate: `outbound_status_label(msg) == "Failed"` (the existing sealed private function returns the chip text — single source of truth for the failure signal). Subhead is `var(--cl-text-muted)` calm muted-text; subhead is absent on `:sent` / `:pending` / non-`:system_outbound` roles (Tests 2 + 3 + 4 pin this).
- **outbound_recovery_card a11y verification gate added (D-09 sub-bullet 1)** — Test 5 pins the existing `<section aria-label="Outbound recovery" class="rail-card outbound-action-card">` on `:resolved` conversations; Test 6 pins that the section does NOT render on non-`:resolved` conversations (Phase 24 sealed behavior). Both are verification-only — the Phase 24 substrate is unchanged.
- **Three non-color signals on the failed bubble (brand §7.5 belt-and-suspenders):**
  1. `message-status-chip status-failed` CSS class (existing)
  2. "Failed" chip text (existing)
  3. Calm reason-forward subhead (NEW, this plan)
  A color-blind operator, a screen-reader user, AND a glance-style operator each read "failed" from at least one of the three signals.
- **No sealed surface mutated.** Source greps confirm:
  - `outbound_status_label/1` (lines 993-1003) — `"failed" -> "Failed"` body byte-for-byte unchanged
  - `outbound_status_class/1` (lines 1005-1014) — unchanged
  - `outbound_recovery_card/1` (lines 825-847) — `aria-label="Outbound recovery"` count = 1, unchanged
  - `has_visible_eligible?/1`, `visible_eligible_ids/1`, `all_visible_selected?/2` — all unchanged
  - `cancel_bulk_confirm` handler — unchanged (the new × button reuses it; no new handler added)
- **D-10 (brand-token CSS extraction) explicitly NOT addressed.** The inline `var(--cl-<token>, <hex>)` fallback pattern in `inbox_live.ex` is the headless-test contract — Tests 1, 2, 6 all assert on the inline token strings in rendered HTML. Extracting to a class would break the test contract. Deferred per CONTEXT.md D-10 / RESEARCH "Deferred Ideas" / threat register T-26-15.

## Task Commits

Each task followed TDD (RED → GREEN):

1. **Task 1: InboxLive D-08 polish (empty-state + modal × + regression gates)**
   - RED  `8b24d9c` test(26-03): 8 new tests in `describe "Phase 26 D-08 polish"` block. Tests 1-5 fail (need implementation); Tests 6-8 pass against the existing Phase 25 substrate (regression gates).
   - GREEN `13e9602` feat(26-03): inserts the empty-state `<p>` branch under `<h1>Inbox</h1>`, prepends `position: relative;` to the dialog inline style, and inserts the × close `<button>` as the FIRST child of the dialog div (35/35 tests pass).

2. **Task 2: ConversationLive D-09 failed-bubble subhead + a11y verification**
   - RED  `fd2a8c1` test(26-03): 7 new tests in `describe "Phase 26 D-09 failed-bubble subhead"` block. Tests 1 + 7 fail (need implementation); Tests 2-6 pass against the existing Phase 22/23/24 substrate (regression + verification gates).
   - GREEN `a9f3cd5` feat(26-03): inserts the subhead `<p class="outbound-failed-subhead">` below the message-content paragraph inside the message-card render, gated on `outbound_status_label(msg) == "Failed"` (68/68 tests pass).

**Plan metadata commit:** This SUMMARY commit (next).

## Files Created/Modified

- **`lib/cairnloop/web/inbox_live.ex`** (MODIFIED, +12 lines) — empty-state branch under `<h1>Inbox</h1>`; `position: relative;` prepended to the dialog inline style; `<button aria-label="Close" phx-click="cancel_bulk_confirm">×</button>` inserted as the first child of `<div class="bulk-confirm-dialog">`. Zero new event handlers, zero new assigns, zero new helper functions.
- **`test/cairnloop/web/inbox_live_test.exs`** (MODIFIED, +167 lines) — new `describe "Phase 26 D-08 polish"` block with 8 tests covering empty-state render + close-button render + handler-reuse count + position-relative anchor + first-child ordering + refusal-banner copy review + has_visible_eligible regression + resolved-cohort non-empty branch. Reuses the existing `render_html/1` + `build_assigns/1` helpers at lines 614-642.
- **`lib/cairnloop/web/conversation_live.ex`** (MODIFIED, +9 lines) — `<p class="outbound-failed-subhead">` inserted between `<p class="message-content">` and the closing `</div>` of the `.message-card` div; conditional gate `outbound_status_label(msg) == "Failed"`. Zero new event handlers, zero new assigns, zero new helper functions. `outbound_status_label/1`, `outbound_status_class/1`, `outbound_recovery_card/1` all byte-for-byte unchanged.
- **`test/cairnloop/web/conversation_live_test.exs`** (MODIFIED, +151 lines) — new `describe "Phase 26 D-09 failed-bubble subhead"` block with 7 tests covering subhead render on :failed + non-render on :sent/:pending/non-system_outbound + outbound_recovery_card a11y verification + outbound_recovery_card hidden on non-:resolved + subhead-position ordering. Local `failed_bubble_assigns/1` helper closure over the canonical assigns shape; reuses the existing `render_html/1` helper at lines 1461-1463.

## Decisions Made

All decisions followed CONTEXT.md verbatim with one implementation-time refinement:

- **D-08 empty-inbox copy adopted verbatim** ("No conversations yet.") from RESEARCH Specific Ideas — short, reason-forward, brand-aligned, no emoji, no exclamation marks. Planner's discretion was exercised in research; executor confirmed and shipped.
- **D-08 close button placed as the FIRST child of the dialog** (not after the title) per RESEARCH Pitfall 6 — `<.focus_wrap>` traps focus inside the dialog and the first focusable element receives focus on modal-open, so placing × first means dismissal is one key away from the moment the modal appears.
- **D-08 close button uses calm `var(--cl-text-muted)` color** — NOT `var(--cl-danger)`. Dismissal is a routine action; red would signal danger/warning where none exists (brand §7.5 + CLAUDE.md operator-copy register).
- **D-09 subhead conditional routes through `outbound_status_label(msg) == "Failed"`** — NOT a direct `metadata["status"] == "failed"` match. The sealed private function is the single source of truth for the failure signal (the chip render already uses it); routing the subhead through the same gate keeps both render paths in lockstep.
- **D-10 brand-token CSS extraction NOT addressed** — explicitly deferred this phase per CONTEXT.md D-10 / RESEARCH "Deferred Ideas". The inline `var(--cl-<token>, <hex>)` fallback pattern is the headless-test contract; extraction would break the asserts on inline token strings in rendered HTML.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test 5 (close-button-first-child ordering) initially matched the substring `"bulk-confirm-title"` which appears earlier in the HTML than the close button because the dialog ROOT carries `aria-labelledby="bulk-confirm-title"`.**

- **Found during:** Task 1 GREEN — Test 5 reported `close button (offset 1180) must appear BEFORE the dialog title (offset 322)` after the implementation was already correct.
- **Issue:** The assertion compared `:binary.match(html, "bulk-confirm-title")` against `:binary.match(html, "aria-label=\"Close\"")`. The string `bulk-confirm-title` first appears at offset 322 inside the dialog ROOT div's `aria-labelledby="bulk-confirm-title"` attribute — NOT at the actual `<h2 id="bulk-confirm-title">` heading element (which is at a later offset, after the close button). The implementation was correct; the test logic was wrong.
- **Fix:** Narrowed the title-match needle from `"bulk-confirm-title"` to `"id=\"bulk-confirm-title\""` so the offset comparison reflects the actual heading element's document position.
- **Files modified:** `test/cairnloop/web/inbox_live_test.exs` (Test 5 only).
- **Verification:** All 35 inbox_live_test.exs tests pass.
- **Committed in:** `13e9602` (Task 1 GREEN commit) — the test-logic fix was applied alongside the implementation.

**2. [Rule 1 - Bug] Test 4 / Test 5 / Test 6 of D-09 subhead initially used bare-class-name assertions like `refute html =~ "message-status-chip"` and `refute html =~ "outbound-action-card"` which always failed because ConversationLive's `render/1` emits an inline `<style>` block at the top containing CSS rules for the same class names (`.message-status-chip`, `.outbound-action-card`).**

- **Found during:** Task 2 RED — Tests 4 + 6 failed at the substrate-regression layer (the existing render was already correct) because the bare class names appear in the embedded CSS regardless of which render branch fires.
- **Issue:** The test logic assumed `class-name` substring matching would map 1:1 to rendered elements. ConversationLive deliberately embeds a CSS block at the top of `render/1` (the `<style>` block at lines ~600-758 of the file). The CSS contains rules like `.outbound-action-card { background: ...; }` and `.message-status-chip { display: inline-flex; ... }` — these rules persist in the HTML output even when zero `<section class="outbound-action-card">` or `<span class="message-status-chip">` elements actually render.
- **Fix:** Narrowed all bare-name matches to the rendered class ATTRIBUTE string (e.g., `class="rail-card outbound-action-card"`, `class={["message-status-chip` — the latter only appears in the source heex). For Test 4 (`refute` on `message-status-chip` when role is `:user`), narrowed to `refute html =~ ~s(class="message-status-chip)` — the actual attribute is only emitted when a chip renders.
- **Files modified:** `test/cairnloop/web/conversation_live_test.exs` (Tests 4 + 5 + 6 of the D-09 block).
- **Verification:** All 68 conversation_live_test.exs tests pass.
- **Committed in:** `fd2a8c1` (Task 2 RED commit) — the test-logic fix was applied before the RED commit landed; the subsequent GREEN landed clean.

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs against the test logic's implicit assumptions about how Phoenix.LiveView's render output is structured). Neither deviation expanded scope or weakened any planned assertion. Both are documented patterns future test authors should reuse:

- Test 5 lesson: when asserting DOM document order via `:binary.match/2`, narrow the needle to the actual element marker (`id="..."`, `class="..."`) — substring matches can hit attribute references on parent elements.
- Test 4/5/6 lesson: ConversationLive embeds a CSS block in its `render/1` output. Test assertions on class names MUST pin the rendered attribute string (`class="..."`), not the bare class name.

## Issues Encountered

- **Pre-existing baseline failure** (`Cairnloop.Automation.DraftTest` M005 drift) remains the only `mix test` failure across the full headless suite (676/677 pass, 1 baseline failure, 39 excluded). Documented in CLAUDE.md MEMORY as NOT a Phase 26 regression.
- **STATE.md was modified mid-execution** (presumably by the orchestrator at agent spawn time). Per the executor's sequential-execution instructions, I did NOT touch STATE.md or ROADMAP.md; the orchestrator owns those post-wave writes.

## Self-Check

- [x] All 4 commits present in git log: `8b24d9c` (Task 1 RED), `13e9602` (Task 1 GREEN), `fd2a8c1` (Task 2 RED), `a9f3cd5` (Task 2 GREEN).
- [x] `mix compile --warnings-as-errors` exits 0 with zero new warnings.
- [x] `mix test test/cairnloop/web/inbox_live_test.exs` — 35/35 pass.
- [x] `mix test test/cairnloop/web/conversation_live_test.exs` — 68/68 pass.
- [x] Full headless `mix test` — 1 doctest, 676 tests, **1 failure** (the documented baseline `Cairnloop.Automation.DraftTest` M005 drift per CLAUDE.md MEMORY — NOT a Phase 26 regression).
- [x] Source assertions all match (Task 1):
  - `grep -c "inbox-empty-state" lib/cairnloop/web/inbox_live.ex` → `1`.
  - `grep -c "No conversations yet." lib/cairnloop/web/inbox_live.ex` → `1`.
  - `grep -c "Phase 26 D-08: empty inbox state" lib/cairnloop/web/inbox_live.ex` → `1`.
  - `grep -c 'aria-label="Close"' lib/cairnloop/web/inbox_live.ex` → `1`.
  - `grep -c "position: relative;" lib/cairnloop/web/inbox_live.ex` → `1` (the dialog div mutation).
  - `grep -c "min-width: 44px; min-height: 44px;" lib/cairnloop/web/inbox_live.ex` → `1`.
  - `grep -c 'phx-click="cancel_bulk_confirm"' lib/cairnloop/web/inbox_live.ex` → `3` (the new × button + the existing dialog Cancel + the existing refusal-banner Cancel — all reuse the sealed handler; ≥ 2 required, got 3).
  - `grep -c 'describe "Phase 26 D-08 polish"' test/cairnloop/web/inbox_live_test.exs` → `1`.
- [x] Source assertions all match (Task 2):
  - `grep -c "outbound-failed-subhead" lib/cairnloop/web/conversation_live.ex` → `1`.
  - `grep -c "Delivery did not complete. Try again from the Outbound recovery card." lib/cairnloop/web/conversation_live.ex` → `1`.
  - `grep -c "outbound_status_label(msg) == \"Failed\"" lib/cairnloop/web/conversation_live.ex` → `1`.
  - `grep -c "Phase 26 D-09" lib/cairnloop/web/conversation_live.ex` → `1`.
  - Sealed-surface check — `grep -c "message-status-chip" lib/cairnloop/web/conversation_live.ex` → `5` (≥ 1 required; the existing chip render + class enumeration + CSS rules remain).
  - Sealed-surface check — `grep -c 'aria-label="Outbound recovery"' lib/cairnloop/web/conversation_live.ex` → `1` (unchanged from Phase 24).
  - Sealed-surface check — `grep -c '"failed" -> "Failed"' lib/cairnloop/web/conversation_live.ex` → `1` (the `outbound_status_label/1` body byte-for-byte unchanged).
  - `grep -c 'describe "Phase 26 D-09 failed-bubble subhead"' test/cairnloop/web/conversation_live_test.exs` → `1`.
- [x] Brand book §7.5 honored: empty-state uses muted-text token (no shouting); close button uses muted-text (not red); failed bubble has three non-color signals (class + chip text + new subhead); all copy strings have no emoji and no exclamation marks.
- [x] Sealed surfaces byte-for-byte unchanged: `outbound_status_label/1`, `outbound_status_class/1`, `outbound_recovery_card/1`, `has_visible_eligible?/1`, `visible_eligible_ids/1`, `all_visible_selected?/2`, `cancel_bulk_confirm` handler.

## Self-Check: PASSED

## TDD Gate Compliance

This plan was executed under the TDD posture from the plan frontmatter (`tdd="true"` on both tasks). The git log shows the canonical sequence for each task:

| Task | RED commit | GREEN commit | Sequence |
|---|---|---|---|
| 1 | `8b24d9c test(26-03): add failing tests for InboxLive D-08 polish` | `13e9602 feat(26-03): InboxLive empty-state + modal × close button (D-08)` | RED → GREEN ✅ |
| 2 | `fd2a8c1 test(26-03): add failing tests for ConversationLive D-09 failed-bubble subhead` | `a9f3cd5 feat(26-03): ConversationLive failed-bubble subhead (D-09)` | RED → GREEN ✅ |

Each RED commit had genuine failing tests (Tests 1-5 in Task 1; Tests 1 + 7 in Task 2) plus regression-/verification-gate tests that already passed against the sealed Phase 22-25 substrate. The unexpectedly-passing-RED-test halt protocol was NOT triggered because the genuinely-new behavior tests DID fail as expected; the gate tests pinning sealed surfaces are documented in `<behavior>` as expected-passing-from-start.

No REFACTOR commits were needed — each GREEN landed clean against `mix compile --warnings-as-errors`.

## Threat Flags

No new threat surface was introduced. All threat register dispositions (T-26-10 through T-26-15) were discharged or accepted per CONTEXT.md.

## User Setup Required

None — Phase 26 Plan 03 is a pure additive template polish pass. Zero new dependencies, zero new application env knobs, zero new infrastructure, zero new event handlers, zero new assigns. Existing host apps continue to work unchanged; the polish renders automatically on:

- Empty inbox views (the calm "No conversations yet." paragraph).
- The bulk-confirm modal (the × close button is visible top-right; Escape continues to work as before).
- `:system_outbound` messages with `metadata["status"] == "failed"` (the calm reason-forward subhead appears below the existing "Failed" chip).

## Manual-Only Verifications (handoff)

Captured here for the operator to spot-check on a Postgres-available host once the Phase 25 BLOCKING handoff gates clear (these are visual / interaction confirmations that headless `Phoenix.LiveViewTest` cannot exercise — the headless tests pin the HTML contract; these confirm the rendered HTML actually looks right in a browser):

1. **Empty-inbox visual verification:** Visit `/` with zero conversations in the database. Confirm the calm "No conversations yet." paragraph appears below the `<h1>Inbox</h1>` in muted-text color, no toolbar, no bulk header. Resize the window to mobile width — text remains legible and properly margined.
2. **Modal × close button tap target & focus order:** Open the bulk-confirm modal (select ≥1 resolved conversation, click "Send recovery follow-up to N"). Confirm:
   - The × button appears top-right with adequate spacing from the dialog edge.
   - On a touch device, the × button accepts a tap (44×44px minimum hit area).
   - On modal-open, keyboard focus lands on the × button (per `<.focus_wrap>` semantics).
   - Tab moves through the dialog content; Shift-Tab returns to the × button.
   - Clicking × closes the modal without sending; selection is preserved (operator can adjust their cohort and re-open).
3. **Failed-bubble subhead visual placement:** Render a conversation with a `:system_outbound` message where `metadata["status"] == "failed"`. Confirm the subhead appears directly below the message content, in muted-text color, alongside (not replacing) the existing "Failed" status chip. Subhead text exactly reads "Delivery did not complete. Try again from the Outbound recovery card."
4. **Refusal-banner state-by-color-alone check (brand §7.5):** Select > 25 resolved conversations and open the bulk modal. Confirm the refusal banner renders THREE independent signals: (a) calm danger-tint background, (b) inline SVG warning icon, (c) reason-forward text ("Batch too large." + "Narrow your selection and try again."). Disable browser color → the icon + text still communicate the refusal state.

## Next Phase Readiness

- **Wave 3 (this plan) — DONE.** Phase 26 closeout polish fully landed at the headless layer.
- **Phase 26 closeout:** All three waves are now functionally complete at the headless layer:
  - Wave 1 (Plan 01 — OBS-01 OI trace substrate) — DONE.
  - Wave 2 (Plan 02 — OBS-02 audit READ facade) — DONE.
  - Wave 3 (Plan 03 — final UI polish) — DONE (this plan).
- **Roadmap success criteria** for Phase 26 are now all satisfied at the headless layer:
  1. OBS-01 (telemetry parity for triggers + delivery, OpenInference) — Wave 1.
  2. OBS-02 (audit reads for bulk outbound) — Wave 2.
  3. "Tightens empty/error states and outbound affordance polish" — Wave 3 (this plan).
- **Remaining manual gates:** the Phase 25 BLOCKING handoffs (operator's `mix ecto.migrate` + in-browser verify on a Postgres host) and the Phase 26 Plan 02 REPO-UNAVAILABLE integration test all remain pending the operator's Postgres-host run. None of these gate Wave 3 — the polish ships at the headless layer and is ready for operator visual verification per the "Manual-Only Verifications" handoff above.
- **No blockers** for the next phase. Cairnloop's vM013 Support-Triggered Outbound Lifecycle milestone is functionally complete at the headless layer pending the documented operator-host manual gates.

---
*Phase: 26-observability-polish*
*Completed: 2026-05-27*
