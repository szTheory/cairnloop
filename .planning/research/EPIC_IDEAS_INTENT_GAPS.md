# Intent Classification & Knowledge Gap Clustering
*A comprehensive synthesis for Cairnloop's domain architecture.*

## 1. The Vision: The Feedback Flywheel
Customer support automation isn't just about deflecting tickets; it's about identifying structural failures in the product or documentation. By leveraging Intent Classification and Knowledge Gaps, Cairnloop transforms support from a cost center into a direct product roadmap input.

**The Workflow:**
1. **Classify:** Every message gets categorized with an Intent and a Confidence Score.
2. **Deflect or Defer:** High confidence = Self-service. Low confidence = Human operator.
3. **Embed Failures:** When self-service fails, embed the user's initial message.
4. **Cluster Gaps:** Group similar unhandled embeddings into "Knowledge Gaps".
5. **Action:** Operator reviews the top Gap, clicks "Draft Article", and closes the loop.

---

## 2. Architectural Deep Dive: Intent Classification

### The Industry Standard (Zendesk / Intercom)
Successful platforms don't rely purely on keyword matching. Zendesk uses an architecture involving Spectral-normalized Neural Gaussian Processes (SNGP). The main takeaway for Cairnloop isn't the specific math, but the *purpose*: **Uncertainty Estimation.** A bot that confidently guesses the wrong answer is worse than a bot that says "I don't know."

### The Cairnloop Approach (Idiomatic Elixir)
Since Cairnloop is an embedded Elixir library, DX is paramount. Forcing heavy ML dependencies (Nx/EXLA) on consuming apps is an anti-pattern. 

**Recommendation: The Pluggable Intent Behaviour**
Define a strict behaviour for intent.

```elixir
defmodule Cairnloop.Intent do
  @type confidence :: :high | :medium | :low
  @callback classify(String.t()) :: {:ok, %{intent: String.t(), confidence: confidence()}}
  @callback embed(String.t()) :: {:ok, list(float())}
end
```

*   **Default (Lightweight):** Provide a `Cairnloop.Intent.OpenAI` adapter. It uses simple API calls (`Req`) with structured outputs to categorize intents and map probabilities to confidence scores.
*   **Advanced (Local ML):** Provide documentation (and eventually an optional package) for `Cairnloop.Intent.Bumblebee`. This uses `Nx.Serving` under a supervision tree to run local text-classification models with automatic batching, saving API costs for massive deployments.

---

## 3. Architectural Deep Dive: Knowledge Gap Clustering

When intent is "Unknown" or the bot fails to satisfy the user, we track it. 

### The Storage Layer: `pgvector`
Do not introduce external vector databases (Pinecone). Since Cairnloop uses Ecto and Postgres, `pgvector` is the undisputed choice.
*   **Action:** Create a `cairnloop_knowledge_gaps` table with a `vector` column representing the embedding of the failed user message.

### The Clustering Engine: Oban
Clustering is slow and CPU intensive. It must not block Phoenix web requests.
*   **Action:** Use an `Oban` cron job (e.g., running nightly or hourly) to process un-clustered vectors.
*   **Methodology:**
    1.  **Phase 1 (Simplest):** For every new unhandled message, do a similarity search (`<->`) against existing "Gap Clusters". If distance < threshold, assign it to the cluster. If no match, create a new cluster.
    2.  **Phase 2 (Advanced):** Use an LLM to periodically summarize the largest clusters into human-readable "Topic Names" (e.g., "Users asking about password resets for legacy accounts").

---

## 4. UI/UX & Developer Ergonomics (DX)

### Operator UX: The Gap Dashboard
*   **Visualizing Volume:** The UI must sort gaps by *volume* and *impact* (e.g., "This missing topic caused 45 human handoffs this week").
*   **One-Click Draft:** When an operator selects a Knowledge Gap, provide a "Draft Article" button. This takes the top 10 user messages from that cluster, sends them to an LLM, and generates a draft Help Center article designed to answer those specific queries.
*   **Suggest Revision:** If an existing published article is repeatedly retrieved but still followed by clarification, escalation, or manual rewrite, the operator should see a "Suggest Revision" path instead of a net-new article flow.
*   **Evidence Discipline:** Drafts should carry explicit support evidence and citations. Resolved cases may inform the proposal, but they should not silently become canonical truth.

### Developer DX: Simple Integration
*   **Migration Safety:** Ensure the Cairnloop Ecto migrations explicitly check for and enable the `pgvector` extension before creating tables.
*   **Oban Independence:** Cairnloop should isolate its Oban jobs (e.g., using a specific queue name like `cairnloop_ml` or a custom prefix) so it doesn't interfere with the consuming application's background jobs.

---

## 5. Pros / Cons & Tradeoffs

| Decision | Pros | Cons |
| :--- | :--- | :--- |
| **LLM API (Default) vs Local Nx** | Zero compilation overhead; works everywhere. Fast setup. | Ongoing API costs; data leaves the server. |
| **`pgvector` vs External Vector DB** | Keeps infrastructure simple. Transactional integrity with existing user data. | `pgvector` approximate indexes (HNSW) can be complex to tune at massive scale. |
| **Background (Oban) Clustering** | Keeps UI fast; resilient to crashes. | Real-time gaps aren't instantly visible; requires Oban setup. |
| **Operator copilot vs autonomous publishing** | Keeps the KB trustworthy and aligns with HITL support posture. | Adds review friction and requires good diff/evidence UX. |

## 6. Summary for the Epic

To execute this, the epic should be broken into:
1.  **Core Interface:** Pluggable AI behaviour and default LLM adapter.
2.  **Telemetry & Storage:** Tracking failed self-service events and storing embeddings via `pgvector`.
3.  **The Engine:** Oban workers for async embedding generation and periodic clustering.
4.  **The UI:** Phoenix LiveView dashboard for operators to view gaps, generate draft articles, and suggest revisions to stale KB content.
5.  **The Review Layer:** Draft-vs-published workflow, citation-backed evidence presentation, and optional Scoria governance/eval integration.
