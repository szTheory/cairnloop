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

## Epic 4: Customer Voice Activation (Customer-Led Growth) (Completed)
**Goal:** Transform the support center from a cost-center to a growth-engine by triggering actions when users are happiest.

* **Idiomatic Elixir Approach:** 
  * Fire high-signal events via `:telemetry.execute([:cairnloop, :conversation, :resolved], %{duration: ..., sentiment_shift: :positive})`.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Keeps Cairnloop perfectly decoupled. Cairnloop doesn't build a referral engine; it just provides the spark.
  * *Cons:* The host must wire up the Telemetry handler to actually show the App Store review prompt.
* **Lessons Learned:** Support is the highest leverage point for reviews. Intercepting angry users (Private Recovery) prevents 1-star reviews, while rapidly solving a bug creates extreme loyalty (Promoters).
* **UX/DX:** DX is phenomenal—developers just attach a telemetry handler. For UX, the end-user gets a highly contextual, well-timed prompt ("We're glad we fixed that for you! Mind leaving a review?").

---

## Epic 5: Durable Auditing & SRE Observability (Completed)
**Goal:** Ensure enterprise-grade compliance and reliability for the support operations.

* **Shipped:** 2026-05-13 (vM005)
* **Built:** `Cairnloop.Auditor` behavior, Parapet SLI integration, and basic telemetry trace lane (vM011).

---

## Epic 6: Omnichannel SLA Escalation (Chimeway) (Completed)
**Goal:** Route critical support events (SLA breaches, VIP tickets) to the Host's internal channels (Slack, PagerDuty, Email) without hardcoding integrations.

* **Shipped:** 2026-05-15 (vM006)

---

## Epic 11: Support-Triggered Outbound Lifecycle (Planned)
**Goal:** Trigger proactive, support-related outbound campaigns (e.g. incident recovery, bug-fix notifications) without building a generic marketing CRM.

* **Priority:** High
* **Idiomatic Elixir Approach:** 
  * Use **Oban** to schedule high-context outbound actions (e.g., `schedule_in: {2, :hours}`).
  * Define a `Cairnloop.Notifier` behaviour wired to Chimeway (routing) and Mailglass (templates) for delivery.
  * Treat outbound messages as Ecto `system_outbound` records appended to the `Conversation`.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Strictly scoped to support events. Maintains the "SaaS in a Box" DNA.
  * *Cons:* Requires the host to wire up Mailglass templates for delivery.
* **Lessons Learned:** Mixing support lifecycle with marketing (Intercom Series) leads to message collisions and bloat. Plain correctly treats support outbound as transactional events linked to ticket resolutions.
* **UX/DX:** "Bulk Incident Recovery" allows fanning out a resolution message to 50 tagged conversations seamlessly. Outbound is clearly differentiated in the LiveView timeline using distinct design tokens.

---

## Epic 12: Advanced Routing & Team Collaboration
**Goal:** Scale support operations from a single-operator "Inbox" to departmental teams and queues.

* **Priority:** Medium
* **Idiomatic Elixir Approach:** 
  * Schema-backed `Team` and `Queue` models with `belongs_to` relationships on `Conversation`.
  * Use **Phoenix PubSub** for real-time routing events (e.g., "Conversation moved to Engineering").
  * Implement "Team Presence" indicators to prevent double-replies.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Necessary for enterprise adoption. Prevents collisions in busy inboxes.
  * *Cons:* Increases UI complexity. Requires more robust permissions logic.
* **Lessons Learned (Zendesk):** Over-complex routing rules are a common pain point. Cairnloop should default to "Simple Handoff" and allow custom `RoutingPlug` extensions.

---

## Epic 13: Privacy-First Local AI (Nx/Bumblebee)
**Goal:** Reduce dependency on remote LLMs by enabling local inference for classification and summarization.

