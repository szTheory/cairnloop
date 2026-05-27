---
phase: 25-bulk-selection-fan-out
plan: 03
subsystem: ui
tags: [phoenix-liveview, focus-wrap, mapset, sticky-bar, bulk-recovery, brand-tokens, inbox-cockpit]

# Dependency graph
requires:
  - phase: 25-bulk-selection-fan-out
    plan: 01
    provides: Cairnloop.Governance.preview_bulk_recovery_cohort/1 (modal sample + count + "+N more") and list_eligible_conversation_ids_for_bulk_recovery/1 (D-14 cohort eligibility narrow read)
  - phase: 25-bulk-selection-fan-out
    plan: 02
    provides: Cairnloop.Outbound.bulk_trigger/2 (D-13 envelope entry point; consumed by confirm_bulk_send) + max_batch_size/0 enforcement at envelope boundary (defense-in-depth alongside the LiveView cap)
  - phase: 24-individual-outbound-ui
    provides: outbound_module() and recovery_follow_up_template_id() indirection helper pattern (lib/cairnloop/web/conversation_live.ex:1739-1745); recovery template config knob (:outbound_recovery_template_id) reused as-is per D-06
provides:
  - InboxLive surface with explicit checkbox multi-select on :resolved rows (D-01/D-03)
  - @selected_ids :: MapSet.t/0 assign (LiveView-local, no persistence; D-04)
  - Sticky bottom-anchored bulk action bar with count + Clear selection + brand-token primary button (D-05 / research OQ4)
  - <.focus_wrap>-based confirmation modal rendering count + first-5 sample + +N more + snapshotted rendered body (D-07)
  - Cancel-preserves-selection guarantee (D-08 / Pitfall 6 regression test)
  - Calm refusal banner (icon + var(--cl-danger) + reason-forward copy; never color-alone) when MapSet.size > max_batch_size (D-10 / brand §7.5)
  - confirm_bulk_send handler that calls outbound_module().bulk_trigger/2 with the snapshotted body + actor=@host_user_id and fans out put_flash on {:ok}/{:error}
affects: [26-observability-polish]

# Tech tracking
tech-stack:
  added: []  # zero new packages — Phoenix.Component.focus_wrap auto-imported via `use Phoenix.LiveView` (phoenix_live_view ~> 1.0)
  patterns:
    - "Indirection helpers in LiveView (outbound_module / governance_module / recovery_follow_up_template_id / max_batch_size) mirror lib/cairnloop/web/conversation_live.ex:1739-1745 — lets tests substitute stubs via Application.put_env without dependency injection ceremony"
    - "Snapshot-at-decision-time on the LiveView: `render_bulk_body/1` is called inside open_bulk_confirm and persisted on @bulk_preview.rendered_body; confirm_bulk_send passes that exact string to bulk_trigger/2 — no template re-resolution between confirm and submit (T-25-03 mitigation)"
    - "Tristate select-all-visible via pure MapSet math against visible_eligible_ids/1 (no JS hook; D-04 keeps state in assigns)"
    - "Fail-closed flash copy that never leaks raw Elixir terms — distinct calm messages per failure mode (template-missing, batch-too-large, generic). Selection PRESERVED on every failure path so the operator can narrow + retry; selection RESET only on {:ok, _}"

key-files:
  created: []  # plan was strictly additive — no new files
  modified:
    - lib/cairnloop/web/inbox_live.ex
    - test/cairnloop/web/inbox_live_test.exs

