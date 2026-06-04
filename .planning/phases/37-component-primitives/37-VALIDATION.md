---
phase: 37
slug: component-primitives
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-03
validated: 2026-06-03
---

# Phase 37 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `37-RESEARCH.md` → Validation Architecture. All P37 tests are **Repo-free**
> (pure `Phoenix.Component` render tests) — no `# REPO-UNAVAILABLE` markers needed (D-12).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (bundled) + `Phoenix.LiveViewTest` (LiveView 1.1.30) |
| **Config file** | `test/test_helper.exs` (`ExUnit.start(exclude: [:integration])`) |
| **Quick run command** | `mix test test/cairnloop/web/components_test.exs` |
| **Full suite command** | `mix test` (fast headless suite; `:integration` excluded by default) |
| **Compile gate** | `mix compile --warnings-as-errors` (mandatory per CLAUDE.md, SC-5) |
| **Estimated runtime** | ~5–15 seconds (headless render tests, no DB) |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors && mix test test/cairnloop/web/components_test.exs test/cairnloop/web/brand_token_gate_test.exs`
- **After every plan wave:** Run `mix test` (full fast suite) + `mix compile --warnings-as-errors`
- **Before `/gsd:verify-work`:** Full `mix test` green (incl. brand-token gate) + warnings-clean build
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

> Row granularity is per-requirement (plans not yet split into tasks at validation-strategy time).
> The planner refines `<automated>` verify blocks per task; every task maps to one of these requirements.

| Req | Behavior | Test Type | Automated Command | Threat Ref | File Exists | Status |
|-----|----------|-----------|-------------------|------------|-------------|--------|
| UIC-01 | `cl_page` renders title/subtitle + `:wide`/`:reading` width class + `:actions`/`:breadcrumb`/`:subnav` slots | unit (render) | `mix test test/cairnloop/web/components_test.exs` | — | ✅ components_test.exs:147,162 | ✅ green |
| UIC-02 | `cl_stat` accepts only `count :integer`; `cl_hero` renders copper count + `:detail` slot at ~2–3× weight | compile + unit (render) | `mix compile --warnings-as-errors && mix test test/cairnloop/web/components_test.exs` | — | ✅ components_test.exs:211,226 | ✅ green |
| UIC-03 | `cl_disclosure` emits `<details class="cl-details …" id=… phx-update="ignore">` with static `open` (no server assign) | unit (structural marker) | `mix test test/cairnloop/web/components_test.exs` | — | ✅ components_test.exs:260-299 | ✅ green |
| UIC-04 | `cl_fact_list`/`cl_source_card`/`cl_status_cell`/`cl_switch` render with no `#hex`; switch has `role="switch"` + string `aria-checked`; source-card has `<svg`; status-cell + switch carry visible labels | unit (render + refute-hex) | `mix test test/cairnloop/web/components_test.exs` | V5 output-enc | ✅ components_test.exs (refute-hex per test) | ✅ green |
| UIC-05 | 3 layout tokens + 3 inert utilities + `.cl-table-scroll` defined in `cairnloop.css`; all 4 `.cl-table` call sites wrapped with `role="region"` + `tabindex="0"` | CSS-presence + render-marker | `mix test test/cairnloop/web/cairnloop_css_test.exs` | — | ✅ cairnloop_css_test.exs (11 tests) | ✅ green |
| D-13 | New components pass the existing brand-token gate unchanged | gate test (existing) | `mix test test/cairnloop/web/brand_token_gate_test.exs` | V5 output-enc | ✅ exists | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Validation Levels (what is validated, at what level)

| Invariant | Level | Mechanism |
|-----------|-------|-----------|
| **Token-purity** (no `#hex` in rendered HTML) | headless render test | `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` per primitive |
| **No hex-fallback in `.ex`** | existing gate test | `brand_token_gate_test.exs` (D-13) |
| **Patch-safety invariant** (disclosure) | headless render test (structural proxy) | `assert html =~ ~s(phx-update="ignore")` + assert a stable `id=` is present |
| **`role="switch"` + string `aria-checked`** | headless render test | `assert html =~ ~s(role="switch")` and `assert html =~ ~s(aria-checked="false")` |
| **never-color-alone** (switch/status-cell/source-card) | headless render test | assert visible label text present; assert `<svg` present (source-card icon) |
| **`.cl-table-scroll` a11y** (region/tabindex/aria-label) | render-marker test at call sites | `assert html =~ ~s(role="region")` + `tabindex="0"` |
| **Warnings-clean build** | compile check | `mix compile --warnings-as-errors` (SC-5) |
| **CSS presence** (3 tokens + 3 utilities + `.cl-table-scroll`) | file-content assertion | optional small ExUnit test reading `priv/static/cairnloop.css` for literal token/class names (recommended so UIC-05's CSS half is machine-verified) |
| **No caller input → `raw/1`** | code review / gate | new primitives render caller text via auto-escaped `{…}`; `raw/1` stays on `cl_icon`'s fixed internal allowlist only |

---

## Wave 0 Requirements

- [x] `test/cairnloop/web/components_test.exs` — **extended** with 31 primitive render tests (token-purity refute on every test).
- [x] `test/cairnloop/web/brand_token_gate_test.exs` — **exists**; runs unchanged (green).
- [x] `test/cairnloop/web/cairnloop_css_test.exs` — **created** (37-01): 11 CSS-presence tests asserting the 3 layout tokens, 3 inert utilities, `.cl-table-scroll`, and primitive class literals. The optional recommendation was adopted — UIC-05's CSS half is now machine-verified, not manual.
- [x] Framework install: none — ExUnit + `Phoenix.LiveViewTest` already present.

*No framework gaps. The recommended CSS-presence test was built; Wave 0 complete.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `cl_hero` count renders at visually ~2–3× a standard `cl_stat` | UIC-02 / SC-2 | Visual weight is a CSS-typography target, not a structural assertion | Render a `cl_hero` and a `cl_stat` side-by-side; confirm `.cl-hero` count typography is visibly ~2–3× the `.cl-stat__count` weight |
| `:wide` vs `:reading` produce *visibly different* inner framing | UIC-01 / SC-1 | Pixel framing is a visual judgment; tests assert the class/token, not the rendered width | Render `cl_page` in both widths; confirm distinct inner `max-width` framing via the layout tokens (1200px vs 352px per verification) |

*UIC-05's CSS half is now automated via `cairnloop_css_test.exs` — only the two visual-weight/framing judgments above remain manual.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — infrastructure existed; CSS test added)
- [x] No watch-mode flags
- [x] Feedback latency < 15s (suite runs in ~0.1s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ✅ NYQUIST-COMPLIANT (validated 2026-06-03)

---

## Validation Audit 2026-06-03

State A audit of the post-execution phase. Draft strategy reconciled against shipped artifacts and a live test run.

| Metric | Count |
|--------|-------|
| Requirements audited | 6 (UIC-01..05 + D-13) |
| COVERED (automated, green) | 6 |
| PARTIAL | 0 |
| MISSING / gaps found | 0 |
| Gaps resolved | 0 (none to resolve) |
| Escalated to manual-only | 0 |
| Manual-only (pre-existing, visual) | 2 (cl_hero weight, page-width framing) |

**Live run:** `mix test components_test.exs cairnloop_css_test.exs brand_token_gate_test.exs` → **43 tests, 0 failures** (~0.1s). No auditor spawn needed — zero gaps. The draft's "optional" CSS-presence test was adopted as `cairnloop_css_test.exs`, moving UIC-05's CSS half from manual to automated.
