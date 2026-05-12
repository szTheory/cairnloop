<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Duration Calculation (TLM-02)**: Add a `resolved_at` (`:utc_datetime_usec`) column to `cairnloop_conversations` table. Update this field when `resolve_conversation/2` is called. The telemetry event must emit `%{duration_seconds: ...}` dynamically calculated.
2. **Operator Context (TLM-02)**: Standardize resolution signature to `Cairnloop.Chat.resolve_conversation(id, resolved_by: actor, metadata: %{})`. The actor should be explicitly required.
3. **Host Extensibility (EXT-01)**: Documentation must strictly delineate observability via `:telemetry` vs domain business logic (side-effects) via `Cairnloop.Notifier`.

### the agent's Discretion
None explicitly stated, but the exact approach to migrating the DB using Igniter and updating `reply_to_conversation` to set `resolved_at: nil` are logical necessities.

### Deferred Ideas (OUT OF SCOPE)
None explicitly specified.
</user_constraints>

# Phase M004-S01: Resolution Telemetry & Host Extensibility - Research

**Researched:** 2024
**Domain:** Elixir Ecto Migrations, Telemetry, and Igniter Integration
**Confidence:** HIGH

## Summary

The phase requires extending the existing `cairnloop_conversations` table with a new `resolved_at` column, and modifying `Cairnloop.Chat.resolve_conversation` to mandate an actor definition (`resolved_by: actor`). This information, along with a dynamically calculated resolution duration, will be emitted via telemetry. We also need to document how host applications should intercept these lifecycle events correctly depending on their goals (observability vs side-effects).

**Primary recommendation:** Use Igniter to generate an upgrade migration for the database change (and update the install task), modify the `Cairnloop.Chat` module, and provide comprehensive guidance in `README.md` or a new `guides/host_integration.md`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Data Persistence | Database / Ecto | API | Adding `resolved_at` requires a new Ecto schema field and DB migration to durably store the resolution timestamp. |
| Observability | API / Telemetry | — | Calculating duration and emitting `[:cairnloop, :conversation, :resolved]` occurs synchronously in the resolution function using `:telemetry.execute`. |
| Extensibility | API / Behaviours | — | `Cairnloop.Notifier` behaviour is responsible for triggering side-effects in host applications. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Ecto` | Current | Database Migrations & Schemas | Core dependency already in project. |
| `:telemetry` | Current | Event Observability | Standard Erlang/Elixir telemetry library. |
| `Igniter` | Current | Migration Generation | Used in the project for generating host migrations (e.g., `Mix.Tasks.Cairnloop.Install`). |

## Architecture Patterns

### Pattern 1: Elixir Telemetry vs Behaviours
**What:** Strict separation of side-effects.
**When to use:** Use `:telemetry.attach/4` for shipping metrics/events to APMs. Use Behaviours (like `Cairnloop.Notifier`) when your app needs to guarantee a side-effect (like an Oban job) and requires compile-time contract enforcement.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Telemetry routing | Custom pub/sub | `:telemetry.execute` | Built-in standard for Elixir libraries to expose observability hooks. |
| Migration tasks | Manual Ecto scripts | `Igniter.Libs.Ecto.gen_migration` | Consistent with `Cairnloop`'s approach as a host-integrated library. |

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `cairnloop_conversations` table | Data migration (add column) via new mix task (e.g. `Mix.Tasks.Cairnloop.AddResolvedAt`) AND update `Mix.Tasks.Cairnloop.Install` for new users. |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

## Common Pitfalls

### Pitfall 1: Telemetry bottlenecks
**What goes wrong:** Adding heavy side-effects (e.g., API calls to a CRM) directly inside a `:telemetry.attach` handler.
**Why it happens:** Misunderstanding the synchronous nature of `:telemetry.execute`. It runs in the caller's process.
**How to avoid:** Reserve `:telemetry` for fast metrics shipping. Use `Cairnloop.Notifier` to enqueue async background jobs (e.g., `Oban`). The documentation update must explicitly call this out.

### Pitfall 2: Reopened conversations retain `resolved_at`
**What goes wrong:** A conversation is resolved, then reopened, but `resolved_at` stays set, corrupting future duration calculations.
**How to avoid:** Ensure `Cairnloop.Chat.reply_to_conversation` sets `resolved_at: nil` when it flips `status: :open`.

## Code Examples

### Telemetry Execution
```elixir
resolved_at = DateTime.utc_now()
duration_seconds = DateTime.diff(resolved_at, conversation.inserted_at, :second)

:telemetry.execute(
  [:cairnloop, :conversation, :resolved],
  %{count: 1, duration_seconds: duration_seconds},
  %{
    conversation_id: updated_conversation.id,
    host_user_id: updated_conversation.host_user_id,
    resolved_by: resolved_by,
    metadata: metadata
  }
)
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
| TLM-01 | `[:cairnloop, :conversation, :resolved]` telemetry event is emitted | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Wave 0 (missing coverage for this func) |
| TLM-02 | Telemetry includes duration and structured actor map | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Wave 0 (missing coverage for this func) |
| EXT-01 | `Cairnloop.Notifier` is triggered upon resolution | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Wave 0 (missing coverage for this func) |

### Wave 0 Gaps
- `test/cairnloop/chat_test.exs` - Missing tests for `resolve_conversation` specifically. We must add tests to verify the telemetry emission (using `:telemetry_test` or capturing via a process) and the `Notifier` hook behavior.

## Sources

### Primary (HIGH confidence)
- Checked `lib/cairnloop/conversation.ex` (schema)
- Checked `lib/cairnloop/chat.ex` (logic)
- Checked `lib/mix/tasks/cairnloop/install.ex` (migrations generation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - uses existing Ecto/Igniter setup.
- Architecture: HIGH - explicit requirements in CONTEXT.md.
- Pitfalls: HIGH - standard Elixir performance insights regarding synchronous `:telemetry`.

**Research date:** 2024
**Valid until:** Stable
