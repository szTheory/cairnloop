# Architectural Research: Cairnloop Host Extensibility (Phase 1)

Based on the provided implementation plans, Cairnloop's codebase, and the deep research artifacts (`elixir-lib-customer-support-automation-deep-research.md`, `parapet overview`, and `scoria overview`), here is the comprehensive analysis and "one-shot" architectural recommendation for Host Extensibility.

---

## 1. Executive Summary & Core Thesis

The "Dual Emission" architecture chosen for Phase 1—emitting both a `[:cairnloop, :conversation, :resolved]` Telemetry event and utilizing a `Cairnloop.Notifier` Behaviour—is fundamentally sound. It correctly solves the primary tension in embedded library design: the need for **ephemeral observability** vs. **durable business logic**. 

To align with the "SaaS in a Box" and "Host-owned over magical black-boxes" DNA of the broader szTheory ecosystem (Parapet, Scoria, Threadline), the architectural boundary must be rigorously enforced:

*   **Telemetry is for Ephemeral Observation:** Use it for metrics, tracing, APM, Parapet SLOs, and ephemeral UI reactivity (e.g., LiveView PubSub broadcasts).
*   **Behaviours are for Durable Action:** Use the Notifier behaviour, backed by transactional Oban jobs, for critical side-effects like CRM syncing, email dispatch (Mailglass), or billing changes (Accrue).

---

## 2. Approach 1: Telemetry Domain Events

**Mechanism:** Emitting events like `:telemetry.execute([:cairnloop, :conversation, :resolved], measurements, meta)` natively in Elixir.

### Pros
*   **Absolute Decoupling (N-arity):** The core library has zero knowledge of who is listening. You can have zero listeners or ten listeners without changing Cairnloop's code.
*   **Ecosystem Native:** This is the lingua franca of Elixir observability. It immediately unlocks integration with **Parapet** (for SLOs/SLIs) and **Scoria** (via OpenInference semantic spans).
*   **Non-intrusive:** Allows the host app to wire up cross-cutting concerns (like logging or metrics reporting) in a single telemetry startup module.

### Cons / Tradeoffs
*   **"Spooky Action at a Distance":** It can be notoriously difficult for new developers to track down where an event is being handled because the wiring is done globally at runtime.
*   **Synchronous Execution Risks:** Telemetry handlers execute in the process that emits them. If a user attaches a slow or failing handler to `[:cairnloop, :conversation, :resolved]`, it blocks the caller or risks crashing the process.
*   **Zero Durability:** If the host app restarts a millisecond after the Ecto transaction commits but before the telemetry event is fully processed by handlers, the event is lost forever.

### Best Use Case Example
Broadcasting a Phoenix PubSub message to a LiveView socket to show an "App Store Rating" or CSAT modal immediately after a user's ticket is resolved. If the broadcast fails, the user misses the modal, but database integrity is maintained.

---

## 3. Approach 2: Notifier Behaviour

**Mechanism:** Defining a `@behaviour Cairnloop.Notifier` that the host app implements, which is invoked by an Oban worker (`Cairnloop.Workers.NotifyResolvedWorker`) scheduled inside the same `Ecto.Multi` transaction that resolves the conversation.

### Pros
*   **Guaranteed At-Least-Once Execution:** Because the Oban job is inserted in the exact same `repo().transaction()` as the conversation state change, it is transactionally bound. If the DB commits, the notification *will* happen, surviving app restarts and network failures.
*   **Explicit Contracts:** A `@behaviour` gives Dialyzer and the compiler strict type checking. It is highly discoverable; a developer can jump to definition and see exactly what `on_conversation_resolved/2` expects.
*   **Centralized Business Logic:** It provides a single, obvious namespace (`MyApp.CairnloopNotifier`) for the host app to handle support lifecycle events.

### Cons / Tradeoffs
*   **Single Arity:** Typically, a configuration parameter only points to one module (`config :cairnloop, :notifier, MyApp.Notifier`). To do multiple things, the host must write the fan-out logic inside that module.
*   **Boilerplate:** Requires creating a module and adding it to `config.exs`.

### Best Use Case Example
Triggering a background job to sync the resolved conversation data to Salesforce, or firing off a resolution confirmation email via **Mailglass**. 

---

## 4. Alternative Idiomatic Approaches Considered

*   **Protocols (`defprotocol`):** Protocols in Elixir are designed for *data polymorphism* (doing different things based on the type of data struct), not for lifecycle hooks or side-effects. This would be an anti-pattern here.
*   **Registry / PubSub:** Cairnloop could run its own internal PubSub for domain events. However, this recreates the ephemeral data-loss risk of Telemetry while adding OTP supervision complexity. Telemetry + Oban-backed Behaviours is vastly superior.

---

## 5. Lessons Learned from the Ecosystem

*   **Help Scout & Pylon (API-First vs. Embedded):** Standalone SaaS platforms rely on Webhooks for extensibility, which suffer from delivery failures and payload size limits. As an *embedded* library, Cairnloop bypasses this network unreliability entirely by using Ecto/Oban for guaranteed execution. We must lean into this advantage.
*   **Oban & Phoenix (Behaviours over DSLs):** The best Elixir libraries (like Oban) avoid creating massive, opaque Macro DSLs. They use plain Modules and Behaviours. The deep research specifically notes: *"Do not build a clever macro DSL for everything. This library should feel like Phoenix/Ecto/Plug: explicit modules, clear behaviours, generated defaults."*
*   **The "Bot Jail" Footgun:** Emphasized in the AI research. Telemetry provides the exact data stream needed to monitor AI escalation rates, ensuring we can alert via Parapet if automated resolutions are failing or looping.

---

## 6. The Perfect "One-Shot" Recommendations (Architecture & DX)

To achieve the best Developer Ergonomics (DX), Principle of Least Surprise, and alignment with the broader szTheory vision, implement the following architectural rules:

### 1. Enforce the Boundary in Documentation (The Golden Rule)
Explicitly document the "why" in the `README.md` and HexDocs. 
*   *"Use Telemetry to **observe** the system (Metrics, Tracing, LiveView PubSub)."*
*   *"Use the Notifier Behaviour to **mutate** external systems (CRM Sync, Email, Auditing)."*

### 2. Transactional Notifier Guarantees
Ensure that `Cairnloop.Workers.NotifyResolvedWorker` is the entity calling `MyApp.Notifier.on_conversation_resolved/2`. This ensures that the host app's critical business logic is protected by Oban's retry mechanisms and backoff, preventing the host app from slowing down the web request that resolved the conversation.

### 3. Safe Telemetry Payloads
Adhere to the Parapet/Scoria constraints: Keep high-cardinality data (like `conversation_id`, `actor_id`, and full message bodies) in the **Metadata** map, NOT the **Measurements** map. Measurements should only contain numeric values (e.g., `duration_seconds: 12`, `count: 1`) to prevent Prometheus cardinality explosions.

### 4. Provide a DX Code Generator
To minimize friction and maximize the "Operator-First DX" highlighted in the Scoria and Parapet briefs, provide an Igniter or Mix task to generate the boilerplate:
`mix cairnloop.gen.notifier`
This should scaffold a clean `lib/my_app/cairnloop_notifier.ex` file and inject the configuration into `config/config.exs`, ensuring developers fall into the pit of success.

### 5. Ecosystem Synergy Targets
*   **Parapet:** Expose `[:cairnloop, :conversation, :resolved]` metrics out of the box so the host can define SLOs like "99% of conversations are resolved within 24 hours".
*   **Threadline:** When the Notifier executes a critical side-effect (like an account-altering AI decision), encourage the host to push an audit log to Threadline.
*   **Scoria:** Ensure all LLM/Agent operations inside Cairnloop emit OpenInference-compliant Telemetry spans so Scoria can build the trace tree automatically.