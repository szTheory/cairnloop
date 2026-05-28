---
phase: 29
slug: brand-token-css-extraction-d-10-closure
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
audited: 2026-05-27
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
| 29-01-01 | 01 | 1 | BRAND-01 | — | Canonical `:root` block from cairnloop.css copied verbatim; dark overrides present | smoke | `mix compile --warnings-as-errors` | ✅ `app.css` | ✅ green |
| 29-02-01 | 02 | 2 | BRAND-02 | — | Zero hex fallbacks in `lib/cairnloop/web/` | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ created | ✅ green |
| 29-02-02 | 02 | 2 | BRAND-04 | — | Gate fails on re-introduction of hex fallback | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ created | ✅ green |
| 29-02-03 | 02 | 2 | BRAND-03 | — | 6 integration assertions pass bare-token form | integration | `mix test.integration test/integration/approval_footer_live_test.exs test/integration/tool_execution_outcome_live_test.exs test/integration/bulk_recovery_live_test.exs` | ✅ existing | ⚠️ partial |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky/partial*

> **29-02-03 PARTIAL note:** Assertions re-pinned to bare-token form and compile passes. Full `mix test.integration` requires a live Postgres DB — unavailable in this workspace (REPO-UNAVAILABLE per CLAUDE.md). Added to Manual-Only below. CI integration lane is the authoritative proof.

---

## Wave 0 Requirements

- [x] `test/cairnloop/web/brand_token_gate_test.exs` — created; covers BRAND-02 + BRAND-04 using `File.read!` + `Regex.match?` (project pattern); passes under default `mix test` (no `:integration` tag)
- Existing test infrastructure: ExUnit + `mix test` fully functional — no framework install needed

*All other phase behaviors use existing infrastructure.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Brand-correct rendering in example app | BRAND-02 | Requires running `mix assets.build` + Phoenix server | Open `/inbox` and `/chat` pages; verify colors render correctly (no fallback gray/default) |
| 6 integration assertions pass bare-token form | BRAND-03 | `mix test.integration` requires live Postgres DB (REPO-UNAVAILABLE in dev workspace) | Run `mix test.integration test/integration/approval_footer_live_test.exs test/integration/tool_execution_outcome_live_test.exs test/integration/bulk_recovery_live_test.exs` against a live DB; expect 0 failures. Assertions re-pinned to `"var(--cl-primary)"` and `"var(--cl-danger)"` (with closing paren per Pitfall 8). |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (`brand_token_gate_test.exs` — created in Plan 02 Task 1)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter
- [x] `wave_0_complete: true` updated (gate test created and passes)

**Approval:** approved 2026-05-27

---

## Validation Audit 2026-05-27

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 0 |
| Escalated to manual-only | 1 |

**Audit notes:** All headless tests pass (231 web tests, 0 failures; brand_token_gate_test.exs: 1 test, 0 failures). BRAND-03 integration assertions are correctly re-pinned in test source; `mix test.integration` requires live DB and is escalated to manual-only. Stale frontmatter corrected (`wave_0_complete: false` → `true`). Per-Task Map statuses updated to reflect actual verification outcomes.
