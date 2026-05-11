# Phase M003-S01: ContextProvider Behaviour & Core Integration - Research

**Researched:** 2024-05-20
**Domain:** Elixir Behaviours, Phoenix LiveView integration, API decoupling
**Confidence:** HIGH

## Summary

This phase implements the `Cairnloop.ContextProvider` behaviour, allowing host applications to dynamically inject context (e.g., billing, identity, usage metrics) into Cairnloop's LiveView dashboard without brittle API syncing. The implementation strictly adheres to standard Elixir behaviour patterns, explicitly mirroring the existing `Cairnloop.AutomationPolicy` structure. The core integration relies on tagged tuple returns (`{:ok, map()} | {:error, term()}`) and ensures the LiveView degrades gracefully to a fallback state if context fetching fails, guaranteeing the support workflow is never blocked by a host database issue.

**Primary recommendation:** Use Application config dependency injection with a robust fallback to `Cairnloop.DefaultContextProvider` to ensure zero-config safety while enabling unconstrained host extensibility.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Callback Signature:** Update the callback to return `{:ok, map()} | {:error, term()}` and accept the `actor_id` string rather than expecting an unwrapped map.
- **UI Rendering Structure (Zero-Config UI):** The returned map should be a deeply nested map of simple Elixir terms (strings, numbers, booleans, dates) that Cairnloop will recursively render as categorized UI sections.
- **Identity Binding:** The behaviour accepts the raw `actor_id` verbatim. Do not assume `actor_id` maps perfectly to an internal `User` schema.
- **Path to S03 (LiveComponent Injection):** For S03, we will extend this same map structure to allow returning a tuple of `{Module, assigns}` for specific keys, signaling that the host wants to take over rendering for that section.

### the agent's Discretion
- Implementation details for gracefully handling the UI in LiveView when context is missing or errors out fall under developer ergonomics and principle of least surprise.

### Deferred Ideas (OUT OF SCOPE)
- Dynamic Context Pane UI rendering logic (deferred to S02).
- LiveComponent extensibility actions (deferred to S03).
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Behaviour Definition | API / Backend | — | Core Elixir contract `Cairnloop.ContextProvider` defining how hosts feed data. |
| Context Data Retrieval | API / Backend | Database | Host's Ecto logic fetching domain details safely decoupled from Cairnloop. |
| Graceful Degradation | Frontend Server (SSR) | — | LiveView must handle `{:error, reason}` gracefully without crashing the UI. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | ~> 1.14 | Runtime / Core | Native `@callback` and `@behaviour` constructs represent the idiomatic way to handle host-level extensibility. |
| Phoenix LiveView | Core stack | Real-time SSR UI | Server-rendered UI naturally consumes Elixir maps and handles tagged tuple error states directly within the same VM without JSON serialization boundaries. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Elixir Behaviours | Webhooks / API Sync | Webhooks introduce state desync, network latency, distributed failure modes, and duplicated data ingestion. Behaviours allow zero-API direct DB querying (the "SaaS in a Box" philosophy). |
| Tagged Tuples (`{:ok, map()}`) | Raw map / exceptions | Exceptions (`try/rescue`) are anti-patterns for expected control flow in Elixir. Tagged tuples force explicit, ergonomic error handling in the LiveView lifecycle. |

## Architecture Patterns

### System Architecture Diagram

Data flow for ContextProvider integration:

```
[ConversationLive] 
       │ (1. Request context for actor_id)
       ▼
[Application.get_env(:cairnloop, :context_provider)]
       │ (2. Resolves to Host App's Provider Module OR DefaultContextProvider)
       ▼
[HostApp.ContextProvider.get_context(actor_id)]
       │ (3. Host queries local DB via Ecto)
       ▼
       ├─ Success ─► {:ok, %{"User" => %{...}}} ───► (4a. LiveView assigns @context)
       │
       └─ Error ───► {:error, :not_found} ───────► (4b. LiveView assigns @context_error)
```

### Pattern 1: Behaviour Definition
**What:** Define the `Cairnloop.ContextProvider` contract for host apps.
**When to use:** The foundational API surface for all host applications to feed contextual identity data to Cairnloop.
**Example:**
```elixir
defmodule Cairnloop.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context for a given actor.
  """

  @doc """
  Fetches context for the provided actor_id.
  Returns `{:ok, map()}` containing simple terms, or `{:error, term()}`.
  """
  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
```

### Pattern 2: Default Fallback Implementation
**What:** A default implementation that returns a safe, empty state to ensure out-of-the-box resilience.
**When to use:** When the host has not yet configured a custom provider in `config.exs`.
**Example:**
```elixir
defmodule Cairnloop.DefaultContextProvider do
  @moduledoc """
  Default implementation of Cairnloop.ContextProvider.
  Returns an empty map to prevent crashes before a host configures their own.
  """
  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(_actor_id, _opts \\ []), do: {:ok, %{}}
end
```

### Pattern 3: Application Config Injection
**What:** Resolving the provider dynamically inside the running LiveView process.
**When to use:** Inside `ConversationLive` when mounting or fetching conversation details.
**Example:**
```elixir
provider = Application.get_env(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider)

context_assigns =
  case provider.get_context(actor_id) do
    {:ok, context_map} -> 
      %{context: context_map, context_error: nil}
    {:error, reason} -> 
      # Fallback UI state - DO NOT crash the support agent's dashboard
      %{context: %{}, context_error: "Context Unavailable"}
  end
```

