---
phase: 30
slug: kb-editorial-polish-t-10-09-t-10-11-closure
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-28
audited: 2026-05-28
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Test paths below are aligned to the ACTUAL files each plan creates/extends (revision pass).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` (HTML via `lazy_html`) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_automation_test.exs test/cairnloop/web/review_task_presenter_test.exs test/cairnloop/web/knowledge_base_live/` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15–30 seconds (headless; Repo-round-trip tests `# REPO-UNAVAILABLE`) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command above
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green (1 known pre-existing failure: `Automation.DraftTest` — M005 drift, excluded as baseline, not a regression)
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

Each row maps a plan task to the actual test file that plan creates or extends.

| Task ID | Plan | Wave | Requirement | Threat Ref | Behavior Proven | Test Type | Automated Command | File (created by) | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------------|--------|
| 30-01-01 | 01 | 1 | SEC-01/SEC-02 | T-10-09/T-10-11 | domain `decode/1` round-trips; marker-carrying `normalize/1` | unit (pure) | `mix test test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs` | `test/.../editor_handoff_test.exs` (30-01 Task 2, W0) | ✅ green |
| 30-01-02 | 01 | 1 | SEC-02 | T-10-11 | web `verify!/2` :ok with marker; raises `Ecto.NoResultsError` without marker / on mismatch | unit (pure) | `mix test test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs` | `test/.../editor_handoff_test.exs` (30-01 Task 2, W0) | ✅ green |
| 30-01-03 | 01 | 1 | SEC-01 | T-10-09 | `record_editor_handoff/2` writes pinned `now_fn` `manual_edit_opened_at` via narrow changeset (Mock) | unit (Mock) | `mix test test/cairnloop/knowledge_automation_test.exs` | `test/cairnloop/knowledge_automation_test.exs` (30-01 Task 4, new) | ✅ green |
| 30-01-04 | 01 | 1 | KB-03 | — | `get_gap_candidate/2` returns `nil` on not-found (rescue branch, Mock) | unit (Mock) | `mix test test/cairnloop/knowledge_automation_test.exs` | `test/cairnloop/knowledge_automation_test.exs` (30-01 Task 4, new) | ✅ green |
| 30-01-05 | 01 | 1 | KB-02 | — | `list_articles/1` desc inserted_at/id ordering + `:status` filter (Mock query capture) | unit (Mock) | `mix test test/cairnloop/knowledge_base_test.exs` | `test/cairnloop/knowledge_base_test.exs` (30-01 Task 4, extend) | ✅ green |
| 30-02-01 | 02 | 1 | KB-01 | — | `kb_nav/1` renders `<nav aria-label="Knowledge base">` + 3 routed links | unit (pure render) | `mix test test/cairnloop/web/knowledge_base_live/nav_component_test.exs` | `test/.../nav_component_test.exs` (30-02 Task 2, W0) | ✅ green |
| 30-02-02 | 02 | 1 | KB-01 | — | active item has `aria-current="page"` + `var(--cl-primary)` border (not color alone); `:editor` → no active marker | unit (pure render) | `mix test test/cairnloop/web/knowledge_base_live/nav_component_test.exs` | `test/.../nav_component_test.exs` (30-02 Task 2, W0) | ✅ green |
| 30-02-03 | 02 | 1 | KB-04 | — | `action_label/2` 3 calm variants; `:failed`→"Review and draft manually", `:article`→"Create manual draft", default→"Open for manual edit"; no raw atom | unit (pure) | `mix test test/cairnloop/web/review_task_presenter_test.exs` | `test/cairnloop/web/review_task_presenter_test.exs` (30-02 Task 3, W0) | ✅ green |
| 30-03-01 | 03 | 2 | KB-02 | — | `"new_article"` event creates article + push_navigates to `/knowledge-base/:id/edit`; error path flashes calm copy | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | `test/.../knowledge_base_live_test.exs` (30-03 Task 3, extend) | ✅ green |
| 30-03-02 | 03 | 2 | KB-03 | — | Editor gap-candidate suggestion renders "Source gap" sidebar w/ title + evidence detail ("2 evidence" + freshness); non-gap renders none | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | `test/.../knowledge_base_live_test.exs` (30-03 Task 3, extend) | ✅ green |
| 30-03-03 | 03 | 2 | SEC-02 | T-10-11 | Editor mount without valid handoff marker → calm flash + redirect to `/knowledge-base/suggestions` (no `assert_raise`) | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | `test/.../knowledge_base_live_test.exs` (30-03 Task 3, extend) | ✅ green |
| 30-04-01 | 04 | 2 | SEC-01 | T-10-09 | `open_for_manual_edit` calls `record_editor_handoff/2` before signing; minted token decodes to non-empty `manual_edit_opened_at` | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | `test/.../suggestion_review_test.exs` (30-04 Task 3, extend) | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

