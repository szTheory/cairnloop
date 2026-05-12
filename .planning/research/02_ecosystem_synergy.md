# Ecosystem Synergy: Cairnloop Integration Opportunities

## The szTheory Stack
Cairnloop is designed to create ecosystem leverage by integrating with the szTheory suite:
* **Parapet (SRE)**: Consume Cairnloop's SLIs for SLO alerting.
* **Scoria (AI Governance)**: Handle AI traces, evaluations, and HITL tool approvals.
* **Sigra (Auth)**: Protect the LiveView dashboard and provide the authenticated `actor_id`.
* **Threadline (Audit)**: Log critical support actions (e.g., human approval of an AI draft) for durable auditing.
* **Chimeway & Mailglass**: Handle asynchronous operator notifications and inbound/outbound email parsing.
* **Accrue & Rindle**: Provide billing and media context to support conversations.

## Extensibility Contracts
Cairnloop relies on explicit Elixir behaviours (`Cairnloop.ContextProvider`, `Cairnloop.ChannelAdapter`, `Cairnloop.Notifier`) to allow the host app to stitch these libraries together seamlessly.