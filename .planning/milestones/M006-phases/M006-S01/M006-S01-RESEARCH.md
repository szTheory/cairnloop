# Phase 1: SLA Countdown Engine (Oban) - Research

**Researched:** 2024-05-14
**Domain:** Elixir/Ecto Backend, Oban Background Jobs
**Confidence:** HIGH

## Summary

The SLA Countdown Engine will introduce a new Ecto schema (`Cairnloop.Conversations.SLA`) to track service level agreements (e.g., `:first_response`, `:next_response`, `:resolution`) for each conversation. We will use `Igniter` to create a migration task (`cairnloop_conversation_slas`), mirroring the pattern used for the `cairnloop_drafts` table. State transitions for SLAs will be bundled directly into the existing `Ecto.Multi` chains inside `Cairnloop.Chat.reply_to_conversation/4` and `resolve_conversation/2`. The engine uses an Oban worker (`CheckSLAWorker`) to evaluate the SLA status idempotently when the target time is reached.

**Primary recommendation:** Introduce `Cairnloop.Conversations.SLA` and weave SLA creation/fulfillment into the `Ecto.Multi` transactions within `Cairnloop.Chat`, leveraging Oban's `schedule_at` functionality to trigger the evaluation job.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Architectural Decision: Multiple SLAs Model Upfront**: Implement a dedicated Ecto schema (`cairnloop_conversation_slas`) rather than mutating a single timestamp on the `cairnloop_conversations` table.
- **Ergonomics (Push-based Oban)**: One target = one row = one scheduled Oban job.
- **State transitions**: Should be bundled into the existing `Ecto.Multi` chains inside `Cairnloop.Chat`.

### the agent's Discretion
- None explicitly requested, but fallback thresholds and the precise check for existing active SLAs during `reply_to_conversation` require careful handling to avoid duplicating SLAs on consecutive user messages.

### Deferred Ideas (OUT OF SCOPE)
- **LiveView Configuration (Phase 3)**: Exposing these SLA configurations to operators in a UI is out of scope for Phase 1.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M006-REQ-01 | System schedules an Oban job (`CheckSLA`) when a conversation is created or updated. | `Cairnloop.Chat`'s `Ecto.Multi` transactions will enqueue jobs with Oban's `schedule_at`. |
| M006-REQ-02 | The `CheckSLA` job executes idempotently, returning NOOP if the conversation is already resolved or replied to. | Job queries the `cairnloop_conversation_slas` record by ID; if status is not `:active`, it safely ignores it. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SLA Tracking (CRUD) | API / Backend (Ecto) | Database | SLAs are persisted records directly tied to conversations to maintain an audit trail for Parapet SLIs. |
| SLA Expiration Triggering | API / Backend (Oban) | Database | Oban provides reliable, persistent background job processing that integrates smoothly with Ecto.Multi and survives system restarts. |
| SLA Status Resolution | API / Backend (Services)| — | `Cairnloop.Chat` governs the business logic for state changes (e.g., message insertions) and determines SLA fulfillment. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Ecto` | Current | SLA Database Schema | Built-in mapping, queries, and multi-record transactions matching project standards. |
| `Oban` | Current | Background job processing | Idempotent SLA countdown jobs using PostgreSQL for persistence. |
| `Igniter` | Current | DB Migration | Consistent scaffolding tool for adding database tables in the project. |

## Architecture Patterns

### System Architecture Diagram
```
[User/Agent Action] -> Cairnloop.Chat (reply_to_conversation/resolve_conversation)
    |
    v
[Ecto.Multi Transaction]
    |-- 1. Insert/Update Message/Conversation
    |-- 2. Update existing :active SLA to :fulfilled (if applicable)
    |-- 3. Insert new :active SLA with `target_at` (e.g., :first_response)
    |-- 4. Enqueue `CheckSLAWorker` Oban Job for `target_at`
    v
[PostgreSQL Database] -> Stores records & Oban jobs
    |
