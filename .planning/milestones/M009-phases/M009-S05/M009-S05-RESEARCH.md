# Phase M009-S05: Search Scope Enforcement & Operator Search Closure - Research

**Researched:** 2026-05-20
**Domain:** LiveView search scope propagation, retrieval provider enforcement, and verification backfill
**Confidence:** HIGH

## User Constraints

- Phase goal: close the remaining operator-search blocker by enforcing tenant and visibility scope on every mounted surface and provider path. [VERIFIED: .planning/M009-ROADMAP.md]
- Requirements in scope: `M009-REQ-04` and `M009-REQ-05`. [VERIFIED: .planning/REQUIREMENTS.md]
- Success criteria:
  1. Inbox, Settings, and conversation surfaces all pass the user/scope context needed for retrieval safely. [VERIFIED: .planning/M009-ROADMAP.md]
  2. `KnowledgeBase` and `ResolvedCases` enforce tenant and visibility filtering before ranking on every search path. [VERIFIED: .planning/M009-ROADMAP.md]
  3. Phase 2 receives explicit verification evidence showing operator search now satisfies the full filtering contract. [VERIFIED: .planning/M009-ROADMAP.md]
- Audit gap to close: `SearchModalComponent` forwards `host_surface` and `host_user_id`, but Inbox and Settings do not pass `host_user_id`; `ResolvedCases` filters only when present; `KnowledgeBase` ignores the filter. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md] [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex]
- Preserve the existing M009 trust contract: canonical Knowledge Base truth first, resolved cases second as assistive evidence only, and retrieval remains server-owned through `Cairnloop.Retrieval`. [VERIFIED: .planning/milestones/M009-phases/M009-S02-CONTEXT.md] [VERIFIED: .planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M009-REQ-04 | Operator can open a global `cmd+k` search and query Knowledge Base content plus similar resolved cases from the LiveView dashboard. [VERIFIED: .planning/REQUIREMENTS.md] | Require every LiveView mount that renders `SearchModalComponent` to provide scoped retrieval context or fail closed, and cover non-conversation mounts with render and retrieval-path tests. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] |
| M009-REQ-05 | Search results enforce tenant and visibility filtering before ranking and show clear source cues such as content type, recency, and citation target. [VERIFIED: .planning/REQUIREMENTS.md] | Push scope checks into provider queries before candidate ranking, preserve existing source/trust cues, and add verification evidence that no provider path returns unscoped results. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/web/search_result_presenter.ex] |
</phase_requirements>

## Summary

This phase is a gap-closure pass, not a redesign. The current search architecture is already correct at a high level: LiveViews mount `SearchModalComponent`, the component calls `Cairnloop.Retrieval.search/2`, and the retrieval facade delegates to `KnowledgeBase`, `ResolvedCases`, and the shared ranker before returning normalized `Retrieval.Result` structs. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/retrieval/result.ex]

The blocker is that scope enforcement is incomplete at both ends. Conversation search passes `host_user_id`, but Inbox and Settings mount the component without it, leaving `ResolvedCases` effectively optional on tenant filtering and leaving `KnowledgeBase` as a total no-op for the same option. Because ranking happens after both provider queries return candidates, the missing filters violate the requirement language exactly where the audit says they do: before ranking. [VERIFIED: lib/cairnloop/web/conversation_live.ex] [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]

