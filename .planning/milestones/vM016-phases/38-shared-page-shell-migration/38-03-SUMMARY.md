---
phase: 38-shared-page-shell-migration
plan: "03"
subsystem: web-presenters
tags: [breadcrumb, presenter, tdd, shell-02, pure-function]
dependency_graph:
  requires: []
  provides: [Cairnloop.Web.BreadcrumbPresenter]
  affects: [lib/cairnloop/web/knowledge_base_live/editor.ex, lib/cairnloop/web/knowledge_base_live/suggestion_review.ex]
tech_stack:
  added: []
  patterns: [presenter-idiom, total-functions, tdd-red-green-refactor]
key_files:
  created:
    - lib/cairnloop/web/breadcrumb_presenter.ex
    - test/cairnloop/web/breadcrumb_presenter_test.exs
  modified: []
decisions:
  - "suggestions_items/1 takes optional task_title (nil or binary) — single-arity with guard covers both the static 2-item and the 3-item task-selected variants cleanly"
  - "Docstring avoids 'Repo' keyword to satisfy acceptance criterion grep gate; uses 'no database calls' instead — semantically equivalent, more readable"
  - "No REFACTOR commit needed — implementation was already total, well-structured, and properly documented after GREEN; no cleanup opportunity arose"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-04T06:01:00Z"
  tasks_completed: 1
  files_created: 2
  files_modified: 0
---

# Phase 38 Plan 03: BreadcrumbPresenter Summary

**One-liner:** Pure total `Cairnloop.Web.BreadcrumbPresenter` with `editor_items/2` (origin-aware from path shape) and `suggestions_items/1` (static lane), 29 headless tests, last-crumb + negative-copy contracts enforced.

## What Was Built

`Cairnloop.Web.BreadcrumbPresenter` — a pure, total, Repo-free presenter module (SHELL-02 foundation) that builds `cl_breadcrumb` items lists for:

1. **`editor_items/2`** — KB editor breadcrumb. Derives the origin label from the `return_to` path shape (already verified upstream via signed handoff token): `"/knowledge-base/..."` → "Suggestions"; any other binary (e.g. `"/42"`) → "Conversation". Nil/non-binary `return_to` → 2-item static fallback. The raw path is never used as a label (copy rule + T-38-05 V5 mitigation).

2. **`suggestions_items/1`** — KB suggestion_review breadcrumb. Without a task title: `[Knowledge, Suggestions]` (2-item static). With a task title: `[Knowledge, Suggestions (linked back), task_title (current)]` (3-item). No conversation→suggestion_review handoff invented (that is Phase 42).

Every clause enforces the `cl_breadcrumb` contract: all non-last items carry `:href`; the last item OMITS `:href` entirely (not `href: nil`).

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED — failing tests | `c7865a4` | Passed (29 tests, all `UndefinedFunctionError`) |
| GREEN — implementation | `cba2a46` | Passed (29 tests, 0 failures) |
| REFACTOR | skipped | No cleanup needed — implementation was already total and well-structured |

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Write failing tests for BreadcrumbPresenter | `c7865a4` | `test/cairnloop/web/breadcrumb_presenter_test.exs` |
| 1 (GREEN) | Implement BreadcrumbPresenter | `cba2a46` | `lib/cairnloop/web/breadcrumb_presenter.ex` |

## Verification Results

- `mix compile --warnings-as-errors` exits 0 (clean)
- `mix test test/cairnloop/web/breadcrumb_presenter_test.exs` exits 0 — 29 tests, 0 failures
- `grep -c "defmodule Cairnloop.Web.BreadcrumbPresenter" ...` returns 1
- `grep -c "Repo" ...` returns 0
- No stubs, no placeholder text, no TODO/FIXME

## Deviations from Plan

None — plan executed exactly as written.

The `suggestions_items/1` arity decision (plan said "Claude's-discretion arity; recommend taking the optional selected-task title") was resolved as a single-arity function taking `task_title` (nil or binary) with a guard-based dispatch — consistent with the total-function pattern and avoids overloading concerns.

## Known Stubs

None. Both functions return complete, correct data for all inputs. No wire-up is deferred within this presenter.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The presenter is a pure in-memory transform module. T-38-05 (information disclosure via raw path label) is mitigated by the negative-copy contract enforced in 2 dedicated tests. No new threat surface beyond what the plan's threat model already covers.

## Self-Check: PASSED

- `lib/cairnloop/web/breadcrumb_presenter.ex` — FOUND
- `test/cairnloop/web/breadcrumb_presenter_test.exs` — FOUND
- RED commit `c7865a4` — FOUND
- GREEN commit `cba2a46` — FOUND
- 29 tests, 0 failures — VERIFIED
