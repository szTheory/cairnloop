---
phase: 25-bulk-selection-fan-out
verified: 2026-05-27T03:57:00Z
status: human_needed
score: 3/3 must-haves verified (headless layer)
overrides_applied: 0
re_verification:
  previous_status: null
  previous_score: null
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Apply Plan 25-01 Task 4 — run `mix ecto.migrate` on a Postgres-available host"
    expected: |
      `mix ecto.migrate` output includes
      `== Running Cairnloop.Repo.Migrations.AddOutboundBulkEnvelopes.change/0`,
      `create table cairnloop_outbound_bulk_envelopes`, and the two indexes
      (`*_requested_at_index`, `*_template_id_index`). A psql/`mix run` column-list
      query on `cairnloop_outbound_bulk_envelopes` returns: `id`, `template_id`,
      `rendered_body`, `recipient_conversation_ids`, `count`, `effective_cap`,
      `requested_by`, `requested_at`, `status`, `refused_reason`, `inserted_at`,
      `updated_at` (12 columns — 11 from the original plan + `effective_cap`
      added by WR-05).
    why_human: |
      `Cairnloop.Repo` is REPO-UNAVAILABLE in this workspace per CLAUDE.md.
      Substrate exists at `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`
      and is compile-clean; only a host with Postgres can apply it. This is the
      canonical operator handoff for Plan 25-01 Task 4 (`checkpoint:human-action`,
      gate: blocking).
  - test: "Run REPO-UNAVAILABLE integration tests on Postgres host: `mix test.integration` (or equivalent)"
    expected: |
      Both `@tag :integration` tests pass:
      (a) `test/cairnloop/outbound_test.exs:511` — name includes "atomically".
          `bulk_trigger/2` writes ONE `BulkEnvelope` row plus N `Message` rows
          atomically; forcing an FK violation rolls back the envelope.
      (b) `test/cairnloop/workers/outbound_worker_test.exs:140` — name includes
          "unique". Two consecutive `Oban.insert` calls with identical
          `(conversation_id, template_id, bulk_envelope_id)` dedup tuple
          succeed once and are deduped on the second.
    why_human: |
      Both tests carry the `# REPO-UNAVAILABLE` marker and are `@tag :integration`
      (excluded from headless `mix test`). They cannot run in this workspace
      and prove Multi atomicity + Oban uniqueness that headless MockRepo tests
      cannot faithfully exercise.
  - test: "Plan 25-03 Task 3 — in-browser end-to-end bulk-send verification on a Postgres-available host"
    expected: |
      With dev server running and 3+ resolved conversations seeded:
      (1) Each `:resolved` row shows a checkbox; non-resolved rows do not.
      (2) Selecting 3 conversations shows the sticky bottom action bar with
          "3 selected" and "Send recovery follow-up to 3" rendered in
          `var(--cl-primary, #A94F30)` (warm rust orange).
      (3) Clicking the primary button opens a `<.focus_wrap>` modal listing
          3 conversation labels (ordered `updated_at desc`), the rendered
          template body, and Cancel/Confirm send buttons.
      (4) Tab cycles focus WITHIN the modal (focus trap works).
      (5) `Esc` cancels the modal AND preserves the 3-row selection (D-08).
      (6) Re-opening and clicking "Confirm send" produces flash
          "Bulk recovery queued for 3 conversations.", clears the selection,
          and appends one `system_outbound` card to each of the three
          conversation timelines (D-A — N cards, not a new card type).
      (7) With `Application.put_env(:cairnloop, :max_batch_size, 2)`:
          selecting 3 resolved + clicking primary shows the refusal banner
          with SVG icon + heading "Batch too large." + body text mentioning
          "safe send limit of 2" + `var(--cl-danger, #B54C36)` accent and
          NO/disabled Confirm send button.
    why_human: |
      Visual brand-token resolution, `<.focus_wrap>` keyboard tab cycling,
      Esc-preserves-selection, and the `system_outbound` cards landing on
      affected timelines all require a live browser session against the
      migrated Postgres host. This is the canonical operator handoff for
      Plan 25-03 Task 3 (`checkpoint:human-verify`, gate: blocking).
---

# Phase 25: Bulk Selection & Fan-out — Verification Report

**Phase Goal:** Enable multi-conversation outbound recovery while keeping operator review and safety explicit.
**Verified:** 2026-05-27T03:57:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Phase 25 Success Criteria from ROADMAP.md)

