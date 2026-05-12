# ROADMAP: M004 Customer Voice Activation

## Phases

- [ ] **Phase 1: Foundation (Telemetry & Events)** - Establish the `[:cairnloop, :conversation, :resolved]` pipeline.
- [ ] **Phase 2: Sentiment Capture (CSAT UI)** - Introduce frictionless in-widget CSAT capture upon resolution.
- [ ] **Phase 3: Host Extensibility** - Provide reference handlers and documentation for external growth actions.

## Phase Details

### Phase 1: Foundation (Telemetry & Events)
**Goal**: The system natively emits rich observability signals when support issues are resolved.
**Depends on**: Nothing
**Requirements**: M004-REQ-01, M004-REQ-02
**Success Criteria** (what must be TRUE):
  1. Developers can observe a `[:cairnloop, :conversation, :resolved]` telemetry event firing whenever a conversation is marked as resolved.
  2. The event payload reliably contains the conversation ID and metadata (like duration).
**Plans**: TBD

### Phase 2: Sentiment Capture (CSAT UI)
**Goal**: End-users can provide immediate sentiment feedback within the widget upon resolution.
**Depends on**: Phase 1
**Requirements**: M004-REQ-03, M004-REQ-04
**Success Criteria** (what must be TRUE):
  1. A user sees a frictionless rating UI (CSAT) appear in the chat widget immediately after their conversation is resolved.
  2. The user can submit a rating without leaving the page or changing context.
  3. The system captures the rating and emits a corresponding `[:cairnloop, :feedback, :csat_submitted]` telemetry event.
**Plans**: TBD
**UI hint**: yes

### Phase 3: Host Extensibility
**Goal**: Host developers can easily consume support signals to trigger growth actions without negatively impacting performance.
**Depends on**: Phase 1
**Requirements**: M004-REQ-05, M004-REQ-06
**Success Criteria** (what must be TRUE):
  1. Developers can read documentation on how to connect external actions (e.g., App Store prompts) to the resolution event.
  2. Developers can deploy a reference Oban worker that processes the telemetry signal asynchronously, ensuring the main request loop is never blocked.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation (Telemetry & Events) | 0/0 | Not started | - |
| 2. Sentiment Capture (CSAT UI) | 1/1 | Planned | - |
| 3. Host Extensibility | 0/0 | Not started | - |