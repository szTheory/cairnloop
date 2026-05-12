# Epic Ideas: The Knowledge Base Engine (RAG Substrate)

**Context:** Cairnloop needs a Phoenix-native Knowledge Base that acts as the source-of-truth for both human self-service and AI RAG (Retrieval-Augmented Generation) for the Scoria triage engine.

## 1. The Core Philosophy

AI support is only as good as its underlying data. If you feed an LLM a messy, outdated, unstructured wiki, it will confidently generate wrong answers. The goal of this Epic is to build a **Highly-Structured, RAG-Optimized CMS** entirely within Elixir/Phoenix.

By keeping this natively embedded (using `Ecto` + `pgvector`), we avoid the distributed state nightmares of syncing a separate headless CMS (Contentful) with a separate vector store (Pinecone).

### Lessons Learned from the Ecosystem
*   **Zendesk Guide:** Extremely powerful, but highly disjointed. Editing an article feels divorced from the agent workspace. It lacks native RAG concepts (just raw HTML). *Takeaway: Keep authoring tight and close to the support workspace.*
*   **Intercom Articles:** Seamless widget integration. They succeed because the KB is deeply integrated into the "Resolution Bot." *Takeaway: Articles must be first-class citizens in the Widget channel.*
*   **Plain / Pylon:** API-first, developer-centric, Markdown-native. *Takeaway: Markdown is the king of RAG. It is naturally structured and easy to chunk.*

## 2. Architectural Recommendation

We recommend a **Revision-Based Hybrid Architecture**.

### The Data Model
Instead of a simple CRUD `Article` table, we use an immutable revision pattern. This prevents "Orphaned Vector" desyncs where an article is updated but old vectors still serve deprecated info.

1.  **`Article`**: Contains the identity (`slug`, `category_id`, `visibility`, `status`).
2.  **`Revision`**: An immutable snapshot of the Markdown content at publish time.
3.  **`Chunk`**: A semantic segment of a `Revision`, containing the raw text, the `pgvector` embedding, and metadata (header level).

### The RAG Pipeline (Idiomatic Elixir)
1.  **Authoring (Phoenix LiveView):** Operator writes in Markdown with a side-by-side live preview. No WYSIWYG HTML editors allowed (they ruin text structure).
2.  **Chunking (Oban):** On publish, an Oban worker traverses the Markdown AST (via `MDEx` or `Earmark`), splitting the document naturally by `H2` and `H3` headers. This is **Semantic Chunking**.
3.  **Embedding (OpenAI/Bumblebee):** The worker fetches vectors for each chunk and saves them to the database.
4.  **Retrieval (Ecto):** Scoria uses Ecto to join the `Chunks` table with the `Article` table, enforcing visibility rules (`where visibility = 'public'`) while sorting by `cosine_distance`.

## 3. Developer Ergonomics & UX

*   **Operator UX:** A Notion-like LiveView editor. Operators should never have to think about "chunks" or "embeddings." They just write Markdown and click Publish. The system handles the AI indexing asynchronously.
*   **Source Attribution:** Because chunks are tied to specific articles, Scoria can trivially append citations to its drafts: *"Based on [Return Policy](#)"*. This builds operator trust.
*   **Feedback Loops:** The widget allows users to vote 👎 on an article. This automatically flags the `Article` in the Cairnloop dashboard as "Needs Review," keeping the source-of-truth clean.

## 4. Tradeoffs & Decisions

| Decision | Approach | Tradeoff |
| :--- | :--- | :--- |
| **Vector DB** | **`pgvector` inside PostgreSQL** | **Pros:** Zero external dependencies; ACID transactions; trivial to join with relational data. **Cons:** HNSW index building can be heavy on massive datasets (not an issue for typical KBs). |
| **Search Method** | **Hybrid Search (BM25 + Vector)** | **Pros:** Catches exact error codes (BM25) *and* conceptual questions (Vector). **Cons:** Requires running two queries and merging them (Reciprocal Rank Fusion). *Recommendation: Start with pure pgvector, add BM25 later.* |
| **Chunking Logic** | **Semantic (AST) vs Fixed-Length** | **Pros:** Semantic chunking preserves context, making RAG drastically smarter. **Cons:** Harder to write the Elixir parsing logic than a simple `String.split`. |

## 5. Phasing the Epic

**Phase 1: The CMS Core**
*   Ecto schemas (`Category`, `Article`, `Revision`).
*   LiveView Markdown Editor and Admin Dashboard.
*   Draft / Publish state machine.

**Phase 2: The RAG Engine**
*   Add `pgvector` to the database.
*   Build the Markdown AST chunker.
*   Oban worker for generating embeddings (OpenAI `text-embedding-3-small`).
*   Integrate with Scoria Engine as a `ContextProvider`.

**Phase 3: Widget Delivery & Feedback**
*   Surface articles in the Widget Channel.
*   Implement `tsvector` keyword search for humans.
*   Add upvote/downvote signals and staleness decay.