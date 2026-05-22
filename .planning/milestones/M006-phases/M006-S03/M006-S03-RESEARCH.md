<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Storage (Host-Owned, Versioned Policy Pattern)**
   Instead of burying SLA configuration in a mutable internal library table, Cairnloop will use an Igniter recipe (`mix cairnloop.install`) to scaffold an immutable, versioned Ecto schema directly into the Host application. Cairnloop will interact with this schema via a defined Behaviour (`Cairnloop.SLAPolicyProvider`). This guarantees temporal correctness for SRE audits (Threadline/Parapet) while maintaining a batteries-included DX.

2. **UI Location (Dedicated `/settings` Route)**
   The settings dashboard will NOT be a modal within the `InboxLive` queue. It will be a dedicated LiveView route (e.g., `/settings`) injected via the `cairnloop_dashboard/2` macro. This prevents the primary operator queue process from bloating with administrative form states and creates a dedicated foundation for future RBAC and team settings.

3. **Priority Modeling (Static `Ecto.Enum`)**
   The system will rely on a static enum (`[:low, :normal, :high, :urgent]`) for priorities rather than allowing operators to dynamically create custom tiers. This removes complex joining logic from the Oban SLA breach workers and provides maximum type safety. If a host needs custom priorities, they can modify their Igniter-generated Ecto schema.

4. **SLA Metric Structure (Explicit Columns)**
   SLA durations will be modeled as explicit integer columns (e.g., `target_first_response_minutes`) on the policy table rather than unstructured JSONB payloads. This ensures Oban sweep queries are fully indexed and performant across millions of records.

### the agent's Discretion
None explicitly listed in CONTEXT.md.

### Deferred Ideas (OUT OF SCOPE)
None explicitly listed in CONTEXT.md.
</user_constraints>

# Phase M006-S03: LiveView SLA Configuration - Research

**Researched:** 2024-05-18
**Domain:** Elixir/Phoenix LiveView, Igniter, Ecto Schemas, Behaviour contracts
**Confidence:** HIGH

## Summary

This phase implements a host-owned, immutable SLA policy configuration system for Cairnloop. Rather than storing settings inside Cairnloop's private tables, we will use an Igniter recipe to inject a versioned Ecto schema (`SlaPolicy`) into the host application. Cairnloop interacts with this table via a new `Cairnloop.SLAPolicyProvider` behaviour. 

To manage these settings, we will add a dedicated `/settings` route to the `cairnloop_dashboard/2` macro, which points to a new `SettingsLive` LiveView. Policies are insert-only to maintain SRE auditability (historical configurations remain intact).

**Primary recommendation:** Use `Application.get_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)` to resolve the provider dynamically, and ensure the `/settings` route is placed *before* the `/:id` route in the router macro to prevent route swallowing.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SLA Policy Storage | Database / Storage | API / Backend | SLA policies must be durable, host-owned, and heavily queried by Oban SLA sweep workers. Immutable append-only pattern ensures auditability. |
| Settings UI | Frontend Server (SSR) | — | LiveView at `/settings` gives an embedded, zero-build step admin panel without polluting the main operator queue. |
| Extensibility Contract | API / Backend | — | `Cairnloop.SLAPolicyProvider` Behaviour abstracts direct database queries from Cairnloop core. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Igniter | ~> 0.1 | Code Generation | Standardized approach to scaffolding files and migrations into host applications in the Elixir ecosystem. |
| Ecto | ~> 3.10 | Data Mapping & Queries | Native schema mapping, enum typing, and immutable insert patterns. |
| Phoenix LiveView | ~> 0.20 | Interactive UI | Renders the `/settings` interface directly from the server. |

## Architecture Patterns

### Pattern 1: Host-Owned Immutable Schema via Igniter
**What:** Generating a migration and Ecto schema inside the host application instead of the library.
**When to use:** When data is highly sensitive to the host's domain, needs SRE auditing, or must be heavily customized by the host team later.
**Example:**
The Igniter recipe (`mix cairnloop.install.sla_policies`) will scaffold:
```elixir
def change do
  create table(:cairnloop_sla_policies) do
    add :priority, :string, null: false
    add :target_first_response_minutes, :integer
    add :target_resolution_minutes, :integer
    # Implicitly active based on `inserted_at` max value per priority
    timestamps(updated_at: false) 
  end
  create index(:cairnloop_sla_policies, [:priority, :inserted_at])
end
```

