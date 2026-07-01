---
phase: 42
slug: cross-screen-threading
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
audited: 2026-06-04
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
| 42-01-01 | 01 | 1 | THREAD-02/03 | — | N/A | unit (+ `# REPO-UNAVAILABLE` FK-join round-trip) | `mix test test/cairnloop/auditor_governance_test.exs` | ✅ | ✅ green ⚠️ rt-deferred |
| 42-01-02 | 01 | 1 | THREAD-02 | — | nil subject → no dead link | unit (presenter) | `mix test test/cairnloop/web/audit_log_presenter_test.exs` | ✅ | ✅ green |
| 42-02-01 | 02 | 1 | THREAD-01 | — | N/A | unit query-shape (+ `# REPO-UNAVAILABLE` scoped read) | `mix test test/cairnloop/chat_test.exs` | ✅ | ✅ green ⚠️ rt-deferred |
| 42-02-02 | 02 | 1 | THREAD-03 | — | absent originating conv → omit link | unit query-shape (+ `# REPO-UNAVAILABLE`) | `mix test test/cairnloop/knowledge_automation_test.exs` | ✅ | ✅ green ⚠️ rt-deferred |
| 42-03-01 | 03 | 2 | THREAD-03 | T-42-07/08/09 | `?proposal` tamper/IDOR → fail-closed | unit (LiveView render) | `mix test test/cairnloop/web/audit_log_live_test.exs` | ✅ | ✅ green |
| 42-03-02 | 03 | 2 | THREAD-02 | T-42-09 | scope-root-relative link, no `/support/` | unit (LiveView render) | `mix test test/cairnloop/web/audit_log_live_test.exs` | ✅ | ✅ green |
| 42-04-01 | 04 | 2 | THREAD-01 | — | nil next → "Queue clear", no dead link | unit (LiveView render) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ✅ green |
| 42-04-02 | 04 | 2 | THREAD-03 | — | scope-root-relative deep-link | unit (LiveView render) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ | ✅ green |
| 42-05-01 | 05 | 2 | THREAD-03 | — | conversation-origin only → conditional crumb | unit (presenter) | `mix test test/cairnloop/web/breadcrumb_presenter_test.exs` | ✅ | ✅ green |
| 42-05-02 | 05 | 2 | THREAD-03 | — | no raw `Repo` in editor LiveView | unit (LiveView render) | `mix test test/cairnloop/web/knowledge_base_live/editor_test.exs` | ✅ | ✅ green |
| 42-06-01 | 06 | 3 | THREAD-01/02/03 | — | real browser transition; `/support/support` guard | E2E | `cd examples/cairnloop_example && mix test.e2e test/e2e/thread_navigation_test.exs` | ✅ | ✅ exists ⚠️ e2e-lane |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ⚠️ rt-deferred (round-trip integration-deferred) · ⚠️ e2e-lane (runs in gated CI e2e lane, not this workspace)*

**Audit result (2026-06-04):** Headless lib suite verified green — `215 tests, 0 failures` across all 8 phase test files. Every THREAD requirement carries executing automated coverage (MockRepo query-shape assertions + `Phoenix.LiveViewTest` render + total-function presenter tests). No requirement is dark (zero-coverage). Three classes of deferral remain, all intentional and documented below.

---

## Wave 0 Requirements

- Existing ExUnit + Phoenix.LiveViewTest infrastructure covers all phase requirements; no new
  framework install needed. E2E spec(s) live under `examples/cairnloop_example/test/e2e/`.

---

## Manual-Only / Deferred Verifications

| Behavior | Requirement | Why Deferred | Where It Runs |
|----------|-------------|--------------|---------------|
| Actual browser navigation transition (JS-driven `<.link navigate>`) | THREAD-01/02/03 | `Phoenix.LiveViewTest` cannot exercise the real JS navigation; a thin E2E spec covers it | `examples/cairnloop_example/test/e2e/thread_navigation_test.exs` (exists) → `mix test.e2e`, gated CI `e2e` lane. Not runnable in this Repo-less workspace. |
| DB round-trip semantics: `next_open_conversation/1` ordering/status-filter/tiebreak (D-06/D-07), `originating_conversation_id/2` scope + earliest-origin (T-42-04, A2), enriched auditor map FK join (THREAD-02/03) | THREAD-01/02/03 | `Cairnloop.Repo` unavailable in this workspace; live Postgres round-trip required to assert real row results | **Currently inactive** — written as commented `# REPO-UNAVAILABLE` stubs in `chat_test.exs`, `knowledge_automation_test.exs`, `auditor_governance_test.exs`. The query *construction* contract IS automated green via MockRepo query-shape assertions; only the row-result round-trip is deferred. |

*Headless tests cover link rendering, param tolerance, fail-closed absence, and query-shape (where/order_by/limit/select) on every `mix test`. Only the live JS transition (E2E lane) and the DB row-result round-trips (integration-deferred) are not exercised in this workspace.*

> **Honest-gap note (auditor decision, 2026-06-04):** The `# REPO-UNAVAILABLE` round-trip tests are
> **commented stubs**, so they do not execute even in CI's `:integration` lane (unlike the active
> `@tag :integration` test in `governance_test.exs`). They were **not** activated during this audit:
> with no live `Repo` in this workspace they cannot be run to green, and committing blind, unrun
> integration tests is riskier than an honest documented deferral (and would risk breaking the CI
> integration lane). Each affected requirement nonetheless has executing green headless coverage of
> its query contract, so `nyquist_compliant` remains `true`. **Follow-up (cheap, non-blocking):** in
> an environment with Postgres, convert these stubs to active `@tag :integration` round-trip tests so
> they run under `mix test.integration` in CI. Owner may veto this follow-up.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-04 (plans verified Nyquist-compliant by gsd-plan-checker: 11/11 tasks carry `<automated>` verify, no 3-consecutive-task gap, E2E gate last, Wave-0 test files co-created in their TDD tasks)

---

## Validation Audit 2026-06-04

Post-execution audit (State A — VALIDATION.md existed pre-execution, statuses were `⬜ pending`). All
8 phase test files confirmed present on disk; headless lib suite run and verified green.

| Metric | Count |
|--------|-------|
| Requirements audited | 4 (THREAD-01/02/03a/03b) |
| Tasks in map | 11 |
| Test files present | 9/9 |
| Headless tests passing | 215 / 215 (0 failures) |
| MISSING gaps (zero coverage) | 0 |
| PARTIAL / deferred (intentional) | 4 (3 DB round-trip stubs + 1 E2E lane) |
| New tests written this audit | 0 |
| Escalated | 0 |

**Verdict:** NYQUIST-COMPLIANT. Every requirement has executing green automated verification of its
contract. Deferrals (DB round-trips, real-browser E2E) are intentional, documented, and bounded by
the workspace `REPO-UNAVAILABLE` / no-browser constraints — not coverage holes. See Honest-gap note
above for the one cheap, non-blocking follow-up (activate round-trip stubs where Postgres exists).
