---
phase: 03-ai-retrieval
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/automation/scoria_engine.ex
  - test/cairnloop/automation/scoria_engine_test.exs
autonomous: true
requirements:
  - M007-REQ-03
must_haves:
  truths:
    - "AI draft generation actively queries the Scrypath index."
    - "AI draft payload includes the retrieved context."
    - "Grounded context is verifiable via test assertions."
  artifacts:
    - path: "lib/cairnloop/automation/scoria_engine.ex"
      provides: "Scrypath context injection into draft payload"
      min_lines: 20
    - path: "test/cairnloop/automation/scoria_engine_test.exs"
      provides: "ScoriaEngine test coverage for context injection"
  key_links:
    - from: "lib/cairnloop/automation/scoria_engine.ex"
      to: "Scrypath API"
      via: "HTTP request using Req"
      pattern: "Req\\.(post|get)"
---

<objective>
Update the Scoria mock execution engine to simulate an MCP Resource read by actively querying the Scrypath index and injecting the retrieved context into the simulated draft payload.

Purpose: Ground AI drafts in factual context retrieved from the Scrypath index, proving out the architectural loop for AI retrieval.
Output: Scoria engine payload includes `context_used` and grounded draft content, with updated test coverage.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/PROJECT_EPICS.md
@.planning/ROADMAP.md
</context>

<tasks>
<task type="auto" tdd="true">
  <name>Task 1: Update ScoriaEngine tests for Scrypath context</name>
  <files>test/cairnloop/automation/scoria_engine_test.exs</files>
  <behavior>
    - Mock a `Req` stub (using `Req.Test` or equivalent) to simulate a successful response from the Scrypath search API.
    - Assert that `ScoriaEngine.generate_draft/1` returns a proposal containing a `:context_used` key.
    - Assert that the `:content` key text is updated to reflect it is a "grounded" draft.
  </behavior>
  <action>
    Update `Cairnloop.Automation.ScoriaEngineTest` to verify the new Scrypath index querying behavior. Use `Req.Test.stub/2` (if `Req` is used for the query) to return dummy Scrypath results (e.g., `%{results: ["relevant context"]}`). Add assertions to ensure the proposal map includes this context in `:context_used` and that the `:content` string implies grounded results.
  </action>
  <verify>
    <automated>mix test test/cairnloop/automation/scoria_engine_test.exs</automated>
  </verify>
  <done>Tests are written, test HTTP dependencies are stubbed, and the test fails correctly expecting the new behavior.</done>
</task>

<task type="auto">
  <name>Task 2: Inject Scrypath context in ScoriaEngine</name>
  <files>lib/cairnloop/automation/scoria_engine.ex</files>
  <action>
    Update `Cairnloop.Automation.ScoriaEngine.generate_draft/1` to actively query the Scrypath index (simulating an MCP Resource read).
    - Read `:scrypath_api_url` from `Application.get_env` (e.g. defaulting to `"https://api.scrypath.local/v1/search"`).
    - Make a `Req` call (GET or POST) passing the `conversation_id`.
    - Inject the retrieved results into the proposal map as `:context_used`.
    - Update the `:content` string to indicate that the draft is now "grounded".
    - Handle any HTTP failures gracefully by falling back to empty context (e.g., `context_used: nil`) so the mock engine doesn't crash entirely.
  </action>
  <verify>
    <automated>mix test test/cairnloop/automation/scoria_engine_test.exs</automated>
  </verify>
  <done>The function fetches context via HTTP, attaches it to the payload, and tests pass successfully.</done>
</task>
</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ScoriaEngine -> Scrypath | Internal service calling another internal/mocked API |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-01 | Information Disclosure | ScoriaEngine Context | accept | Scrypath data is internal context specifically requested for grounding |
| T-03-02 | Denial of Service | Scrypath HTTP Call | mitigate | Handle HTTP errors gracefully, falling back to empty context rather than crashing |
</threat_model>

<verification>
mix test test/cairnloop/automation/scoria_engine_test.exs
</verification>

<success_criteria>
The mock ScoriaEngine explicitly queries Scrypath, successfully injects the fetched data into its output payload as `context_used`, updates its content string, and passes tests.
</success_criteria>
