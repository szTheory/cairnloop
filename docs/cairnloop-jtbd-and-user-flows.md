# Cairnloop, From a Phoenix SaaS Builder's Perspective

Cairnloop is not "Zendesk, but in Elixir."

It is closer to an embedded support operations layer for Phoenix apps: a support inbox, a conversation workspace, a knowledge base, a retrieval system, a safe AI draft loop, SLA tracking, and host-controlled extension points for app-specific actions.

The most useful way to think about it is this:

> Cairnloop helps you keep support inside your monolith, close to your product data, and close to the operators who need to make judgment calls.

That is the good news.

The honest news is that Cairnloop is currently split between three maturity levels:

- Some parts are real and coherent already.
- Some parts are strong scaffolding with the intended flow visible.
- Some parts still stop one layer short of "I would trust this in production."

This memo maps the library from the point of view of a Phoenix SaaS engineer deciding what jobs it can do today, what user flows are genuinely built, and where the major gaps still are.

## The Core Job To Be Done

When I run a Phoenix SaaS app and want support to live inside my product, not in a disconnected external system, Cairnloop helps me:

- receive and organize support conversations,
- give operators customer context while they work the thread,
- search canonical guidance and past resolved cases,
- draft safe AI-assisted replies instead of freewheeling automation,
- capture support outcomes as reusable knowledge and operational signals,
- plug support actions back into my app through Elixir behaviors, telemetry, and LiveView surfaces.

That is the main job.

Everything else is a supporting job around that loop.

## What Cairnloop Already Does Well

The memorable version:

- It gives you a support cockpit inside Phoenix.
- It treats the knowledge base as the source of truth.
- It treats resolved cases as helpful evidence, not canon.
- It prefers "draft, clarify, or escalate" over "confidently hallucinate."
- It increasingly turns support work into better future retrieval.
- It expects your app to stay in charge of business actions.

If that philosophy matches how you build SaaS, a lot of Cairnloop already points in the right direction.

## JTBD And User Flows Built So Far

Each flow below is written from the library user's perspective, with a confidence label:

- `Real`: coherent enough that the main flow is genuinely present.
- `Partial`: the intended flow is implemented in meaningful pieces, but some important legs are thin.
- `Stubbed`: the shape exists, but the implementation still stops short of the promised experience.

### 1. Run an embedded support inbox inside my Phoenix app

**JTBD**

When I want support to live in my app, Cairnloop gives me an operator-facing dashboard instead of forcing me into an external support SaaS.

**Flow**

1. I mount the Cairnloop dashboard in my Phoenix router.
2. Operators land in an inbox of conversations.
3. They open a thread, work the conversation, inspect context, review drafts, and navigate adjacent support surfaces.

**What Cairnloop automates**

- Embedded LiveView routes for inbox, conversation view, knowledge base, and settings.
- A basic inbox listing and conversation workspace.
- A consistent dashboard shell with search available across the support UI.

**Confidence**

`Real`

This is one of the clearest parts of the library. The dashboard routing and core LiveView surfaces exist and hang together.

### 2. Work a support conversation while seeing app-specific customer context

**JTBD**

When an operator opens a conversation, I want them to see the account context that matters: plan, identity, status, or any other host-owned facts.

**Flow**

1. A conversation opens in the operator workspace.
2. Cairnloop asks the host app for customer context using a provider interface.
3. The UI renders that context in a normalized side rail.
4. If context is missing or unavailable, the operator still keeps working instead of being blocked.

**What Cairnloop automates**

- A host context provider seam.
- A conversation side rail that renders context safely.
- Graceful empty and error states instead of exploding the conversation view.

**Confidence**

`Real`

This flow is well-shaped and practical. It already behaves like a useful embedded support screen for Phoenix apps.

### 3. Search verified knowledge and similar prior cases without leaving the thread

**JTBD**

When an operator needs grounding fast, I want them to search both the official answer and "what happened last time" from the same workspace.

**Flow**

1. The operator opens the search palette.
2. They search one query across canonical knowledge base content and resolved cases.
3. Results are grouped by source type.
4. Knowledge-base hits are presented as truth; resolved cases are presented as assistive evidence.
5. The operator previews the evidence before navigating away.

**What Cairnloop automates**

- One retrieval surface over two corpora.
- Result ranking that prefers knowledge-base truth over anecdotal prior cases.
- A retrieval-backed search palette with keyboard navigation, preview, source/trust labels, and open destinations for both corpora.

**Confidence**

`Real`

This is one of the most product-legible parts of the library. The retrieval model has a strong opinion: canon first, similar cases second.

It also got materially more real. The search UI now runs through Cairnloop's own retrieval layer, presents fixed `Knowledge Base` and `Similar resolved cases` sections, and gives operators preview/open behavior without treating the search box like a thin placeholder.

