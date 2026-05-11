# Phase M003-S02: Dynamic Context Pane UI in LiveView - Research

**Researched:** 2026-05-11 [VERIFIED: `date +%F`]
**Domain:** Phoenix LiveView UI composition, deterministic context normalization, and graceful reload/error handling [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `lib/cairnloop/web/conversation_live.ex`]
**Confidence:** HIGH [VERIFIED: codebase inspection + official Phoenix/Elixir docs]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Decision:** Render host context and the draft-audit surface inside a single right-hand rail in `ConversationLive`.
- **Layout:** On desktop, this is a fixed sidebar. On narrower screens, the same cards stack below the message timeline rather than becoming a separate navigation mode.
- **Content order:** `Customer Context` first, `AI Draft / Audit` second.
- **Rationale:** The operator should have one stable evidence surface. Tabs, drawers, or a separate child LiveView would add mode-switching and make the dashboard feel like multiple apps glued together. The existing M002 decisions already established a dedicated audit cockpit, so S02 should extend that surface instead of introducing a second one.
- **Decision:** Keep `Cairnloop.Web.ConversationLive` as the owner of the conversation assign and render the rail through extracted function components.
- **Suggested shape:** `context_pane/1`, `context_section/1`, `context_field/1`, and `draft_audit_card/1`.
- **Rationale:** The pane is read-mostly in S02, so a `Phoenix.LiveComponent` or nested LiveView would add state and lifecycle complexity without a matching benefit. Phoenix idiom here is to prefer function components unless there is real local event/state encapsulation.
- **Footguns avoided:** no extra process boundary, no `id` choreography for stateful components, and no duplicated refresh logic between parent and child views.
- **Decision:** Treat the provider return value as an input contract, not a render contract. Normalize the nested map into a deterministic render tree before emitting HTML.
- **Rules:**
  - Sort map keys deterministically before rendering.
  - Keep host keys as strings; do not atomize them.
  - Render only simple values directly.
  - Fallback safely for unexpected values instead of crashing or leaking raw structs into the UI.
- **Recommended shape:** a list/tree of section structs or maps with explicit titles, field rows, and optional child sections.
- **Rationale:** Raw Elixir maps are unordered, so rendering them directly creates unstable UI. The upstream S01 decision was “zero-config nested maps,” but the UI still needs a normalized tree to be predictable and readable.
- **Decision:** Always render the rail shell. If host context is missing, empty, or fails to load, show a clear empty/error card in the rail rather than hiding it.
- **Behavior:** A failure in `ContextProvider.get_context/2` should become `context_error` state, not a crash. The conversation, messages, and draft workflow must remain usable.
- **Refresh:** Reload context whenever the conversation reloads from a LiveView event or action handler. Do not treat mount-time fetch as the only source of truth.
- **Rationale:** Host billing or identity state can change while the operator is viewing the thread. A stale or absent panel is better than a broken one, but a visible error card is better than silently removing the operator’s context.
- **Decision:** The context rail should feel like an operator evidence panel, not a generic admin sidebar.
- **Copy and hierarchy:** Use short labels, concrete values, and visible grouping. Favor calm, grounded language over abstract system jargon.
- **Rationale:** Cairnloop’s brand and product posture are about grounded support operations. The UI should reinforce trust, source trail, and clarity rather than looking like a generic SaaS settings panel.

### Claude's Discretion
- Not explicitly provided in `M003-S02-CONTEXT.md`. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`]

### Deferred Ideas (OUT OF SCOPE)
- Host-owned extension slots for custom card blocks. This is intentionally left for `M003-S03`.
- Tabs for separate `Details / AI / Apps` views. Too much mode switching for this slice.
- Free-form custom fields in the rail. That would push the UI toward a support-platform builder instead of an opinionated embedded library.
- A separate child LiveView for the context rail. The coordination cost is not justified for S02.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M003-S02 | Dynamic right-hand Context Pane in `ConversationLive` that renders host `ContextProvider` data plus draft/audit content. [VERIFIED: `.planning/M003-ROADMAP.md` + user prompt] | Single-rail layout, parent-owned function components, deterministic normalization, and persistent empty/error shell. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md` + Phoenix docs] |
| S02 | Refresh context when the conversation reloads via events/actions and degrade gracefully on provider failure. [VERIFIED: user prompt + `.planning/phases/M003-S02-CONTEXT.md`] | Centralized reload pattern, error-state card, and callback-level tests for reload paths. [VERIFIED: `lib/cairnloop/web/conversation_live.ex` + Phoenix.LiveView docs + current tests] |
</phase_requirements>

