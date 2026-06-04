---
phase: 42
slug: cross-screen-threading
status: approved
nyquist_compliant: true
wave_0_complete: true
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
| 42-01-01 | 01 | 1 | THREAD-02/03 | — | N/A | unit | `mix test test/cairnloop/auditor_governance_test.exs` | ❌ W1 (co-created) | ⬜ pending |
| 42-01-02 | 01 | 1 | THREAD-02 | — | nil subject → no dead link | unit (presenter) | `mix test test/cairnloop/web/audit_log_presenter_test.exs` | ❌ W1 (co-created) | ⬜ pending |
| 42-02-01 | 02 | 1 | THREAD-01 | — | N/A | unit (`# REPO-UNAVAILABLE` scoped read) | `mix test test/cairnloop/chat_test.exs` | ❌ W1 (co-created) | ⬜ pending |
| 42-02-02 | 02 | 1 | THREAD-03 | — | absent originating conv → omit link | unit (`# REPO-UNAVAILABLE`) | `mix test test/cairnloop/knowledge_automation_test.exs` | ❌ W1 (co-created) | ⬜ pending |
| 42-03-01 | 03 | 2 | THREAD-03 | T-42-07/08/09 | `?proposal` tamper/IDOR → fail-closed | unit (LiveView render) | `mix test test/cairnloop/web/audit_log_live_test.exs` | ✅ | ⬜ pending |
| 42-03-02 | 03 | 2 | THREAD-02 | T-42-09 | scope-root-relative link, no `/support/` | unit (LiveView render) | `mix test test/cairnloop/web/audit_log_live_test.exs` | ✅ | ⬜ pending |
| 42-04-01 | 04 | 2 | THREAD-01 | — | nil next → "Queue clear", no dead link | unit (LiveView render) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ⬜ pending |
| 42-04-02 | 04 | 2 | THREAD-03 | — | scope-root-relative deep-link | unit (LiveView render) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ⬜ pending |
| 42-05-01 | 05 | 2 | THREAD-03 | — | conversation-origin only → conditional crumb | unit (presenter) | `mix test test/cairnloop/web/breadcrumb_presenter_test.exs` | ✅ | ⬜ pending |
| 42-05-02 | 05 | 2 | THREAD-03 | — | no raw `Repo` in editor LiveView | unit (LiveView render) | `mix test test/cairnloop/web/knowledge_base_live/editor_test.exs` | ✅ | ⬜ pending |
| 42-06-01 | 06 | 3 | THREAD-01/02/03 | — | real browser transition; `/support/support` guard | E2E | `cd examples/cairnloop_example && mix test.e2e test/e2e/thread_navigation_test.exs` | ❌ W3 (co-created) | ⬜ pending |

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
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-04 (plans verified Nyquist-compliant by gsd-plan-checker: 11/11 tasks carry `<automated>` verify, no 3-consecutive-task gap, E2E gate last, Wave-0 test files co-created in their TDD tasks)
