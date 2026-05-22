# Technology Stack

**Project:** Cairnloop (M006)
**Researched:** Current Date

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Oban | ~> 2.17 | Job scheduling & Execution | The premier persistent job queue for Elixir. Provides reliable `schedule_in` semantics and built-in retry mechanisms essential for SLA countdowns. |
| Chimeway | (Internal) | Notification Routing | Provides a durable, template-driven async notification delivery abstraction, keeping third-party API integrations out of Cairnloop. |
| Mailglass | (Internal) | Email Templates | Works alongside Chimeway to handle the email delivery templating if the host prefers email escalations over Slack/Discord. |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Oban Pro | (Optional) | Workflows & Batching | If the host requires complex cancelation of SLA jobs or partitioned pruning. However, Cairnloop will target Oban OSS for the baseline. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Task Scheduling | Oban (`schedule_in`) | `Process.send_after` | In-memory timers are lost on node restart or deploy. Unacceptable for SLAs spanning hours or days. |
| Task Scheduling | Oban (`schedule_in`) | `:timer` / `GenServer` | Same as above. Not durable across pod restarts. |
| Delivery | Chimeway | `Req` to Slack Webhook | Hardcoding webhook URLs limits extensibility and assumes every host wants Slack. We must use adapter patterns. |

## Installation

\`\`\`elixir
# Assumes Oban is already installed from Core Loop, but we will configure specific queues.
# config.exs
config :cairnloop, Oban,
  queues: [sla_escalations: 10, notifications: 20],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7} # Prune old SLA jobs after 7 days
  ]
\`\`\`

## Sources

- Oban OSS Documentation / GitHub recipes (Verified via Context7)
- Cairnloop Backlog & Epic Definitions