### Pattern 2: Elixir Behaviour Contract
**What:** `Cairnloop.SLAPolicyProvider` defining how Cairnloop fetches SLA rules.
**Example:**
```elixir
defmodule Cairnloop.SLAPolicyProvider do
  @callback get_active_policies() :: {:ok, list(map())} | {:error, term()}
  @callback set_policy(priority :: atom(), attrs :: map()) :: {:ok, map()} | {:error, term()}
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Priority Enums | Custom string validation / DB checks | `Ecto.Enum` | Native integration with Postgres enum mapping or string constraints, plus compile-time atom safety in Elixir. |
| Dynamic Resolution | GenServer Registry | `Application.get_env/3` | Standard Elixir dependency injection pattern for resolving the active provider behaviour at runtime. |

## Common Pitfalls

### Pitfall 1: LiveView Route Swallowing
**What goes wrong:** Adding `live("/settings", SettingsLive)` after `live("/:id", ConversationLive)` in the macro causes `/settings` to route to the Conversation UI with `id: "settings"`.
**Why it happens:** Phoenix router pattern matching is sequential top-to-bottom.
**How to avoid:** The macro in `lib/cairnloop/router.ex` must explicitly order routes correctly:
```elixir
live_session :cairnloop_dashboard, opts do
  live("/", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
  live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
  live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
end
```

### Pitfall 2: Mutating SLA Rules
**What goes wrong:** Using `Repo.update` on SLA policies destroys historical SRE data. If a policy changes, past breached tickets might retroactively look successful.
**Why it happens:** Treating configuration like standard CRUD.
**How to avoid:** Enforce insert-only paradigms in the generated `SLAPolicyProvider.set_policy/2`. Use `Repo.insert` to create a new row, and query the active policy with `order_by: [desc: :inserted_at], limit: 1`.

## Code Examples

### Resolving the Provider Dynamically
```elixir
def active_policies do
  provider = Application.get_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)
  provider.get_active_policies()
end
```

### Igniter Implementation
```elixir
defmodule Mix.Tasks.Cairnloop.Install.SlaPolicies do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_module = Igniter.Project.Application.app_module(igniter)
    provider_module = Module.concat([app_module, Cairnloop, SLAPolicyProvider])

    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      :cairnloop,
      [:sla_policy_provider],
      provider_module
    )
    # Generate migration and schema
    # ...
  end
end
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-1 | Igniter scaffolding works without errors | unit | `mix test test/cairnloop/tasks/install.sla_policies_test.exs` | ❌ |
| REQ-2 | `cairnloop_dashboard` router macro routes `/settings` correctly | unit | `mix test test/cairnloop/router_test.exs` | ❌ |
| REQ-3 | `DefaultSLAPolicyProvider` returns mock static SLAs | unit | `mix test test/cairnloop/default_sla_policy_provider_test.exs` | ❌ |

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Handled by host application via route protection |
| V3 Session Management | yes | Handled by Phoenix LiveView session token |
| V4 Access Control | yes | Future RBAC will leverage the dedicated `/settings` route |
| V5 Input Validation | yes | Ecto Changeset validations for integer ranges and priority enums |
| V6 Cryptography | no | — |

### Known Threat Patterns for Elixir/Phoenix

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Route Spoofing | Spoofing | Macro order matching `/settings` before `/:id` |
| Unbounded SLA Targets | Tampering | Ecto bounds checking (e.g. `validate_number(:target_first_response_minutes, greater_than: 0)`) |

## Sources

### Primary (HIGH confidence)
- `lib/cairnloop/router.ex` - Verified macro route structure and potential `/:id` swallowing pitfall.
- `lib/cairnloop/context_provider.ex` - Verified existing Provider behaviour patterns (dynamic configuration dependency injection).
- `.planning/milestones/M006-phases/M006-S03-CONTEXT.md` - Locked architectural decisions.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Directly follows Cairnloop's existing Igniter + Behaviour standards.
- Architecture: HIGH - Fully detailed in the Discussion/Context output.
- Pitfalls: HIGH - Route matching order is a verifiable standard Phoenix behavior.

**Research date:** 2024-05-18
**Valid until:** Permanent (Architectural design locked)