The new-file (Wave 0) gates are owned by their plans (each plan's first test task creates the file
before/with the production code). `wave_0_complete: false` until those tasks land.

- [x] `test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs` — SEC-01/SEC-02 `decode/1` + `verify!/2` marker-gate (30-01 Task 2)
- [x] `test/cairnloop/knowledge_automation_test.exs` — SEC-01/KB-03 `record_editor_handoff/2` write + `get_gap_candidate/2` nil-rescue (30-01 Task 4, new file)
- [x] `test/cairnloop/knowledge_base_test.exs` — KB-02 `list_articles/1` ordering + `:status` filter (30-01 Task 4, extends an existing file)
- [x] `test/cairnloop/web/knowledge_base_live/nav_component_test.exs` — KB-01 `kb_nav/1` render (30-02 Task 2, new file)
- [x] `test/cairnloop/web/review_task_presenter_test.exs` — KB-04 `action_label/2` copy variants (30-02 Task 3, new file)
- [x] Framework install: none — ExUnit + `lazy_html` already present

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `list_articles/1` real Postgres round-trip | KB-02 | Repo unavailable in workspace | Headless test asserts the captured `%Ecto.Query{}` `order_bys`/`wheres`; real SQL fetch tagged `# REPO-UNAVAILABLE` — run against a live DB |
| `record_editor_handoff/2` durable DB write | SEC-01 | Repo unavailable | Headless test asserts the applied changeset carries the pinned `now_fn` `manual_edit_opened_at`; real `repo().update` persistence tagged `# REPO-UNAVAILABLE` — verify `manual_edit_opened_at` set in DB after `open_for_manual_edit` |
| `get_gap_candidate/2` present-record happy path (preload + hydrate_memberships) | KB-03 | Repo unavailable (`one!/1` + `preload(:memberships)`) | Headless test covers the nil-rescue branch (the consumer-relevant behavior); present-record round-trip tagged `# REPO-UNAVAILABLE` |

---

## Validation Sign-Off

- [x] All tasks have an `<automated>` verify or a Wave 0 dependency to a test file a plan creates
- [x] Per-task map references only test paths the plans actually create/extend
- [x] Sampling continuity: no 3 consecutive tasks without an automated verify
- [x] Wave 0 covers all MISSING references (editor_handoff, knowledge_automation, nav_component, review_task_presenter)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated (revision pass) — paths aligned to plan test files; SEC-01 DB write + facade reads now have behavioral (Mock/REPO-UNAVAILABLE) coverage in 30-01 Task 4.

---

## Validation Audit 2026-05-28

| Metric | Count |
|--------|-------|
| Tasks audited | 12 |
| Gaps found | 0 |
| Resolved | 0 |
| Escalated to manual-only | 0 |
| Test files verified | 7 |
| Tests run | 68 |
| Failures | 0 |

**Outcome:** All 12 per-task rows confirmed COVERED. All 7 referenced test files exist on disk and 68 tests pass with 0 failures (`mix test` on the focused set). Wave 0 files all present. Status upgraded `draft → complete`, `wave_0_complete: false → true`.