The implementation-ready recommendation is to keep `Cairnloop.Retrieval` as the only public search seam, make scope presence a mount-time contract for every `SearchModalComponent` surface, and make provider-side filtering fail closed when the required scope is absent. For Knowledge Base, the real enforceable visibility gate available in the current schema is published revision state; there is no per-user tenant field in `Article` or `Revision`, so this phase should not invent a fake tenant predicate there. Instead, the planner should encode the distinction explicitly: resolved-case provider enforces tenant scope via `host_user_id`, Knowledge Base provider enforces visibility via published-state-only content, and the shared retrieval entrypoint refuses unscoped search for surfaces that require tenant safety. [VERIFIED: lib/cairnloop/knowledge_base/article.ex] [VERIFIED: lib/cairnloop/knowledge_base/revision.ex] [VERIFIED: lib/cairnloop/retrieval/resolved_case_evidence.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [ASSUMED]

**Primary recommendation:** Add an explicit `host_user_id` acquisition/fail-closed contract to Inbox and Settings mounts, enforce `host_user_id` filtering in `ResolvedCases` on every path, preserve published-only visibility enforcement in `KnowledgeBase`, and backfill Phase 2 with mount-level and provider-level verification evidence rather than UI-only smoke evidence. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Surface scope acquisition for operator search | Frontend Server (LiveView) | Browser / Client | Inbox, Settings, and conversation mounts decide what context is available to the shared search component. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] |
| Search boundary contract | API / Backend | Frontend Server (LiveView) | `SearchModalComponent` is the UI caller, but `Cairnloop.Retrieval.search/2` is the server-owned boundary that must reject or classify unscoped calls safely. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/retrieval.ex] |
| Tenant filtering for resolved-case evidence | Database / Storage | API / Backend | The actual tenant discriminator available today is `ResolvedCaseEvidence.host_user_id`, so the provider query owns this predicate before any ranking. [VERIFIED: lib/cairnloop/retrieval/resolved_case_evidence.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] |
| Visibility filtering for Knowledge Base evidence | Database / Storage | API / Backend | The current Knowledge Base visibility boundary is published revision state; that filter already exists in the provider query and must remain the only source of canonical KB visibility until the schema grows. [VERIFIED: lib/cairnloop/knowledge_base/revision.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] |
| Result ranking and trust ordering | API / Backend | — | `Ranker.merge/3` sorts after both providers return candidates, so provider filtering must complete before the ranker runs. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] |
| Verification evidence for closure | Frontend Server (LiveView) | API / Backend | Phase 2 closure needs both rendered-surface evidence and retrieval/provider assertions; current tests prove mostly the former. [VERIFIED: test/cairnloop/web/search_modal_component_test.exs] [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs] [VERIFIED: test/cairnloop/retrieval_test.exs] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | repo `1.1.30`; current stable line still includes `1.1.30`, with `1.2.0-rc.*` also published upstream. [VERIFIED: mix.lock] [CITED: https://hex.pm/packages/phoenix_live_view] | Shared dashboard surfaces and `SearchModalComponent` mounts. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] | This phase is mount-contract and render-contract work inside existing LiveViews, not a UI stack change. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] |
| Ecto / Ecto SQL | repo `ecto 3.13.6`, `ecto_sql 3.13.5`; upstream now has `ecto 3.14.0`, while `ecto_sql 3.13.5` is the currently pinned repo version. [VERIFIED: mix.lock] [CITED: https://hex.pm/packages/ecto] [CITED: https://hex.pm/packages/ecto_sql/versions] | Provider query predicates and any fail-closed scope helpers. [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] | The needed enforcement is query-layer filtering with no new data-access abstraction. [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] |
| `Cairnloop.Retrieval` + `Cairnloop.Retrieval.Ranker` | repo modules [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] | Single public search seam and post-filter ranking boundary. [VERIFIED: lib/cairnloop/retrieval.ex] | All scope enforcement should stay behind this facade so UI surfaces do not guess filtering rules. [VERIFIED: .planning/milestones/M009-phases/M009-S02-CONTEXT.md] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Phoenix.LiveViewTest` | bundled with LiveView `1.1.30`. [VERIFIED: mix.lock] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Mount/render assertions for Inbox, Settings, and conversation surfaces. [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs] [VERIFIED: test/cairnloop/web/conversation_live_test.exs] | Use for DOM contract checks and, where interactive event scoping matters, for full `live/2` tests rather than isolated component rendering. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| `:telemetry` | repo `1.4.1`; upstream `1.4.2` exists. [VERIFIED: mix.lock] [CITED: https://hex.pm/packages/telemetry] | Preserve the existing bounded search telemetry while fixing scope propagation. [VERIFIED: lib/cairnloop/retrieval/telemetry.ex] | Use to verify the surface label remains correct after scope changes; do not expand Phase 5 into new telemetry design. [VERIFIED: test/cairnloop/retrieval/telemetry_test.exs] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Fail-closed search when required scope is missing | Best-effort unscoped search from Inbox/Settings | Violates the audit finding and `M009-REQ-05` because tenant filtering becomes optional. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md] |
| Provider-owned filtering before ranking | Rank first, then hide rows in the presenter | Too late; `Ranker.merge/3` has already mixed unsafe candidates. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] |
| Explicit schema-aware distinction between tenant and visibility enforcement | Pretend KB and resolved cases share the same tenant predicate | The current Knowledge Base schema has no tenant field, so that recommendation would be false. [VERIFIED: lib/cairnloop/knowledge_base/article.ex] [VERIFIED: lib/cairnloop/knowledge_base/revision.ex] |

**Installation:** No new dependency is required. This phase should stay inside the existing LiveView, Ecto, and retrieval modules. [VERIFIED: mix.exs] [VERIFIED: mix.lock]

**Version verification:** This is not a dependency-upgrade phase. Use the repo-pinned versions above for implementation compatibility, while noting current upstream package versions where relevant. [VERIFIED: mix.lock] [CITED: https://hex.pm/packages/phoenix_live_view] [CITED: https://hex.pm/packages/ecto] [CITED: https://hex.pm/packages/ecto_sql/versions] [CITED: https://hex.pm/packages/telemetry] [CITED: https://hex.pm/packages/oban/versions] [CITED: https://hex.pm/packages/pgvector/versions]

## Architecture Patterns

### System Architecture Diagram

```text
InboxLive / SettingsLive / ConversationLive
        |
        v
 SearchModalComponent
        |
        +-- requires host_surface
        +-- requires host_user_id for tenant-safe search
        |        |
        |        +-- missing -> fail closed / scoped unavailable state
        |
        v
 Cairnloop.Retrieval.search/2
        |
        +--> KnowledgeBase provider
        |      |
        |      +-- published revision visibility filter
        |
        +--> ResolvedCases provider
               |
               +-- host_user_id tenant filter on keyword path
               +-- host_user_id tenant filter on semantic path
        |
        v
 Ranker.merge/3
        |
        v
 normalized Retrieval.Result[] -> SearchResultPresenter -> UI sections / preview
```

### Recommended Project Structure
```text
lib/cairnloop/web/inbox_live.ex                  # Acquire/pass scope for inbox search
lib/cairnloop/web/settings_live.ex               # Acquire/pass scope for settings search
lib/cairnloop/web/conversation_live.ex           # Keep existing scoped mount as reference
lib/cairnloop/web/search_modal_component.ex      # Fail-closed search boundary and scoped opts
lib/cairnloop/retrieval.ex                       # Optional guard/helper for required scope
lib/cairnloop/retrieval/providers/knowledge_base.ex  # Visibility enforcement before ranking
lib/cairnloop/retrieval/providers/resolved_cases.ex  # Tenant enforcement before ranking
test/cairnloop/web/inbox_live_test.exs           # Mount contract assertions
test/cairnloop/web/settings_live_test.exs        # Mount contract assertions
test/cairnloop/web/search_modal_component_test.exs   # Fail-closed and scoped search assertions
test/cairnloop/retrieval_test.exs                # Provider/ranker contract assertions
```

### Pattern 1: Mount-Time Scope Contract
**What:** Every LiveView that mounts `SearchModalComponent` must either pass a real `host_user_id` or intentionally disable scoped search. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex]
**When to use:** Inbox, Settings, any future shared dashboard surface. [VERIFIED: lib/cairnloop/web/search_modal_component.ex]
**Example:**
```elixir
# Source: lib/cairnloop/web/conversation_live.ex
<.live_component
  module={Cairnloop.Web.SearchModalComponent}
  id="search-modal"
  host_surface="conversation"
  host_user_id={@conversation.host_user_id}
  current_path={"/#{@conversation.id}"}
  preserve_reply_form={true}
/>
```

### Pattern 2: Filter Before Merge
**What:** Apply provider predicates in `keyword_candidates/3` and `semantic_candidates/3` before results are merged and ranked. [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex]
**When to use:** All retrieval-backed search paths, not just `SearchModalComponent`. [VERIFIED: lib/cairnloop/retrieval.ex]
**Example:**
```elixir
# Source: lib/cairnloop/retrieval/providers/resolved_cases.ex, https://hexdocs.pm/ecto/Ecto.Query.html
ResolvedCaseChunk
|> join(:inner, [chunk], evidence in ResolvedCaseEvidence,
  on: evidence.id == chunk.resolved_case_evidence_id
)
|> where([_chunk, evidence], evidence.host_user_id == ^to_string(host_user_id))
|> order_by([chunk, _evidence], fragment("? <-> ?", chunk.embedding, ^Pgvector.new(embedding_vector)))
```

### Pattern 3: Full LiveView Test for Mounted Component Behavior
**What:** Use `live/2` when the planner needs to prove mounted component wiring and DOM event behavior together; keep `render_component/1` only for static assign checks. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
**When to use:** The backfill evidence for non-conversation surfaces and scoped palette interactions. [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs]
**Example:**
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
{:ok, view, _html} = live(conn, "/settings")
assert view |> element("#search-modal-search-root") |> render() =~ "data-host-user-id"
```

### Anti-Patterns to Avoid
- **Best-effort scope fallback:** Do not allow Inbox or Settings to search resolved cases when `host_user_id` is absent. That recreates the blocker. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]
- **Presenter-layer filtering:** Do not hide unsafe results in `SearchResultPresenter`; by then ranking already consumed them. [VERIFIED: lib/cairnloop/retrieval/ranker.ex] [VERIFIED: lib/cairnloop/web/search_result_presenter.ex]
- **Invented Knowledge Base tenant predicates:** There is no KB tenant column in the current schema. Do not document or implement a fictitious filter. [VERIFIED: lib/cairnloop/knowledge_base/article.ex] [VERIFIED: lib/cairnloop/knowledge_base/revision.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interactive mounted-component proof | Ad hoc socket-state assertions only | `Phoenix.LiveViewTest.live/2` where mount wiring matters | Official LiveView docs require a real LiveView for mounted component interaction tests. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| Query filtering DSL | Custom post-processing over result lists | Ecto `where/3` in provider queries | The required enforcement point is the SQL query before ranking. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |
| New search abstraction | Separate “scoped search service” module | Existing `Cairnloop.Retrieval.search/2` facade | The repo already has the correct public boundary. [VERIFIED: lib/cairnloop/retrieval.ex] |

**Key insight:** The code already centralizes ranking and result normalization. Phase 5 should tighten the contract at the mounts and providers, not add another layer. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] [VERIFIED: lib/cairnloop/retrieval/result.ex]

## Common Pitfalls

### Pitfall 1: Treating `host_surface` as tenant scope
**What goes wrong:** Gap records and UI labels use `"conversation"`, `"inbox"`, or `"settings"` as if they were security scope. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex]
**Why it happens:** The repo currently persists `tenant_scope: host_surface`. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex]
**How to avoid:** Keep UI surface metadata separate from tenant discriminator semantics in planning and verification. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]
**Warning signs:** Tests pass while `tenant_scope` still equals `"settings"` or `"inbox"`. [VERIFIED: test/cairnloop/web/search_modal_component_test.exs] [VERIFIED: test/cairnloop/automation/workers/draft_worker_test.exs]

