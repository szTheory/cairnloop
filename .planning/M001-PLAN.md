---
phase: M001
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: [
  "mix.exs",
  "lib/cairnloop/workers/process_message.ex",
  "lib/cairnloop/channels/widget_socket.ex",
  "lib/cairnloop/channels/widget_channel.ex",
  "lib/cairnloop/ingress/email_parser.ex",
  "lib/cairnloop/ingress/email_webhook_plug.ex"
]
autonomous: true
requirements: [EPIC-01-INGRESS]
must_haves:
  truths:
    - "System can receive real-time messages via WebSockets from a web widget"
    - "System can parse incoming email threads using Mailglass, separating new replies from quoted history"
    - "Incoming messages from all channels are enqueued and processed reliably in the background via Oban"
  artifacts:
    - path: "lib/cairnloop/workers/process_message.ex"
      provides: "Oban worker for message persistence and broadcasting"
    - path: "lib/cairnloop/channels/widget_channel.ex"
      provides: "Phoenix Channel for widget communication"
    - path: "lib/cairnloop/ingress/email_parser.ex"
      provides: "Email thread parsing"
  key_links:
    - from: "lib/cairnloop/channels/widget_channel.ex"
      to: "Oban"
      via: "enqueueing ProcessMessage job on \"new_msg\""
    - from: "lib/cairnloop/ingress/email_webhook_plug.ex"
      to: "Oban"
      via: "enqueueing ProcessMessage job on email received"
---

<objective>
Implement the Multi-Channel Ingress Engine (Epic 1) to capture support requests from inbound email and a host-embedded Web Widget.

Purpose: Provide reliable, real-time (Web Widget) and async (Email) support ingestion using Elixir-idiomatic tools (Phoenix Channels, Mailglass, Oban).
Output: Working Phoenix channels, an email webhook parser, and Oban background workers.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT_EPICS.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Oban Pipeline Setup</name>
  <files>mix.exs, lib/cairnloop/workers/process_message.ex</files>
  <action>Add `oban` (e.g., `{:oban, "~> 2.17"}`) to `mix.exs` dependencies. Create `Cairnloop.Workers.ProcessMessage` (an `Oban.Worker`). The `perform/1` function should extract the payload (e.g., `%{ "channel" => channel, "content" => content }`) and implement the logic for persisting the new message to the database using the core context. (Note: Since this is a library, Oban configuration is usually done in the host app, but the worker module should be defined here.)</action>
  <verify>
    <automated>mix deps.get && mix compile</automated>
  </verify>
  <done>Oban dependency is added and ProcessMessage worker compiles cleanly.</done>
</task>

<task type="auto">
  <name>Task 2: Web Widget Ingress (Phoenix Channels)</name>
  <files>lib/cairnloop/channels/widget_socket.ex, lib/cairnloop/channels/widget_channel.ex</files>
  <action>Implement the Phoenix Channel for the web widget. Create `Cairnloop.Channels.WidgetSocket` to handle user connection and authentication. Create `Cairnloop.Channels.WidgetChannel` to handle a `"widget:lobby"` or dynamic conversation topic. When the channel receives a `"new_message"` event, instead of blocking the process, it must enqueue a job to Oban via `Cairnloop.Workers.ProcessMessage.new(%{channel: "widget", content: payload["content"]}) |> Oban.insert()`.</action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>WidgetSocket and WidgetChannel are defined and compile successfully.</done>
</task>

<task type="auto">
  <name>Task 3: Email Ingress (Mailglass & Webhook Plug)</name>
  <files>mix.exs, lib/cairnloop/ingress/email_parser.ex, lib/cairnloop/ingress/email_webhook_plug.ex</files>
  <action>Add `mailglass` (e.g., `{:mailglass, "~> 0.2"}`) to `mix.exs` dependencies. Create `Cairnloop.Ingress.EmailParser` that wraps Mailglass to strictly isolate new reply text from quoted history (preventing thread bloat). Create a Plug `Cairnloop.Ingress.EmailWebhookPlug` that handles incoming POST webhook requests from email providers (like Sendgrid or Postmark), processes the body with `EmailParser`, and enqueues the extracted text to Oban using `Cairnloop.Workers.ProcessMessage`.</action>
  <verify>
    <automated>mix deps.get && mix compile</automated>
  </verify>
  <done>Mailglass dependency is added, the parser and plug are defined, and the code compiles without warnings.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Web Widget → Channel | Untrusted client sending WebSocket payloads |
| Email Provider → Webhook | Untrusted internet POSTs delivering inbound emails |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M001-01 | Spoofing | WidgetSocket | mitigate | Validate user auth tokens or signatures during socket connection (`connect/3`). |
| T-M001-02 | Spoofing | EmailWebhookPlug | mitigate | Require webhook signature verification or secret token to ensure the POST is from the authorized email provider. |
| T-M001-03 | Denial of Service | Channels/Oban | mitigate | Enqueueing to Oban prevents channel blocking. Channel payload sizes should be capped. |
</threat_model>

<verification>
Run `mix compile --warnings-as-errors` to ensure all new modules and dependencies compile correctly.
</verification>

<success_criteria>
- Oban worker `ProcessMessage` exists and is ready for host usage.
- Phoenix Channels (`WidgetSocket`, `WidgetChannel`) are implemented for real-time web ingress.
- `EmailParser` and `EmailWebhookPlug` are implemented for email parsing and ingress.
- Message processing for all channels is unified through Oban.
- The project compiles successfully.
</success_criteria>

<output>
After completion, create `.planning/phases/M001-PLAN-SUMMARY.md`
</output>