## Summary

This slice is primarily a server-rendered composition problem inside `Cairnloop.Web.ConversationLive`, not a new component system or a new process boundary. The current module already owns conversation fetches and draft events, but it only loads `host_context` during `mount/3` and renders provider data by iterating the raw map with `inspect/1`. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] That implementation conflicts with the locked S02 decisions on deterministic sections, an always-visible rail shell, and refresh-on-reload behavior. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`]

Phoenix’s current guidance matches the phase direction: prefer function components for reusable stateless UI, and avoid LiveComponents when the goal is only code organization. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html] The implementation should therefore keep `ConversationLive` as the single source of truth, normalize host context into an explicit render tree before HEEx, and route every conversation reload path through one shared “reload conversation + reload context” flow so the rail never drifts behind the timeline. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [ASSUMED]

The repo’s testing infrastructure is also an important planning input: it has ExUnit and direct module tests, but no endpoint-backed LiveView test harness or `ConnCase` today. [VERIFIED: `test/test_helper.exs` + `find test -maxdepth 2 -type f` + `rg -n "LiveViewTest|ConnCase|Phoenix.ConnTest" test lib`] That means the safest plan is to add deterministic render/callback tests first, and only introduce mounted LiveView testing if the phase also adds the missing web test scaffolding. [VERIFIED: `test/cairnloop/web/conversation_live_test.exs`] [ASSUMED]

**Primary recommendation:** Implement the context rail as extracted function components inside `ConversationLive`, backed by a private normalization layer and a single reload helper that updates both `conversation` and `host_context` on every reload path. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `lib/cairnloop/web/conversation_live.ex`] [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Conversation reload orchestration | Frontend Server (SSR) | API / Backend | `ConversationLive` owns `mount/3`, `handle_event/3`, and `handle_info/2`, so it is the right place to refetch assigns after user actions or PubSub messages. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| Host context fetch | API / Backend | Database / Storage | `Cairnloop.ContextProvider.get_context/2` is a host-side behavior contract that resolves `actor_id` into domain data. [VERIFIED: `lib/cairnloop/context_provider.ex`] |
| Context normalization | Frontend Server (SSR) | — | The provider returns a nested map contract, but the rail needs deterministic, render-safe sections before HEEx interpolation. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] [CITED: https://hexdocs.pm/elixir/Map.html] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html] |
| Rail presentation | Frontend Server (SSR) | Browser / Client | The rail is server-rendered HEEx, while the browser only handles layout and event dispatch. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| Draft actions within rail | Frontend Server (SSR) | API / Backend | Approve/edit/discard events already terminate in `ConversationLive` and automation modules; S02 only relocates the surface into the right rail. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | `1.19.5` [VERIFIED: `elixir -v`] | Runtime and normalization helpers | The repo is pinned to Elixir `~> 1.19` and the local runtime is `1.19.5`. [VERIFIED: `mix.exs` + `elixir -v`] |
| Phoenix | `1.8.7` released `2026-05-06` [VERIFIED: `mix hex.info phoenix`] | LiveView host framework | Current project dependency and current stable Phoenix release as of 2026-05-11. [VERIFIED: `mix.lock` + `mix hex.info phoenix`] |
| Phoenix LiveView | `1.1.30` released `2026-05-05` [VERIFIED: `mix hex.info phoenix_live_view`] | Stateful page lifecycle plus HEEx rendering | LiveView provides the mount/event/message callbacks and modern function-component API used by this slice. [VERIFIED: `mix.lock` + `mix hex.info phoenix_live_view`] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| Phoenix HTML | `4.3.0` released `2025-09-28` [VERIFIED: `mix hex.info phoenix_html`] | HTML safety and template string conversion | HEEx relies on `Phoenix.HTML.Safe`; unsupported values should be normalized before render. [VERIFIED: `mix.lock` + `mix hex.info phoenix_html`] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit | bundled with Elixir `1.19.5` [VERIFIED: `elixir -v`] | Unit and callback tests | Use for normalization helpers and direct `handle_event/3` / `handle_info/2` tests. [VERIFIED: `test/test_helper.exs` + `test/cairnloop/web/conversation_live_test.exs`] |
| Phoenix.LiveViewTest | `1.1.30` through LiveView dependency [VERIFIED: `mix.lock`] | Rendering and component test helpers | Use `rendered_to_string/1` or `render_component/3` if the planner keeps tests at component/callback level. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Parent-owned function components | `Phoenix.LiveComponent` | LiveComponents add an `id`, state, and lifecycle; Phoenix recommends function components when there is no local state/event ownership need. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html] |
| Single rail with stacked cards | Tabs, drawers, or a child LiveView | Conflicts with locked UX decisions and introduces mode switching or process duplication. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] |
| Explicit normalization tree | Direct map iteration plus `inspect/1` | Elixir maps are unordered and Phoenix templates require HTML-safe values, so raw rendering is unstable and can break or leak ugly output. [CITED: https://hexdocs.pm/elixir/Map.html] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html] |

**Installation:** No new runtime dependency is required for S02 as scoped today. [VERIFIED: `mix.exs` + phase docs]

**Version verification:** `phoenix 1.8.7`, `phoenix_live_view 1.1.30`, and `phoenix_html 4.3.0` were verified from Hex package metadata on 2026-05-11. [VERIFIED: `mix hex.info phoenix` + `mix hex.info phoenix_live_view` + `mix hex.info phoenix_html`]

## Architecture Patterns

### System Architecture Diagram

```text
ConversationLive mount/event/info
        |
        | reload request
        v
  +---------------------+
  | fetch conversation  |
  | Chat.get_conversation!/1 |
  +---------------------+
        |
        | host_user_id
        v
  +---------------------+
  | fetch host context  |
  | ContextProvider.get_context/2 |
  +---------------------+
        |
        +--> {:ok, nested_map} ------+
        |                            |
        +--> {:error, reason} --+    |
                                |    |
                                v    v
                      +-----------------------+
                      | normalize render tree |
                      | sort keys, stringify  |
                      | safe values only      |
                      +-----------------------+
                                |
                                v
               +--------------------------------------+
               | render rail shell via function comps |
               | Customer Context + AI Draft / Audit  |
               +--------------------------------------+
                                |
                                v
                     success / empty / error card state
