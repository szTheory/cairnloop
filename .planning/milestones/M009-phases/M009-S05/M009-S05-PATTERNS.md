# Phase M009-S05 - Pattern Map

**Mapped:** 2026-05-20
**Scope source:** user-provided focus areas plus adjacent M009 artifacts (`M009-S02`, `M009-S04`)
**Important note:** no dedicated `M009-S05` context or research artifact existed at read time, so the target file list below is the probable S05 work surface inferred from the requested focus areas.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/web/search_modal_component.ex` | component | request-response | `lib/cairnloop/web/search_modal_component.ex` | exact |
| `lib/cairnloop/web/conversation_live.ex` | component | request-response | `lib/cairnloop/web/conversation_live.ex` | exact |
| `lib/cairnloop/web/inbox_live.ex` | component | request-response | `lib/cairnloop/web/inbox_live.ex` | exact |
| `lib/cairnloop/web/settings_live.ex` | component | request-response | `lib/cairnloop/web/settings_live.ex` | exact |
| `lib/cairnloop/retrieval.ex` | service | request-response | `lib/cairnloop/retrieval.ex` | exact |
| `lib/cairnloop/retrieval/providers/knowledge_base.ex` | service | CRUD | `lib/cairnloop/retrieval/providers/knowledge_base.ex` | exact |
| `lib/cairnloop/retrieval/providers/resolved_cases.ex` | service | CRUD | `lib/cairnloop/retrieval/providers/resolved_cases.ex` | exact |
| `lib/cairnloop/automation/workers/draft_worker.ex` | service | event-driven | `lib/cairnloop/automation/workers/draft_worker.ex` | exact |
| `test/cairnloop/web/search_modal_component_test.exs` | test | request-response | `test/cairnloop/web/search_modal_component_test.exs` | exact |
| `test/cairnloop/web/conversation_live_test.exs` | test | request-response | `test/cairnloop/web/conversation_live_test.exs` | exact |
| `test/cairnloop/automation/workers/draft_worker_test.exs` | test | event-driven | `test/cairnloop/automation/workers/draft_worker_test.exs` | exact |
| `test/cairnloop/retrieval_test.exs` | test | request-response | `test/cairnloop/retrieval_test.exs` | exact |
| `test/cairnloop/retrieval/telemetry_test.exs` | test | event-driven | `test/cairnloop/retrieval/telemetry_test.exs` | exact |
| `.planning/milestones/M009-phases/M009-S05/M009-S05-VALIDATION.md` | config | batch | `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md` | role-match |
| `.planning/milestones/M009-phases/M009-S05/M009-S05-0x-PLAN.md` | config | batch | `.planning/milestones/M009-phases/M009-S02/M009-S02-01-PLAN.md`, `.planning/milestones/M009-phases/M009-S04/M009-S04-03-PLAN.md` | role-match |

## Pattern Assignments

### Shared LiveView search mount across surfaces

**Primary analogs**
- `lib/cairnloop/web/conversation_live.ex:159-168`
- `lib/cairnloop/web/inbox_live.ex:30-35`
- `lib/cairnloop/web/settings_live.ex:51-56`

**Copy this mount contract**
```elixir
<.live_component
  module={Cairnloop.Web.SearchModalComponent}
  id="search-modal"
  host_surface="conversation"
  host_user_id={@conversation.host_user_id}
  current_path={"/#{@conversation.id}"}
  preserve_reply_form={true}
/>
```

**Lower-scope surface variants**
```elixir
<.live_component
  module={Cairnloop.Web.SearchModalComponent}
  id="search-modal"
  host_surface="inbox"
  current_path="/"
/>
```

```elixir
<.live_component
  module={Cairnloop.Web.SearchModalComponent}
  id="search-modal"
  host_surface="settings"
  current_path="/settings"
/>
```

**Recommended extension points**
- Extend the component callsite first, not the retrieval layer, when a new surface needs scope or UI-preservation hints.
- Keep `host_surface`, `host_user_id`, `current_path`, and `preserve_reply_form` as the paved-road assigns because the component already renders them into DOM data attrs at `lib/cairnloop/web/search_modal_component.ex:35-44`.
- Use `ConversationLive` as the highest-sensitivity analog when adding any new shared mount because it already proves the pattern for preserving in-flight reply state.

**What this pattern is buying**
- Shared component mounted identically across surfaces.
- Surface-specific behavior carried as assigns, not hidden globals.
- No per-surface branching inside retrieval providers.

---

### Component-side scope propagation and local event handling

**Primary analog:** `lib/cairnloop/web/search_modal_component.ex:15-30, 278-305, 307-324, 469-511`

**Assign/update pattern**
```elixir
socket =
  socket
  |> assign_defaults()
  |> assign(assigns)
  |> assign(
    :retrieval_module,
    Map.get(assigns, :retrieval_module, socket.assigns.retrieval_module)
  )
  |> assign(
    :gap_recorder,
    Map.get(assigns, :gap_recorder, socket.assigns.gap_recorder)
  )
  |> ensure_preview_state()
