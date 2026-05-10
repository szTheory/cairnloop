Recommendation: build a Phoenix-native Customer Knowledge Automation OS, not a generic helpdesk clone

The strongest version of this library is not “open-source Zendesk for Phoenix.” That is too broad, too operationally heavy, and too easy to turn into a forever-clone of Chatwoot/Zammad/Intercom.

The sharper wedge is:

A Phoenix-native, embedded customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions.

That framing is important. The core value is not merely “manage tickets.” The core value is:

1. Deflect what can be safely deflected.
2. Draft and summarize what cannot be deflected.
3. Escalate risky or ambiguous issues cleanly.
4. Turn repeated support pain into durable product knowledge.
5. Expose support quality as an operator-grade health signal.

Commercial tools already validate the direction: Help Scout’s AI Answers relies on a knowledge base as the source for support answers, Zendesk’s AI support stack emphasizes intent/language/sentiment/entity triage and knowledge gaps, and newer B2B support products like Plain and Pylon emphasize API-first support infrastructure, account context, sources, routing, and knowledge-gap workflows.  ￼

The best OSS/Phoenix angle is therefore:

Embedded, host-owned, Ecto-native support automation for Phoenix SaaS apps.

Not a separate SaaS. Not a full omnichannel contact-center suite. Not a black-box AI bot. A library you install into a Phoenix app that gives the operator an inbox, knowledge base, widget, AI drafting, safe automation, signal extraction, and deep integration with the rest of the app.

⸻

The product boundary

Build these

Area	Recommendation	Why
Support inbox	Core	The operator needs one durable place for conversations, messages, states, assignments, and history.
In-app widget	Core	For a Phoenix SaaS, this is the highest-leverage channel because it can carry authenticated user/account context.
Email support	Core, via adapter	Email is unavoidable, but delivery/inbound parsing should be delegated to Mailglass/MailglassInbound or providers.
Knowledge base	Core	AI support is only as good as the maintained source of truth.
AI answer drafting	Core	Highest ROI and safest early automation mode.
AI self-service answers	Core, gated	Good for low-risk, well-sourced answers with citations and easy handoff.
Triage/classification	Core	Intent, urgency, sentiment, product area, billing/auth/bug/feature labels.
Knowledge-gap detection	Core differentiator	This is where the product becomes more than a helpdesk.
Customer signal layer	Core differentiator	Convert conversations into roadmap inputs, issue clusters, churn risk, testimonials, and product friction.
Safe action tools	Later but important	Billing lookups, account diagnostics, status checks, resend receipt, cancel request, etc.
Lifecycle rescue messages	Later, narrow	Send support-triggered “we fixed this,” onboarding rescue, or known-issue recovery messages.

Do not build these in v1

Area	Decision	Reason
Email deliverability infrastructure	Do not own	Deliverability is operationally specialized. Postmark and Resend explicitly sell reliable email delivery as their product; SES deliverability docs also show how much operational monitoring is involved.  ￼
Full CRM	Do not own	Keep account/customer context thin and adapter-based.
Full product analytics	Do not own	Emit events and integrate outward. Do not rebuild PostHog.
Full social inbox	Do not own initially	API churn, moderation, identity mapping, rate limits, and channel-specific workflows are a separate product.
Phone/contact center	Do not own initially	High operational complexity, transcription, compliance, queueing, SLAs.
Payments/subscriptions	Do not own	Use Accrue/Stripe-shaped integrations for billing context/actions.
Autonomous unrestricted AI agent	Never as default	Tool use must be policy-gated, audited, and reversible where possible.

The clean rule:

Build workflows where your advantage is AI + Phoenix context + structured automation. Rent or adapt workflows where the hard part is infrastructure, compliance, channel operations, or deliverability.

⸻

The shape of the library

Use a placeholder name for now; I’ll call it SupportOS below. I would avoid the actual package name support because it is too generic and will create namespace confusion.

flowchart LR
    A[Customer] --> B[Widget / Email / API Adapter]
    B --> C[Ingress Normalizer]
    C --> D[(Ecto Conversation Store)]
    D --> E[Triage Pipeline]
    E --> F[Knowledge Retrieval]
    F --> G[AI Draft / Answer]
    G --> H{Policy Gate}
    H -->|low risk + sourced| I[Auto Reply]
    H -->|uncertain| J[Human Inbox]
    H -->|action needed| K[Tool Approval]
    J --> L[Resolution]
    K --> L
    I --> L
    L --> M[CSAT / Feedback]
    L --> N[Signal Extraction]
    N --> O[Knowledge Gaps]
    O --> P[Article Drafts / Macro Drafts]
    G --> Q[Scoria Traces + Evals]
    D --> R[Parapet SLIs / SLOs]
    L --> S[Threadline Audit]
    K --> S

The library should have five first-class surfaces:

1. Embedded dashboard for the operator.
2. In-app support widget for end users.
3. Email ingress/egress adapters.
4. Programmatic API for the host Phoenix app.
5. Automation/evaluation layer integrated with Scoria, Parapet, Threadline, Chimeway, Mailglass, Accrue, and Sigra.

⸻

The strongest product positioning

I would position it as:

Phoenix-native customer support automation for solo SaaS operators and small engineering teams.

More expansive:

An embedded Customer Knowledge OS for Phoenix apps: inbox, knowledge base, AI support, customer signal extraction, and safe support automation.

