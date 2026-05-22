# M008 Milestone Summary: The Knowledge Base Engine (RAG Substrate)

## Overview
Milestone M008 successfully built a highly-structured, RAG-optimized CMS entirely within Elixir/Phoenix that serves as the source-of-truth for self-service and Scoria AI triage. This milestone implemented an immutable Revision-Based architecture, a LiveView Markdown authoring interface, and a background Oban worker pipeline to parse and embed content using `pgvector`.

## Completed Phases

### Phase 1: Immutable Knowledge Base Foundation (Ecto)
- Established the core relational models (`Article`, `Revision`, `Chunk`) using Ecto schemas and migrations.
- Configured PostgreSQL to use the `vector` extension.
- Added strict immutability rules to the `Revision` changeset, preventing modifications once a revision state is marked as `:published`.
- Implemented robust retrieval functions like `get_latest_active_revision`.

### Phase 2: LiveView Markdown Authoring Interface
- Integrated `Earmark` to safely parse Markdown on the server side.
- Built a native Markdown LiveView editor with a debounced, side-by-side preview to optimize for operator authoring without relying on RAG-destroying WYSIWYG editors.
- Implemented core draft and publish workflows: creating a new draft correctly versions a published article, while modifying a draft simply updates the existing draft state.

### Phase 3: Semantic Chunking & pgvector Embeddings (Oban)
- Established an `Embedder` behavior alongside an `ExternalApi` module utilizing `Req` to interface with the OpenAI embedding endpoint.
- Created `MarkdownParser` to cleanly slice content into segments bounded by H2 and H3 structural headers.
- Engineered an idempotent Oban worker (`ChunkRevision`) that automatically enqueues upon revision publishing. It securely extracts markdown chunks, requests embeddings, drops old chunks for the revision, and seamlessly persists `pgvector` data directly to the database.

## Key Outcomes & Value Delivered
- **Orphaned Vectors Prevented:** The core implementation of Ecto immutability guarantees historical accuracy and prevents dangling or mismatched vector embeddings.
- **RAG Substrate Ready:** Markdown authoring coupled with header-based semantic chunking ensures the Knowledge Base retains high structural fidelity, perfect for downstream Scoria AI LLM generation and retrieval tasks.
- **Transparent AI Processes:** The embedding sequence and chunk generation operate completely decoupled in the background via Oban, guaranteeing no UI blocking or performance degradation for operators authoring content.
