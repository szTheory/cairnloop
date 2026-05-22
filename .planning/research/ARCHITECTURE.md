# Architecture Patterns

**Domain:** Support Ticketing SLA Management & Notification Routing
**Researched:** Current Date

## Recommended Architecture

\`\`\`mermaid
graph TD
    A[Ticket Created/Updated] -->|Oban.insert(schedule_in)| B(Oban: CheckSLA Worker)
    B -->|Time Reached| C{Is Ticket Resolved?}
    C -->|Yes| D[NOOP / Job Completed]
    C -->|No| E[Trigger Cairnloop.Notifier]
    E --> F[Chimeway Routing]
    F --> G[Host Adapter: Slack/Discord/Email]
\`\`\`

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `CheckSLA` Worker | Executes after SLA duration, checks ticket state. | Ecto (`Conversation`), `Cairnloop.Notifier` |
| `Cairnloop.Notifier` | Defines the behaviour for dispatching escalations. | `CheckSLA`, Chimeway |
| Chimeway | Abstract delivery and retry of the outbound notification. | `Cairnloop.Notifier`, Host App |
| Host Adapter | The actual API payload delivery (e.g., Slack Webhook). | Chimeway, Third-party APIs |

## Patterns to Follow

### Pattern 1: Idempotent SLA Evaluation
**What:** Instead of trying to cancel Oban jobs when a ticket is resolved (which requires finding the job by args and deleting it), let the job run and evaluate the state.
**When:** Always, for scheduled state checks.
**Example:**
\`\`\`elixir
def perform(%Oban.Job{args: %{"conversation_id" => id, "expected_state" => "unresolved"}}) do
  conversation = Repo.get(Conversation, id)
  
  if conversation.status == :resolved do
    :ok # NOOP: The user was helped before the SLA breached
  else
    Notifier.dispatch_escalation(conversation)
    :ok
  end
end
\`\`\`

### Pattern 2: Behaviour-Driven Extensibility
**What:** Define the contract, not the implementation.
**When:** Integrating external delivery systems.
**Example:**
\`\`\`elixir
defmodule Cairnloop.Notifier do
  @callback dispatch_escalation(Conversation.t(), map()) :: :ok | {:error, term()}
end
\`\`\`

## Anti-Patterns to Avoid

### Anti-Pattern 1: In-Memory Timers
**What:** Using `Process.send_after` or GenServer timeouts for SLAs.
**Why bad:** The countdown is lost instantly if the pod crashes or a new deployment occurs. 
**Instead:** Always persist scheduled checks using Oban `scheduled_at` or `schedule_in`.

### Anti-Pattern 2: Hard Job Cancellation
**What:** Querying the `oban_jobs` table to delete pending SLAs when a ticket is resolved.
**Why bad:** It creates race conditions and tight coupling to Oban's internal schema structure.
**Instead:** Make the job worker verify the ticket state upon execution (Idempotent NOOP).

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Oban Table Bloat | Negligible | Moderate | Partitioning is required. Configure Oban's Pruner plugin aggressively to drop resolved jobs. |
| Notification Spikes | Synchronous delivery is fine | Oban manages concurrency | Push Chimeway delivery to its own dedicated queue with concurrency limits to avoid rate-limiting from Slack/PagerDuty. |

## Sources

- Oban Reliability Guidelines (At-most-once / At-least-once).
- Elixir standard practices for durable messaging.