key-decisions:
  - "Sticky bar markup uses inline styles (not a CSS class) so all brand-token references and the position: sticky / bottom: 0 invariants are self-contained in the LiveView file. Matches lib/cairnloop/web/search_modal_component.ex's existing inline-style vocabulary and avoids cross-file coupling for a single-surface affordance."
  - "Refusal SVG is INLINE (not <img>): two-element circle + exclamation glyph rendered with currentColor stroke so it inherits the var(--cl-danger) accent. Inline SVG is FOUC-free (research recommendation), tiny (no extra HTTP), and trivially a11y (aria-hidden=\"true\" since the heading carries the semantic meaning)."
  - "+N more renders as `+ 3 more` (space after + before the number). The Test 2 assertion in inbox_live_test.exs pinned this exact form."
  - "Body-rendering approach inside open_bulk_confirm is the trivial `\"Outbound message using template: \#{template_id}\"` — pure function of template_id, matching the default content string in lib/cairnloop/outbound.ex (build_trigger_multi/2 line 97). v1 has no per-recipient personalization per D-07, so the body operators confirm is byte-for-byte the body recipients receive."
  - "Used `use Phoenix.LiveView` alone (NOT `import Phoenix.Component, only: [focus_wrap: 1]`) — the `use` macro already imports Phoenix.Component; adding an explicit `only:` import shadows assign/2 and sigil_H/2 from the LiveView macro and breaks compilation."
  - "Tasks 1 and 2 GREEN landed in ONE commit (5f74610) rather than two. Rationale: both tasks share the same two files (lib + test); the test file was authored up front (RED commit 9e165e5) covering both tasks' behaviors; splitting GREEN into two commits would require partial-file commits that don't compile or pass tests independently. This mirrors the precedent set in Plan 25-02 Task 3 (SUMMARY note: \"the function arrived earlier than the test file because Task 2's build_trigger_multi/2 extraction inherently exposed it\")."

patterns-established:
  - "Bulk-recovery cockpit shape: per-row checkbox (eligibility-gated) + header select-all-visible + sticky bottom action bar + <.focus_wrap> confirmation modal + brand-token-aligned refusal banner. Reusable for any future bulk-action surface (BULK-04+ tag-driven cohorts when they land)."
  - "Selection state lifecycle for v1: open_bulk_confirm DOES NOT touch @selected_ids; cancel_bulk_confirm DOES NOT touch @selected_ids; {:ok, _} from bulk_trigger/2 IS the only path that resets it; every {:error, _} preserves it. This asymmetry is load-bearing and is pinned by Tests 4 / 7 / 8 / 9 of the test file."
  - "Test stubbing for LiveView surfaces that delegate to facade modules: in-test StubGovernance / StubOutbound modules (matches MockNotifier in test/cairnloop/workers/outbound_worker_test.exs) + Application.put_env substitution + Process-dictionary capture via send(test_pid, …)."

requirements-completed: [BULK-01, BULK-02, BULK-03, UI-03]

# Metrics
duration: 6min
completed: 2026-05-27
---

# Phase 25 Plan 03: InboxLive Bulk-Recovery Cockpit Summary