The important word is embedded. Existing open-source tools such as Chatwoot, Zammad, FreeScout, and Papercups mostly behave like standalone support products. Chatwoot positions itself as a self-hosted/open-source alternative to Intercom, Zendesk, and Salesforce Service Cloud with conversations across channels, AI agent features, and a help center; Zammad is an open-source web-based helpdesk with email, chat, phone, and social channels; FreeScout is a lightweight self-hosted Help Scout/Zendesk-style shared inbox; Papercups was an Elixir live support app, but is now in maintenance mode.  ￼

That suggests the gap:

There are open-source helpdesks. There are commercial AI support platforms. But there is room for a Phoenix-native support automation substrate that lives inside the app, sees the app’s domain context, and composes with the app’s auth, billing, observability, audit, and notification layers.

That is much more defensible than “yet another ticketing UI.”

⸻

What to learn from existing tools

1. Chatwoot: learn omnichannel ambition, avoid omnichannel sprawl

Chatwoot validates the market for self-hosted support, shared inboxes, help centers, and AI agents. It also shows the danger: once you become a full support suite, you inherit every channel, every integration, every UI workflow, and every enterprise expectation.  ￼

Lesson: use adapters, but do not make omnichannel breadth the v1 differentiator.

For this Phoenix library, start with:

1. In-app widget.
2. Email.
3. Programmatic API.

Then maybe later:

4. Slack/Discord/community support.
5. App review ingestion.
6. Social channels.

Do not start with phone, SMS, full social, or contact center features.

⸻

2. Papercups: learn the Elixir fit, avoid becoming a stagnant standalone app

Papercups is especially relevant because it was written in Elixir and positioned as a self-hosted alternative to Zendesk/Intercom, with email, SMS, live chat, Slack/Mattermost integrations, markdown support, team invites, and conversation management. It is now explicitly in maintenance mode.  ￼

Lesson: Elixir/Phoenix is a great fit for realtime support, but the product cannot merely be “open-source Intercom clone.” That surface area is huge.

Your library should not try to win by being a standalone support app. It should win by being:

* Phoenix-native.
* Embedded.
* Ecto-owned.
* App-context-aware.
* AI-observable.
* Support-to-knowledge-loop oriented.

⸻

3. FreeScout: learn the power of email-first simplicity

FreeScout’s appeal is clear: self-hosted, lightweight, no lock-in, shared inbox, conversation management, collision detection, push notifications, and practical support workflows.  ￼

Lesson: boring support basics matter.

Do not let AI distract from the core support workflow:

* every inbound message has a durable record;
* every conversation has state;
* operators can assign, tag, search, reply, merge, close, reopen;
* no message is lost;
* duplicate replies are prevented;
* the UI makes the next action obvious.

AI should improve that workflow, not replace it.

⸻

4. Zammad: learn the value of API/docs/security maturity

Zammad is a broad open-source support platform with multiple channels, API docs, install docs, security posture, and foundation-backed governance.  ￼

Lesson: if this is OSS infrastructure, documentation and extension contracts are product features.

For your library, high-quality docs should include:

* install guide;
* dashboard mounting guide;
* security model;
* adapter authoring guide;
* telemetry contract;
* migration/versioning guide;
* AI safety guide;
* example Phoenix app;
* upgrade guide.

⸻

5. Help Scout and Zendesk: AI support starts with knowledge quality

Help Scout’s AI Answers uses Docs as the knowledge source and can operate in different modes, including self-service and neutral modes. Their docs emphasize needing sources, agent tone/brand directives, and a solid information foundation. Zendesk similarly emphasizes generative search, content gaps, article performance, and AI-powered knowledge creation/maintenance.  ￼

Lesson: the knowledge base is not a side feature. It is the automation substrate.

A good Phoenix AI support library needs:

* article versioning;
* source attribution;
* audience visibility;
* product/version scoping;
* search analytics;
* failed-search tracking;
* repeated-question clustering;
* draft article generation;
* human approval before publishing.

⸻

6. Zendesk intelligent triage: intent classification is a force multiplier

Zendesk’s intelligent triage detects intent, language, sentiment, and entities, then uses those signals for routing, grouping, reporting, and macros.  ￼

Lesson: the library needs a normalized Support.Intent layer early.

Even if v0.1 has no fancy AI agent, it should classify conversations into stable buckets:

* billing;
* auth/login;
* bug report;
* feature request;
* onboarding;
* account setup;
* cancellation;
* refund;
* incident/downtime;
* documentation gap;
* abuse/security;
* sales/pricing;
* integration/API help.

These intents become the foundation for routing, macros, analytics, SLOs, knowledge gaps, and automation policy.

⸻

7. Plain and Pylon: API-first support is the modern B2B direction

Plain positions around AI support infrastructure with no-code/all-code workflows, MCP support, cross-channel support, and API-first programmability. Pylon emphasizes B2B support across channels, intent routing, knowledge gaps, account intelligence, drafting, categorization, and sourced AI answers.  ￼

Lesson: your library should be API-first, not just dashboard-first.

A Phoenix-native support library should let the host app do things like:

SupportOS.open_conversation(user, %{
  subject: "Can't export invoice",
  message: "Export fails on my March invoice",
  source: :in_app,
  metadata: %{current_path: "/billing/invoices"}
})
SupportOS.attach_context(conversation, %{
  account_id: account.id,
  plan: account.plan,
  last_invoice_status: :paid,
  feature_flags: [:new_invoice_export]
})
SupportOS.suggest_reply(conversation)

That is where embedded beats standalone.

⸻

The v1 product thesis

The v1 should be:

An embedded Phoenix support inbox + knowledge base + AI drafting layer, with safe automation, support telemetry, and customer-signal extraction.

Not:

* a complete customer service suite;
* a CRM;
* a social inbox;
* a marketing platform;
* a chatbot-only widget;
* a generic admin CRUD panel;
* an unrestricted AI agent.

