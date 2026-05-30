# Phase 34: Operator Settings Surface - Research

**Researched:** 2024-05-18
**Domain:** Elixir/Phoenix Settings UI, Runtime Configuration, State Management
**Confidence:** HIGH

## Summary

This phase transforms `SettingsLive` from a placeholder SLA-CRUD view into the primary operations surface for the Cairnloop host operator. It introduces robust MCP token management, health checks for both Notifiers (event handlers) and Retrieval (pgvector embeddings), and a dark-mode toggle for operator ergonomics.

**Primary recommendation:** 
- Use existing `Cairnloop.MCP` functions for token management while querying `Token` schemas directly for the list view. 
- Perform live reachability checks on the `Notifier` behaviour implementation via code reflection.
- Use `Ecto.Adapters.SQL` to directly verify the `pgvector` extension and check `Oban.Job` for indexing queue states. 
- Use pure Javascript encapsulated in a toggle button to control `data-theme` and `localStorage` to ensure the library can change themes without requiring host app JS hook integration.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| MCP Token CRUD | API / Backend | Browser / Client | State persists via `Cairnloop.MCP` into Ecto schema; Client only displays the clear-text token once. |
| Notifier Health | API / Backend | — | The health check is an internal code/module reflection (`Code.ensure_loaded?`) executed by the Elixir backend. |
| Retrieval Health | API / Backend | Database | Backend queries `pg_extension` and `Oban.Job` tables to assess the readiness of the vector store and indexing queues. |
| Dark Mode Toggle | Browser / Client | — | Must be fully encapsulated client-side JS modifying `data-theme` and `localStorage` so it works independent of the host application's asset pipeline. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | ~> 0.20 | Reactive UI | Standard in Cairnloop; used to handle real-time setting toggles and health updates. |
| Ecto | ~> 3.10 | Database Access | Querying MCP tokens, pgvector stats, and Oban job metrics. |

## Architecture Patterns

### Pattern 1: Encapsulated Library Theme Toggle
**What:** Changing the color scheme from within an embedded library component without a dedicated JS hook.
**When to use:** When providing a theme toggle inside `cairnloop` where the host app controls the `<head>` and `app.js`.
**Example:**
```html
<button
  type="button"
  onclick="
    const root = document.documentElement;
    const isDark = root.getAttribute('data-theme') === 'dark';
    const nextTheme = isDark ? 'light' : 'dark';
    root.setAttribute('data-theme', nextTheme);
    localStorage.setItem('phx:theme', nextTheme);
    
    // Also dispatch phx:set-theme in case the host app is listening
    window.dispatchEvent(new CustomEvent('phx:set-theme', {detail: {theme: nextTheme}}));
  "
>
  Toggle Dark Mode
</button>
```

### Pattern 2: Reflection-based Health Checks
**What:** Verifying that a host-configured module (like a Notifier) is loaded and complies with the expected behaviour.
**When to use:** To surface integration health dynamically without requiring network pings.
**Example:**
```elixir
notifier = Application.get_env(:cairnloop, :notifier)
health = cond do
  is_nil(notifier) -> {:warning, "Not configured"}
  not Code.ensure_loaded?(notifier) -> {:error, "Module not found"}
  not function_exported?(notifier, :on_conversation_resolved, 2) -> {:error, "Missing behaviour callbacks"}
  true -> {:ok, "Healthy"}
end
```

### Pattern 3: Extension Verification via SQL
**What:** Directly querying Postgres for the presence of the `pgvector` extension instead of relying solely on Ecto schemas.
**When to use:** To establish base capabilities for the Retrieval dashboard module.
**Example:**
```elixir
case Ecto.Adapters.SQL.query(repo, "SELECT 1 FROM pg_extension WHERE extname = 'vector'") do
  {:ok, %{num_rows: 1}} -> :installed
  _ -> :missing
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MCP Token generation | Custom crypto/hashing inside SettingsLive | `Cairnloop.MCP.issue_token/1` | Centralized token logic ensures security and correct SHA256 hashing. |
| DB Extension checks | Parsing schema dumps or migrations | `Ecto.Adapters.SQL.query` | Directly querying `pg_extension` is faster and definitive. |

## Common Pitfalls

### Pitfall 1: Displaying MCP Tokens After Creation
**What goes wrong:** Attempting to display the raw MCP token after the initial creation response.
**Why it happens:** The database only stores `token_hash`. The raw string is only available in the `{:ok, token, raw_token}` response from `issue_token/1`.
**How to avoid:** Assign the `raw_token` to the socket *once* immediately after creation. Hide it when the modal is closed or another token is clicked. Do not store it in state permanently.

### Pitfall 2: LiveView JS Hooks for Library Toggle
**What goes wrong:** Trying to define a Phoenix JS Hook (`Hooks.ThemeToggle`) in `SettingsLive`.
**Why it happens:** Cairnloop is a library, so it cannot inject JS Hooks into the host application's `app.js` without manual integration steps.
**How to avoid:** Use an inline `onclick` script in the HEEx template to manage `data-theme` and `localStorage`, bypassing the need for a registered hook.

### Pitfall 3: Notifier Application Config Nil
**What goes wrong:** Server crashes when attempting to call `Code.ensure_loaded?(nil)`.
**Why it happens:** The `notifier` configuration might be missing in `config.exs`.
**How to avoid:** Always pattern match or guard against `nil` before doing module reflection.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Postgres with pgvector | Retrieval System | ✓ | >= 16 | — |

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `Cairnloop.MCP` for token validation |
| V3 Session Management | yes | Host-provided `cairnloop_dashboard` live session |
| V4 Access Control | yes | Settings LiveView is protected by host router mounts |
| V5 Input Validation | yes | Ecto Changesets for MCP tokens |
| V6 Cryptography | yes | `:crypto.hash(:sha256)` and `:crypto.strong_rand_bytes` via `Cairnloop.MCP` |

### Known Threat Patterns for Elixir/Phoenix Settings

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Insecure Direct Object Reference (IDOR) | Elevation of Privilege | Settings access is limited strictly by the host's `cairnloop_dashboard` macro scoping rules. |
| Timing Attacks on Tokens | Information Disclosure | `validate_token` uses constant-time comparison implicitly via database hashing. |
| Cross-Site Scripting (XSS) via Setting Input | Tampering | Phoenix HTML escaping safely renders token names or inputs. |

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Directly follows established Elixir/LiveView idioms in the project.
- Architecture: HIGH - Uses verified existing facades (`Cairnloop.MCP`) and standard LiveView behaviors.
- Pitfalls: HIGH - Documented issues (like raw token retrieval) are structural guarantees of the current design.