### Pitfall 2: Relying on conversation coverage as proof for all surfaces
**What goes wrong:** Search seems scoped because conversation tests pass, but Inbox and Settings remain unscoped. [VERIFIED: test/cairnloop/web/conversation_live_test.exs] [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs]
**Why it happens:** Only conversation render tests assert `data-host-user-id` today. [VERIFIED: test/cairnloop/web/conversation_live_test.exs]
**How to avoid:** Add explicit non-conversation mount assertions and at least one end-to-end scoped search test outside conversation. [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs]
**Warning signs:** Inbox/Settings tests assert `data-host-surface` but never `data-host-user-id`. [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs]

### Pitfall 3: Assuming KB needs the same tenant predicate as resolved cases
**What goes wrong:** Planning adds speculative schema work or bogus query conditions. [VERIFIED: lib/cairnloop/knowledge_base/article.ex] [VERIFIED: lib/cairnloop/knowledge_base/revision.ex]
**Why it happens:** Requirement language says “tenant and visibility filtering,” but the two providers do not share the same data model. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/cairnloop/retrieval/resolved_case_evidence.ex]
**How to avoid:** Write provider-specific enforcement tasks: tenant on resolved cases, visibility on KB, shared fail-closed behavior at the boundary. [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex]
**Warning signs:** A proposed change adds `host_user_id` filtering to KB without a backing column. [VERIFIED: lib/cairnloop/knowledge_base/article.ex] [VERIFIED: lib/cairnloop/knowledge_base/revision.ex]

