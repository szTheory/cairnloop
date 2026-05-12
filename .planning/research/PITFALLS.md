# Domain Pitfalls

**Domain:** Customer Support in B2B SaaS (Customer-Led Growth)
**Researched:** 2024-05

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Synchronous Telemetry Handlers
**What goes wrong:** The host app developer writes a telemetry handler that makes an HTTP request to an external CRM (e.g., Salesforce or HubSpot) directly within the handler function.
**Why it happens:** Telemetry handles are often introduced as "event hooks," and developers assume they run asynchronously like typical PubSub or message queue consumers. Elixir's `:telemetry` handlers, however, run synchronously in the process that called `:telemetry.execute/3`.
**Consequences:** If the external CRM API is slow or down, the process handling the user's web request hangs. The user experiences a frozen UI when clicking the "Rate your experience" button.
**Prevention:** Always emphasize in documentation that telemetry handlers must be pure or offload side-effects to an async worker (like `Oban`). Provide clear reference implementations utilizing `Oban.insert/1`.
**Detection:** Spikes in request duration metrics for the resolve endpoint/LiveView event; timeout exceptions originating from the telemetry handler.

## Moderate Pitfalls

### Pitfall 1: Survey Fatigue and Generic Delivery
**What goes wrong:** Sending an automated email survey 24 hours after a ticket closes.
**Prevention:** Avoid email entirely if possible. B2B users receive too much email and will ignore generic surveys. In-app, contextual prompts (within the LiveView widget immediately upon resolution) convert significantly higher because the context is fresh and the action requires one click.

### Pitfall 2: Optimizing for CSAT over CES
**What goes wrong:** Focusing solely on "Customer Satisfaction" (CSAT). A user can be "satisfied" with a support interaction (the agent was nice), but the issue might have taken 4 hours of their time to resolve.
**Prevention:** Educate the host app on the difference. While CSAT is good, Customer Effort Score (CES) — "How easy was it to get this resolved?" — is a much stronger predictor of churn. Consider capturing both or defaulting to CES in advanced implementations.

## Minor Pitfalls

### Pitfall 1: Leaking PII into Telemetry Metrics
**What goes wrong:** Passing the raw `Message` body or user's email directly into the telemetry `measurements` or `metadata`.
**Prevention:** Pass strictly the necessary identifiers (e.g., `user_id`, `conversation_id`, `sentiment`) into the telemetry event. The host app can use those IDs to look up the necessary data on their end.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Foundation (Telemetry) | Host developers don't know how to test telemetry hooks. | Provide a built-in ExUnit helper or reference code for asserting telemetry events. |
| Sentiment UI | The UI feels disjointed from the rest of the conversation timeline. | Ensure the CSAT/CES prompt renders as a native message bubble inside the existing `WidgetLive` timeline. |

## Sources

- Experience from scaling Elixir telemetry in production.
- SaaS customer success guidelines on survey fatigue.