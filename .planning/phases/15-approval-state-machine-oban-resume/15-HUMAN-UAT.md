---
status: partial
phase: 15-approval-state-machine-oban-resume
source: [15-VERIFICATION.md, 15-VALIDATION.md]
started: 2026-05-24
updated: 2026-05-24
---

## Current Test

[awaiting human / host-environment testing]

> All four items are environment-blocked in this workspace (no live Oban runtime,
> no Postgres-backed `Cairnloop.Repo`, no browser) and were pre-declared Manual-Only /
> `# REPO-UNAVAILABLE` in 15-VALIDATION.md. Run them in a host app that has Oban +
> Postgres configured. The automated Phase 15 surface is fully green (260 scoped
> tests, 0 failures; `mix compile --warnings-as-errors` clean) and all 10 must-haves
> verified in code.

## Tests

### 1. Footer affordance brand compliance (FLOW-03, brand §7.5/§10.2/§13.2)
expected: In a conversation with a `:requires_approval` governed action, the
Approve / Reject / Defer footer affordances render with status conveyed by BOTH
text and color (never color-alone), calm reason-forward copy, brand primary token
(`var(--cl-primary, #A94F30)`), and correct rail placement.
result: [pending]

### 2. Snapshot-vs-live prose divergence (D15-14 trust-drift)
expected: With a proposal whose propose-time snapshot (`rendered_consequence`/`title`)
diverges from what live `Preview.render/1` would now produce, the approval surface
shows the SNAPSHOTTED value, never the live render. (Code reads the snapshot column;
behavioral proof needs a row where the two genuinely differ.)
result: [pending]

### 3. End-to-end async approval → resume Oban flow (APRV-01/APRV-02/APRV-03)
expected: In a host app with Oban configured, approving an action enqueues
`ApprovalResumeWorker`, which re-validates against current context, transitions the
approval to `:execution_pending` (never executes `run/3`), and produces the full
append-only event trail (`:approval_requested` → `:approved` → `:revalidation_passed`).
Also confirm the scheduled `ApprovalExpiryWorker` flips a stale `:pending` → `:expired`.
result: [pending]

### 4. FLOW-03 blank-reason UX in the browser
expected: Submitting Reject or Defer without a reason surfaces a calm, humanized
"A reason is required." message and persists nothing (server-side guard is
code-verified; this confirms the rendered flash/UX).
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
