# Architecture Patterns

**Domain:** Customer Support in B2B SaaS (Customer-Led Growth)
**Researched:** 2024-05

## Recommended Architecture

The core of this architecture relies on a highly decoupled event bus using Erlang/Elixir's `:telemetry`. Cairnloop is responsible for internal state management (closing a ticket, capturing a UI click for sentiment) and broadcasting the change. The Host Application is strictly responsible for reacting to that change (routing to external APIs, triggering CRM flows).

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `Cairnloop.Conversation` Context | Manages the Ecto state of tickets (open, resolved) and records sentiment. Emits `:telemetry` events. | Database (Ecto), `:telemetry` |
| `WidgetLive` (Phoenix LiveView) | Renders the 1-click CSAT UI to the end user after ticket resolution. | `Cairnloop.Conversation` (Context) |
| Host Telemetry Handler | Attaches to `[:cairnloop, :conversation, :resolved]`. Filters and routes signals to external growth tools. | Cairnloop Telemetry, External APIs (e.g., Slack, App Store APIs) |

### Data Flow

1. Operator clicks "Resolve" in the `ConversationLive` dashboard.
2. `Cairnloop.Conversation.resolve(conversation_id)` updates the Ecto record.
3. The end-user's `WidgetLive` receives a PubSub broadcast and updates the UI to show a "Rate your experience" micro-interaction (CSAT: Positive, Neutral, Negative).
4. The user clicks "Positive".
5. `WidgetLive` calls `Cairnloop.Conversation.record_sentiment(conversation_id, :positive)`.
6. This context function executes `:telemetry.execute([:cairnloop, :conversation, :resolved], %{duration: 3600}, %{sentiment: :positive, user_id: 123})`.
7. The Host's attached handler intercepts the event, sees `:positive`, and schedules an Oban job to email the user an App Store review link.

## Patterns to Follow

### Pattern 1: Telemetry-Driven Extensibility
**What:** Exposing business lifecycle hooks via `:telemetry` rather than custom Webhooks or GenServer callbacks.
**When:** Whenever Cairnloop crosses a significant boundary (ticket created, resolved, escalated) that a host might care about.
**Example:**
```elixir
# In Cairnloop's internal context
def record_sentiment(conversation, sentiment) do
  conversation
  |> Ecto.Changeset.change(%{sentiment: sentiment})
  |> Repo.update()
  |> case do
    {:ok, updated} ->
      :telemetry.execute(
        [:cairnloop, :conversation, :resolved],
        %{duration_minutes: calculate_duration(updated)},
        %{conversation_id: updated.id, sentiment: sentiment, user_id: updated.user_id}
      )
      {:ok, updated}
    error -> error
  end
end
```

### Pattern 2: Asynchronous Handler Execution
**What:** Host handlers must immediately delegate work to background jobs (`Oban`) rather than executing synchronous API calls in the telemetry handler process.
**When:** The host receives a `[:cairnloop, :conversation, :resolved]` event.
**Example:**
```elixir
# In the Host Application's telemetry setup
def handle_event([:cairnloop, :conversation, :resolved], measurements, metadata, _config) do
  if metadata.sentiment == :positive do
    HostApp.Workers.SendReviewPrompt.new(%{user_id: metadata.user_id})
    |> Oban.insert()
  end
end
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Synchronous API calls in Telemetry Handlers
**What:** Performing `Req.post("https://api.hubspot.com/...")` directly inside `handle_event/4`.
**Why bad:** Telemetry handlers execute synchronously in the process that emitted the event. Blocking this process means the web request (and the UI) hangs for the user who just clicked the CSAT button.
**Instead:** Insert an `Oban` job and return immediately.

### Anti-Pattern 2: Hardcoding Integration Logic into Cairnloop
**What:** Adding `Cairnloop.Integrations.Slack` or `Cairnloop.Integrations.AppStore`.
**Why bad:** Violates the "Embedded Support Layer" philosophy. Cairnloop becomes a bloated CRM, requiring constant maintenance of 3rd-party APIs.
**Instead:** Emit the telemetry event and provide documentation.

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Telemetry Handler Overhead | Synchronous execution is fine for fast local logic. | Synchronous API calls will start blocking DB transactions. | Must strictly enforce Oban job delegation. Telemetry events process extremely fast if they only insert a row into Postgres (Oban). |
| Ecto Storage | Simple boolean/enum on `Conversation` table. | Same. | Might need a separate `conversation_metrics` table to avoid locking the main conversation row during high-velocity updates. |

## Sources

- https://hexdocs.pm/telemetry/
- B2B SaaS architecture best practices for decoupled event sourcing.