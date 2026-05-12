# Cairnloop: Research Synthesis

## The Vision
Cairnloop (Cairnloop) is an embedded, Ecto-native customer support automation library for Phoenix.

## Core Value Loop
1. **Ingress**: Capture support requests (Web Widget, Email).
2. **Context Enrichment**: Natively access host data (billing, identity).
3. **AI Triage & Drafting**: Classify intent, retrieve KB context, and draft a response.
4. **Policy Gate**: Rely on `AutomationPolicy` to determine if AI can auto-reply or needs human review.
5. **Growth Activation**: Emit telemetry upon successful resolution to trigger "Customer Voice Activation" (reviews, referrals) in the host app.

## Milestone 0 Focus
Establish the durable Ecto layer, the Igniter installation pipeline, and the core Ingress -> Dashboard loop.