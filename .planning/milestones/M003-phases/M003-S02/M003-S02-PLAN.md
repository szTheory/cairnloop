---
phase: M003-S02
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/web/conversation_live.ex
  - test/cairnloop/web/conversation_live_test.exs
autonomous: true
requirements:
  - M003-S02
  - S02
must_haves:
  truths:
    - "Operators always see one evidence rail with Customer Context first and AI Draft / Audit second."
    - "Host context renders as deterministic grouped rows instead of raw inspected terms."
    - "Empty or failed host context keeps the rail visible with clear fallback copy."
    - "Reply, draft, and PubSub reload paths refresh both conversation data and host context."
    - "Draft review actions remain usable from the rail, including inline discard confirmation."
  artifacts:
    - path: "lib/cairnloop/web/conversation_live.ex"
      provides: "Shared reload/context helpers, normalized render nodes, and evidence-rail function components"
    - path: "test/cairnloop/web/conversation_live_test.exs"
      provides: "Normalization, render-state, inline audit-action, and reload-path coverage"
  key_links:
    - from: "lib/cairnloop/web/conversation_live.ex"
      to: "Cairnloop.ContextProvider.get_context/2"
      via: "load_host_context/1"
      pattern: "get_context\\(conversation\\.host_user_id, \\[\\]\\)"
    - from: "lib/cairnloop/web/conversation_live.ex"
      to: "Cairnloop.Chat.get_conversation!/1"
      via: "reload_conversation_with_context/2"
      pattern: "Chat\\.get_conversation!"
    - from: "lib/cairnloop/web/conversation_live.ex"
      to: "test/cairnloop/web/conversation_live_test.exs"
      via: "normalized section/component render assertions"
      pattern: "Customer Context|AI Draft / Audit|Unsupported value"
---

<objective>
Implement the S02 evidence rail inside `ConversationLive` so host context and draft review share one stable operator surface with deterministic rendering and live refresh behavior.

Purpose: Deliver the dynamic context-pane UI promised by M003 without introducing child LiveViews, extension slots, or mount-only context state.
Output: Updated `ConversationLive` helpers/components plus test coverage for normalization, shell states, draft-audit rendering, and shared reload paths.
</objective>

<execution_context>
@/Users/jon/.codex/get-shit-done/workflows/execute-plan.md
@/Users/jon/.codex/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/M003-ROADMAP.md
@.planning/phases/M003-S02-CONTEXT.md
@.planning/phases/M003-S02/M003-S02-RESEARCH.md
@.planning/phases/M003-S02/M003-S02-PATTERNS.md
@.planning/phases/M003-S02/M003-S02-VALIDATION.md
@.planning/phases/M003-S02/M003-S02-UI-SPEC.md
@.planning/phases/M003-S01/M003-S01-SUMMARY.md
@lib/cairnloop/web/conversation_live.ex
@test/cairnloop/web/conversation_live_test.exs

<interfaces>
From `lib/cairnloop/context_provider.ex`:
```elixir
@callback get_context(actor_id :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
```

From `lib/cairnloop/chat.ex`:
```elixir
def get_conversation!(id)
def reply_to_conversation(conversation_id, content, role \\ :agent)
```

Current `ConversationLive` seams to preserve:
```elixir
def mount(%{"id" => id}, _session, socket)
def handle_info({:draft_created, _draft_id}, socket)
def handle_event("reply", %{"content" => content}, socket)
def handle_event("approve_draft", %{"draft-id" => draft_id}, socket)
def handle_event("edit_draft", %{"draft-id" => draft_id}, socket)
def handle_event("discard_draft", %{"draft-id" => draft_id}, socket)
```
</interfaces>
</context>