```

**Retrieval option passing pattern**
```elixir
defp search_opts(socket) do
  [
    surface: :search_modal,
    host_surface: socket.assigns.host_surface,
    host_user_id: socket.assigns.host_user_id
  ]
end
```

**Boundary-owned search branch pattern**
```elixir
case run_search(socket.assigns.retrieval_module, query, search_opts(socket)) do
  {:ok, results} ->
    _ = maybe_record_search_gap_for_results(socket, results)

    {:noreply,
     socket
     |> assign(loading: false)
     |> assign_results(results)}

  {:error, reason} ->
    _ = maybe_record_search_error(socket, reason)

    {:noreply,
     socket
     |> clear_results()
     |> assign(loading: false, error: true, search_state: :error)}
end
```

**Gap recording seam**
```elixir
attrs = %{
  query: socket.assigns.query,
  surface: :search_modal,
  outcome_class: outcome_class,
  reason: reason,
  host_user_id: socket.assigns.host_user_id,
  tenant_scope: socket.assigns.host_surface,
  attempted_evidence: Keyword.get(opts, :attempted_evidence, [])
}
```

**Recommended extension points**
- If S05 adds more scope, extend `search_opts/1` and the root DOM attrs together so runtime behavior and rendered shell stay aligned.
- If S05 adds surface-specific event behavior, keep it in component events like `toggle_search`, `handle_palette_key`, or helper functions; do not push row-selection or preview logic into the host LiveView.
- Reuse `assign_defaults/1` for any new shared assign to preserve testability and stable mount behavior.

**Anti-regression note**
- The component already distinguishes local interaction from retrieval calls. Preserve the contract where arrow-key movement and preview updates are local-only after results load.

---

### Conversation surface as the high-sensitivity host analog

**Primary analogs**
- `lib/cairnloop/web/conversation_live.ex:14-19`
- `lib/cairnloop/web/conversation_live.ex:134-157`
- `lib/cairnloop/web/conversation_live.ex:159-168`

**Copy this state-preserving mount flow**
```elixir
socket =
  socket
  |> assign(form: to_form(%{"content" => ""}), pending_discard_draft_id: nil)
  |> reload_conversation_with_context(id)
```

**Copy this host-context lookup seam**
```elixir
if conversation.host_user_id do
  case provider.get_context(conversation.host_user_id, []) do
    {:ok, map} -> {map, nil}
    {:error, reason} -> {%{}, reason}
  end
else
  {%{}, nil}
end
```

**Recommended extension points**
- If S05 needs a new shared component visible in conversation, mount it before the rest of the shell the same way search is mounted now.
- Pass any host-user or host-surface value from `@conversation` assigns, not by recomputing it in the component.
- Keep reply composer safety anchored here. `ConversationLive` is the analog for any “shared component across surfaces, but conversation cannot lose local form state” requirement.

---

### Retrieval facade option passing

**Primary analog:** `lib/cairnloop/retrieval.ex:12-27, 29-85, 223-240, 290-320`

**Facade-first search pattern**
```elixir
def search(query, opts \\ []) do
  started_at = System.monotonic_time()

  try do
    knowledge_base_results = search_knowledge_base(query, opts)
    resolved_case_results = search_resolved_cases(query, opts)
    results = ranker(opts).merge(knowledge_base_results, resolved_case_results, opts)

    emit_search_telemetry(results, opts, started_at)
    results
  rescue
    error ->
      emit_search_error_telemetry(error, opts, started_at)
      reraise error, __STACKTRACE__
  end
