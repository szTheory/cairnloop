---
phase: 26-observability-polish
plan: 02
subsystem: governance-facade
tags: [governance, facade, audit, bulk-envelope, narrow-facade, regression, elixir, ecto]

# Dependency graph
requires:
  - phase: 25-bulk-selection-fan-out
    provides: "Cairnloop.Outbound.BulkEnvelope durable audit row (D-13) with :submitted | :refused_cap_exceeded enum + cairnloop_outbound_bulk_envelopes table; sealed auditor.audit/4 call sites on Outbound.trigger/2 (line 95-98) and bulk_trigger_submit/6 (line 339-343)."
  - phase: 25-bulk-selection-fan-out
    provides: "Cairnloop.Governance narrow-facade pattern (D-14): list_eligible_conversation_ids_for_bulk_recovery/1 + preview_bulk_recovery_cohort/1 at lib/cairnloop/governance.ex:1021-1081 as the analog for any further outbound-domain reads."
  - phase: 26-observability-polish, plan 01
    provides: "Wave 1 OBS-01 OI trace substrate (already shipped); independent of Wave 2 but completes the OBS half of the phase so Wave 3 polish lands on a stable observability + audit-read substrate."
provides:
  - "Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1 — narrow audit READ facade returning BulkEnvelope rows ordered requested_at desc, default limit 50, hard cap 500 (raises ArgumentError above cap), optional :status filter (:submitted | :refused_cap_exceeded | :all)."
  - "Cairnloop.Governance.get_bulk_outbound_envelope/1 — single-row read by binary UUID; returns nil on miss (does NOT raise) per D-06 callers-branch-on-result contract."
  - "D-05 auditor-metadata-shape regression block in test/cairnloop/outbound_test.exs pinning EXACTLY [:conversation_id, :template_id] on :outbound_trigger and [:bulk_envelope_id, :count, :template_id] on :bulk_outbound_trigger via Enum.sort()-equality + negative refute Map.has_key? for PII-rich extras."
  - "MockRepo dispatch arm on cairnloop_outbound_bulk_envelopes (pure query-inspection — no Process.put(:filter, ...) parallel channel) + BulkEnvelope get/2 clause + extract_envelope_status_filter/1 + extract_limit/1 helpers reusable for any future BulkEnvelope facade test."
affects:
  - phase 26 wave 3 (final UI polish) — independent of this plan; carries the same narrow-facade posture for any future operator surface that consumes bulk history.
  - future host integrators / example-app admin LiveView (host apps that want to render bulk audit history MUST consume this facade — D-14).
  - threat register T-26-06 (DoS via unbounded read) — closed by @bulk_envelope_hard_cap 500 ArgumentError guard.
  - threat register T-26-07 (audit-metadata drift / information-disclosure) — closed by D-05 negative refute Map.has_key? assertions on PII-rich keys.
  - threat register T-26-08 (D-14 facade bypass) — closed by zero direct Cairnloop.Repo references in lib/cairnloop/governance.ex.

# Tech tracking
tech-stack:
  added: []  # No new dependencies — :telemetry / :ecto already in mix.exs.
  patterns:
    - "@<scope>_default_limit + @<scope>_hard_cap module-attribute constant pair guarding ArgumentError at the facade boundary BEFORE the query is built — defense-in-depth against unbounded reads from untrusted future callers."
    - "filter_<scope>_status/2 private helper with no-op clause for :all and parametrised where-clause for enum values — reusable shape for any future enum-filtered facade read."
    - "MockRepo query-inspection dispatch on cairnloop_outbound_bulk_envelopes from.source — mirrors the Phase 25 cairnloop_conversations arm verbatim; NO Process.put(:filter, ...) parallel channel (the existing cairnloop_conversations precedent reads filters off the %Ecto.Query{} struct, the new arm does the same)."
    - "Auditor-metadata-shape regression via local capture-into-mailbox MapShapeAuditor + Enum.sort()-equality on Map.keys + negative refute Map.has_key? — pins the EXACT key set so future PRs adding extra keys fail the regression."

key-files:
  created: []
  modified:
    - lib/cairnloop/governance.ex
    - test/cairnloop/governance_test.exs
    - test/cairnloop/outbound_test.exs

