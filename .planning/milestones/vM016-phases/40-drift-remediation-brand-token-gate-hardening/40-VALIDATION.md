---
phase: 40
slug: drift-remediation-brand-token-gate-hardening
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
audited: 2026-06-26
---

# Phase 40 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `40-RESEARCH.md` § Validation Architecture (Nyquist).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5) + Credo 1.7.18 |
| **Config file** | `test/test_helper.exs`, `.credo.exs` |
| **Quick run command** | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| **Full suite command** | `mix test` then `mix credo --strict` |
| **Estimated runtime** | ~5s gate test; full suite per baseline |

> `Cairnloop.Repo` may be unavailable in this workspace. The brand-token gate is a
> pure `File.read!` + per-line regex ExUnit test (no DB) — keep it that way.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/brand_token_gate_test.exs`
- **After every plan wave:** Run `mix test` + `mix compile --warnings-as-errors`
- **Before `/gsd:verify-work`:** Full suite green + `mix credo --strict` clean
- **Max feedback latency:** ~5 seconds (gate test)

---

## Per-Task Verification Map

> Task IDs assigned by the planner. Each remediation/gate task maps to a requirement
> and an automated command below. Filled to concrete task IDs post-planning.

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| 40-NN-NN | TBD | TBD | DRIFT-01 | N/A | grep/gate | `grep -rnE '#[0-9a-fA-F]{3,6}\|rgba\(\|hsl\(' lib/cairnloop/web/conversation_live.ex lib/cairnloop/web/search_modal_component.ex` → empty | ⬜ pending |
| 40-NN-NN | TBD | TBD | DRIFT-02 | N/A | grep/compile | footer region has no color-literal `style=`; `<.cl_button`/`class="cl-textarea"` present; `mix compile --warnings-as-errors` exits 0 | ⬜ pending |
| 40-NN-NN | TBD | TBD | GATE-01 | fail-closed | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` (FAIL-set flagged, PASS-set clean, `# cl-allow-color` suppresses) | ⬜ pending |
| 40-NN-NN | TBD | TBD | GATE-02 | advisory | credo | `mix credo --strict` surfaces `NoHardcodedColor`; does NOT hard-fail CI alone | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/cairnloop/web/brand_token_gate_test.exs` with the two new patterns
      (`style="…#hex…"`, raw `rgba(`/`hsl(`) + helper-hex full-source scan + `# cl-allow-color`
      allowlist + FAIL/PASS string fixtures (GATE-01). **No new test file** (D-04).
- [ ] `lib/cairnloop/credo_checks/no_hardcoded_color.ex` — new custom `Credo.Check` (GATE-02).
- [ ] `.credo.exs` — register the custom check (`requires:` / `checks:` entry), kept advisory (GATE-02).
- [ ] No framework install needed (ExUnit + Credo already present).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Remediated strings respond to theme tokens | DRIFT-01/02 (SC5) | Visual theming cannot be asserted headlessly | Toggle `data-theme="dark"` on the root element (cairnloop.css:160); confirm remediated text/surfaces flip to the dark palette — no string stays light-locked (proves replacements are live `var(--cl-…)` tokens, not off-palette hex). |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (gate test fixtures + Credo check)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

## Validation Audit 2026-06-26

Post-execution closeout reconciled this draft strategy against `40-VERIFICATION.md` and Phase 45's
final sweep.

| Metric | Count |
|--------|-------|
| Requirements audited | 4 (DRIFT-01, DRIFT-02, GATE-01, GATE-02) |
| Observable truths verified | 8/8 |
| Blocking validation gaps | 0 |
| Accepted deviations | 1 (`.credo.exs requires:` removed to avoid module-redefine warning) |

**Evidence:** `40-VERIFICATION.md` records zero off-palette render color drift in the targeted files,
the primitive footer rebuild, the hardened ExUnit gate passing clean and failing on real probes, and
the advisory Credo check firing without a hard exit. Phase 45 later records the full root suite,
integration lane, example E2E, and `mix check` all passing.

**Verdict:** NYQUIST-COMPLIANT. The unchecked planning boxes above are historical draft-plan state;
the shipped phase has automated coverage for all drift and gate requirements.
