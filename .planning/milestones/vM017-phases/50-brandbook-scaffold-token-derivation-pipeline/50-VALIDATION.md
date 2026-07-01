---
phase: 50
slug: brandbook-scaffold-token-derivation-pipeline
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-25
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for source/drift checks; Playwright 1.60.0 for file-url browser proof |
| **Config file** | `mix.exs`; existing Playwright dependency under `examples/cairnloop_example/assets/package-lock.json` |
| **Quick run command** | `mix run scripts/derive_brandbook_tokens.exs --check && mix test test/cairnloop/web/brandbook_scaffold_test.exs` |
| **Full suite command** | `mix compile --warnings-as-errors && mix test && node scripts/verify_brandbook_file_load.mjs` |
| **Estimated runtime** | ~60-120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix run scripts/derive_brandbook_tokens.exs --check` once the derivation script exists, plus the focused source guards for any touched `brandbook/` files.
- **After every plan wave:** Run `mix compile --warnings-as-errors && mix test` and the file-url browser proof.
- **Before `/gsd:verify-work`:** Full suite and `node scripts/verify_brandbook_file_load.mjs` must be green.
- **Max feedback latency:** 120 seconds for focused checks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 0 | BOOK-02 | T-50-01 | Token outputs cannot drift from canonical CSS silently | source/unit | `mix run scripts/derive_brandbook_tokens.exs --check` | ❌ W0 | ⬜ pending |
| 50-01-02 | 01 | 0 | BOOK-01 | T-50-02 | Local scaffold cannot load remote assets or leak network requests | browser | `node scripts/verify_brandbook_file_load.mjs` | ❌ W0 | ⬜ pending |
| 50-01-03 | 01 | 0 | BOOK-01, BOOK-02 | T-50-03 | Brandbook remains git-tracked collateral, not a shipped package surface | source | `mix test test/cairnloop/web/brandbook_scaffold_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/derive_brandbook_tokens.exs` — generator/checker for `brandbook/assets/css/tokens.css` and `brandbook/color/swatches.json`.
- [ ] `scripts/verify_brandbook_file_load.mjs` — Playwright file-url proof with console, page error, request, and requestfailed collection.
- [ ] `test/cairnloop/web/brandbook_scaffold_test.exs` — pure source/layout/package guard for required files, forbidden URLs, token provenance, and `mix.exs` package exclusion.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | BOOK-01, BOOK-02 | All phase behaviors have automated verification. | N/A |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 120s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-25