```

The diagram above reflects the existing callback ownership in `ConversationLive` plus the locked S02 normalization and shell-visibility decisions. [VERIFIED: `lib/cairnloop/web/conversation_live.ex` + `.planning/phases/M003-S02-CONTEXT.md`]

### Recommended Project Structure

```text
lib/
└── cairnloop/
    └── web/
        └── conversation_live.ex   # LiveView owner, private reload/normalize helpers, function components [VERIFIED: current file + locked decision]

test/
└── cairnloop/
    └── web/
        └── conversation_live_test.exs   # normalization, shell-state, and reload callback tests [VERIFIED: current file]
```

This phase does not need a new LiveView or LiveComponent module if the current scope stays read-mostly. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html]

### Pattern 1: Parent-Owned Function Components
**What:** Extract the rail into HEEx function components, but keep state and events in `ConversationLive`. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]
**When to use:** Use for `context_pane/1`, `context_section/1`, `context_field/1`, and `draft_audit_card/1` because they are render abstractions, not independent state owners. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`]
**Example:**
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html
use Phoenix.Component

attr :title, :string, required: true
slot :inner_block, required: true

def section(assigns) do
  ~H"""
  <section>
    <h3>{@title}</h3>
    {render_slot(@inner_block)}
  </section>
  """
end
```

### Pattern 2: Deterministic Normalization Before HEEx
**What:** Convert provider output into an explicit render tree of sections, fields, and safe fallback nodes before template interpolation. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] [CITED: https://hexdocs.pm/elixir/Map.html] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html]
**When to use:** Use for all host context values because top-level and nested maps are not a safe or readable render contract by themselves. [VERIFIED: `lib/cairnloop/context_provider.ex` + `.planning/phases/M003-S02-CONTEXT.md`]
**Example:**
```elixir
# Source concepts: https://hexdocs.pm/elixir/Map.html
# Source concepts: https://hexdocs.pm/elixir/Enum.html
defp normalize_map(map) do
  map
  |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
  |> Enum.map(fn {key, value} -> {to_string(key), normalize_value(value)} end)
