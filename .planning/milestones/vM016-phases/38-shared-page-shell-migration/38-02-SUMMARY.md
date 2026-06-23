---
phase: 38-shared-page-shell-migration
plan: "02"
subsystem: web/knowledge_base_live
tags: [shell-migration, cl_page, kb-screens, subnav, breadcrumb, tdd]
dependency_graph:
  requires: [37-component-primitives]
  provides: [SHELL-01-kb-screens]
  affects: [38-03, 38-04]
tech_stack:
  added: []
  patterns:
    - cl_page wrapping cl_shell inner content (KB screens)
    - :subnav slot for kb_nav sub-tab strip
    - :actions slot for single primary button (Index only)
    - :breadcrumb slot for cl_breadcrumb (Editor, static items this plan)
key_files:
  created: []
  modified:
    - lib/cairnloop/web/knowledge_base_live/index.ex
    - lib/cairnloop/web/knowledge_base_live/gaps.ex
    - lib/cairnloop/web/knowledge_base_live/editor.ex
    - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
    - test/cairnloop/web/knowledge_base_live_test.exs
    - test/cairnloop/web/knowledge_base_live/gaps_test.exs
    - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
decisions:
  - "Followed TDD: RED (failing tests) committed before GREEN (implementation) for each task pair"
  - "Editor breadcrumb items carried verbatim (static Knowledge + Editing crumb); origin-aware items deferred to 38-04"
  - "Suggestion review gets no breadcrumb in this plan (pure structural lift); new lane crumb wired in 38-04"
  - "kb_nav above-to-below reorder is intentional (Pitfall 5): kb_nav was above h1; now in :subnav below the page header"
metrics:
  duration: "~7 minutes"
  completed_date: "2026-06-04"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 7
---

# Phase 38 Plan 02: KB Screen Shell Migration Summary

Four KB sub-screens (Index, Editor, Gaps, Suggestion review) migrated to render inside `<.cl_page width="wide">` nested in `<.cl_shell>`, delivering SHELL-01 for the KB half of the cockpit. `kb_nav` tabs moved to `:subnav`, the Index "New article" button to `:actions`, and the Editor's existing free-floating `cl_breadcrumb` into the `:breadcrumb` slot (static items; origin-aware crumb is 38-04).

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 - RED | Failing render assertions for KB Index + Gaps | b88a866 |
| 1 - GREEN | Migrate KB Index + Gaps to cl_page | 9536075 |
| 2 - RED | Failing render assertions for KB Editor + Suggestion review | 8f8ba1a |
| 2 - GREEN | Migrate KB Editor + Suggestion review to cl_page | 73db7c8 |

## What Was Built

### KB Index (index.ex)
- `<.cl_page title="Knowledge Base" width="wide">` replaces the `<div class="cl-row cl-row--between">` wrapper
- `<:subnav><.kb_nav current={:index} /></:subnav>` — kb_nav moved from above h1 into the subnav slot
- `<:actions><.cl_button variant="primary" phx-click="new_article" phx-disable-with="Creating...">New article</.cl_button></:actions>` — primary button moved into actions slot
- Gap-candidates `<p>` link + articles `cl_card` stay in `inner_block` unchanged

### KB Gaps (gaps.ex)
- `<.cl_page title="Knowledge gaps" subtitle="Ranked maintenance signals..." width="wide">` replaces the `<header class="cl-mb-7">` wrapper + its `<h1>` + `<p class="cl-text-muted">`
- `<:subnav><.kb_nav current={:gaps} /></:subnav>` — kb_nav moved into subnav slot
- No `:actions`, no `:breadcrumb` (gaps is a lane index, not a detail screen)
- Gap-candidates card stays in `inner_block` unchanged

### KB Editor (editor.ex)
- `<.cl_page title={"Editing: #{@article.title}"} width="wide">` replaces the `<div class="cl-row cl-row--between">` h1 wrapper
- `<:breadcrumb><.cl_breadcrumb items={[%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: #{@article.title}"}]} /></:breadcrumb>` — existing free-floating breadcrumb (was at :263) moved into the :breadcrumb slot, items VERBATIM
- `<:subnav><.kb_nav current={:editor} /></:subnav>` — kb_nav moved into subnav slot
- 2-col markdown/preview grid (token `style=` at :294) kept UNCHANGED (D-05)
- Banners, grid, source-gap card moved wholesale into `inner_block`

### KB Suggestion review (suggestion_review.ex)
- `<.cl_page title="Suggestion review" subtitle="Inspect grounded KB proposals..." width="wide">` replaces `<header class="cl-mb-7">` wrapper
- `<:subnav><.kb_nav current={:suggestions} /></:subnav>` — kb_nav moved into subnav slot
- No `:breadcrumb` added in this plan (Suggestion review had none; new lane breadcrumb wired in 38-04)
- Filter card + queue table + detail cards stay in `inner_block` unchanged

## Intentional Behavior Change: kb_nav Reorder (Pitfall 5)

**For P45 screenshot diff reviewers:** The `kb_nav` tab strip previously rendered ABOVE the `<h1>` on every KB screen. In `cl_page`, the `:subnav` slot renders BELOW the page header (`components.ex:342`). This is an INTENTIONAL structural reorder — it is not a regression. The visual result places tabs below the title+subtitle row rather than above it.

## Verification

### Acceptance Criteria

| Criterion | Result |
|-----------|--------|
| `grep -c "<.cl_page" index.ex` | 1 |
| `grep -c "<.cl_page" gaps.ex` | 1 |
| `grep -c "<.cl_page" editor.ex` | 1 |
| `grep -c "<.cl_page" suggestion_review.ex` | 1 |
| `grep -c "<:subnav>" index.ex` | 1 |
| `grep -c "<:subnav>" gaps.ex` | 1 |
| `grep -c "<:subnav>" editor.ex` | 1 |
| `grep -c "<:subnav>" suggestion_review.ex` | 1 |
| `grep -c "<:actions>" index.ex` | 1 |
| `grep -c "<:breadcrumb>" editor.ex` | 1 |
| `mix compile --warnings-as-errors` | CLEAN |
| KB render tests (40 total across 3 files) | 0 failures |
| Brand token gate | CLEAN |

### Test Coverage Added

- `knowledge_base_live_test.exs`: +2 render tests (KB Index cl_page markers; KB Editor cl_page + breadcrumb)
- `gaps_test.exs`: +1 render test (KB Gaps cl_page markers)
- `suggestion_review_test.exs`: +1 render test (KB Suggestion review cl_page markers)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The editor breadcrumb uses static items (Knowledge + Editing title) which is the CURRENT correct behavior. Origin-aware crumbs are intentionally deferred to 38-04 as specified in the plan.

## TDD Gate Compliance

Both tasks followed the mandatory RED/GREEN cycle:

1. Task 1 RED: `b88a866` — `test(38-02): add failing render assertions for KB Index + Gaps cl_page migration`
2. Task 1 GREEN: `9536075` — `feat(38-02): migrate KB Index + Gaps to render inside cl_page`
3. Task 2 RED: `8f8ba1a` — `test(38-02): add failing render assertions for KB Editor + Suggestion review cl_page migration`
4. Task 2 GREEN: `73db7c8` — `feat(38-02): migrate KB Editor + Suggestion review to render inside cl_page`
