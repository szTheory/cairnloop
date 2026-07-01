---
phase: 49
slug: chosen-logo-finalization-asset-family
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-25
---

# Phase 49 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5 plus shell asset checks |
| **Config file** | `mix.exs`; no separate asset-lint config exists |
| **Quick run command** | `xmllint --noout logo/*.svg && ! rg -n '(<image|<script|<foreignObject|href="https?:|href="data:|xlink:href|data:image|base64|<metadata|sodipodi:|inkscape:)' logo/*.svg` |
| **Full suite command** | `mix test && xmllint --noout logo/*.svg && ! rg -n '(<image|<script|<foreignObject|href="https?:|href="data:|xlink:href|data:image|base64|<metadata|sodipodi:|inkscape:)' logo/*.svg && magick identify logo/favicon-16.png logo/favicon-32.png logo/favicon.ico logo/cairnloop-og.png && du -ck logo/*.png logo/*.ico` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick SVG hygiene command for touched SVGs.
- **After raster export tasks:** Run `magick identify logo/favicon-16.png logo/favicon-32.png logo/favicon.ico logo/cairnloop-og.png` and `du -ck logo/*.png logo/*.ico`.
- **After every plan wave:** Run the full suite command.
- **Before `/gsd:verify-work`:** Full suite must be green and the raster total from `du -ck` must be <= 150KB.
- **Max feedback latency:** 90 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-01 | TBD | 1 | LOGO-04 | T-49-01 | SVGs contain no embedded raster, scripts, external refs, or editor metadata | static asset | `xmllint --noout logo/*.svg && ! rg -n '(<image|<script|<foreignObject|href="https?:|href="data:|xlink:href|data:image|base64|<metadata|sodipodi:|inkscape:)' logo/*.svg` | W0 | pending |
| 49-01-02 | TBD | 1 | LOGO-04 | T-49-02 | Production lockups avoid live-font drift | static asset | `! rg -n '<text\\b' logo/cairnloop-lockup-*.svg logo/cairnloop-og.svg` | W0 | pending |
| 49-02-01 | TBD | 1 | LOGO-05 | T-49-03 | Favicon and OG raster exports exist with expected dimensions | static asset | `magick identify logo/favicon-16.png logo/favicon-32.png logo/favicon.ico logo/cairnloop-og.png` | W0 | pending |
| 49-02-02 | TBD | 1 | LOGO-05 | T-49-03 | Raster budget stays within milestone cap | static asset | `du -ck logo/*.png logo/*.ico` | W0 | pending |
| 49-03-01 | TBD | 1 | LOGO-06 | T-49-04 | Usage guidance documents clearspace, minimum sizes, approved files, and prohibited misuse | docs/static | `rg -n 'clearspace|minimum|no rectangular cage|no-icon-left|chat bubble|infinity|subtitle' logo/USAGE.md` | W0 | pending |
| 49-04-01 | TBD | 2 | HYGIENE-02 | T-49-05 | Rejected contest artifacts are removed only after final assets exist | repo hygiene | `test ! -e logo/_contest && test -f logo/cairnloop-lockup-horizontal.svg && test -f logo/USAGE.md` | W0 | pending |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

- [ ] `logo/cairnloop-lockup-horizontal.svg`, `logo/cairnloop-lockup-stacked.svg`, `logo/cairnloop-mark.svg`, `logo/cairnloop-lockup-horizontal-mono.svg`, `logo/cairnloop-lockup-horizontal-reverse.svg`, and `logo/cairnloop-lockup-tagline.svg`.
- [ ] `logo/favicon.svg`, `logo/favicon-16.png`, `logo/favicon-32.png`, `logo/favicon.ico`, `logo/cairnloop-og.svg`, and `logo/cairnloop-og.png`.
- [ ] `logo/USAGE.md`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Logo-family sign-off | LOGO-04, LOGO-05, LOGO-06 | Milestone explicitly has a subjective owner sign-off before wiring | Executor records assets and validation evidence; owner review happens before Phase 52 wiring, not as an autonomous Phase 49 task |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing asset references.
- [x] No watch-mode flags.
- [x] Feedback latency < 90s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-25