end
```

### Pattern 3: Reload Through LiveView Callback Boundaries
**What:** Update both conversation data and context data whenever the parent LiveView reloads state from an event or PubSub message. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]
**When to use:** Apply to `handle_info({:draft_created, ...})`, `reply`, `approve_draft`, `edit_draft`, and `discard_draft`, because each path already refetches the conversation. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]
**Example:**
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
def handle_info({:updated_card, card}, socket) do
  {:noreply, socket}
end
```

### Anti-Patterns to Avoid
- **Raw map iteration in HEEx:** The current `for {key, value} <- @host_context` plus `inspect(value)` pattern produces unstable ordering and unreadable nested output. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [CITED: https://hexdocs.pm/elixir/Map.html]
- **Stateful component extraction for layout only:** Phoenix explicitly advises against using LiveComponents merely for code organization. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html]
- **Conditional shell removal:** Hiding the whole rail when context is empty or errors creates layout shifts and violates the locked “always visible” behavior. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md`]
- **Mount-only context fetch:** Reload handlers currently refetch `conversation` without refetching `host_context`, which guarantees stale context after changes. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Layout decomposition | Child LiveView or stateful LiveComponent just to split markup | Function components in the parent LiveView | Smaller surface area, no extra lifecycle or `id` bookkeeping, and aligns with locked phase decisions. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html] [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] |
| Generic map dumping | `inspect/1`-driven recursive renderer | Explicit section/field normalization | `inspect/1` is not an operator-facing presentation model and raw maps do not preserve stable display order. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [CITED: https://hexdocs.pm/elixir/Map.html] |
| Success/empty/error branching at container level | Separate rail layouts per state | One stable rail shell with stateful card content | Preserves spatial memory and matches the phase UX contract. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md`] |
| Broad table UI for narrow data | Universal table renderer | Stacked label/value rows in cards | The phase UI spec locks narrow-rail field rows instead of tables for readability. [VERIFIED: `M003-S02-UI-SPEC.md`] |

**Key insight:** The hard part in this slice is not fetching more data; it is defining a deterministic render contract between an open-ended host map and a narrow LiveView evidence rail. [VERIFIED: `lib/cairnloop/context_provider.ex` + `.planning/phases/M003-S02-CONTEXT.md`]

## Common Pitfalls

### Pitfall 1: Unstable Section Ordering
**What goes wrong:** The same context map renders in a different visual order after reloads or host changes. [VERIFIED: current raw map iteration in `lib/cairnloop/web/conversation_live.ex`]
**Why it happens:** Elixir maps do not preserve insertion order for display purposes. [CITED: https://hexdocs.pm/elixir/Map.html] [CITED: https://hexdocs.pm/elixir/keywords-and-maps.html]
**How to avoid:** Sort keys deterministically at every map level before building section nodes. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`]
**Warning signs:** Snapshot-style render tests fail intermittently or UI headings jump positions after unrelated reloads. [ASSUMED]

### Pitfall 2: Rendering Unsupported Values Directly
**What goes wrong:** HEEx receives a struct or arbitrary term that does not have a safe HTML representation, or the UI falls back to noisy `inspect/1` output. [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html] [VERIFIED: current `inspect(value)` path in `lib/cairnloop/web/conversation_live.ex`]
**Why it happens:** The provider contract is a nested map, but the current view treats it like already-formatted display data. [VERIFIED: `lib/cairnloop/context_provider.ex` + `lib/cairnloop/web/conversation_live.ex`]
**How to avoid:** Normalize supported scalar types, recurse through maps/lists intentionally, and emit a muted fallback like `Unsupported value` for everything else. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md`] [ASSUMED]
**Warning signs:** Protocol errors, raw `%Struct{}` output, or operator-facing metadata like `__meta__` and association internals. [ASSUMED]

