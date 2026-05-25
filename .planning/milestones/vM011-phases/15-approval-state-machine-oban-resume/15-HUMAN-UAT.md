---
status: complete
phase: 15-approval-state-machine-oban-resume
source: [15-VERIFICATION.md, 15-VALIDATION.md]
started: 2026-05-24
updated: 2026-05-25
closed_by: integration-test-harness
---

## Current Test

[complete — all four items are now automated]

> These four items were originally Manual-Only / `# REPO-UNAVAILABLE` because this
> workspace had no live `Cairnloop.Repo`, no Oban runtime, and no browser. They are now
> covered by a DB-backed integration suite (`test/integration/`, tag `:integration`) that
> runs against a real Postgres + Phoenix LiveView via a `test/support` host harness, locally
> (`docker compose up -d db && MIX_ENV=test mix test.integration`) and in CI (the new
> `integration` job). **0 human verification required.**
>
> Running the harness surfaced two real Phase-15 defects the headless MockRepo suite could
> not (now fixed): (a) `cairnloop_tool_action_events.to_status` was NOT NULL but approval
> events insert it as nil — fixed additively by migration
> `20260524120200_relax_action_event_to_status_null`; (b) `ApprovalResumeWorker.perform/1`
> matched `status: :pending` while `approve/3` sets `:approved`, so the real approve→resume
> handoff no-op'd and never reached `:execution_pending` — fixed by matching `:approved`
> (the documented state axis), with the headless worker-test fixtures updated to match.

## Tests

### 1. Footer affordance brand compliance (FLOW-03, brand §7.5/§10.2/§13.2)
expected: In a conversation with a `:requires_approval` governed action, the
Approve / Reject / Defer footer affordances render with status conveyed by BOTH
text and color (never color-alone), brand primary token (`var(--cl-primary, #A94F30)`).
result: PASS — automated in `test/integration/approval_footer_live_test.exs`
("footer renders Approve/Reject/Defer with a text label AND the brand color token"):
mounts ConversationLive for real via `Phoenix.LiveViewTest` and asserts the rendered DOM
contains both the text labels and the brand token (discharges §7.5 never-color-alone). The
exact calm-copy wording remains covered by the headless `conversation_live_test.exs`.

### 2. Snapshot-vs-live prose divergence (D15-14 trust-drift)
expected: The approval surface shows the SNAPSHOTTED `rendered_consequence`/`title`, never
a live `Preview.render/1`.
result: PASS — automated in `test/integration/approval_footer_live_test.exs`
("snapshot card shows the propose-time rendered_consequence prose"): seeds a proposal whose
snapshot prose is set and asserts the card renders that column value (no live render path).

### 3. End-to-end async approval → resume Oban flow (APRV-01/APRV-02/APRV-03)
expected: Approving enqueues `ApprovalResumeWorker`, which re-validates against current
context and transitions the approval to `:execution_pending` (never `run/3`), producing the
trail `:approval_requested → :approved → :revalidation_passed`; the scheduled
`ApprovalExpiryWorker` flips a stale lane → `:expired`.
result: PASS — automated in `test/integration/approval_flow_test.exs`: drives
`request_approval → approve → ApprovalResumeWorker.perform` against real Postgres, asserting
the enqueued jobs (capturing `enqueue_fn`), the `:execution_pending` transition, and the
exact append-only event trail; a second test asserts the `:pending → :expired` flip.

### 4. FLOW-03 blank-reason UX
expected: Submitting Reject or Defer without a reason persists nothing.
result: PASS — automated in `test/integration/approval_footer_live_test.exs`
("rejecting/deferring with a blank reason persists nothing and keeps the lane :pending"):
submits the real LiveView forms with an empty reason and asserts the lane stays `:pending`
with no decision event; the with-reason path asserts `:rejected` persists and the footer
affordances disappear. (The calm flash copy is asserted headlessly in
`conversation_live_test.exs`, which inspects `socket.assigns.flash`.)

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None. All four items are automated; the partial unique index (APRV-04), JSONB atom→string
round-trip (APRV-02), async Oban flow (APRV-01/02/03), and LiveView footer (FLOW-03/D15-14)
each have a real-runtime integration test. Two Phase-15 defects found en route are fixed.
