---
phase: 29
slug: brand-token-css-extraction-d-10-closure
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-27
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) |
| **Config file** | `config/test.exs` (Cairnloop.Repo sandbox, headless Endpoint) |
| **Quick run command** | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~10 seconds (headless; no DB) |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors && mix test test/cairnloop/web/brand_token_gate_test.exs`
- **After every plan wave:** Run `mix test` (full headless suite)
- **Before `/gsd:verify-work`:** Full suite must be green (`mix test` + `mix test.integration` or documented baseline failure)
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | BRAND-01 | — | Canonical `:root` block from cairnloop.css copied verbatim; dark overrides present | smoke | `mix compile --warnings-as-errors` | ✅ `app.css` | ⬜ pending |
| 29-02-01 | 02 | 2 | BRAND-02 | — | Zero hex fallbacks in `lib/cairnloop/web/` | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ❌ Wave 0 | ⬜ pending |
| 29-02-02 | 02 | 2 | BRAND-04 | — | Gate fails on re-introduction of hex fallback | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ❌ Wave 0 | ⬜ pending |
| 29-02-03 | 02 | 2 | BRAND-03 | — | 6 integration assertions pass bare-token form | integration | `mix test.integration test/integration/approval_footer_live_test.exs test/integration/tool_execution_outcome_live_test.exs test/integration/bulk_recovery_live_test.exs` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/brand_token_gate_test.exs` — covers BRAND-02 + BRAND-04 using `File.read!` + `Regex.scan` (project pattern); new file (Wave 0 for Plan 02)
- Existing test infrastructure: ExUnit + `mix test` fully functional — no framework install needed

*All other phase behaviors use existing infrastructure.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Brand-correct rendering in example app | BRAND-02 | Requires running `mix assets.build` + Phoenix server | Open `/inbox` and `/chat` pages; verify colors render correctly (no fallback gray/default) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (`brand_token_gate_test.exs` — created in Plan 02 Task 1)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27
