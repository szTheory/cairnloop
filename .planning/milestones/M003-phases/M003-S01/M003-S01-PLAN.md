---
phase: M003
plan: S01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/context_provider.ex
  - lib/cairnloop/default_context_provider.ex
  - test/cairnloop/context_provider_test.exs
  - lib/cairnloop/web/conversation_live.ex
  - test/cairnloop/web/conversation_live_test.exs
autonomous: true
requirements:
  - S01
must_haves:
  truths:
    - "Developer can define a module implementing Cairnloop.ContextProvider"
    - "The callback signature returns a tagged tuple ({:ok, map()} or {:error, term()}) for graceful error handling"
    - "The callback accepts an actor_id string directly, deferring domain mapping to the host"
    - "LiveView gracefully handles the context lookup and assigns to context"
  artifacts:
    - path: "lib/cairnloop/context_provider.ex"
      provides: "The formal ContextProvider behaviour"
    - path: "lib/cairnloop/default_context_provider.ex"
      provides: "The default context provider implementation"
    - path: "test/cairnloop/context_provider_test.exs"
      provides: "Verification of behaviour compilation and types"
    - path: "lib/cairnloop/web/conversation_live.ex"
      provides: "Integration of the context provider into the LiveView"
    - path: "test/cairnloop/web/conversation_live_test.exs"
      provides: "Verification of ConversationLive context provider integration and error handling"
  key_links:
    - from: "lib/cairnloop/default_context_provider.ex"
      to: "lib/cairnloop/context_provider.ex"
      via: "@behaviour Cairnloop.ContextProvider"
      pattern: "@behaviour Cairnloop.ContextProvider"
    - from: "lib/cairnloop/web/conversation_live.ex"
      to: "lib/cairnloop/context_provider.ex"
      via: "Application.get_env"
      pattern: "Application.get_env\\(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider\\)"
---

<objective>
Update the `Cairnloop.ContextProvider` behaviour and implement `Cairnloop.DefaultContextProvider` to support resilient, zero-API-sync context fetching. Then, wire the provider dynamically into `ConversationLive`.

Purpose: Natively bind the support ticket to the Host's billing/identity state by allowing the host to implement a callback. Returning tagged tuples ensures graceful degradation if the host's DB is down. 
Output: An updated behaviour, a default provider, core wiring in LiveView, and test verification.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/M003-ROADMAP.md
@.planning/phases/M003-S01/M003-S01-CONTEXT.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update ContextProvider Behaviour</name>
  <files>lib/cairnloop/context_provider.ex</files>
  <action>Update the `@callback get_context/2` to accept `actor_id :: String.t()` and `opts :: keyword()` and return `{:ok, map()} | {:error, term()}`. Add comprehensive module documentation explaining the map structure (zero-config UI nested maps of simple terms) and the importance of using tagged tuples for resilience without exceptions. Use `lib/cairnloop/automation_policy.ex` as an analog for the behaviour definition pattern.</action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>The callback signature is updated and documented according to the M003-S01 Context decisions.</done>
</task>

<task type="auto">
  <name>Task 2: Implement DefaultContextProvider and Tests</name>
  <files>lib/cairnloop/default_context_provider.ex, test/cairnloop/context_provider_test.exs</files>
  <action>Implement `Cairnloop.DefaultContextProvider` that adopts `@behaviour Cairnloop.ContextProvider` and returns `{:ok, %{}}` for any input. In the test file, write a test case to verify this behavior. Use `lib/cairnloop/default_automation_policy.ex` and `test/cairnloop/automation_policy_test.exs` as analogs for the implementation and testing patterns respectively.</action>
  <verify>
    <automated>mix test test/cairnloop/context_provider_test.exs</automated>
  </verify>
  <done>The default provider is implemented and the test runs successfully, returning `{:ok, %{}}`.</done>
</task>

<task type="auto">
  <name>Task 3: Wire ContextProvider into ConversationLive</name>
  <files>lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs</files>
  <action>Update `ConversationLive` to dynamically invoke the configured context provider using `Application.get_env(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider)`. Map the `{:ok, context}` and `{:error, reason}` returns to assigns (`@context` and `@context_error` respectively) to ensure graceful degradation. Use the existing config dependency injection analog found within `lib/cairnloop/web/conversation_live.ex` as the reference pattern. In the test file, mock the provider to verify that LiveView properly resolves the configured provider and gracefully handles both success (`{:ok, map()}`) and error (`{:error, term()}`) tuples.</action>
  <verify>
    <automated>mix test test/cairnloop/web/conversation_live_test.exs</automated>
  </verify>
  <done>ConversationLive dynamically calls the context provider, safely handles both success and error tuples, and is verified by tests mocking the context provider.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Host -> Cairnloop | The map returned by `get_context` originates from the host app and is rendered in the UI. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M003-S01-01 | Information Disclosure | `ContextProvider` | accept | Cairnloop relies on the host developer to only return safe/authorized context data in the map. |
| T-M003-S01-02 | Denial of Service | `ContextProvider` | mitigate | Tagged tuples force explicit handling of `:error` instead of crashing the LiveView process on lookup failure. |
</threat_model>

<verification>
- The `Cairnloop.ContextProvider` exports a `get_context/2` callback with correct typespecs.
- `Cairnloop.DefaultContextProvider` correctly implements the behaviour.
- `ConversationLive` utilizes `Application.get_env` to load the provider and gracefully handles tagged tuples.
- Tests verify the default provider behavior and ConversationLive integration.
</verification>

<success_criteria>
- Zero API sync foundation is laid via updated behaviour and default implementation.
- `ConversationLive` natively handles context injection without crashing on missing data.
- `mix test` passes with zero warnings.
- Next slices (S02) can depend on `@context` for UI rendering.
</success_criteria>

<output>
After completion, create `.planning/phases/M003-S01/M003-S01-SUMMARY.md`
</output>