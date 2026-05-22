# M009-S02 Pattern Map

## Target Files And Closest Analogs

| Planned file | Role | Closest analog | Why it matches |
|---|---|---|---|
| `lib/cairnloop/web/search_modal_component.ex` | shared retrieval palette component | `lib/cairnloop/web/search_modal_component.ex` | Existing mount point and event lifecycle already live here |
| `lib/cairnloop/web/search_result_presenter.ex` | UI presenter over retrieval results | `lib/cairnloop/retrieval/result.ex` | Should stay close to the normalized result contract rather than inventing a second payload model |
| `lib/cairnloop/retrieval/providers/knowledge_base.ex` | canonical-result metadata enrichment | `lib/cairnloop/retrieval/providers/knowledge_base.ex` | Existing provider already controls KB row shape and ordering |
| `lib/cairnloop/retrieval/providers/resolved_cases.ex` | assistive-result metadata enrichment | `lib/cairnloop/retrieval/providers/resolved_cases.ex` | Existing provider already controls resolved-case row shape |
| `lib/cairnloop/web/conversation_live.ex` | host surface with state-preservation risk | `lib/cairnloop/web/conversation_live.ex` | Most sensitive mount point because it owns reply/draft state |
| `test/cairnloop/web/search_modal_component_test.exs` | palette interaction tests | `test/cairnloop/web/knowledge_base_live_test.exs` | Existing LiveView-oriented test style is a better baseline than the current placeholder |

## Reusable Code Patterns

### 1. Retrieval facade as the only search boundary

From `lib/cairnloop/retrieval.ex`:

```elixir
def search(query, opts \\ []) do
  knowledge_base_results = search_knowledge_base(query, opts)
  resolved_case_results = search_resolved_cases(query, opts)
  ranker(opts).merge(knowledge_base_results, resolved_case_results, opts)
end
```

Phase 2 should call this boundary from the modal instead of posting to Scrypath directly.

### 2. Provider-owned source and trust semantics

From `lib/cairnloop/retrieval/providers/knowledge_base.ex` and `resolved_cases.ex`:

```elixir
source_type: :knowledge_base,
trust_level: :canonical
```

```elixir
source_type: :resolved_case,
trust_level: :assistive
```

Keep these semantics server-owned and extend them with preview/destination metadata rather than recomputing them in the UI.

### 3. Stable ranking contract

From `lib/cairnloop/retrieval/ranker.ex`:

```elixir
|> Enum.sort_by(&sort_key/1, :desc)
```

Within each UI section, preserve backend ordering. The component should group results by source without re-ranking inside the browser.

### 4. Sensitive host-surface state

From `lib/cairnloop/web/conversation_live.ex`:

```elixir
|> assign(form: to_form(%{"content" => ""}), pending_discard_draft_id: nil)
```

Search integration must not disturb these assigns when the palette opens, previews, or closes.

## File-Specific Guidance

### `lib/cairnloop/web/search_modal_component.ex`

- Replace direct `Req.post` usage with `Cairnloop.Retrieval.search/2`
- Add active-row, grouped-section, loading, and preview state
- Keep query debounce server-side, but keep row movement local after results load

### `lib/cairnloop/retrieval/providers/knowledge_base.ex`

- Expose article/revision metadata needed for explicit KB destinations
- Expose timestamps or recency-friendly fields for UI formatting

### `lib/cairnloop/retrieval/providers/resolved_cases.ex`

- Expose preview-safe evidence fields and `resolved_at`
- Preserve `assistive` semantics in metadata and labels

### `test/cairnloop/web/search_modal_component_test.exs`

- Stub retrieval results for both source types
- Assert fixed section order and active-row/preview behavior
- Assert error state when retrieval returns failure

## Non-Patterns To Avoid

- Do not keep direct remote HTTP search calls in `SearchModalComponent`
- Do not guess routes from `result["id"]` or `result["conversation_id"]`
- Do not flatten KB and resolved-case hits into one undifferentiated list
- Do not make arrow-key movement trigger new retrieval requests
