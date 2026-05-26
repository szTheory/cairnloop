---
phase: 10-citation-backed-draft-suggestions
reviewed: 2026-05-23T11:57:43Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/cairnloop/knowledge_automation.ex
  - lib/cairnloop/web/knowledge_base_live/editor.ex
  - lib/cairnloop/web/article_suggestion_presenter.ex
  - test/cairnloop/knowledge_automation/article_suggestion_test.exs
  - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
  - test/cairnloop/web/knowledge_base_live_test.exs
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-05-23T11:57:43Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Re-reviewed the Phase 10 fixes with focus on the previously reported evidence normalization, editor handoff scoping, presenter reload safety, and the new regression tests. Two of the prior findings are fixed in code: `normalize_map_key/1` no longer atomizes arbitrary strings in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1611), and `to_result/1` now reads destination metadata through the string-key-safe helper in [lib/cairnloop/web/article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:179). The focused test run passed (`35 tests, 0 failures`), although it emitted Postgrex config errors before ExUnit booted.

One functional integrity gap remains in the editor handoff, and one test-coverage issue still gives false confidence around the fixed reload path.

## Warnings

### WR-01: `review_task_id` can still be paired with the wrong article when no `suggestion_id` is present

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:98-105,123-135,187-203`
**Issue:** The latest patch scopes `suggestion_id` and `review_task_id` lookups, and it rejects mismatched task/suggestion pairs when both params are present. But `ensure_review_task_matches!/2` returns `:ok` for `nil` suggestions, so `/knowledge-base/:id/edit?review_task_id=...` still loads any in-scope review task without proving it belongs to the route article. That stale pairing then flows into `maybe_mark_review_task_material_edit/2`, which can mark edits against an unrelated review task after saving a draft for a different article.
**Fix:**
```elixir
defp load_review_context(%{"review_task_id" => review_task_id} = params, scope_filters, suggestion, article) do
  task =
    review_task_id
    |> normalize_id()
    |> knowledge_automation().get_review_task!(scope_filters)

  :ok = ensure_review_task_matches!(task, suggestion)
  :ok = ensure_review_task_article_matches!(task, suggestion, article)

  ...
end

defp ensure_review_task_article_matches!(task, suggestion, article) do
  task_article_id =
    suggestion && (suggestion.article_id || metadata_value(suggestion.grounding_metadata || %{}, :authoring_article_id)) ||
      task.article_suggestion &&
        (task.article_suggestion.article_id ||
           metadata_value(task.article_suggestion.grounding_metadata || %{}, :authoring_article_id))

  if is_nil(task_article_id) || task_article_id == article.id do
    :ok
  else
    raise Ecto.NoResultsError, queryable: KnowledgeAutomation.ReviewTask
  end
end
```

### WR-02: The new regression tests do not actually cover persisted string-key evidence or scoped editor lookups

**File:** `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs:681-688,727-735`; `test/cairnloop/web/knowledge_base_live_test.exs:58-100,159-220`
**Issue:** The new test named `"review surface renders persisted evidence metadata with string keys"` still renders the default fixture, whose `citation_target` and `metadata.destination` are atom-keyed maps inside an `ArticleSuggestionEvidence` struct. That means it never exercises the persisted JSON reload shape that previously crashed. The editor tests also use mock `get_article_suggestion!/2` and `get_review_task!/2` functions that ignore `opts`, so they do not prove that `scope_filters(session)` is passed through or that a bare `review_task_id` mismatch is rejected.
**Fix:**
```elixir
test "review surface renders persisted evidence metadata with string keys" do
  persisted =
    struct(ArticleSuggestionEvidence, %{
      source_type: :knowledge_base,
      trust_level: :canonical,
      title: "Billing export reference",
      excerpt: "Use the export endpoint with a date range.",
      citation_target: %{"article_id" => 77, "revision_id" => 44, "chunk_index" => 2},
      metadata: %{"destination" => %{"article_id" => 77, "revision_id" => 44}},
      match_reasons: ["matched export settings"]
    })

  ...
end

test "editor rejects review_task_id that resolves to a different article without suggestion_id" do
  assert_raise Ecto.NoResultsError, fn ->
    Editor.mount(%{"id" => "42", "review_task_id" => "27"}, %{"host_user_id" => "user-1"}, %Phoenix.LiveView.Socket{})
  end
end

test "editor forwards scope filters into suggestion and review-task lookups" do
  Editor.mount(%{"id" => "42", "suggestion_id" => "15", "review_task_id" => "27"}, %{"host_user_id" => "user-1"}, %Phoenix.LiveView.Socket{})
  assert_received {:suggestion_lookup_opts, [tenant_scope: :host_user_scoped, host_user_id: "user-1"]}
  assert_received {:review_task_lookup_opts, [tenant_scope: :host_user_scoped, host_user_id: "user-1"]}
end
```

---

_Reviewed: 2026-05-23T11:57:43Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
