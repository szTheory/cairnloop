# Requirements: vM006 Omnichannel SLA Escalation, vM007 Semantic Search & vM008 Knowledge Base Engine

## Active Requirements (M006)

### SLA Countdown Engine
- [ ] **M006-REQ-01**: System schedules an Oban job (`CheckSLA`) when a conversation is created or updated.
- [ ] **M006-REQ-02**: The `CheckSLA` job executes idempotently, returning NOOP if the conversation is already resolved or replied to.

### Notifier & Chimeway Integration
- [ ] **M006-REQ-03**: System defines a `Cairnloop.Notifier` behaviour for omnichannel delivery.
- [ ] **M006-REQ-04**: System integrates `Chimeway` to deliver notifications when an SLA is breached.
- [ ] **M006-REQ-05**: Host application can configure Chimeway adapters to route messages to Slack, Discord, or Email.

### LiveView Configuration
- [ ] **M006-REQ-06**: Operators can configure SLA thresholds (e.g., Time to First Response, Time to Resolution) via the LiveView dashboard.

## Active Requirements (M007)

### Telemetry & Asynchronous Ingestion
- [ ] **M007-REQ-01**: System emits Telemetry events upon conversation resolution.
- [ ] **M007-REQ-02**: System triggers an asynchronous Oban worker to ingest resolved conversation data into Scrypath.

### Operator Semantic Search Interface (LiveView)
- [ ] **M007-REQ-03**: LiveView dashboard provides a global `cmd+k` semantic search interface for operators.
- [ ] **M007-REQ-04**: System retrieves semantic search results from Scrypath based on operator queries.

### AI Retrieval & Context Grounding
- [ ] **M007-REQ-05**: System integrates Scrypath as an MCP Resource for the Scoria AI drafting engine to ground responses in historical data.

## Active Requirements (M008)

### Immutable Knowledge Base Foundation
- [ ] **M008-REQ-01**: System implements an immutable Revision-Based architecture in Ecto, utilizing `Article`, `Revision`, and `Chunk` schemas.

### LiveView Markdown Authoring
- [ ] **M008-REQ-02**: LiveView dashboard provides a Markdown-native authoring interface with side-by-side preview for operators.

### Semantic Chunking & Embedding Pipeline
- [ ] **M008-REQ-03**: System triggers an asynchronous Oban worker upon revision publish to semantically chunk the Markdown content based on headers (H2/H3).
- [ ] **M008-REQ-04**: System utilizes `pgvector` within PostgreSQL to store vector embeddings for each parsed Markdown chunk.
- [ ] **M008-REQ-05**: AI chunking and embedding processes execute completely transparently in the background, without blocking operator workflows.
- [ ] **M008-REQ-06**: The Knowledge Base system exposes a retrieval API, serving as a RAG-optimized source-of-truth for Scoria AI triage and self-service.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| M006-REQ-01 | Phase 1 (M006) | Pending |
| M006-REQ-02 | Phase 1 (M006) | Pending |
| M006-REQ-03 | Phase 2 (M006) | Pending |
| M006-REQ-04 | Phase 2 (M006) | Pending |
| M006-REQ-05 | Phase 2 (M006) | Pending |
| M006-REQ-06 | Phase 3 (M006) | Pending |
| M007-REQ-01 | Phase 1 (M007) | Pending |
| M007-REQ-02 | Phase 1 (M007) | Pending |
| M007-REQ-03 | Phase 2 (M007) | Complete |
| M007-REQ-04 | Phase 2 (M007) | Pending |
| M007-REQ-05 | Phase 3 (M007) | Pending |
| M008-REQ-01 | Phase 1 (M008) | Pending |
| M008-REQ-02 | Phase 2 (M008) | Pending |
| M008-REQ-03 | Phase 3 (M008) | Pending |
| M008-REQ-04 | Phase 3 (M008) | Pending |
| M008-REQ-05 | Phase 3 (M008) | Pending |
| M008-REQ-06 | Phase 3 (M008) | Pending |