| # | Truth (Success Criterion) | Status | Evidence |
| - | ------------------------- | ------ | -------- |
| 1 | Operators can multi-select conversations in `InboxLive` | VERIFIED | `lib/cairnloop/web/inbox_live.ex:80-107` adds `selected_ids: MapSet.new()` to mount assigns (D-04). Lines 131-141 render per-row checkbox gated on `conv.status == :resolved` with `phx-click="toggle_select"`, `phx-value-id={conv.id}`, `checked={MapSet.member?(@selected_ids, conv.id)}`, and an a11y label. Lines 118-128 render a `Select all visible` header checkbox (`phx-click="toggle_select_all_visible"`). Lines 297-327 implement `toggle_select`, `toggle_select_all_visible`, and `clear_selection` handlers. Lines 150-174 render the sticky bottom action bar (`position: sticky; bottom: 0`, `role="region"`, `aria-label="Bulk actions"`) when `MapSet.size > 0` with `N selected` text and `var(--cl-primary)` primary button. 22 headless tests in `test/cairnloop/web/inbox_live_test.exs` (all green). |
| 2 | A bulk outbound action exposes cohort preview before execution | VERIFIED | `lib/cairnloop/web/inbox_live.ex:333-378` `open_bulk_confirm` handler calls `governance_module().preview_bulk_recovery_cohort(ids)` (key link present, line 346) which returns `%{eligible_ids, sample, more, total}` from `lib/cairnloop/governance.ex:1049-1072` (filters `c.status == :resolved`, orders `updated_at desc`, takes first 5 with `+N more` tail). Modal markup (lines 176-281) renders count + first-5 sample + `+ N more` tail + the snapshotted `rendered_body` inside a `<.focus_wrap id="bulk-confirm-wrap">` with `aria-modal="true"` and `phx-window-keydown="cancel_bulk_confirm" phx-key="Escape"`. WR-06 fix (lines 353-376) snapshots `eligible_ids` from the preview so the count shown equals the count actually sent (CLAUDE.md "snapshot trust facts at decision time"). Confirm path calls `outbound_module().bulk_trigger(ids, opts)` (line 446) — the snapshot boundary is the LiveView, not the worker. |
| 3 | Large batches are bounded to protect host resources | VERIFIED | Two layers of defense-in-depth: (a) UI cap in `lib/cairnloop/web/inbox_live.ex:333-344` — when `count > max_batch_size()` the modal opens with the refusal banner branch and `bulk_trigger/2` is NEVER called. Refusal banner (lines 192-230) shows SVG icon + `var(--cl-danger)` accent + heading "Batch too large." + body referencing the cap + disabled Confirm send button (D-10, brand §7.5 icon+text, never color-alone). (b) Envelope cap in `lib/cairnloop/outbound.ex:199-215` — `bulk_trigger/2` validates `length(conversation_ids) <= max_batch_size()` regardless of caller (defense-in-depth — research Pitfall 4); over-cap calls return `{:error, :batch_too_large}` AND persist a `BulkEnvelope` row with `status: :refused_cap_exceeded` (lines 220-292). `max_batch_size/0` reads `Application.get_env(:cairnloop, :max_batch_size, 25)` (line 37). Oban dedup keys `[:conversation_id, :template_id, :bulk_envelope_id]` (workers/outbound_worker.ex:64-66) enforce at-most-once delivery per recipient per envelope. |

