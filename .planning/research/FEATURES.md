# Feature Landscape

**Domain:** Support Ticketing SLA Management & Notification Routing
**Researched:** Current Date

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| First Response SLA | Operators need to ensure no user is ignored for > X hours. | Medium | Scheduled on initial ingress. |
| Resolution Time SLA | SLA for total time to resolve the issue. | Medium | Scheduled upon creation, requires cancelling or NOOP-ing if resolved early. |
| VIP Routing | High-value customers need different thresholds. | Low | Check user tags/context when setting `schedule_in`. |
| Internal Delivery | Alerts must go to Slack/Email, not just in-app. | Low | Handled by Chimeway. |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Zero-Config Adapters | Host developers just define a Chimeway adapter; Cairnloop handles the rest. | Medium | Vastly superior DX compared to managing API clients. |
| Dashboard Thresholds | Support managers can tweak SLA times without a developer deploying code. | Low | Simple LiveView forms updating settings in Ecto. |
| At-Risk Indicators | Visual warnings in `ConversationLive` when an SLA is < 15 mins from breaching. | Medium | Requires comparing current time to the pending Oban job. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Zendesk-style Trigger Builder | Turing-complete UI rule engines are massive engineering sinks, prone to infinite loops, and confusing to operators. | Provide fixed, opinionated SLA types (First Response, Next Reply, Resolution) that are strictly defined and easy to toggle. |
| Direct Slack Integrations | Hardcoding Slack API limits the product to one ecosystem. | Use the `Cairnloop.Notifier` behaviour backed by Chimeway so the host can route to Discord, Teams, or PagerDuty. |

## Feature Dependencies

\`\`\`text
Oban Countdown Engine → Chimeway Notifier Behaviour → LiveView Configuration UI
\`\`\`

## MVP Recommendation

Prioritize:
1. First Response SLA Countdown (`schedule_in`).
2. Idempotent NOOP execution (if ticket already replied to, do nothing).
3. Delivery via `Cairnloop.Notifier` to a generic host adapter.

Defer: 
Complex SLA pause logic (e.g., pausing SLAs during weekends/holidays). Keep it strictly wall-clock time for the MVP, and evaluate business hours logic later.

## Sources

- Cairnloop Epic 6 specifications.
- Zendesk trigger complexity (lessons learned).