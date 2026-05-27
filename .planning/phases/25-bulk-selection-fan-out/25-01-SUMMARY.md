---
phase: 25-bulk-selection-fan-out
plan: 01
subsystem: database
tags: [ecto, postgres, governance-facade, bulk-outbound, audit-envelope]

# Dependency graph
requires:
  - phase: 24-individual-outbound-ui
    provides: sealed Outbound.trigger/2 primitive and resolved-only recovery affordance the bulk lane will fan out over
  - phase: 14-operator-timeline
    provides: Cairnloop.Governance narrow-facade pattern (`repo()` indirection, D-30) that the new cohort reads extend
provides:
  - Cairnloop.Outbound.BulkEnvelope Ecto schema (D-13 audit envelope; snapshotted template + cohort)
  - cairnloop_outbound_bulk_envelopes migration (binary_id PK, status/refused_reason lanes, indexes on requested_at + template_id)
  - Governance.list_eligible_conversation_ids_for_bulk_recovery/1 (D-01 / D-02 / D-14 — narrow cohort-eligibility read)
  - Governance.preview_bulk_recovery_cohort/1 (D-07 — modal preview shape: %{eligible_ids, sample, more, total})
affects: [25-02-bulk-trigger, 25-03-inboxlive-selection, 26-observability-polish]

# Tech tracking
tech-stack:
  added: []  # zero new packages — research § "Package Legitimacy Audit" confirmed
  patterns:
    - "Durable audit envelope per bulk action (D-13, OBS-02-shaped) — refused attempts persist on same table with status: :refused_cap_exceeded"
    - "Narrow facade cohort reads — InboxLive (plan 03) is forbidden from running direct Conversation queries (D-14)"
    - "MockRepo Conversation-source clause: dispatch on query.from.source string, filter against Process.get(:conversations, []) — headless tests stay REPO-UNAVAILABLE safe (D-16)"

key-files:
  created:
    - lib/cairnloop/outbound/bulk_envelope.ex
    - priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs
    - test/cairnloop/outbound/bulk_envelope_test.exs
  modified:
    - lib/cairnloop/governance.ex
    - test/cairnloop/governance_test.exs

key-decisions:
  - "@primary_key {:id, :binary_id, autogenerate: false} on BulkEnvelope: callers must supply UUID at confirm time (easier to assert in tests + future correlation keys)"
  - "Status enum is binary {:submitted, :refused_cap_exceeded} in v1 — per-recipient delivery status lives on the existing Message rows, not on BulkEnvelope"
  - "Order of preview_bulk_recovery_cohort sample is updated_at desc (research Open Question 6 — most-recently-resolved is what the operator most likely had in mind)"
  - "label_for fallback is 'Conversation #<id>' (not 'No Subject', not raw Elixir terms — brand-aligned calm copy)"
  - "MockRepo Conversation-source dispatch reads candidate_ids out of query.wheres params and applies status==:resolved + order_by in Elixir (Option (b) from the plan — pure / total-function tests per D-16)"

patterns-established:
  - "Phase 25 cohort facade: list_eligible_conversation_ids_for_bulk_recovery/1 + preview_bulk_recovery_cohort/1 are the ONLY way the web layer reads cohort eligibility — plan 03 acceptance grep will assert grep -c 'Conversation |> where' lib/cairnloop/web/inbox_live.ex == 0"
  - "Schema/migration column-list correspondence: 11 columns in both (id, template_id, rendered_body, recipient_conversation_ids, count, requested_by, requested_at, status, refused_reason, inserted_at, updated_at)"

requirements-completed: [BULK-01, BULK-03]

# Metrics
duration: 6min
completed: 2026-05-27
---

# Phase 25 Plan 01: BulkEnvelope Substrate Summary

