# Phase M009-S04 Verification

## Scope

This closure artifact backfills the missing proof for Phase M009-S04 after the Phase 8 semantics
repair. It records fresh automated evidence from 2026-05-21, maps the repaired implementation to
`M009-REQ-08` and `M009-REQ-09`, and keeps the repo-backed realism lane separate from the
implementation-backed proof that did complete in this workspace.

## Requirement Coverage Summary

| Requirement | Closure posture | Primary fresh evidence | Notes |
|-------------|-----------------|------------------------|-------|
| `M009-REQ-08` | Closed with residual verification risk | Focused Phase 4 rerun on 2026-05-21 (`50 tests, 0 failures`) | Search and draft boundaries now use repaired scope semantics; repo-backed recorder lane is still blocked by missing `Cairnloop.Repo` |
| `M009-REQ-09` | Closed with residual verification risk | Focused Phase 4 rerun on 2026-05-21 (`50 tests, 0 failures`) | Durable gap storage now separates access semantics from UI context and dedupes assistive-only search gaps within 24 hours |

## M009-REQ-08

### Implementation evidence

- `lib/cairnloop/retrieval/gap_event.ex`
  now treats `tenant_scope` as a bounded access-contract enum and adds bounded `ui_surface`
  metadata so the durable contract no longer stores UI surface names as pseudo-scope.
- `lib/cairnloop/retrieval/gap_recorder.ex`
  normalizes `tenant_scope`, `ui_surface`, and `host_user_id` in one boundary-owned seam and
  applies the 24-hour assistive-only search dedupe rule without moving durable writes into
  telemetry handlers.
- `lib/cairnloop/web/search_modal_component.ex`
  persists search no-hit, retrieval-error, and assistive-only outcomes with
  `tenant_scope: :host_user_scoped` plus separate `ui_surface`, while leaving mixed or
  canonical-backed searches out of durable gap storage.
- `lib/cairnloop/automation/workers/draft_worker.ex`
  preserves weak-grounding and policy-limit recording from the draft boundary while writing the
  repaired scope semantics instead of `"conversation"`-style pseudo-scope values.
- `priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs`
  backfills old rows by mapping `conversation | inbox | settings` into `ui_surface` and
  repurposing `tenant_scope` to bounded access semantics.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs`
- Observed outcome on `2026-05-21`: `50 tests, 0 failures`.
- Repeated startup caveat preserved exactly once per closure guidance:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- `test/cairnloop/retrieval_test.exs` and `test/cairnloop/retrieval/telemetry_test.exs`
  preserve the broader telemetry contract, including `:mixed_results` and
  `:assistive_only_results`, so observability remains broader than durable storage.
- `test/cairnloop/web/search_modal_component_test.exs` proves durable storage now records
  no-hit, retrieval-error, and assistive-only outcomes with corrected scope semantics and skips
  mixed or canonical-backed results.

### Manual checks

- Search no-hit and retrieval-failure trust-language review: current implementation and
  `test/cairnloop/web/search_modal_component_test.exs` keep the UI copy calm and explicit:
  "No verified guidance matched this search yet" for no-hit and
  "Search is unavailable right now. Keep working in the current conversation, then try the search again."
  for retrieval failure.

### Residual risk

The fresh seam-level proof is strong, but this workspace still cannot complete a repo-backed
recorder or query lane. Requirement closure therefore stays at `closed with residual verification
risk` instead of claiming a full live-storage proof.

## M009-REQ-09

### Implementation evidence

- `lib/cairnloop/retrieval/gap_event.ex`
  now stores access semantics, UI context, query fingerprinting, canonical-versus-assistive hit
  counts, and bounded evidence snapshots in one explicit envelope.
- `lib/cairnloop/retrieval/gap_recorder.ex`
  now defaults unscoped events to `:system_unscoped`, defaults missing UI context to
  `:unspecified`, and dedupes assistive-only search rows by query fingerprint plus access
  contract, `host_user_id`, `ui_surface`, retrieval surface, outcome class, and reason.
- `test/cairnloop/retrieval/gap_recorder_test.exs`
  now proves the repaired semantics directly, including `tenant_scope: :host_user_scoped`,
  `ui_surface: :conversation`, and the 24-hour dedupe rule.
- `test/cairnloop/automation/workers/draft_worker_test.exs`
  proves draft-side weak-grounding rows preserve the existing reasons while writing corrected
  access semantics and bounded UI metadata.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs`
