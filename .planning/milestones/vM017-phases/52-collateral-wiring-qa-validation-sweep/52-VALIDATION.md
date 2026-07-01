---
phase: 52
slug: collateral-wiring-qa-validation-sweep
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-26
updated: 2026-06-26T03:48:38Z
---

# Phase 52 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for source/package/SVG/raster guards; PhoenixTest Playwright for browser E2E |
| **Config file** | Root `mix.exs`; example `examples/cairnloop_example/mix.exs`; example `test/test_helper.exs` excludes `:e2e` by default |
| **Quick run command** | `mix test test/cairnloop/web/collateral_wiring_test.exs` |
| **Full suite command** | `mix test && (cd examples/cairnloop_example && PW_TRACE=true mix test.e2e)` |
| **Estimated runtime** | ~120 seconds locally, excluding first Playwright browser install |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/collateral_wiring_test.exs` for static/package/collateral-source changes.
- **After browser wiring tasks:** Run `cd examples/cairnloop_example && mix test.e2e test/e2e/collateral_wiring_test.exs`.
- **After every plan wave:** Run `mix test && (cd examples/cairnloop_example && PW_TRACE=true mix test.e2e)`.
- **Before `/gsd:verify-work`:** Full suite, package unpack proof, SVG lint, raster budget, and diff-scope evidence must be green.
- **Max feedback latency:** 180 seconds for the focused static + E2E checks once dependencies are installed.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 52-01-01 | 01 | 1 | WIRE-02 | T-52-04 / T-52-05 | README uses approved local SVG path and no old emoji identity | source | `mix test test/cairnloop/web/collateral_wiring_test.exs` | yes | green |
| 52-01-02 | 01 | 1 | HYGIENE-01 | T-52-01 / T-52-02 | Tracked SVGs are valid XML with safe local-only references | source/tool | `mix test test/cairnloop/web/collateral_wiring_test.exs && xmllint --noout $(git ls-files '*.svg')` | yes | green |
| 52-01-03 | 01 | 1 | HYGIENE-02 | T-52-03 / T-52-05 | Raster set stays limited to favicon and OG assets under the 150KB budget | source/tool | `mix test test/cairnloop/web/collateral_wiring_test.exs && du -ck logo/*.png logo/*.ico examples/cairnloop_example/priv/static/favicon.ico examples/cairnloop_example/priv/static/images/cairnloop-og.png` | yes | green |
| 52-01-04 | 01 | 1 | HYGIENE-03 | T-52-06 | Hex package excludes `brandbook/`, `logo/`, and `scripts/` | source/package | `mix test test/cairnloop/web/collateral_wiring_test.exs && mix hex.build --unpack` | yes | green |
| 52-02-01 | 02 | 1 | WIRE-01 | T-52-04 / T-52-05 | Example app serves only approved local static logo, favicon, and OG assets | source/e2e | `cd examples/cairnloop_example && mix test.e2e test/e2e/collateral_wiring_test.exs` | yes | green |
| 52-02-02 | 02 | 1 | WIRE-03 | T-52-03 / T-52-05 | Browser proves visible logo dimensions, favicon links, OG metadata, successful asset fetches, and no collateral-caused browser failures | e2e | `cd examples/cairnloop_example && PW_TRACE=true mix test.e2e test/e2e/collateral_wiring_test.exs` | yes | green |
| 52-03-01 | 03 | 2 | HYGIENE-03 | T-52-06 | Final gate records full suite, package, raster, SVG, and diff-scope evidence before closeout | integration/tool | `mix test && (cd examples/cairnloop_example && PW_TRACE=true mix test.e2e) && mix hex.build --unpack && git diff --stat` | yes | green |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [x] `test/cairnloop/web/collateral_wiring_test.exs` - DB-free source/package/SVG/raster guard covering WIRE-01, WIRE-02, HYGIENE-01, HYGIENE-02, and HYGIENE-03.
- [x] `examples/cairnloop_example/test/e2e/collateral_wiring_test.exs` - browser collateral proof covering WIRE-01 and WIRE-03.
- [x] `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex` - minimal logo semantics update so E2E can assert `alt="Cairnloop"`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Logo-family subjective sign-off before wiring | WIRE-01, WIRE-02 | The owner approval gate is subjective, but it must already be recorded or recorded before the first collateral edit. | Confirm sign-off artifact/status exists in phase context or summary before editing README/example assets. |

All implementation behavior after sign-off must be automated; do not add human-rendered verification tasks for logo, favicon, metadata, package hygiene, or diff scope.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing validation files.
- [x] No watch-mode flags.
- [x] Feedback latency target is below 180 seconds after dependencies are installed.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** verified 2026-06-26

## Validation Audit 2026-06-26

| Metric | Count |
|--------|-------|
| Requirements checked | 6 |
| Task verification rows | 7 |
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All Phase 52 requirements have automated verification: the focused collateral guard, focused contrast guard, full root suite, full example E2E lane, SVG lint, raster budget, ImageMagick identification, Hex unpack proof, and diff-scope evidence are recorded in `52-QA-REPORT.md` and summarized in `52-VERIFICATION.md`.