**Score:** 3/3 success criteria verified at the headless / source-evidence layer.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/cairnloop/outbound/bulk_envelope.ex` | Ecto schema with `changeset/2`, `count > 0` validation, status enum `[:submitted, :refused_cap_exceeded]` | VERIFIED | 115 lines; schema `"cairnloop_outbound_bulk_envelopes"`; `@primary_key {:id, :binary_id, autogenerate: false}`; all required fields validated; WR-05 added `:effective_cap` with `> 0` validation. |
| `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs` | Migration with table, `:requested_at` + `:template_id` indexes | VERIFIED | 55 lines; `create table(:cairnloop_outbound_bulk_envelopes, primary_key: false)`; columns match schema (12 total incl. WR-05 `:effective_cap`); two `create index` calls. Migration *application* is human-deferred (Plan 25-01 Task 4). |
| `lib/cairnloop/governance.ex` (+`list_eligible_conversation_ids_for_bulk_recovery/1`, `preview_bulk_recovery_cohort/1`) | Two narrow facade reads (D-14) | VERIFIED | Lines 1021-1027 + 1049-1072; both go through `repo().all/1` (narrow facade per CLAUDE.md / D-30); `preview_bulk_recovery_cohort/1` returns the documented `%{eligible_ids, sample, more, total}` shape ordered `updated_at desc`. |
| `lib/cairnloop/outbound.ex` (+`bulk_trigger/2`, `build_trigger_multi/2`, `max_batch_size/0`, additive `:bulk_envelope_id` opt) | Sealed-additive `trigger/2`; new `bulk_trigger/2` | VERIFIED | 350 lines; `def bulk_trigger(conversation_ids, opts) when is_list(conversation_ids)` at line 199; sealed `def trigger(conversation_id, opts) do` at line 71 (exactly one match — D-12 verified). Telemetry enum-only (WR-04 dropped PII labels from `:triggered` event too). CR-02 fix observes refused-envelope insert errors (lines 252-290). |
| `lib/cairnloop/workers/outbound_worker.ex` | Oban `unique:` keyed on `(conversation_id, template_id, bulk_envelope_id)` | VERIFIED | Lines 64-66; WR-01 expanded moduledoc documents the new job-args shape so host-side custom Oban consumers are forewarned. |
| `lib/cairnloop/web/inbox_live.ex` | Selection + sticky bar + modal + refusal + submit | VERIFIED | 543 lines (from 44 pre-Phase-25); 6 new `handle_event/3` clauses; 4 indirection helpers (`outbound_module/0`, `governance_module/0`, `recovery_follow_up_template_id/0`, `max_batch_size/0`); CR-01 fix (lines 478-487) handles `Ecto.Multi` 4-tuple failure with calm operator copy; WR-06 (lines 353-376, 414-438) snapshots `eligible_ids`. |
| `test/cairnloop/outbound/bulk_envelope_test.exs` | Headless schema tests | VERIFIED | 7 tests; all green. |
| `test/cairnloop/governance_test.exs` (+ 6 new tests) | Cohort-read tests via MockRepo | VERIFIED | 2 new describes; all green. |
| `test/cairnloop/outbound_test.exs` (+ 12 new tests + 1 integration) | `:bulk_envelope_id` opt + `bulk_trigger/2` + REPO-UNAVAILABLE integration | VERIFIED | 17 headless tests pass; 1 `@tag :integration` "atomically" test authored (line 511) awaiting Postgres host. |
| `test/cairnloop/workers/outbound_worker_test.exs` (+ 4 new tests + 1 integration) | Oban unique policy + REPO-UNAVAILABLE integration | VERIFIED | 6 headless tests pass; 1 `@tag :integration` "unique" test authored (line 140) awaiting Postgres host. |
| `test/cairnloop/web/inbox_live_test.exs` (+ 21 new tests) | Headless LiveView tests | VERIFIED | 22 tests total (1 pre-existing + 21 new); all green. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `lib/cairnloop/outbound.ex` `bulk_trigger/2` (submit lane) | `lib/cairnloop/outbound/bulk_envelope.ex` | `Ecto.Multi.insert(:envelope, BulkEnvelope.changeset(...))` | WIRED | Line 328: `Ecto.Multi.insert(:envelope, BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs))`. Refusal lane also persists (line 252) — both paths land on the same audit table per OBS-02 posture. |
| `lib/cairnloop/outbound.ex` `bulk_trigger/2` (submit lane) | `lib/cairnloop/outbound.ex` `build_trigger_multi/2` | `Ecto.Multi.merge` + `Ecto.Multi.append(acc, build_trigger_multi(cid, recipient_opts))` | WIRED | Lines 329-338. Per-recipient multi keys disambiguated via `:multi_key_prefix => cid`. |
| `lib/cairnloop/outbound.ex` `build_trigger_multi/2` | `lib/cairnloop/workers/outbound_worker.ex` | `OutboundWorker.new(job_args, job_opts)` with `bulk_envelope_id`, `conversation_id`, `template_id` keys | WIRED | Lines 146-156. The three keys map exactly to the worker's `unique: keys:` tuple — Oban can dedup. |
| `lib/cairnloop/outbound.ex` cap helper | Application env `:max_batch_size` | `Application.get_env(:cairnloop, :max_batch_size, 25)` | WIRED | Line 37; one occurrence in `outbound.ex` (acceptance grep gate); LiveView has its own copy (D-09 defense-in-depth). |
| `lib/cairnloop/web/inbox_live.ex` `open_bulk_confirm` | `lib/cairnloop/governance.ex` `preview_bulk_recovery_cohort/1` | `governance_module().preview_bulk_recovery_cohort(ids)` | WIRED | Line 346. Indirection helper at line 61-63 lets tests stub Governance via `Application.put_env`. |
| `lib/cairnloop/web/inbox_live.ex` `confirm_bulk_send` | `lib/cairnloop/outbound.ex` `bulk_trigger/2` | `outbound_module().bulk_trigger(ids, opts)` | WIRED | Line 446. Snapshotted `rendered_body` passed verbatim (T-25-03 mitigation). WR-06: `ids` sourced from `preview.eligible_ids` (the snapshot), not raw `@selected_ids`. |
| `lib/cairnloop/web/inbox_live.ex` sticky bar primary button | CSS brand token `--cl-primary` | inline `style` attribute | WIRED | Line 169 (primary button); line 156 (sticky bar surface); line 226 (disabled primary in refusal); line 272 (confirm send). All use `var(--cl-primary, #A94F30)` form (WR-03 — host stylesheets can override the cascade). |
| `lib/cairnloop/web/inbox_live.ex` refusal banner | CSS brand token `--cl-danger` | inline `style` attribute | WIRED | Lines 197, 199 — border + icon `currentColor` stroke inherits the token. Brand §7.5 (icon + text, never color-alone) satisfied by the inline SVG at line 199. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `InboxLive` sticky bar count | `@selected_ids` (MapSet) | `toggle_select` / `toggle_select_all_visible` event handlers mutate it; `mount/3` initializes to `MapSet.new()` | Yes — runtime MapSet operations | FLOWING |
| `InboxLive` modal preview | `@bulk_preview` (`%{count, sample, more, rendered_body, eligible_ids, template_id}`) | `open_bulk_confirm` calls `governance_module().preview_bulk_recovery_cohort(ids)` → real `repo().all/1` against `Conversation` schema with `status: :resolved` filter | Yes — real Ecto query through narrow facade | FLOWING (production); headless tests stub via `StubGovernance` |
| `BulkEnvelope.rendered_body` | `:rendered_body` schema field | Caller (`InboxLive`) passes pre-rendered body to `bulk_trigger/2`; persisted verbatim into envelope row (no re-rendering) | Yes — snapshotted at decision time | FLOWING |
| `OutboundWorker` job args (dedup tuple) | `"conversation_id"`, `"template_id"`, `"bulk_envelope_id"` | Built in `build_trigger_multi/2` from caller opts; passed to `OutboundWorker.new/2` | Yes — three keys land in `Oban.Job.args` map | FLOWING |
| Refusal `BulkEnvelope` row | `:status :refused_cap_exceeded`, `:refused_reason`, `:effective_cap` | `bulk_trigger_refused/6` builds attrs and inserts via `repo().insert/1`; CR-02 fix observes the result and surfaces audit-failure telemetry | Yes — durable audit row + telemetry observability | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Warnings-clean build (D-15) | `mix compile --warnings-as-errors` | exit 0 | PASS |
| Phase 25 headless test suite | `mix test test/cairnloop/outbound_test.exs test/cairnloop/outbound/bulk_envelope_test.exs test/cairnloop/governance_test.exs test/cairnloop/workers/outbound_worker_test.exs test/cairnloop/web/inbox_live_test.exs --exclude integration` | 126 tests, 0 failures (2 integration excluded as expected) | PASS |
| Sealed `trigger/2` public signature | `grep -c "^  def trigger(conversation_id, opts) do" lib/cairnloop/outbound.ex` | 1 | PASS (D-12) |
| D-14 negative gate (no direct Ecto in web layer) | `grep -c "Conversation \|> where" lib/cairnloop/web/inbox_live.ex` | 0 | PASS |
| No raw Elixir terms in operator copy | `grep -E "inspect\(" lib/cairnloop/web/inbox_live.ex \| grep -v '^#' \| wc -l` | 0 | PASS (T-25-06 mitigation) |
| Oban unique declaration | `grep -c "unique: \[period: :infinity, fields: \[:worker, :args\], keys: \[:conversation_id, :template_id, :bulk_envelope_id\]\]" lib/cairnloop/workers/outbound_worker.ex` | 1 | PASS (D-11) |
| REPO-UNAVAILABLE coverage | `grep -c "# REPO-UNAVAILABLE" test/cairnloop/outbound_test.exs test/cairnloop/workers/outbound_worker_test.exs` | 2 + 2 | PASS (D-16) |
| Integration tests authored | `grep -n "@tag :integration"` in the two test files | line 511 "atomically" + line 140 "unique" | PASS (both keywords present, awaiting Postgres host) |
| Brand-token expression (WR-03) | `grep -c "var(--cl-primary\|var(--cl-danger\|var(--cl-text-muted\|var(--cl-text-soft\|var(--cl-overlay\|var(--cl-on-primary\|var(--cl-shadow\|var(--cl-surface" lib/cairnloop/web/inbox_live.ex` | Multiple | PASS |

### Probe Execution

This phase does not declare probes in the `scripts/*/tests/probe-*.sh` convention; SKIPPED (no probe contract).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| BULK-01 | 25-01 + 25-03 | Bulk selection capability in `InboxLive` for resolved or tagged conversations | SATISFIED | Plan 25-01 added narrow facade reads (`list_eligible_conversation_ids_for_bulk_recovery/1`, `preview_bulk_recovery_cohort/1`); Plan 25-03 wired per-row checkboxes + select-all-visible + sticky bar on `:resolved` rows. v1 covers status-based eligibility; tag-driven cohorts are out of scope per the PRD. |
| BULK-02 | 25-02 + 25-03 | Bulk outbound trigger workflow: "Compose once, fan-out to N recipients" | SATISFIED | Plan 25-02 added `Outbound.bulk_trigger/2` (library layer) — snapshot `rendered_body` once, fan out per-recipient via `build_trigger_multi/2`. Plan 25-03 wired the InboxLive `confirm_bulk_send` handler that calls it through `outbound_module().bulk_trigger(ids, opts)`. |
| BULK-03 | 25-01 + 25-02 + 25-03 | Safety guards for bulk actions: max batch size limits and idempotency | SATISFIED | Cap: `max_batch_size/0` defaults to 25, sourced from `Application.get_env(:cairnloop, :max_batch_size, 25)`. Enforced at both layers (UI in `inbox_live.ex:338`, envelope in `outbound.ex:208`). Idempotency: Oban `unique: [..., keys: [:conversation_id, :template_id, :bulk_envelope_id]]` on `OutboundWorker`. Refusal lane persists `:refused_cap_exceeded` envelope row + CR-02 surfaces audit failures. |
| UI-03 | 25-03 | Bulk action toolbar in the Inbox for multi-select operations | SATISFIED | Sticky bottom-anchored action bar with `N selected` + Clear selection + brand-primary Send recovery follow-up to N button. `<.focus_wrap>` confirmation modal with `aria-modal="true"`, `phx-window-keydown="cancel_bulk_confirm" phx-key="Escape"`, cancel-preserves-selection (D-08 Pitfall 6), calm fail-closed refusal banner (D-10). All four requirement IDs accounted for; no orphans against REQUIREMENTS.md mapping. |

All four phase-declared requirements (BULK-01, BULK-02, BULK-03, UI-03) are SATISFIED at the headless layer. REQUIREMENTS.md does not map additional IDs to Phase 25 — no orphans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none of the Phase-25-modified files) | — | TBD/FIXME/XXX debt markers | INFO | Zero unreferenced debt markers in any of the 5 modified source files (Phase 25 source files clean per debt-marker gate). |
| `lib/cairnloop/web/inbox_live.ex` | 82 | Comment contains literal "placeholder" | INFO (not a stub) | Self-documenting historical comment explaining WR-02 fix (a dead `if connected?(socket)` block was removed). Points to future pubsub work via the wired-but-unused `prune_selected_ids/2` helper. No code path is a stub. |
| `lib/cairnloop/outbound.ex` | 267, 282 | Logger.error uses `inspect/1` | INFO | Acceptable per CR-02 rationale and CLAUDE.md (T-15-13 forbids inspect on operator-visible columns; structured diagnostics for ops are allowed). Comment on lines 261-263 explicitly notes "structured diagnostic for ops, not operator copy". |

