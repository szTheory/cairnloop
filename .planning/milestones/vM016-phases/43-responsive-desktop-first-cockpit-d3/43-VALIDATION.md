---
phase: 43
slug: responsive-desktop-first-cockpit-d3
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
audited: 2026-06-26
---

# Phase 43 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) + Phoenix.LiveViewTest |
| **Config file** | `test/test_helper.exs` (standard) |
| **Quick run command** | `mix test test/cairnloop/web/cairnloop_css_test.exs` (CSS-presence + markup scans — DB-free, sub-second) |
| **Full suite command** | `mix test` (excludes `:integration`; includes hardened brand-token gate) |
| **Estimated runtime** | ~30–90 seconds (headless lib suite) |

> **REPO-UNAVAILABLE caveat:** `Cairnloop.Repo` may be unavailable in this workspace. This is a
> CSS + markup-attribute phase with NO DB reads — all automated validation is a file/source scan
> (`File.read!` of `priv/static/cairnloop.css` and the four `.cl-table` render `.ex` files) or a
> pure `render/1` assertion. No Postgres round-trip is required for any RESP-01/RESP-02 check.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/cairnloop_css_test.exs` (+ any new `responsive_markup_test.exs`) — sub-second, DB-free.
- **After every plan wave:** Run `mix compile --warnings-as-errors` + `mix test` (incl. brand-token gate).
- **Before `/gsd:verify-work`:** Full suite green AND the gated `e2e` lane green (`inbox_geometry_test.exs` — automated 768px rendered-geometry; no manual step).
- **Max feedback latency:** ~2 seconds for the CSS/markup scans; the geometry E2E runs in the gated CI `e2e` lane.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 43-01-* | 01 | 1 | RESP-01 | — | No `max-width` width media conditions remain in cairnloop.css | unit (CSS file scan) | `mix test test/cairnloop/web/cairnloop_css_test.exs` | ✅ extend existing | ⬜ pending |
| 43-01-* | 01 | 1 | RESP-01 | — | Breakpoints 640/768/1024 present as literal constants in one comment block | unit (CSS file scan) | same | ✅ extend | ⬜ pending |
| 43-01-* | 01 | 1 | RESP-01 | — | No `var()` inside any `@media` condition | unit (CSS file scan) | same | ✅ extend | ⬜ pending |
| 43-02-* | 02 | 2 | RESP-02 | — | Each `.cl-table` wrapped w/ `role="region"`/`tabindex="0"`/`aria-label` | unit (source `.ex` scan, Repo-free) | `mix test test/cairnloop/web/cairnloop_css_test.exs` (or new `responsive_markup_test.exs`) | ❌ W0 (recommended new test) | ⬜ pending |
| 43-02-* | 02 | 2 | RESP-02 | — | Conversation layout: stacked base + `min-width:1024` two-column row | unit (CSS file scan) | assert `.conversation-layout` base column + `min-width:1024` | ✅ extend | ⬜ pending |
| 43-03-* | 03 | 3 | RESP-02 | — | Tap targets ≥44px on bulk-bar controls + both raw checkboxes | unit (CSS scan + markup) + browser E2E (rendered geometry) | `mix test test/cairnloop/web/responsive_markup_test.exs`; `mix test.e2e` (`inbox_geometry_test.exs`) | ✅ both | ⬜ pending |
| 43-03-* | 03 | 3 | RESP-02 | — | Bulk-bar clears last row (no sticky occlusion) at 768px | **browser E2E (was manual)** | `mix test.e2e` — `inbox_geometry_test.exs` scrolls to bottom, asserts last-row bottom ≤ bulk-bar top | ✅ gated CI e2e lane | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/cairnloop_css_test.exs` — extend with RESP-01 CSS-presence cases (no `max-width` width media conditions, three literal breakpoints documented, no `var()` in `@media`) and the conversation stacked-base + `min-width:1024` assertion. Reuse the existing `setup_all` CSS read.
- [ ] `test/cairnloop/web/responsive_markup_test.exs` (or extend an existing source-scan test) — assert all four `.cl-table` render files (`audit_log_live.ex`, `settings_live.ex`, `knowledge_base_live/index.ex`, `knowledge_base_live/suggestion_review.ex`) carry the `cl-table-scroll` wrapper with `role="region"`/`tabindex="0"`/`aria-label`; assert bulk-bar tap-target sizing. Mirror the `brand_token_gate_test.exs` `File.read!` source-scan approach (Repo-free).
- [ ] No framework install needed — ExUnit + Phoenix.LiveViewTest already present.

---

## Rendered-Geometry Verifications — AUTOMATED (formerly Manual-Only)

> **Zero human UAT.** The three rendered-geometry behaviors below were originally flagged
> manual-only. Per the owner's "automate the world / shift-left onto CI" directive, they are now
> measured by a gated Playwright E2E at a 768px viewport
> (`examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`, via the `evaluate/3`
> `getBoundingClientRect()`/`getComputedStyle()` bridge) — the same pattern Phases 41/42 used. The
> CI `e2e` job is a required `release_gate` check and `mix test.e2e` auto-discovers the file, so
> these run on every push with no human in the loop. (Local run is blocked only by this workspace's
> Postgres lacking the pgvector extension; CI uses `pgvector/pgvector:pg16`.)

| Behavior | Requirement | Automated By | Assertion |
|----------|-------------|--------------|-----------|
| Sticky bulk-bar clears / does not occlude the last inbox row | RESP-02 | `inbox_geometry_test.exs` (E2E) | Select all, scroll to bottom; assert last `li` bottom ≤ `.cl-inbox-bulk-bar` top (also catches a future `position: fixed` regression) |
| Tap targets ≥44×44px (checkboxes + bulk-bar buttons) | RESP-02 | `inbox_geometry_test.exs` (E2E) | `getBoundingClientRect()` width/height ≥ 44 on both `.cl-checkbox` and both `.cl-button--lg` |
| No visual regression from the `max-width:640` → `min-width` conversions | RESP-01 | `inbox_geometry_test.exs` (E2E) | `.cl-main` computed `padding-left` ≥ 24px at 768px (min-width rule fired) + `.cl-nav__link` renders |

> **Note:** Inbox horizontal table scroll + conversation rail stacking below 1024 are pinned by the
> Plan 02 source-scan (`responsive_markup_test.exs`) and the CSS-scan (`cairnloop_css_test.exs`);
> the geometry E2E above covers the inbox-specific tap-target and occlusion facts.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (manual items explicitly enumerated above)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (the two new/extended test files)
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s for CSS/markup scans
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

## Validation Audit 2026-06-26

Post-execution closeout reconciled this draft strategy against `43-VERIFICATION.md` and Phase 45's
final sweep.

| Metric | Count |
|--------|-------|
| Requirements audited | 2 (RESP-01, RESP-02) |
| Observable truths verified | 11/11 |
| Blocking validation gaps | 0 |
| Rendered-geometry checks | Automated via gated Playwright E2E |

**Evidence:** `43-VERIFICATION.md` records mobile-first breakpoint normalization, accessible table
scroll wrappers, conversation stacking, tap targets, bulk-bar clearance, and geometry E2E wiring.
Phase 45 later records the full root suite, integration lane, example E2E, and screenshot capture all
passing.

**Verdict:** NYQUIST-COMPLIANT. The unchecked planning boxes above are historical draft-plan state;
the shipped phase has automated coverage for all responsive requirements.
