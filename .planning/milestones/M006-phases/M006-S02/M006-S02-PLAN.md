---
phase: M006-S02
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/notifier/chimeway.ex
  - test/cairnloop/notifier/chimeway_test.exs
  - test/cairnloop/workers/check_sla_test.exs
autonomous: true
requirements: [M006-REQ-03, M006-REQ-04, M006-REQ-05]
must_haves:
  truths:
    - Chimeway adapter gracefully handles the absence of the optional chimeway dependency at runtime.
    - Chimeway adapter tests assert the correct payload and idempotency key are dispatched.
    - CheckSLA worker executes without error when no notifier is configured.
  artifacts:
    - path: lib/cairnloop/notifier/chimeway.ex
      provides: Chimeway adapter implementation with safety checks
    - path: test/cairnloop/notifier/chimeway_test.exs
      provides: Tests for payload formatting and dependency safety
    - path: test/cairnloop/workers/check_sla_test.exs
      provides: Tests for configured and unconfigured dispatcher states
  key_links:
    - from: lib/cairnloop/workers/check_sla.ex
      to: Application.get_env(:cairnloop, :notifier)
      via: Dynamic dispatch configuration check
    - from: lib/cairnloop/notifier/chimeway.ex
      to: Chimeway module
      via: Optional dependency verification and configurable module resolution
---

<objective>
Validate the existing "Optional Dep + Default Adapter" architecture and reinforce its reliability. Improve test assertions for side effects (mocking `Chimeway`) and ensure the adapter gracefully handles environments where the optional dependency is omitted.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/milestones/M006-phases/M006-S02-CONTEXT.md
@.planning/milestones/M006-phases/M006-S02/M006-S02-RESEARCH.md
@.planning/M006-ROADMAP.md
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add Unconfigured State Test to CheckSLA</name>
  <files>test/cairnloop/workers/check_sla_test.exs</files>
  <behavior>
    - Test: "worker gracefully defaults to :ok when notifier is not configured"
    - Input: Oban job args for SLA breach, with `:notifier` config explicitly deleted
    - Output: Returns `:ok` without crashing or sending messages
  </behavior>
  <action>
    Add a new test block to `CheckSLATest` that clears the `:notifier` environment variable (using `Application.delete_env/2` if not already handled by setup) and verifies that `Cairnloop.Workers.CheckSLA.perform/1` returns `:ok`. 
  </action>
  <verify>
    <automated>mix test test/cairnloop/workers/check_sla_test.exs</automated>
  </verify>
  <done>CheckSLA worker's fallback behavior is proven safe via test</done>
</task>

<task type="auto">
  <name>Task 2: Implement Dependency Safety & Configurable Chimeway Client</name>
  <files>lib/cairnloop/notifier/chimeway.ex</files>
  <action>
    Modify `Cairnloop.Notifier.Chimeway.on_sla_breach/3` to resolve Pitfall 1 from the research phase and enable testing without Mox.
    1. Read the client module from config: `chimeway_client = Application.get_env(:cairnloop, :chimeway_client, Chimeway)`.
    2. Check if the client module is loaded using `if Code.ensure_loaded?(chimeway_client)`.
    3. If loaded, call `chimeway_client.trigger/3` with the payload and idempotency key, and return `:ok`.
    4. If not loaded, return `{:error, :missing_chimeway_dependency}`.
  </action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>Adapter dynamically checks for the Chimeway module and supports mock injection.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Improve Chimeway Adapter Test Assertions</name>
  <files>test/cairnloop/notifier/chimeway_test.exs</files>
  <behavior>
    - Test 1: Returns error when Chimeway dependency is missing (by configuring a non-existent dummy module).
    - Test 2: Sends correct payload and idempotency key to the configured Chimeway client.
  </behavior>
  <action>
    Update `ChimewayTest` to leverage the configurable `:chimeway_client`.
    Create a local inline mock module (e.g., `DummyChimeway`) inside the test file that implements a `trigger/3` function which uses `send(self(), {:chimeway_triggered, namespace, payload, opts})`.
    In setup or the specific test, configure `:cairnloop, :chimeway_client` to use this mock.
    Assert that `on_sla_breach` results in a received message matching the expected `payload` (with `conversation_id`, `sla_type`, `breached_at`) and `opts` (with `idempotency_key`).
    Add another test configuring the client to a non-existent module name (e.g., `SomeMissingModule`) to verify it returns `{:error, :missing_chimeway_dependency}`.
  </action>
  <verify>
    <automated>mix test test/cairnloop/notifier/chimeway_test.exs</automated>
  </verify>
  <done>Chimeway payload formatting and dependency safety checks are thoroughly asserted.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Oban Worker -> Config | Worker relies on environment config to execute trusted code (Notifier) |
| System -> External (Chimeway) | System dispatches potentially sensitive conversation context (ID, SLA metadata) over external HTTP |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M006-S02-01 | Information Disclosure | `Chimeway.trigger` | mitigate | Ensure adapter payload only contains non-PII IDs and metadata (no raw message bodies) |
| T-M006-S02-02 | Denial of Service | `Chimeway.trigger` | mitigate | Execution is deferred to background worker (Oban) and external trigger is async or isolated |
</threat_model>
