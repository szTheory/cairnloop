---
phase: 51
slug: full-html-brand-book-assembly
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-25
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for DB-free source/content checks; Playwright 1.60.0 for file-url browser proof |
| **Config file** | `mix.exs`; existing Playwright dependency under `examples/cairnloop_example/assets/package-lock.json` |
| **Quick run command** | `mix run scripts/derive_brandbook_tokens.exs --check && mix test test/cairnloop/web/brandbook_scaffold_test.exs && node scripts/verify_brandbook_file_load.mjs` |
| **Full suite command** | `mix compile --warnings-as-errors && mix test && node scripts/verify_brandbook_file_load.mjs` |
| **Estimated runtime** | ~60-180 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix run scripts/derive_brandbook_tokens.exs --check && mix test test/cairnloop/web/brandbook_scaffold_test.exs`.
- **After every plan wave:** Run `node scripts/verify_brandbook_file_load.mjs`.
- **Before `/gsd:verify-work`:** Full suite must be green: `mix compile --warnings-as-errors && mix test && node scripts/verify_brandbook_file_load.mjs`.
- **Max feedback latency:** 180 seconds for focused checks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 0 | BOOK-03 | T-51-01 | Required brandbook sections cannot regress to prose-only, missing, or runtime-fetch-dependent content | source/browser | `mix test test/cairnloop/web/brandbook_scaffold_test.exs && node scripts/verify_brandbook_file_load.mjs` | ✅ | ⬜ pending |
| 51-01-02 | 01 | 0 | BOOK-04 | T-51-02 | Logo assets and downloads must remain local, approved, and not redrawn or remote-loaded | source/browser | `mix test test/cairnloop/web/brandbook_scaffold_test.exs && node scripts/verify_brandbook_file_load.mjs` | ✅ | ⬜ pending |
| 51-01-03 | 01 | 0 | BOOK-05 | T-51-03 | Theme, focus, and status indicators must not communicate state by color alone | source/browser | `node scripts/verify_brandbook_file_load.mjs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/brandbook_scaffold_test.exs` — extend for Phase 51 required labels, live section coverage, badge text, logo/download inventory, forbidden dependencies, and package boundary.
- [ ] `scripts/verify_brandbook_file_load.mjs` — extend for theme toggle, focus-visible, responsive geometry, blank-page/clipping sanity, and local asset failure copy.
- [ ] Repo-local assembly/check seam — add or extend deterministic generation/checking for complete `brandbook/index.html`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | BOOK-03, BOOK-04, BOOK-05 | All phase behaviors have automated source or browser verification. | N/A |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 180s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-25
