# Phase M004-S02: Customer Satisfaction (CSAT) Capture - Research

**Researched:** 2024-05-24
**Domain:** Elixir/Phoenix Backend & Ecto (cairnloop library)
**Confidence:** HIGH

## Summary
To implement the CSAT capture, we need to modify the data model to support arbitrary metadata on messages and CSAT ratings on conversations. Since `cairnloop` is an embeddable library that uses `Igniter` for installation and migrations, we must update the base installation migration and provide a new Mix task for existing installations to apply the schema updates. The backend will hook into the existing `Cairnloop.Chat.resolve_conversation/2` function to insert a system message, and `Cairnloop.Channels.WidgetChannel` will be updated to handle the `submit_csat` event. The channel delegates persistence to a new `Cairnloop.Chat.submit_csat/2` function, which saves the rating and executes the required telemetry event.

**Primary recommendation:** Use `Ecto.Enum` for `csat_rating` to safely validate inbound payload strings, and `Igniter.Libs.Ecto.gen_migration` for DB migrations to integrate with the host application. Extract the conversation ID dynamically from `socket.topic` in the channel.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
#### 1. Delivery Mechanism (System Message)
We will **NOT** use an ephemeral channel event to trigger the CSAT UI. Instead, we will leverage **System Messages**.
* When a conversation is resolved, the backend will atomically insert a `Message` with `role: :system` and `metadata: %{"type" => "csat_request"}`.
* This guarantees durability: if a user reconnects hours later, the CSAT prompt is still waiting for them at the bottom of the timeline.
* It enables omnichannel support (e.g., rendering the prompt in an email thread).
* The client widget will intercept this specific system message type and render an interactive CSAT component instead of a text bubble.

#### 2. Rating Scale
The CSAT rating will use a **Thumbs up/down** binary scale.

#### 3. Data Model Updates
* **Messages:** Add a `metadata` (JSONB/map) column to `cairnloop_messages` to support arbitrary structured data on system events (like `type: "csat_request"`).
* **Conversations:** Add a `csat_rating` (string/enum) column to `cairnloop_conversations` allowing values like `:positive` or `:negative`. This fulfills the requirement to "durably store the rating on the conversation record."

#### 4. Submission
When the user selects a rating in the widget UI:
1. The widget will push a `"submit_csat"` event to the `WidgetChannel` with the selected score.
2. The backend will update the `csat_rating` on the `Conversation` record.
3. The backend will execute the `[:cairnloop, :feedback, :csat_submitted]` telemetry event.

### the agent's Discretion
None explicitly defined in CONTEXT.md, but the agent determines how to correctly implement migrations via Igniter and how to organize the Ecto logic.

### Deferred Ideas (OUT OF SCOPE)
None defined.
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| System Message Delivery | API / Backend | Database | Backend `Cairnloop.Chat.resolve_conversation/2` must insert the message atomically alongside the conversation status update. |
| Rating Submission | API / Backend | Frontend Server (Phoenix Channel) | The channel (`WidgetChannel`) receives the event and delegates to the backend (`Cairnloop.Chat`) to persist and emit telemetry. |
| Schema Management | Database | Igniter | Since this is a library, database migrations are managed via `Igniter` Mix tasks generated into the host app. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto | Current | Database modeling | The project already uses Ecto. `Ecto.Enum` natively supports safely casting string ratings to atoms without exhaustion risks. |
| Igniter | Current | Code generation/migrations | The library relies on `Igniter` to inject code and schema migrations into host apps (e.g., `mix igniter.install`). |

## Architecture Patterns

### Pattern 1: Ecto.Multi for Atomic Operations
**What:** Combining multiple database operations into a single transaction.
**When to use:** When modifying multiple related records, such as marking a conversation as resolved and inserting a system message simultaneously.
**Example:**
```elixir
    Ecto.Multi.new()
    |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :resolved, resolved_at: resolved_at}))
    |> Ecto.Multi.insert(:csat_message, Message.changeset(%Message{}, %{
      conversation_id: conversation.id,
      content: "Please rate your experience.", # required by changeset, but UI can ignore based on metadata
      role: :system,
      metadata: %{"type" => "csat_request"}
    }))
    |> repo().transaction()
```

### Pattern 2: Igniter Migration Tasks
**What:** Creating a Mix task that host applications can run to generate and inject migrations.
**When to use:** Whenever the library's data model changes.
**Example:**
Create `lib/mix/tasks/cairnloop/add_csat_and_metadata_columns.ex` matching the pattern of existing tasks (e.g., `AddResolvedAtColumn`), using `Igniter.Libs.Ecto.gen_migration`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String-to-Atom Casting | Manual `String.to_existing_atom/1` | `Ecto.Enum` | `Ecto.Enum` safely parses inputs (like `"positive"`) and validates them intrinsically without potential atom-exhaustion vulnerability. |
| DB Migrations | Raw SQL files | `Igniter.Libs.Ecto.gen_migration` | Keeps the library integrated smoothly into host apps, respecting their specific Ecto Repo setups. |

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Host applications' database schemas | Data migration: Provide a new `Igniter` Mix task to add `:metadata` (`:map`) to messages and `:csat_rating` (`:string`) to conversations. Update `Mix.Tasks.Cairnloop.Install`. |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