key-decisions:
  - "Adopted D-06 verbatim: hard cap @bulk_envelope_hard_cap = 500 (raise ArgumentError on overflow), default @bulk_envelope_default_limit = 50, optional :status filter :submitted | :refused_cap_exceeded | :all (default :all)."
  - "Adopted D-14 narrow-facade contract: both new reads go through repo().all/1 / repo().get/2; zero direct Cairnloop.Repo references in lib/cairnloop/governance.ex (source-grep verified). Docstring references to the forbidden direct-repo path are rephrased to 'the concrete repo module' so the grep-gate stays clean."
  - "MockRepo extension is pure query inspection — extract_envelope_status_filter/1 walks query.wheres |> Enum.flat_map(& &1.params) for the status atom; extract_limit/1 reads query.limit.params (with expr fallback). No Process.put(:bulk_envelopes_filter, ...) parallel-channel approach (which would couple the test to the implementation's internal arg-shape). Mirrors the cairnloop_conversations arm at lines 64-96 verbatim."
  - "BulkEnvelope PK is :binary_id (autogenerate: false) per Pitfall 4 — get_bulk_outbound_envelope/1 accepts a binary UUID string. Ecto.Repo.get/2 handles invalid-shape input via cast-to-nil; we do NOT add extra validation."
  - "D-05 regression uses a NEW MapShapeAuditor defmodule (send-into-mailbox capture pattern) — distinct from the existing Phase 22 TestAuditor block (positive integration probe at lines 202-216) which is byte-for-byte unchanged. The new auditor's purpose is the negative-refute + sorted-key-set equality contract, not value capture for direct-result inspection."
  - "Bulk-envelope regression test passes is_binary(metadata.bulk_envelope_id) rather than an exact UUID equality because the value is generated at runtime inside bulk_trigger_submit/6. Exact equality would force the test to spy on Ecto.UUID.generate/0 or wrap it — both fragile. Shape-only assertion preserves the contract while keeping the test deterministic."

patterns-established:
  - "Append-after-preview narrow-facade insertion point — Phase 25's list_eligible_conversation_ids_for_bulk_recovery/1 + preview_bulk_recovery_cohort/1 pair sits at the bottom of governance.ex (~line 1081); future outbound-domain reads cluster after it as the 'outbound-domain facade' block, keeping the file readable as a single coherent surface."
  - "Defense-in-depth ArgumentError guard at the facade boundary — the hard cap is enforced BEFORE the Ecto query is built so a malicious or buggy caller cannot trick the facade into a 100_000-row read by passing :limit 100_000. The guard pattern is `if limit > @hard_cap, do: raise ArgumentError, \"limit \#{limit} exceeds <scope> hard cap \#{cap}\"`."
  - "Auditor-shape regression block as a sibling to the existing positive integration probe — leaves the canonical Phase 22 test untouched and adds a narrow regression that pins the metadata key SET (not values). The sorted-Enum equality + negative refute Map.has_key? on PII-rich keys catches BOTH additions and drift in one expression each."

requirements-completed: [OBS-02]

# Metrics
duration: 25min
completed: 2026-05-27
---

# Phase 26 Plan 02: OBS-02 Audit READ Facade Summary

**Narrow `Cairnloop.Governance` audit READ facade for the Phase 25 `BulkEnvelope` substrate — two new functions (`list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`) appended after `preview_bulk_recovery_cohort/1`, both routed through `repo().all/1` / `repo().get/2` per D-14 (zero direct `Cairnloop.Repo` references), guarded by the `@bulk_envelope_hard_cap 500` `ArgumentError` rail (T-26-06 DoS mitigation), accepting an optional `:status` enum filter (`:submitted | :refused_cap_exceeded | :all`) — plus a D-05 regression block in `outbound_test.exs` that pins the EXACT auditor metadata key set on both `:outbound_trigger` and `:bulk_outbound_trigger` lanes via `Enum.sort()`-equality + negative `refute Map.has_key?` for PII-rich extras (T-26-07 mitigation).**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-27T05:30Z (approximate; ratified at first commit)
- **Completed:** 2026-05-27T05:40Z
- **Tasks:** 2 (Task 1 TDD RED→GREEN cycle for the facade; Task 2 single-commit regression-pin against existing substrate)
- **Files modified:** 3 (0 created, 3 modified)
- **Total source lines added:** ~463 (94 facade impl + 251 facade tests + 118 D-05 regression block)