### Pitfall 3: Context Drift After Draft/Reply Actions
**What goes wrong:** The message timeline reflects the latest conversation state, but the context rail still shows stale host data. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]
**Why it happens:** `handle_info/2` and several `handle_event/3` branches refetch `conversation` only. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]
**How to avoid:** Route every reload path through one helper that refreshes both `conversation` and context assigns. [ASSUMED]
**Warning signs:** A host-side billing or identity change is visible after hard refresh but not after in-page actions. [ASSUMED]

### Pitfall 4: Rail Collapse on Empty/Error State
**What goes wrong:** Empty context removes the entire card or rail, causing layout jumps and hiding the operator evidence surface. [VERIFIED: current render only shows success block when `map_size(@host_context) > 0` in `lib/cairnloop/web/conversation_live.ex`]
**Why it happens:** The implementation treats “no context” as “nothing to render” instead of “render the shell with a state card.” [VERIFIED: `lib/cairnloop/web/conversation_live.ex` + `.planning/phases/M003-S02-CONTEXT.md`]
**How to avoid:** Always render `Customer Context` and switch only the inner card content between success, empty, and error. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md`]
**Warning signs:** The right column disappears on first load for tickets with no host data. [ASSUMED]

### Pitfall 5: Over-Abstracting the Rail Before S03
**What goes wrong:** S02 builds a pluggable slot or component registry prematurely, increasing complexity before the S03 extensibility contract exists. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`]
**Why it happens:** The UI surface looks like a natural place for extension, but S03 is the explicit phase for host-owned custom blocks. [VERIFIED: `.planning/M003-ROADMAP.md` + `.planning/phases/M003-S02-CONTEXT.md`]
**How to avoid:** Keep S02 limited to normalized data sections plus the existing draft/audit card. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`]
**Warning signs:** New APIs for arbitrary host components appear in the S02 plan. [ASSUMED]

## Code Examples

Verified patterns from official sources:

### Function Component With Attributes and Slots
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html
attr :title, :string, required: true
slot :inner_block, required: true

def panel(assigns) do
  ~H"""
  <section>
    <h3>{@title}</h3>
    {render_slot(@inner_block)}
  </section>
  """
end
```

### LiveView Test Rendering to String
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
import Phoenix.Component
import Phoenix.LiveViewTest

assigns = %{}

assert rendered_to_string(~H"""
       <MyComponents.greet name="Mary" />
       """) == "<div>Hello, Mary!</div>"
```

### LiveView Message Callback Pattern
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
def handle_info({:updated_card, card}, socket) do
  {:noreply, socket}
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline raw-map rendering with `inspect/1` | Function-component rail backed by normalized render nodes | S02 design direction, documented 2026-05-11. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md`] | Produces deterministic sections and operator-readable values. [VERIFIED: phase docs] |
| Mount-only context fetch | Reload context on every conversation refresh path | S02 requirement, documented 2026-05-11. [VERIFIED: user prompt + `.planning/phases/M003-S02-CONTEXT.md`] | Prevents rail/timeline drift after LiveView events and PubSub updates. [VERIFIED: current gap in `lib/cairnloop/web/conversation_live.ex`] |
| Optional context block that vanishes on empty success state | Always-visible rail shell with success/empty/error states | S02 requirement, documented 2026-05-11. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md` + `M003-S02-UI-SPEC.md`] | Preserves spatial stability and makes failures explicit without breaking the rest of the dashboard. [VERIFIED: phase docs] |

**Deprecated/outdated:**
- Raw `inspect/1` output as the success-state display contract is outdated for this phase because it conflicts with the deterministic grouping and operator-tone requirements. [VERIFIED: `lib/cairnloop/web/conversation_live.ex` + `.planning/phases/M003-S02-CONTEXT.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A single private reload helper should be introduced so every event/info path refreshes both `conversation` and context assigns. [ASSUMED] | Summary, Architecture Patterns, Common Pitfalls | Low - the exact helper shape can vary, but the planner must still guarantee shared refresh behavior. |
| A2 | Unsupported provider values should render as a muted fallback string such as `Unsupported value` rather than attempting a generic inspector. [ASSUMED] | Common Pitfalls | Low - the exact copy can change, but the planner must still define a safe fallback rule. |
| A3 | Existing direct callback tests are the minimum viable strategy unless the phase also adds missing endpoint-backed LiveView test scaffolding. [ASSUMED] | Summary, Validation Architecture | Medium - if hidden web test infrastructure exists elsewhere, the test plan can be more ambitious. |