## Common Pitfalls

### Pitfall 1: Channel Topic Parsing
**What goes wrong:** Failing to securely extract the `conversation_id` from the channel topic.
**Why it happens:** Assuming it will always be passed in the payload or not matching the Phoenix topic pattern correctly.
**How to avoid:** Use pattern matching on `socket.topic` in the `handle_in` clause explicitly: `"widget:" <> conversation_id = socket.topic`.

### Pitfall 2: Missing Base Migration Updates
**What goes wrong:** New users installing the library don't get the new columns, resulting in crashes.
**Why it happens:** Only creating an update migration without updating the base `Mix.Tasks.Cairnloop.Install`.
**How to avoid:** Remember to update `lib/mix/tasks/cairnloop/install.ex` to include the `metadata` and `csat_rating` fields in the primary `create_cairnloop_tables` string body.

## Code Examples

### WidgetChannel Event Handler
```elixir
  @impl true
  def handle_in("submit_csat", %{"rating" => rating}, socket) do
    # Extract conversation_id from the joined room
    "widget:" <> conversation_id = socket.topic

    case Cairnloop.Chat.submit_csat(conversation_id, rating) do
      {:ok, _conversation} ->
        {:reply, :ok, socket}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "invalid_rating"}}, socket}
    end
  end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom schemas for specific system events | Map/JSONB metadata field | Current phase | Allows the UI to render completely custom components purely based on the `metadata.type` property. Highly scalable pattern. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Extracting `conversation_id` from `socket.topic` like `"widget:" <> id = socket.topic` is correct. | Code Examples | [ASSUMED] The channel logic is `"widget:" <> _private_room_id` where `_private_room_id` is the conversation ID. If this mapping changes, the channel handler will crash. |
| A2 | The `content` field on `Cairnloop.Message` must be populated even for system messages. | Architecture Patterns | [ASSUMED] The changeset validates required `:content`. Providing a fallback string like "Please rate your experience" satisfies DB constraints safely. |

## Open Questions

1. **Message Content Requirement** (RESOLVED)
   - What we know: `Cairnloop.Message.changeset` requires `:content`.
   - What's unclear: Should we provide a placeholder like `"Please rate your conversation"` or change the schema to allow `nil` content when `role == :system`?
   - Recommendation: Pass a placeholder string during resolution so the DB constraint succeeds. The frontend widget will parse `metadata.type == "csat_request"` and replace the render block, ignoring the content anyway.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified)

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
| REQ-CSAT | `resolve_conversation/2` inserts system message with `metadata` | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Wave 0 |
| REQ-CSAT | `submit_csat/2` updates rating and emits telemetry | unit | `mix test test/cairnloop/chat_test.exs` | ✅ Wave 0 |
| REQ-CSAT | `WidgetChannel` handles `submit_csat` and delegates | unit | `mix test test/cairnloop/channels/widget_channel_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/cairnloop/channels/widget_channel_test.exs` — Covers `WidgetChannel` joining and `submit_csat` telemetry handling. (File currently missing)
- [ ] Migrations test (Verifying Igniter correctly generates the new task migration).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Channel connection token validation (`WidgetSocket.connect/3`) |
| V3 Session Management | yes | Channel presence/join access controls via auth token |
| V4 Access Control | yes | User can only submit CSAT for the room they joined |
| V5 Input Validation | yes | Use `Ecto.Enum` to validate rating payload |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for Elixir/Phoenix

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Atom Exhaustion | Denial of Service | `Ecto.Enum` or explicit mapping instead of unsafe `String.to_atom` |
| Unauthenticated Channel Join | Information Disclosure | Handled by existing `WidgetSocket` token checks |

## Sources

### Primary (HIGH confidence)
- Codebase Context (`lib/cairnloop/chat.ex`, `lib/cairnloop/channels/widget_channel.ex`) - implementation context.
- `.planning/milestones/M004-phases/M004-S02/M004-S02-CONTEXT.md` - Phase constraints.
- Elixir/Phoenix standard practices - `Ecto.Enum` usages and Phoenix Channel telemetry standards.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Ecto and Igniter are already standard within this library.
- Architecture: HIGH - The proposed changes naturally fit `Cairnloop.Chat` and existing widget paradigms.
- Pitfalls: HIGH - Addresses common Phoenix Channel and DB migration issues effectively.

**Research date:** 2024-05-24
**Valid until:** 30 days
