---
phase: 44
slug: motion
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-05
audited: 2026-06-26
---

# Phase 44 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 44-RESEARCH.md "Validation Architecture". CSS-only motion phase.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (unit / DB-free string scans) + `PhoenixTest.Playwright` (E2E, `@moduletag :e2e`) |
| **Config file** | `mix.exs` aliases (`test`, `test.e2e`, `test.integration`); E2E in `examples/cairnloop_example/test/e2e/` |
| **Quick run command** | `mix test test/cairnloop/web/brand_token_gate_test.exs test/cairnloop/web/motion_css_test.exs` (DB-free) |
| **Full suite command** | `mix test` (excludes `:integration`/`:e2e`), then `mix test.e2e` + `mix test.integration` |
| **Estimated runtime** | quick ~3s · E2E lane ~minutes |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors` + new CSS string-scan unit test + brand-token gate.
- **After every plan wave:** `mix test` (full headless) + `mix test.e2e` (motion_test).
- **Before `/gsd:verify-work`:** Full suite green AND E2E motion lane green.
- **Max feedback latency:** ~5s for the unit/gate layer.

---

## Per-Task Verification Map

| Requirement | Behavior | Test Type | Automated Command | File Exists |
|-------------|----------|-----------|-------------------|-------------|
| MOTION-01 | New motion rules use only `transform`/`opacity` — no `width`/`height`/`top`/`left`/`max-height`/`max-width` transitions | unit (CSS string scan) | `mix test test/cairnloop/web/motion_css_test.exs` | ✅ 2026-06-26 |
| MOTION-01 | Example app imports canonical `priv/static/cairnloop.css` instead of forking motion rules | unit (string scan) | same file | ✅ 2026-06-26 |
| MOTION-01 | Hero count entrance present and count rules have no `transition-property` | source/CSS scan | same file | ✅ 2026-06-26 |
| MOTION-01 | Stagger and state motion resolve in a real browser | E2E (`getComputedStyle`) | `mix test.e2e test/e2e/motion_test.exs` | ✅ 2026-06-26 |
| MOTION-01 (negative) | Reply-send carries NO new `cl-motion-*` class / no new entrance | unit grep | motion_css_test.exs | ✅ 2026-06-26 |
| MOTION-02 | `prefers-reduced-motion: reduce`: transform animations collapse while `.cl-motion-state` remains meaning-bearing | E2E (`reduced_motion: :reduce` + computed durations) | motion_test.exs | ✅ 2026-06-26 |
| Criterion 4 | New `cl_flash/1` (`.ex`) is hex-free (brand gate auto-covers new `.ex`) | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ exists |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Negative assertions check absence of NEW `cl-motion-*` classes, NOT zero transitions — `.cl-button`/`.cl-input` carry pre-existing universal micro-affordances.*

---

## Wave 0 Requirements

- [x] `test/cairnloop/web/motion_css_test.exs` — DB-free pure-`File.read!` string scan (model on `brand_token_gate_test.exs`):
  - (a) no new motion rule contains a forbidden layout property;
  - (b) the example app imports canonical `priv/static/cairnloop.css` instead of forking motion CSS;
  - (c) `.cl-hero__count` / `.cl-stat__count` rules contain no `transition-property`.
- [x] `examples/cairnloop_example/test/e2e/motion_test.exs` — `@moduletag :e2e`, `use PhoenixTest.Playwright.Case`; verifies persistent browser-computed motion styles and reduced-motion behavior.
- [x] No framework install needed — ExUnit + Playwright lane already present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `message-status-chip` renders distinct text per state (not color-alone, §7.5) | MOTION-01 / brand §7.5 | Source/render check | Confirmed by `outbound_status_label/1`: Pending/Sent/Failed |

*Most behaviors have automated verification; the §7.5 label-distinctness check is the one open visual confirm (research A2).*

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (motion_css_test.exs + motion_test.exs)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s (unit layer)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

## Validation Audit 2026-06-26

Post-execution closeout reconciled this draft strategy against `44-VERIFICATION.md` and Phase 45's
final sweep.

| Metric | Count |
|--------|-------|
| Requirements audited | 2 (MOTION-01, MOTION-02) |
| Motion verification commands passing | 8 |
| Blocking validation gaps | 0 |
| Reduced-motion proof | Automated via E2E |

**Evidence:** `44-VERIFICATION.md` records the motion CSS scan, brand-token gate, compile gates,
conversation/inbox/responsive tests, example motion E2E, brandbook scaffold test, and full root
`mix test` passing with 0 failures. Phase 45 later records the full root suite, integration lane,
example E2E, and screenshot capture all passing.

**Verdict:** NYQUIST-COMPLIANT. The unchecked planning boxes above are historical draft-plan state;
the shipped phase has automated coverage for all motion requirements.