## Open Questions (RESOLVED)

1. **Is `M003-S02-UI-SPEC.md` fully locked or still advisory?**
   - Resolution: Treat `.planning/phases/M003-S02/M003-S02-UI-SPEC.md` as the implementation contract for S02 despite `status: draft`. The locked phase decisions and the UI spec align, and the planner/executor should carry concrete values from the spec into the plan unless the user later narrows scope explicitly. [VERIFIED: `.planning/phases/M003-S02/M003-S02-UI-SPEC.md` + `.planning/phases/M003-S02-CONTEXT.md`]
   - Planning consequence: Task actions and acceptance criteria should name the `352px` rail width, `32px` desktop gap, `24px` card padding/gap, narrow-screen stacking order, locked card titles, and inline discard confirmation copy from the UI spec. [VERIFIED: `M003-S02-UI-SPEC.md`]

2. **Should S02 add mounted LiveView test infrastructure, or stay with direct callback/render tests?**
   - Resolution: Keep S02 on the existing direct callback/render test style in `test/cairnloop/web/conversation_live_test.exs`. Do not add `ConnCase`, endpoint-backed LiveView tests, or broader web-test scaffolding in this phase. [VERIFIED: `test/test_helper.exs` + `rg -n "LiveViewTest|ConnCase|Phoenix.ConnTest" test lib`]
   - Planning consequence: Validation for this slice should focus on deterministic render assertions, callback-level reload coverage, and manual UI checks for responsive layout and visual contract alignment. If mounted LiveView coverage becomes necessary later, treat it as separate follow-on work rather than widening S02. [ASSUMED]

## Environment Availability

**Step 2.6: SKIPPED** (This phase is a code-and-template change within the existing Elixir/Phoenix stack; no new external tools or services were identified.) [VERIFIED: phase scope + `mix.exs`]

## Validation Architecture

`.planning/config.json` is absent, so Nyquist validation is treated as enabled by default for this research output. [VERIFIED: `.planning/config.json` missing in repo]

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with Phoenix render/callback tests. [VERIFIED: `test/test_helper.exs` + current tests] |
| Config file | `test/test_helper.exs` [VERIFIED: `test/test_helper.exs`] |
| Quick run command | `mix test test/cairnloop/web/conversation_live_test.exs` [VERIFIED: existing file path] |
| Full suite command | `mix test` [VERIFIED: Mix standard + repo test layout] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| M003-S02 | Renders a persistent right rail with `Customer Context` then `AI Draft / Audit`. [VERIFIED: phase docs] | render/unit | `mix test test/cairnloop/web/conversation_live_test.exs -x` | ✅ |
| S02 | Normalizes nested context maps into deterministic sections and safe fallback values. [VERIFIED: phase docs] | unit | `mix test test/cairnloop/web/conversation_live_test.exs -x` | ✅ |
| S02 | Refreshes context when `handle_info/2` or draft/reply events reload the conversation. [VERIFIED: phase docs + current code] | callback/unit | `mix test test/cairnloop/web/conversation_live_test.exs -x` | ✅ |
| S02 | Keeps the rail shell visible for empty and error states. [VERIFIED: phase docs] | render/unit | `mix test test/cairnloop/web/conversation_live_test.exs -x` | ✅ |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/conversation_live_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] Add normalization-focused tests for sorted nested sections, list rendering, and unsupported-value fallback in `test/cairnloop/web/conversation_live_test.exs`. [VERIFIED: current file lacks these cases]
- [ ] Add callback tests asserting that `handle_info/2`, `reply`, `approve_draft`, `edit_draft`, and `discard_draft` all refresh context as well as conversation data. [VERIFIED: current file only covers `:draft_created` conversation reload and mount-time context]
- [ ] Decide whether to add endpoint-backed LiveView test scaffolding; none exists today. [VERIFIED: `test/test_helper.exs` + repo grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host auth is outside this UI slice’s direct scope. [VERIFIED: phase scope] |
| V3 Session Management | no | No new session mechanism is introduced here. [VERIFIED: phase scope] |
| V4 Access Control | yes | Preserve raw `actor_id` handoff to the host provider and avoid inventing new identity mapping logic in the LiveView. [VERIFIED: `lib/cairnloop/context_provider.ex` + `.planning/phases/M003-S02-CONTEXT.md`] |
| V5 Input Validation | yes | Normalize and constrain provider output before rendering; only render supported scalar values directly. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html] |
| V6 Cryptography | no | No cryptographic operation is added in S02. [VERIFIED: phase scope] |