**Cairnloop.Outbound.BulkEnvelope schema + cairnloop_outbound_bulk_envelopes migration + two narrow Cairnloop.Governance cohort-eligibility reads (list_eligible_conversation_ids_for_bulk_recovery/1, preview_bulk_recovery_cohort/1) so InboxLive (plan 03) can show a fail-closed bulk-recovery confirmation modal without ever running a direct Ecto query from the web layer (D-14).**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-27T06:47:00Z
- **Completed:** 2026-05-27T06:53:28Z
- **Tasks:** 3 of 4 complete (Task 4 awaiting human action — see Task 4 section)
- **Files modified:** 5 (matches plan's `files_modified` exactly — no scope creep)

## Accomplishments

- Cairnloop.Outbound.BulkEnvelope schema (D-13) lands the audit envelope per bulk action with snapshotted template_id, rendered_body, recipient cohort, and a `:submitted | :refused_cap_exceeded` status lane (refused attempts persist so OBS-02 reads see both lanes from one table — mirrors `Governance.propose_blocked` posture).
- priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs creates the table with bigint-array recipient ids (matches conversations PK), indexes on `:requested_at` and `:template_id`, and a string status column defaulted to `"submitted"`.
- Cairnloop.Governance gained two PUBLIC cohort-eligibility reads, each routing through `repo().all/1` (D-30 narrow facade): `list_eligible_conversation_ids_for_bulk_recovery/1` (returns the resolved subset of a candidate id list, D-01) and `preview_bulk_recovery_cohort/1` (returns `%{eligible_ids, sample, more, total}` with updated_at-desc-ordered first-5 sample + "+N more" tail, D-07).
- 12 new tests total (7 schema + 5 governance cohort reads on top of 1 extra MockRepo conversation-source extension). All headless / REPO-UNAVAILABLE safe (D-16).

## Task Commits

Each task was committed atomically:

1. **Task 1: BulkEnvelope schema + headless changeset tests** — `5b49eaf` (feat) — TDD: RED test ran first (compile error on missing module), then GREEN with schema impl.
2. **Task 2: Migration for cairnloop_outbound_bulk_envelopes** — `83ea233` (feat)
3. **Task 3: Cohort-eligibility reads on Governance facade** — `edf0aae` (feat) — TDD: RED tests ran first (UndefinedFunctionError), then GREEN with `list_eligible_conversation_ids_for_bulk_recovery/1` + `preview_bulk_recovery_cohort/1` impl.

**Plan metadata:** _to be assigned when SUMMARY commits_ (docs: complete plan)

## Migration Filename (downstream FK reference)

Plan 02 (`Outbound.bulk_trigger/2`) will need to reference this for its FK / column shape:

- **Exact path:** `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`
- **Module name:** `Cairnloop.Repo.Migrations.AddOutboundBulkEnvelopes`
- **Table name:** `cairnloop_outbound_bulk_envelopes`
- **PK type:** `binary_id` (callers supply `Ecto.UUID.generate/0` at confirmation time)
- **Column list (confirmed identical between schema and migration — 11 columns):**
  `id`, `template_id`, `rendered_body`, `recipient_conversation_ids`, `count`, `requested_by`, `requested_at`, `status`, `refused_reason`, `inserted_at`, `updated_at`

## Files Created / Modified

- **`lib/cairnloop/outbound/bulk_envelope.ex` (created)** — Ecto schema, `changeset/2` with required-field + `count > 0` validation, status enum `[:submitted, :refused_cap_exceeded]`.
- **`priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs` (created)** — `create table(:cairnloop_outbound_bulk_envelopes, primary_key: false)` + two indexes. No FK from `recipient_conversation_ids` (research A6: array FKs are awkward, join is purely audit-time).
- **`lib/cairnloop/governance.ex` (modified)** — Added `alias Cairnloop.Conversation` and two public functions (`list_eligible_conversation_ids_for_bulk_recovery/1`, `preview_bulk_recovery_cohort/1`) with a private `bulk_recovery_label_for/1` helper. Docstrings cite D-01/D-02/D-07/D-14/D-30.
- **`test/cairnloop/outbound/bulk_envelope_test.exs` (created)** — 7 headless schema tests (valid attrs, per-required-field invalidation via iteration, `count > 0`, refusal lane, recipient-list typing positive + non-list + non-integer-element negatives).
- **`test/cairnloop/governance_test.exs` (modified)** — Added `alias Cairnloop.Conversation`, extended `MockRepo.all/1` with a `Conversation`-source clause that dispatches on `query.from.source == {"cairnloop_conversations", _}` and applies `id in candidate_ids` + `status == :resolved` + `order_by desc: updated_at` in Elixir against `Process.get(:conversations, [])`. Added 6 new tests across two new describes.

## Function / Test Counts (downstream-relied-on facts)

- **`Cairnloop.Governance` gained 2 public functions:** `list_eligible_conversation_ids_for_bulk_recovery/1`, `preview_bulk_recovery_cohort/1`.
- **`Cairnloop.Outbound.BulkEnvelope` test file has 7 tests.** (Plan declared "five behavior tests" — the executor split Test 5 into three concrete tests: positive list-of-integers, negative non-list, negative non-integer-elements — Nyquist coverage of the same Test 5 behavior.)
- **`Cairnloop.GovernanceTest` gained 6 new tests** in two describes: 3 for `list_eligible_conversation_ids_for_bulk_recovery/1` and 3 for `preview_bulk_recovery_cohort/1`. Total file went from 60 to 66 tests, all green.

## Decisions Made

- **Schema PK is `binary_id` not `:id` autoincrement (A2 from research).** Picked UUID for opaque correlation key (matches `mcp_tokens` and the pattern Plan 02 will need when threading `bulk_envelope_id` through `Outbound.trigger/2` opts).
- **`recipient_conversation_ids` as `{:array, :bigint}` not a join table (A6 from research).** Acceptable for v1 OBS-02 audit purpose; if future analytics want JOINs, that's a future-phase migration concern.
- **No FK from `recipient_conversation_ids` to `cairnloop_conversations`.** Array FKs are awkward; the join is purely audit-time, not a runtime read.
- **Test 5 in Task 1 was split into three concrete tests** (positive list-of-integers + negative non-list + negative non-integer-element) for clearer failure messages. This is a tighter realization of the plan's single Test 5 behavior, not a deviation.
- **MockRepo `Conversation`-source clause uses Option (b) from the plan** (Process-dictionary + Elixir-side filtering) — simpler and matches the project's pure / total-function preference under D-16.

## Deviations from Plan

None — plan executed exactly as written.

**Auto-fix tally:** Zero Rule 1/2/3 fixes were necessary. The plan's `<interfaces>` block and research § "Code Examples" were complete; the executor applied them verbatim with only the cosmetic Test 5 split noted above (which is a tighter realization, not a deviation).

**Total deviations:** 0 auto-fixed.
**Impact on plan:** None. No scope creep; all five `files_modified` paths from the plan frontmatter were the only files touched.

## Issues Encountered

None during planned work. One environmental note:

- The pre-existing `Cairnloop.Automation.DraftTest` baseline failure (memory: cairnloop-baseline-draft-test-failure — M005 drift) remains the sole failure in the full `mix test` suite (1 failure / 573 tests). It is NOT a regression introduced by this plan. Per CLAUDE.md it is unrelated `*.Repo` boot noise / pre-existing baseline.

## Task 4 (BLOCKING — awaiting human action)

Task 4 of the plan is `<task type="checkpoint:human-action" gate="blocking">` — running `mix ecto.migrate` on a Postgres-available host to apply the new migration. Per CLAUDE.md the workspace is REPO-UNAVAILABLE (D-16); the executor cannot run `mix ecto.migrate` here. Plan 25-01 is `autonomous: false` so the executor returns the structured checkpoint to the orchestrator rather than auto-resolving.

**Resume signal expected from the operator:** "migrated" (after running `mix ecto.migrate` on the project's primary dev/CI Postgres host and confirming the table + indexes + column list match the plan's `<how-to-verify>` block) or "blocked: <reason>" if it cannot run.

Plans 02 and 03 (Wave 2 and Wave 3) build on this table — their headless tests pass against the MockRepo, but their integration assertions (Oban uniqueness, FK integrity, multi atomicity, real-DB cohort preview) cannot run without the real table in place.

## Plan-wide Verification

1. **`mix compile --warnings-as-errors`** → exit 0 (D-15 — mandatory). ✅
2. **`mix test test/cairnloop/outbound/bulk_envelope_test.exs test/cairnloop/governance_test.exs`** → 73 tests, 0 failures. ✅
3. **`mix test`** (full headless suite) → 573 tests, 1 failure. The single failure is the pre-existing `Cairnloop.Automation.DraftTest` baseline (memory note: cairnloop-baseline-draft-test-failure / M005 drift). No new regressions introduced by this plan. ✅
4. **`git diff --stat 658437c..HEAD -- . ':!.planning'`** → exactly the 5 declared `files_modified` paths. No scope creep. ✅
5. **Task 4 (`mix ecto.migrate`)** → AWAITING human action (workspace is REPO-UNAVAILABLE). The migration file exists at the exact declared path; the operator must run it on a Postgres-available host before declaring the plan FULLY done. ⏸️ (Tasks 1-3 are committed and durable; Task 4 has been raised as a structured checkpoint to the orchestrator.)

## Next Plan Readiness

- **Plan 02 (`Outbound.bulk_trigger/2`)** can begin its headless / MockRepo-against work immediately. Its integration assertions (Oban uniqueness key shape, multi atomicity) will need the real migration applied — Task 4's "migrated" resume signal is the gate.
- **Plan 03 (InboxLive selection + modal)** will consume both of the new Governance functions added in Task 3. The acceptance criterion "no direct `Conversation |> where(...)` in `InboxLive`" (T-25-04 mitigation) can be asserted via the grep already documented in the threat register.

## Self-Check: PASSED

- Created files exist:
  - `lib/cairnloop/outbound/bulk_envelope.ex` → FOUND
  - `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs` → FOUND
  - `test/cairnloop/outbound/bulk_envelope_test.exs` → FOUND
  - `.planning/phases/25-bulk-selection-fan-out/25-01-SUMMARY.md` → FOUND (this file)
- Modified files have new content:
  - `lib/cairnloop/governance.ex` → contains `def list_eligible_conversation_ids_for_bulk_recovery` and `def preview_bulk_recovery_cohort`
  - `test/cairnloop/governance_test.exs` → contains new describes "list_eligible_conversation_ids_for_bulk_recovery/1 (Phase 25, D-14)" and "preview_bulk_recovery_cohort/1 (Phase 25, D-07 / D-14)"
- Commits exist:
  - `5b49eaf` → FOUND (Task 1 — feat(25-01): add BulkEnvelope schema + headless changeset tests)
  - `83ea233` → FOUND (Task 2 — feat(25-01): add migration for cairnloop_outbound_bulk_envelopes)
  - `edf0aae` → FOUND (Task 3 — feat(25-01): add cohort-eligibility reads to Cairnloop.Governance facade)

---
*Phase: 25-bulk-selection-fan-out*
*Plan: 01*
*Completed (Tasks 1-3): 2026-05-27 — Task 4 (mix ecto.migrate) awaiting operator on Postgres-available host*