* **Priority:** Medium
* **Idiomatic Elixir Approach:** 
  * Use **`Nx` and `Bumblebee`** for local BERT/Llama inference.
  * Wrap in `Nx.Serving` to handle batching and GPU/CPU partitioning.
  * Maintain the existing `Cairnloop.Intent` behavior so local vs remote is a config switch.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Zero data egress. Significant cost reduction for high-volume classification.
  * *Cons:* Host hardware requirements (RAM/GPU) increase. Model management adds complexity.
* **Lessons Learned:** Privacy is a top-tier blocker for many internal-tool adopters. Local classification ("Is this PII?") is often the first step in a "Dark AI" strategy.

---

## Epic 14: Mobile SDK Surface
**Goal:** Bring the real-time support experience to mobile applications (React Native, Flutter, Native) via a simplified protocol and headless SDK.

* **Priority:** Low
* **Idiomatic Elixir Approach:** 
  * Build a specialized **JSON-API or gRPC ingress** optimized for mobile latency.
  * Provide a headless Elixir-backed SDK (or JS bridge) that wraps the `WidgetChannel` logic.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Opens up mobile SaaS markets.
  * *Cons:* High maintenance surface for client libraries.
* **UX/DX:** Developers shouldn't need to rebuild the UI; Cairnloop should provide "Unstyled Primitives" for mobile so it fits the host app's design system perfectly.

---

## Epic 7: Grounded Support Retrieval & Answering (Reframed 2026-05-17)
**Goal:** Turn the Knowledge Base engine into a visible support loop by grounding operator search and AI drafts in trustworthy retrieval.

* **Idiomatic Elixir Approach:** 
  * Build a host-owned retrieval boundary on top of **`pgvector` plus PostgreSQL full-text search** before introducing external search infrastructure.
  * Index published Knowledge Base revisions as primary truth and resolved conversation summaries as secondary evidence via **Oban**.
  * Emit retrieval, reranking, and grounding telemetry so **Scoria** and **Parapet** can inspect answer quality end to end.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Highest leverage on the M008 substrate, safer than broader agent autonomy, reusable by both operator search and AI drafting.
  * *Cons:* Retrieval quality becomes the product bottleneck quickly, and weak visibility filtering or stale evidence can destroy trust.
* **Lessons Learned:** Help Scout, Zendesk, Plain, and Pylon all reinforce the same rule: AI support quality is downstream of grounded knowledge retrieval, not the other way around. Historical conversations help, but KB content must remain the primary factual source.
* **UX/DX:** Operators get `cmd+k` search, similar-case assist, and cited draft evidence; host apps get one retrieval abstraction instead of a UI-specific remote search dependency.

---

## Epic 8: The Knowledge Base Engine (RAG Substrate)
**Goal:** Build a highly-structured, RAG-optimized CMS entirely within Elixir/Phoenix that serves as the source-of-truth for self-service and Scoria AI triage.

* **Idiomatic Elixir Approach:** 
  * Use an immutable **Revision-Based** architecture (`Article`, `Revision`, `Chunk`) inside Ecto.
  * Use `MDEx` or `Earmark` via an Oban worker to semantically chunk Markdown headers (H2/H3).
  * Use `pgvector` inside PostgreSQL for embeddings instead of external vector DBs.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Zero external dependencies, trivial to join relational visibility rules (authenticated vs public).
  * *Cons:* Requires building semantic Markdown parsing in Elixir rather than simple string splits.
* **Lessons Learned:** Zendesk Guide is too disjointed; Pylon/Plain succeed by keeping articles Markdown-native. Avoid WYSIWYG HTML as it destroys RAG parsing fidelity. Immutable revisions prevent "Orphaned Vectors" where AI cites deprecated policy.
* **UX/DX:** Operators author in Markdown with a LiveView side-by-side preview. The AI chunking and embedding happens completely transparently via Oban.

---

## Epic 9: AI Tool Governance & MCP Integration
**Goal:** Safely expose policy-gated support tools (like Accrue billing lookups or Stripe refunds) to the AI drafting engine without runaway agency.

