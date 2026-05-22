# Phase M009-S02 Verification

## Scope

This verification artifact closes the operator-search audit gap that remained after the original
M009-S02 implementation. Phase 2 already delivered the retrieval-backed palette, result
presentation, keyboard interaction model, and shared component mount surface. Phase M009-S05
backfilled the missing non-conversation scope enforcement and pre-ranking filter proof needed to
verify `M009-REQ-04` and `M009-REQ-05` end to end.

## M009-REQ-04

Operator can open a global `cmd+k` search and query Knowledge Base content plus similar resolved
cases from the LiveView dashboard.

### Implementation evidence

- `lib/cairnloop/web/conversation_live.ex`
  Conversation remains the reference path and mounts `SearchModalComponent` with
  `host_user_id={@conversation.host_user_id}`.
- `lib/cairnloop/web/inbox_live.ex`
  Inbox now reads `session["host_user_id"]` in `mount/3`, stores it on the socket, and passes it
  into the shared search component.
- `lib/cairnloop/web/settings_live.ex`
  Settings now reads `session["host_user_id"]` in `mount/3`, stores it on the socket, and passes
  it into the shared search component.
- `lib/cairnloop/router.ex`
  The `cairnloop_dashboard` live session now documents the host-app contract that dashboard
  surfaces must supply `host_user_id` for tenant-scoped operator search.
- `lib/cairnloop/web/search_modal_component.ex`
  The shared component distinguishes `:scoped_unavailable`, `:no_hit`, and `:error` states and
  fails closed on surfaces that require scope when `host_user_id` is absent.

### Automated evidence

- `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/search_modal_component_test.exs`
- `test/cairnloop/web/inbox_live_test.exs`
  Asserts Inbox renders the search component with explicit `data-host-user-id`.
- `test/cairnloop/web/settings_live_test.exs`
  Asserts Settings stores `session["host_user_id"]` and renders the shared search component with
  explicit `data-host-user-id`.
- `test/cairnloop/web/conversation_live_test.exs`
  Preserves conversation-surface search behavior while existing draft and trust-state coverage
  continues to pass.
- `test/cairnloop/web/search_modal_component_test.exs`
  Proves the search palette passes scope metadata into retrieval and fails closed with a
  scoped-unavailable state when a non-conversation surface lacks `host_user_id`.

### Manual checks

- Open Inbox with a valid dashboard session and confirm `cmd+k` still opens the shared search
  palette.
- Open Settings with a valid dashboard session and confirm the palette stays shared rather than
  forking into a surface-specific implementation.
- Render Inbox or Settings without `host_user_id` and confirm the copy says scoped search is
  unavailable on that surface rather than presenting a generic outage or a partially filtered
  search.

## M009-REQ-05

Search results enforce tenant and visibility filtering before ranking and show clear source cues
such as content type, recency, and citation target.

### Implementation evidence

- `lib/cairnloop/retrieval.ex`
  Adds an explicit retrieval boundary guard that rejects dashboard `:search_modal` searches when a
  required `host_user_id` is missing, preventing unsafe candidates from reaching `Ranker.merge/3`.
- `lib/cairnloop/retrieval/providers/resolved_cases.ex`
  Returns no candidates when `host_user_id` is absent and continues to apply tenant filtering on
  both keyword and semantic query paths before any merge step.
- `lib/cairnloop/retrieval/providers/knowledge_base.ex`
  Keeps published-only visibility enforcement and removes the misleading host-user no-op seam
  rather than pretending Knowledge Base has a tenant predicate it does not support.
- `lib/cairnloop/web/search_modal_component.ex`
  Preserves `Knowledge Base` versus `Similar resolved cases` trust cues while adding
  scoped-unavailable and no-hit handling.

### Automated evidence

- `mix test test/cairnloop/retrieval_test.exs`
- `test/cairnloop/retrieval_test.exs`
  Proves `Retrieval.search/2` returns `{:error, :scope_unavailable}` for unscoped dashboard
  searches and that the ranker is not called in that path.
- `test/cairnloop/web/search_modal_component_test.exs`
  Preserves source/trust rendering, no-hit state, and retrieval-error handling after the scope
  changes.

### Manual checks

- Run one scoped search that returns both source types and confirm Knowledge Base remains visually
  primary while resolved cases remain assistive evidence only.
- Inspect one no-hit search and confirm the palette keeps canonical-versus-assistive trust language
  instead of collapsing into a generic empty state.
- Inspect one retrieval error and confirm it remains distinct from scoped-unavailable and no-hit.

## Backfill Summary

- Original M009-S02 delivery: retrieval-backed shared palette, interaction model, result presenter,
  and baseline dashboard integration.
- M009-S05 backfill: `session["host_user_id"]` propagation for non-conversation surfaces,
  fail-closed search behavior, pre-ranking scope enforcement, provider-side contract cleanup, and
  requirement-level verification evidence.