end
```

**Draft-grounding option propagation pattern**
```elixir
context = normalize_draft_context(query_or_context)
query = Map.fetch!(context, :query)
clarification_attempts = Map.get(context, :clarification_attempts, 0)
search_opts = Keyword.put_new(opts, :surface, :draft_generation)
results = search(query, search_opts)
```

**Grounding diagnostic taxonomy seam**
```elixir
cond do
  strong_canonical? -> {:grounded, :canonical_results}
  has_canonical? and clarification_attempts < 1 -> {:weak_grounding, :canonical_insufficient_detail}
  has_canonical? and clarification_attempts >= 1 -> {:policy_limit, :clarification_limit_reached}
  assistive != [] -> {:weak_grounding, :assistive_only_results}
  true -> {:empty_recall, :no_canonical_results}
end
```

**Recommended extension points**
- Pass future retrieval boundary options via `opts`, not by stuffing them into `query_or_context`; `normalize_draft_context/1` only preserves query and clarification attempts today.
- Keep `Retrieval.search/2` and `Retrieval.ground_for_draft/2` as the only surface-facing seams. Do not let LiveViews or workers call providers directly.
- If S05 needs new metadata for provider filtering or host scoping, thread it through `opts` and let providers decide whether they can honor it.

---

### Draft worker as the non-LiveView scope propagation analog

**Primary analog:** `lib/cairnloop/automation/workers/draft_worker.ex:33-58, 117-143`

**Boundary-owned context build**
```elixir
draft_context = %{
  conversation_id: conversation_id,
  query: query_builder.(conversation_id),
  clarification_attempts: (latest_draft && latest_draft.clarification_attempts) || 0,
  host_user_id: conversation.host_user_id,
  host_surface: "conversation"
}

retrieval_opts = [
  surface: :draft_generation,
  host_surface: draft_context.host_surface,
  host_user_id: draft_context.host_user_id
]
```

**Gap recording pattern**
```elixir
attrs = %{
  query: grounding_bundle.query || draft_context.query,
  surface: :draft_generation,
  outcome_class: diagnostic.class || :retrieval_error,
  reason: diagnostic.reason || :unexpected_error,
  host_user_id: draft_context.host_user_id,
  tenant_scope: draft_context.host_surface,
  canonical_hit_count: diagnostic.canonical_hit_count || 0,
  assistive_hit_count: diagnostic.assistive_hit_count || 0,
  clarification_attempts: grounding_bundle.clarification_attempts || 0,
  attempted_evidence: Map.get(grounding_bundle, :evidence, [])
}
```

**Recommended extension points**
- If S05 needs retrieval-boundary behavior outside LiveView, follow this worker pattern: assemble boundary context locally, then pass normalized retrieval opts separately.
- Keep product semantics at the worker boundary. Do not infer them later from telemetry or Oban state.

---

### Provider-side filtering in Ecto queries

**Primary analogs**
- `lib/cairnloop/retrieval/providers/resolved_cases.ex:20-44, 80-92, 155-159`
- `lib/cairnloop/retrieval/providers/knowledge_base.ex:23-44, 79-91, 150-151`

**Resolved-cases filter pattern to copy**
```elixir
host_user_id = Keyword.get(opts, :host_user_id)

ResolvedCaseChunk
|> join(:inner, [chunk], evidence in ResolvedCaseEvidence,
  on: evidence.id == chunk.resolved_case_evidence_id
)
|> maybe_filter_host_user(host_user_id)
|> where(
  [chunk, _evidence],
  fragment(
    "cairnloop_resolved_case_chunks.search_vector @@ websearch_to_tsquery('english', ?)",
    ^query
  )
)
```

```elixir
defp maybe_filter_host_user(query, nil), do: query

defp maybe_filter_host_user(query, host_user_id) do
  where(query, [_chunk, evidence], evidence.host_user_id == ^to_string(host_user_id))
end
```

**Knowledge-base seam to extend, not replace**
```elixir
host_user_id = Keyword.get(opts, :host_user_id)

