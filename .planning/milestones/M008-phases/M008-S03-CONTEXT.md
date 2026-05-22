# M008 Phase 3: Semantic Chunking & pgvector Embeddings (Oban)

## Overview
This phase automatically prepares and indexes Markdown content transparently in the background for optimal AI retrieval via RAG. It addresses requirements M008-REQ-03 through M008-REQ-06.

## Key Decisions
1. **Embedding Generation**: 
   - **Decision**: Define a `Cairnloop.Embedder` Behaviour. Default to using an External API (e.g., calling OpenAI or the Scrypath mock via `Req`) for vector generation. Provide Bumblebee/Nx as an opt-in adapter.
   - **Rationale**: True zero-dependency local ML requires compiling XLA, which adds a massive DX penalty and bloats host Phoenix applications. A Behaviour allows us to ship a lightweight default while supporting air-gapped environments strictly for users who opt into the compile time.
2. **Markdown Parsing**:
   - **Decision**: Use `Earmark` (pure Elixir).
   - **Rationale**: Chunking by structural headers (H2/H3) requires generating an AST. `Earmark` achieves this without introducing native Rust/C NIFs (like `MDEx` would), maintaining Cairnloop's promise of easy embedding and pristine DX.

## Architectural Notes
- The Oban worker will trigger on `Revision` publish events.
- It will parse the Markdown, split by H2/H3 using Earmark, and generate vector embeddings using the configured `Embedder`.
- The chunks and embeddings are stored directly on the `Chunk` schema (using `pgvector`), related to the immutable `Revision`.
