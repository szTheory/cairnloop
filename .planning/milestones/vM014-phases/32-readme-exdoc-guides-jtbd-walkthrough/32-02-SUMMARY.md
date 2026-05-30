---
phase: 32-readme-exdoc-guides-jtbd-walkthrough
plan: "02"
subsystem: documentation
tags: [guides, exdoc, jtbd, host-integration, telemetry, behaviours]
dependency_graph:
  requires: []
  provides:
    - guides/02-jtbd-walkthrough.md
    - guides/03-host-integration.md
  affects:
    - HexDocs published guide set (once mix.exs wired in plan 32-03)
tech_stack:
  added: []
  patterns:
    - ExDoc guide prose structure (H1 + ## per stage/section)
    - Bounded screenshot TODO block (D-01)
    - Four-behaviour host integration documentation order
key_files:
  created:
    - guides/02-jtbd-walkthrough.md
    - guides/03-host-integration.md
  modified: []
decisions:
  - "Used /support and /support/:id throughout (shipped routes, not test-internal /inbox or /governance/:id)"
  - "AutomationPolicy headline example defaults to :require_approval — not :allow — matching HITL invariant"
  - "Notifier documents all three callbacks (on_conversation_resolved/2, on_sla_breach/3, on_outbound_triggered/2) — stale README 2-callback pattern not carried over"
  - "Telemetry section relocated from README into 03-host-integration.md as observability-only subsection"
  - "No PNG references committed; guides/assets/ not created; bounded SCREENSHOTS TODO block placed as final content in 02"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-29T01:11:57Z"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 32 Plan 02: Content-Heavy ExDoc Guides — JTBD Walkthrough + Host Integration Summary

Nine-stage JTBD prose walkthrough with screen-region descriptions and bounded screenshot TODO, plus full four-behaviour host integration guide with relocated telemetry section.

## What Was Built

### Task 1: guides/02-jtbd-walkthrough.md (commit fb322cc)

A 193-line ExDoc guide covering the full JTBD lifecycle in the exact stage order from
`test/integration/golden_path_test.exs`. Each stage has a prose description explaining what
happens and why, plus a labeled screen-region description telling the operator what to expect
in the UI.

Stage sequence (golden-path order):
1. Seed — conversation + customer message created
2. Inbox sees the conversation — InboxLive at `/support` shows all status states
3. Conversation workspace — `/support/:id`, cmd+k search, citation chip
4. Approve AI draft — HITL approval before any reply reaches the customer
5. Governed tool proposal approve — via `Cairnloop.Governance` facade
6. ToolExecutionWorker reaches `:success` — three-layer at-most-once idempotency
7. Resolve — `Chat.resolve_conversation/2`
8. Outbound trigger from sidebar — `Cairnloop.Outbound.trigger/2` recovery follow-up
9. Bulk recovery — InboxLive multi-select → confirm → `BulkEnvelope` row + per-recipient Oban jobs

The guide:
- Uses only shipped routes `/support` and `/support/:id` (never `/inbox` or `/governance/`)
- Contains no PNG image references
- Does not create `guides/assets/`
- Ends with the verbatim bounded `<!-- SCREENSHOTS: ... -->` block (D-01)

### Task 2: guides/03-host-integration.md (commit 6ea4609)

A 324-line ExDoc guide covering the four host behaviour contracts in adopter-implementation
order: `ContextProvider` → `Notifier` → `AutomationPolicy` → `SLAPolicyProvider`.

Key correctness points:
- `Notifier` documents all three current callbacks — the README's stale 2-callback example
  is not carried over
- `AutomationPolicy` headline example defaults to `:require_approval`, not `:allow` —
  mirroring the project's HITL/approval-gated-only invariant (T-32-03 mitigation)
- All code examples use `MyApp.*` placeholder names, no real secrets or tokens (T-32-02 mitigation)
- `mix cairnloop.gen.notifier` generator escape hatch is documented
- Telemetry section relocated from README (D-09): dual-emission prose with both the
  `[:cairnloop, :conversation, :resolve, :stop]` span example and the
  `[:cairnloop, :conversation, :resolved]` domain-event example
- Arch posture explicitly stated: telemetry is observability only, never a UI/display source

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | fb322cc | docs(32-02): add guides/02-jtbd-walkthrough.md |
| 2 | 6ea4609 | docs(32-02): add guides/03-host-integration.md |

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria met; all automated
verification checks passed.

## Known Stubs

None. Both guides are text-complete. The bounded `<!-- SCREENSHOTS: ... -->` block in
`guides/02-jtbd-walkthrough.md` is an intentional, scoped TODO (D-01) — it is not a
broken stub. The guides are immediately useful without screenshots; PNG capture is a
follow-on manual step for the repo owner.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced.
This is a documentation-only plan.

Both STRIDE threats in the plan's threat register are mitigated:
- T-32-02 (Information Disclosure): all code examples use `MyApp.*` placeholders — no real
  secrets, tokens, or hostnames appear in either guide.
- T-32-03 (Tampering — AutomationPolicy default): the `decide/2` example returns
  `:require_approval`, not `:allow`, matching the project's approval-gated-only invariant.

## Self-Check: PASSED

Files exist:
- guides/02-jtbd-walkthrough.md: FOUND
- guides/03-host-integration.md: FOUND

Commits exist:
- fb322cc: FOUND (git log confirms)
- 6ea4609: FOUND (git log confirms)