### Anti-Patterns to Avoid
- **Anti-pattern:** Assuming `actor_id` is an integer or UUID. 
  - *Instead:* Always pass `actor_id` as a string verbatim to decouple from the host's primary key types, promoting the principle of least surprise.
- **Anti-pattern:** Returning raw Ecto structs (like `%User{}`).
  - *Instead:* Map Ecto structs to simple maps with basic terms (strings, numbers). Structs bleed host application internals into Cairnloop, confusing the rendering engine and complicating future JSON serialization for AI models.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Extensibility | Custom Webhooks / Sync Workers | Elixir `@callback` Behaviours | Cairnloop is embedded in the same VM; calling a module is synchronous, atomic, and zero-latency compared to HTTP. It's idiomatic Elixir. |
| Error Handling | `try/rescue` wrappers | Tagged tuples (`{:ok, result} | {:error, reason}`) | Elixir idiom is to return tags for expected failures. Unhandled exceptions should only be used for true catastrophic VM states, not missing DB records. |

## Common Pitfalls

### Pitfall 1: Leaking Internal Structs
**What goes wrong:** The host returns `{:ok, %{user: %HostApp.User{}}}`. The LiveView or AI RAG pipeline fails to parse it correctly because it has unresolved Ecto associations or hidden metadata (`__meta__`).
**Why it happens:** The host developer returns Ecto query results directly for convenience without a formatting step.
**How to avoid:** Explicitly document in `@moduledoc` that the `map()` must only contain simple scalar terms (string, integer, float, boolean, list, map). The UI expects easily serializable primitives.

### Pitfall 2: Crashing the Support Dashboard on Host DB Error
**What goes wrong:** The host's provider utilizes a bang query (`Repo.get!`) which raises an `Ecto.NoResultsError`, crashing the entire `ConversationLive` process for the support agent.
**Why it happens:** Unhandled exceptions in the provider bypass the tagged tuple contract and bubble up to the LiveView.
**How to avoid:** Ensure `ConversationLive` encapsulates the invocation of the behaviour (though a hard crash in the host app is technically their fault, we should document that they should use safe `Repo.get` calls and return `{:error, reason}`).

## Code Examples

Verified analog pattern from `lib/cairnloop/automation_policy.ex`:

### Defining an Embedded Policy Behaviour
```elixir
defmodule Cairnloop.AutomationPolicy do
  @callback decide(proposal :: map(), opts :: map()) ::
              :allow | :draft_only | :require_approval | :deny
end
```
*Directly applicable to ContextProvider creation.*

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| API Polling / Event Webhooks | In-VM Behaviours / Callbacks | Elixir Embedded Paradigm | Zero network latency, zero data duplication. Enables "SaaS in a Box" developer ergonomics. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | [ASSUMED] The implementation will rely on `Application.get_env/3` for dependency injection. | Patterns | Low - this is standard for Elixir and matches existing patterns in `ConversationLive`. |
| A2 | [ASSUMED] The second argument to `get_context/2` will be `opts :: keyword()` to allow future extensibility (e.g. context boundaries). | Patterns | Low - standard Elixir behaviour idiom. |

## Open Questions (RESOLVED)

1. **Test Coverage Strategy (RESOLVED)**
   - What we know: The existing `AutomationPolicy` has basic tests for the default implementation.
   - What's unclear: Should we test the dependency injection resolution directly in `ConversationLive` tests, or simply mock the provider?
   - Resolution: Mock the provider in controller/LiveView tests, but write explicit unit tests for `DefaultContextProvider` ensuring it returns `{:ok, %{}}`.

## Environment Availability
**Step 2.6: SKIPPED** (Pure Elixir application logic; no external dependencies or CLI tooling required).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/cairnloop/context_provider_test.exs test/cairnloop/web/conversation_live_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| S01-1 | Default provider returns empty ok tuple | unit | `mix test test/cairnloop/context_provider_test.exs` | ❌ Wave 0 |
| S01-2 | LiveView resolves provider via app config | unit/integration | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ Wave 0 (needs modification) |
| S01-3 | LiveView handles error tuple gracefully | unit/integration | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ Wave 0 (needs modification) |

### Sampling Rate
- **Per task commit:** `mix test <path-to-test-file>`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/cairnloop/context_provider_test.exs` — required for testing the default provider.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | Context injection should ensure data boundaries are respected, but the host Ecto Repo governs this. |
| V5 Input Validation | yes | `opts` and `actor_id` validation via Elixir typespecs. |
| V6 Cryptography | no | — |

## Sources

### Primary (HIGH confidence)
- Cairnloop Phase Patterns: `.planning/phases/M003-S01/M003-S01-PATTERNS.md`
- Cairnloop Roadmap: `.planning/M003-ROADMAP.md`
- Milestone Context: `.planning/phases/M003-S01-CONTEXT.md`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Elixir Behaviours are core language features.
- Architecture: HIGH - Matches existing `AutomationPolicy` implementation directly.
- Pitfalls: HIGH - Common Elixir extensibility anti-patterns documented.

**Research date:** 2024-05-20
**Valid until:** 30 days