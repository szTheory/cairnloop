---
phase: 43
slug: responsive-desktop-first-cockpit-d3
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
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
- **Before `/gsd:verify-work`:** Full suite must be green AND manual 768px viewport verification complete.
- **Max feedback latency:** ~2 seconds for the CSS/markup scans.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 43-01-* | 01 | 1 | RESP-01 | — | No `max-width` width media conditions remain in cairnloop.css | unit (CSS file scan) | `mix test test/cairnloop/web/cairnloop_css_test.exs` | ✅ extend existing | ⬜ pending |
| 43-01-* | 01 | 1 | RESP-01 | — | Breakpoints 640/768/1024 present as literal constants in one comment block | unit (CSS file scan) | same | ✅ extend | ⬜ pending |
| 43-01-* | 01 | 1 | RESP-01 | — | No `var()` inside any `@media` condition | unit (CSS file scan) | same | ✅ extend | ⬜ pending |
| 43-02-* | 02 | 2 | RESP-02 | — | Each `.cl-table` wrapped w/ `role="region"`/`tabindex="0"`/`aria-label` | unit (source `.ex` scan, Repo-free) | `mix test test/cairnloop/web/cairnloop_css_test.exs` (or new `responsive_markup_test.exs`) | ❌ W0 (recommended new test) | ⬜ pending |
| 43-02-* | 02 | 2 | RESP-02 | — | Conversation layout: stacked base + `min-width:1024` two-column row | unit (CSS file scan) | assert `.conversation-layout` base column + `min-width:1024` | ✅ extend | ⬜ pending |
| 43-03-* | 03 | 2 | RESP-02 | — | Tap targets ≥44px on bulk-bar controls + both raw checkboxes | unit (CSS scan + markup) | assert `.cl-button--lg`/`min-height:44px`; assert checkbox sizing class | ❌ W0 | ⬜ pending |
| 43-03-* | 03 | 2 | RESP-02 | — | Bulk-bar wraps (`.cl-row--wrap`) + clears last row | **manual / visual** | screenshot pipeline or manual 768px resize | human-needed | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/cairnloop_css_test.exs` — extend with RESP-01 CSS-presence cases (no `max-width` width media conditions, three literal breakpoints documented, no `var()` in `@media`) and the conversation stacked-base + `min-width:1024` assertion. Reuse the existing `setup_all` CSS read.
- [ ] `test/cairnloop/web/responsive_markup_test.exs` (or extend an existing source-scan test) — assert all four `.cl-table` render files (`audit_log_live.ex`, `settings_live.ex`, `knowledge_base_live/index.ex`, `knowledge_base_live/suggestion_review.ex`) carry the `cl-table-scroll` wrapper with `role="region"`/`tabindex="0"`/`aria-label`; assert bulk-bar tap-target sizing. Mirror the `brand_token_gate_test.exs` `File.read!` source-scan approach (Repo-free).
- [ ] No framework install needed — ExUnit + Phoenix.LiveViewTest already present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sticky bulk-bar clears / does not occlude the last inbox row | RESP-02 | Scroll-occlusion is a rendered-geometry behavior; no current bottom clearance exists (no `padding-bottom` on the inbox list) — only a real viewport shows the fix | Resize Inbox to 768px width, select rows to show the bulk-bar, scroll to the bottom; confirm the last row is fully reachable above the sticky bar |
| No visual regression from the two `max-width:640` → `min-width` conversions | RESP-01 | Behavioral equivalence of the converted media queries is best confirmed visually | At 768px and ~600px widths, confirm `.cl-main` padding and `.cl-nav` layout match pre-conversion behavior |
| Inbox table scrolls accessibly + conversation rail stacks below header at 768px | RESP-02 | Tablet-viewport layout is a rendered behavior | At 768px: Inbox table scrolls horizontally inside its `role="region"` wrapper; conversation evidence-rail stacks below the conversation header |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies (manual items explicitly enumerated above)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (the two new/extended test files)
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s for CSS/markup scans
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
