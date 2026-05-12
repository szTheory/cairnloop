# Phase 1: Foundation (Telemetry & Events)

**Goal**: The system natively emits rich observability signals when support issues are resolved.

## Requirements
- **M004-REQ-01**: System emits `[:cairnloop, :conversation, :resolved]` telemetry event upon conversation resolution.
- **M004-REQ-02**: Event payload includes conversation ID, duration, and any available metadata.

## Success Criteria
1. Developers can observe a `[:cairnloop, :conversation, :resolved]` telemetry event firing whenever a conversation is marked as resolved.
2. The event payload reliably contains the conversation ID and metadata (like duration).