## Accomplishments

- **`Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1` shipped** — narrow audit READ facade that returns `BulkEnvelope` rows ordered `requested_at desc`, defaulting to limit `50`, hard-capped at `500` (raises `ArgumentError` BEFORE building the query if a caller asks for more — defense-in-depth, T-26-06 DoS mitigation), accepting an optional `:status` filter (`:submitted | :refused_cap_exceeded | :all`, default `:all`). Goes through `repo().all/1` (D-14) via a `filter_envelope_status/2` private helper that uses a no-op for `:all` and `where(query, [e], e.status == ^status)` for the two enum values.
- **`Cairnloop.Governance.get_bulk_outbound_envelope/1` shipped** — one-line `repo().get(BulkEnvelope, id)` wrapper. Returns `nil` on miss (does NOT raise) per D-06 callers-branch-on-result contract; the `BulkEnvelope` PK is `:binary_id (autogenerate: false)` so callers pass the binary UUID string they supplied at `bulk_trigger/2` confirmation time.
- **D-05 auditor metadata regression complete** — 4 tests in a new `describe "auditor metadata shape regression (Phase 26 OBS-02 D-05)"` block at the bottom of `test/cairnloop/outbound_test.exs` PIN both lanes:
  - `:outbound_trigger` → exactly `[:conversation_id, :template_id]` (`Enum.sort()` equality + exact-map equality `%{conversation_id: 1, template_id: "test"}`).
  - `:bulk_outbound_trigger` → exactly `[:bulk_envelope_id, :count, :template_id]` (`Enum.sort()` equality + `is_binary(metadata.bulk_envelope_id)` for the runtime UUID + exact equality on `count` and `template_id`).
  - Negative `refute Map.has_key?` on PII-rich extras (`:actor`, `:rendered_body`, `:recipient_conversation_ids`, `:effective_cap`) — pins that future refactors can't drift the contract by leaking host-facing PII through the auditor callback.
- **MockRepo extended via pure query-inspection** — new `from.source: "cairnloop_outbound_bulk_envelopes"` arm in `test/cairnloop/governance_test.exs` reads everything off the `%Ecto.Query{}` struct: a new `extract_envelope_status_filter/1` walks `query.wheres |> Enum.flat_map(& &1.params)` to find the status atom (or returns `:all` if none); a new `extract_limit/1` reads `query.limit.params` (with `expr` fallback) to apply `Enum.take/2`. The new `get/2` clause matching `Cairnloop.Outbound.BulkEnvelope` returns `nil` on miss via `Enum.find/2`. NO `Process.put(:bulk_envelopes_filter, ...)` parallel channel — the existing `cairnloop_conversations` arm at lines 64-96 is the verbatim template.
- **REPO-UNAVAILABLE handoff captured** — added `@tag :integration` placeholder `describe "list_recent_bulk_outbound_envelopes/1 — Postgres integration"` block with `flunk("integration-only: requires Cairnloop.Repo + cairnloop_outbound_bulk_envelopes table")`; runs against a real Postgres host via `mix test.integration` (mirrors the Phase 25 BLOCKING-handoff pattern from `test/cairnloop/workers/outbound_worker_test.exs:139-154`).
- **No sealed surface mutated.** `Cairnloop.Outbound.trigger/2`, `bulk_trigger/2`, `bulk_trigger_submit/6`, `bulk_trigger_refused/6`, the existing `Governance.list_eligible_conversation_ids_for_bulk_recovery/1`, `Governance.preview_bulk_recovery_cohort/1`, and the existing Phase 22 `TestAuditor` block (lines 202-216 of `outbound_test.exs`) are all byte-for-byte unchanged.

## Task Commits

