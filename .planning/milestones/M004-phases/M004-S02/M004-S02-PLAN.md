---
phase: M004-S02
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/mix/tasks/cairnloop/add_csat_columns.ex
  - lib/mix/tasks/cairnloop/install.ex
  - lib/cairnloop/message.ex
  - lib/cairnloop/conversation.ex
  - lib/cairnloop/chat.ex
  - test/cairnloop/chat_test.exs
  - lib/cairnloop/channels/widget_channel.ex
  - test/cairnloop/channels/widget_channel_test.exs
autonomous: true
requirements:
  - REQ-CSAT
  - SNT-01
  - SNT-02
  - SNT-03
must_haves:
  truths:
    - User sees a frictionless CSAT rating prompt upon conversation resolution
    - Ratings are durably stored on the conversation record
    - Telemetry is emitted when feedback is submitted
  artifacts:
    - path: lib/mix/tasks/cairnloop/add_csat_columns.ex
      provides: CSAT database migration task
    - path: lib/cairnloop/message.ex
      provides: Message metadata schema field
    - path: lib/cairnloop/chat.ex
      provides: Backend functions for CSAT logic
  key_links:
    - from: lib/cairnloop/channels/widget_channel.ex
      to: lib/cairnloop/chat.ex
      via: Cairnloop.Chat.submit_csat/2
      pattern: Cairnloop.Chat.submit_csat
    - from: lib/cairnloop/chat.ex
      to: telemetry
      via: execute
      pattern: :telemetry.execute\(\[:cairnloop, :feedback, :csat_submitted\]
---

<objective>
Implement Customer Satisfaction (CSAT) capture backend logic and database models.

Purpose: Enable users to provide feedback seamlessly after a conversation resolves and capture that data durably for telemetry and metrics.
Output: Igniter migration tasks, updated Ecto models, modified chat backend logic, and channel handlers.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/milestones/M004-phases/M004-S02/M004-S02-CONTEXT.md
@.planning/milestones/M004-phases/M004-S02/M004-S02-PATTERNS.md
@.planning/milestones/M004-phases/M004-S02/M004-S02-RESEARCH.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Data Model and Migrations</name>
  <files>lib/mix/tasks/cairnloop/add_csat_columns.ex, lib/mix/tasks/cairnloop/install.ex, lib/cairnloop/message.ex, lib/cairnloop/conversation.ex</files>
  <action>Create `AddCsatColumns` Mix task using `Igniter.Libs.Ecto.gen_migration`. The migration adds `metadata` (:map) to `cairnloop_messages` and `csat_rating` (:string) to `cairnloop_conversations`. Follow the pattern in `add_resolved_at_column.ex`. Update `lib/mix/tasks/cairnloop/install.ex` to include `add :metadata, :map` on messages and `add :csat_rating, :string` on conversations in the create table statement. Update `Cairnloop.Message`: Add `field(:metadata, :map, default: %{})` and cast it in changeset. Update `Cairnloop.Conversation`: Add `field(:csat_rating, Ecto.Enum, values: [:positive, :negative])` and cast it in changeset.</action>
  <verify>
    <automated>mix test</automated>
  </verify>
  <done>Ecto schemas and Igniter tasks are updated and compile successfully.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Chat Service Backend Logic</name>
  <files>lib/cairnloop/chat.ex, test/cairnloop/chat_test.exs</files>
  <behavior>
    - `resolve_conversation/2`: Modifies the Ecto.Multi to also insert a System message with `content: "Please rate your experience."`, `role: :system`, and `metadata: %{"type" => "csat_request"}`.
    - `submit_csat/2`: New function taking `conversation_id` and `rating` (string). Updates the conversation's `csat_rating`. Executes telemetry `[:cairnloop, :feedback, :csat_submitted]` with count and conversation ID/rating.
  </behavior>
  <action>Implement the logic as specified in the behavior block, ensuring transaction safety with `Ecto.Multi` inside `resolve_conversation/2`. Add unit tests verifying both the system message creation on resolution and the telemetry plus state update on CSAT submission.</action>
  <verify>
    <automated>mix test test/cairnloop/chat_test.exs</automated>
  </verify>
  <done>Chat context handles system message insertion and rating submission correctly.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Widget Channel Integration</name>
  <files>lib/cairnloop/channels/widget_channel.ex, test/cairnloop/channels/widget_channel_test.exs</files>
  <behavior>
    - Handle `submit_csat` event in `WidgetChannel`.
    - Extract `conversation_id` from `socket.topic` (e.g. `"widget:" <> conversation_id = socket.topic`).
    - Delegate to `Cairnloop.Chat.submit_csat/2`. Reply `:ok` if successful, or `{:error, %{reason: "invalid_rating"}}` if changeset fails.
  </behavior>
  <action>Add the new `handle_in("submit_csat", ...)` clause. Create the missing test file `widget_channel_test.exs` and write a test confirming the channel correctly extracts the conversation ID and handles successful/failed submissions.</action>
  <verify>
    <automated>mix test test/cairnloop/channels/widget_channel_test.exs</automated>
  </verify>
  <done>Widget channel successfully processes rating submissions and returns appropriate Phoenix replies.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Client -> WidgetChannel | Untrusted rating inputs submitted by users over WebSockets. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M004-S02-01 | Tampering | `submit_csat` | mitigate | Use Ecto.Enum to safely cast and validate incoming `rating` strings, preventing atom exhaustion or invalid states. |
| T-M004-S02-02 | Spoofing | `WidgetChannel` | mitigate | Extract conversation ID dynamically from the authenticated `socket.topic` rather than relying on payload parameters. |
</threat_model>

<verification>
- `mix test` passes fully without errors.
- DB migrations compile.
- Igniter mix tasks correctly inject the fields.
</verification>

<success_criteria>
Users can successfully click a rating on a resolved conversation and have it stored natively on the Conversation record, with telemetry tracking the metric.
</success_criteria>

<output>
After completion, create `.planning/milestones/M004-phases/M004-S02/M004-S02-SUMMARY.md`
</output>
