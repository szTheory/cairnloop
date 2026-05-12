# Milestone 002 Summary: AI Triage, Drafting, & Governance

## Overview
Milestone 002 focused on integrating the **Scoria** AI governance library into Cairnloop. This integration powers asynchronous, safe, and observable AI drafting capabilities. By delegating LLM execution to Scoria, we successfully enforce a strict Human-in-the-Loop (HITL) policy gate, prioritizing support operator efficiency without risking hallucination sprawl.

## Achievements
- **AI Drafting Data & UI Seams (S01):** Implemented distinctly styled "Pending AI Draft" UI elements in the `ConversationLive` dashboard, featuring state management for "Approve & Send", "Edit", and "Discard" actions.
- **Oban Async Drafting Pipeline (S02):** Established an Oban worker (`DraftWorker`) to handle AI execution completely asynchronously, avoiding any blocking of Phoenix request cycles. Added Phoenix.PubSub broadcasting to ensure immediate UI updates upon draft creation.
- **Scoria Governance Integration (S03):** 
  - Integrated `ScoriaEngine` to handle the actual LLM generation.
  - Enforced `Cairnloop.AutomationPolicy` behavior, giving host developers granular control over draft policies (allow, deny, draft-only, require_approval).
  - Emitted `OpenInference` semantic telemetry to ensure drafting and execution stages are deeply observable.

## Verification
- Codebase formatting is perfectly clean (`mix format --check-formatted`).
- Zero compilation warnings are present (`mix compile --warnings-as-errors`).
- All tests pass, including the Oban worker execution, LiveView updates, and stateful database mutations (`mix test`).
- Verified architectural constraints, proving that the solution correctly leverages Ecto Multi for database operations, and uses `:telemetry` spans conforming to OpenInference standards.

## Next Steps
We are now ready to tackle **Epic 3: Deep Context Enrichment**, aiming to bind the support ticket natively to the host's billing and identity systems utilizing Elixir behaviours and protocols.
