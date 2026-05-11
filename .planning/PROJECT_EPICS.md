# Cairnloop: Project Epics & Architectural Roadmap

This document outlines the comprehensive roadmap, epics, and architectural tradeoffs for Cairnloop (Cairnloop). It serves as the durable planning artifact to ensure we do not start from scratch for future milestones.

## Milestone 0 (M000): Foundation & Core Loop (Completed)
- **Built:** Ecto-native schemas (`Message`, `Conversation`), Igniter installation pipeline, LiveView Dashboard (`InboxLive`, `ConversationLive`), Extensibility Contracts (`ContextProvider`, `Notifier`).
- **Validated:** The core "append-only" Ecto model and embedded dashboard pattern.

---

## Epic 1 (M001): The Multi-Channel Ingress Engine (Completed)
**Goal:** Capture support requests seamlessly from inbound email and a host-embedded Web Widget.

- **Built:** `Mailglass` email parser (`EmailParser`), `EmailWebhookPlug` for external email provider integrations, `WidgetSocket` and `WidgetChannel` for real-time WebSocket ingress, and the `ProcessMessage` Oban worker for async message processing and persistence.
- **Validated:** Codebase compiles without warnings, Elixir formatter passes, and the test suite is green.

* **Idiomatic Elixir Approach:** 
  * **Email:** Utilize `Mailglass` (or `Swoosh` integrations) for inbound parsing, backed by `Oban` for reliable, retryable background ingestion.
  * **Web Widget:** Phoenix WebSockets / Channels for real-time presence and instant updates.
* **Pros/Cons & Tradeoffs:** 
  * *Email:* Highly durable and user-friendly (customers just hit "reply"), but parsing nested HTML threads and quoting is notoriously brittle. 
  * *Channels:* Provides an incredible, "Intercom-like" real-time UX, but requires managing persistent connection state and scaling WebSockets (which Phoenix handles exceptionally well).
* **Lessons Learned (Zendesk/Intercom):** Both giants struggle with email thread stripping. We must ensure our inbound parser strictly isolates the new reply from the quoted history.
* **UX/DX:** For DX, the host should only need to drop `<script src="/cairnloop/widget.js"></script>` into their layout. For UX, agents see presence indicators (e.g., "User is currently online") in the LiveView dashboard.

---

## Epic 2 (M002): AI Triage, Drafting, & Governance (Completed)
**Goal:** Automatically classify intent, retrieve Knowledge Base context, and draft responses without hallucination risks.

* **Idiomatic Elixir Approach:** 
  * Use `Oban` for the asynchronous LLM drafting pipeline to never block the Plug request loop.
  * Emit `:telemetry` events adhering to OpenInference semantic conventions.
  * **Integration:** Delegate the actual LLM execution, tracing, and Human-in-the-Loop (HITL) tool approvals to **Scoria** (our AI Governance library).
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* By offloading to Scoria, Cairnloop stays a "Support" library, not an "AI" library. It guarantees strict governance.
  * *Cons:* Introduces a soft dependency on Scoria if the host wants AI features. 
* **Lessons Learned:** Intercom's Fin and early AI agents suffered from hallucination and lack of auditability. By strictly enforcing a `PolicyGate` (HITL), we ensure the operator always reviews the draft before it goes to the customer until confidence is proven.
* **UX/DX:** The LiveView dashboard must clearly differentiate between "User Message", "AI Draft (Pending Approval)", and "Agent Message" using distinct visual tokens (e.g., Cairnloop Palette).

---

## Epic 3 (M003): Deep Context Enrichment (The "SaaS in a Box" Integrations) (Completed)
**Goal:** Bind the support ticket natively to the Host's billing (Accrue) and identity (Sigra) state without brittle API syncing.

* **Idiomatic Elixir Approach:** 
  * Rely entirely on Elixir Behaviours (`Cairnloop.ContextProvider`) and Protocols.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Zero data duplication. No webhooks to sync Stripe data. The embedded LiveView queries the host's Ecto repo directly.
  * *Cons:* The host developer must write the callback implementations (e.g., mapping `actor_id` to their `Users` schema).
* **Lessons Learned (Plain/Pylon):** API-first support tools try to solve this with complex custom data ingestion APIs. Cairnloop sidesteps this entirely by living inside the monolith. 
* **UX/DX:** The agent dashboard should feature a right-hand "Context Pane" that dynamically renders LiveComponents provided by the host (e.g., a "Refund" button that talks directly to Accrue).

