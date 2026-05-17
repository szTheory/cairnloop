# M008 Roadmap: The Knowledge Base Engine (RAG Substrate)

## Overview
**Goal:** Build a highly-structured, RAG-optimized CMS entirely within Elixir/Phoenix that serves as the source-of-truth for self-service and Scoria AI triage.
**Architecture:** Utilizes an immutable Revision-Based architecture (`Article`, `Revision`, `Chunk`) inside Ecto. Operators author in pure Markdown via a LiveView side-by-side interface. An Oban worker semantically chunks the Markdown headers (H2/H3) and uses `pgvector` for embedding storage, preventing orphaned vectors and enabling transparent, background RAG indexing.

## Requirements
- **M008-REQ-01**: System implements an immutable Revision-Based architecture in Ecto, utilizing `Article`, `Revision`, and `Chunk` schemas.
- **M008-REQ-02**: LiveView dashboard provides a Markdown-native authoring interface with side-by-side preview for operators.
- **M008-REQ-03**: System triggers an asynchronous Oban worker upon revision publish to semantically chunk the Markdown content based on headers (H2/H3).
- **M008-REQ-04**: System utilizes `pgvector` within PostgreSQL to store vector embeddings for each parsed Markdown chunk.
- **M008-REQ-05**: AI chunking and embedding processes execute completely transparently in the background, without blocking operator workflows.
- **M008-REQ-06**: The Knowledge Base system exposes a retrieval API, serving as a RAG-optimized source-of-truth for Scoria AI triage and self-service.

## Phases

- [ ] **Phase 1: Immutable Knowledge Base Foundation (Ecto)** - Establish the core relational models for a revision-based Knowledge Base
- [ ] **Phase 2: LiveView Markdown Authoring Interface** - Enable operators to securely write and preview Knowledge Base articles in Markdown
- [x] **Phase 3: Semantic Chunking & pgvector Embeddings (Oban)** - Automatically prepare and index Markdown content for optimal AI retrieval via RAG

## Phase Details

### Phase 1: Immutable Knowledge Base Foundation (Ecto)
**Goal**: Establish the core relational models for a revision-based Knowledge Base to prevent orphaned vector embeddings.
**Depends on**: Nothing
**Requirements**: M008-REQ-01
**Success Criteria**:
  1. Database contains `Article`, `Revision`, and `Chunk` schemas with proper foreign keys and indexes.
  2. Ecto models enforce immutability for published revisions, ensuring historical accuracy and preventing "Orphaned Vectors".
  3. System can query the latest active revision for any given article.
**Plans**: TBD

### Phase 2: LiveView Markdown Authoring Interface
**Goal**: Enable operators to securely write and preview Knowledge Base articles in Markdown, avoiding RAG-destroying WYSIWYG HTML.
**Depends on**: Phase 1
**Requirements**: M008-REQ-02
**Success Criteria**:
  1. Operator can navigate to a "Knowledge Base" section in the LiveView dashboard.
  2. Operator can author an article using a native Markdown editor and see a real-time, side-by-side preview.
  3. Operator can save drafts and publish new revisions seamlessly.
**Plans**:
  - [02-01-PLAN.md](./milestones/M008-phases/M008-S02/02-01-PLAN.md)
**UI hint**: yes

### Phase 3: Semantic Chunking & pgvector Embeddings (Oban)
**Goal**: Automatically prepare and index Markdown content transparently in the background for optimal AI retrieval via RAG.
**Depends on**: Phase 1, Phase 2
**Requirements**: M008-REQ-03, M008-REQ-04, M008-REQ-05, M008-REQ-06
**Success Criteria**:
  1. Publishing a revision seamlessly enqueues an Oban worker to parse and chunk the Markdown content by structural headers (H2/H3).
  2. The background worker generates embeddings for each chunk and persists them directly to the `Chunk` schema using PostgreSQL's `pgvector`.
  3. AI drafting tools and triage systems can perform vector similarity searches against the chunk embeddings to retrieve highly specific context without blocking the host application.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Immutable Knowledge Base Foundation (Ecto) | 1/1 | Complete | 2026-05-16 |
| 2. LiveView Markdown Authoring Interface | 1/1 | Planned | - |
| 3. Semantic Chunking & pgvector Embeddings (Oban) | 1/1 | Complete | 2026-05-17 |