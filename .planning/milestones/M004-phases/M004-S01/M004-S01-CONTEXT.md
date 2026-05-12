# M004-S01 Context and Decisions

## Phase Scope
**Goal**: Host applications can reliably react to conversation resolution events.
**Requirements**: TLM-01, TLM-02, EXT-01

## Architectural Decisions

### 1. Duration Calculation (TLM-02)
* **Decision**: Add a `resolved_at` (`:utc_datetime_usec`) column to the `cairnloop_conversations` table. Calculate duration at runtime for the telemetry payload.
* **Implementation**: When `resolve_conversation/2` is called, update the database with `status: :resolved` and `resolved_at: DateTime.utc_now()`. The telemetry event `[:cairnloop, :conversation, :resolved]` should emit `%{duration_seconds: DateTime.diff(resolved_at, inserted_at, :second)}` as a measurement. If a conversation is reopened (in future requirements), `resolved_at` will be cleared to `nil`.
* **Rationale**: Querying the database for "conversations resolved this week" is a fundamental operational need. Calculating it dynamically in SQL by hunting for `status == :resolved` and `updated_at` is brittle. The telemetry payload gets an exact snapshot of the duration for this specific cycle.

### 2. Operator Context (TLM-02)
* **Decision**: Standardize the resolution signature to enforce explicit actor provenance.
* **Implementation**: Update to `Cairnloop.Chat.resolve_conversation(id, resolved_by: actor, metadata: %{})`. The `actor` should be a structured map indicating the provenance of the action, e.g., `%{type: :human, id: "operator_123"}` or `%{type: :ai, run_id: "auto_890"}`.
* **Rationale**: The project's vision emphasizes "automation as a ladder of trust" and rigorous auditing. Knowing *who* or *what* resolved a conversation is critical. It prevents the `metadata` map from becoming a dumping ground of unstructured data.

### 3. Host Extensibility (EXT-01)
* **Decision**: Strictly delineate use cases in the documentation. Use `:telemetry` exclusively for observability (metrics, Parapet SLOs), and use `Cairnloop.Notifier` for domain business logic (side-effects).
* **Implementation**: In the documentation (e.g., `README.md` or a new `guides/host_integration.md`), provide two distinct examples:
  1. **Observability**: Example of a `:telemetry.attach/4` handler that ships `duration_seconds` and `actor` data to an APM/Parapet to track "Resolution Time".
  2. **Business Logic**: Example of implementing the `Cairnloop.Notifier` behaviour (`on_conversation_resolved/3`) to trigger a background Oban job (e.g., to sync the resolution state to an external CRM or send a CSAT email).
* **Rationale**: Telemetry handlers run synchronously; heavy business logic creates performance footguns. The `Notifier` behaviour adheres to "Behaviours over a giant DSL," providing a clear, compile-time-checked contract.

### 4. Actor Validation Contract
* **Decision**: `resolve_conversation` must strictly validate the `actor` structure rather than treating it as an opaque map.
* **Implementation**: Pattern match `%{type: _, id: _}` directly in the function arguments or early in the function body.
* **Rationale**: Opaque maps inevitably become a dumping ground. If the library's goal is operator-grade support observability (e.g., tracking automated vs. human resolutions), strictly typed provenance is mandatory.

### 5. Notifier Signature Evolution
* **Decision**: Make `actor` a first-class citizen in the Notifier behaviour.
* **Implementation**: Change `on_conversation_resolved/2` to `on_conversation_resolved(conversation, actor, metadata)`.
* **Rationale**: Elixir behaviours benefit from explicit arguments for load-bearing context. Hiding the actor inside the metadata map obscures the provenance contract.

### 6. Telemetry on Reopen
* **Decision**: Emitting telemetry upon reopen is a required part of Phase 1.
* **Implementation**: When `reply_to_conversation` sets a conversation back to `:open` and clears `resolved_at`, it must emit `[:cairnloop, :conversation, :reopened]`.
* **Rationale**: "Reopen rate" is a critical quality metric for support automation (indicating a failed resolution). Omitting this event leaves a gap in the observability lifecycle.