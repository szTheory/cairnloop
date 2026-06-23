---
phase: 40-drift-remediation-brand-token-gate-hardening
plan: "01"
subsystem: web-render
tags: [drift-remediation, brand-tokens, hex-migration, conversation-live]
dependency_graph:
  requires: []
  provides: [on-palette-conversation-live, primitive-footer]
  affects: [brand-token-gate]
tech_stack:
  added: []
  patterns: [cl_button-variant, cl-textarea, cl-stack, cl-row, token-valued-inline-style]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/conversation_live.ex
decisions:
  - "Used cl_button variant=default for defer button (no 'warning' variant exists in cl_button)"
  - "Used token-valued inline style=color:var(--cl-text) for body-color prose (no .cl-text utility class)"
  - "Used class combination cl-text-muted + cl-text-small/micro for muted text (removes hex)"
  - "Used style=gap:var(--cl-space-4) for 12px footer gap (no exact 12px stack utility)"
  - "Used style=align-items:flex-start on button row (cl-row centers by default)"
metrics:
  duration: "~25 minutes"
  completed: "2026-06-04T08:27:31Z"
  tasks_completed: 2
  files_modified: 1
---

# Phase 40 Plan 01: Conversation Rail + Footer Hex Tokenization Summary

Migrated all 15 hardcoded hex color literals out of `lib/cairnloop/web/conversation_live.ex` and rebuilt the approve/reject/defer footer using `cl_button` primitives and `.cl-textarea`. The file now carries zero off-palette hex; the build is warnings-clean; the existing brand-token gate test passes.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Tokenize conversation rail prose + divider hex (non-footer) | efba3d9 | lib/cairnloop/web/conversation_live.ex |
| 2 | Rebuild approve/reject/defer footer with cl_button + .cl-textarea | fb9b98e | lib/cairnloop/web/conversation_live.ex |

## What Was Built

### Task 1 — Non-footer hex tokenization

Applied the D-02 hex→token map to 8 non-footer occurrences:

| Line (before) | Literal | Replacement |
|---------------|---------|-------------|
| 792 | `#e5e7eb` border-top | `var(--cl-border)` |
| 1002, 1049 | `#8b7355` summary color | `class="cl-text-muted cl-text-small"` |
| 1019 | `#8b7355` details color | `class="cl-text-muted cl-text-micro"` |
| 1020 | `#4c4033` event detail body | `style="color: var(--cl-text)"` |
| 1033 | `#8b7355` no-history text | `class="cl-text-muted cl-text-small"` |
| 1040, 1046 | `#4c4033` scope/policy prose | `class="cl-text-small" style="color: var(--cl-text)"` |

### Task 2 — Footer primitives rebuild

Replaced the hand-rolled approve/reject/defer footer block (lines 1070-1117):

| Element | Before | After |
|---------|--------|-------|
| Footer container | `style="display:flex;flex-direction:column;gap:12px"` | `class="cl-stack" style="gap:var(--cl-space-4)"` |
| "Approval required" label | `style="color:#4c4033;font-weight:600"` | `class="cl-text-small" style="color:var(--cl-text);font-weight:600"` |
| Button row | `style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-start"` | `class="cl-row cl-row--wrap" style="align-items:flex-start"` |
| Approve button | Hand-styled `<button style="...color:#fffdf8...">` | `<.cl_button variant="primary" phx-click="approve_action" phx-value-approval-id={...}>` |
| Reject form | `style="display:flex;flex-direction:column;gap:6px"` | `class="cl-stack"` |
| Reject textarea | `style="border:1px solid #c38f57;..."` | `class="cl-textarea"` |
| Reject button | `style="...border:#8b1a1a;background:#fdecea;color:#8b1a1a..."` | `<.cl_button variant="danger" type="submit">` |
| Defer form | Same as reject form | `class="cl-stack"` |
| Defer textarea | `style="border:1px solid #c38f57;..."` | `class="cl-textarea"` |
| Defer button | `style="...border:#7a5c00;background:#fef9e5;color:#7a5c00..."` | `<.cl_button variant="default" type="submit">` |
| Helper text | `style="color:#8b7355;font-style:italic"` | `class="cl-text-muted cl-text-micro" style="font-style:italic"` |

All phx-click/phx-submit event names (`approve_action`, `reject_action`, `defer_action`) and phx-value-approval-id preserved verbatim.

## Deviations from Plan

None — plan executed exactly as written. The structural gaps flagged in RESEARCH §F were pre-resolved in the plan itself:
- Gap #1 (no `warning` variant): plan specified `variant="default"` for defer — used as directed.
- Gap #2 (no `.cl-text` utility): plan specified token-valued inline `style="color:var(--cl-text)"` — used as directed.
- Gap #3 (no exact 12px gap utility): plan permitted `style="gap:var(--cl-space-4)"` — used as directed.

## Verification Results

```
$ grep -nE '#[0-9a-fA-F]{3,6}|rgba\(|hsl\(' lib/cairnloop/web/conversation_live.ex
(no output — file is hex-free)

$ mix compile --warnings-as-errors
(exit 0 — no warnings)

$ mix test test/cairnloop/web/brand_token_gate_test.exs
1 test, 0 failures

$ grep -c '<.cl_button' lib/cairnloop/web/conversation_live.ex
7

$ grep -c 'class="cl-textarea"' lib/cairnloop/web/conversation_live.ex
2

$ grep -c 'variant="warning"' lib/cairnloop/web/conversation_live.ex
0

$ git diff HEAD -- priv/static/cairnloop.css
(no output — cairnloop.css untouched)
```

## Known Stubs

None — all hex literals fully remediated.

## Threat Flags

None — markup-only refactor, no new network endpoints, auth paths, or input-validation changes. Server-side `handle_event` callbacks for `approve_action`/`reject_action`/`defer_action` are untouched (T-40-01 accepted).

## Self-Check: PASSED

- [x] `lib/cairnloop/web/conversation_live.ex` exists and modified
- [x] Commit efba3d9 exists (Task 1)
- [x] Commit fb9b98e exists (Task 2)
- [x] Zero hex/rgba in file (grep returns empty)
- [x] `mix compile --warnings-as-errors` exits 0
- [x] Brand token gate test: 1 test, 0 failures
- [x] `cairnloop.css` untouched (D-01)
