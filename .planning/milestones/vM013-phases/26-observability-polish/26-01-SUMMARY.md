---
phase: 26-observability-polish
plan: 01
subsystem: observability
tags: [telemetry, openinference, oban, outbound, elixir, traces]

# Dependency graph
requires:
  - phase: 17-governed-actions
    provides: "Cairnloop.Governance.Telemetry.Traces — the canonical OI-conformant trace lane module (D17-01, D17-03, D17-05) copy-modified verbatim for the outbound namespace."
  - phase: 22-outbound-trigger
    provides: "Cairnloop.Outbound.trigger/2 sealed public signature + Cairnloop.Telemetry.span([:outbound, :triggered]) bounded-metrics block."
  - phase: 24-conversation-outbound-recovery
    provides: "OutboundWorker.perform/1 four-arm delivery case block (notifier :ok / {:ok, _} / error / no-notifier)."
  - phase: 25-bulk-selection-fan-out
    provides: "Outbound.bulk_trigger/2 + bulk_trigger_submit/6 + bulk_trigger_refused/6 (CR-02 three-arm refusal lane) + BulkEnvelope durable substrate + OutboundWorker D-11 unique-clause."
provides:
  - "Cairnloop.Outbound.Telemetry.Traces — OI-conformant trace lane module on the disjoint 4-segment namespace [:cairnloop, :outbound, :trace, <event>] with 7-atom @events whitelist, attribution-ref-only metadata, fail-closed guard clause, and TOOL/GUARDRAIL span-kind taxonomy."
  - "Delivery-side bounded-metrics events [:cairnloop, :outbound, :delivery, :sent | :failed] on all 4 arms of OutboundWorker.perform/1 with enum-only {outcome, reason} metadata."
  - "OI trace lane wired alongside (never replacing) sealed bounded-metrics spans in Outbound.trigger/2 (started/completed/failed + rescue→exception path), bulk_trigger_submit/6 (bulk_submitted inside span), and bulk_trigger_refused/6 (bulk_refused on all 3 arms with :effective_cap)."
  - "Cairnloop.Telemetry @moduledoc ## Outbound Events block documenting both bounded-metrics + OI trace vocabularies (D-04)."
affects:
  - phase 26 wave 2 (OBS-02 audit READ facade — same Governance facade pattern)
  - phase 26 wave 3 (UI polish — independent)
  - future host integrators (Scoria, Phoenix.Tracer, OpenTelemetry exporters can now attach to [:cairnloop, :outbound, :trace, *])
  - future operator dashboards (Prometheus / StatsD / Datadog can now scrape [:cairnloop, :outbound, :delivery, *] for sent/failed counts)

# Tech tracking
tech-stack:
  added: []  # No new dependencies — :telemetry already in mix.exs from Phase 17
  patterns:
    - "OI trace sibling module under <domain>.Telemetry.Traces (mirrors Phase 17 Cairnloop.Governance.Telemetry.Traces) — disjoint 4-segment namespace, attribution-refs-only metadata, fail-closed guard clause"
    - "Side-by-side bounded-metrics + OI trace emit pattern (Cairnloop.Telemetry.execute then Traces.emit) — additive, fire-and-forget, never replaces sealed bounded-metrics spans"
    - "OI rescue-path emission: try/rescue around sealed :telemetry.span/3 with Traces.emit(:trigger_failed, outcome: :exception) BEFORE reraise(e, __STACKTRACE__) so raises surface on the OI lane without being swallowed"
    - "MockRepo Process-dictionary failure-forcing hooks (:mock_repo_force_insert_unexpected_shape, :mock_repo_force_transaction_failure, :mock_repo_force_transaction_raise) for headless coverage of error and rescue arms"

key-files:
  created:
    - lib/cairnloop/outbound/telemetry/traces.ex
    - test/cairnloop/outbound/telemetry/traces_test.exs
  modified:
    - lib/cairnloop/workers/outbound_worker.ex
    - test/cairnloop/workers/outbound_worker_test.exs
    - lib/cairnloop/outbound.ex
    - test/cairnloop/outbound_test.exs
    - lib/cairnloop/telemetry.ex

