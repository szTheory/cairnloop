---
phase: 38
slug: shared-page-shell-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-03
---

# Phase 38 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.x / Phoenix LiveView) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/cairnloop/web/` |
| **Full suite command** | `mix compile --warnings-as-errors && mix test` |
| **Estimated runtime** | ~60–90 seconds (headless render tests; excludes `:integration`) |

> **Repo caveat:** `Cairnloop.Repo` may be unavailable in this workspace. P38 is a render-layer
> migration — every in-scope screen already uses the `Module.render(assigns) |> rendered_to_string()`
> headless pattern (no Repo round-trip). Mark any genuinely Repo-dependent assertion `# REPO-UNAVAILABLE`.

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors` + the touched screen's render test
- **After every plan wave:** Run `mix test test/cairnloop/web/`
- **Before `/gsd:verify-work`:** `mix compile --warnings-as-errors && mix test` must be green
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

> Planner fills one row per task. Every screen-migration task asserts the screen renders inside
> `.cl-page`; the breadcrumb tasks assert ≥2 crumbs + a working back link (href). All headless.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | SHELL-01 | — | N/A (render-layer only) | render | `mix test test/cairnloop/web/` | ❌ W0 | ⬜ pending |
| 38-0X-XX | 0X | X | SHELL-02 | — | origin label humanized (no raw path rendered) | render | `mix test test/cairnloop/web/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Render-test assertions for each migrated screen confirming it renders inside `.cl-page`
      (SHELL-01) — extend existing `*_live_test.exs` / component render tests where present.
- [ ] Breadcrumb render assertions: editor (origin-aware, ≥2 crumbs + href when `return_to` present;
      static fallback otherwise) and suggestion_review (new static lane crumb) — SHELL-02.
- [ ] Negative copy assertion: origin crumb label is humanized ("Conversation"/"Suggestions"), the raw
      `return_to` path is never rendered as crumb text.

*Existing ExUnit infrastructure covers the framework; no new framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Consistent header height / inner content width across all 5+ screens | SHELL-01 (success-criterion 1) | Pixel-consistency is visual; full screenshot baseline acceptance is P45 | Run the screenshot pipeline as a smoke (must execute clean — no baseline diff acceptance in P38); eyeball uniform header/width |

*The ≥2-crumbs + back-link behavior (success-criterion 2) IS automated headlessly — not manual.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