1. **Task 1 RED** — `b92192d test(26-02): add failing tests for BulkEnvelope audit READ facade`
   - Extended MockRepo with `cairnloop_outbound_bulk_envelopes` dispatch arm + `BulkEnvelope` `get/2` clause + `extract_envelope_status_filter/1` + `extract_limit/1` helpers.
   - 7 failing tests for `list_recent_bulk_outbound_envelopes/1` covering default-50 / custom-limit / hard-cap-501-raises-ArgumentError / :status :submitted / :status :refused_cap_exceeded / :status :all / `requested_at desc` ordering — all `UndefinedFunctionError` as expected.
   - 2 failing tests for `get_bulk_outbound_envelope/1` covering the happy-path hit + nil-on-miss contract.
   - `@tag :integration # REPO-UNAVAILABLE` placeholder for the Postgres-host round-trip.

2. **Task 1 GREEN** — `5a4f2f1 feat(26-02): implement BulkEnvelope audit READ facade in Governance`
   - Added `alias Cairnloop.Outbound.BulkEnvelope` to the alias block (after the Phase 25 `Cairnloop.Conversation` alias).
   - Added module attributes `@bulk_envelope_default_limit 50` + `@bulk_envelope_hard_cap 500` near the existing `approval_ttl_seconds/0` block.
   - Appended `list_recent_bulk_outbound_envelopes(opts \\ [])` + `get_bulk_outbound_envelope(id)` AFTER `preview_bulk_recovery_cohort/1` and BEFORE the existing `defp bulk_recovery_label_for/1` helpers. Both go through `repo().all/1` / `repo().get/2`.
   - Added `defp filter_envelope_status/2` private helper below the public functions (no-op for `:all`; `where(query, [e], e.status == ^status)` for the two enum values).
   - All 9 new tests pass; full `mix test test/cairnloop/governance_test.exs` is 75/75 (1 excluded `:integration`); `mix compile --warnings-as-errors` exits 0.

3. **Task 2 (regression-pin)** — `e0e3547 test(26-02): pin auditor metadata shape via D-05 regression block`
   - Single commit because the substrate already exists in `lib/cairnloop/outbound.ex` (lines 95-98 + 339-343); a separate RED step is meaningless for an existing-contract regression and would have failed the TDD halt-and-report's "unexpectedly-passing-RED-test" check.
   - Added 4 tests in a new `describe "auditor metadata shape regression (Phase 26 OBS-02 D-05)"` block at the bottom of `outbound_test.exs` (before the REPO-UNAVAILABLE integration block, after the OI trace lane block).
   - Added a local `MapShapeAuditor` defmodule (capture-into-mailbox via `send(self(), ...)` pattern; mirrors `MockNotifier.on_outbound_triggered/2`). The existing Phase 22 `TestAuditor` block (lines 202-216) is untouched.
   - All 4 new tests pass against the existing substrate. Full `mix test test/cairnloop/outbound_test.exs` runs 30/30 (1 excluded `:integration`).

**Plan metadata commit:** This SUMMARY commit (next).

## Files Created/Modified

- **`lib/cairnloop/governance.ex`** (MODIFIED, +94 lines) — added `alias Cairnloop.Outbound.BulkEnvelope`; added `@bulk_envelope_default_limit 50` + `@bulk_envelope_hard_cap 500` module attributes; appended `list_recent_bulk_outbound_envelopes(opts \\ [])` + `get_bulk_outbound_envelope(id)` public functions + private `filter_envelope_status/2` helper. Zero direct `Cairnloop.Repo` references (source-grep verified — D-14).
- **`test/cairnloop/governance_test.exs`** (MODIFIED, +251 lines) — extended `MockRepo` with `cairnloop_outbound_bulk_envelopes` `from.source` dispatch arm + `BulkEnvelope` `get/2` clause; added `extract_envelope_status_filter/1` + `extract_limit/1` private helpers (pure query inspection); extended `on_exit` cleanup to delete `:bulk_envelopes`; added `describe "list_recent_bulk_outbound_envelopes/1 (Phase 26 OBS-02 D-06)"` block with 7 tests; added `describe "get_bulk_outbound_envelope/1 (Phase 26 OBS-02 D-06)"` block with 2 tests; added `describe "list_recent_bulk_outbound_envelopes/1 — Postgres integration"` block with the `@tag :integration # REPO-UNAVAILABLE` placeholder.
- **`test/cairnloop/outbound_test.exs`** (MODIFIED, +118 lines) — added `describe "auditor metadata shape regression (Phase 26 OBS-02 D-05)"` block with a local `MapShapeAuditor` defmodule and 4 tests pinning the EXACT key set on both `:outbound_trigger` and `:bulk_outbound_trigger` lanes. Existing Phase 22 `TestAuditor` block byte-for-byte unchanged.

