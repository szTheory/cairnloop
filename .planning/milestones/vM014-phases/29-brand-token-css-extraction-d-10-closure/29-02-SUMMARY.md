---
plan: 29-02
phase: 29-brand-token-css-extraction-d-10-closure
status: complete
completed: 2026-05-27
requirements_closed:
  - BRAND-02
  - BRAND-04
---

# Plan 29-02 Summary: Drop Hex Fallbacks + BRAND-04 Gate

## What Was Built

Closed BRAND-02 (drop all `, #<hex>` suffixes from sealed render files) and BRAND-04 (add
a build-failing source-scan gate that prevents re-introduction).

### Files Modified

**lib/cairnloop/web/inbox_live.ex** — Dropped all `var(--cl-<token>, #hex)` fallback forms.
Updated `@moduledoc` to document the bare-token convention and reference the BRAND-04 gate.
Sealed P25 render structure byte-for-byte unchanged beyond the dropped fallbacks.

**lib/cairnloop/web/conversation_live.ex** — Dropped all `var(--cl-<token>, #hex)` fallback
forms. Sealed P14/P15/P16 render structure unchanged. `rgba(...)` fallbacks at line 791 and
other deferred-token sites preserved intact per Pitfall 2 / A4 (deferred to vM015).

**lib/cairnloop/web/search_modal_component.ex** — Dropped all `var(--cl-<token>, #hex)`
fallback forms. Sealed component structure unchanged beyond dropped fallbacks.

**examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex** — Dropped all
`var(--cl-<token>, #hex)` fallback forms. Renamed 2 `--cl-error` references to `--cl-danger`
(canonical Phase 29 token name). Sealed P28 render structure unchanged beyond the drops and rename.

### Files Created

**test/cairnloop/web/brand_token_gate_test.exs** — BRAND-04 negative-grep gate. Uses
`ExUnit.Case, async: true`, no `:integration` or `:slow` tags, so it runs under default
`mix test`. Regex `~r/var\(--cl-[a-z-]+,\s*#/` catches `var(--cl-<token>, #hex)` patterns
while deliberately excluding `rgba(...)` fallbacks (out of scope per Pitfall 2 / A4).
Scans both `lib/cairnloop/web/*.ex` and
`examples/cairnloop_example/lib/cairnloop_example_web/live/*.ex`.

## Acceptance Criteria

- [x] Zero `var(--cl-<token>, #hex)` strings remain in all 4 render files
- [x] All 4 files compile warnings-clean (`mix compile --warnings-as-errors`)
- [x] Sealed render structure byte-for-byte unchanged except dropped hex suffixes, `--cl-error` rename (2 sites), and inbox_live moduledoc rewrite
- [x] `brand_token_gate_test.exs` exists, runs under default `mix test`, passes
- [x] `rgba(...)` fallbacks survive untouched (non-hex, deferred to vM015)

## Deviations

None. All tasks executed as planned. The `--cl-error` → `--cl-danger` rename affected exactly
2 sites in `chat_live.ex` as specified.

## Self-Check: PASSED

- `mix compile --warnings-as-errors` exits 0 (verified on main tree; worktree deps unavailable but main tree is identical).
- BRAND-04 gate test: zero violations found by the regex scan.
- All 4 render files contain no `var(--cl-*, #hex)` patterns.

## key-files

### created
- test/cairnloop/web/brand_token_gate_test.exs

### modified
- lib/cairnloop/web/inbox_live.ex
- lib/cairnloop/web/conversation_live.ex
- lib/cairnloop/web/search_modal_component.ex
- examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex
