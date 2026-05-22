# Architectural Decision: Vector Embedding Generation

## 1. Executive Summary & Recommendation

**Recommendation: Implement an `Embedder` Behaviour (Option A by default, with Option B as opt-in).**

For the M008 Phase 3 Oban worker responsible for chunking and embedding Markdown, Cairnloop should default to an **External API Client** (Option A) via a well-defined Elixir `@behaviour`. 

While the pure vision aims for "zero external infrastructure dependencies," forcing local ML evaluation (Bumblebee/Nx/EXLA) onto every host Phoenix application imposes an unacceptable Developer Experience (DX) penalty. Compiling XLA and managing local model weights violates the "embedded simplicity" and "operator-first DX" principles. We must redefine "zero infrastructure" to mean *no additional stateful infrastructure to host* (no Redis, no separate vector DB, no separate worker nodes—just Postgres/Oban), while treating the AI model provider as a configurable SaaS dependency by default, identical to an email provider like Postmark.

## 2. Context & Constraints

The project’s Core Value states: *"Provide an embedded Elixir-native customer support engine with high extensibility, strict AI governance, and zero external infrastructure dependencies."*

However, embedding a library into a host Phoenix application means we share the host's build and deployment pipeline. 

The tension:
- **Zero Infrastructure:** Local ML (Bumblebee) achieves this perfectly. No OpenAI keys, no external SaaS. Data never leaves the host.
- **Embedded DX:** Local ML requires compiling `exla` (C++ bindings), downloading gigabytes of model weights, and tuning memory limits on the host deployment (e.g., Fly.io or Render 1GB instances). This severely harms adoption for "solo SaaS operators and small engineering teams."

## 3. Analysis of Options

### Option A: External API Client (Req + Provider)
Generating embeddings via an HTTP call to a provider (OpenAI, Anthropic, or an internal mock like Scrypath).

**Pros:**
* **Zero DX Penalty:** No C++ compilation, no `exla` dependencies. The library remains lightweight and fast to compile (`mix deps.get` takes seconds, not minutes).
* **Low Deployment Overhead:** Fits comfortably on the smallest Fly.io/Render web instances without memory exhaustion from loading LLM/embedding models.
* **Idiomatic Elixir:** HTTP clients (Req/Finch) supervised by Oban jobs are the standard way Elixir applications handle asynchronous, fault-tolerant background work. 
* **Scoria Alignment:** Easy to emit standard `telemetry` events (e.g., `RETRIEVER`, `EMBEDDER`) for external API calls, tracking token costs and latency for the control plane.

**Cons:**
* Data leaves the host environment (privacy implications).
* Requires the host to manage API keys.
* Technically breaks the absolute purist definition of "zero dependencies."

### Option B: Local ML Models (Bumblebee + Nx)
Running embedding models directly inside the Erlang VM using Nx and Bumblebee.

**Pros:**
* Absolute data privacy (data never leaves the host).
* Truly "zero external dependencies" (no API keys, no external network calls).
* Highly resilient to network partitions.

**Cons:**
* **Massive DX Penalty:** Compiling `exla` is notoriously slow and brittle across different OS/Architecture targets (especially Apple Silicon vs Linux CI).
* **Bloated Footprint:** The host application's Docker image size balloons, and boot times increase as models are loaded into memory.
* **Support Burden:** As library maintainers, we would inherit issues related to XLA compilation, CUDA drivers, and memory limits across every host app's environment.

## 4. The "SaaS in a Box" Synergy

Drawing from the ecosystem lessons (Sigra, Scoria, Parapet), Cairnloop should be "Batteries-Included but Composable." 

We can satisfy both the DX requirement and the privacy requirement by utilizing Elixir's strongest feature: **Behaviours**.

### Implementation Strategy

1. **Define the Contract:** Create a `Cairnloop.KnowledgeBase.Embedder` behaviour.
    ```elixir
    defmodule Cairnloop.KnowledgeBase.Embedder do
      @callback embed(text :: String.t(), opts :: keyword()) :: {:ok, pgvector_tensor()} | {:error, term()}
    end
    ```

2. **Default to the Network (Option A):** Ship a default adapter, e.g., `Cairnloop.KnowledgeBase.Embedder.OpenAI` (or `ReqLLM` / `Scrypath`), configured via the host's `config.exs`. This ensures the library installs cleanly via `mix cairnloop.install` with zero compile-time friction.

3. **Opt-In to Local ML (Option B):** Provide documentation (or a separate companion package like `cairnloop_bumblebee`) for users who *demand* absolute data privacy. They can add `:nx` and `:bumblebee` to their own `mix.exs`, configure the `Embedder` adapter, and assume the XLA compile penalty themselves.

4. **Oban Worker Design:** The Oban worker simply calls `Cairnloop.config(:embedder_adapter).embed(chunk)`. If the API rate limits, Oban's native backoff and retry mechanisms handle it gracefully. 

## 5. Conclusion

By defining "infrastructure" as stateful services (databases, queues) rather than stateless APIs (LLMs, Embeddings), we preserve the spirit of Cairnloop. The host app still only needs Postgres and Oban to run.

Defaulting to an External API adapter provides the frictionless "Day-0 visual onboarding" required for wide adoption, while an Ecto/Plug/Behaviour-driven architecture leaves the door open for enterprise users to inject local Bumblebee execution when privacy outweighs DX.