<source_audit>
- GOAL `M003-S02`: Covered by Tasks 2 and 3 via the always-visible evidence rail, extracted function components, and merged Customer Context + AI Draft / Audit surface.
- REQ `M003-S02`: Covered by Tasks 2 and 3 with locked card order, narrow/desktop shell behavior in markup, and preserved draft actions inside the same rail.
- REQ `S02`: Covered by Tasks 1 and 3 with deterministic normalization, safe fallback rendering, shared reload behavior, and provider-error handling.
- RESEARCH: Covered by Task 1 (`normalize_context_sections/1` tree and unsupported fallback), Task 2 (`context_pane/1`, `context_section/1`, `context_field/1`, `draft_audit_card/1`), and Task 3 (`reload_conversation_with_context/2` across all reload branches).
- CONTEXT decisions D-rail / D-components / D-normalize / D-visible-shell / D-tone: Covered exactly by Tasks 2 and 3; deferred S03 extension slots, tabs, free-form builders, and child LiveViews are excluded from all tasks.
</source_audit>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add deterministic normalization and rail-state test coverage</name>
  <files>test/cairnloop/web/conversation_live_test.exs</files>
  <read_first>.planning/phases/M003-S02-CONTEXT.md, .planning/phases/M003-S02/M003-S02-RESEARCH.md, .planning/phases/M003-S02/M003-S02-VALIDATION.md, .planning/phases/M003-S02/M003-S02-UI-SPEC.md, lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs</read_first>
  <behavior>
    - Nested host maps render in a deterministic top-level and child-key order per the S02 normalization decision.
    - Lists of simple values render intentionally, while unsupported terms render the exact fallback copy `Unsupported value`.
    - Empty context and provider errors keep the `Customer Context` shell visible with the locked empty/error copy from the UI spec.
  </behavior>
  <action>Extend `ConversationLiveTest` first with fixtures and assertions that lock the S02 render contract before implementation changes land. Add a nested success provider returning top-level groups such as `Billing`, `Identity`, and child keys that prove sorting and label humanization; add a provider that returns unsupported terms so the render path must emit `Unsupported value` instead of `inspect/1`; add render tests asserting the exact empty heading `No customer context yet`, the empty body `This conversation has no host context to show. Continue with the thread, or reload after host data becomes available.`, and the error copy `Customer context is unavailable right now. Continue handling the conversation, then reload to try again.`. Keep the tests in the existing direct render/callback style; do not add `ConnCase`, mounted LiveView scaffolding, extension-slot tests, or S03 child-view coverage.</action>
  <acceptance_criteria>`test/cairnloop/web/conversation_live_test.exs` contains tests that grep for `Unsupported value`, `No customer context yet`, `Customer context is unavailable right now.`, and assertions that compare ordered section output rather than raw `inspect/1` dumps.</acceptance_criteria>
  <verify>
    <automated>mix test test/cairnloop/web/conversation_live_test.exs</automated>
  </verify>
  <done>The test file expresses the locked normalization, empty/error shell, and operator-copy contract for S02 and passes after the implementation tasks complete.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Extract the evidence-rail function components and inline draft audit state</name>
  <files>lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs</files>
  <read_first>.planning/phases/M003-S02-CONTEXT.md, .planning/phases/M003-S02/M003-S02-PATTERNS.md, .planning/phases/M003-S02/M003-S02-UI-SPEC.md, lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs</read_first>
  <behavior>
    - `ConversationLive` remains the owner LiveView, while the rail is rendered through function components inside the same module.
    - The rail shell stays visible in success, empty, and error states with `Customer Context` first and `AI Draft / Audit` second.
    - Draft review actions remain in the rail and discard becomes a two-step inline confirmation rather than an immediate destructive click.
  </behavior>
  <action>Refactor `ConversationLive.render/1` to a two-column shell that keeps the message timeline as the left reading surface and renders one evidence rail through clearly named function components per D-components: `context_pane/1`, `context_section/1`, `context_field/1`, and `draft_audit_card/1` (or an equivalent set with these responsibilities and names preserved in comments/tests if Phoenix naming constraints require minor variation). Encode the locked UI-spec layout contract directly in the LiveView markup/classes: desktop uses a fixed-width `352px` evidence rail with a `32px` gap from the timeline, narrow screens stack the rail directly below the message timeline and above the reply composer, rail card order remains `Customer Context` then `AI Draft / Audit`, each rail card uses `24px` internal padding with `24px` card-to-card spacing, and field rows keep `16px` separation. Add normalized render-node helpers such as `normalize_context_sections/1`, `normalize_context_value/1`, and `humanize_context_label/1` so top-level groups become sections, nested maps become inset subsections, simple lists become deliberate lines/chips, and unsupported values become the exact muted fallback `Unsupported value` per D-normalize. Keep host keys string-based and sorted at every map level. Move draft rendering into `draft_audit_card/1`, preserve `Approve & Send` behavior, rename the edit action label to `Apply to Composer`, and add inline discard confirmation using a `pending_discard_draft_id` assign plus locked confirmation copy `Discard draft: Remove this draft from the rail? This action is recorded and cannot be undone.`. Do not introduce a child LiveView, `Phoenix.LiveComponent`, tabs, slots, or a generic field-builder API.</action>
  <acceptance_criteria>`lib/cairnloop/web/conversation_live.ex` defines `context_pane`, `context_section`, `context_field`, and `draft_audit_card`; the rendered HTML contains `Customer Context` before `AI Draft / Audit`; the implementation encodes the locked `352px` rail width, `32px` desktop column gap, narrow-screen stack-below-timeline behavior, `24px` card padding/card gap, and `16px` field-row spacing from the UI spec; the file contains `pending_discard_draft_id` and the exact confirmation copy; raw success-state `inspect(` output is removed from context rendering.</acceptance_criteria>
  <verify>
    <automated>mix test test/cairnloop/web/conversation_live_test.exs</automated>
  </verify>
  <done>The LiveView renders a single evidence rail with extracted function components, deterministic context sections, preserved draft controls, and inline discard confirmation that matches the UI spec copy.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Route every conversation reload through shared conversation-plus-context helpers</name>
  <files>lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs</files>
  <read_first>.planning/phases/M003-S02-CONTEXT.md, .planning/phases/M003-S02/M003-S02-RESEARCH.md, .planning/phases/M003-S02/M003-S02-VALIDATION.md, lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs</read_first>
  <behavior>
    - Mount, PubSub reload, reply, approve, apply-to-composer, and confirmed discard all refresh `conversation`, `host_context`, and `context_error` together.
    - Provider failures degrade into rail error state without breaking message or draft workflows.
    - Draft edit still loads the selected draft content into the composer while reloading context from the freshly fetched conversation.
  </behavior>
  <action>Introduce a private shared reload seam inside `ConversationLive`, named `reload_conversation_with_context/2` plus a smaller `load_host_context/1` helper, and route all existing reload points through it per S02: `mount/3`, `handle_info({:draft_created, ...})`, `handle_event("reply", ...)`, `handle_event("approve_draft", ...)`, `handle_event("edit_draft", ...)`, and the confirmed discard branch. The helper must fetch the conversation through `Chat.get_conversation!/1`, call the configured context provider with `get_context(conversation.host_user_id, [])`, map `{:ok, map}` to normalized context state, map `{:error, reason}` to `%{}` plus `context_error`, and leave the rest of the LiveView usable. Add callback tests proving host context changes after reloads, proving error tuples become the rail error state, and proving `edit_draft` still seeds the composer with the selected draft content after the shared reload. Keep `discard_draft` as the entry into inline confirmation and perform the destructive call only from the explicit confirm event; do not add new child processes or S03 extension hooks.</action>
  <acceptance_criteria>`lib/cairnloop/web/conversation_live.ex` contains a shared helper such as `reload_conversation_with_context`; `mount`, `handle_info`, `reply`, `approve_draft`, `edit_draft`, and the confirmed discard path call that helper instead of open-coded `Chat.get_conversation!` reloads; `test/cairnloop/web/conversation_live_test.exs` includes callback tests for `:draft_created`, `reply`, `approve_draft`, `edit_draft`, and discard confirmation context refresh behavior.</acceptance_criteria>
  <verify>
    <automated>mix test test/cairnloop/web/conversation_live_test.exs && mix test</automated>
  </verify>
  <done>All conversation reload paths update host context and error state in lockstep with the conversation, and the full test suite remains green.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Host context provider -> LiveView rail | Untrusted host-owned nested maps and terms cross into HEEx rendering. |
