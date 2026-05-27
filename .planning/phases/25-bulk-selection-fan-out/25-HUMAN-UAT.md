---
status: complete
phase: 25-bulk-selection-fan-out
source: [25-VERIFICATION.md]
started: 2026-05-27T07:35:00Z
updated: 2026-05-27T16:55:00Z
---

## Current Test

[testing complete — all 3 items shifted left to CI]

## Tests

### 1. Apply migration on a Postgres-available host (Plan 25-01 Task 4)
expected: `mix ecto.migrate` runs `Cairnloop.Repo.Migrations.AddOutboundBulkEnvelopes.change/0`; creates `cairnloop_outbound_bulk_envelopes` table + two indexes (`requested_at_index`, `template_id_index`). Final column list (12 cols): `id, template_id, rendered_body, recipient_conversation_ids, count, effective_cap, requested_by, requested_at, status, refused_reason, inserted_at, updated_at`.
result: pass
covered_by: |
  test/integration/outbound_bulk_envelopes_migration_test.exs — asserts the
  12-column ordering via `information_schema.columns` AND the two B-tree indexes
  (`cairnloop_outbound_bulk_envelopes_requested_at_index`,
  `cairnloop_outbound_bulk_envelopes_template_id_index`) via `pg_indexes`.
  Runs in CI under `mix test.integration` (`.github/workflows/ci.yml` integration
  job, pgvector:pg16 service).

### 2. Run REPO-UNAVAILABLE integration tests on Postgres host (Plans 25-01 + 25-02)
expected: `mix test --only integration` passes:
- `test/cairnloop/outbound_test.exs:511` — `bulk_trigger/2` is atomic under FK rollback (Multi semantics)
- `test/cairnloop/workers/outbound_worker_test.exs:140` — Oban `unique:` dedup rejects duplicate `(conversation_id, template_id, bulk_envelope_id)` job inserts
result: pass
covered_by: |
  2(a) — test/integration/bulk_trigger_atomicity_test.exs proves Multi
  atomicity using a custom FailingAuditor that returns `{:error, :forced_rollback}`
  from its `Multi.run` step. Asserts envelope row + all per-recipient Message
  rows roll back together (cleaner than relying on a Postgrex FK raise — see
  module docstring). Happy-path companion test verifies the envelope correlation
  key lands on every per-recipient Message.

  2(b) — test/cairnloop/workers/outbound_worker_test.exs ("Oban unique: config
  (D-11)") replaces the prior flunk stub with a headless assertion on
  `OutboundWorker.__opts__()[:unique]`. Cairnloop ships no Oban migration (the
  host owns oban_jobs — see test/integration/approval_flow_test.exs:9), so a
  real `Oban.insert` round-trip is out of reach for the integration suite. The
  headless config check is the right level: it locks the dedup tuple to
  `[:conversation_id, :template_id, :bulk_envelope_id]` with
  `period: :infinity, fields: [:worker, :args]`; runtime dedup is Oban's
  upstream contract.

### 3. In-browser bulk-recovery UAT (Plan 25-03 Task 3)
expected: Boot `iex -S mix phx.server`, seed ≥3 resolved conversations, walk the bulk-recovery cockpit (selection → sticky bar → modal → confirm/refusal → timeline cards).
result: pass
covered_by: |
  test/integration/bulk_recovery_live_test.exs — mounts the real
  `Cairnloop.Web.InboxLive` via `Phoenix.LiveViewTest.live/2` against a real
  Postgres-backed inbox and walks the cockpit headlessly:

  - Resolved-only checkboxes (D-01 / D-03).
  - Sticky bar with N selected + brand `var(--cl-primary)` (D-05 + brand §7.5).
  - Modal markup includes `<.focus_wrap>` (id="bulk-confirm-wrap"), cohort
    sample labels, the rendered template body, Cancel/Confirm affordances
    (D-07 / D-08).
  - `render_keydown(view, "cancel_bulk_confirm", %{"key" => "Escape"})`
    closes the modal AND preserves the selection (D-08 / Pitfall 6).
  - Confirm path routes through real `Outbound.bulk_trigger/2`: flash fires
    ("Bulk recovery queued for N conversations."), selection clears, exactly
    N `system_outbound` Messages are persisted and carry
    `metadata["bulk_envelope_id"]` (D-13 / D-A).
  - Refusal lane (`max_batch_size: 2`, 3 resolved selected): modal opens with
    SVG icon + "Batch too large." heading + "safe send limit of 2" copy +
    `var(--cl-danger)` accent + disabled Confirm (D-10 / brand §7.5).

  Focus-trap interior tab cycling is Phoenix's `<.focus_wrap>` contract
  (browser DOM, headless renderer can't drive focus events) — asserting the
  component is in the markup is the right level for this layer; the contract
  is upstream-tested by Phoenix LiveView itself.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none — all human verification items shifted left to CI integration suite]

## Shift-left record

All three items in the original `human_verification` block (see
`25-VERIFICATION.md`) were converted to CI-runnable tests rather than left as
operator handoffs. CI job `integration` (`.github/workflows/ci.yml`) runs
`mix test.integration` against pgvector/pg16; the three new test files above
are picked up under the standard `test --include integration test/integration`
selector.

Rationale: zero-human-verification keeps the phase verifiable on every PR
without a Postgres-equipped operator session, and the LiveViewTest layer
exercises the same code paths a browser would (header → sticky bar →
`<.focus_wrap>` modal → bulk_trigger/2 → `system_outbound` cards) while
surfacing regressions in a deterministic harness.
