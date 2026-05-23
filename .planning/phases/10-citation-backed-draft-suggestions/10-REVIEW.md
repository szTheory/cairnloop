---
phase: 10-citation-backed-draft-suggestions
reviewed: 2026-05-23T11:41:25Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/cairnloop/knowledge_automation.ex
  - lib/cairnloop/knowledge_automation/article_suggestion.ex
  - lib/cairnloop/knowledge_automation/stale_article_signal.ex
  - lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex
  - lib/cairnloop/web/knowledge_base_live/index.ex
  - lib/cairnloop/web/knowledge_base_live/editor.ex
  - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
  - lib/cairnloop/web/article_suggestion_presenter.ex
  - test/cairnloop/knowledge_automation/article_suggestion_test.exs
  - test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs
  - test/cairnloop/web/knowledge_base_live/gaps_test.exs
  - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
  - test/cairnloop/web/knowledge_base_live_test.exs
findings:
  critical: 2
  warning: 1
  info: 1
  total: 4
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-05-23T11:41:25Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Reviewed the current Phase 10 suggestion-domain, worker, review-lane, editor-handoff, and Plan 10-05 entrypoint-grounding changes, with emphasis on `KnowledgeAutomation`, `StaleArticleSignal`, the KB index/gaps entrypoints, and the focused test suites. The new grounding path is materially better than the earlier generic fallback, and the targeted ExUnit suites pass, but three previously open integration bugs still remain and Plan 10-05 introduced an atom-exhaustion risk in evidence normalization.

## Critical Issues

### CR-01: Evidence normalization atomizes untrusted map keys before validation

**File:** `lib/cairnloop/knowledge_automation.ex:1543-1568`
**Issue:** `normalize_citation_target/4` and `normalize_destination_metadata/3` call `normalize_map_key/1`, which uses `String.to_atom/1` on every incoming key (`lib/cairnloop/knowledge_automation.ex:1611`). These maps come from retrieval payloads and persisted JSON-backed evidence, so a malformed or adversarial payload can create unbounded atoms and eventually crash the VM. This happens before the later `ArticleSuggestionEvidence` validation can reject oversized or invalid payloads.
**Fix:**
```elixir
@citation_target_keys ~w(article_id revision_id chunk_index slug section)a
@destination_keys ~w(article_id revision_id conversation_id)a

defp normalize_citation_target(%{} = citation_target, article_id, revision_id, chunk_index) do
  citation_target
  |> Enum.reduce(%{}, fn
    {key, value}, acc when key in @citation_target_keys -> Map.put(acc, key, value)
    {key, value}, acc when is_binary(key) ->
      case key do
        "article_id" -> Map.put(acc, :article_id, value)
        "revision_id" -> Map.put(acc, :revision_id, value)
        "chunk_index" -> Map.put(acc, :chunk_index, value)
        "slug" -> Map.put(acc, :slug, value)
        "section" -> Map.put(acc, :section, value)
        _ -> acc
      end
    _, acc -> acc
  end)
  |> Map.put_new(:article_id, article_id)
  |> Map.put_new(:revision_id, revision_id)
  |> Map.put_new(:chunk_index, chunk_index)
end
```

### CR-02: Editor handoff still trusts unscoped `suggestion_id` and `review_task_id`

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:11-16`
**Issue:** `mount/3` loads the article from the path, then independently loads `suggestion_id` and `review_task_id` with `get_article_suggestion!/1` and `get_review_task!/1` in `preload_content/2` and `load_review_context/1` (`lib/cairnloop/web/knowledge_base_live/editor.ex:81-105`). No session scope is applied, and nothing verifies that the loaded suggestion/task belongs to the article being edited. A caller can tamper with query params to preload another tenant's suggestion or pair a suggestion for article A with `/knowledge-base/:id/edit` for article B.
**Fix:**
```elixir
def mount(params, session, socket) do
  scope_filters = scope_filters(session)
  article = repo().get!(Article, normalize_id(params["id"] || session["id"]))

  suggestion =
    case params["suggestion_id"] do
      nil -> nil
      id -> knowledge_automation().get_article_suggestion!(normalize_id(id), scope_filters)
    end

  review_task =
    case params["review_task_id"] do
      nil -> nil
      id -> knowledge_automation().get_review_task!(normalize_id(id), scope_filters)
    end

  :ok = ensure_editor_target_matches!(article, suggestion, review_task)
  ...
end
```

## Warnings

### WR-01: Suggestion review can still crash on persisted evidence with string-key metadata

**File:** `lib/cairnloop/web/article_suggestion_presenter.ex:179-188`
**Issue:** `to_result/1` guards with `metadata_value(evidence.metadata, :destination)` but then reads `evidence.metadata.destination` directly. Persisted embeds commonly reload as plain maps with string keys, so this raises instead of rendering the suggestion review evidence path. The current tests only use atom-keyed structs, so the failure mode is not covered.
**Fix:**
```elixir
defp to_result(evidence) do
  destination = metadata_value(evidence.metadata, :destination)

  %Result{
    source_type: evidence.source_type,
    trust_level: evidence.trust_level,
    title: evidence.title,
    content: evidence.excerpt,
    article_id: metadata_value(evidence.citation_target, :article_id),
    revision_id: metadata_value(evidence.citation_target, :revision_id),
    metadata: if(is_map(destination), do: %{destination: destination}, else: %{})
  }
end
```

## Info

### IN-01: Focused tests miss the two highest-risk editor/reload regressions

**File:** `test/cairnloop/web/knowledge_base_live_test.exs:117-165`
**Issue:** The editor tests prove only the happy path with hard-coded article `42`, suggestion `15`, and review task `27`. They do not assert that mismatched article/suggestion pairs are rejected, that scope filters are passed into `KnowledgeAutomation`, or that persisted string-key evidence maps render without crashing. `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs:657-684` also seeds only atom-keyed `ArticleSuggestionEvidence` structs, so it cannot catch the presenter bug above.
**Fix:** Add regression tests that:
```elixir
assert_raise Ecto.NoResultsError, fn ->
  Editor.mount(%{"id" => "42", "suggestion_id" => "foreign-id"}, %{"host_user_id" => "user-1"}, %Phoenix.LiveView.Socket{})
end

assert_raise ArgumentError, fn ->
  render_with_persisted_evidence(%{"metadata" => %{"destination" => %{"article_id" => 77, "revision_id" => 44}}})
end
```
then update the code so those tests pass with scope-aware lookup and string-key-safe rendering.

---

_Reviewed: 2026-05-23T11:41:25Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