### 4. Keep the knowledge base as the canonical source of support truth

**JTBD**

When I want support quality to improve over time, I need a built-in knowledge system rather than a pile of tribal operator memory.

**Flow**

1. An operator views knowledge-base articles.
2. They edit an article draft.
3. They preview Markdown while editing.
4. They publish a revision.
5. Publishing triggers chunking and indexing for retrieval.

**What Cairnloop automates**

- Article, revision, and chunk lifecycle.
- Draft-versus-published revision handling, including an immutable published boundary.
- Markdown preview during editing.
- Post-publish chunking/indexing hooks for retrieval, plus corpus rebuild/replay ergonomics.

**Confidence**

`Real`

This is a meaningful product surface, not a placeholder. The KB exists as a first-class concept, and retrieval is designed to treat it as canon.

The backing model is stronger now too: first-class articles, revisions, and retrieval chunks exist as durable records, publishing has a real immutability boundary, and indexing is clearly part of the product contract rather than an implied future step.

**What this naturally wants next**

This flow is the natural home for AI-assisted KB maintenance.

Not "let the bot write docs and hope."

More like:

1. repeated support failures expose a knowledge gap,
2. Cairnloop clusters the evidence,
3. the operator clicks `Draft article` or `Suggest revision`,
4. AI proposes a draft with support evidence attached,
5. the operator edits, approves, and publishes,
6. the KB gets stronger without weakening its canonical status.

That is not really a separate product. It is the next layer of the same job: keeping the KB trustworthy while making it easier to maintain.

That direction is now more concrete than hand-wavy. Cairnloop already records retrieval gaps, and the next KB-maintenance lane is explicitly specified. What is still missing is the operator-facing workflow itself.

### 5. Draft safe AI-assisted replies instead of letting AI answer blindly

**JTBD**

When a customer sends a message, I want AI to help my operator move faster without letting it improvise beyond verified support knowledge.

**Flow**

1. A new user message enters a conversation.
2. Cairnloop schedules draft generation asynchronously.
3. Retrieval gathers canonical and assistive evidence.
4. The draft engine assesses grounding strength.
5. Cairnloop produces one of three proposal shapes:
   - a reply,
   - a single clarifying question,
   - an escalation recommendation.
6. The operator sees the proposal with evidence attached.

**What Cairnloop automates**

- Async draft generation.
- Retrieval-grounded proposal construction.
- A safety posture that prefers clarification or escalation over bluffing.
- An explicit distinction between grounded truth and supporting prior examples.
- Structured grounding metadata, evidence snapshots, and clarification-attempt tracking on drafts.

**Confidence**

`Partial`

The important product logic is there. The system genuinely models `reply / clarification / escalation`, and that is a strong design choice.

It also has a sharper operational spine than before: weak grounding can now be recorded as a retrieval gap, and the draft object carries more explicit grounding/evidence state instead of just generic copy.

But the copy is still generic, the draft engine is intentionally mock-like, and the end-to-end reliability depends on adjacent flows that are not fully finished yet.

### 6. Keep a human in the loop for AI-generated support actions

**JTBD**

When AI proposes a customer response, I want the operator to stay in charge.

**Flow**

1. A draft appears in the conversation rail.
2. The operator reviews the summary, proposed reply, and evidence.
3. They approve and send it, apply it into the composer for editing, or discard it.
4. Those decisions are tracked as part of the draft lifecycle.

**What Cairnloop automates**

- Draft statuses such as pending, approved, discarded, and edited.
- A visible audit-style draft card in the conversation view, with structured review context instead of only plain reply text.
- Policy hooks that default to draft-only behavior.

**Confidence**

`Real`

This is one of the best-articulated user flows in the library. Cairnloop already knows what "safe AI" means operationally: not autonomy first, review first.

### 7. Allow host-defined actions directly inside support conversations

**JTBD**

When a conversation needs an app-specific action, I want operators to act from the support workspace instead of tabbing through admin surfaces.

**Flow**

1. The host app provides executable tools.
2. Cairnloop filters them based on actor and context.
3. Operators execute a simple action or fill in a small form.
4. The action runs through the host-defined tool implementation.

**What Cairnloop automates**

- Tool registration.
- Per-conversation filtering based on context and authorization.
- Basic generated UI for tool inputs, with an escape hatch for custom UI.

**Confidence**

`Partial`

The extension model is real and promising. For Phoenix SaaS apps, this may end up being one of the highest-leverage pieces.

What is still missing is the broader operational hardening around these tools: richer permissions, deeper auditability, and more opinionated host integration patterns.

### 8. Track support SLAs and expose support operations as telemetry

**JTBD**