### Known Threat Patterns for LiveView Context Rails

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant or wrong-identity context lookup | Information Disclosure | Keep `actor_id` verbatim for the host provider and let the host app own the mapping boundary. [VERIFIED: `lib/cairnloop/context_provider.ex`] |
| Raw struct or unsafe term rendered into HEEx | Information Disclosure / DoS | Normalize values before render and reject unsupported terms with a safe fallback node. [CITED: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html] [ASSUMED] |
| Provider failure crashing the dashboard | Denial of Service | Convert provider failures into `context_error` state and keep the rest of the view usable. [VERIFIED: `.planning/phases/M003-S02-CONTEXT.md`] |
| Stale context after in-page actions | Tampering / Integrity drift | Refresh context whenever conversation state is reloaded from events or PubSub handlers. [VERIFIED: user prompt + current code gap] |

## Sources

### Primary (HIGH confidence)
- `lib/cairnloop/web/conversation_live.ex` - current LiveView ownership, render strategy, and reload gaps. [VERIFIED: codebase]
- `lib/cairnloop/context_provider.ex` - host context contract and zero-config nested map intent. [VERIFIED: codebase]
- `test/cairnloop/web/conversation_live_test.exs` - current test strategy and coverage gaps. [VERIFIED: codebase]
- `.planning/phases/M003-S02-CONTEXT.md` - locked phase decisions. [VERIFIED: planning docs]
- `.planning/phases/M003-S02/M003-S02-UI-SPEC.md` - draft UI contract for layout, copy, and token usage. [VERIFIED: planning docs]
- `.planning/M003-ROADMAP.md` - slice goal and dependency position. [VERIFIED: planning docs]
- https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html - function component API, attrs, and slots. [CITED]
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html - when to prefer function components over LiveComponents. [CITED]
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html - callback ownership for `mount/3`, `handle_event/3`, and `handle_info/2`. [CITED]
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html - `rendered_to_string/1` and component test helpers. [CITED]
- https://hexdocs.pm/phoenix_html/Phoenix.HTML.Safe.html - HTML-safe rendering contract. [CITED]
- https://hexdocs.pm/elixir/Map.html - maps are unordered key-value structures. [CITED]
- https://hexdocs.pm/elixir/keywords-and-maps.html - maps have internal ordering that is not guaranteed across maps. [CITED]

### Secondary (MEDIUM confidence)
- None.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions and current release dates were verified from local runtime, lockfile, and Hex metadata. [VERIFIED: `elixir -v` + `mix.lock` + `mix hex.info ...`]
- Architecture: HIGH - recommendations align with locked phase docs, current code ownership, and current Phoenix guidance on component boundaries. [VERIFIED: codebase + planning docs] [CITED: Phoenix docs]
- Pitfalls: HIGH - each pitfall maps directly to a current code gap or an official framework/data constraint. [VERIFIED: codebase] [CITED: Elixir/Phoenix docs]

**Research date:** 2026-05-11 [VERIFIED: `date +%F`]
**Valid until:** 2026-06-10 for codebase facts; re-check Phoenix/LiveView release metadata if planning starts later. [VERIFIED: current date + fast-moving dependency versions]
