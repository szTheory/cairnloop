# Requirements: vM004 Customer Voice Activation

## Active Requirements

### Core Telemetry Pipeline
- [x] **M004-REQ-01**: System emits `[:cairnloop, :conversation, :resolved]` telemetry event upon conversation resolution.
- [x] **M004-REQ-02**: Event payload includes conversation ID, duration, and any available metadata.

### Sentiment Capture (CSAT UI)
- [ ] **M004-REQ-03**: Upon resolution, user is presented with a frictionless CSAT (Customer Satisfaction) rating UI directly in the LiveView widget.
- [ ] **M004-REQ-04**: System durably stores the rating and emits `[:cairnloop, :feedback, :csat_submitted]` telemetry event when rating is provided.

### Host Extensibility
- [x] **M004-REQ-05**: Documentation exists demonstrating how a host application can listen to the resolution telemetry event to trigger external actions.
- [ ] **M004-REQ-06**: Reference implementation (e.g., an Oban worker) is provided for handling these signals asynchronously without blocking the synchronous telemetry handler.

## Out of Scope
- Marketing automation or generic marketing CRMs.
- Generic email surveys for CSAT.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| M004-REQ-01 | Phase 1 | Completed |
| M004-REQ-02 | Phase 1 | Completed |
| M004-REQ-03 | Phase 2 | Pending |
| M004-REQ-04 | Phase 2 | Pending |
| M004-REQ-05 | Phase 3 | Completed |
| M004-REQ-06 | Phase 3 | Pending |