key-decisions:
  - "Carried D-01 forward: bounded-metrics delivery metadata stays enum-only ({:outcome, :count, :reason}) — no conversation_id/template_id/actor/bulk_envelope_id ever leaks to attached Prometheus/StatsD/Datadog handlers."
  - "Adopted D-03 verbatim from Phase 17 D17-01/D17-03/D17-05: disjoint 4-segment namespace, 7-atom @events whitelist, attribution-refs-only metadata, fail-closed unknown-atom guard clause, direct :telemetry.execute/3 (bypasses Cairnloop.Telemetry centralizer)."
  - "Implemented RESEARCH OQ3: :effective_cap is included on :bulk_refused OI metadata only (not :bulk_submitted, not :delivery_*), so OI consumers can correlate refusals against cap-at-decision-time policy."
  - "Implemented RESEARCH OQ2: delivery-time OI events carry actor_id: nil (system-initiated — trigger-time actor lives on :trigger_started)."
  - "Rescue branch on Outbound.trigger/2 emits :trigger_failed with outcome: :exception then reraises (mirrors :telemetry.span/3 :exception semantics on the OI lane; never swallows the raise)."
  - "Extended Outbound.trigger/2's post-span case to handle BOTH the {:error, reason} 2-tuple shape AND Ecto.Multi's {:error, name, value, changes} 4-tuple shape — both surface as Traces.emit(:trigger_failed, outcome: :failed) on the OI lane (deviation from PLAN's expected source-grep count of 2; see Deviations)."

patterns-established:
  - "OI trace sibling module structure under Cairnloop.<Domain>.Telemetry.Traces — Phase 17 Governance + Phase 26 Outbound now both follow it; future domains can copy-modify either."
  - "Try/rescue-around-sealed-span pattern for OI lifecycle parity — let the sealed bounded-metrics span keep its :exception semantics while the OI lane mirrors them additively then reraises."
  - "MockRepo Process-dictionary failure-forcing hooks (per-test-cleaned in on_exit) — pattern reusable for any future test that needs to exercise arm-specific failure paths without a live DB."

requirements-completed: [OBS-01]

# Metrics
duration: 40min
completed: 2026-05-27
---

# Phase 26 Plan 01: OBS-01 Observability Substrate Summary

**OpenInference trace lane + delivery-side bounded metrics for the outbound domain, mirroring Phase 17 verbatim — new `Cairnloop.Outbound.Telemetry.Traces` module on the disjoint `[:cairnloop, :outbound, :trace, …]` 4-segment namespace, delivery telemetry on all four arms of `OutboundWorker.perform/1`, and OI emissions wired alongside (never replacing) the sealed `:telemetry.span/3` blocks in `Outbound.trigger/2`, `bulk_trigger_submit/6`, and `bulk_trigger_refused/6` (all three refusal arms).**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-05-27T08:49Z (approximate; ratified at first commit)
- **Completed:** 2026-05-27T09:29Z
- **Tasks:** 3 (all TDD — RED + GREEN cycles)
- **Files modified:** 5 (2 created, 3 modified) — plus 1 file (`lib/cairnloop/telemetry.ex`) moduledoc-only
- **Total source lines added:** ~470 (155 traces module, 297 traces test, ~75 outbound patches, ~140 test extensions, ~45 moduledoc)

## Accomplishments