The v1 “killer workflow” should be:

A customer asks a question in-app or by email. The library attaches app/customer/billing context, retrieves relevant knowledge, drafts or sends a sourced answer, escalates when uncertain, logs the full AI trace, measures outcome quality, and turns repeated unresolved friction into a proposed KB/product improvement.

That is the magic loop.

⸻

Phoenix/Elixir architecture recommendations

1. Use a router macro, not a separate Phoenix endpoint

The idiomatic embedded admin approach in Phoenix is to mount a dashboard through the host router, protected by the host app’s normal pipelines. Phoenix’s own router supports forwarding paths to plugs, and the docs show that forwarded routes can still be protected through pipelines such as browser/auth/admin pipelines. They also warn against forwarding to another Phoenix endpoint.  ￼

Oban Web is a useful model: it exposes an oban_dashboard router macro that the host imports and mounts at a path, with options for things like CSP nonces, resolver, on_mount, socket path, and transport options.  ￼

Recommended pattern:

defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import SupportOS.Web.Router
  scope "/admin", MyAppWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]
    support_dashboard "/support",
      repo: MyApp.Repo,
      otp_app: :my_app,
      on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
      csp_nonce_assign_key: :csp_nonce
  end
end

Do not hide auth behind magic. Let the host app own:

* auth;
* authorization;
* session;
* CSP;
* route placement;
* admin layout;
* socket path;
* deployment concerns.

This matches the “host-owned over magical black boxes” DNA from Parapet and your other libraries.

⸻

2. Use Igniter for install, migrations, and host patching

Igniter is directly relevant because it is designed for code generation, project patching, installers, upgrades, and semantic modification of host app files. It also encourages composable Mix tasks and library installers.  ￼

Recommended install flow:

mix igniter.install support_os
mix support_os.install \
  --repo MyApp.Repo \
  --web MyAppWeb \
  --sigra \
  --scoria \
  --mailglass \
  --chimeway \
  --parapet
mix ecto.migrate

Generated files should be obvious and host-owned:

priv/repo/migrations/*_create_support_os_tables.exs
lib/my_app/support_os.ex
lib/my_app/support_os/context_provider.ex
lib/my_app/support_os/redactor.ex
lib/my_app/support_os/policy.ex
lib/my_app_web/support_os_auth.ex

The installer should support:

mix support_os.install --dry-run
mix support_os.install --yes
mix support_os.gen.adapter email
mix support_os.gen.context billing
mix support_os.doctor

mix support_os.doctor should check:

* repo configured;
* migrations present;
* dashboard route mounted;
* PubSub configured;
* Oban configured if needed;
* Mailglass inbound/outbound configured if email enabled;
* Scoria integration reachable if AI tracing enabled;
* Sigra auth hook configured if selected;
* dangerous automation modes disabled in production unless explicitly approved.

⸻

3. Ecto-native state, append-only messages, explicit transitions

Ecto is the right persistence layer. Changesets give you filtering, casting, validation, and constraints before insert/update, and Ecto.Multi is the right tool for multi-step state changes with clear transaction results.  ￼

Use Ecto for durable state:

support_conversations
support_messages
support_participants
support_contact_identities
support_inboxes
support_assignments
support_tags
support_intents
support_automation_runs
support_ai_turns
support_tool_calls
support_kb_articles
support_kb_article_versions
support_kb_chunks
support_search_events
support_feedback_events
support_signal_clusters
support_idempotency_keys

Important design choice:

Messages should be append-only. Conversation state can change, but message history should not silently mutate.

For edits/redactions, use fields/events such as:

redacted_at
redacted_by_id
redaction_reason
superseded_by_message_id

This matters for audit, safety, customer trust, and AI replay.

⸻

4. Behaviours over a giant DSL

Do not build a clever macro DSL for everything. This library should feel like Phoenix/Ecto/Plug: explicit modules, clear behaviours, generated defaults, easy overrides.

Recommended behaviours:

defmodule SupportOS.CustomerResolver do
  @callback resolve_customer(term(), map()) ::
              {:ok, SupportOS.Customer.t()} | :unknown | {:error, term()}
end
defmodule SupportOS.ContextProvider do
  @callback context_for(SupportOS.Conversation.t(), map()) ::
              {:ok, map()} | {:error, term()}
end
defmodule SupportOS.ChannelAdapter do
  @callback normalize_inbound(map()) ::
              {:ok, SupportOS.InboundMessage.t()} | {:error, term()}
  @callback deliver_reply(SupportOS.Message.t(), map()) ::
              {:ok, term()} | {:error, term()}
end
defmodule SupportOS.AutomationPolicy do
  @callback decide(SupportOS.AutomationProposal.t(), map()) ::
              :allow | :draft_only | :require_approval | :deny
end
defmodule SupportOS.Redactor do
  @callback redact(term(), map()) :: term()
end
defmodule SupportOS.Notifier do
  @callback notify(atom(), map()) :: :ok | {:error, term()}
end

This is more maintainable than trying to express every integration through config.

⸻

5. Telemetry is a public API

Use :telemetry heavily, but safely. The Telemetry docs are clear that handlers are invoked when events are executed, and handlers run in the process dispatching the event. That means expensive telemetry handlers can hurt the caller if you are not careful.  ￼

Emit events like:

[:support_os, :conversation, :opened]
[:support_os, :conversation, :resolved]
[:support_os, :message, :received]
[:support_os, :message, :sent]
[:support_os, :triage, :classified]
[:support_os, :ai, :draft, :started]
[:support_os, :ai, :draft, :stopped]
[:support_os, :ai, :answer, :accepted]
[:support_os, :ai, :answer, :rejected]
[:support_os, :kb, :search, :performed]
[:support_os, :kb, :gap, :detected]
[:support_os, :tool, :approval, :requested]
[:support_os, :tool, :executed]
[:support_os, :csat, :submitted]

Keep metrics labels low-cardinality. Put high-cardinality data like user IDs, conversation IDs, email addresses, raw paths, and message bodies into structured metadata or durable evidence, not metric labels. That aligns with Parapet’s label-safety posture.

⸻

The core domain language

Use language that support teams understand, but avoid importing all the baggage of enterprise ticketing.

Primary nouns

Noun	Meaning
Inbox	A configured support entrypoint: in-app, email, API, future Slack, etc.
Conversation	The durable customer support thread. Prefer this over “ticket” for user-facing UX.
Message	An inbound/outbound/internal note in a conversation.
Participant	Customer, operator, AI agent, system, integration.
Customer	The human/end-user. May map to host app user.
Account	B2B workspace/org/customer account. Optional but important.
Contact identity	Email/user ID/external channel identity mapped to a customer.
Intent	Classified reason for contact.
Topic	Product area or feature area.
Signal	Extracted product/customer insight from support.
Knowledge article	Published source-of-truth content.
Knowledge gap	Repeated unresolved/friction pattern not well-covered by current KB.
Macro	Reusable reply/action template.
Automation run	A specific AI/rules execution with inputs, outputs, decision, policy result.
Tool call	A proposed or executed external/domain action.
Handoff	Transition from AI/self-service to human/operator.
Resolution	Conversation outcome.
Feedback	CSAT/CES/article feedback/reply rating.

Core verbs

ingest
normalize
classify
route
assign
retrieve
draft
cite
approve
reply
escalate
resolve
reopen
summarize
redact
link
cluster
promote
publish
audit
evaluate
notify

Core events

conversation.opened
conversation.assigned
conversation.resolved
conversation.reopened
message.received
message.sent
message.redacted
triage.classified
triage.overridden
ai.draft.created
ai.answer.sent
ai.answer.blocked
ai.answer.escalated
tool.proposed
tool.approved
tool.denied
tool.executed
tool.failed
kb.article.created
kb.article.published
kb.article.updated
kb.gap.detected
feedback.csat_requested
feedback.csat_submitted
signal.cluster_created
signal.promoted_to_roadmap

This language gives you a stable conceptual map for docs, schemas, telemetry, UI, and AI prompts.

⸻

Automation architecture

The biggest design principle:

Automation is not binary. It is a ladder of trust.

Use explicit automation levels.

Level	Mode	What happens	Safe default?
0	Off	Store and route only	Yes
1	Draft-only	AI drafts replies/summaries, human sends	Best v0.1 default
2	Self-service	Widget shows sourced answer, user can still contact human	Good default
3	Auto-reply low-risk	AI replies only when sourced, low-risk, high-confidence	Later
4	Tool-assisted with approval	AI proposes action, human approves	Later
5	Tool-assisted automatic	AI executes narrow allowlisted actions	Rare
6	Autonomous agent	Broad multi-step agency	Avoid as product default

This avoids the “bot jail” anti-pattern where the user cannot reach a human and the AI keeps looping.

The policy gate

Every AI output should pass through a policy gate:

%SupportOS.AutomationProposal{
  conversation_id: "...",
  action: :send_reply,
  risk: :low,
  confidence: 0.86,
  sources: [%{article_id: "...", chunk_id: "..."}],
  customer_visible?: true,
  requires_tool?: false,
  contains_refund?: false,
  contains_legal_claim?: false,
  contains_security_claim?: false
}

Policy result:

:allow
:draft_only
:require_approval
:deny

The gate should consider:

* source coverage;
* retrieval confidence;
* intent risk;
* customer tier;
* sentiment/urgency;
* account status;
* whether the reply makes promises;
* whether billing/security/legal/account actions are involved;
* whether this intent has passed evals;
* whether the current incident state says automation should pause.

⸻

AI safety and governance

The library should assume prompt injection and over-agency are real risks. OWASP’s LLM Top 10 includes sensitive information disclosure, insecure plugin design, excessive agency, and overreliance. OWASP’s prompt-injection guidance also notes that RAG and fine-tuning do not fully mitigate prompt injection, and indirect prompt injection can occur through external content.  ￼

So the default AI design should be:

1. Grounded: answer only from retrieved, allowed sources.
2. Cited: every customer-visible factual answer has source references internally, and ideally visible citations in the UI/widget.
3. Scoped: the AI sees only the customer/account context needed for the task.
4. Redacted: PII/secrets are scrubbed before model calls where possible.
5. Policy-gated: all risky outputs require approval or are blocked.
6. Audited: every customer-visible AI action is recorded.
7. Evaluated: failures become test cases.
8. Reversible where possible: side effects should be idempotent and compensatable.

OpenAI’s eval guidance emphasizes eval-driven development, logging, automation, and avoiding vibe-based assessment for AI systems. That maps perfectly to Scoria’s “promote production failure to eval dataset” model.  ￼

⸻

Scoria integration should be first-class

This library is exactly the kind of AI-adjacent system that should emit OpenInference-compatible traces. OpenInference defines semantic conventions for LLM calls, agent reasoning, tool invocations, retrieval operations, and AI observability concepts such as token economics, agentic control flow, privacy sensitivity, and nondeterminism.  ￼

Every AI support run should produce a trace like:

SUPPORT_AUTOMATION_RUN
  ├─ GUARDRAIL: redact_input
  ├─ RETRIEVER: search_kb
  ├─ RERANKER: rerank_chunks
  ├─ LLM: classify_intent
  ├─ LLM: draft_reply
  ├─ GUARDRAIL: policy_gate
  ├─ TOOL: billing_lookup
  └─ DECISION: draft_only / auto_send / approval_required

Scoria should receive:

* prompt version;
* retrieved chunks;
* model;
* latency;
* token cost;
* policy decision;
* confidence signals;
* final action;
* human override;
* outcome feedback;
* promoted eval case if the result was bad.

That gives you a strong feedback loop:

flowchart LR
    A[Bad AI Reply / Failed Deflection] --> B[Operator Marks Failure]
    B --> C[Promote to Scoria Dataset]
    C --> D[Regression Eval]
    D --> E[Prompt / KB / Policy Fix]
    E --> F[Safer Automation]

⸻

MCP/tool-use integration

MCP is relevant, but should be treated as an advanced integration surface, not the core v0.1 abstraction. MCP lets applications expose context and tools through a JSON-RPC-based model of hosts, clients, and servers. Its spec also emphasizes user consent, data privacy, tool safety, and human authorization.  ￼

The key is not “give the AI tools.” The key is:

Expose narrow, typed, auditable support tools with explicit risk levels.

Examples:

defmodule MyApp.SupportTools.Billing do
  use SupportOS.Tool
  tool :lookup_invoice,
    risk: :read_only,
    description: "Look up invoice status for the current authenticated account"
  tool :resend_invoice_email,
    risk: :low_write,
    requires_approval?: false
  tool :issue_refund,
    risk: :high_write,
    requires_approval?: true
end

Good support tools:

* are narrow;
* have typed inputs;
* validate authorization server-side;
* are idempotent when possible;
* return compact structured data;
* redact secrets;
* log to Threadline;
* emit Scoria tool spans;
* have timeouts;
* never trust model-provided identity or authorization.

Anthropic’s tool-use guidance is directionally aligned here: agents are only as effective as their tools, and tools should be intentionally selected, clearly namespaced, token-efficient, and return meaningful context.  ￼

⸻

Parapet integration: support quality is a reliability signal

Support should be treated as a customer-harm signal, not merely an inbox.

Parapet can consume support SLIs such as:

SLI	Meaning
First response time	How quickly customers get an initial answer.
Human handoff latency	How long escalated conversations wait.
Resolution time	Time from open to resolved.
Reopen rate	Quality/reliability of resolution.
AI escalation rate	How often automation cannot answer.
AI rejection rate	How often humans reject drafts.
Deflection success rate	Self-service answers that avoid contact and receive positive feedback.
CSAT	Customer satisfaction after resolution.
CES	Customer effort score.
Backlog age	Oldest unresolved support item.
Incident-linked support surge	Spike in support conversations related to a failing feature.

Zendesk’s metric docs define common support metrics such as average resolution time, first reply time, first contact resolution, CSAT, and customer effort score.  ￼

Support SLIs can become Parapet SLOs:

Parapet.SLO.define :support_first_response do
  description "Customers receive first support response quickly"
  objective 99.0
  window :rolling_30d
  good_events [:support_os, :conversation, :first_response_within_target]
  total_events [:support_os, :conversation, :opened]
end

The interesting part is correlation:

* deploy happens;
* errors increase;
* support conversations about “export failed” spike;
* CSAT drops;
* AI escalation rate increases;
* Parapet links the customer-harm evidence to the deploy window.

That is operator-grade support automation.

⸻

Integration map for your ecosystem

Library	Integration
Sigra	Authenticate dashboard users, attach actor_id, permission gates for support actions. Sigra currently positions itself as Phoenix 1.8+/Ecto auth with host-owned generated auth, Argon2id, TOTP, passkeys, encryption, audit, and optional deps.  ￼
Scoria	Trace AI classification, retrieval, drafting, guardrails, tool calls, evals, costs, and failures.
Parapet	Support SLIs/SLOs, customer-harm signals, incident correlation, support-surge alerts.
Threadline	Audit human approvals, AI replies, policy changes, tool calls, article publication, redactions.
Chimeway	Notify operator of VIP escalations, approval requests, CSAT drops, old backlog, support surges. Chimeway is already described as a durable notification library for Elixir.  ￼
Mailglass	Outbound support email delivery.
MailglassInbound	Inbound email parsing and support conversation ingestion.
Accrue	Billing context, invoice lookup, subscription status, refund/cancel workflows with approval. Accrue is positioned around Phoenix-era billing state, subscriptions, invoices, checkout, webhooks, and a Stripe-shaped surface.  ￼
Scrypath	Search/indexing for KB, conversations, traces, macros, and signal clusters.
Rulestead	Feature/config flags; correlate support spikes with flag changes; pause automation through config.

Important OSS design point:

These integrations should be optional adapters, not hard dependencies.

Your package should work standalone with Phoenix/Ecto. Then it should become dramatically better when the user also has Sigra, Scoria, Parapet, Threadline, Chimeway, Mailglass, and Accrue.

⸻

Recommended package layering

support_os
├── SupportOS
│   ├── Conversations
│   ├── Messages
│   ├── Inboxes
│   ├── Knowledge
│   ├── Triage
│   ├── Automation
│   ├── Signals
│   ├── Feedback
│   ├── Policies
│   ├── Telemetry
│   └── Integrations
│
├── SupportOS.Web
│   ├── Router
│   ├── DashboardLive
│   ├── ConversationLive
│   ├── KnowledgeLive
│   ├── SignalLive
│   └── WidgetLive
│
├── SupportOS.Adapters
│   ├── Email
│   ├── InApp
│   ├── API
│   └── Test
│
├── SupportOS.AI
│   ├── Classifier
│   ├── Retriever
│   ├── Drafter
│   ├── Guardrails
│   ├── Evaluator
│   └── Costing
│
└── SupportOS.Integrations
    ├── Sigra
    ├── Scoria
    ├── Parapet
    ├── Threadline
    ├── Chimeway
    ├── Mailglass
    ├── Accrue
    └── Scrypath

Avoid separate packages too early. Start as one package with optional modules. Split integrations later only if dependency pressure becomes painful.

⸻

Data model recommendation

The schema should be normalized enough to support serious workflows, but not so abstract that v1 becomes impossible.

erDiagram
    INBOX ||--o{ CONVERSATION : receives
    CONVERSATION ||--o{ MESSAGE : has
    CONVERSATION ||--o{ ASSIGNMENT : has
    CONVERSATION ||--o{ AUTOMATION_RUN : has
    CONVERSATION ||--o{ FEEDBACK_EVENT : has
    CONVERSATION }o--o{ TAG : tagged
    CONVERSATION }o--o{ INTENT : classified
    CUSTOMER ||--o{ CONTACT_IDENTITY : has
    CUSTOMER ||--o{ CONVERSATION : starts
    ACCOUNT ||--o{ CUSTOMER : contains
    ACCOUNT ||--o{ CONVERSATION : owns
    KB_SPACE ||--o{ KB_ARTICLE : contains
    KB_ARTICLE ||--o{ KB_ARTICLE_VERSION : has
    KB_ARTICLE_VERSION ||--o{ KB_CHUNK : indexed
    AUTOMATION_RUN ||--o{ AI_TURN : has
    AUTOMATION_RUN ||--o{ TOOL_CALL : proposes
    KB_CHUNK ||--o{ AI_TURN : cited_by
    SIGNAL_CLUSTER ||--o{ CONVERSATION : references
    SIGNAL_CLUSTER ||--o{ KB_ARTICLE : suggests

Tables

support_inboxes
support_customers
support_accounts
support_contact_identities
support_conversations
support_messages
support_participants
support_assignments
support_tags
support_conversation_tags
support_intents
support_conversation_intents
support_automation_runs
support_ai_turns
support_tool_calls
support_kb_spaces
support_kb_articles
support_kb_article_versions
support_kb_chunks
support_kb_search_events
support_feedback_events
support_signal_clusters
support_signal_cluster_items
support_idempotency_keys

Conversation state

Use a small, understandable state machine:

new
open
waiting_on_customer
waiting_on_operator
waiting_on_approval
resolved
closed
spam

Separate “state” from “intent.” A billing issue can be open; a bug report can be waiting_on_operator.

Message types

customer_message
operator_reply
internal_note
ai_draft
ai_reply
system_event
tool_result
email_event

Important: an ai_draft is not the same as an ai_reply. Drafts are internal. Replies are customer-visible.

⸻

Knowledge base design

The KB is the automation substrate, so it needs more structure than a markdown blob.

Article fields

id
space_id
slug
title
status: draft | published | archived
audience: public | authenticated | internal
product_area
language
created_by_id
published_by_id
published_at

Article version fields

article_id
version
body_markdown
body_html
summary
source_refs
embedding_status
published_at
superseded_at

Chunk fields

article_version_id
chunk_index
text
embedding
token_count
metadata

The AI should retrieve against published article versions, not mutable drafts. When an article changes, create a new version and reindex.

Knowledge gap detection

Create gaps from:

* repeated intents with no article;
* KB searches with no click;
* AI retrieval failures;
* conversations resolved with long manual replies;
* repeated internal notes/macros;
* low CSAT after AI answer;
* operator “mark as gap” action.

Gap object:

%SupportOS.SignalCluster{
  kind: :knowledge_gap,
  title: "Users do not understand invoice export permissions",
  count: 17,
  first_seen_at: ~U[...],
  last_seen_at: ~U[...],
  suggested_article_title: "Who can export invoices?",
  severity: :medium,
  linked_conversations: [...]
}

⸻

AI/RAG pipeline

Recommended support-answer pipeline:

flowchart TD
    A[Inbound message] --> B[Redact + normalize]
    B --> C[Classify intent / urgency / language]
    C --> D[Resolve customer/account context]
    D --> E[Retrieve KB + relevant app context]
    E --> F[Rerank / filter by permissions]
    F --> G{Enough grounded evidence?}
    G -->|No| H[Escalate / ask clarifying question]
    G -->|Yes| I[Draft answer with citations]
    I --> J[Guardrail checks]
    J --> K[Automation policy gate]
    K -->|allow| L[Send answer]
    K -->|draft only| M[Human review]
    K -->|approval| N[Approval workflow]
    K -->|deny| H

Do not depend on one giant prompt. Use small, inspectable steps:

1. classify;
2. retrieve;
3. draft;
4. check;
5. decide;
6. send/escalate.

This is easier to debug, test, evaluate, and trace.

⸻

Cost-control strategy

AI support can get expensive if every message triggers multiple LLM calls. Keep costs down by making automation layered.

Cheap first

Use deterministic/rules-based logic for:

* obvious spam;
* exact-match help-center search;
* known intents;
* routing;
* macro suggestions;
* status-page links;
* account plan lookups;
* known incident banners.

Use small models for

* intent classification;
* sentiment;
* language detection;
* summary;
* tag suggestions.

Use larger models only for

* nuanced reply drafting;
* article drafting;
* complex multi-source synthesis;
* support signal clustering;
* tool-use planning.

Cache aggressively

Cache:

* embeddings;
* article chunks;
* common FAQ answers;
* classification for repeated messages;
* generated summaries;
* conversation-level context packs.

Put budgets in config

config :support_os, :ai,
  monthly_budget_usd: 50,
  per_conversation_budget_cents: 20,
  default_mode: :draft_only,
  auto_reply_max_risk: :low,
  disable_auto_reply_when_budget_exceeded?: true

Expose in dashboard:

* cost per conversation;
* cost per resolved issue;
* cost per deflection;
* top expensive intents;
* token usage by model;
* auto-reply ROI.

⸻

Operator UX

The dashboard should not feel like generic CRUD. It should feel like an operator cockpit.

Main inbox layout

┌──────────────────────┬────────────────────────────┬──────────────────────┐
│ Queue                │ Conversation               │ Context / AI         │
│                      │                            │                      │
│ New                  │ Customer messages          │ Customer/account      │
│ Waiting on me        │ Operator replies           │ Billing/auth/status   │
│ Waiting approval     │ Internal notes             │ AI draft              │
│ VIP / high risk      │ Timeline                   │ Sources used          │
│ Bugs                 │                            │ Policy decision       │
│ Billing              │ Reply composer             │ Suggested actions     │
└──────────────────────┴────────────────────────────┴──────────────────────┘

AI panel must show “why”

For every draft or auto-answer:

AI Draft
Confidence: High
Policy: Draft-only because billing topic
Sources:
  - "Refund policy", version 4
  - "Invoice export permissions", version 2
Context used:
  - Account plan: Pro
  - Last invoice: paid
  - Feature flag: invoice_export_v2 enabled
Suggested action:
  - Resend invoice email
  - Requires approval: no

Never make the operator guess why the AI said something.

Handoff UX

When AI cannot solve the issue:

I’m going to send this to support with the context you already provided.

For the operator, automatically generate:

* summary;
* user goal;
* attempted answers;
* sources shown;
* current page/path;
* account/customer facts;
* suspected intent;
* risk flags.

This is what prevents bot experiences from feeling hostile.

⸻

End-user widget UX

The widget should not look like “chatbot jail.” It should have three obvious paths:

1. Search/ask docs.
2. Contact support.
3. View existing conversations.

Recommended default widget modes:

:contact_first
:self_service_first
:ai_first
:disabled

For B2B/B2C SaaS, I would default to self-service first, but with visible human contact.

Bad UX:

Bot: I don't understand.
Bot: Try rephrasing.
Bot: I don't understand.

Good UX:

I found two possible answers. If neither helps, I can send this to support with your context attached.

⸻

Metrics that matter

Do not only track “automation rate.” A high automation rate can be bad if customers are frustrated.

Track a balanced scorecard:

Metric	Why it matters
First response time	Basic support responsiveness.
Resolution time	How long customers wait for real resolution.
First contact resolution	Whether the first answer actually solved it.
Reopen rate	Quality of resolution.
CSAT	Customer satisfaction.
CES	Customer effort.
AI draft acceptance rate	Whether AI helps operators.
AI auto-answer success rate	Whether self-service works.
Escalation rate	Where AI/KB fails.
Knowledge gap count	Where docs/product are weak.
Top contact reasons	Product roadmap input.
Support surge by product area	Reliability/product regression signal.
Cost per resolved conversation	Unit economics.

Gartner’s 2025 service/support AI survey identified agent enablement, low-effort self-service, operations-support automation, and agentic AI as valuable AI service/support use cases, which lines up with this balanced approach.  ￼

⸻

Roadmap

v0.1 — Embedded support inbox + AI drafts

Goal: make it useful without trusting automation.

Ship:

* Ecto schemas/migrations.
* Embedded LiveView dashboard.
* In-app widget.
* Email adapter skeleton.
* Conversation/message store.
* Assignment, tags, states.
* Internal notes.
* Basic KB articles.
* KB search.
* AI draft replies.
* Conversation summaries.
* Intent classification.
* Telemetry events.
* mix support_os.install.
* mix support_os.doctor.
* Scoria tracing for AI calls.
* Sigra-compatible dashboard auth hook.
* Chimeway notification hook for new/escalated conversations.

Default automation mode:

:draft_only

This is the right v0.1 because it provides immediate value while avoiding risky auto-replies.

⸻

v0.2 — Self-service answers + knowledge gaps

Goal: make support volume go down safely.

Ship:

* Widget AI answers from KB.
* Visible citations/sources.
* Confidence/policy gate.
* “Contact support” handoff.
* Search failure tracking.
* Repeated-question clustering.
* Suggested macros.
* Suggested article drafts.
* Article versioning.
* Article feedback.
* CSAT after resolution.
* Parapet support SLIs.
* Threadline audit for AI-visible customer replies.

Default automation mode:

:self_service

Still do not auto-send email replies by default.

⸻

v0.3 — Safe tools and billing/account context

Goal: automate repetitive support tasks.

Ship:

* Tool registry.
* Tool risk levels.
* Approval queue.
* Accrue billing context adapter.
* Read-only account diagnostics.
* Resend invoice/receipt tool.
* Refund/cancel tools requiring approval.
* Scoria tool spans.
* Threadline audit for tool approvals/executions.
* Chimeway approval notifications.

Automation policy:

read-only tools: allow for operator-visible context
low-risk write tools: allow by policy
high-risk tools: require approval

⸻

v0.4 — Customer signal/control plane

Goal: turn support into product intelligence.

Ship:

* Signal clusters.
* Roadmap candidate export.
* “Promote to issue” hooks.
* “Ask for testimonial” workflow after high-CSAT resolution.
* “We fixed this” lifecycle notification.
* Incident/support surge correlation.
* Product area health dashboard.
* Feature flag/deploy correlation via Parapet/Rulestead.

⸻

v1.0 — Polished OSS infrastructure

Goal: stable public API and serious adoption.

Ship:

* Stable telemetry contract.
* Stable adapter behaviours.
* Stable dashboard router API.
* Stable migration/versioning story.
* Security guide.
* AI safety guide.
* Adapter authoring docs.
* Example Phoenix app.
* CI matrix.
* Upgrade guide.
* Semantic versioning policy.
* Hex docs polished.

Hex/Mix are already the natural release path for Elixir packages, and Hex packages/docs become available through the normal Elixir dependency ecosystem once published.  ￼

⸻

CI/CD and release recommendations

For an OSS Phoenix library, CI should prove four things:

1. The core library compiles and tests.
2. The generated host app compiles and boots.
3. The dashboard mounts correctly.
4. The installer/generator remains stable.

Recommended GitHub Actions checks:

mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs
mix hex.audit
mix sobelow

Add integration checks:

mix support_os.install --dry-run
mix support_os.install --yes
mix ecto.create
mix ecto.migrate
mix test.integration

For release:

v0.1.x = rapid iteration, unstable internals
v0.2.x = adapter APIs settle
v0.3.x = AI/tool policy APIs settle
v0.4.x = signal/analytics APIs settle
v1.0.0 = stable public API, stable telemetry events

Treat these as semver-major breaking surfaces:

* telemetry event names;
* telemetry measurements/metadata;
* migration assumptions;
* public behaviours;
* router macro options;
* automation policy return values;
* adapter callbacks;
* public context APIs.

⸻

Biggest footguns to avoid

1. Bot jail

Never trap customers in a bot. Always provide escalation.

2. Unsourced AI answers

If the system cannot cite a trusted source, it should not confidently answer.

3. Overbuilding omnichannel

Adapters are good. Owning every channel is a trap.

4. Tool over-agency

The AI should not be able to refund, delete, cancel, change permissions, or disclose sensitive account data without explicit policy and audit.

5. Generic CRUD dashboard

Support is workflow-heavy. A generic admin UI will not feel good enough.

6. Weak audit trail

Every customer-visible AI action, operator action, policy change, article publication, and risky tool call needs an audit trail.

7. PII leakage through telemetry

Do not put raw user IDs, email addresses, conversation IDs, message bodies, or account names into metric labels.

8. One giant agent

Use pipelines and state machines, not a single all-powerful support agent prompt.

9. Making your ecosystem mandatory

Sigra/Scoria/Parapet/etc. should make the library excellent, but not required for the library to run.

10. Confusing customer support with marketing automation

Support-triggered lifecycle messages are useful. Full email marketing is a separate product.

⸻

The cohesive architecture decision

The cleanest recommendation is:

SupportOS is an Ecto-native, Phoenix-embedded support automation substrate.
It owns:
  - conversations
  - messages
  - support inbox
  - knowledge base
  - AI drafting
  - self-service answers
  - triage
  - safe automation policy
  - knowledge gaps
  - customer support signals
It integrates with:
  - Sigra for auth
  - Scoria for AI traces/evals/governance
  - Parapet for support SLOs and customer-harm signals
  - Threadline for audit/evidence
  - Chimeway for notifications
  - Mailglass/MailglassInbound for email
  - Accrue for billing context/actions
  - Scrypath for search/indexing
  - Rulestead for flags/config/deploy correlation
It refuses to own:
  - email deliverability infrastructure
  - full CRM
  - full product analytics
  - full marketing automation
  - phone/contact center
  - full social inbox
  - unrestricted autonomous support agents

That gives you a real OSS gap in the Elixir ecosystem: not “helpdesk clone,” but Phoenix-native support automation infrastructure.

⸻

The one-shot implementation north star

Build the library so that this is possible after installation:

# Router
support_dashboard "/support",
  repo: MyApp.Repo,
  otp_app: :my_app,
  on_mount: [{MyAppWeb.UserAuth, :ensure_admin}]
# Host app support context
defmodule MyApp.SupportContext do
  @behaviour SupportOS.ContextProvider
  def context_for(conversation, _opts) do
    user = MyApp.Accounts.get_user!(conversation.customer.external_id)
    account = MyApp.Accounts.get_account_for_user(user)
    {:ok,
     %{
       user: %{id: user.id, email: user.email, role: user.role},
       account: %{id: account.id, plan: account.plan},
       billing: MyApp.Billing.support_snapshot(account),
       feature_flags: MyApp.Flags.enabled_for(account)
     }}
  end
end
# Policy
defmodule MyApp.SupportPolicy do
  @behaviour SupportOS.AutomationPolicy
  def decide(%{action: :send_reply, risk: :low, sources: [_ | _], confidence: c}, _opts)
      when c >= 0.85 do
    :allow
  end
  def decide(%{requires_tool?: true, risk: risk}, _opts)
      when risk in [:medium, :high] do
    :require_approval
  end
  def decide(_, _opts), do: :draft_only
end

And the operator gets:

* inbox;
* KB;
* AI drafts;
* cited self-service;
* support metrics;
* approval queue;
* knowledge gaps;
* Scoria traces;
* Parapet SLOs;
* Threadline audit;
* Chimeway notifications.

That is the version that feels native to Phoenix, useful to solo operators, and differentiated from existing helpdesk products.