## Decisions Made

All decisions followed CONTEXT.md verbatim with two implementation-time refinements documented under "Deviations from Plan" below.

- **D-06 facade shape adopted verbatim:** default limit `50`, hard cap `500` enforced via `ArgumentError` BEFORE the query is built, optional `:status` filter with `:all` default, ordering `requested_at desc`. Both reads through `repo().all/1` / `repo().get/2` per D-14.
- **D-05 regression block scoped to key SETS, not values:** the negative `refute Map.has_key?` assertions are the primary drift-catcher; the positive `Enum.sort()` equality + exact-map equality assertions back it up. Tests assert the EXACT metadata equals `%{conversation_id: 1, template_id: "test"}` for the trigger lane (deterministic) but use `is_binary(metadata.bulk_envelope_id)` for the bulk lane (UUID is runtime-generated).
- **D-14 narrow-facade contract preserved:** the source-grep gate `grep -c "Cairnloop.Repo\\." lib/cairnloop/governance.ex` returns `0`. Docstring references to the forbidden direct path were rephrased to "the concrete repo module" so the grep-gate stays clean while the documentation remains explicit about the constraint.
- **`@tag :integration` REPO-UNAVAILABLE handoff present:** mirrors Phase 25's BLOCKING-handoff pattern; the placeholder test documents the operator-host check for the Postgres-backed round-trip and is excluded by default from headless runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Docstring referenced `Cairnloop.Repo.all/1` / `Cairnloop.Repo` as the "forbidden direct path"; the D-14 source-grep gate (`grep -c "Cairnloop.Repo\\."`) flagged this as `1` not `0`.**

- **Found during:** Task 1 GREEN — first source-assertion run.
- **Issue:** The plan's `<source_assertions>` block requires `grep -c "Cairnloop.Repo\\." lib/cairnloop/governance.ex == 0`. My initial implementation included a docstring that explicitly named `Cairnloop.Repo.all/1` as the path the facade does NOT use ("never `Cairnloop.Repo.all/1` directly"). The grep doesn't distinguish docstring from code — it's a hard 0-or-fail gate.
- **Fix:** Rephrased both docstring mentions to "the concrete repo module" — the constraint is still explicit, but the grep-gate stays clean. This preserves the threat-register T-26-08 mitigation (`Cairnloop.Repo` never referenced from `governance.ex`) without weakening the documentation.
- **Files modified:** `lib/cairnloop/governance.ex` (2 docstring edits in `list_recent_bulk_outbound_envelopes/1` and `get_bulk_outbound_envelope/1`).
- **Verification:** `grep -c "Cairnloop.Repo\\." lib/cairnloop/governance.ex` → `0`. `mix compile --warnings-as-errors` clean. Tests still pass.
- **Committed in:** `5a4f2f1` (Task 1 GREEN commit) — the rephrase was applied before the commit landed.

**2. [Rule 1 - Bug, prevention] Removed RED step for Task 2 (D-05 regression).**

