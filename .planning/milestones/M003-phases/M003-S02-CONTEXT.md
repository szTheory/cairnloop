# M003-S02 Context: Dynamic Context Pane UI in LiveView

This document captures the implementation decisions for Milestone 3, Slice 02. It assumes the upstream contracts from `M002-S01` and `M003-S01` are already locked.

## 1. One Right Rail, Not Multiple Surfaces
- **Decision:** Render host context and the draft-audit surface inside a single right-hand rail in `ConversationLive`.
- **Layout:** On desktop, this is a fixed sidebar. On narrower screens, the same cards stack below the message timeline rather than becoming a separate navigation mode.
- **Content order:** `Customer Context` first, `AI Draft / Audit` second.
- **Rationale:** The operator should have one stable evidence surface. Tabs, drawers, or a separate child LiveView would add mode-switching and make the dashboard feel like multiple apps glued together. The existing M002 decisions already established a dedicated audit cockpit, so S02 should extend that surface instead of introducing a second one.

## 2. Render Through Function Components
- **Decision:** Keep `Cairnloop.Web.ConversationLive` as the owner of the conversation assign and render the rail through extracted function components.
- **Suggested shape:** `context_pane/1`, `context_section/1`, `context_field/1`, and `draft_audit_card/1`.
- **Rationale:** The pane is read-mostly in S02, so a `Phoenix.LiveComponent` or nested LiveView would add state and lifecycle complexity without a matching benefit. Phoenix idiom here is to prefer function components unless there is real local event/state encapsulation.
- **Footguns avoided:** no extra process boundary, no `id` choreography for stateful components, and no duplicated refresh logic between parent and child views.

## 3. Normalize The Host Map Before Rendering
- **Decision:** Treat the provider return value as an input contract, not a render contract. Normalize the nested map into a deterministic render tree before emitting HTML.
- **Rules:**
  - Sort map keys deterministically before rendering.
  - Keep host keys as strings; do not atomize them.
  - Render only simple values directly.
  - Fallback safely for unexpected values instead of crashing or leaking raw structs into the UI.
- **Recommended shape:** a list/tree of section structs or maps with explicit titles, field rows, and optional child sections.
- **Rationale:** Raw Elixir maps are unordered, so rendering them directly creates unstable UI. The upstream S01 decision was “zero-config nested maps,” but the UI still needs a normalized tree to be predictable and readable.

## 4. Graceful Failure, Always Visible
- **Decision:** Always render the rail shell. If host context is missing, empty, or fails to load, show a clear empty/error card in the rail rather than hiding it.
- **Behavior:** A failure in `ContextProvider.get_context/2` should become `context_error` state, not a crash. The conversation, messages, and draft workflow must remain usable.
- **Refresh:** Reload context whenever the conversation reloads from a LiveView event or action handler. Do not treat mount-time fetch as the only source of truth.
- **Rationale:** Host billing or identity state can change while the operator is viewing the thread. A stale or absent panel is better than a broken one, but a visible error card is better than silently removing the operator’s context.

## 5. UX Tone
- **Decision:** The context rail should feel like an operator evidence panel, not a generic admin sidebar.
- **Copy and hierarchy:** Use short labels, concrete values, and visible grouping. Favor calm, grounded language over abstract system jargon.
- **Rationale:** Cairnloop’s brand and product posture are about grounded support operations. The UI should reinforce trust, source trail, and clarity rather than looking like a generic SaaS settings panel.

## Canonical Refs
- `.planning/M003-ROADMAP.md`
- `.planning/phases/M003-S01-CONTEXT.md`
- `.planning/phases/M002-S01-CONTEXT.md`
- `lib/cairnloop/web/conversation_live.ex`
- `lib/cairnloop/context_provider.ex`
- `lib/cairnloop/default_context_provider.ex`
- `test/cairnloop/web/conversation_live_test.exs`
- `prompts/cairnloop_brand_book.md`
- `prompts/cairnloop.tokens.json`
- `prompts/cairnloop.css`
- `prompts/elixir-lib-customer-support-automation-deep-research.md`
- `prompts/scoria overview for integration ideas.txt`

## Deferred Ideas
- Host-owned extension slots for custom card blocks. This is intentionally left for `M003-S03`.
- Tabs for separate `Details / AI / Apps` views. Too much mode switching for this slice.
- Free-form custom fields in the rail. That would push the UI toward a support-platform builder instead of an opinionated embedded library.
- A separate child LiveView for the context rail. The coordination cost is not justified for S02.
