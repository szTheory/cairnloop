---
phase: M007-S01
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mix.exs
  - lib/cairnloop/workers/ingest_scrypath.ex
  - lib/cairnloop/application.ex
  - test/cairnloop/workers/ingest_scrypath_test.exs
autonomous: true
requirements:
  - M007-REQ-01
  - M007-REQ-02
must_haves:
  truths:
    - Resolving a conversation emits a telemetry event.
    - System asynchronously enqueues an Oban job upon resolution.
    - The worker logic successfully prepares data for the Scrypath API.
  artifacts:
    - path: mix.exs
      provides: Scrypath dependency declaration
    - path: lib/cairnloop/workers/ingest_scrypath.ex
      provides: Oban worker for API ingestion
    - path: lib/cairnloop/application.ex
      provides: Telemetry handler wiring for resolved conversations
  key_links:
    - from: lib/cairnloop/application.ex
      to: lib/cairnloop/workers/ingest_scrypath.ex
      via: Telemetry handler enqueuing Oban worker
---

<objective>
Implement telemetry and asynchronous ingestion for conversation resolution events.

Purpose: Seamlessly index resolved conversations into the Scrypath vector database, powering future operator semantic search and AI grounding.
Output: Oban worker for Scrypath ingestion and telemetry handlers securely wired.
</objective>

<context>
@.planning/M007-ROADMAP.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add Scrypath Dependency</name>
  <files>mix.exs</files>
  <action>Add `:scrypath` to the `deps` list in `mix.exs` with `optional: true` configuration.</action>
  <verify>
    <automated>mix deps.get &amp;&amp; mix compile</automated>
  </verify>
  <done>Scrypath is successfully retrieved and compiled without errors.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create IngestScrypath Worker</name>
  <files>lib/cairnloop/workers/ingest_scrypath.ex, test/cairnloop/workers/ingest_scrypath_test.exs</files>
  <behavior>
    - Test 1: Worker perform/1 processes valid arguments and successfully makes or mocks the API call to Scrypath for vector embedding and indexing.
  </behavior>
  <action>Create the Oban worker `Cairnloop.Workers.IngestScrypath`. It must define a `perform/1` function that handles API communication with Scrypath to generate embeddings and index the conversation text. Use standard ExUnit assertions to verify behavior, mocking external API calls if necessary.</action>
  <verify>
    <automated>mix test test/cairnloop/workers/ingest_scrypath_test.exs</automated>
  </verify>
  <done>Worker logic is fully implemented and passes all unit tests.</done>
</task>

<task type="auto">
  <name>Task 3: Attach Telemetry Handler</name>
  <files>lib/cairnloop/application.ex</files>
  <action>Update `Cairnloop.Application` to attach a `:telemetry` handler to the `[:cairnloop, :conversation, :resolved]` event. This handler should be responsible for asynchronously enqueuing the `Cairnloop.Workers.IngestScrypath` Oban worker with the resolved conversation's relevant details.</action>
  <verify>
    <automated>mix test</automated>
  </verify>
  <done>Telemetry handler is attached and properly enqueues the worker upon the resolved event.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Application → Scrypath API | Resolving conversations pushes internal text/metadata to an external vector database. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M007-S01-01 | Information Disclosure | IngestScrypath | mitigate | Ensure communication with Scrypath happens strictly over HTTPS/TLS. |
| T-M007-S01-02 | Denial of Service | Telemetry Handler | mitigate | Delegate indexing workload to Oban worker asynchronously rather than blocking the telemetry event emitter. |
</threat_model>

<success_criteria>
- The system correctly handles the `[:cairnloop, :conversation, :resolved]` telemetry event.
- The `IngestScrypath` worker is successfully enqueued and can hit the Scrypath API.
- `mix.exs` lists `:scrypath` as an optional dependency.
- `mix test test/cairnloop/workers/ingest_scrypath_test.exs` passes successfully.
</success_criteria>

<output>
After completion, create `.planning/milestones/M007-phases/M007-S01/M007-S01-01-SUMMARY.md`
</output>