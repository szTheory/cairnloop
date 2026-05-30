---
phase: 30-kb-editorial-polish-t-10-09-t-10-11-closure
plan: "01"
subsystem: security
tags: [elixir, phoenix, ecto, plug_crypto, editor_handoff, knowledge_base, knowledge_automation]

# Dependency graph
requires:
  - phase: vM010-kb-ai-maintenance
    provides: ArticleSuggestion schema with manual_edit_opened_at field, EditorHandoff domain/web modules, KnowledgeAutomation facade, KnowledgeBase facade

provides:
  - "Token.decode/1 on Cairnloop.KnowledgeAutomation.EditorHandoff (single Plug.Crypto.verify call)"
  - "manual_edit_opened_at key in EditorHandoff.normalize/1 payload"
  - "Web EditorHandoff.sign/5 with keyword opts (manual_edit_opened_at)"
  - "Web EditorHandoff.verify!/2 three-step pipeline: Token.decode -> assert_handoff_marker -> non_marker_attrs equality"
  - "Web EditorHandoff.assert_handoff_marker/1: rejects tokens lacking non-empty binary marker"
  - "KnowledgeAutomation.record_editor_handoff/2: writes manual_edit_opened_at = now_fn(opts).() via narrow changeset"
  - "KnowledgeAutomation.get_gap_candidate/2: non-bang sibling returning nil on not-found"
  - "ArticleSuggestion.manual_edit_changeset/2: narrow cast of :manual_edit_opened_at only"
  - "KnowledgeBase.list_articles/1: Article ordered desc inserted_at, desc id with optional :status filter"
  - "Pure tests: editor_handoff_test.exs (decode/1 + verify!/2 marker gate), knowledge_automation_test.exs (new), knowledge_base_test.exs extended"

affects:
  - 30-02 (Wave 2 LiveView plans that call sign/5 with marker opt)
  - 30-03 (knowledge_base_live_test.exs sign-without-marker fixtures need updating there)
  - 30-04 (Editor mount rescue + gap_candidate assign consume these primitives)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "decode/1 in domain token module: Plug.Crypto.verify returns {:ok, payload} | {:error, reason}; semantic assertions stay in web layer"
    - "three-step with verify!/2: decode integrity -> assert_handoff_marker -> non_marker_attrs equality; marker ONLY in decoded payload, never URL param"
    - "narrow wrapper changeset (manual_edit_changeset/2): mirror dismiss_changeset shape, cast single field, no heavy validate_required re-run"
    - "non-bang rescue sibling (get_gap_candidate/2): wrap bang with rescue Ecto.NoResultsError -> nil"
    - "opts-list facade read (list_articles/1): Article |> maybe_filter_article_status |> order_by desc |> repo().all()"

key-files:
  created:
    - test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs
    - test/cairnloop/knowledge_automation_test.exs
  modified:
    - lib/cairnloop/knowledge_automation/editor_handoff.ex
    - lib/cairnloop/web/knowledge_base_live/editor_handoff.ex
    - lib/cairnloop/knowledge_automation/article_suggestion.ex
    - lib/cairnloop/knowledge_automation.ex
    - lib/cairnloop/knowledge_base.ex
    - test/cairnloop/knowledge_base_test.exs

key-decisions:
  - "verify!/2 step 3 compares non_marker_attrs(payload) == normalized_attrs(params, article_id) — four non-marker keys only; manual_edit_opened_at is NEVER included in the attrs-equality check (including it would compare ISO8601 string in payload against guaranteed-nil in expected, always failing)"
  - "record_editor_handoff/2 uses now_fn(opts).() for test-pinnable timestamps; overwrites on each open (refresh-to-latest idempotency per RESEARCH Open Q2 RESOLVED)"
  - "get_gap_candidate/2 wraps get_gap_candidate!/2 with rescue rather than duplicating the query pipeline (scope/preload/hydrate chain)"
  - "Token.decode/1 is purely additive — existing sealed verify/2 is untouched and backward-compatible"

patterns-established:
  - "Integrity primitive in domain (decode/1), semantic assertions in web layer — canonical Elixir/Phoenix pattern (mirrors Phoenix.Token, Guardian, Joken)"
  - "Narrow wrapper changeset for single-field writes avoids re-running heavy validate_required on unrelated fields"
  - "Mock-injection test seam: Application.put_env(:cairnloop, :repo, MockRepo) + on_exit delete; Process.get/put for per-test state"

requirements-completed: [SEC-01, SEC-02, KB-02, KB-03]

# Metrics
duration: 35min
completed: "2026-05-28"
---

# Phase 30 Plan 01: KB Security Gate Primitives + Facade Reads/Writes Summary

**Double-layer EditorHandoff marker gate (T-10-11 closure via signed token + T-10-09 closure via DB write), `record_editor_handoff/2`, `get_gap_candidate/2`, `manual_edit_changeset/2`, and `list_articles/1` — all pure domain/web plumbing proven by headless tests**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-05-28T15:55:00Z
- **Completed:** 2026-05-28T16:30:00Z
- **Tasks:** 4
- **Files modified:** 7 (2 new test files, 5 source files modified)

## Accomplishments