- Observed outcome on `2026-05-21`: `50 tests, 0 failures`.
- Repeated startup caveat:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- `test/cairnloop/retrieval/gap_recorder_test.exs`
  covers append-only sanitized persistence, repaired scope semantics, and the assistive-only
  dedupe window.
- `test/cairnloop/retrieval/workers/prune_gap_events_test.exs`
  preserves the explicit 90-day retention contract.
- `test/cairnloop/automation/workers/draft_worker_test.exs` and
  `test/cairnloop/web/search_modal_component_test.exs`
  prove the real product seams now emit corrected durable rows instead of storing UI-surface
  strings in `tenant_scope`.

### Manual checks

- Draft weak-grounding and escalation trust-language review: the current shared reason copy keeps
  assistive-only and policy-limit states explicit without bluffing canonical confidence, and the
  existing draft rail tests still preserve that distinction between canonical guidance and
  supporting evidence.

### Residual risk

The durable contract is well-covered by focused tests and implementation review, but the realism
lane could not execute against a live repo-backed persistence path in this shell. The correct
closure posture remains `closed with residual verification risk`.

## Semantics Checklist

- Access-contract semantics are distinct from UI-surface metadata:
  `tenant_scope` now stores bounded access semantics such as `host_user_scoped`, while
  `ui_surface` stores `conversation | inbox | settings | unspecified`.
- Assistive-only search outcomes persist only when canonical evidence is absent:
  durable search writes now create `assistive_only_results` rows only for zero-canonical,
  assistive-present result sets.
- Telemetry remains broader than durable gap storage:
  retrieval telemetry still classifies `mixed_results` and canonical-backed outcomes, while
  durable storage intentionally skips those branches.
- Canonical-versus-assistive distinctions remain preserved in storage, copy, and verification
  language:
  hit counts, reason atoms, search copy, draft copy, and this closure artifact all keep the two
  evidence classes separate.

## Realistic Proof Lane

### Attempted command

`MIX_ENV=test mix run -e 'Application.put_env(:cairnloop, :repo, Cairnloop.Repo); IO.inspect(Cairnloop.Retrieval.GapRecorder.record(%{query: "phase-8-proof", surface: :search_modal, outcome_class: :weak_grounding, reason: :assistive_only_results, host_user_id: "phase-8-proof", tenant_scope: :host_user_scoped, ui_surface: :conversation}, schedule_prune_fn: fn -> :ok end), label: "gap_record")'`

### Observed outcome

- The command was attempted on `2026-05-21`.
- It did not complete a repo-backed recorder path.
- First blocking error line:
  `** (UndefinedFunctionError) function Cairnloop.Repo.one/1 is undefined (module Cairnloop.Repo is not available)`
- The run also repeated the existing startup caveat:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- This is an environment-blocked proof lane, not a retrieval-contract defect in the Phase 8
  implementation itself.

### Residual risk impact

The blocked realism lane means the freshest proof stays seam-level and implementation-backed rather
than repo-backed. That residual verification risk must stay visible, but it is not grounds for
`cannot close` because the focused suite and semantic checks completed successfully.

## Backfill Summary

Fresh proof on `2026-05-21` shows the focused Phase 4 suite passed with `50 tests, 0 failures`
after the semantics repair. The repaired implementation now separates access semantics from UI
context, persists assistive-only search gaps only at the zero-canonical decision boundary, and
keeps telemetry broader than durable storage. The repo-backed recorder realism lane is still
blocked by the missing `Cairnloop.Repo` runtime surface, so the honest closure posture is
`closed with residual verification risk`.