**InboxLive becomes a checkbox-driven multi-select cockpit: `@selected_ids :: MapSet.t/0`, a sticky bottom bulk-action bar with the brand-primary `Send recovery follow-up to N` button, a `<.focus_wrap>` confirmation modal that snapshots the rendered template body at confirm-open time, a calm fail-closed refusal banner (icon + danger token + reason-forward copy) for oversized cohorts, and a submit handler that calls `Cairnloop.Outbound.bulk_trigger/2` and surfaces per-outcome calm flash copy without ever leaking a raw Elixir term to the operator.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-05-27T07:15:02Z
- **Completed:** 2026-05-27T07:21:13Z
- **Tasks:** 2 of 3 complete (Tasks 1 + 2 executed and committed; Task 3 is a `checkpoint:human-verify` gated on a Postgres-available host — see "Task 3" section)
- **Files modified:** 2 (matches the plan's `files_modified` frontmatter exactly — no scope creep)

## Accomplishments

- **InboxLive selection cockpit** lands the operator-visible surface for Phase 25: per-row checkboxes (only on `:resolved` rows — D-01 LiveView second line of defense), header `Select all visible` tristate toggle (D-03), `@selected_ids :: MapSet.t/0` LiveView-local assign (D-04, no persistence, cleared on remount), and a sticky bottom-anchored bulk action bar (D-05 / research OQ4) that uses `var(--cl-primary, #A94F30)` and shows `N selected` + `Clear selection` + `Send recovery follow-up to N`.
- **Confirmation modal** (D-07) renders count, first-5 recipient sample (ordering owned by `Cairnloop.Governance.preview_bulk_recovery_cohort/1`), `+ N more` tail, and the SINGLE rendered template body — snapshotted at confirm-open time and passed verbatim to `bulk_trigger/2` (T-25-03 snapshot integrity). Modal uses `<.focus_wrap>` for a11y (UI-03) and `phx-window-keydown="cancel_bulk_confirm" phx-key="Escape"` for keyboard dismissal.
- **Cancel preserves selection** (D-08 / Pitfall 6) is a hard contract: closing the modal via Cancel or Esc clears only `@bulk_modal_open` + `@bulk_preview` + `@bulk_refusal`; `@selected_ids` is untouched so the operator can adjust and re-open. Success ({:ok, _}) is the ONLY path that resets selection.
- **Calm fail-closed refusal banner** (D-10 / brand §7.5) renders when `MapSet.size > max_batch_size()` — inline SVG (icon, not color-alone) + `var(--cl-danger, #B54C36)` accent + reason-forward copy `This batch exceeds the safe send limit of 25. Narrow your selection and try again.` — and the `Confirm send` button is `disabled`. `bulk_trigger/2` is NEVER called from the refusal path.
- **`confirm_bulk_send` end-to-end wiring** (D-13): guards on `recovery_follow_up_template_id() == nil` (mirrors `conversation_live.ex:207`), calls `outbound_module().bulk_trigger(ids, template_id:, rendered_body:, actor: @host_user_id)`, and surfaces distinct calm flash messages per outcome: success info flash + selection reset; `{:error, :batch_too_large}` calm fail-closed flash (no raw Elixir term) + selection preserved; generic `{:error, _}` mirrors `conversation_live.ex:225` copy + selection preserved.
- **22 headless tests** in `inbox_live_test.exs` (1 existing Phase 22 search-modal-scope test stays green + 21 new Phase 25 tests). Full headless suite: 610 tests, 1 pre-existing baseline failure (`Automation.DraftTest` / M005 drift — NOT a regression; per memory note `cairnloop-baseline-draft-test-failure`).

## Task Commits

Each task was committed atomically (the GREEN commit covers both Tasks 1 + 2 — see rationale in `key-decisions`):

1. **Task 1 + 2 RED — failing test suite** — `9e165e5` (test) — TDD RED for both tasks: 21 failing tests authored up front against undefined handlers (UndefinedFunctionError) so the GREEN bar is unambiguous.
2. **Tasks 1 + 2 GREEN — full LiveView surface** — `5f74610` (feat) — selection MapSet + sticky bar + modal + refusal banner + submit handler all land together; 22/22 tests in the file green; all acceptance grep gates pass; `mix compile --warnings-as-errors` clean.

**Plan metadata commit:** _to be assigned when SUMMARY commits_ (docs: complete plan).

## Files Modified

- **`lib/cairnloop/web/inbox_live.ex`** (modified, +279 lines, from 44 to 323 total) — moduledoc enumerates D-03 / D-04 / D-05 / D-06 / D-07 / D-08 / D-10 / D-13 / D-14 traceability. Module-private indirection helpers (`outbound_module/0`, `governance_module/0`, `recovery_follow_up_template_id/0`, `max_batch_size/0`) mirror `conversation_live.ex:1739-1745`. New `mount/3` assigns add `selected_ids: MapSet.new()` + `bulk_modal_open: false` + `bulk_preview: nil` + `bulk_refusal: nil`. New `handle_event/3` clauses: `"toggle_select"`, `"toggle_select_all_visible"`, `"clear_selection"` (Task 1 — selection state), plus `"open_bulk_confirm"`, `"cancel_bulk_confirm"`, `"confirm_bulk_send"` (Task 2 — modal + submit). New helpers: `visible_eligible_ids/1`, `has_visible_eligible?/1`, `all_visible_selected?/2`, `render_bulk_body/1`, private `do_confirm_bulk_send/1`. Existing `SearchModalComponent` mount stays intact. Render adds: select-all-visible header checkbox (when any visible eligible exists), per-row checkbox (only on `:resolved`), sticky bottom action bar (only when `MapSet.size > 0`), modal backdrop + `<.focus_wrap>` + refusal branch / preview branch.
- **`test/cairnloop/web/inbox_live_test.exs`** (modified, +507 lines, from 27 to ~530 total) — moved from `async: true` to `async: false` (the Task 2 setup mutates `Application.put_env`). Existing Phase 22 search-modal-scope test stays green (extended its assigns to include the new bulk-related fields). 21 new tests across multiple describes: `mount/3` (1), `handle_event toggle_select` (1), `checkbox visibility` (1), `handle_event toggle_select_all_visible` (2), `handle_event clear_selection` (1), `sticky bulk action bar` (4), `open_bulk_confirm` (9 — sample + +N more + refusal + cancel + focus_wrap + submit happy + flash success + fail-closed flash + template-missing), `D-14 invariants` (2 — negative greps). Inline `EmptyRepo` for the mount test (stubs `Chat.list_conversations/0`'s `repo().all/1`). Inline `StubGovernance` + `StubOutbound` for Task 2 (matches `MockNotifier` pattern from `test/cairnloop/workers/outbound_worker_test.exs`).

## Test / Function Counts (downstream-relied-on facts)

- **`Cairnloop.Web.InboxLive` gained 6 `handle_event/3` clauses** — `"toggle_select"`, `"toggle_select_all_visible"`, `"clear_selection"`, `"open_bulk_confirm"`, `"cancel_bulk_confirm"`, `"confirm_bulk_send"`.
- **`Cairnloop.Web.InboxLive` gained 7 private helpers** — `outbound_module/0`, `governance_module/0`, `recovery_follow_up_template_id/0`, `max_batch_size/0`, `visible_eligible_ids/1`, `has_visible_eligible?/1`, `all_visible_selected?/2`, `render_bulk_body/1`, `do_confirm_bulk_send/1`.
- **`Cairnloop.Web.InboxLiveTest` went from 1 test to 22 tests** — all 22 headless green. 0 integration tests (this plan is pure LiveView surface; the integration-layer validation is Task 3's human-verify checkpoint).

## Decisions Made

- **Tasks 1 + 2 GREEN combined into one commit** (5f74610). Rationale documented in `key-decisions` above and in the commit message body. The RED commit (9e165e5) already authored tests for both tasks, so the implementation file naturally lands together.
- **Test file moved to `async: false`** so the `setup` block in `open_bulk_confirm` describe can safely `Application.put_env(:cairnloop, :outbound_module, StubOutbound)` without race conditions across async test runners. Matches `OutboundTest` / `OutboundWorkerTest` posture (research Pitfall 7).
- **Confirmation modal uses inline-styled markup, not a LiveComponent.** The plan allowed either; an inline approach keeps all decision-ID traceability in one file (the moduledoc + the render function) and avoids a new module for a single-surface affordance. If Phase 26 OBS-02 ever needs a reusable bulk-confirm shape, it can be extracted then.
- **`Esc` is the modal dismissal key**, wired via `phx-window-keydown="cancel_bulk_confirm" phx-key="Escape"` on the backdrop. The Cancel button uses the same `phx-click="cancel_bulk_confirm"` handler so both paths share the load-bearing Pitfall-6 invariant (selection preservation).
- **The `Confirm send` button in the refusal branch is `disabled` (not absent).** Reason: keeping the same DOM shape across preview-vs-refusal lets future a11y testing tooling find the button consistently; `disabled` + `aria-disabled="true"` is the cleaner signal than removing the element entirely.
- **`render_bulk_body/1` returns `""` on a `nil` template_id** rather than crashing. This is defensive — `confirm_bulk_send` already guards on `nil` template id and never reaches the rendered body; the fallback is just belt-and-suspenders for any future code path that pre-renders.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Explicit `import Phoenix.Component, only: [focus_wrap: 1]` broke compilation**
- **Found during:** First compile pass after writing the LiveView.
- **Issue:** The explicit `import` shadowed `assign/2` and `sigil_H/2` that `use Phoenix.LiveView` had already brought in. `mix compile --warnings-as-errors` failed with `undefined function assign/2` and `undefined function sigil_H/2`.
- **Fix:** Removed the explicit import — `<.focus_wrap>` is already available via the `use Phoenix.LiveView` macro (which imports `Phoenix.Component`).
- **Files modified:** `lib/cairnloop/web/inbox_live.ex` (one-line removal).
- **Verification:** `mix compile --warnings-as-errors` exits 0; the focus_wrap markup renders (Test 5 asserts `"Phoenix.FocusWrap"` substring in HTML).
- **Commit:** `5f74610` (Tasks 1+2 GREEN).

**2. [Rule 3 - Blocking] `<%# %>` template comments emitted deprecation warnings under `--warnings-as-errors`**
- **Found during:** Compile pass after fix #1.
- **Issue:** Phoenix.LiveView 1.0 warns that `<%# ... %>` is deprecated in favor of `<%!-- ... --%>`. Under `--warnings-as-errors` (D-15 mandatory) this failed the build.
- **Fix:** Replaced the three deprecation-triggering comments with `<%!-- --%>` form.
- **Files modified:** `lib/cairnloop/web/inbox_live.ex` (3 one-line edits).
- **Verification:** `mix compile --warnings-as-errors` exits 0.
- **Commit:** `5f74610` (Tasks 1+2 GREEN).

**3. [Rule 1 - Bug] `<strong>3</strong> selected` text broken across HTML tags failed the literal substring test**
- **Found during:** Task 1 Test 7 first run.
- **Issue:** Rendered HTML was `<strong>3</strong> selected` so `html =~ "3 selected"` failed (the `<strong>` tag interrupted the literal substring).
- **Fix:** Flattened the sticky-bar count to `<span><%= MapSet.size(@selected_ids) %> selected</span>` (dropped the inner `<strong>`). Visual styling can be reapplied via the span's CSS if needed (currently the visual weight is carried by the primary button copy, which already includes the count).
- **Files modified:** `lib/cairnloop/web/inbox_live.ex` (one-line edit).
- **Verification:** Test 7 passes; the rendered HTML contains the literal `"3 selected"`.
- **Commit:** `5f74610` (Tasks 1+2 GREEN).

**4. [Rule 1 - Bug] Moduledoc contained the literal `Conversation |> where` string, tripping the D-14 negative grep**
- **Found during:** Task 1 Test "D-14 invariants — no `Conversation |> where`" first run.
- **Issue:** A docstring line that documented the D-14 grep gate accidentally contained the literal `Conversation |> where` substring inside backticks, so the negative grep assertion failed.
- **Fix:** Rephrased the docstring to "asserts the `Conversation`-where pattern is absent from this file" — preserves the documentation intent while satisfying the negative grep gate.
- **Files modified:** `lib/cairnloop/web/inbox_live.ex` (one-line docstring rephrase).
- **Verification:** `grep -c "Conversation |> where" lib/cairnloop/web/inbox_live.ex` returns 0; the D-14 invariant test passes.
- **Commit:** `5f74610` (Tasks 1+2 GREEN).

**5. [Rule 3 - Blocking] `mount/3` test crashed because `Chat.list_conversations/0` requires `Cairnloop.Repo`**
- **Found during:** Task 1 Test 1 (mount populates selected_ids) first run.
- **Issue:** Calling `InboxLive.mount/3` invokes `Chat.list_conversations/0` which calls `repo().all(query)`; with no Repo configured in the test env, `Ecto.Repo.Registry.lookup/1` raises. This is the REPO-UNAVAILABLE caveat (D-16).
- **Fix:** Added an in-file `EmptyRepo` stub that responds to `all/1` with `[]`, wrapped the `mount/3` call in `Application.put_env(:cairnloop, :repo, EmptyRepo)` + `try/after` cleanup that restores the prior value.
- **Files modified:** `test/cairnloop/web/inbox_live_test.exs` (one describe block).
- **Verification:** Test passes; no global state leak (the `after` block restores the prior `:repo` env value).
- **Commit:** `5f74610` (Tasks 1+2 GREEN).

---

**Total deviations:** 5 auto-fixed (3 Rule-3 blocking, 2 Rule-1 bug). All in-scope (each was a tight-feedback fix caused by this task's own changes).
**Impact on plan:** None on intent. None on scope (no new files; no new modules; no envelope or governance changes). The Rule-3 fixes were build/test plumbing required to make the planned acceptance criteria green; the Rule-1 fixes were precision corrections (substring matching, doc-vs-grep collision) that left the user-visible behavior intact.

## Issues Encountered

None during planned work. One environmental note:

- **Pre-existing baseline failure:** `Cairnloop.Automation.DraftTest "changeset/2 requires content, status, and conversation_id"` remains the sole failure in the full `mix test` suite (1 failure / 611 tests). It is NOT a Phase 25 regression — same baseline failure recorded in 25-01-SUMMARY and 25-02-SUMMARY (memory note: `cairnloop-baseline-draft-test-failure` / M005 drift).

## Task 3 — checkpoint:human-verify (REPO-UNAVAILABLE, awaiting Postgres-available host)

Task 3 of the plan is `<task type="checkpoint:human-verify" gate="blocking">` — operator verification of the end-to-end bulk-send flow on a Postgres-available host (browser interaction, focus trap, brand-token visual treatment, system_outbound timeline cards). The executor returns a structured checkpoint to the orchestrator rather than auto-resolving:

- The DB-touching integration assertions from Plans 01 + 02 (`BulkEnvelope` row persisted; Oban uniqueness rejecting duplicate enqueues; FK integrity) plus the in-browser visual + a11y checks (`<.focus_wrap>` tab cycling, Esc preserves selection, brand-token visual treatment of primary + danger accents, `system_outbound` card append on each affected timeline) all gate on `Cairnloop.Repo` being available. The current workspace is REPO-UNAVAILABLE per CLAUDE.md / D-16.

- The integration story has a known PREDECESSOR blocker: **Plan 25-01 Task 4** (`mix ecto.migrate` on a Postgres-available host to apply `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`) is STILL awaiting the operator from the prior wave. The Phase 25 integration suite cannot run until that migration lands.

- **Resume signal expected from the operator:** `"verified"` (after running the in-browser checks 4–7 + the oversized-refusal check 7–8 from the plan's `<how-to-verify>` block, AND running `mix test` + `mix test.integration` green on a Postgres host) — or `"failed: <summary>"` if any check fails so the planner can revise the failing plan cleanly.

Plans 01 + 02 + 03 are durable / committed; the headless-test posture is fully green; Task 3 is the integration-layer human-verify gate, not a code change.

## Plan-wide Verification

1. **`mix compile --warnings-as-errors`** → exit 0 (D-15 — mandatory). ✓
2. **`mix test test/cairnloop/web/inbox_live_test.exs`** → 22 tests, 0 failures. ✓
3. **`mix test`** (full headless suite) → 1 doctest + 610 tests, 1 failure (pre-existing `Automation.DraftTest` / M005 drift baseline — NOT a Phase 25 regression). ✓
4. **`git diff --stat 0f1c6c0..HEAD -- . ':!.planning'`** → exactly the 2 declared `files_modified` paths (`lib/cairnloop/web/inbox_live.ex`, `test/cairnloop/web/inbox_live_test.exs`). No scope creep. ✓
5. **Acceptance grep gates (Task 1 + Task 2):**
   - `selected_ids: MapSet.new()` count == 1 ✓
   - `def handle_event "toggle_select"` count == 1 ✓
   - `def handle_event "toggle_select_all_visible"` count == 1 ✓
   - `def handle_event "clear_selection"` count == 1 ✓
   - `def handle_event "open_bulk_confirm"` count == 1 ✓
   - `def handle_event "cancel_bulk_confirm"` count == 1 ✓
   - `def handle_event "confirm_bulk_send"` count == 1 ✓
   - `var(--cl-primary` count >= 1 (2) ✓
   - `var(--cl-danger` count >= 1 (3) ✓
   - `position: sticky` count >= 1 ✓
   - `bottom: 0` count >= 1 ✓
   - `aria-label="Bulk actions"` count == 1 ✓
   - `aria-modal="true"` count == 1 ✓
   - `<.focus_wrap` count >= 1 ✓
   - `<svg` count >= 1 ✓
   - `outbound_module().bulk_trigger(` count == 1 ✓
   - `governance_module().preview_bulk_recovery_cohort` count == 1 ✓
   - `Conversation |> where` count == 0 (D-14 negative gate) ✓
   - `inspect(` in non-comment lines == 0 (no raw-Elixir-term operator copy — T-25-06 mitigation) ✓
   - D-0[345789] / D-1[034] mentions >= 1 (decision-ID traceability in moduledoc) ✓

## Phase-wide Decision Coverage Cross-Check (D-01..D-16, D-A..D-D)

Per the plan's `<verification>` block, every decision must be traceable from at least one acceptance criterion or must-have across Plans 01..03:

| Decision | Covered by | Where |
|---|---|---|
| D-01 (resolved-only) | Plan 01 (Governance facade) + Plan 03 Task 1 (LiveView second-line of defense) | governance.ex:1021-1027; inbox_live.ex render checkbox guard |
| D-02 (visible cohort only) | Plan 01 (facade reads `candidate_ids` only) + Plan 03 Task 1 (`@selected_ids` always derived from `@conversations`) | governance.ex docstring; inbox_live.ex visible_eligible_ids/1 |
| D-03 (checkbox + select-all-visible) | Plan 03 Task 1 | inbox_live.ex checkbox markup + `toggle_select_all_visible` handler |
| D-04 (MapSet assign, no persistence) | Plan 03 Task 1 | inbox_live.ex mount/3 + moduledoc |
| D-05 / research OQ4 (sticky bottom bar) | Plan 03 Task 1 | inbox_live.ex sticky bar (position: sticky; bottom: 0) |
| D-06 (reuses configured recovery template) | Plan 03 Task 2 | inbox_live.ex `recovery_follow_up_template_id/0` (same env knob as Phase 24) |
| D-07 (modal: count + sample + +N more + body) | Plan 03 Task 2 | inbox_live.ex modal markup + open_bulk_confirm handler |
| D-08 (cancel preserves selection) | Plan 03 Task 2 | inbox_live.ex cancel_bulk_confirm + Test 4 regression |
| D-09 (max_batch_size cap) | Plan 02 (envelope guard) + Plan 03 Task 2 (LiveView refusal) | outbound.ex max_batch_size/0; inbox_live.ex open_bulk_confirm guard |
| D-10 (calm refusal + icon + token) | Plan 03 Task 2 | inbox_live.ex refusal banner (inline SVG + var(--cl-danger)) |
| D-11 (Oban unique:) | Plan 02 | outbound_worker.ex `unique: [period: :infinity, fields:, keys:]` |
| D-12 (trigger/2 sealed) | Plan 02 | outbound.ex (additive opt only; public signature unchanged) |
| D-13 (bulk_trigger envelope + snapshot) | Plan 02 + Plan 03 Task 2 | outbound.ex bulk_trigger/2; inbox_live.ex render_bulk_body/1 + confirm_bulk_send |
| D-14 (Governance facade for reads) | Plan 01 + Plan 03 | governance.ex new functions; inbox_live.ex negative grep gate (0) |
| D-15 (warnings-clean build) | Every plan / every task | `mix compile --warnings-as-errors` exits 0 |
| D-16 (REPO-UNAVAILABLE / headless) | Every plan + Task 3 human-verify gate | headless tests across all plans; Task 3 awaits Postgres host |
| D-A (system_outbound cards) | Plan 02 (sealed trigger/2 still produces them — one per recipient) | outbound.ex build_trigger_multi/2 |
| D-B (enum-only telemetry) | Plan 02 | outbound.ex bulk_trigger_submit/6 + bulk_trigger_refused/6 telemetry blocks |
| D-C (durable records, telemetry observability-only) | Plans 01 + 02 (BulkEnvelope is workflow truth; telemetry is enum-only labels) | bulk_envelope.ex; outbound.ex |
| D-D (brand tokens + icon + text + no raw Elixir) | Plan 03 Task 1 + Task 2 | inbox_live.ex brand-token greps + refusal SVG + flash-copy negative grep |

All 16 decisions plus D-A..D-D have at least one acceptance criterion or must-have backing them across Plans 01..03.

## Next Phase Readiness

- **Phase 25 is functionally complete at the headless layer.** Plans 01 + 02 + 03 are committed and tested; all D-01..D-16 + D-A..D-D decisions are covered. The remaining gates are:
  - **Plan 25-01 Task 4** (`mix ecto.migrate` on Postgres host) — still awaiting operator. This is the prerequisite for any DB-touching integration assertion.
  - **Plan 25-03 Task 3** (in-browser human-verify on Postgres host) — depends on Task 4 above. The plan's `<how-to-verify>` block enumerates the exact sequence.
- **Phase 26 (Observability & Polish)** can begin its OBS-01 / OBS-02 work against the substrate landed across Plans 01..03:
  - OBS-01 attaches to the telemetry events landed in Plan 02 (`[:cairnloop, :outbound, :bulk, :triggered, :start | :stop]` for submitted; `[:cairnloop, :outbound, :bulk, :triggered]` point-in-time for refusals — enum-only labels per D-B).
  - OBS-02 reads `cairnloop_outbound_bulk_envelopes` rows (both `:submitted` and `:refused_cap_exceeded` lanes) for bulk-action audit dashboards.

## Self-Check: PASSED

- Modified files have new content:
  - `lib/cairnloop/web/inbox_live.ex` → contains `selected_ids: MapSet.new()`, all six `def handle_event` clauses, `<.focus_wrap>`, `outbound_module().bulk_trigger(`, `governance_module().preview_bulk_recovery_cohort`, `var(--cl-primary`, `var(--cl-danger`, `position: sticky`, `bottom: 0`, `aria-label="Bulk actions"`, `aria-modal="true"`, `<svg`. Negative-grep: 0 matches for `Conversation |> where` and 0 matches for `inspect(` in non-comment lines.
  - `test/cairnloop/web/inbox_live_test.exs` → contains `describe "open_bulk_confirm` block with 9 tests, the existing Phase 22 search-modal test, in-file `EmptyRepo` + `StubGovernance` + `StubOutbound` stubs, and the two `D-14 invariants` regression assertions.
- Commits exist on `main`:
  - `9e165e5` → FOUND (Task 1+2 RED — test(25-03): add failing tests for InboxLive bulk selection + modal)
  - `5f74610` → FOUND (Tasks 1+2 GREEN — feat(25-03): wire InboxLive bulk-recovery cockpit end-to-end)

---

*Phase: 25-bulk-selection-fan-out*
*Plan: 03*
*Completed (Tasks 1 + 2): 2026-05-27 — Task 3 (in-browser human-verify on Postgres-available host) awaiting operator + prerequisite Plan 25-01 Task 4 (`mix ecto.migrate`)*
