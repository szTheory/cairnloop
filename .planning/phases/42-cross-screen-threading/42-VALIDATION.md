---
phase: 42
slug: cross-screen-threading
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 42 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Phoenix.LiveViewTest; phoenix_test_playwright for E2E |
| **Config file** | `test/test_helper.exs` (lib) · `examples/cairnloop_example/test/` (E2E) |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix test && mix test.integration` |
| **E2E command** | `mix test.e2e` (gated CI lane; example app) |
| **Estimated runtime** | ~30–90 seconds (headless lib suite) |

> **REPO-UNAVAILABLE caveat:** `Cairnloop.Repo` may be unavailable in this workspace. Prefer
> headless `render/1`-with-built-assigns + presenter/total-function tests (no DB). Behaviors that
> genuinely need a Postgres round-trip (the FK join resolving audit-row→conversation, scoped
> `next_open_conversation/1` reads) are written but marked `# REPO-UNAVAILABLE` and run under
> `mix test.integration` / CI.

---

## Sampling Rate

- **After every task commit:** Run `mix test` (headless lib suite)
- **After every plan wave:** Run `mix test && mix compile --warnings-as-errors`
- **Before `/gsd:verify-work`:** Full suite (`mix test` + `mix test.integration`) must be green
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _populated by planner per task_ | | | | | | | `mix test` | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing ExUnit + Phoenix.LiveViewTest infrastructure covers all phase requirements; no new
  framework install needed. E2E spec(s) live under `examples/cairnloop_example/test/e2e/`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Actual browser navigation transition (JS-driven `<.link navigate>`) | THREAD-01/02/03 | `Phoenix.LiveViewTest` cannot exercise the real JS navigation; a thin E2E spec covers it | Run `mix test.e2e` in example app; assert URL + landing-view assertions per thread |

*Headless tests cover link rendering, param tolerance, and fail-closed absence; only the live JS transition is E2E/manual.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