---

## Epic 4: Customer Voice Activation (Customer-Led Growth)
**Goal:** Transform the support center from a cost-center to a growth-engine by triggering actions when users are happiest.

* **Idiomatic Elixir Approach:** 
  * Fire high-signal events via `:telemetry.execute([:cairnloop, :conversation, :resolved], %{duration: ..., sentiment_shift: :positive})`.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Keeps Cairnloop perfectly decoupled. Cairnloop doesn't build a referral engine; it just provides the spark.
  * *Cons:* The host must wire up the Telemetry handler to actually show the App Store review prompt.
* **Lessons Learned:** Support is the highest leverage point for reviews. Intercepting angry users (Private Recovery) prevents 1-star reviews, while rapidly solving a bug creates extreme loyalty (Promoters).
* **UX/DX:** DX is phenomenal—developers just attach a telemetry handler. For UX, the end-user gets a highly contextual, well-timed prompt ("We're glad we fixed that for you! Mind leaving a review?").

---

## Epic 5: Durable Auditing & SRE Observability (Threadline & Parapet)
**Goal:** Ensure enterprise-grade compliance and reliability for the support operations.

* **Idiomatic Elixir Approach:** 
  * Integrate with **Threadline** for immutable audit logging of critical operator actions (e.g., "Agent manually approved AI draft", "Agent redacted PII").
  * Integrate with **Parapet** to consume Cairnloop's SLIs (e.g., Time to First Response) into SLO alerts.
* **Pros/Cons & Tradeoffs:** 
  * Avoids reinventing audit trails and alerting within Cairnloop.
* **Lessons Learned:** Enterprise deals are often blocked by a lack of auditability in support software.

---

## Epic 6: Omnichannel SLA Escalation (Chimeway)
**Goal:** Route critical support events (SLA breaches, VIP tickets) to the Host's internal channels (Slack, PagerDuty, Email) without hardcoding integrations.

* **Idiomatic Elixir Approach:** 
  * Integrate with **Chimeway** for durable, template-driven async notification delivery.
  * Use Oban for SLA countdowns (e.g., schedule a `CheckSLA` job 4 hours after a ticket is opened).
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Support agents live in Slack/Discord; they need push alerts when a user has been waiting too long. Chimeway handles the delivery abstractions.
  * *Cons:* Requires managing scheduled jobs for SLAs, which can clutter the Oban queues if not partitioned correctly.
* **Lessons Learned:** Zendesk's trigger system is extremely powerful but complex. Cairnloop will provide simple, out-of-the-box Oban jobs and Chimeway templates for the most common SLA scenarios (First Response, Resolution Time).
* **UX/DX:** Operators can configure SLA thresholds in the LiveView dashboard. Host developers just provide the Chimeway adapter for their preferred chat tool.

---

## Epic 7: Semantic Search & AI Retrieval (Scrypath)
**Goal:** Enable operators to instantly query past conversations, and empower the AI drafting engine to ground its answers using historical resolutions.

* **Idiomatic Elixir Approach:** 
  * Integrate with **Scrypath** for embedding generation, vector indexing, and fast operator querying.
  * Emit Telemetry events upon ticket resolution to trigger asynchronous Scrypath ingestion.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Native Postgres full-text search is good, but Scrypath provides the semantic vector search needed for high-quality RAG (Retrieval-Augmented Generation) when Scoria drafts replies.
  * *Cons:* Adds vector DB overhead or relies on pgvector. Requires a robust syncing strategy to keep the index fresh.
* **Lessons Learned:** AI drafts are only as good as their context. Grounding the Scoria drafting engine with past, resolved tickets prevents hallucination and ensures tone consistency.
* **UX/DX:** The LiveView dashboard gets a powerful `cmd+k` search bar for operators, while Scoria transparently uses Scrypath as an MCP Resource to fetch context.

---

## Next Steps: Structuring M003
Based on the above, **Milestone 3 (M003)** should focus strictly on **Epic 3: Deep Context Enrichment (The "SaaS in a Box" Integrations)**.
1. **ContextProvider Behaviour:** Define the protocols for mapping generic support users to host-specific entities (e.g., Sigra identities).
2. **Dynamic Context Pane:** Build the LiveView extensions for the host to inject billing/account data (e.g., Accrue).
3. **Default Implementations:** Provide mock/reference implementations to ensure the developer experience is seamless.