When I need support to be run like an operational system, I want first-response and resolution timing to exist as actual system concepts.

**Flow**

1. A conversation receives a user message.
2. Cairnloop can create an active first-response SLA window.
3. An agent reply fulfills that SLA and starts a resolution SLA.
4. Resolution fulfills the active SLA and emits support lifecycle telemetry.
5. The host app can react with alerts, CRM sync, or downstream workflows.

**What Cairnloop automates**

- SLA records and countdown jobs.
- Resolution events.
- A notifier behavior for host-owned side effects.
- Telemetry for observability and domain reactions.

**Confidence**

`Real`

The lifecycle is real enough to count as a built user flow now. User replies can start first-response timing, agent replies can fulfill that window and begin resolution timing, resolution emits lifecycle telemetry, and notifier hooks exist for host-owned reactions.

What still feels in-progress is the operational depth around it: richer admin ergonomics, more configurable policy surfaces, and stronger day-2 reporting.

### 9. Turn resolved conversations into future retrieval evidence

**JTBD**

When support solves something once, I want the system to remember it usefully next time.

**Flow**

1. A conversation is resolved.
2. Cairnloop schedules indexing into the resolved-case corpus.
3. Later searches can surface that case as supporting evidence.
4. AI drafts can use it as assistive context without treating it as canonical truth.

**What Cairnloop automates**

- Resolved-case indexing hooks.
- Retrieval support for resolved-case evidence.
- A trust model that marks prior cases as assistive instead of authoritative.

**Confidence**

`Real`

The retrieval and ranking philosophy is strong, and the corpus-building loop is now concrete enough to treat as present. Resolution schedules indexing into a durable resolved-case evidence corpus, and later retrieval can surface those cases as assistive context.

This still wants more production-depth before you would call it battle-tested, but it no longer feels like a speculative flow.

### 10. Capture post-resolution customer sentiment in the support loop

**JTBD**

When a thread closes, I want lightweight customer feedback to become part of the support record.

**Flow**

1. A conversation is resolved.
2. Cairnloop injects a CSAT request into the conversation flow.
3. The customer can submit a rating.
4. The rating becomes part of the conversation state and telemetry stream.

**What Cairnloop automates**

- Resolution-time CSAT prompting.
- CSAT storage on the conversation.
- CSAT telemetry for downstream analysis.

**Confidence**

`Partial`

The primitives exist. The broader customer-facing experience around collection and analysis still feels early.

## The Most Natural Next JTBD Extension

If you asked me which next user flow feels most native to Cairnloop's current architecture, it is still this:

**When repeated support questions expose missing or stale guidance, help operators turn real support evidence into safe KB draft updates.**

That belongs under the existing KB/retrieval family, not as a totally separate AI product.

And this is no longer just architectural intuition. Cairnloop now has both the gap-capture primitives and a much more explicit product spec for the next step.

Why this fits:

- Cairnloop already treats the KB as canon.
- Cairnloop already records retrieval misses and weak grounding.
- Cairnloop already treats support work as something that should leave behind better knowledge.
- The existing publish flow already gives the system a canonical boundary.

The likely operator experience:

1. weak retrieval, repeated clarifications, or repeated manual handling create a gap signal,
2. operators see those gaps ranked by volume and impact,
3. they generate a draft article or draft revision from clustered support evidence,
4. they review the proposal with citations and diff context,
5. they publish through the normal KB revision flow,
6. retrieval gets better for the next customer.

The important design constraint is that AI should help maintain the KB, not silently redefine it.

What is still missing is the operator-facing product loop that turns those primitives into a durable review workflow.

So if you are thinking like a Phoenix SaaS builder, the memorable version is:

**Cairnloop should not become an AI writer. It should become a support-to-knowledge loop with a very good editor.**

## The Short, Honest Product Summary

If you want the memorable one-paragraph read:

Cairnloop already behaves like a Phoenix-native support workspace with a strong opinion about truth, safety, and host ownership. It can give operators an embedded inbox, a conversation rail with customer context, a searchable knowledge-plus-cases layer, and AI drafts that are designed to be reviewed instead of blindly sent. What it does not yet fully give you is a finished, production-complete support system from inbound customer event all the way through durable outbound operations.

## What Is Real Versus Aspirational

### Real enough to use and build around

- Embedded dashboard and operator surfaces
- Conversation workspace with host context
- Search palette over knowledge base plus resolved cases
- Knowledge-base revision and publish loop
- SLA lifecycle and notifications
- Resolved-case retrieval lifecycle
- Human-in-the-loop draft review flow
- Host extension seams through providers, behaviors, telemetry, and tools

### Real, but still clearly in-progress

- AI draft generation loop
- Customer feedback capture
- Tool execution as an in-thread operations model