(When `target_at` occurs)
    |
[Oban Scheduler] -> Executes `CheckSLAWorker`
    |
    |-- Check SLA Status:
        |-- If :active -> Mark as :breached, set `completed_at`
        |-- If :fulfilled/:breached -> No-op (idempotent)
```

### Pattern 1: Idempotent SLA Worker
**What:** The Oban worker simply checks the state of the SLA record at execution time. It doesn't rely on complex state machines; if the SLA is no longer active, it exits safely.
**When to use:** Tracking time-based targets.
**Example:**
```elixir
def perform(%Oban.Job{args: %{"sla_id" => sla_id}}) do
  sla = Repo.get(SLA, sla_id)
  
  if sla && sla.status == :active do
    # Mark breached
  else
    :ok # No-op
  end
end
```

### Pattern 2: Igniter Migration Task
**What:** Using Igniter to ensure the library's schemas can be added safely to a host project's repository.
**When to use:** Whenever introducing new tables to the Cairnloop library (`add_sla_table.ex`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| In-memory countdown timers | `Process.send_after` or `GenServer` state loops | `Oban` | In-memory timers are lost on deploy/restart. Oban persists jobs to PostgreSQL ensuring SLAs trigger reliably regardless of application lifecycle. |

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None | N/A - Greenfield schema |
| Live service config | None | N/A |
| OS-registered state | None | N/A |
| Secrets/env vars | None | Will need application env config for threshold times |
| Build artifacts | None | N/A |

## Common Pitfalls

### Pitfall 1: Multi-insertion of SLAs
**What goes wrong:** A user sends multiple messages consecutively, triggering the creation of multiple `:first_response` or `:next_response` SLAs.
**Why it happens:** The `reply_to_conversation` logic blindly inserts an SLA for every user message.
**How to avoid:** Ensure the `Ecto.Multi` chain checks for an existing `:active` SLA for the conversation before creating a new one.

### Pitfall 2: Lost audit trail on updates
**What goes wrong:** Updating an SLA to a new target time instead of marking it fulfilled and creating a new one.
**Why it happens:** Attempting to optimize row count.
**How to avoid:** Never modify `target_at` or `target_type` of an existing SLA. Always transition `status` to `:fulfilled` and insert a brand new record for the next phase.

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
| M006-REQ-01 | Schedule Oban job on conversation update | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Wave 0 |
| M006-REQ-02 | CheckSLA job executes idempotently | unit | `mix test test/cairnloop/workers/sla_countdown_worker_test.exs` | ❌ Wave 0 |

### Wave 0 Gaps
- [ ] `test/cairnloop/conversations/sla_test.exs` — Test Ecto changesets
- [ ] `test/cairnloop/workers/sla_countdown_worker_test.exs` — Test idempotent job execution
- [ ] `test/cairnloop/tasks/add_sla_table_test.exs` — (Optional) Igniter task test

## Code Examples

### Telemetry Wrapped Chat Service
Following `Cairnloop.Chat` conventions, operations on SLAs should be embedded into the multi chains safely:

```elixir
# Example snippet for Ecto.Multi addition inside reply_to_conversation
multi = 
  if role == :user do
    Ecto.Multi.run(multi, :sla, fn repo, _changes ->
      # Check for active SLA, insert if none, enqueue worker
      # ...
    end)
  else
    Ecto.Multi.run(multi, :sla, fn repo, _changes ->
      # Find active SLA, fulfill it, create :resolution SLA, enqueue worker
      # ...
    end)
  end
```

## Environment Availability
Step 2.6: SKIPPED (no external dependencies identified beyond Elixir/Postgres already in project)

## Sources
### Primary (HIGH confidence)
- `M006-S01-CONTEXT.md` - Verified architecture decisions
- `M006-S01-PATTERNS.md` - Verified mapping to existing files
- `lib/cairnloop/chat.ex` - Checked existing multi chains and structure
- `test/cairnloop/chat_test.exs` - Checked testing structure and requirements
