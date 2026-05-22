# Phase M009-S02: Operator Search Experience - Research

**Researched:** 2026-05-17
**Domain:** Phoenix LiveView operator search UX over host-owned retrieval APIs
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md) [VERIFIED: `.planning/milestones/M009-phases/M009-S02-CONTEXT.md`]

### Locked Decisions
- **D-04 to D-09:** Use one global `cmd+k` search surface with fixed source-aware sections: `Knowledge Base` first and `Similar resolved cases` second. Do not default to a single mixed list. Ranking truth stays server-owned.
- **D-10 to D-17:** Preview on focus, open on confirm. Knowledge Base hits are canonical destinations; resolved cases are assistive evidence with structured preview before navigation. Preserve operator session context, especially in `ConversationLive`.
- **D-18 to D-24:** Upgrade the modal into a bounded retrieval-first palette with keyboard parity, debounce-to-server search, and a cleaner shortcut model than the current unfiltered `phx-window-keydown`.
- **D-25 to D-31:** Every row needs visible source, trust label, title, snippet, recency, and a direct source action. Do not expose numeric scores. Resolved-case content must stay clearly assistive.
- **D-32 to D-35:** Route everything through `Cairnloop.Retrieval` and the normalized result contract. Do not invent UI-owned ranking or direct HTTP search calls.

### Important Discretion Areas
- The exact preview-pane composition on desktop vs mobile.
- Whether the component derives explicit destinations from `Retrieval.Result.metadata` or from a small presenter layer over the result struct.
- Whether shortcut filtering is implemented with a filtered `phx-window-keydown` contract only, or with a small JS hook if the host app exposes an asset bootstrap.
</user_constraints>

<phase_requirements>
## Phase Requirements [VERIFIED: `.planning/REQUIREMENTS.md` + `.planning/M009-ROADMAP.md`]

| ID | Description | Planning Implication |
|----|-------------|----------------------|
| M009-REQ-04 | Operator can open a global `cmd+k` search and query Knowledge Base content plus similar resolved cases from the LiveView dashboard. | Search must mount consistently in Inbox, Conversation, and Settings; query the existing retrieval facade; and support keyboard-first open, move, preview, and confirm flows. |
| M009-REQ-05 | Search results enforce tenant and visibility filtering before ranking and show clear source cues such as content type, recency, and citation target. | UI must render trust/source labels and recency from retrieval-backed metadata, while providers must expose enough metadata for destination/citation rendering without client-side guesswork. |
</phase_requirements>

## Summary

The repo already has the essential retrieval substrate for this phase but the current operator search implementation is still Phase 3-era scaffolding. `Cairnloop.Web.SearchModalComponent` opens with a global `phx-window-keydown`, posts directly to Scrypath via `Req`, renders one flat list, guesses destinations from raw result maps, and has only a placeholder test. That directly conflicts with the Phase 2 context, which requires a retrieval-first, source-aware, preview-capable operator surface. [VERIFIED: `lib/cairnloop/web/search_modal_component.ex` + `test/cairnloop/web/search_modal_component_test.exs`]

The good news is that M009-S01 already created the internal retrieval boundary this phase wants. `Cairnloop.Retrieval.search/2` merges `knowledge_base` and `resolved_case` results, and `Cairnloop.Retrieval.Result` already carries `source_type`, `trust_level`, `citation_target`, and ranking metadata. The main planning gap is that the current provider payload is not yet rich enough for the Phase 2 UI contract: the palette needs explicit destination/preview metadata such as article identifiers, recency labels, and resolved-case preview fields, not just `title`, `content`, and a citation target. [VERIFIED: `lib/cairnloop/retrieval.ex` + `lib/cairnloop/retrieval/result.ex` + `lib/cairnloop/retrieval/providers/knowledge_base.ex` + `lib/cairnloop/retrieval/providers/resolved_cases.ex`]

The host-surface constraint is also real. This library repo exposes LiveViews and the dashboard router macro, but it does not include a normal `assets/js/app.js` tree. That means the implementation plan cannot assume a host-controlled JS hook is already available. The safest planning path is: first get the retrieval-backed palette working with a filtered keyboard contract that avoids the current unbounded event stream, then add a minimal client hook only if a real bootstrap point exists or can be created without overreaching phase scope. [VERIFIED: `lib/cairnloop/router.ex` + repo root file layout + `README.md`]

