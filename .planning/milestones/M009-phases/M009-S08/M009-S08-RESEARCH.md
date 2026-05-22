# Phase M009-S08 Research

**Date:** 2026-05-21
**Phase:** M009-S08 Gap Signal Semantics & Telemetry Closure
**Status:** Ready for planning

## Outcome

Phase 8 should stay as one closure-oriented execution plan. The work is tightly coupled:

- the durable gap-event schema currently stores UI surface names in `tenant_scope`
- search currently records `no_hit` and retrieval-error rows but does not persist assistive-only search outcomes
- draft weak-grounding persistence already exists and should be preserved while its stored scope semantics are repaired
- Phase 4 still lacks `M009-S04-VERIFICATION.md` and an updated `M009-S04-VALIDATION.md`

Splitting this into multiple plans would mostly add coordination overhead, because the code repair and the closure artifacts need to describe the same final semantics.

## Current Mismatch

### Durable scope semantics

- `lib/cairnloop/retrieval/gap_event.ex` stores `tenant_scope` as a plain string and has no separate `ui_surface`.
- `lib/cairnloop/web/search_modal_component.ex` records gap events with `tenant_scope: socket.assigns.host_surface`.
- `lib/cairnloop/automation/workers/draft_worker.ex` records gap events with `tenant_scope: draft_context.host_surface`.
- Existing tests assert the current wrong behavior by expecting `tenant_scope: "conversation"`.

This is the main Phase 8 semantic defect: the field named `tenant_scope` is currently storing UI context instead of access-contract semantics.

### Assistive-only persistence

- Telemetry already classifies assistive-only search or draft outcomes through `:assistive_only_results`.
- Draft weak-grounding persistence already records non-grounded outcomes through `GapRecorder`.
- Search persistence only records retrieval errors and empty recall; it does not yet persist the locked assistive-only search case where canonical hits are zero and assistive hits are present.

This is the second required repair: durable evidence must remain narrower than telemetry, but it still needs the zero-canonical assistive-only search branch.

## Recommended Implementation Package

### 1. Repair the gap-event storage contract

- Add a bounded `ui_surface` field to `cairnloop_retrieval_gap_events`.
- Keep `tenant_scope`, but repurpose it to access semantics.
- Use explicit bounded values such as:
  - `host_user_scoped`
  - `public_only`
  - `system_unscoped`
- Keep `host_user_id` as the concrete scoped subject when the contract is user-scoped.

### 2. Keep semantic decisions at the boundary-owned recorder seam

- Keep writes flowing through `Cairnloop.Retrieval.GapRecorder`.
- Add normalization helpers so callers can pass `tenant_scope` and `ui_surface` explicitly without duplicating mapping logic everywhere.
- Add a bounded dedupe rule for assistive-only search persistence keyed by:
  - `query_fingerprint`
  - `tenant_scope`
  - `host_user_id`
  - `ui_surface`
  - `surface`
  - `outcome_class`
  - `reason`
- Use a 24-hour window for this assistive-only search dedupe path.

### 3. Extend search persistence, not telemetry

- Keep telemetry broad and unchanged unless a concrete mismatch is discovered.
- In `SearchModalComponent`, persist durable assistive-only search events only when:
  - canonical results are zero
  - assistive results are greater than zero
  - the ranked result set therefore lacks canonical guidance
- Do not persist `mixed_results` or canonical-backed searches as gap events.

### 4. Preserve draft weak-grounding behavior while fixing stored semantics

- `DraftWorker` should continue to record weak-grounding outcomes including `:assistive_only_results`, `:clarification_limit_reached`, and `:canonical_insufficient_detail`.
- The Phase 8 change is about stored semantics and closure evidence, not a new draft policy.

## Expected File Ownership

- `priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs`
- `lib/cairnloop/retrieval/gap_event.ex`
- `lib/cairnloop/retrieval/gap_recorder.ex`
- `lib/cairnloop/web/search_modal_component.ex`
- `lib/cairnloop/automation/workers/draft_worker.ex`
- `test/cairnloop/retrieval/gap_recorder_test.exs`
- `test/cairnloop/web/search_modal_component_test.exs`
- `test/cairnloop/automation/workers/draft_worker_test.exs`
- `.planning/milestones/M009-phases/M009-S04/M009-S04-VERIFICATION.md`
- `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md`
- `.planning/REQUIREMENTS.md`

## Verification Surface

Use one focused rerun that covers semantics, persistence, and operator-surface behavior:

`mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs`

Additional focused checks:

- `mix test test/cairnloop/retrieval/gap_recorder_test.exs`
- `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/automation/workers/draft_worker_test.exs`
- `rg -n "tenant_scope|ui_surface|assistive_only_results|host_user_scoped|public_only|system_unscoped" lib/cairnloop test/cairnloop`

## Closure Artifact Guidance

`M009-S04-VERIFICATION.md` should follow the S01 and S03 backfill pattern:

- requirement-structured sections for `M009-REQ-08` and `M009-REQ-09`
- exact commands and observed outcomes
- one narrow realism lane or an explicit blocked-proof note
- a small explicit semantics checklist
- two narrow manual checks only:
  - search no-hit or retrieval-failure copy
  - draft weak-grounding or escalation copy

`M009-S04-VALIDATION.md` should move out of `draft` only after the code repair and verification artifact agree on the real proof state.

## Planning Recommendation

Create one execute plan with four tasks:

1. Repair gap-event scope semantics and add bounded `ui_surface` support.
2. Extend boundary persistence and tests for assistive-only search plus corrected draft semantics.
3. Create `M009-S04-VERIFICATION.md` from a fresh focused rerun plus one realism lane.
4. Update `M009-S04-VALIDATION.md` and `.planning/REQUIREMENTS.md` only if no real contract defect is found.

## Residual Risks To Keep Explicit

- The workspace may still block a live repo-backed realism lane, as seen in S01 and S03 closure work.
- Requirement traceability must not flip to verified if Phase 8 surfaces a real semantics defect during the repair.
- `tenant_scope` naming remains imperfect by design; this phase should fix meaning, not rename the public field.
