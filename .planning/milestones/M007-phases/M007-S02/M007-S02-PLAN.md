---
phase: M007-S02
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/web/search_modal_component.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/web/settings_live.ex
  - lib/cairnloop/web/conversation_live.ex
autonomous: true
requirements: [M007-REQ-02]
must_haves:
  truths:
    - User can press cmd+k to open search modal
    - User can search for resolved conversations semantically
    - User can click a search result to navigate to that conversation
  artifacts:
    - path: lib/cairnloop/web/search_modal_component.ex
      provides: "LiveComponent for semantic search"
  key_links:
    - from: lib/cairnloop/web/search_modal_component.ex
      to: Scrypath API
      via: HTTP/API call for semantic search
---

<objective>
Implement the Operator Semantic Search Interface (LiveView) allowing operators to press `cmd+k` / `ctrl+k` to search resolved conversations using the Scrypath semantic search API.

Purpose: Provide operators with a quick, keyboard-accessible way to find relevant past conversations via semantic similarity.
Output: A globally accessible Search Modal LiveComponent injected into main LiveViews.
</objective>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create Search Modal LiveComponent</name>
  <files>lib/cairnloop/web/search_modal_component.ex</files>
  <action>
    Create `Cairnloop.Web.SearchModalComponent` as a `Phoenix.LiveComponent`.
    Implement the following:
    1. A `render/1` function containing a modal container and a search input.
    2. Add `phx-window-keydown="toggle_search"` to handle `cmd+k` / `ctrl+k` to toggle visibility state (e.g. `@show`).
    3. Add `phx-change="search"` to the input with a debounce (e.g. `phx-debounce="300"`) for the search query.
    4. In `handle_event("search", %{"query" => query}, socket)`, call the Scrypath API (or an appropriate integration module) to retrieve semantically similar resolved conversations.
    5. Render the top results in the modal.
    6. Each result should be a link or button that navigates to the ConversationLive route (`/:id`).
  </action>
  <verify>
    <automated>mix test</automated>
  </verify>
  <done>Component exists, toggles on cmd+k, debounces search, queries Scrypath, and lists clickable results.</done>
</task>

<task type="auto">
  <name>Task 2: Inject Search Modal into LiveViews</name>
  <files>
    lib/cairnloop/web/inbox_live.ex
    lib/cairnloop/web/settings_live.ex
    lib/cairnloop/web/conversation_live.ex
  </files>
  <action>
    Inject `<.live_component module={Cairnloop.Web.SearchModalComponent} id="search-modal" />` into the `render/1` templates of `Cairnloop.Web.InboxLive`, `Cairnloop.Web.SettingsLive`, and `Cairnloop.Web.ConversationLive`. Ensure the component is correctly aliased or referenced with the full module name.
  </action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>The search modal is present in all primary operator LiveView routes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Operator -> Modal | Operator input via search box. Must be sanitized before rendering. |
| Server -> Scrypath API | Outbound API call; ensure query is properly escaped and API keys are protected. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M007-S02-01 | Spoofing | SearchModalComponent | mitigate | Ensure operator session is authenticated before allowing LiveView connection. |
| T-M007-S02-02 | Info Disclosure | SearchModalComponent | mitigate | Ensure search results returned from Scrypath only include conversations the operator is authorized to view. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` passes.
- Modal opens on `cmd+k` or `ctrl+k`.
- Typing in modal input successfully calls the semantic search backend and returns results.
</verification>

<success_criteria>
- The operator can launch the search modal from `InboxLive`, `SettingsLive`, and `ConversationLive` using a keyboard shortcut.
- Search queries are debounced and sent to Scrypath API.
- Clicking a result navigates directly to the specified conversation view.
</success_criteria>

<output>
After completion, create `.planning/milestones/M007-phases/M007-S02/M007-S02-SUMMARY.md`
</output>