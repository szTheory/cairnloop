# Phase 1: Foundation (Telemetry & Events) - Research

**Researched:** Current
**Domain:** Elixir / Telemetry
**Confidence:** HIGH

## Summary

The system's goal of natively emitting rich observability signals when support issues are resolved is already fully implemented and verified. The `resolve_conversation/2` function in `lib/cairnloop/chat.ex` natively utilizes the standard Erlang `:telemetry` module to emit the `[:cairnloop, :conversation, :resolved]` event. It properly attaches payload information such as `conversation_id`, `duration_seconds`, `host_user_id`, `actor`, and `metadata`. Test coverage also exists in `test/cairnloop/chat_test.exs` ensuring this behavior works as intended.

**Primary recommendation:** No further implementation is required for this phase. The planner should create a validation plan that simply verifies the existing implementation and moves immediately to subsequent phases.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M004-REQ-01 | System emits `[:cairnloop, :conversation, :resolved]` telemetry event upon conversation resolution. | `lib/cairnloop/chat.ex` already emits this event using `:telemetry.execute/3`. Tested in `chat_test.exs`. |
| M004-REQ-02 | Event payload includes conversation ID, duration, and any available metadata. | `duration_seconds`, `conversation_id`, `metadata`, etc., are included in the telemetry measurements/metadata payload. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Telemetry Event Emission | API / Backend | — | Emitted within the core backend logic (`cairnloop/chat.ex`) via standard Elixir `:telemetry`. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:telemetry` | standard | Emitting application events | Built-in standard for Elixir observability |

## Architecture Patterns

### Pattern 1: Elixir Telemetry Emission
**What:** The standard way to emit business and domain events in Elixir applications.
**When to use:** Whenever emitting signals for metrics or observability.
**Example:**
```elixir
# Source: lib/cairnloop/chat.ex
:telemetry.execute(
  [:cairnloop, :conversation, :resolved],
  %{count: 1, duration_seconds: duration_seconds},
  %{
    conversation_id: updated_conversation.id,
    host_user_id: updated_conversation.host_user_id,
    actor: actor,
    metadata: Enum.into(metadata, %{})
  }
)
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Observability Events | Custom GenServer or PubSub system | `:telemetry` | Core ecosystem library that easily integrates with external reporting tools. |

**Key insight:** The Erlang `:telemetry` ecosystem is the standard for observability in the beam ecosystem. It allows dynamic handler attachment without tight coupling.

## Common Pitfalls

### Pitfall 1: Missing Event Attributes
**What goes wrong:** Critical fields missing from payload.
**Why it happens:** Incomplete event payload during `telemetry.execute`.
**How to avoid:** Ensure test coverage captures the emitted event payload and asserts all required keys exist.
**Warning signs:** Partial metrics failing to show up in downstream observability systems.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Quick run command | `mix test test/cairnloop/chat_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| M004-REQ-01 | Emits telemetry event on resolve | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Yes |
| M004-REQ-02 | Event payload includes ID and metadata | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Yes |

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements.

## Sources

### Primary (HIGH confidence)
- [VERIFIED: codebase grep] `lib/cairnloop/chat.ex`
- [VERIFIED: codebase grep] `test/cairnloop/chat_test.exs`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - `telemetry` is the de-facto Elixir standard.
- Architecture: HIGH - the logic is already natively implemented within the project using the idiomatic `:telemetry` module.
- Pitfalls: HIGH - Elixir `:telemetry` errors are generally related to missing data in payloads or detached handlers.

**Research date:** 2024
**Valid until:** 2025
