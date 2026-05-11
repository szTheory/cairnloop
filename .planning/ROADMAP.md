# Roadmap

**Milestone:** vM004 Customer Voice Activation

## Phases
- [x] **M004-S01: Resolution Telemetry & Host Extensibility** - Core telemetry pipeline and documentation for resolution events.
- [ ] **M004-S02: Customer Satisfaction (CSAT) Capture** - User-facing CSAT rating UI, storage, and telemetry emission.

## Phase Details

### M004-S01: Resolution Telemetry & Host Extensibility
**Goal**: Host applications can reliably react to conversation resolution events.
**Depends on**: None (First phase)
**Requirements**: TLM-01, TLM-02, EXT-01
**Success Criteria** (what must be TRUE):
  1. Resolving a conversation emits the `[:cairnloop, :conversation, :resolved]` telemetry event with conversation ID and duration.
  2. Developers can consult documentation and a reference handler to hook external actions (like App Store prompts) to the resolution event.
**Plans**: 1
**UI hint**: no

### M004-S02: Customer Satisfaction (CSAT) Capture
**Goal**: Users can seamlessly provide feedback upon conversation resolution, which is durably stored and emitted as telemetry.
**Depends on**: M004-S01
**Requirements**: SNT-01, SNT-02, SNT-03
**Success Criteria** (what must be TRUE):
  1. User sees a frictionless CSAT rating prompt in the widget immediately after a conversation is resolved.
  2. Selecting a rating dismisses the prompt and durably stores the rating on the conversation record.
  3. Submitting the rating emits a `[:cairnloop, :feedback, :csat_submitted]` telemetry event.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| M004-S01: Resolution Telemetry & Host Extensibility | 1/1 | Completed | 2024-05-18 |
| M004-S02: Customer Satisfaction (CSAT) Capture | 0/? | Not started | - |