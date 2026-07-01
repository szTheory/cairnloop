---
phase: 37-component-primitives
plan: "04"
subsystem: web-components
tags: [components, status, aria, accessibility, brand-tokens, never-color-alone]
dependency_graph:
  requires: ["37-03"]
  provides: ["cl_switch/1", "cl_status_cell/1", "cl_source_card/1"]
  affects: ["lib/cairnloop/web/components.ex", "test/cairnloop/web/components_test.exs"]
tech_stack:
  added: []
  patterns:
    - "role=switch button with to_string(checked) ARIA string attribute"
    - "cl_chip delegation (no re-authored markup)"
    - "assign_new resolved_icon from status_icon/1 map (cl_banner analog)"
key_files:
  created: []
  modified:
    - lib/cairnloop/web/components.ex
    - test/cairnloop/web/components_test.exs
decisions:
  - "cl_switch uses aria-checked={to_string(@checked)} not raw boolean — ARIA needs string true/false"
  - "cl_status_cell delegates to cl_chip; does not call non-existent action_tone/1"
  - "cl_source_card resolves icon via status_icon/1 map reuse (not hand-authored SVG)"
  - "phx-value-* added to cl_switch :rest include: list — not default Phoenix.Component globals"
metrics:
  duration: "4 minutes"
  completed: "2026-06-03T23:23:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 2
requirements: [UIC-04]
---

# Phase 37 Plan 04: Status/Toggle Primitives Summary

**One-liner:** Three status-bearing primitives — `cl_switch/1` (ARIA role=switch with string aria-checked), `cl_status_cell/1` (cl_chip delegation wrapper), and `cl_source_card/1` (variant+icon status surface) — completing the UIC-04 set with never-color-alone and token-pure render tests.

## What Was Built

### cl_switch/1 (UIC-04 / D-04)
A real `<button role="switch">` toggle control with server-owned checked state:
- `aria-checked={to_string(@checked)}` emits the literal string `"true"` or `"false"` — not a raw boolean HTML attribute (which would be present/absent and unreadable by assistive tech as "off")
- Always-present `@label` (never color alone, brand §7.5)
- `:rest` global `include:` list carries `phx-click`, `phx-value-id`, `phx-value-key` — these are NOT default Phoenix.Component globals; omitting them silently drops toggle wiring (RESEARCH Pitfall 5)
- Markup: `<button>` → `<span class="cl-switch__track"><span class="cl-switch__thumb">` + `<span class="cl-switch__label">`

### cl_status_cell/1 (UIC-04 / D-07)
A thin wrapper delegating to `cl_chip` for table-cell alignment:
- No re-authored chip markup — pure `<span class="cl-status-cell"><.cl_chip .../></span>` delegation
- Required `label` (always visible — never color alone)
- Icon resolved automatically through `cl_chip`'s existing `status_icon/1` map
- No dependency on `AuditLogPresenter.action_tone/1` — that function does not exist; variant+label passed directly by callers (P38/P40 add tone-mapping at adoption)

### cl_source_card/1 (UIC-04 / D-06)
A variant-keyed status surface card mirroring `cl_banner`'s shape:
- `source_variant` → `cl-source-card--#{@source_variant}` class + header icon resolved from `status_icon/1` map (REUSE — no hand-authored SVG)
- Required `:title` slot, optional body `inner_block`, optional `:meta` footer slot
- Drift-map contract honored: `success` replaces `#4A6238`; `info` replaces `#3F6F80` — P40 swap contract ready
- Icon always present in header (never color alone, §7.5)

## Tests Added

9 headless render tests added to `components_test.exs` (Repo-free, fast default suite):

| Test | Primitive | Asserts |
|------|-----------|---------|
| role=switch + aria-checked=false + label + phx-click | cl_switch | ARIA contract + :rest passthrough |
| aria-checked=true when checked={true} | cl_switch | String attr form, not boolean |
| Token-purity (no hex) | cl_switch | refute html =~ ~r/#[0-9a-fA-F]{3,6}/ |
| cl-status-cell + cl-chip--success + label + svg | cl_status_cell | chip delegation + never-color-alone |
| Default neutral variant renders label | cl_status_cell | Default attr behavior |
| Token-purity (no hex) | cl_status_cell | refute html =~ ~r/#[0-9a-fA-F]{3,6}/ |
| cl-source-card--success + svg + title | cl_source_card | Variant + icon + slot |
| cl-source-card--info + :meta slot | cl_source_card | Optional meta slot rendering |
| Token-purity (no hex) | cl_source_card | refute html =~ ~r/#[0-9a-fA-F]{3,6}/ |

## Deviations from Plan

None — plan executed exactly as written.

The only minor variance: the `cl_status_cell` doc comment originally said "Does NOT call `AuditLogPresenter.action_tone/1`" which would have caused `grep -F 'action_tone' lib/cairnloop/web/components.ex` to match. Rephrased to "tone-agnostic by design" to honor the acceptance criteria strictly (no `action_tone` string in the file).

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All three components are stateless render-only functions. XSS mitigated via HEEx auto-escaped `{...}` for all caller text; `cl_icon`'s `raw/1` stays on its FIXED internal icon-path allowlist — `cl_source_card` resolves the icon name from the trusted `status_icon/1` map, never from caller input (T-37-08). `cl_switch` `:rest` uses explicit `include:` allowlist dropping arbitrary attrs (T-37-09).

## Known Stubs

None. All three primitives are fully wired: `cl_switch` renders real ARIA markup, `cl_status_cell` delegates to the real `cl_chip`, and `cl_source_card` renders real variant classes + real icons from the shared map.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1: cl_switch/1 | be38000 | feat(37-04): add cl_switch/1 role=switch toggle component (UIC-04 / D-04) |
| Task 2: cl_status_cell/1 | 5822a38 | feat(37-04): add cl_status_cell/1 table-cell chip wrapper (UIC-04 / D-07) |
| Task 3: cl_source_card/1 | 1878fd6 | feat(37-04): add cl_source_card/1 variant-keyed status surface (UIC-04 / D-06) |

## Self-Check: PASSED

| Item | Status |
|------|--------|
| lib/cairnloop/web/components.ex | FOUND |
| test/cairnloop/web/components_test.exs | FOUND |
| 37-04-SUMMARY.md | FOUND |
| Commit be38000 (cl_switch) | FOUND |
| Commit 5822a38 (cl_status_cell) | FOUND |
| Commit 1878fd6 (cl_source_card) | FOUND |
| 3 new functions in components.ex | VERIFIED |
| mix compile --warnings-as-errors | PASSED |
| mix test components_test.exs (31 tests) | PASSED |
| mix test brand_token_gate_test.exs | PASSED |
| grep action_tone → no match | PASSED |
