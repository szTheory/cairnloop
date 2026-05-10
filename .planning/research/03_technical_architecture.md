# Technical Architecture: Cairnloop

## Ecto-Native Persistence
All state is durable, append-only, and managed via Ecto.
* **Append-Only Messages**: Conversation histories are immutable. Redactions are handled via explicit fields (`redacted_at`, `superseded_by`).
* **Ecto.Multi**: All complex state transitions are wrapped in transactions.

## Igniter Integration
* `mix cairnloop.install` generates Ecto migrations, Context modules, and mounts the LiveView dashboard macro in the host's router.

## Behaviours over DSLs
Use explicit Elixir behaviours for extensibility (e.g., `ChannelAdapter` for custom ingress, `AutomationPolicy` for human-in-the-loop rules).

## Telemetry and OpenInference
* Emits standard `:telemetry` events for all major lifecycle actions.
* Strict adherence to OpenInference semantic conventions for AI tracing.