- **Found during:** Task 2 planning — reading the TDD halt-and-report protocol.
- **Issue:** The plan declares `tdd="true"` on Task 2, but Task 2 is a regression test that PINS existing behavior (`auditor.audit(:outbound_trigger, …, %{conversation_id, template_id})` already exists in `outbound.ex:95-98` from Phase 22; `auditor.audit(:bulk_outbound_trigger, …, %{bulk_envelope_id, count, template_id})` already exists at line 339-343 from Phase 25). If I wrote the test and ran it expecting RED, it would PASS immediately — which the TDD halt-and-report protocol explicitly flags as a stop condition ("If a test passes unexpectedly during the RED phase, STOP. The feature may already exist…").
- **Fix:** Committed Task 2 as a single `test(...)` commit (regression-pin) rather than the RED→GREEN cycle. The commit message documents the rationale.
- **Files modified:** none beyond the new tests themselves.
- **Verification:** All 4 new tests pass against the existing substrate. Full `outbound_test.exs` 30/30 (1 excluded).
- **Committed in:** `e0e3547` (Task 2 single-commit).

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs against the plan's implicit assumptions; neither expanded scope).
**Impact on plan:** Both fixes preserve the locked decisions verbatim (D-06 facade contract; D-14 narrow-facade gate; D-05 regression coverage). Neither weakens the threat-register mitigations.

## Issues Encountered

- **Logger.error output in test runs is expected** for the existing `bulk_trigger_refused/6` arms B + C (changeset-failure and unexpected-shape lanes per Phase 25 CR-02 hardening). The Phase 26 plan 01 D-03 OI trace tests intentionally trip these paths; the new Phase 26 plan 02 tests do not, but the `outbound_test.exs` suite as a whole emits these diagnostics. Not a regression — pre-existing Phase 25 behavior.
- **`Cairnloop.Repo` unavailable in this workspace** per CLAUDE.md — all headless tests use `MockRepo`. The `@tag :integration` REPO-UNAVAILABLE placeholder is the operator-host handoff.
- **No checkpoints required** — the plan was fully autonomous and headless.

## Self-Check

- [x] All 3 commits present in git log: `b92192d` (Task 1 RED), `5a4f2f1` (Task 1 GREEN), `e0e3547` (Task 2 single-commit regression-pin).
- [x] `mix compile --warnings-as-errors` exits 0 with zero warnings.
- [x] `mix test test/cairnloop/governance_test.exs` — 75/75 pass (1 excluded `:integration`).
- [x] `mix test test/cairnloop/outbound_test.exs` — 30/30 pass (1 excluded `:integration`).
- [x] Full headless `mix test` — 661 tests, **1 failure** (the documented baseline `Cairnloop.Automation.DraftTest` M005 drift per CLAUDE.md MEMORY — NOT a Phase 26 regression).
- [x] Source assertions all match:
  - `grep -c "alias Cairnloop.Outbound.BulkEnvelope" lib/cairnloop/governance.ex` → `1`.
  - `grep -c "def list_recent_bulk_outbound_envelopes" lib/cairnloop/governance.ex` → `1`.
  - `grep -c "def get_bulk_outbound_envelope" lib/cairnloop/governance.ex` → `1`.
  - `grep -c "@bulk_envelope_default_limit 50" lib/cairnloop/governance.ex` → `1`.
  - `grep -c "@bulk_envelope_hard_cap 500" lib/cairnloop/governance.ex` → `1`.
  - `grep -c "Cairnloop.Repo\\." lib/cairnloop/governance.ex` → `0` (D-14 narrow-facade gate clean).
  - `grep -c "repo().all" lib/cairnloop/governance.ex` → `9` (≥ 3 expected; existing 8 + 1 new).
  - `grep -c "repo().get(BulkEnvelope" lib/cairnloop/governance.ex` → `1`.
  - `grep -c 'describe "list_recent_bulk_outbound_envelopes/1 (Phase 26 OBS-02 D-06)"' test/cairnloop/governance_test.exs` → `1`.
  - `grep -c 'describe "get_bulk_outbound_envelope/1 (Phase 26 OBS-02 D-06)"' test/cairnloop/governance_test.exs` → `1`.
  - `grep -c "cairnloop_outbound_bulk_envelopes" test/cairnloop/governance_test.exs` → `3` (≥ 1 expected).
  - `grep -c "# REPO-UNAVAILABLE" test/cairnloop/governance_test.exs` → `2` (≥ 1 expected).
  - `grep -c 'describe "auditor metadata shape regression (Phase 26 OBS-02 D-05)"' test/cairnloop/outbound_test.exs` → `1`.
  - `grep -c "defmodule MapShapeAuditor" test/cairnloop/outbound_test.exs` → `1`.
  - `grep -c 'Map.keys(metadata) |> Enum.sort() == \[:conversation_id, :template_id\]' test/cairnloop/outbound_test.exs` → `1`.
  - `grep -c 'Map.keys(metadata) |> Enum.sort() == \[:bulk_envelope_id, :count, :template_id\]' test/cairnloop/outbound_test.exs` → `1`.
  - `grep -c "refute Map.has_key?(metadata, :rendered_body)" test/cairnloop/outbound_test.exs` → `2` (≥ 2 expected — Tests 3 + 4 both refute).