* **Idiomatic Elixir Approach:** 
  * Use an **Asynchronous State Machine** with Oban and Ecto. When the LLM calls a high-risk MCP tool, halt the Oban worker, persist a `ToolApproval` record, and broadcast a PubSub event.
  * Resume via a new Oban job only after LiveView operator approval.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Prevents process timeouts and provides operator-grade safety (Human-in-the-Loop).
  * *Cons:* High complexity requiring pause/resume state management rather than simple `GenServer.call` blocks.
* **Lessons Learned:** Pylon's "Runbooks" succeed by replacing raw JSON with domain-specific UI. Never rely purely on "confidence scores" for mutations.
* **UX/DX:** Operators don't approve raw JSON. The `ContextProvider` renders rich LiveComponents (e.g., an Accrue "Refund Preview" card) inside `ConversationLive` for frictionless HITL approval.

---

## Epic 10: Intent Classification & Knowledge Gap Clustering
**Goal:** Transform unhandled support failures into direct product roadmap inputs by identifying structural gaps in the Knowledge Base.

* **Idiomatic Elixir Approach:** 
  * Define a `Cairnloop.Intent` behaviour with a default `Req`-based LLM adapter, allowing for future local ML via `Nx.Serving` (Bumblebee).
  * Use `pgvector` to store embeddings of failed/unhandled user messages.
  * Run periodic background Oban cron jobs to cluster similar vectors (`<->`) using similarity thresholds.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* High resilience by pushing clustering to Oban. Pluggable adapters avoid forcing Nx/EXLA on the host application.
  * *Cons:* Background clustering means gaps aren't instantly real-time.
* **Lessons Learned:** Zendesk's Intelligent Triage focuses on SNGP for "Uncertainty Estimation." Knowing when to defer to a human is more critical than guessing the right intent.
* **UX/DX:** The Operator Gap Dashboard sorts by volume and impact. A "One-Click Draft" button takes the top 10 messages from a cluster and uses an LLM to propose a new KB Article.
* **Recommended operating model:** Ship this as an operator-copilot core that proposes KB draft articles and KB draft revisions from support evidence. Keep human approval mandatory for publication, and reserve autonomy for narrow non-canonical maintenance work only.
* **Scoria boundary:** Optional integration only. Cairnloop owns the KB lifecycle and review UX; Scoria may add citations, grounding scores, eval persistence, and approval/workflow evidence.

---

## Epic 11: Support-Triggered Outbound Lifecycle
**Goal:** Trigger proactive, support-related outbound campaigns (e.g. incident recovery, bug-fix notifications) without building a generic marketing CRM.

* **Idiomatic Elixir Approach:** 
  * Use **Oban** to schedule high-context outbound actions (e.g., `schedule_in: {2, :hours}`).
  * Define a `Cairnloop.Notifier` behaviour wired to Chimeway (routing) and Mailglass (templates) for delivery.
  * Treat outbound messages as Ecto `system_outbound` records appended to the `Conversation`.
* **Pros/Cons & Tradeoffs:** 
  * *Pros:* Strictly scoped to support events. Maintains the "SaaS in a Box" DNA.
  * *Cons:* Requires the host to wire up Mailglass templates for delivery.
* **Lessons Learned:** Mixing support lifecycle with marketing (Intercom Series) leads to message collisions and bloat. Plain correctly treats support outbound as transactional events linked to ticket resolutions.
* **UX/DX:** "Bulk Incident Recovery" allows fanning out a resolution message to 50 tagged conversations seamlessly. Outbound is clearly differentiated in the LiveView timeline using distinct design tokens.

---

## Next Steps: Structuring M009
Based on the current product state on **2026-05-17**, the next milestone should be **M009: Retrieval-First Support Answers & Search Ops**.
1. **Hybrid Retrieval Corpus:** Build a host-owned retrieval layer over published KB content and resolved support evidence.
2. **Operator Search:** Use that retrieval layer for a trustworthy `cmd+k` dashboard workflow.
3. **Grounded Drafts:** Feed cited retrieval evidence into the draft loop before any broader agent autonomy work.
4. **Retrieval Analytics:** Preserve no-hit evidence and quality signals so M010 can cluster real knowledge gaps instead of inferred ones.