- **`Cairnloop.Outbound.Telemetry.Traces` module created** — verbatim copy-modify of the Phase 17 `Cairnloop.Governance.Telemetry.Traces` pattern, swapped to the outbound 7-atom event whitelist (`:trigger_started`, `:trigger_completed`, `:trigger_failed`, `:bulk_submitted`, `:bulk_refused`, `:delivery_sent`, `:delivery_failed`) with TOOL span-kind for delivery (execution) events and GUARDRAIL for lifecycle/bulk events. Attribution-refs-only metadata (`:bulk_envelope_id`, `:conversation_id`, `:template_id`, `:actor_id`, `:outcome`; plus `:effective_cap` on `:bulk_refused` only). Fail-closed guard clause for unknown atoms. Calls `:telemetry.execute/3` directly, bypassing the bounded-metrics centralizer per D-03 / D17-01.
- **Delivery-side bounded-metrics events land on all FOUR arms** of `OutboundWorker.perform/1` (research Pitfall 1): arms A and B both fire `:sent`/`:notifier_ok`, arm C fires `:failed`/`:notifier_returned_error`, arm D fires `:sent`/`:no_notifier_configured`. Enum-only metadata per D-01.
- **OI trace lane fires alongside bounded-metrics** at the same call sites: `:delivery_sent`/`:delivery_failed` TOOL spans with conversation/template/bulk-envelope attribution refs (no actor at delivery time per RESEARCH OQ2). `:trigger_started` → sealed bounded-metrics span → `:trigger_completed` or `:trigger_failed` (covering BOTH the `{:error, reason}` 2-tuple AND `Ecto.Multi`'s `{:error, name, value, changes}` 4-tuple). Rescue path emits `:trigger_failed` with `outcome: :exception` then `reraise(e, __STACKTRACE__)` so raises surface on the OI lane without being swallowed.
- **Bulk OI lane covers all three refused arms** (research Pitfall 3): `{:ok, _envelope}`, `{:error, %Ecto.Changeset{}}`, and `other`. Each carries `:effective_cap` (cap-of-the-moment, per RESEARCH OQ3) so OI consumers can correlate refusals against policy changes.
- **`Cairnloop.Telemetry` `@moduledoc` documents BOTH vocabularies** in a new `## Outbound Events` block (D-04). Cross-references `Cairnloop.Outbound.Telemetry.Traces`.
- **No sealed surface mutated.** `Outbound.trigger/2` + `bulk_trigger/2` public signatures byte-for-byte unchanged; both `Cairnloop.Telemetry.span(...)` blocks unchanged; `OutboundWorker` `use Oban.Worker` unique-clause unchanged.

## Task Commits

Each task followed TDD (RED → GREEN):

1. **Task 1: Create `Cairnloop.Outbound.Telemetry.Traces` module + headless test**
   - RED  `9b2d501` test(26-01): 15 failing tests covering span-kind mapping, attribution refs, payload exclusion, fail-closed guard, namespace isolation, and `:effective_cap`-only-on-:bulk_refused
   - GREEN `e080ade` feat(26-01): 155-line module with @events whitelist, build_metadata/2 (conditional `:effective_cap` on `:bulk_refused`), span_kind_for/1, direct `:telemetry.execute/3` call, guard-clause no-op
2. **Task 2: Delivery telemetry + OI traces in `OutboundWorker.perform/1`**
   - RED  `f526e03` test(26-01): added `OkTupleNotifier` and 7 failing tests in `describe "delivery telemetry (Phase 26 OBS-01 D-02)"` covering all 4 arms + OI parity + bulk_envelope_id threading
   - GREEN `64bec8f` feat(26-01): `perform/1` head extended to bind `args`, four `emit_delivery/4` calls (one per arm), new private helper emitting both lanes side-by-side; arms A and B capture `update_message_status/2` result and return it after emit to preserve the Phase 22/23 `{:ok, _}` return-shape contract
3. **Task 3: OI traces in `Outbound.trigger/2` + bulk_trigger lanes + `Telemetry.@moduledoc`**
   - RED  `3558598` test(26-01): MockRepo regression hooks (`:mock_repo_force_insert_unexpected_shape`, `:mock_repo_force_transaction_failure`, `:mock_repo_force_transaction_raise`) + 8 failing tests in `describe "OI trace lane (Phase 26 D-03)"`
   - GREEN `b908f84` feat(26-01): try/rescue around sealed span in `trigger/2`; `Traces.emit(:bulk_submitted, …)` inside sealed `bulk_trigger_submit/6` span; `Traces.emit(:bulk_refused, …)` on all three arms of `bulk_trigger_refused/6`; `## Outbound Events` block added to `Cairnloop.Telemetry.@moduledoc`

**Plan metadata commit:** This SUMMARY commit (next).

## Files Created/Modified

- **`lib/cairnloop/outbound/telemetry/traces.ex`** (NEW, 155 lines) — Cairnloop.Outbound.Telemetry.Traces module mirroring Phase 17 verbatim
- **`test/cairnloop/outbound/telemetry/traces_test.exs`** (NEW, 297 lines) — 15 headless tests proving span-kind mapping, attribution refs, payload exclusion, fail-closed guard, namespace isolation, and `:effective_cap`-only-on-`:bulk_refused`
- **`lib/cairnloop/workers/outbound_worker.ex`** (MODIFIED) — added `alias Cairnloop.Outbound.Telemetry.Traces`; `perform/1` head extended to bind `args`; `emit_delivery/4` private helper; arm-by-arm side-by-side bounded-metrics + OI emit; arms A/B capture and return `update_message_status/2`'s `{:ok, _}` result
- **`test/cairnloop/workers/outbound_worker_test.exs`** (MODIFIED) — added `OkTupleNotifier`; new `describe "delivery telemetry (Phase 26 OBS-01 D-02)"` block with 7 tests covering all 4 arms + OI lane parity + bulk_envelope_id threading
- **`lib/cairnloop/outbound.ex`** (MODIFIED) — added `alias Cairnloop.Outbound.Telemetry.Traces`; try/rescue around sealed `Cairnloop.Telemetry.span/3` in `trigger/2` with `:trigger_started` / `:trigger_completed` / `:trigger_failed` (both 2-tuple and 4-tuple branches) / rescue-`:trigger_failed`-with-`outcome: :exception`-then-reraise; `:bulk_submitted` inside `bulk_trigger_submit/6`'s sealed span; `:bulk_refused` on all 3 arms of `bulk_trigger_refused/6` with `:effective_cap`
- **`test/cairnloop/outbound_test.exs`** (MODIFIED) — MockRepo regression hooks (`:mock_repo_force_insert_unexpected_shape`, `:mock_repo_force_transaction_failure`, `:mock_repo_force_transaction_raise`); new `describe "OI trace lane (Phase 26 D-03)"` block with 8 tests covering trigger started/completed/failed/exception + bulk submit + all 3 bulk_refused arms
- **`lib/cairnloop/telemetry.ex`** (MODIFIED, moduledoc-only) — appended `## Outbound Events` block documenting both bounded-metrics and OI trace vocabularies + cardinality note + cross-reference to `Cairnloop.Outbound.Telemetry.Traces`

## Decisions Made

All decisions followed the locked CONTEXT.md decisions verbatim with two implementation-time refinements:

- **Carried D-01 forward unchanged** (enum-only bounded-metrics labels).
- **Adopted D-03 verbatim** from Phase 17 D17-01/D17-03/D17-05.
- **D-04 moduledoc block** documents both vocabularies and the cardinality posture.
- **Implementation-time refinement 1 — RESEARCH OQ3 (cap on `:bulk_refused` only):** `:effective_cap` is conditionally added in `build_metadata/2` via a case clause on `event == :bulk_refused`. Tests Test-7 and Test-14 pin both the inclusion AND the exclusion contract.
- **Implementation-time refinement 2 — RESEARCH OQ2 (delivery `actor_id: nil`):** `emit_delivery/4` always passes `actor_id: nil` to the OI lane. Trigger-time actor lives on the `:trigger_started` / `:trigger_completed` / `:trigger_failed` events; delivery is system-initiated.
- **Implementation-time refinement 3 — rescue mirrors `:telemetry.span/3` `:exception` semantics:** the `try`/`rescue` around the sealed span emits `:trigger_failed` with `outcome: :exception` then `reraise(e, __STACKTRACE__)`. This is additive only (the bounded-metrics span still fires its own `:exception` event from inside the raise unwind), and never swallows the raise.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Extended `trigger/2` case to handle Ecto.Multi's 4-tuple `{:error, name, value, changes}` failure shape**

- **Found during:** Task 3 GREEN — first failing test was `trigger/2 transaction failure — :trigger_failed fires GUARDRAIL with outcome :failed`, which forced `repo().transaction/1` to return `{:error, :message, :synthetic_failure, %{}}` (the canonical Ecto.Multi failure shape). My initial implementation only branched on `{:ok, _}` and `{:error, _}` (the 2-tuple shape), causing a `CaseClauseError`.
- **Issue:** The plan's `<action>` block specified "branch on `span_result` to emit `Traces.emit(:trigger_completed, ...)` on `{:ok, _}` (with `outcome: :triggered`) or `Traces.emit(:trigger_failed, ...)` on `{:error, _}`". This implicitly assumed `Cairnloop.Telemetry.span/3` returns either `{:ok, _}` or `{:error, _}`. But the wrapped function returns `repo().transaction(multi)` which for Ecto.Multi can return EITHER `{:ok, results}` or `{:error, failed_op_name, failed_value, changes_so_far}` — a 4-tuple. The plan's source-grep assertion `grep -c "Traces.emit(:trigger_failed" lib/cairnloop/outbound.ex` returns `3` (not the predicted `2`) because the implementation needs three branches: 2-tuple `{:error, _}`, 4-tuple `{:error, _, _, _}`, AND the rescue clause.
- **Fix:** Added a second `{:error, _name, _value, _changes}` case-clause that fires the same `Traces.emit(:trigger_failed, outcome: :failed)`. Result is correct under both real Ecto.Multi shapes.
- **Files modified:** `lib/cairnloop/outbound.ex`
- **Verification:** All 26 outbound tests pass including the new trigger transaction-failure test. `mix compile --warnings-as-errors` clean.
- **Committed in:** `b908f84` (Task 3 GREEN commit) — the extra clause was added before the commit landed.

**2. [Rule 1 - Bug] Preserved arm A/B `{:ok, _}` return-shape contract by capturing `update_message_status/2`'s result**

- **Found during:** Task 2 GREEN first compile run.
- **Issue:** The existing Phase 22/23 tests at `test/cairnloop/workers/outbound_worker_test.exs:71` + `:127` assert `{:ok, _} = OutboundWorker.perform(...)` on the happy arms. My initial implementation called `emit_delivery/4` as the last statement of arms A and B, causing `perform/1` to return `:ok` (the return value of `Traces.emit/2`) instead of `{:ok, %Message{}}`.
- **Fix:** Captured `result = update_message_status(message, "sent")` in arms A and B, then `emit_delivery(...)`, then `result` as the arm's last expression. Arm D's original `:ok` return is preserved (it was always returning `:ok` explicitly).
- **Files modified:** `lib/cairnloop/workers/outbound_worker.ex`
- **Verification:** All 13 worker tests pass including the legacy `perform/1` regression assertions.
- **Committed in:** `64bec8f` (Task 2 GREEN commit) — the fix was applied before the commit landed.

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs against the plan's implicit assumptions).
**Impact on plan:** Both fixes preserve Phase 22/23/25 sealed-contract semantics and are required for correctness. Neither expands scope; they refine planner-assumed shapes to match the actual call surfaces.

## Issues Encountered

- **Logger.error output in test runs is expected.** The bulk_refused arms B and C (both `{:error, %Ecto.Changeset{}}` and `other`) emit a structured `Logger.error` diagnostic per Phase 25's CR-02 hardening. The new OI tests intentionally trip these paths, so the test output includes the diagnostic lines. This is unchanged behavior — not a new issue.
- **STATE.md was modified mid-execution** (presumably by the orchestrator at agent spawn time). Per the executor's parallel-execution instructions, I did NOT touch STATE.md or ROADMAP.md; the orchestrator owns those post-wave writes.

## Self-Check

- [x] Created files exist on disk: `lib/cairnloop/outbound/telemetry/traces.ex` and `test/cairnloop/outbound/telemetry/traces_test.exs`
- [x] All 6 commits present in git log (3 RED + 3 GREEN): `9b2d501`, `e080ade`, `f526e03`, `64bec8f`, `3558598`, `b908f84`
- [x] `mix compile --warnings-as-errors` exits 0 with zero warnings
- [x] `mix test test/cairnloop/outbound/telemetry/traces_test.exs` — 15/15 pass
- [x] `mix test test/cairnloop/workers/outbound_worker_test.exs` — 13/13 pass (1 excluded :integration)
- [x] `mix test test/cairnloop/outbound_test.exs` — 26/26 pass (1 excluded :integration)
- [x] `mix test` (full headless) — 648 tests, **1 failure** (the documented baseline `Cairnloop.Automation.DraftTest` M005 drift per CLAUDE.md MEMORY — NOT a Phase 26 regression)
- [x] Source assertions verified for Task 1, Task 2, Task 3 — all match (modulo the trigger_failed count of 3 vs predicted 2, documented under Deviations Rule 1)
- [x] Phase 25 D-11 unique-clause regression test still passes (untouched)
- [x] Sealed `Cairnloop.Telemetry.span([:outbound, :triggered], …)` and `Cairnloop.Telemetry.span([:outbound, :bulk, :triggered], …)` blocks both unchanged

## Self-Check: PASSED

## TDD Gate Compliance

This plan was executed under the TDD posture from the plan frontmatter (`tdd="true"` on every task). The git log shows the canonical sequence for each task:

| Task | RED commit | GREEN commit | Sequence |
|---|---|---|---|
| 1 | `9b2d501 test(26-01): add failing test for Cairnloop.Outbound.Telemetry.Traces` | `e080ade feat(26-01): implement Cairnloop.Outbound.Telemetry.Traces` | RED → GREEN ✅ |
| 2 | `f526e03 test(26-01): add failing tests for delivery telemetry` | `64bec8f feat(26-01): wire delivery telemetry + OI traces in OutboundWorker.perform/1` | RED → GREEN ✅ |
| 3 | `3558598 test(26-01): add failing tests for OI trace lane on Outbound.trigger/2 + bulk` | `b908f84 feat(26-01): wire OI traces in Outbound trigger/2 + bulk lanes + Telemetry moduledoc` | RED → GREEN ✅ |

No REFACTOR commits were needed — each GREEN landed clean against `mix compile --warnings-as-errors`.

## User Setup Required

None — Phase 26 Plan 01 is a pure additive observability substrate. Zero new dependencies, zero new application env knobs, zero new infrastructure. Existing hosts continue to work unchanged; hosts wanting to consume the new lanes simply attach `:telemetry` handlers to:

- `[:cairnloop, :outbound, :delivery, :sent | :failed]` — bounded-metrics delivery outcomes (Prometheus / StatsD / Datadog)
- `[:cairnloop, :outbound, :trace, :trigger_started | :trigger_completed | :trigger_failed | :bulk_submitted | :bulk_refused | :delivery_sent | :delivery_failed]` — OI-conformant trace spans (Scoria / Phoenix.Tracer / OpenTelemetry exporters)

## Next Phase Readiness

- **Wave 1 (this plan) — DONE.** OBS-01 substrate is fully landed at the headless layer.
- **Wave 2 (Plan 02 — OBS-02 audit READ facade)** can begin immediately. It is independent of this plan's substrate and uses the same `Cairnloop.Governance` narrow-facade + MockRepo dispatch-by-from-source patterns already established in Phase 25.
- **Wave 3 (Plan 03 — final UI polish)** is independent of both Wave 1 and Wave 2; it patches `InboxLive` (empty state + modal `×`) and `ConversationLive` (failed-bubble subhead) using pure template patches against `var(--cl-*)` brand tokens.
- **No blockers** for Wave 2 or Wave 3. The Phase 25 BLOCKING handoff gates (operator's `mix ecto.migrate` + in-browser verify on a Postgres host) are unrelated to this phase's headless work.

---
*Phase: 26-observability-polish*
*Completed: 2026-05-27*
