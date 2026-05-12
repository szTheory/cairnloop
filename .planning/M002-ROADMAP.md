# Milestone M002: AI Triage, Drafting, & Governance

## Vision
Integrate the Scoria AI governance library into Cairnloop to provide asynchronous, safe, and observable AI drafting capabilities. Cairnloop remains the UI and orchestrator, delegating LLM execution to Scoria to enforce a strict Human-in-the-Loop (HITL) PolicyGate, preventing hallucination sprawl while maximizing operator efficiency.

## Slices

- [x] **S01: AI Drafting Data & UI Seams** `risk:medium` `depends:[]`
  > After this: An operator can see distinctly styled "Pending AI Draft" messages in the LiveView dashboard, complete with citations, confidence scores, and "Approve & Send" / "Edit" / "Discard" affordances.

- [x] **S02: Oban Async Drafting Pipeline** `risk:high` `depends:[S01]`
  > After this: A debounced Oban pipeline connects real multi-channel ingress to an async worker that automatically inserts a mock "Pending AI Draft" into the conversation, instantly updating the UI via Phoenix.PubSub.

- [x] **S03: Scoria Governance Integration** `risk:high` `depends:[S02]`
  > After this: The mock AI payload is replaced with real Scoria execution. The Oban worker emits OpenInference telemetry and enforces the `Cairnloop.AutomationPolicy` behaviour before yielding a draft for human review.
  **Plans:** 2 plans
  - [x] M002-S03-01-PLAN.md — Establish the foundational AI policy boundaries and Scoria engine interface
  - [x] M002-S03-02-PLAN.md — Update DraftWorker with Scoria, OpenInference telemetry, and policy enforcement

## Success Criteria
- **Safety:** No AI-generated message can be sent directly to the customer without explicit human approval (HITL).
- **Latency:** LLM API execution must be fully asynchronous (Oban) and never block Phoenix request cycles or WebSocket processes.
- **Ergonomics:** The host developer can easily override the default AI policy via a behaviour, while the UI cleanly differentiates AI vs Human messages.

## Horizontal Checklist
- [ ] Schema changes follow append-only conventions.
- [ ] Oban workers include retry logic.
- [ ] LiveView updates efficiently utilizing `stream/3`.