**Primary recommendation:** Split execution into two waves. Wave 1 should extend retrieval/provider metadata and replace the direct HTTP modal with a retrieval-backed, sectioned palette shell. Wave 2 should add preview/open behavior, source-aware destination handling, and host-surface tests that protect `ConversationLive` draft state and keyboard behavior. This keeps the trust semantics and UI shell correct before layering richer interaction behavior.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Search query + ranking | API / Backend | Database / Storage | `Cairnloop.Retrieval` already owns this; UI must not re-rank. |
| Source/trust/result normalization | API / Backend | UI presenter | Providers should emit canonical metadata; a presenter may format labels/sections without changing ranking truth. |
| Palette open/close, active row, preview state | LiveComponent / LiveView | Browser | This is local UI state that belongs in `SearchModalComponent`. |
| Keyboard shortcut filtering | Browser + LiveView event contract | — | Needs to avoid noisy global key events and accidental capture while typing elsewhere. |
| Navigation destination resolution | Retrieval metadata + presenter | Host LiveView | Context forbids route guessing inside the modal. |
| Conversation-state preservation | Host LiveView | Search component | Opening and closing search must not wipe draft/reply state in `ConversationLive`. |

## Existing Code Realities

### What can be reused
- `Cairnloop.Retrieval.search/2` already provides one internal search boundary. [VERIFIED: `lib/cairnloop/retrieval.ex`]
- `Cairnloop.Retrieval.Result` and `Cairnloop.Retrieval.Ranker` already encode source/trust semantics. [VERIFIED: `lib/cairnloop/retrieval/result.ex` + `lib/cairnloop/retrieval/ranker.ex`]
- Search modal is already mounted in Inbox, Conversation, and Settings, so there is one shared integration point. [VERIFIED: `lib/cairnloop/web/inbox_live.ex` + `lib/cairnloop/web/conversation_live.ex` + `lib/cairnloop/web/settings_live.ex`]

### What is missing
- KB provider rows do not expose `article_id`, revision timestamps, or any explicit internal destination metadata for canonical opening flows. [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`]
- Resolved-case provider rows do not expose preview-friendly fields such as `issue_summary`, `resolution_note`, `actions_taken`, `outcome`, or `resolved_at`. [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`]
- The component has no concept of active row, preview pane, grouped sections, section-empty states, loading state continuity, or new-tab open semantics. [VERIFIED: `lib/cairnloop/web/search_modal_component.ex`]
- Tests are skeletal and do not verify retrieval integration, section ordering, or keyboard contracts. [VERIFIED: `test/cairnloop/web/search_modal_component_test.exs`]

## Recommended Structure

```text
lib/cairnloop/
├── retrieval/
│   ├── result.ex
│   ├── providers/knowledge_base.ex
│   └── providers/resolved_cases.ex
└── web/
    ├── search_modal_component.ex
    └── search_result_presenter.ex   # new, if needed

test/cairnloop/web/
├── search_modal_component_test.exs
├── inbox_live_test.exs
├── conversation_live_test.exs
└── settings_live_test.exs           # new if host-surface coverage is added
```

The new presenter module is optional but recommended because the context explicitly says to keep one normalized presenter over `Cairnloop.Retrieval.Result`, not an ad hoc search-only payload model.

## Patterns To Follow

### Pattern 1: Retrieval-backed result sections
Use the retrieval facade for search and group already-ranked results into fixed UI sections by `source_type`, preserving order within each section.

### Pattern 2: Presenter over normalized results
Format source labels, trust labels, recency copy, and explicit open actions in one presenter module rather than scattering UI formatting across the LiveComponent template.

### Pattern 3: Preview-on-focus state machine
Keep active row and preview state fully local after results load. Moving the active selection must not issue new retrieval calls.

### Pattern 4: Host-safe navigation
Resolve explicit destinations from metadata or presenter output. Do not build links from guessed `id` keys as the current component does.

## Risks And Pitfalls

- **Destination ambiguity for KB hits:** the current router exposes KB index and editor routes, but retrieval rows only carry `revision_id`. Planning must include enriching provider metadata so canonical open targets are explicit.
- **Shortcut implementation drift:** because this repo lacks a standard assets tree, any plan that mandates a custom hook without a bootstrap path will stall. The first executable plan should keep a safe LiveView-only fallback.
- **Conversation draft regression:** `ConversationLive` keeps draft/reply form state in assigns. Search open/close flows must not reset those assigns or navigate away on focus changes.
- **Trust blurring:** resolved-case snippets cannot look like policy truth. Preview blocks and labels need separate wording from KB article copy.

## Validation Architecture

The phase should verify three layers:

1. Retrieval metadata contract:
   - Provider results expose enough metadata for explicit destinations, recency, and trust/source cues.
2. Palette interaction contract:
   - open/close, min query length, debounce behavior, local active-row movement, section ordering, preview updates, and source-aware open actions.
3. Host-surface safety:
   - search mounts in Inbox, Conversation, and Settings without breaking route/state expectations.

Fast feedback should come from focused component and LiveView tests rather than full end-to-end browser automation. The current repo is much closer to unit/integration-style LiveView tests than to a full browser harness. [VERIFIED: `test/cairnloop/web/*`]
