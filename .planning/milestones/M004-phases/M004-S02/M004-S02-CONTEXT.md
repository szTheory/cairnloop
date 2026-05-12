# M004-S02: Customer Satisfaction (CSAT) Capture Context

## Goal
Users can seamlessly provide feedback upon conversation resolution, which is durably stored and emitted as telemetry.

## Architectural Decisions

Following a deep research spike and alignment discussion, the following architectural choices have been made for the implementation of CSAT Capture:

### 1. Delivery Mechanism (System Message)
We will **NOT** use an ephemeral channel event to trigger the CSAT UI. Instead, we will leverage **System Messages**.
* When a conversation is resolved, the backend will atomically insert a `Message` with `role: :system` and `metadata: %{"type" => "csat_request"}`.
* This guarantees durability: if a user reconnects hours later, the CSAT prompt is still waiting for them at the bottom of the timeline.
* It enables omnichannel support (e.g., rendering the prompt in an email thread).
* The client widget will intercept this specific system message type and render an interactive CSAT component instead of a text bubble.

### 2. Rating Scale
The CSAT rating will use a **Thumbs up/down** binary scale.

### 3. Data Model Updates
* **Messages:** Add a `metadata` (JSONB/map) column to `cairnloop_messages` to support arbitrary structured data on system events (like `type: "csat_request"`).
* **Conversations:** Add a `csat_rating` (string/enum) column to `cairnloop_conversations` allowing values like `:positive` or `:negative`. This fulfills the requirement to "durably store the rating on the conversation record."

### 4. Submission
When the user selects a rating in the widget UI:
1. The widget will push a `"submit_csat"` event to the `WidgetChannel` with the selected score.
2. The backend will update the `csat_rating` on the `Conversation` record.
3. The backend will execute the `[:cairnloop, :feedback, :csat_submitted]` telemetry event.

## Success Criteria Mapping
1. **User sees a frictionless CSAT rating prompt:** Supported via the durable System Message delivered through the standard message sync/channel broadcast.
2. **Durably stored on conversation record:** Supported via the new `csat_rating` column on the `Conversation` table.
3. **Emits telemetry:** The `"submit_csat"` channel handler will explicitly emit `[:cairnloop, :feedback, :csat_submitted]`.
