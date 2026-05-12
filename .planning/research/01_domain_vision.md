# Domain Vision: Cairnloop (Cairnloop)

## Core Concept
Cairnloop is a Phoenix-native, embedded customer support automation layer. It is built for solo SaaS operators and small engineering teams running Phoenix apps. It rejects the "standalone helpdesk clone" model in favor of an Ecto-native, host-owned substrate that lives *inside* the application.

## The "SaaS in a Box" DNA
Cairnloop adheres to the szTheory unix-philosophy:
* **Host-Owned**: Uses `Igniter` to inject Ecto migrations, boilerplate, and routing directly into the host app.
* **Embedded Context**: It natively understands the user's billing state (via Accrue), identity (via Sigra), and domain context without relying on brittle API syncing.
* **Operator-First DX**: Provides an embedded LiveView dashboard and CLI diagnostics (`mix cairnloop.doctor`).

## The Core Support-to-Knowledge Loop
The primary value proposition is deflecting what can be deflected, drafting answers for what cannot, and turning recurring issues into durable knowledge. 
* Ingress -> Triage -> KB Retrieval -> AI Draft -> Human Approval / Auto-Reply -> KB Gap Detection.

## Expansion: Customer Voice Activation (Customer-Led Growth)
Support is a critical touchpoint in the customer lifecycle. While Cairnloop is fundamentally a support library, its embedded nature allows it to act as the trigger for "Customer Voice Activation" or Customer-Led Growth (CLG).

When a support issue is successfully resolved, Cairnloop is uniquely positioned to:
1. **Identify Happy Users**: Detect when a frustrated user is converted into a satisfied user via rapid resolution.
2. **Trigger Growth Asks**: Emit telemetry or webhooks that tell the host app to prompt the user for an App Store review, a testimonial, or a referral *at the exact moment of high satisfaction*.
3. **Capture Private Recovery**: Intercept detractors before they leave a public negative review by routing them into a high-priority triage queue.

Cairnloop won't build a full referral engine, but its **Intent and Sentiment Classification** must be robust enough to serve as the *trigger* for the host application's growth layers.