### Still too thin to treat as production-complete

- End-to-end inbound message ingestion and persistence
- Full customer-facing widget/email support experience
- A unified, polished top-level public API
- Day-2 operational depth and admin ergonomics
- Production onboarding/documentation shape for external adopters

## Major Gaps In JTBD And User Flows

This is the part that matters if you want to use Cairnloop in real Phoenix SaaS apps.

These are not "bugs." These are the next big jobs the library still needs to do.

### Gap 1. "I want customer messages to reliably become conversations and messages"

Right now Cairnloop clearly wants to support widget and email ingress, but the deepest persistence path is not fully complete.

What is missing:

- a fully durable inbound pipeline,
- clear message-to-conversation creation rules,
- production-grade identity/threading rules,
- stronger ingress verification and operational observability.

Why it matters:

Without this, the most important support promise, "customers contact us and the thread exists cleanly," still depends on unfinished plumbing.

### Gap 2. "I want a complete operator loop from inbound issue to outbound resolution"

The middle of the product is stronger than the edges.

What is missing:

- clearer outbound reply delivery integration,
- richer conversation state transitions,
- better thread lifecycle ergonomics,
- stronger real-time refresh and queue-management behavior.

Why it matters:

Today Cairnloop feels more complete as a support workspace substrate than as a fully closed-loop support desk.

### Gap 3. "I want customer-facing support channels, not just operator-facing internals"

There is a widget shape. There is email ingress shape. There is CSAT shape.

But a polished customer journey is not yet the star of the system.

What is missing:

- a stronger customer widget experience,
- clearer multi-turn conversation behavior from the customer side,
- more complete email threading/egress expectations,
- a better end-user resolution and feedback loop.

Why it matters:

If you are embedding this into a SaaS app, your users experience the support system from the outside first, not from the operator dashboard inward.

### Gap 4. "I want AI support automation I can trust in production"

Cairnloop has the right instinct here. The safety model is better than the average "AI support copilot" story.

What is missing:

- a real model/runtime integration story beyond the mock-shaped engine,
- better grounding quality controls,
- stronger audit and evaluation loops,
- clearer approval semantics when actions go beyond drafting text.
- an operator-facing KB-maintenance workflow on top of the new gap-capture signals.

Why it matters:

The current design is good. The production trust story still wants another layer of hardening.

The picture here is better than it was. Cairnloop now records retrieval gaps and weak-grounding conditions more explicitly, which is the right substrate for safer automation and future KB maintenance.

That same warning still applies to KB maintenance, though. The right first step is draft-first, citation-backed, operator-reviewed KB assistance rather than autonomous publishing, and that lane is specified more clearly than it is implemented.

### Gap 5. "I want this to feel like a coherent library, not a promising cluster of surfaces"

Today the practical API is spread across multiple modules, behaviors, tasks, and LiveView surfaces.

What is missing:

- a tighter top-level narrative for adopters,
- clearer "start here" integration flow,
- stronger install/generator cohesion,
- a more obvious public API contract.

Why it matters:

For a senior Phoenix engineer, this is survivable. For broader adoption, it is friction.

### Gap 6. "I want support operations, not just support screens"

Support as a product needs day-2 muscle.

What is missing:

- triage and queue management,
- assignment/escalation workflows,
- analytics and reporting,
- replay/recovery ergonomics,
- operational dashboards for failures, backlog, and SLA risk.

Why it matters:

Cairnloop already understands support as an operational loop. It now needs more of the operator machinery that makes the loop durable.

## What I Would Use It For Today

If I were embedding Cairnloop into a Phoenix SaaS app right now, I would treat it as:

- a strong embedded support workspace foundation,
- a real knowledge-and-retrieval layer,
- a promising human-in-the-loop AI support copilot,
- an app-native extension surface for support actions,
- an opinionated internal support subsystem I would continue shaping.

I would not yet treat it as:

- a fully turnkey support desk,
- a production-finished inbound/outbound messaging platform,
- a completely baked AI support automation product.

## The Memorable Bottom Line

Cairnloop already knows what kind of company it wants to be.

It wants support to stay close to the product.
It wants the knowledge base to outrank vibes.
It wants AI to assist operators, not cosplay certainty.
It wants your Phoenix app to remain the source of business truth.

That is a strong thesis.

What has been built so far proves the thesis in the middle of the loop: operator workspace, context, knowledge, retrieval, and draft review.

What still needs work is the outer ring: hardened ingress, polished customer channels, production-depth operations, and a cleaner adoption story.

So from a library user's perspective, Cairnloop today is best understood as an embedded Phoenix support operating layer with a surprisingly coherent brain, a usable operator cockpit, and a still unfinished circulatory system.