No blocker or warning anti-patterns. No `console.log`-only implementations (N/A for Elixir). No `return null` placeholders. No `coming soon` operator copy. The codebase is implementation-complete at the headless layer.

### Human Verification Required

Three items deferred to operator on Postgres-available host (all documented as `checkpoint:human-action` / `checkpoint:human-verify` gates within the plan; surfaced in `human_verification` frontmatter):

#### 1. Apply migration on Postgres host (Plan 25-01 Task 4)

**Test:** Run `mix ecto.migrate` on a host where `Cairnloop.Repo` is available.
**Expected:** Output shows the migration name, table creation, and the two `*_index` lines. A `information_schema.columns` query returns the 12-column list (including WR-05's `:effective_cap`).
**Why human:** `Cairnloop.Repo` is REPO-UNAVAILABLE in this workspace per CLAUDE.md / D-16.

#### 2. Run REPO-UNAVAILABLE integration tests (Plans 25-02 + 25-03)

**Test:** `mix test.integration` (or equivalent) on the migrated Postgres host.
**Expected:** Both `@tag :integration` tests pass — atomicity FK rollback (in `outbound_test.exs:511`) + Oban dedup uniqueness (in `outbound_worker_test.exs:140`).
**Why human:** Both tests carry the `# REPO-UNAVAILABLE` marker and prove Multi atomicity + Oban uniqueness that headless MockRepo tests cannot faithfully exercise.

#### 3. In-browser end-to-end bulk-send verification (Plan 25-03 Task 3)

**Test:** Boot dev server, seed three resolved conversations, exercise checkbox selection → sticky bar → modal → Confirm send → observe `system_outbound` cards on affected timelines. Then exercise the cap-exceeded refusal path with `Application.put_env(:cairnloop, :max_batch_size, 2)`.
**Expected:** All seven sub-checks from Plan 25-03 Task 3 `<how-to-verify>` hold: checkboxes only on resolved rows; sticky bar with brand-primary button; `<.focus_wrap>` traps tab focus; Esc preserves selection; Confirm clears selection + queues flash; oversized cohort renders the SVG-iconed refusal banner with `var(--cl-danger)` accent and no Confirm send button.
**Why human:** Visual brand-token resolution, `<.focus_wrap>` keyboard tab cycling, Esc-preserves-selection, and `system_outbound` cards landing on affected timelines all require a live browser session against the migrated Postgres host. This is the canonical operator handoff for the checkpoint:human-verify gate.

### Gaps Summary

**No gaps blocking goal achievement at the headless layer.**

All three ROADMAP Success Criteria are observably satisfied in the codebase:
1. Multi-select wiring + sticky bar with brand-token primary button + 22 green LiveView tests.
2. Cohort preview modal with snapshotted body, sample, and `+N more` tail; eligibility goes through the narrow Governance facade (D-14 gate at 0); 126 headless tests pass.
3. Hard cap enforced at BOTH layers (UI + envelope) with calm fail-closed refusal banner + persisted refusal envelope (CR-02 surfaces audit failures); Oban dedup keys enforce at-most-once delivery per recipient per envelope.

The three remaining items (migration apply, integration tests, in-browser UAT) are explicitly documented as `checkpoint:human-action` / `checkpoint:human-verify` gates within the plans themselves — they are the canonical operator handoff for this phase under the REPO-UNAVAILABLE constraint (CLAUDE.md / D-16), NOT gaps. Per the verifier's contract, they surface in `human_verification` rather than `gaps`.

The 8 code-review fix commits (CR-01, CR-02, WR-01..WR-06) that landed on top of the plan commits are all reflected in the current source files — verified by grep against the actual code, not just the SUMMARY narrative:
- CR-01: `lib/cairnloop/web/inbox_live.ex:478-487` handles Ecto.Multi 4-tuple failure.
- CR-02: `lib/cairnloop/outbound.ex:252-290` observes refused-envelope insert errors with structured Logger.error + distinct `:refused_cap_exceeded_audit_failed` telemetry outcome.
- WR-01: Worker moduledoc enumerates expanded job-args shape.
- WR-02: Dead `if connected?(socket)` block removed; `prune_selected_ids/2` wired for future pubsub.
- WR-03: All hex/rgba colors expressed as `var(--cl-<name>, <fallback>)` form.
- WR-04: PII labels dropped from `Outbound.trigger/2` telemetry (now `outcome: :triggered` enum-only).
- WR-05: `:effective_cap` snapshot on BulkEnvelope (both submit + refused paths) — schema, migration, and both call sites all updated.
- WR-06: `confirm_bulk_send` sends `preview.eligible_ids`, not raw `@selected_ids` (closes the multi-tab drift window).

---

_Verified: 2026-05-27T03:57:00Z_
_Verifier: Claude (gsd-verifier)_