- Closed the token-layer half of T-10-11: `verify!/2` now requires a non-empty binary `manual_edit_opened_at` in the decoded payload; bare-URL handoffs raise `Ecto.NoResultsError` before `proposed_markdown` is ever loaded
- Closed T-10-09 DB-write half: `record_editor_handoff/2` writes `manual_edit_opened_at = now_fn(opts).()` via a narrow `manual_edit_changeset/2` wrapper (no incidental re-validation of unrelated required fields)
- Added `get_gap_candidate/2` non-bang sibling (nil-on-not-found) and `list_articles/1` facade read — both needed by Wave 2 LiveView plans (30-03, 30-04)
- 19 headless tests across 3 files: pure decode/verify round-trips (no Repo), Mock-injected changeset writes, query-struct assertions (no Postgres)

## Task Commits

1. **Task 1: Extend domain + web EditorHandoff** - `099ad56` (feat)
2. **Task 2: Add pure editor_handoff_test.exs** - `6eb6be3` (test)
3. **Task 3: Add record_editor_handoff/2, get_gap_candidate/2, manual_edit_changeset/2, list_articles/1** - `d1c7f16` (feat)
4. **Task 4: Add headless behavioral tests** - `6688724` (test)

## Files Created/Modified

- `lib/cairnloop/knowledge_automation/editor_handoff.ex` — Added `decode/1` + `manual_edit_opened_at` in `normalize/1`
- `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex` — `sign/4` → `sign/5` (opts), three-step `verify!/2`, `assert_handoff_marker/1`, `non_marker_attrs/1`, `normalized_attrs/2`
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` — Added `manual_edit_changeset/2` (narrow cast)
- `lib/cairnloop/knowledge_automation.ex` — Added `record_editor_handoff/2`, `get_gap_candidate/2`
- `lib/cairnloop/knowledge_base.ex` — Added `list_articles/1`, `maybe_filter_article_status/2`
- `test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs` — New: pure decode/1 round-trip + verify!/2 marker gate tests (5 tests)
- `test/cairnloop/knowledge_base_test.exs` — Extended: `MockRepo.all/1`, `describe "list_articles/1"` (5 new tests)
- `test/cairnloop/knowledge_automation_test.exs` — New: manual_edit_changeset/2 unit + record_editor_handoff/2 end-to-end + get_gap_candidate/2 nil-rescue (4 tests)

## Decisions Made

- `normalized_attrs/2` in the web wrapper produces ONLY the four non-marker attrs (`suggestion_id`, `article_id`, `review_task_id`, `return_to`) — never includes `manual_edit_opened_at`. Including it would always fail step 3 because the ISO8601 string in the decoded payload would compare against a nil in the expected map.
- `record_editor_handoff/2` overwrites on each open (refresh-to-latest idempotency) — simplest approach, satisfies the auditable-marker intent per RESEARCH Open Q2 RESOLVED.
- `get_gap_candidate/2` wraps `get_gap_candidate!/2` with a rescue clause rather than duplicating the query pipeline (scope + preload + hydrate_memberships chain).

## Deviations from Plan

None — plan executed exactly as written. The order_by assertion in `list_articles/1` tests required reading the actual `%Ecto.Query{}` struct shape from a test run (the `expr` field is a flat list of `{dir, field}` tuples, not `{env, fields}`), but this was a test-assertion detail corrected inline before commit — not a deviation from plan intent.

## Issues Encountered

- Test suite runs required `MIX_BUILD_ROOT` and `MIX_DEPS_PATH` flags to point to the main repo's `deps` directory, since the git worktree does not have its own `deps` symlink. This is a worktree environment detail, not a code issue.
- The `mix test` order_by assertion in Task 4 needed one iteration to match the actual `%Ecto.Query{}` struct shape. Fixed inline before commit.

## Known Stubs

None — this plan is pure domain/web-wrapper plumbing with no render files. No stub patterns introduced.

## Threat Flags

No new unplanned threat surface introduced. All new code is covered by the plan's threat model:
- `record_editor_handoff/2` (T-10-09 mitigated) and `get_gap_candidate/2` thread `opts` through existing `apply_scope/2` + `enforce_scope!/3`.
- `list_articles/1` accepts scope opts (Article has no tenant fields yet — reserved per D-09).
- `verify!/2` rewrite closes T-10-11 exactly as specified.

## Handoff Note for Plan 03 (knowledge_base_live_test.exs)

The ~8 existing `knowledge_base_live_test.exs` call sites that use `EditorHandoff.sign(id, article_id, review_task_id, return_to)` WITHOUT a `manual_edit_opened_at` marker will fail `verify!/2` until Plan 03 updates them with the marker opt. The 3 `assert_raise` mount tests similarly depend on Plan 03's mount-rescue + token-fixture updates. This is the documented hand-off per the plan's `<output>` spec — NOT a regression introduced here.

The token-shape change invalidates any pre-deploy tokens minted without the marker. This is expected and acceptable (`@max_age 1800` = 30 min; tokens are minted at operator click-time).

## Next Phase Readiness

- Wave 2 LiveView plans (30-02, 30-03, 30-04) can call all functions built here
- `sign/5` is ready for `SuggestionReview.open_for_manual_edit` to add the marker opt
- `record_editor_handoff/2` is ready for the DB write call in `SuggestionReview`
- `list_articles/1` is ready for `KnowledgeBase.Index.mount/3` to replace `repo().all(Article)`
- `get_gap_candidate/2` is ready for `Editor.mount/3`'s `load_gap_candidate_from_suggestion/2` helper

---
*Phase: 30-kb-editorial-polish-t-10-09-t-10-11-closure*
*Completed: 2026-05-28*
