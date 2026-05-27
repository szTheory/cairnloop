---
status: partial
phase: 25-bulk-selection-fan-out
source: [25-VERIFICATION.md]
started: 2026-05-27T07:35:00Z
updated: 2026-05-27T07:35:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Apply migration on a Postgres-available host (Plan 25-01 Task 4)
expected: `mix ecto.migrate` runs `Cairnloop.Repo.Migrations.AddOutboundBulkEnvelopes.change/0`; creates `cairnloop_outbound_bulk_envelopes` table + two indexes (`requested_at_index`, `template_id_index`). Final column list (12 cols): `id, template_id, rendered_body, recipient_conversation_ids, count, effective_cap, requested_by, requested_at, status, refused_reason, inserted_at, updated_at`. Verify via `Cairnloop.Repo.query!("SELECT column_name FROM information_schema.columns WHERE table_name = 'cairnloop_outbound_bulk_envelopes' ORDER BY ordinal_position").rows`.
result: [pending]

### 2. Run REPO-UNAVAILABLE integration tests on Postgres host (Plans 25-01 + 25-02)
expected: `mix test --only integration` passes:
- `test/cairnloop/outbound_test.exs:511` — `bulk_trigger/2` is atomic under FK rollback (Multi semantics)
- `test/cairnloop/workers/outbound_worker_test.exs:140` — Oban `unique:` dedup rejects duplicate `(conversation_id, template_id, bulk_envelope_id)` job inserts
result: [pending]

### 3. In-browser bulk-recovery UAT (Plan 25-03 Task 3)
expected: Boot `iex -S mix phx.server` from a host app, seed ≥3 resolved conversations, then:
- Each resolved row shows a checkbox; non-resolved rows do not
- Selecting rows adds them to a MapSet selection; sticky bar appears at bottom of panel with "N selected" + "Send recovery follow-up to N" primary button using `var(--cl-primary, #A94F30)`
- Clicking primary opens `<.focus_wrap>` modal: count + first-5 sample (ordered `updated_at desc`) + `+N more` + snapshotted template body + Confirm/Cancel buttons
- **Tab cycles focus WITHIN modal** (Cancel ↔ Confirm); `Esc` cancels AND preserves selection (D-08)
- Clicking Confirm produces flash "Bulk recovery queued for N conversations." and clears selection
- Opening each selected conversation shows a single `system_outbound` card appended to timeline (D-A)
- Refusal lane: set `Application.put_env(:cairnloop, :max_batch_size, 2)`, reload inbox, select 3 resolved rows, click primary — modal opens with refusal banner (SVG icon + heading "Batch too large." + body explaining safe limit + `var(--cl-danger, #B54C36)` accent + disabled Confirm button per D-10 / brand §7.5)
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
