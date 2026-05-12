---
phase: M004-S01
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/conversation.ex
  - lib/mix/tasks/cairnloop/install.ex
  - lib/mix/tasks/cairnloop/add_resolved_at_column.ex
  - lib/cairnloop/chat.ex
  - test/cairnloop/chat_test.exs
  - README.md
autonomous: true
requirements: [TLM-01, TLM-02, EXT-01]
must_haves:
  truths:
    - "Host applications can reliably react to conversation resolution events"
    - "Duration of the conversation is calculated automatically on resolution"
    - "Actor who resolved the conversation is explicitly tracked"
    - "Observability and business logic extensibility are clearly documented"
  artifacts:
    - path: "lib/cairnloop/conversation.ex"
      provides: "Schema definition with resolved_at field"
    - path: "lib/mix/tasks/cairnloop/add_resolved_at_column.ex"
      provides: "Migration generator for existing installations"
    - path: "lib/cairnloop/chat.ex"
      provides: "Telemetry emission and state update logic"
  key_links:
    - from: "lib/cairnloop/chat.ex"
      to: "telemetry"
      via: ":telemetry.execute"
      pattern: "telemetry\\.execute"
---

<objective>
Implement resolution telemetry and host extensibility hooks for conversations.

Purpose: To allow host applications to predictably hook into conversation resolution for observability (APM) and side-effects (CRM syncing, CSAT triggers) while ensuring rigorous provenance (actor tracking) and data correctness.
Output: Updated database schema, chat service logic emitting telemetry, Igniter migration tasks, and host integration documentation.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/milestones/M004-phases/M004-S01/M004-S01-CONTEXT.md
@.planning/milestones/M004-phases/M004-S01/M004-S01-PATTERNS.md
@.planning/milestones/M004-phases/M004-S01/M004-S01-RESEARCH.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Database Migration & Schema Updates</name>
  <files>lib/cairnloop/conversation.ex, lib/mix/tasks/cairnloop/install.ex, lib/mix/tasks/cairnloop/add_resolved_at_column.ex</files>
  <action>
    - In `lib/cairnloop/conversation.ex`, add `field(:resolved_at, :utc_datetime_usec)`.
    - In `lib/mix/tasks/cairnloop/install.ex`, update the generated `create_cairnloop_conversations` migration body to include `add :resolved_at, :utc_datetime_usec`.
    - Create a new mix task `lib/mix/tasks/cairnloop/add_resolved_at_column.ex` that uses Igniter (patterned after `add_draft_table.ex`) to generate an `alter table(:cairnloop_conversations) do add :resolved_at, :utc_datetime_usec end` migration. Set `on_exists: :skip`.
  </action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>Schema fields are present, install task is updated, and the new Igniter migration task compiles.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Core Logic, Telemetry & Tests</name>
  <files>lib/cairnloop/chat.ex, test/cairnloop/chat_test.exs</files>
  <behavior>
    - Test 1: `resolve_conversation` sets status to `:resolved` and `resolved_at` to current UTC time.
    - Test 2: `resolve_conversation` requires `resolved_by` in options and emits telemetry `[:cairnloop, :conversation, :resolved]` containing `duration_seconds` measurement and `actor` metadata.
    - Test 3: `resolve_conversation` invokes the configured Notifier behaviour.
    - Test 4: `reply_to_conversation` (which reopens) clears `resolved_at` back to `nil`.
  </behavior>
  <action>
    - In `lib/cairnloop/chat.ex`, update `resolve_conversation(conversation_id, opts \\ [])` to require a `resolved_by` keyword argument (e.g. `[resolved_by: actor] = opts`) and optional `metadata`.
    - Inside `resolve_conversation`, set `resolved_at = DateTime.utc_now()` and `status: :resolved` via Ecto Changeset.
    - Calculate `duration_seconds = DateTime.diff(resolved_at, conversation.inserted_at, :second)`.
    - Execute `:telemetry.execute` emitting `%{count: 1, duration_seconds: duration_seconds}` and metadata containing `conversation_id`, `actor`, and `metadata`.
    - Update `notify_resolved` to pass the `actor` context appropriately if needed by the callback.
    - In `reply_to_conversation`, ensure it sets `resolved_at: nil` whenever it transitions a conversation back to `:open`.
    - Add matching tests in `chat_test.exs`.
  </action>
  <verify>
    <automated>mix test test/cairnloop/chat_test.exs</automated>
  </verify>
  <done>Tests pass, telemetry is emitted, and `resolved_at` transitions correctly on resolve and reopen.</done>
</task>

<task type="auto">
  <name>Task 3: Documentation</name>
  <files>README.md</files>
  <action>
    - Add a "Host Integration: Resolving Conversations" section to `README.md`.
    - Explicitly delineate Observability vs. Business Logic as specified in EXT-01.
    - Provide a code snippet for observability using `:telemetry.attach/4` intercepting `[:cairnloop, :conversation, :resolved]` and tracking `duration_seconds` for APMs.
    - Provide a code snippet for business logic demonstrating the implementation of the `Cairnloop.Notifier` behaviour's `on_conversation_resolved` callback to safely trigger side-effects (e.g., enqueueing an Oban job).
  </action>
  <verify>
    <automated>mix format</automated>
  </verify>
  <done>README contains clear guidelines and code snippets outlining the dual-track integration pattern.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Host Application -> API | Host application provides `resolved_by` provenance to `resolve_conversation`. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M004-01 | Tampering | `chat.ex` | mitigate | Explicitly require `resolved_by` actor map in the function signature, preventing unauthenticated system calls from bypassing audit tracking. |
| T-M004-02 | Info Disclosure | `telemetry` | accept | Telemetry runs synchronously in host process; host is trusted to filter PII before sending to APMs. |
</threat_model>

<verification>
1. Compile the application and ensure no syntax or resolution errors.
2. Run the test suite specifically for `chat_test.exs`.
3. Check `README.md` to ensure the host extensibility documentation is complete and accurate.
</verification>

<success_criteria>
- `cairnloop_conversations` has a `resolved_at` field and supporting Igniter migrations.
- `resolve_conversation` correctly records `resolved_at` and calculates duration.
- `[:cairnloop, :conversation, :resolved]` telemetry event is emitted with proper metadata.
- Reopening a conversation correctly unsets `resolved_at`.
- Host integration is cleanly documented separating telemetry from Notifier behaviours.
</success_criteria>

<output>
After completion, create `.planning/milestones/M004-phases/M004-S01/M004-S01-SUMMARY.md`
</output>
