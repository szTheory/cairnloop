---
phase: 48
slug: token-evolution-lock-propagate
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-24
---

# Phase 48 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mix aliases + Playwright E2E alias |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs` |
| **Full suite command** | `mix test && mix test.integration && mix test.e2e` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs`
- **After every plan wave:** Run `mix test && mix test.integration && mix test.e2e`
- **Before `/gsd:verify-work`:** Full suite must be green, or any environment caveat must be documented with command output and regression scope.
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 1 | TOKEN-02 | T-48-01 | Existing `--cl-*` token names remain stable while selected values are applied canonically. | unit/source | `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs` | ❌ W0 | ⬜ pending |
| 48-01-02 | 01 | 1 | TOKEN-03 | T-48-02 | Expressed derivative values match canonical source exactly. | unit/source | `mix test test/cairnloop/web/token_drift_test.exs` | ❌ W0 | ⬜ pending |
| 48-01-03 | 01 | 1 | TOKEN-04 | T-48-03 | Phase 46 contrast rows are recomputed against evolved tokens and failures are closed or documented. | unit/source | `mix test test/cairnloop/web/token_drift_test.exs` | ❌ W0 | ⬜ pending |
| 48-01-04 | 01 | 1 | TOKEN-04 | T-48-04 | Product smoke and browser gates remain green after token propagation. | integration/e2e | `mix test && mix test.integration && mix test.e2e` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/token_drift_test.exs` - covers TOKEN-02 no-renames, TOKEN-03 derivative parity, and TOKEN-04 contrast revalidation.
- [ ] `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` - durable evidence table for Phase 46 baseline rows recomputed against the evolved palette.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Human judgment is limited to accepting documented contrast remediation when a row is classified as decorative or out of scope.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-24
