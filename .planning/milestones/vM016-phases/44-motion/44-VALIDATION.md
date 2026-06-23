---
phase: 44
slug: motion
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-05
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
| MOTION-01 | New motion rules use only `transform`/`opacity` — no `width`/`height`/`top`/`left`/`max-height`/`max-width` transitions | unit (CSS string scan) | `mix test test/cairnloop/web/motion_css_test.exs` | ❌ W0 |
| MOTION-01 | New `.cl-motion-*`/`.cl-toast`/keyframe rules mirrored across both stylesheets | unit (string parity scan) | same file | ❌ W0 |
| MOTION-01 | Hero count entrance present, duration < 180ms; count text node has no `transition-property` | E2E (`getComputedStyle`) | `mix test.e2e` (motion_test.exs) | ❌ W0 |
| MOTION-01 | Stagger applies to ≤5 `<li>`; rail/drawer reveal transform/opacity only | E2E (computed `animation-name`, `transition-property`) | motion_test.exs | ❌ W0 |
| MOTION-01 (negative) | Reply-send + ⌘K open carry NO new `cl-motion-*` class / no new entrance | E2E (assert absence) + unit grep | motion_test.exs | ❌ W0 |
| MOTION-02 | `prefers-reduced-motion: reduce`: transform animations → ~0.01ms; `.cl-motion-state` stays 120ms | E2E (`emulateMedia` + computed durations) | motion_test.exs | ❌ W0 |
| Criterion 4 | New `cl_flash/1` (`.ex`) is hex-free (brand gate auto-covers new `.ex`) | unit | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ exists |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Negative assertions check absence of NEW `cl-motion-*` classes, NOT zero transitions — `.cl-button`/`.cl-input` carry pre-existing universal micro-affordances.*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/motion_css_test.exs` — DB-free pure-`File.read!` string scan (model on `brand_token_gate_test.exs`):
  - (a) no new motion rule contains a forbidden layout property;
  - (b) new `@keyframes` / `.cl-motion-*` / `.cl-toast` blocks exist in BOTH `priv/static/cairnloop.css` and `examples/cairnloop_example/priv/static/assets/css/app.css` (mirror parity);
  - (c) `.cl-hero__count` / `.cl-stat__count` rules contain no `transition-property`.
- [ ] `examples/cairnloop_example/test/e2e/motion_test.exs` — `@moduletag :e2e`, `use PhoenixTest.Playwright.Case`; model header/fixtures on `rail_disclosure_test.exs`. Assert hero entrance `animation-name` + duration; rail/drawer reveal transform/opacity only; reply-send has no `cl-motion-*` class; `emulateMedia` reduced-motion → transforms ~0, `.cl-motion-state` = 120ms.
- [ ] No framework install needed — ExUnit + Playwright lane already present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `message-status-chip` renders distinct text per state (not color-alone, §7.5) | MOTION-01 / brand §7.5 | Visual/semantic check the gate can't assert | Inspect chip in pending/sent/failed states; confirm label text differs, not just color |

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