- [x] Sealed surfaces unchanged: `Outbound.trigger/2`, `bulk_trigger/2`, `bulk_trigger_submit/6`, `bulk_trigger_refused/6`, `Governance.list_eligible_conversation_ids_for_bulk_recovery/1`, `Governance.preview_bulk_recovery_cohort/1`, the existing Phase 22 `TestAuditor` block at `outbound_test.exs:202-216`.

## Self-Check: PASSED

## TDD Gate Compliance

This plan was executed under the TDD posture from the plan frontmatter (`tdd="true"` on both tasks). The git log shows:

| Task | RED commit | GREEN commit | Sequence |
|---|---|---|---|
| 1 | `b92192d test(26-02): add failing tests for BulkEnvelope audit READ facade` | `5a4f2f1 feat(26-02): implement BulkEnvelope audit READ facade in Governance` | RED → GREEN ✅ |
| 2 | `e0e3547 test(26-02): pin auditor metadata shape via D-05 regression block` (single-commit regression-pin — see Deviation 2) | (substrate already exists in Phase 22/25) | regression-pin only |

Task 2 deliberately did NOT follow the RED→GREEN pattern because the substrate it pins (`auditor.audit/4` call sites in `outbound.ex:95-98` + `:339-343`) already exists from Phase 22/25. Writing a failing test first against an existing implementation would have tripped the TDD halt-and-report protocol's "unexpectedly-passing-RED-test" stop condition. The single-commit regression-pin is the correct shape for this contract-pinning intent, and is documented under Deviations Rule 1.

No REFACTOR commits were needed — each GREEN landed clean against `mix compile --warnings-as-errors`.

## User Setup Required

None — Phase 26 Plan 02 is a pure additive narrow-facade + regression-test landing. Zero new dependencies, zero new application env knobs, zero new infrastructure. Existing hosts continue to work unchanged; hosts wanting to consume the bulk audit history simply call:

- `Cairnloop.Governance.list_recent_bulk_outbound_envelopes(limit: 50, status: :all)` — recent BulkEnvelope rows ordered `requested_at desc`.
- `Cairnloop.Governance.get_bulk_outbound_envelope("uuid-string")` — single row by binary UUID; `nil` on miss.

The REPO-UNAVAILABLE integration placeholder is the same operator-host check pattern Phase 25 introduced; it will run when an operator executes `mix test.integration` on a Postgres-available host (no new setup beyond what Phase 25 plan 01 task 4 already requires).

## Next Phase Readiness

- **Wave 2 (this plan) — DONE.** OBS-02 audit READ facade fully landed at the headless layer.
- **Wave 3 (Plan 03 — final UI polish)** can begin immediately. It is independent of both Wave 1 and Wave 2; it patches `InboxLive` (empty state + modal `×`) and `ConversationLive` (failed-bubble subhead) using pure template patches against `var(--cl-*)` brand tokens.
- **No blockers** for Wave 3. The Phase 25 BLOCKING handoff gates (operator's `mix ecto.migrate` + in-browser verify on a Postgres host) and the Phase 26 Plan 02 REPO-UNAVAILABLE integration test all remain pending the operator's Postgres-host run; none gate Wave 3's pure-template polish work.
- **OBS-02 closeout:** OBS-02 is now functionally complete at the headless layer — both the audit-WRITE substrate (Phase 25 plan 01 + plan 02) and the audit-READ facade (this plan) are landed. The operator-host integration handoff in `26-02-SUMMARY.md` and the existing Phase 25 BLOCKING handoffs remain the only outstanding items before formal sign-off.

---
*Phase: 26-observability-polish*
*Completed: 2026-05-27*
