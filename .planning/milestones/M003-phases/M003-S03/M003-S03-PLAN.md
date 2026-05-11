---
phase: M003-S03
plan: 01
type: execute
wave: 1
depends_on: [M003-S02]
files_modified:
  - lib/cairnloop/tool.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/application.ex
autonomous: true
requirements:
  - M003-S03
must_haves:
  truths:
    - "Tools are defined in dedicated modules using the Cairnloop.Tool behaviour."
    - "Tool inputs are defined via embedded Ecto schemas to enable auto-generated UIs and AI JSON schemas."
    - "Cairnloop maintains strict error boundaries; simple forms are handled natively, and complex UI requires a nested LiveView."
    - "Tools are globally registered but dynamically filtered per-actor."
---

<objective>
Implement Extensibility Components & Actions for the Context Pane so host applications can securely inject interactive tools (like "Refund User") into the Cairnloop dashboard.

Purpose: Deliver the M003-S03 requirement of host-injected actions with zero API sync, strict error boundaries, and future-proof AI compatibility.
Output: A new `Cairnloop.Tool` behaviour, dynamic UI rendering in `ConversationLive` for actions, and test coverage proving strict process isolation.
</objective>

<context>
@.planning/M003-ROADMAP.md
@.planning/phases/M003-S02/M003-S02-SUMMARY.md

### Architectural Decisions (Discuss Phase)
1. **Action Architecture:** Hybrid Tool Registry. Host applications define declarative tools, and Cairnloop renders them. For complex human UI, hosts can provide an optional `LiveView` module, which Cairnloop mounts using `live_render` to guarantee process-level error isolation. LiveComponents are strictly avoided due to shared crash domains.
2. **API Boundary:** Dedicated Tool Modules. Every action is a distinct module (`use Cairnloop.Tool`) registered in config. Cairnloop calls `Host.Tool.can_execute?(actor_id, context)` to dynamically evaluate which tools appear in the UI.
3. **Input Schema:** Embedded Ecto Schemas. Tool modules use standard `embedded_schema` and `changeset/2` to define required arguments. Cairnloop uses `to_form/1` to auto-generate human UI, and will use schema reflection in v0.3 to auto-generate JSON Schemas for AI agents.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Define the `Cairnloop.Tool` behaviour</name>
  <files>lib/cairnloop/tool.ex</files>
  <behavior>
    - Provides a `__using__` macro to inject Ecto schema capabilities.
    - Requires callbacks: `can_execute?/2` (authorization) and `execute/3` (the action).
    - Exposes schema reflection for future LLM integration.
  </behavior>
  <action>Create `lib/cairnloop/tool.ex`. Define the behaviour including `c:can_execute?/2` and `c:execute/3`. Set up a macro that allows developers to define an `embedded_schema` for the tool's inputs, and requires them to provide a `changeset/2` function for casting and validation. Ensure tools return `{:ok, result}` or `{:error, changeset | reason}`.</action>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Global Registration and Dynamic Filtering</name>
  <files>lib/cairnloop/tool_registry.ex</files>
  <behavior>
    - Reads configured tools from `config :cairnloop, tools: [...]`.
    - Exposes a `get_available_tools(actor_id, host_context)` function that filters the global list by calling `can_execute?/2` on each tool.
  </behavior>
  <action>Create a simple registry module that fetches the list of tool modules from the application environment. Implement the dynamic filtering logic so that `ConversationLive` can easily fetch only the tools authorized for the current conversation's `actor_id` and loaded context.</action>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Render Auto-Generated Action UI</name>
  <files>lib/cairnloop/web/conversation_live.ex</files>
  <behavior>
    - Iterates over available tools in the Context Pane.
    - If a tool has no inputs (empty schema), renders a simple button.
    - If a tool has inputs, renders an auto-generated form using `to_form/1` based on the tool's empty changeset.
    - Submitting the form casts the params through the tool's changeset and calls `execute/3`.
  </behavior>
  <action>Update the Context Pane function components in `ConversationLive` to include a new "Actions" section. Map over the available tools. Use the tool's module to generate a fresh struct, pass it through the tool's `changeset/2`, and use `Phoenix.Component.to_form/1` to dynamically render inputs. Add a `handle_event("execute_tool", ...)` that catches the submission, validates the changeset, and invokes the host's logic safely within a `try/rescue` block to preserve the error boundary.</action>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Implement Nested LiveView Escape Hatch</name>
  <files>lib/cairnloop/web/conversation_live.ex</files>
  <behavior>
    - If a tool module specifies a custom LiveView module via an optional callback (e.g., `custom_ui/0`), Cairnloop uses `live_render` instead of auto-generating the form.
  </behavior>
  <action>Add an optional callback to `Cairnloop.Tool` for `custom_ui/0` that returns `{:ok, module()}`. In the rendering loop, if this returns a module, mount it using `<%= live_render(@socket, module, id: "tool-#{tool}", session: %{"actor_id" => ...}) %>`. This ensures complex human interfaces run in isolated processes.</action>
</task>

</tasks>

<threat_model>
## Trust Boundaries
- **Host Tools -> Cairnloop Dashboard:** Host tools are arbitrary code. If they crash during `execute/3`, the dashboard must catch the exception rather than taking down the operator's session.
- **Nested LiveViews -> Cairnloop Dashboard:** Custom LiveViews are isolated by OTP processes; a crash there safely restarts only the widget.

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M003-S03-01 | DoS | `execute/3` callback | mitigate | Wrap the synchronous execution of auto-generated tools in `try/rescue` (or run them in an unlinked Task) so host application exceptions do not crash `ConversationLive`. |
| T-M003-S03-02 | Elevation of Privilege | Tool execution | mitigate | The `can_execute?/2` callback acts as the explicit authorization boundary. It must be called before rendering the UI *and* strictly enforced again inside the `execute_tool` event handler to prevent IDOR attacks. |
</threat_model>

<success_criteria>
- Host developers can define tools via `use Cairnloop.Tool` with embedded Ecto schemas.
- Cairnloop automatically renders forms for these tools in the Context Pane.
- Complex UIs can be built safely using `live_render`.
- Exceptions in host tools do not crash the main operator dashboard.
- The design perfectly paves the way for AI tool-calling in future milestones.
</success_criteria>