## Code Examples

### Existing Scoped Search Opts
```elixir
# Source: lib/cairnloop/web/search_modal_component.ex
defp search_opts(socket) do
  [
    surface: :search_modal,
    host_surface: socket.assigns.host_surface,
    host_user_id: socket.assigns.host_user_id
  ]
end
```

### Existing Resolved-Case Tenant Filter
```elixir
# Source: lib/cairnloop/retrieval/providers/resolved_cases.ex
defp maybe_filter_host_user(query, host_user_id) do
  where(query, [_chunk, evidence], evidence.host_user_id == ^to_string(host_user_id))
end
```

### Existing Knowledge Base Visibility Gate
```elixir
# Source: lib/cairnloop/retrieval/providers/knowledge_base.ex
|> where([_chunk, revision], revision.state == :published)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UI-only search wiring evidence | Scope-aware retrieval boundary with provider-specific enforcement and mounted-surface tests | M009 Phase 4 added scope metadata to real search/draft boundaries on 2026-05-20. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-03-SUMMARY.md] | Phase 5 can close the gap by finishing enforcement and verification rather than reworking the search UX. |
| Generic telemetry/gap scope naming | Explicit distinction needed between UI surface and security scope | Audit recorded on 2026-05-20. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md] | Verification must prove the filtering contract, not just the event shape. |

**Deprecated/outdated:**
- “Search works if the component forwards scope” is outdated. The audit shows forwarding alone is insufficient without mount coverage and provider enforcement. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Inbox and Settings should fail closed when they cannot obtain `host_user_id`, rather than allowing KB-only or partially scoped search. | Summary | If the host app expects a different fallback, the implementation plan may block a surface the product owner wanted to keep partially available. |
| A2 | `M009-REQ-05` can be satisfied for Knowledge Base in this phase by published-state visibility enforcement plus shared boundary refusal of unscoped search, without adding a new KB tenant column. | Summary | If product intent actually requires per-tenant KB partitioning, this phase would need schema work and likely exceeds its current goal. |

## Open Questions (RESOLVED)

1. **Where should Inbox and Settings get `host_user_id` from?**
   - Resolution: use the existing LiveView session payload as the explicit non-conversation scope source. `InboxLive.mount/3` and `SettingsLive.mount/3` should read `session["host_user_id"]`, assign it, and pass it through to `SearchModalComponent`. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/router.ex]
   - Why this is the right seam: the dashboard already runs inside one `live_session`, the router macro already exposes that seam to the host app, and the repo has no better established `current_user` or `on_mount` contract to reuse. [VERIFIED: lib/cairnloop/router.ex]
   - Planning consequence: `lib/cairnloop/router.ex` must document or encode the session contract so host apps know they must supply `host_user_id` for scoped operator search on Inbox and Settings.

2. **Does product intent allow KB-only search when resolved-case tenant scope is unavailable?**
   - Resolution: no. Inbox and Settings must fail closed when `session["host_user_id"]` is absent; they should not fall back to KB-only or partially scoped search. [VERIFIED: .planning/M009-ROADMAP.md] [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]
   - Why: the phase goal is explicit about enforcing scope safely on every mounted surface, and a KB-only fallback would still leave the operator flow partially broken while claiming closure. [VERIFIED: .planning/M009-ROADMAP.md]
   - Planning consequence: the search component needs a distinct scoped-unavailable state, and verification must assert that unscoped non-conversation search does not reach retrieval/ranking.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Build and tests | ✓ | `1.19.5` [VERIFIED: local command `elixir --version`] | — |
| Mix | Test execution | ✓ | `1.19.5` [VERIFIED: local command `mix --version`] | — |
| PostgreSQL client | Optional local DB diagnostics | ✓ | `psql 14.17` [VERIFIED: local command `psql --version`] | Not required for the targeted mocked tests |
| Docker | Optional local service bring-up | ✓ | `29.4.1` [VERIFIED: local command `docker --version`] | — |

**Missing dependencies with no fallback:**
- None for research or the currently targeted mocked test surface. [VERIFIED: local environment audit]

**Missing dependencies with fallback:**
- Live DB configuration for `Chimeway.Repo` is absent in this workspace, but the targeted search/retrieval tests still pass because they use mocks. [VERIFIED: local `mix test` run] [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with Phoenix LiveView test helpers. [VERIFIED: test/cairnloop/web/inbox_live_test.exs] [VERIFIED: test/cairnloop/web/settings_live_test.exs] [VERIFIED: test/cairnloop/web/conversation_live_test.exs] |
| Config file | none found. [VERIFIED: repo file inventory] |
| Quick run command | `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/automation/workers/draft_worker_test.exs` [VERIFIED: local `mix test` run] |
| Full suite command | `mix test` [ASSUMED] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| M009-REQ-04 | Inbox, Settings, and conversation mounts all provide the scoped search contract. [VERIFIED: .planning/M009-ROADMAP.md] | render + live integration | `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/search_modal_component_test.exs` | Inbox/Settings/conversation files exist; missing full live scoped interaction coverage. [VERIFIED: test file inventory] |
| M009-REQ-05 | Provider queries enforce filtering before ranking and trust cues remain intact. [VERIFIED: .planning/REQUIREMENTS.md] | unit + integration | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/web/search_modal_component_test.exs` | Files exist; missing provider-path scope assertions. [VERIFIED: test file inventory] |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval_test.exs`
- **Per wave merge:** `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/automation/workers/draft_worker_test.exs`
- **Phase gate:** Re-run the targeted milestone suite used by the audit once new verification evidence is added. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]

### Wave 0 Gaps
- [ ] Extend [test/cairnloop/web/inbox_live_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/web/inbox_live_test.exs:1) to assert `data-host-user-id` or explicit fail-closed copy, not just `data-host-surface`.
- [ ] Extend [test/cairnloop/web/settings_live_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/web/settings_live_test.exs:1) the same way.
- [ ] Add provider-focused scope tests in [test/cairnloop/retrieval_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/retrieval_test.exs:1) or a new provider test file so both keyword and semantic paths prove filtering before merge.
- [ ] Add one mounted LiveView interaction test proving non-conversation search cannot run unscoped. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- [ ] Create `M009-S02` verification evidence that cites the new tests and the targeted rerun output. [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host app authentication is outside this phase. [ASSUMED] |
| V3 Session Management | yes | Use existing LiveView session/mount inputs as the source for scoped search context. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [ASSUMED] |
| V4 Access Control | yes | Provider-side filtering before ranking, plus fail-closed behavior when required scope is absent. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] [ASSUMED] |
| V5 Input Validation | yes | Keep search query handling inside the existing LiveView and retrieval boundary; avoid new raw SQL or direct route guessing. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: .planning/milestones/M009-phases/M009-S02-CONTEXT.md] |
| V6 Cryptography | no | No new crypto requirements beyond existing gap-event fingerprinting, which is out of scope for this phase. [VERIFIED: lib/cairnloop/retrieval/gap_recorder.ex] |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant resolved-case disclosure | Information Disclosure | Require `host_user_id` at the search boundary and apply the predicate in both resolved-case query paths. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] |
| Unsafe ranking of out-of-scope results | Information Disclosure | Filter in provider queries before `Ranker.merge/3`. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex] |
| Scope confusion between UI surface and security scope | Tampering | Keep `host_surface` for diagnostics/UI only; do not treat it as the tenant discriminator in closure evidence. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md] |

## Sources

### Primary (HIGH confidence)
- Local codebase files listed in the user prompt and adjacent tests/providers. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/providers/knowledge_base.ex] [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: test/cairnloop/web/search_modal_component_test.exs] [VERIFIED: test/cairnloop/web/conversation_live_test.exs]
- Planning artifacts and audit: [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/M009-ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/vM009-vM009-MILESTONE-AUDIT.md] [VERIFIED: .planning/milestones/M009-phases/M009-S02-CONTEXT.md] [VERIFIED: .planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-RESEARCH.md]
- Local environment/test audit: targeted `mix test` run on 2026-05-20 passed `23 tests, 0 failures` despite known `Chimeway.Repo` startup noise. [VERIFIED: local `mix test` run]

### Secondary (MEDIUM confidence)
- Phoenix LiveComponent docs for `mount/1`, `update/2`, and mounted component behavior. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html]
- Phoenix LiveView test docs for when to use `live/2` with mounted components. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- Ecto query docs for query-layer filtering patterns. [CITED: https://hexdocs.pm/ecto/Ecto.Query.html]
- Hex package pages for current package version verification. [CITED: https://hex.pm/packages/phoenix_live_view] [CITED: https://hex.pm/packages/ecto] [CITED: https://hex.pm/packages/ecto_sql/versions] [CITED: https://hex.pm/packages/telemetry] [CITED: https://hex.pm/packages/oban/versions] [CITED: https://hex.pm/packages/pgvector/versions]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new libraries are needed and repo-pinned tooling is clear. [VERIFIED: mix.lock]
- Architecture: HIGH - the gap is directly observable in local mounts, providers, and ranker flow. [VERIFIED: lib/cairnloop/web/inbox_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: lib/cairnloop/retrieval.ex]
- Pitfalls: MEDIUM - the UI-surface-vs-tenant-scope distinction is clear in code, but product-approved fail-closed behavior for Inbox/Settings still needs confirmation. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [ASSUMED]

**Research date:** 2026-05-20
**Valid until:** 2026-06-19

## RESEARCH COMPLETE
