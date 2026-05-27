---
phase: 26-observability-polish
fixed_at: 2026-05-27T18:50:00Z
review_path: .planning/phases/26-observability-polish/26-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 26: Code Review Fix Report

**Fixed at:** 2026-05-27T18:50:00Z
**Source review:** `.planning/phases/26-observability-polish/26-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (WR-01 through WR-07; Info findings IN-01..IN-04 out of scope)
- Fixed: 7
- Skipped: 0

**Verification:**
- `mix compile --warnings-as-errors`: clean.
- `mix test`: 681 tests, 1 failure, 39 excluded. The single failure is the
  pre-existing baseline failure in `test/cairnloop/automation/draft_test.exs:9`
  (`Cairnloop.Automation.DraftTest changeset/2 requires content, status, and
  conversation_id` — the known M005 drift documented in
  `cairnloop-baseline-draft-test-failure` and CLAUDE.md). NOT a regression from
  these fixes.
- Focused re-runs of the 5 touched test files (outbound_test,
  outbound_worker_test, inbox_live_test, conversation_live_test,
  traces_test): 166 tests, 0 failures.
- Governance facade regression run (`test/cairnloop/governance_test.exs`): 75
  tests, 0 failures.

## Fixed Issues

### WR-01 + WR-02: `bulk_trigger_submit/6` emits OI `:bulk_submitted` trace and reports `outcome: :submitted` on `:stop` unconditionally

**Files modified:** `lib/cairnloop/outbound.ex`, `lib/cairnloop/outbound/telemetry/traces.ex`
**Commit:** `adb81e6`
**Applied fix:** Combined WR-01 and WR-02 in a single atomic commit since
they touch the same submit-lane code path and share a single root cause
(the lane never branched on `result`). Added `:bulk_failed` to
`Traces.@events` whitelist, then refactored the inside of the
`Cairnloop.Telemetry.span/3` callback so both the OI trace event and the
bounded-metrics `:stop` metadata outcome are derived from the actual
transaction result — `{:ok, _changes}` fires `:bulk_submitted` + `:submitted`,
any other shape fires `:bulk_failed` + `:failed`. The OI lane now matches
the symmetric `trigger/2` lane's posture (which always branched on result).

### WR-03: `trigger/2` bounded-metrics `:stop` reports `outcome: :triggered` regardless of transaction result

**Files modified:** `lib/cairnloop/outbound.ex`
**Commit:** `62e5d24`
**Applied fix:** Derived the `:stop` outcome from the transaction result
inside the existing `Cairnloop.Telemetry.span/3` callback. `{:ok, _}` keeps
`outcome: :triggered`; anything else (`{:error, _}` or the Ecto.Multi
4-tuple) reports `:failed`. The OI trace lane was already branching
correctly — this brings the bounded-metrics lane into agreement.
Metadata stays enum-only (D-B / Pitfall 5).

### WR-04: `OutboundWorker` reports `outcome: :sent` when no notifier is configured

**Files modified:** `lib/cairnloop/workers/outbound_worker.ex`, `test/cairnloop/workers/outbound_worker_test.exs`
**Commit:** `3778c9d`
**Applied fix:** Introduced a third `:no_op` outcome for the no-notifier
arm of `OutboundWorker.perform/1`. Extended `emit_delivery/4`'s outcome
guard to `[:sent, :failed, :no_op]`. On the OI trace lane the `:no_op`
case intentionally fires NO trace event — a TOOL span represents an actual
execution and no execution happened (this is the architecturally
correct OI semantics; per the WR-04 fix discussion, treating `:no_op`
as a third trace event would add an enum that doesn't map to any OI
span kind). Also took IN-04's cleanup opportunity along the way:
replaced the inline `if/3` trace-event mapping with an explicit `case`
so the `:no_op` no-trace branch is locally visible. Updated arm-D
test to assert the new `:no_op` outcome and added a regression test
pinning the no-trace-on-no-op invariant.

**Note on IN-04:** This commit's `case` refactor incidentally satisfies
IN-04 too (inline `if` → `case` for trace event mapping). IN-04 was out
of scope per `fix_scope: critical_warning`, but the cleanup was a
natural side-effect of the WR-04 fix and is not separately tracked.

### WR-05: D-14 narrow-facade test is trivially circumventable

**Files modified:** `test/cairnloop/web/inbox_live_test.exs`
**Commit:** `dca77a0`
**Applied fix:** Replaced the single-substring grep with three broader
structural gates and a shared `strip_comments/1` helper:
  1. `InboxLive` does not `import` / `require` `Ecto.Query`.
  2. `InboxLive` does not `alias Cairnloop.Conversation` or
     `Cairnloop.Outbound.BulkEnvelope`.
  3. `InboxLive` source contains no `|> where`, `from(`, or pipe into
     common `Ecto.Query` macros (`join`/`select`/`order_by`/`group_by`/
     `having`/`preload`/`distinct`/`limit`/`offset`).

Each `refute` carries its own failure message so a regression tells
the operator exactly which query-construction form leaked. Retained
the original `Conversation |> where` substring assertion as a
historical belt-and-suspenders gate. The existing `inspect(` test was
refactored to reuse the new comment-stripping helper.

### WR-06: `render_bulk_body/1` silently returns empty string for non-binary template_id

**Files modified:** `lib/cairnloop/web/inbox_live.ex`, `test/cairnloop/web/inbox_live_test.exs`
**Commit:** `7d628db`
**Applied fix:** Converted the `if count > cap do ... else ... end` block in
`handle_event("open_bulk_confirm", ...)` to a `cond` with a new
`not is_binary(template_id) ->` branch that fail-closes with the same
calm operator copy used in the existing nil-template branch
(`"Recovery follow-up template is not configured."`). The
`confirm_bulk_send` defense-in-depth `is_nil` check remains in place
(belt-and-suspenders for any future caller that bypasses
`open_bulk_confirm`). Updated Test 9's narrative comment to reflect the
new fail-closed-at-open behavior (selection preservation invariant
unchanged) and added Test 10 explicitly pinning the atom-template-id
case — the exact misconfiguration class WR-06 protects against.

### WR-07: `failed_bubble_assigns/1` fixture omits `quick_fix_card` and `governed_actions` required by render

**Files modified:** `test/cairnloop/web/conversation_live_test.exs`
**Commit:** `2c1e779`
**Applied fix:** Added `quick_fix_card: %{status: :idle}` and
`governed_actions: []` to the fixture map, matching the established
shape used by `quick_fix_socket/1` and `approval_socket/1` elsewhere in
the same file. All 7 tests in the `Phase 26 D-09 failed-bubble subhead`
describe block continue to pass; the fixture is no longer relying on
Phoenix's accidental lenience for unbound assigns.

## Skipped Issues

_None — all 7 in-scope warnings were fixed._

---

_Fixed: 2026-05-27T18:50:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
