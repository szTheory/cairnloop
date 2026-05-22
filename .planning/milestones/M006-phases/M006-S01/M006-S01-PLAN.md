---
phase: M006-S01
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/conversations/sla.ex
  - lib/mix/tasks/cairnloop/add_sla_table.ex
  - lib/cairnloop/workers/sla_countdown_worker.ex
  - lib/cairnloop/chat.ex
  - test/cairnloop/conversations/sla_test.exs
  - test/cairnloop/workers/sla_countdown_worker_test.exs
  - test/cairnloop/chat_test.exs
autonomous: true
requirements:
  - M006-REQ-01
  - M006-REQ-02
must_haves:
  truths:
    - "System stores discrete SLA records associated with a conversation"
    - "Oban job is enqueued to evaluate SLA at target time"
    - "Oban worker idempotently checks if the SLA is breached, otherwise no-ops"
  artifacts:
    - path: "lib/cairnloop/conversations/sla.ex"
      provides: "Ecto schema for SLA records"
    - path: "lib/mix/tasks/cairnloop/add_sla_table.ex"
      provides: "Igniter task to generate migration"
    - path: "lib/cairnloop/workers/sla_countdown_worker.ex"
      provides: "Oban worker for SLA evaluation"
  key_links:
    - from: "lib/cairnloop/chat.ex"
      to: "lib/cairnloop/workers/sla_countdown_worker.ex"
      via: "Oban schedule_at in Ecto.Multi"
    - from: "lib/cairnloop/workers/sla_countdown_worker.ex"
      to: "lib/cairnloop/conversations/sla.ex"
      via: "Database query to check SLA status"
---

<objective>
Implement the SLA Countdown Engine by introducing an SLA Ecto schema, an Oban worker to evaluate SLA breaches, and weaving SLA lifecycle creation/fulfillment into existing Chat service operations.

Purpose: To durably and accurately track SLA timelines (e.g., first response, resolution) per conversation, providing an audit trail for SLO metrics while abstracting countdown mechanics away from in-memory constraints.
Output: A new DB schema for SLA records, a scheduled Oban worker, and updated chat transactions.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/milestones/M006-phases/M006-S01-CONTEXT.md
@.planning/milestones/M006-phases/M006-S01/M006-S01-PATTERNS.md
@.planning/milestones/M006-phases/M006-S01/M006-S01-RESEARCH.md
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Data Foundation (Schema & Migration)</name>
  <files>lib/cairnloop/conversations/sla.ex, lib/mix/tasks/cairnloop/add_sla_table.ex, test/cairnloop/conversations/sla_test.exs</files>
  <behavior>
    - Test 1: Changeset validates required fields (status, target_type, target_at, conversation_id).
    - Test 2: Changeset enforces enum values for target_type (:first_response, :next_response, :resolution) and status (:active, :fulfilled, :breached).
  </behavior>
  <action>
    Create the `Cairnloop.Conversations.SLA` Ecto schema. Define fields per CONTEXT.md (`target_type`, `status`, `target_at`, `completed_at`) and standard timestamp handling.
    Create the Igniter task `Mix.Tasks.Cairnloop.AddSlaTable` that outputs a migration for `cairnloop_conversation_slas`. Ensure foreign keys, constraints, and indexes (on `conversation_id`) are applied exactly as modeled in `AddDraftTable` pattern.
  </action>
  <verify>
    <automated>mix test test/cairnloop/conversations/sla_test.exs</automated>
  </verify>
  <done>SLA schema and migration task exist; tests for changeset pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: SLA Countdown Worker</name>
  <files>lib/cairnloop/workers/sla_countdown_worker.ex, test/cairnloop/workers/sla_countdown_worker_test.exs</files>
  <behavior>
    - Test 1: Worker marks an :active SLA as :breached and sets completed_at to now.
    - Test 2: Worker returns :ok without modifications if the SLA is already :fulfilled or :breached.
    - Test 3: Worker gracefully handles missing SLA records (no-op).
  </behavior>
  <action>
    Implement an Oban worker `Cairnloop.Workers.SlaCountdownWorker` expecting an `sla_id` in args. 
    Retrieve the SLA record. If it exists and status is `:active`, update status to `:breached` and `completed_at` to now using a Repo update. 
    If not `:active` or not found, safely return `:ok` to ensure idempotency. 
    Use dependency injection/Application environment retrieval for DB context where appropriate, mimicking `NotifyResolvedWorker`.
  </action>
  <verify>
    <automated>mix test test/cairnloop/workers/sla_countdown_worker_test.exs</automated>
  </verify>
  <done>Worker idempotently transitions active SLA to breached status.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Chat SLA Lifecycle Integration</name>
  <files>lib/cairnloop/chat.ex, test/cairnloop/chat_test.exs</files>
  <behavior>
    - Test 1: User message creates an :active SLA if none exists, enqueues worker.
    - Test 2: User message on a conversation with an existing :active SLA does not create duplicates.
    - Test 3: Operator message fulfills existing :active SLA and starts a :resolution SLA, enqueues worker.
  </behavior>
  <action>
    Modify `Cairnloop.Chat.reply_to_conversation` and `resolve_conversation` Ecto.Multi pipelines to include SLA lifecycle management. Wrap changes in `Cairnloop.Telemetry.span`.
    - If user replies: Check if there is an `:active` SLA for the conversation. If not, insert a new `:first_response` (or `:next_response`) SLA scheduled X hours from now, and insert `SlaCountdownWorker` scheduled for `target_at`. If one exists, skip inserting a new one to prevent duplication.
    - If operator replies: Update any existing `:active` SLA to `:fulfilled` with `completed_at: now()`. Insert a new `:resolution` SLA and enqueue the scheduled worker.
    (Note: Hardcode temporary fallback thresholds e.g., +2 hours, as dynamic configuration is slated for Phase 3).
  </action>
  <verify>
    <automated>mix test test/cairnloop/chat_test.exs</automated>
  </verify>
  <done>Ecto.Multi pipelines natively manage the SLA creation, fulfillment, and job scheduling.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Service → Job Queue | Internal Oban args validation |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M006-01 | Tampering | SLA Schema Status | mitigate | Enforce enum fields and valid state transitions via Ecto Changesets. |
| T-M006-02 | Denial of Service | Oban Worker | mitigate | Ensure idempotency in CheckSLAWorker; no-ops efficiently if job is duplicate or record state advanced. |
</threat_model>

<verification>
- `mix test` passes completely for chat, schema, and workers.
- The Oban job handles SLA state transitions without error.
</verification>

<success_criteria>
- SLA schema exists and migration can be generated via Igniter.
- CheckSLA Oban worker exists and idempotently updates active SLAs.
- Chat operations automatically enqueue and resolve SLAs seamlessly within existing Ecto Multi structures.
</success_criteria>

<output>
After completion, create `.planning/milestones/M006-phases/M006-S01/M006-S01-SUMMARY.md`
</output>
