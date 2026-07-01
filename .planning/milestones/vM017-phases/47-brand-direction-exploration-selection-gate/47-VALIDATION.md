---
phase: 47
slug: brand-direction-exploration-selection-gate
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-24
---

# Phase 47 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix; static HTML/SVG source checks; optional browser console/render check |
| **Config file** | `mix.exs` aliases; no new package or server dependency for this phase |
| **Quick run command** | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~60 seconds for the focused command; full suite depends on existing Repo availability |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/brand_token_gate_test.exs` and the relevant static `rg` checks for `logo/_contest/direction-boards.html`.
- **After every plan wave:** Run `mix compile --warnings-as-errors`; run `mix test` if the wave touches anything outside static contest assets and phase docs.
- **Before `/gsd:verify-work`:** `logo/_contest/direction-boards.html` exists, static checks pass, browser/file-open check is recorded, and phase docs record the locked owner selection.
- **Max feedback latency:** 90 seconds for focused validation in this static-artifact phase.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 0 | LOGO-01 | T-47-01 | SVG/HTML uses no external resources, scripts, raster embeds, or full-canvas cages | static | `test -f logo/_contest/direction-boards.html && ! rg -n 'https?://|cdn\\.|<script|<image|xlink:href|data:' logo/_contest` | no W0 | pending |
| 47-01-02 | 01 | 1 | LOGO-01 | T-47-01 | Four hand-authored SVG directions exist with transparent mark backgrounds | static + review | `rg -n 'Direction A|Direction B|Direction C|Direction D|viewBox|xmlns' logo/_contest/direction-boards.html` | no W0 | pending |
| 47-01-03 | 01 | 1 | LOGO-02 | T-47-02 | Board renders all required proof sizes, lockups, surfaces, and no-cage rows | static + browser | `rg -n '16px|24px|48px|256px|horizontal|vertical|light|dark|no-cage' logo/_contest/direction-boards.html` | no W0 | pending |
| 47-01-04 | 01 | 1 | LOGO-03 | - | Locked owner selection and rationale are durably recorded | doc check | `rg -n 'C3\\.6|crowning-loop|Refined|current type stack|owner-selected' .planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md .planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md logo/_contest/direction-boards.html` | partial W0 | pending |
| 47-01-05 | 01 | 1 | TOKEN-01 | T-47-02 | Palette/type variants are shown as preview choices without mutating canonical tokens | static + diff | `rg -n 'Refined|Conservative|Bolder|Atkinson|Fraunces|Martian Mono|Preview only: canonical tokens change in Phase 48' logo/_contest/direction-boards.html && git diff --name-only -- priv/static/cairnloop.css examples/cairnloop_example/assets/css/app.css prompts/cairnloop.tokens.json` | no W0 | pending |

---

## Wave 0 Requirements

- [ ] `logo/_contest/direction-boards.html` - create the static board artifact that covers LOGO-01, LOGO-02, LOGO-03, and TOKEN-01.
- [ ] `logo/_contest/` source hygiene - no external URLs, scripts, raster embeds, data payloads, or SVG background cages.
- [ ] Static proof checks - include plan tasks that run the exact `rg` commands above after the artifact exists.
- [ ] Browser/file-open check - record that the board opens from `file://` with no failed network requests or console errors.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Owner selection is accepted as the gate outcome | LOGO-03, TOKEN-01 | Subjective selection was already made by the owner during discussion and must not be automated | Confirm `47-DISCUSSION-LOG.md`, `47-CONTEXT.md`, and the board all name C3.6, Refined palette, and current type stack as selected |
| Four directions are genuinely distinct and hand-authored | LOGO-01 | Distinctiveness and brand fit are partly visual judgments | Inspect the board at 16/24/48/256px on light and dark surfaces; verify C3.6 is marked selected and the integrated typemark is marked explored/rejected |

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency < 90s for focused validation.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-24