Chunk
|> join(:inner, [chunk], revision in Revision, on: revision.id == chunk.revision_id)
|> join(:inner, [_chunk, revision], article in Article, on: article.id == revision.article_id)
|> where([_chunk, revision], revision.state == :published)
|> maybe_filter_host_user(host_user_id)
```

```elixir
defp maybe_filter_host_user(query, nil), do: query
defp maybe_filter_host_user(query, _host_user_id), do: query
```

**Recommended extension points**
- If S05 adds KB-side scope filtering, implement it in `KnowledgeBase.maybe_filter_host_user/2` or an equivalent provider-local helper. That is the paved extension seam.
- Keep provider-local filtering inside the query pipeline, before `limit/2` and `select/3`, matching `ResolvedCases`.
- Do not apply host filtering in `Retrieval.search/2`, the ranker, or any LiveView. The provider modules own query visibility boundaries.

**Important gap to preserve consciously**
- `ResolvedCases` already enforces `host_user_id`.
- `KnowledgeBase` currently exposes the same helper seam but intentionally no-ops it.
- If S05 changes KB filtering semantics, make that decision explicit in the provider and document it in tests. Do not leave a silent half-scope where only one provider honors the option.

---

### Verification and validation doc patterns for M009 phase artifacts

**Primary analogs**
- `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md:1-69`
- `.planning/milestones/M009-phases/M009-S02/M009-S02-VALIDATION.md:1-59`
- `.planning/milestones/M009-phases/M009-S02/M009-S02-01-PLAN.md:1-203`
- `.planning/milestones/M009-phases/M009-S04/M009-S04-03-PLAN.md` for scope/host propagation wording

**Validation frontmatter pattern**
```yaml
---
phase: M009-S04
slug: retrieval-telemetry-gap-signals
status: draft
nyquist_compliant: pending_execution
wave_0_complete: planned
created: 2026-05-20
---
```

**Test infrastructure table pattern**
```markdown
## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Quick run command** | `mix test ...` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~25-50 seconds |
```

**Per-task verification map pattern**
```markdown
## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| M009-S04-03-01 | 03 | 3 | M009-REQ-08, M009-REQ-09 | T-M009-S04-06, T-M009-S04-08 | Search and draft boundaries propagate host scope and record no-hit, retrieval-error, and weak-grounding evidence from the correct application seams | unit | `mix test ...` | ⬜ pending |
```

**Wave 0 checklist pattern**
```markdown
## Wave 0 Requirements

- [x] ... concrete scaffold or fixture expectation ...
```

**Recommended extension points**
- For S05 validation docs, keep the same section order: frontmatter, test infrastructure, sampling rate, per-task map, wave 0 requirements, manual-only verifications, validation sign-off.
- Make each verification row map one behavior to one or two specific commands. Do not hide multiple distinct risks behind one broad “mix test”.
- If S05 introduces shared-component mounting or provider-filtering changes, split quick-run commands by seam the way S04 split retrieval, storage, boundary, and LiveView checks.

---

### Test organization patterns for LiveView and retrieval boundary coverage

**Search component tests**

Source: `test/cairnloop/web/search_modal_component_test.exs:7-71, 73-236, 238-291`

**Use this injected-boundary style**
```elixir
defmodule MockRetrieval do
  def search("policy", opts) do
    send(self(), {:retrieval_search, "policy", opts})
    [%Result{...}, %Result{...}]
  end
end

defmodule MockGapRecorder do
  def record(attrs) do
    send(self(), {:gap_recorded, attrs})
    {:ok, attrs}
  end
end
```

**Use this mount helper style**
```elixir
{:ok, socket} = SearchModalComponent.mount(%Phoenix.LiveView.Socket{})

{:ok, socket} =
  SearchModalComponent.update(
    %{
      id: "search-modal",
      retrieval_module: MockRetrieval,
      gap_recorder: MockGapRecorder,
      host_surface: "conversation",
      host_user_id: "user_42",
      current_path: "/99",
      preserve_reply_form: true
    },
    socket
  )
```

**What to assert**
- shortcut contract: `test/cairnloop/web/search_modal_component_test.exs:73-100`
- local-only preview movement: `:114-135`
- open-on-enter without movement side effects: `:137-157`
- scope propagation and no-hit gap recording: `:213-236`

**Conversation surface tests**

Source: `test/cairnloop/web/conversation_live_test.exs:196-221, 312-457`

**Use rendered-shell assertions for shared component mounting**
```elixir
assert html =~ "data-host-surface=\"conversation\""
assert html =~ "data-host-user-id=\"user_42\""
assert html =~ "data-preserve-reply-form=\"true\""
```

**Use draft-rail assertions for trust-cue alignment**
```elixir
assert html =~ "Canonical guidance matched"
assert html =~ "Supporting evidence"
assert html =~ "Clarification required"
assert html =~ "Escalation recommended"
```

**Draft worker tests**

Source: `test/cairnloop/automation/workers/draft_worker_test.exs:25-76, 93-128, 145-200`

**Use opts-propagation assertions**
```elixir
assert_received {:ground_for_draft,
                 %{host_surface: "conversation", host_user_id: "user_42"},
                 [surface: :draft_generation, host_surface: "conversation", host_user_id: "user_42"]}
