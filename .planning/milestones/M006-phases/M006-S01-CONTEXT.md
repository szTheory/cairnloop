# M006-S01 Context: SLA Countdown Engine (Oban)

## Architectural Decision: Multiple SLAs Model Upfront

To build the SLA Countdown Engine, we will implement a dedicated Ecto schema (`cairnloop_conversation_slas`) rather than mutating a single timestamp on the `cairnloop_conversations` table. 

### Why this approach?
1. **Audit & SLOs:** Mutating a single timestamp destroys the historical audit trail needed for Parapet SLIs (Time to First Response vs Time to Resolution metrics). By materializing SLA targets as discrete records, we preserve the full timeline of SLA performance.
2. **Ergonomics (Push-based Oban):** One target = one row = one scheduled Oban job. When an SLA is inserted with `status: :active`, we enqueue an Oban job scheduled for the `target_at` time. When the job runs, it simply checks the Ecto state: if still `:active`, it marks it `:breached` and escalates. If already `:fulfilled` or `:breached`, it safely no-ops.
3. **Future-Proof:** Modern B2B support tools materialize these targets early to avoid painful data migrations when customers demand granular SLA reporting. This sets the right foundation for Phase 3 (LiveView Configuration).

## Proposed Ecto Schema

```elixir
defmodule Cairnloop.Conversations.SLA do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_conversation_slas" do
    belongs_to :conversation, Cairnloop.Conversation
    
    field :target_type, Ecto.Enum, values: [:first_response, :next_response, :resolution]
    field :status, Ecto.Enum, values: [:active, :fulfilled, :breached]
    
    field :target_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec # When it was fulfilled or breached

    timestamps()
  end
end
```

## Lifecycle & Ecto.Multi

State transitions should be bundled into the existing `Ecto.Multi` chains inside `Cairnloop.Chat`:
- **Inbound Message (New Conversation):** Insert SLA (`target_type: :first_response`, `status: :active`, `target_at: +X hours`) -> Enqueue Oban Worker.
- **Operator Reply:** Find the `:active` SLA -> Update SLA (`status: :fulfilled`, `completed_at: now()`) -> Insert new SLA (`target_type: :resolution` or `:next_response`, `status: :active`) -> Enqueue Oban Worker.

## References
- `.planning/M006-ROADMAP.md`
- `prompts/elixir-lib-customer-support-automation-deep-research.md` (Vision for Parapet SLI integration)
