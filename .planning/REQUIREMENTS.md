# Requirements: vM004 Customer Voice Activation

## Active Requirements

### Core Telemetry Pipeline
- [ ] **TLM-01**: System emits `[:cairnloop, :conversation, :resolved]` telemetry event upon conversation resolution.
- [ ] **TLM-02**: Event payload includes conversation ID, duration, and operator context.

### Sentiment Capture (CSAT/CES)
- [ ] **SNT-01**: Upon resolution, user is presented with a frictionless CSAT (Customer Satisfaction) rating UI in the widget.
- [ ] **SNT-02**: System emits `[:cairnloop, :feedback, :csat_submitted]` telemetry event when rating is provided.
- [ ] **SNT-03**: CSAT score is durably appended to the Conversation history in the database.

### Host Extensibility
- [ ] **EXT-01**: Documentation and reference handler implementation is provided for listening to the resolution event and triggering host-specific logic.

## Future Requirements (Deferred)
- Aggregated CSAT reporting dashboard.
- Natural language sentiment analysis of the conversation to automatically infer CSAT.

## Out of Scope
- Marketing automation or "drip campaigns" for reviews. Cairnloop emits the spark (telemetry); the host app handles the downstream marketing workflow.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TLM-01 | M004-S01 | Pending |
| TLM-02 | M004-S01 | Pending |
| EXT-01 | M004-S01 | Pending |
| SNT-01 | M004-S02 | Pending |
| SNT-02 | M004-S02 | Pending |
| SNT-03 | M004-S02 | Pending |