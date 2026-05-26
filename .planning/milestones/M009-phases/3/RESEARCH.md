# Phase 3: Operator UI - Research

**Researched:** 2024-05-24
**Domain:** Phoenix LiveView, Keyboard Event Handling, UI Components
**Confidence:** HIGH

## Summary

The goal of this phase is to provide operators with a global `cmd+k` semantic search interface in the LiveView dashboard. This allows operators to issue natural language queries that search past conversations via the Scrypath vector database. 

A preliminary `SearchModalComponent` exists in the codebase but requires refinement. The key architectural challenges are safely capturing global keyboard shortcuts without flooding the LiveView server with keystroke events, ensuring immediate input focus when the modal opens, and adhering to the project's explicit API patterns for querying Scrypath via HTTP (using `Req`). 

**Primary recommendation:** Use `phx-window-keydown="toggle_search"` with the `phx-key="k"` filter to restrict server-side event handling to just the "k" key, verifying the `metaKey` or `ctrlKey` parameter in the handler. Use `Req` to query Scrypath's HTTP API, maintaining consistency with the established patterns from Phase 1.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Global Shortcut Interception | Browser / Client | | Handled purely via LiveView's `phx-window-keydown` binding. |
| Search Modal State | Frontend Server (SSR)| | `Phoenix.LiveComponent` manages the `:show` assign, query string, and results list. |
| Semantic Querying | API / Backend | | LiveComponent handles the debounced `phx-change` event and issues a `Req.post` to the Scrypath HTTP API. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Phoenix.LiveComponent` | ~> 1.0 | UI Encapsulation | Isolates the complex modal state (open/close/query/results) from the host LiveViews. |
| `Req` | ~> 0.5 | HTTP Client | Project standard for Scrypath integration per `3-PATTERNS.md`. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `phx-window-keydown` | Custom JS Hook | JS Hooks require client-side configuration (editing `app.js`). Since this app appears API/component-heavy with potentially ignored/abstracted assets, utilizing the native `phx-window-keydown` with `phx-key` filtering is safer and requires less boilerplate. |

## Architecture Patterns

### Pattern 1: Filtered Window Keydown
**What:** Catching global `cmd+k` events without capturing every keystroke.
**When to use:** When you need global keyboard shortcuts in LiveView without writing custom client-side JS.
**Example:**
```elixir
<div phx-window-keydown="toggle_search" phx-key="k" phx-target={@myself}>
```
By appending `phx-key="k"`, LiveView filters events on the client side, only sending network requests to the server when "k" (or "K") is pressed. The server then checks for the modifier key.

### Pattern 2: Immediate Input Focus
**What:** Automatically focusing the search input when the modal renders.
**When to use:** In dynamic LiveView modals where the HTML `autofocus` attribute fails because it only fires on the initial full-page load.
**Example:**
```elixir
<input 
  type="text" 
  name="query" 
  phx-mounted={JS.focus()} 
  phx-debounce="300"
/>
```

### Anti-Patterns to Avoid
- **Unfiltered Window Events:** Using `phx-window-keydown="toggle"` without `phx-key="k"`. This will send a WebSocket message for *every single key* pressed anywhere on the page, severely degrading performance.
- **Querying on Empty Strings:** Sending an empty or very short query (e.g., `< 3` characters) to the vector DB. Always pattern-match in Elixir to clear results without making an HTTP request if the query is too short.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Request Debouncing | `Process.send_after` in Elixir | `phx-debounce="300"` | LiveView natively supports client-side input debouncing, preventing rapid typing from overwhelming the server. |
| Click-away closing | JS event listeners | `phx-click-away="close"` | Native LiveView binding that handles clicks outside the modal cleanly and safely. |

## Common Pitfalls

### Pitfall 1: Capturing Input Keystrokes as Shortcuts
**What goes wrong:** A user is typing the letter "k" into a form input, and the search modal suddenly opens.
**Why it happens:** Global keydown bindings normally capture all typing.
**How to avoid:** LiveView automatically ignores `phx-window-keydown` bindings if the active DOM element is an `<input>`, `<textarea>`, or `<select>`. This provides built-in safety. However, if the app uses custom `contenteditable` elements, this might break and require custom JS hooks.

### Pitfall 2: Modal Z-Index Conflicts
**What goes wrong:** The modal opens but appears behind other UI elements (like sticky headers).
**Why it happens:** The modal is mounted inside a host container with a lower `z-index` or `overflow: hidden`.
**How to avoid:** Ensure the backdrop div has a sufficiently high `z-index` (e.g., `z-50`) and `position: fixed`.

## Code Examples

### Optimized Event Handler
```elixir
# Only triggered if "k" is pressed due to phx-key="k" on the template
def handle_event("toggle_search", %{"key" => key} = params, socket) do
  is_cmd = params["metaKey"] == true or params["ctrlKey"] == true
  
  if is_cmd do
    # Toggle visibility and reset state
    {:noreply, assign(socket, show: !socket.assigns.show, query: "", results: [])}
  else
    {:noreply, socket}
  end
end

def handle_event("search", %{"query" => query}, socket) when byte_size(query) < 3 do
  {:noreply, assign(socket, query: query, results: [])}
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `autofocus` attribute | `phx-mounted={JS.focus()}` | LiveView 0.17+ | Ensures inputs in dynamically rendered modals actually receive focus immediately, vastly improving UX. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Scrypath API | Semantic Search | ✓ | Project dependency | — |
| Req | HTTP Client | ✓ | 0.5+ | — |

**Missing dependencies with fallback:**
- None — all necessary infrastructure is present in the `mix.exs` and codebase patterns.