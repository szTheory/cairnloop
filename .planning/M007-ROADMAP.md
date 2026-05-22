# M007 Roadmap: Semantic Search & AI Retrieval (Scrypath)

## Overview
**Goal:** Enable operators to instantly query past conversations, and empower the AI drafting engine to ground its answers using historical resolutions.
**Architecture:** Telemetry events trigger Oban workers for asynchronous vector indexing via Scrypath, LiveView powers a `cmd+k` semantic search interface for operators, and Scoria leverages Scrypath as an MCP Resource for context-aware AI drafting.

## Requirements
- **M007-REQ-01**: System emits Telemetry events upon conversation resolution.
- **M007-REQ-02**: System triggers an asynchronous Oban worker to ingest resolved conversation data into Scrypath.
- **M007-REQ-03**: LiveView dashboard provides a global `cmd+k` semantic search interface for operators.
- **M007-REQ-04**: System retrieves semantic search results from Scrypath based on operator queries.
- **M007-REQ-05**: System integrates Scrypath as an MCP Resource for the Scoria AI drafting engine to ground responses in historical data.

## Phases

- [ ] **Phase 1: Telemetry & Asynchronous Ingestion** - Index resolved conversations asynchronously via Scrypath
- [ ] **Phase 2: Operator Semantic Search Interface (LiveView)** - Build a `cmd+k` global search modal for operators
- [ ] **Phase 3: AI Retrieval & Context Grounding** - Provide historical context to Scoria via MCP

## Phase Details

### Phase 1: Telemetry & Asynchronous Ingestion
**Goal**: Ensure resolved conversations are seamlessly and asynchronously indexed into the vector database.
**Depends on**: Nothing
**Requirements**: M007-REQ-01, M007-REQ-02
**Success Criteria**:
  1. Resolving a conversation emits a `:cairnloop, :conversation, :resolved` Telemetry event.
  2. A dedicated Oban worker acts upon the event and successfully pushes the text and metadata to Scrypath for vector embedding and indexing.
**Plans**: TBD

### Phase 2: Operator Semantic Search Interface (LiveView)
**Goal**: Allow operators to query and retrieve past conversations using natural language semantic search.
**Depends on**: Phase 1
**Requirements**: M007-REQ-03, M007-REQ-04
**Success Criteria**:
  1. Operators can open a `cmd+k` search modal from anywhere in the LiveView dashboard.
  2. Submitting natural language queries returns a list of highly relevant, historically resolved conversations powered by Scrypath.
**Plans**: TBD
**UI hint**: yes

### Phase 3: AI Retrieval & Context Grounding
**Goal**: Empower the Scoria AI drafting engine to natively fetch and ground drafts with historical ticket resolutions.
**Depends on**: Phase 1
**Requirements**: M007-REQ-05
**Success Criteria**:
  1. Scrypath is successfully registered as an MCP Resource within the Scoria integration.
  2. AI-generated drafts demonstrate awareness of past resolutions by retrieving context from the Scrypath index when generating responses.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Telemetry & Asynchronous Ingestion | 0/0 | Not started | - |
| 2. Operator Semantic Search Interface (LiveView) | 0/0 | Not started | - |
| 3. AI Retrieval & Context Grounding | 0/0 | Not started | - |