| Operator draft actions -> automation backend | Destructive and state-changing actions originate from UI events inside the evidence rail. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M003-S02-01 | Information Disclosure / DoS | `context_field/1` and normalization helpers | mitigate | Normalize provider values before render, recurse only through supported maps/lists/scalars, and render exact fallback `Unsupported value` for unsupported terms instead of raw `inspect/1` output. |
| T-M003-S02-02 | Tampering / Integrity Drift | reload callbacks in `ConversationLive` | mitigate | Route mount, PubSub, reply, approve, apply-to-composer, and confirmed discard through `reload_conversation_with_context/2` so host context cannot drift behind conversation state. |
| T-M003-S02-03 | Repudiation / Accidental destructive action | rail discard controls | mitigate | Replace one-click discard with inline confirmation state and explicit confirm/cancel events in `draft_audit_card/1`, while preserving backend audit behavior. |
</threat_model>

<verification>
- `mix test test/cairnloop/web/conversation_live_test.exs` proves deterministic ordering, safe fallback rendering, shell persistence, inline discard confirmation, and shared reload behavior.
- `mix test` stays green after the LiveView refactor.
- Grep checks show extracted component/helper names and the locked UI copy in `lib/cairnloop/web/conversation_live.ex`.
- Manual responsive-layout check: run the app, open a conversation on a desktop-width viewport, and verify the message timeline stays left while a single right evidence rail renders at `352px` width with a `32px` gap and `Customer Context` above `AI Draft / Audit`.
- Manual narrow-screen check: reduce the viewport below `1024px` and verify the evidence rail stacks directly below the message timeline and above the reply composer, preserving the same card order and always-visible shell.
- Manual visual-contract check: compare the rendered rail against `.planning/phases/M003-S02/M003-S02-UI-SPEC.md` and confirm `24px` card padding, `24px` card-to-card spacing, `16px` field-row spacing, locked card titles/copy, and operator-style evidence-rail presentation.
</verification>

<success_criteria>
- `ConversationLive` renders one stable evidence rail with `Customer Context` above `AI Draft / Audit` on every state.
- Host context output is deterministic, readable, and safe for unsupported values.
- Empty/error context never collapses the rail or breaks messaging/draft workflows.
- All conversation reload branches refresh context and tests cover those paths.
</success_criteria>

<output>
After completion, create `.planning/phases/M003-S02/M003-S02-SUMMARY.md`
</output>
