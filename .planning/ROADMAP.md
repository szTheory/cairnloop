# M007 Roadmap: Semantic Search & AI Retrieval (Scrypath)

## Overview
**Goal:** Enable operators to instantly query past conversations, and empower the AI drafting engine to ground its answers using historical resolutions.
**Architecture:** Scrypath for embedding generation and vector indexing, Telemetry and Oban for async ingestion, and Scoria MCP Resource integration for AI grounding.

## Requirements
- **M007-REQ-01**: System integrates with Scrypath for embedding generation and vector indexing.
- **M007-REQ-02**: System emits Telemetry events upon ticket resolution to trigger asynchronous Scrypath ingestion.
- **M007-REQ-03**: System provides a `cmd+k` search bar in the LiveView dashboard for operators to query past conversations.
- **M007-REQ-04**: System connects the Scoria drafting engine with Scrypath as an MCP Resource to fetch context for AI drafts.

## Phases

- [ ] **Phase 1: Scrypath Integration** - Integrate with Scrypath for embedding generation and vector indexing
- [ ] **Phase 2: Telemetry Ingestion** - Emit Telemetry events upon ticket resolution to trigger asynchronous Scrypath ingestion
- [ ] **Phase 3: Operator UI** - Add a powerful `cmd+k` search bar to the LiveView dashboard
- [ ] **Phase 4: AI Grounding** - Connect Scoria drafting engine with Scrypath as an MCP Resource to fetch context

## Phase Details

### Phase 1: Scrypath Integration
**Goal**: System integrates with Scrypath for embedding generation and vector indexing.
**Depends on**: Nothing
**Requirements**: M007-REQ-01
**Success Criteria**:
  1. System is configured to communicate with Scrypath for managing vector indexes.
  2. Embeddings can be accurately generated and stored for conversation data.
**Plans**: TBD

### Phase 2: Telemetry Ingestion
**Goal**: Emits Telemetry events upon ticket resolution to trigger asynchronous Scrypath ingestion.
**Depends on**: Phase 1
**Requirements**: M007-REQ-02
**Success Criteria**:
  1. Resolving a ticket correctly fires a telemetry event.
  2. An async Oban handler listens to the event and triggers ingestion of the conversation into Scrypath.
**Plans**: TBD

### Phase 3: Operator UI
**Goal**: Add a powerful `cmd+k` search bar to the LiveView dashboard.
**Depends on**: Phase 2
**Requirements**: M007-REQ-03
**Success Criteria**:
  1. Operator can open a search modal using the `cmd+k` shortcut in the LiveView dashboard.
  2. Semantic search query returns relevant historical conversations.
**Plans**: 1 plan
- [ ] 03-01-PLAN.md — Implement the cmd+k semantic search modal in the LiveView dashboard
**UI hint**: yes

### Phase 4: AI Grounding
**Goal**: Connect Scoria drafting engine with Scrypath as an MCP Resource to fetch context.
**Depends on**: Phase 2
**Requirements**: M007-REQ-04
**Success Criteria**:
  1. Scoria AI drafting engine transparently uses Scrypath to retrieve historical context.
  2. AI drafts cite past resolutions to ensure tone consistency and reduce hallucinations.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scrypath Integration | 0/0 | Not started | - |
| 2. Telemetry Ingestion | 0/0 | Not started | - |
| 3. Operator UI | 1/1 | Completed | 2024-05-24 |
| 4. AI Grounding | 0/0 | Not started | - |
