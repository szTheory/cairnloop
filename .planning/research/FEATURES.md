# Feature Landscape

**Domain:** Customer Support in B2B SaaS (Customer-Led Growth)
**Researched:** 2024-05

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Frictionless CSAT Capture | Users won't fill out long forms; they expect a 1-click micro-interaction (e.g. 5 stars, or smiley faces). | Low | Must be embedded directly in the Web Widget (`WidgetLive`). |
| Resolution Telemetry Pipeline | Host apps need a predictable way to know when a ticket is closed. | Low | Simple `:telemetry` emission upon Ecto state change. |
| Basic Extensibility Handlers | Developers need documented hooks to wire these signals to their internal APIs. | Low | Provide Elixir snippet templates for App Store/G2 routing. |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| CES (Customer Effort Score) over CSAT | CES is a stronger predictor of B2B SaaS churn than CSAT. Asking "How easy was it to get this solved?" yields more actionable data. | Medium | Requires different phrasing and scale (1-7), plus educating the operator. |
| Contextual Triggers | Only asking for feedback if the ticket was open for > X hours, or if the user's intent was a "Bug". | Medium | Passes rich context into the `:telemetry` payload so handlers can filter aggressively. |
| Detractor Interception (Private Recovery) | Instantly routing a negative CSAT/CES score to a high-priority slack channel for an Account Manager, avoiding public 1-star reviews. | High | Requires a robust handler example that integrates with Chimeway or standard Slack webhooks. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Internal CRM / Drip Campaign Builder | Cairnloop is an embedded support tool, not HubSpot or Intercom Series. Building marketing campaign logic adds immense bloat. | Provide the `[:cairnloop, :conversation, :resolved]` telemetry event and let the host wire it to their actual CRM (e.g., Customer.io). |
| Native App Store Modals | Cairnloop cannot know if the host is a mobile app, web app, or desktop app. | Only emit the signal; the host's frontend must trigger the actual OS-level modal. |

## Feature Dependencies

```
Resolution Telemetry Pipeline → Frictionless CSAT Capture (Cannot accurately attribute CSAT without a resolved state)
Frictionless CSAT Capture → Detractor Interception (Need the score to intercept it)
```

## MVP Recommendation

Prioritize:
1. Resolution Telemetry Pipeline (`[:cairnloop, :conversation, :resolved]`).
2. Frictionless CSAT Capture (1-click smiley/frown in widget).
3. Reference Telemetry Handler (Documentation for the host developer).

Defer: CES scale customization. Keep it simple with Positive/Neutral/Negative CSAT first to ensure adoption.

## Sources

- Customer-Led Growth SaaS Patterns (2024): Transitioning from PLG to NRR focus.
- Elixir Telemetry conventions.