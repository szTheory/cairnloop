# Technology Stack

**Project:** Cairnloop (M004: Customer Voice Activation)
**Researched:** 2024-05

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Elixir `telemetry` | ~> 1.0 | Event dispatching for resolution and CSAT events | Idiomatic Elixir approach for decoupled event logging and observability. Doesn't force the host to use a specific pub/sub system. |
| Phoenix LiveView | ~> 0.20 | Frictionless in-app UI for capturing CES/CSAT | Allows "One-Click" feedback without page reloads, essential for high conversion rates. |
| Ecto | ~> 3.10 | Persisting sentiment scores | We need to append the final sentiment to the `Conversation` or a related `Sentiment` schema to track over time. |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `telemetry_metrics` | ~> 1.0 | Aggregating CSAT/CES scores over time | Used by the host if they want to build dashboards of support sentiment directly in Phoenix/LiveDashboard. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Event Bus | `:telemetry` | Phoenix.PubSub | `PubSub` is great for real-time node-to-node messaging, but `:telemetry` is specifically designed for instrumentation, metrics, and hooking into library-level events decoupled from process distribution. |
| Feedback Delivery | In-App (LiveView) | Email Surveys (Mailglass) | Email surveys suffer from terrible open and response rates and break the context of the user's immediate workflow. In-app is strongly preferred. |

## Implementation

```elixir
# Core dispatch in Cairnloop.Conversation
:telemetry.execute(
  [:cairnloop, :conversation, :resolved],
  %{duration_seconds: duration, csat_score: score},
  %{conversation_id: id, user_id: user_id}
)
```

## Sources

- Elixir Telemetry Official Docs: https://hexdocs.pm/telemetry/
- Modern SaaS CLG Practices: High emphasis on in-app contextual feedback over asynchronous channels.