```

**Use boundary-persistence assertions**
```elixir
assert_received {:gap_recorded,
                 %{
                   surface: :draft_generation,
                   outcome_class: :policy_limit,
                   reason: :clarification_limit_reached,
                   host_user_id: "user_42",
                   tenant_scope: "conversation"
                 }}
```

**Retrieval contract and telemetry tests**

Sources
- `test/cairnloop/retrieval_test.exs:77-218`
- `test/cairnloop/retrieval/telemetry_test.exs:50-149`

**Use result-struct mocks, not raw maps, for retrieval behavior**
```elixir
%Result{
  source_type: :knowledge_base,
  trust_level: :canonical,
  citation_target: %{revision_id: 10, chunk_index: 0}
}
```

**Use telemetry attachment for bounded metadata checks**
```elixir
:telemetry.attach_many(
  handler_id,
  [Telemetry.search_event_name(), Telemetry.draft_grounding_event_name()],
  fn event, measurements, metadata, _config ->
    send(test_pid, {:telemetry_event, event, measurements, metadata})
  end,
  nil
)
```

**Recommended extension points**
- Put LiveView shell/mount assertions in the host surface test file, not in retrieval tests.
- Put provider-filtering and diagnostic taxonomy assertions in retrieval or worker tests, not in LiveView rendering tests.
- When a feature spans both surfaces and retrieval boundaries, pair one UI-level assertion file with one boundary-level assertion file. S04 already shows this split cleanly.

## Shared Patterns

### Scope values are passed twice on purpose

**Sources**
- `lib/cairnloop/web/search_modal_component.ex:35-44`
- `lib/cairnloop/web/search_modal_component.ex:469-475`
- `lib/cairnloop/automation/workers/draft_worker.ex:42-56`

Pattern:
- render host/surface values into assigns-backed DOM attrs for shell visibility and tests
- pass the same values into retrieval opts for provider filtering, telemetry, and durable evidence

Do not choose only one of those paths.

### Boundary code owns durable semantics

**Sources**
- `lib/cairnloop/web/search_modal_component.ex:288-305, 477-511`
- `lib/cairnloop/automation/workers/draft_worker.ex:56-58, 117-139`

Pattern:
- boundary decides `outcome_class` and `reason`
- boundary records durable evidence synchronously
- retrieval remains the normalized evidence source

### Provider modules own visibility filters

**Sources**
- `lib/cairnloop/retrieval/providers/resolved_cases.ex:20-44, 155-159`
- `lib/cairnloop/retrieval/providers/knowledge_base.ex:23-44, 150-151`

Pattern:
- retrieval passes opts through
- providers apply or intentionally ignore them
- tests must make the difference explicit

## No Exact Analog Found

| Concern | Closest Analog | Reason |
|---|---|---|
| Knowledge-base host scoping behavior beyond the current no-op seam | `lib/cairnloop/retrieval/providers/knowledge_base.ex:150-151` | The extension seam exists, but there is no implemented KB filter yet |
| A dedicated shared LiveView wrapper for search-like components beyond `SearchModalComponent` | `lib/cairnloop/web/search_modal_component.ex` mounts in host LiveViews | Shared mounting is repeated directly in each surface today rather than abstracted behind a wrapper component |
| S05-specific validation doc | `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md` | Adjacent phases define the doc shape, but S05 has no artifact yet |

## Summary

The paved road for S05 is already clear: mount shared LiveView components the same way `SearchModalComponent` is mounted now, carry `host_surface` and `host_user_id` as explicit assigns and retrieval opts, keep filtering inside provider query modules, and split verification between UI shell tests and retrieval-boundary tests. `ConversationLive` is the safest analog when new shared UI must coexist with reply/draft state, while `DraftWorker` is the analog for non-LiveView boundary propagation.

## Anti-Patterns To Avoid

- Do not move host filtering into `Retrieval.search/2`, rankers, or LiveViews; the provider modules own query visibility.
- Do not pass new scope only in assigns or only in opts. The existing pattern uses both rendered attrs and retrieval opts deliberately.
- Do not recompute `host_user_id` or `host_surface` inside shared components when the host LiveView already owns them.
- Do not collapse no-hit, weak-grounding, policy-limit, and retrieval-error branches into one generic failure bucket.
- Do not let local keyboard or preview interactions trigger fresh retrieval calls after results are loaded.
- Do not create an S05 validation artifact that skips the M009 conventions for frontmatter, per-task verification rows, and explicit quick-run commands.
