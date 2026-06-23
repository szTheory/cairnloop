---
phase: 41-conversation-rail-progressive-disclosure-d2
plan: "03"
subsystem: web/conversation_live
tags: [rail, disclosure, tier-2, cl_disclosure, D-08, D-09, RAIL-01, RAIL-02]
dependency_graph:
  requires: ["41-01", "41-02"]
  provides: ["governed_action_card restructured — 3 Tier-2 cl_disclosure groups + Trace group + auto-open booleans"]
  affects: ["lib/cairnloop/web/conversation_live.ex"]
tech_stack:
  added: []
  patterns:
    - "cl_disclosure/1 for all 4 rail groups (3 Tier-2 + 1 Trace standalone)"
    - "Enum.with_index for unique per-event disclosure ids"
    - "cl_fact_list/1 replacing bespoke trace dl"
    - "Static auto_open_inputs / auto_open_policy booleans from snapshot state (D-08/D-09)"
key_files:
  created: []
  modified:
    - lib/cairnloop/web/conversation_live.ex
decisions:
  - "auto_open_inputs derived from pending? OR proposal.status in [:scope_invalid, :policy_denied] — same discriminant as block_reason_copy/1 (no second discrimination path)"
  - "auto_open_policy derived from proposal.status == :policy_denied only"
  - "Scope section folded into Inputs & scope group body (3 Tier-2 groups, not 4)"
  - "Trace group carries no data-tier attribute — Expand-all (D-06) must not reach it"
  - "No raw/1 introduced; D-22 masking preserved (inspect+<pre> behind expanders)"
metrics:
  duration: "~15 min"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 1
---

# Phase 41 Plan 03: governed_action_card/1 Restructure Summary

One-liner: Restructured `governed_action_card/1` into a safety-pinned native-`<details>` accordion — Tier-1 pinned outside `<details>`, 3 Tier-2 `cl_disclosure` groups (Inputs & scope / History / Policy explanation) + 1 standalone Trace group, with static auto-open booleans from snapshot state for D-08.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Compute static auto-open booleans in the assign block (D-08, D-09) | 00cd42e | conversation_live.ex |
| 2 | Migrate four expanders to cl_disclosure, fold Scope into Inputs, pin Tier-1, add Trace group | 33f5b57 | conversation_live.ex |

## Verification Results

- `mix compile --warnings-as-errors` exits 0 after each task.
- RAIL-01 (Tier-1 isolation): GREEN — `governed-action-footer` is a Tier-1 sibling; all `<details>` before the footer are balanced.
- RAIL-02 structure: GREEN — exactly 3 `data-tier="2"` groups with summaries "Inputs & scope", "History", "Policy explanation" + "Identifiers & trace" standalone without `data-tier`.
- RAIL-02 mechanism: GREEN — `<details>` count == `phx-update="ignore"` count and >= 4.
- D-08 positive: GREEN — pending proposal opens Inputs group; policy_denied opens both Inputs and Policy.
- D-08 negative: GREEN — non-pending/non-blocked proposal emits no static `open` on any Tier-2 group.
- D-09 render-purity (behavior 6): GREEN — no `handle_event` clause head toggles disclosure state; `open={@...}` only binds `@auto_open_inputs` / `@auto_open_policy`.
- RAIL-03 (behavior 7): RED — expected to stay RED; Wave 4 (Plan 04) adds Expand-all / Collapse-all controls.
- Pre-existing tests: GREEN — status labels, no-history empty state, approval footer, no regressions.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all data is wired from the existing assign pipeline.

## Threat Flags

No new threat surface introduced. The D-02/D-22 masking choke point is STRENGTHENED by this plan:
- Previously always-visible trace `dl` is now behind a default-closed `cl_disclosure` (T-41-03 mitigated).
- All raw snapshots remain behind `inspect(.., pretty: true)` in `<pre>` — no `raw/1` (T-41-04 mitigated).

## Self-Check: PASSED

- FOUND: `.planning/phases/41-conversation-rail-progressive-disclosure-d2/41-03-SUMMARY.md`
- FOUND commit: `00cd42e` (Task 1 — auto-open booleans)
- FOUND commit: `33f5b57` (Task 2 — template restructure)
- `mix compile --warnings-as-errors` exits 0
- RAIL-01/RAIL-02/D-08/D-09: all GREEN
- RAIL-03: RED (expected — Wave 4)
- No pre-existing regressions (OutboundWorkerTest + SettingsLive are documented baseline flakes)
