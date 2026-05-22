# Phase M006-S02: Optional Dep + Default Adapter - Research

**Researched:** 2024-05-15
**Domain:** Elixir Behaviours, Optional Dependencies, and Background Workers
**Confidence:** HIGH

## Summary
The research investigated the "Optional Dep + Default Adapter" pattern for dispatching SLA breach notifications to the host app using Chimeway. The investigation found that the structural requirements outlined in `M006-S02-CONTEXT.md` and `M006-S02-PATTERNS.md` are **already fully implemented** in the current state of the codebase. 

The system defines a flexible `Cairnloop.Notifier` behaviour, provides a default `Cairnloop.Notifier.Chimeway` adapter utilizing the optional `:chimeway` dependency, and dynamically dispatches events from the `CheckSLA` Oban worker based on the host application's configuration.

**Primary recommendation:** Since the structural components are already in place, the primary focus should be on refining test assertions (e.g., using Mox for stronger adapter testing) and ensuring robust fallback logic if the adapter is unconfigured or if the optional dependency is missing at runtime.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Implement the Optional Dep + Default Adapter pattern for integrating Chimeway.
- Make `:chimeway` an `optional: true` dependency in `mix.exs`.
- The core logic only interacts with a strict `Cairnloop.Notifier` behaviour.
- Provide a `Cairnloop.Notifier.Chimeway` adapter.
- The `CheckSLA` Oban worker calls the configured notifier synchronously, and the adapter enqueues the outbound delivery.

### the agent's Discretion
- None explicitly stated, but implies discretion on testing and fallback mechanisms for the optional dependency.

### Deferred Ideas (OUT OF SCOPE)
- None explicitly stated.
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Notification Definition | Core Behaviour (`Cairnloop.Notifier`) | — | Defines the strict contract for system events (SLA breaches, resolution). |
| Notification Delivery | Adapter (`Cairnloop.Notifier.Chimeway`) | — | Implements the delivery mechanism (via Chimeway) without polluting core business logic. |
| Event Evaluation & Trigger | API / Backend (`Cairnloop.Workers.CheckSLA`) | — | Background workers evaluate state and trigger the configured notifier dynamically. |

## Current Implementation State

### 1. The Notifier Behaviour
- **File:** `lib/cairnloop/notifier.ex`
- **Status:** Fully implemented. 
- **Details:** The `@callback on_conversation_resolved/2` exists, alongside the `@callback on_sla_breach/3`. Both return `:ok | {:error, term()} | any()`, providing flexibility for different adapters.

### 2. The Chimeway Adapter
- **File:** `lib/cairnloop/notifier/chimeway.ex`
- **Status:** Fully implemented.
- **Details:** The module correctly implements the `@behaviour Cairnloop.Notifier`. `on_sla_breach/3` maps the arguments to a payload map and delegates to `Chimeway.trigger/3` with an idempotency key. `on_conversation_resolved/2` is stubbed out to return `:ok`.

### 3. Optional Dependency Configuration
- **File:** `mix.exs`
- **Status:** Fully implemented.
- **Details:** `{:chimeway, "~> 1.0", optional: true}` is present in the `deps()` list.

### 4. Dynamic Dispatch in Oban Workers
- **File:** `lib/cairnloop/workers/check_sla.ex`
- **Status:** Fully implemented.
- **Details:** The `perform/1` function evaluates the SLA and then dynamically resolves the notifier using `Application.get_env(:cairnloop, :notifier)`. If a valid atom is returned, it calls `notifier.on_sla_breach(conversation, sla, %{})`. Otherwise, it gracefully defaults to `:ok`.

## Common Pitfalls

### Pitfall 1: Missing Optional Dependency at Runtime
**What goes wrong:** If a host app configures `Cairnloop.Notifier.Chimeway` as the notifier but does *not* include the `:chimeway` package in their own `mix.exs`, calling `Chimeway.trigger/3` will raise an `UndefinedFunctionError` at runtime.
**How to avoid:** The adapter could check if `Code.ensure_loaded?(Chimeway)` returns true before attempting to call it, or documentation must clearly instruct users to include the dependency if they use the default adapter.

### Pitfall 2: Weak Test Assertions
**What goes wrong:** `Cairnloop.Notifier.ChimewayTest` currently only asserts that `on_sla_breach` returns `:ok` without crashing. It does not verify that `Chimeway.trigger/3` was actually called with the correct payload and idempotency key.
**How to avoid:** Use a mocking library like `Mox` to define a mock for the `Chimeway` behaviour (if Chimeway provides one) or use an intercept pattern to verify side effects and arguments directly.

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
| REQ-01 | CheckSLA dynamic dispatch | unit | `mix test test/cairnloop/workers/check_sla_test.exs` | ✅ Yes |
| REQ-02 | Chimeway adapter implementation | unit | `mix test test/cairnloop/notifier/chimeway_test.exs` | ✅ Yes |
| REQ-03 | Notifier behaviour definition | unit | `mix test test/cairnloop/notifier_test.exs` | ✅ Yes |

### Current Testing Strategy & Gaps
The `CheckSLA` test correctly uses a local `DummyNotifier` to intercept and assert the callback was invoked. This is a robust pattern for testing configuration-driven dynamic dispatch without needing heavy mocks. However, the `ChimewayTest` (`test/cairnloop/notifier/chimeway_test.exs`) lacks assertions on the external HTTP trigger, merely verifying the function doesn't crash given valid structs. This should be addressed to prevent regressions in payload formatting.

## Code Examples

### Standard Dynamic Dispatch Pattern
```elixir
# Source: lib/cairnloop/workers/check_sla.ex
case Application.get_env(:cairnloop, :notifier) do
  notifier when is_atom(notifier) and not is_nil(notifier) ->
    notifier.on_sla_breach(conversation, sla, %{})

  _ ->
    :ok # Fallback if no notifier is configured
end
```