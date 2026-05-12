# Epic Idea: Support-Triggered Outbound Lifecycle & Rescue Campaigns

**Domain:** Customer Support Automation (Cairnloop)
**Context:** Triggering proactive, support-related outbound campaigns (e.g. incident recovery, bug-fix notifications) without turning the library into a generic marketing CRM.

## 1. The Core Vision & Philosophy

**"Confusing customer support with marketing automation is a footgun."**

Cairnloop is a Phoenix-native, embedded support automation layer. Its mandate is to resolve customer friction, not to nurture leads. However, proactive support is the highest form of customer service. When a known bug is fixed, or an incident is resolved, or a user gets stuck in an onboarding flow, the support system should proactively reach out. 

The goal is to build **Support-Native Transactional Outbound**—highly contextual, strictly scoped, and operator-approved messages—while explicitly avoiding building a full Marketing Automation Platform (MAP) like Customer.io or Braze.

## 2. Lessons Learned from the Ecosystem

### Intercom (The Anti-Pattern)
Intercom started as a simple widget and evolved into a massive platform with "Series" (a visual campaign builder). 
* **What went wrong:** Support and marketing teams began colliding. A user would receive a support "How are you doing?" message at the exact same time as a marketing "New Feature Announcement." It bloated the product and degraded the end-user UX through message fatigue.

### Zendesk (The Footgun)
Zendesk uses a rigid "Triggers and Automations" system.
* **What went wrong:** It's notoriously easy to create infinite email loops (two out-of-office bots replying to each other) or blast users with uncontextual "Ticket Updated" spam. The UI is overly complex for simple lifecycle needs.

### Plain / Pylon (The Modern Standard)
These API-first platforms treat support outbound as high-priority, contextual events. 
* **What went right:** They scope outbound support strictly to ticket resolution, known issue recovery, and API-triggered events. They don't try to build visual drip campaigns; they rely on the host's CDP/MAP for marketing, keeping support messages explicitly "transactional."

## 3. Architectural Tradeoffs & Approaches

### Approach A: The Full Visual Campaign Builder (Reject)
* **Concept:** Building a drag-and-drop UI for time-delayed email drips inside Cairnloop.
* **Why not:** Requires massive state management, frequency capping, subscription management (CAN-SPAM/GDPR), and A/B testing. This violates the "SaaS in a Box" DNA and turns Cairnloop into a bloated CRM.

### Approach B: CDP-First / Event Producer (The Global Standard)
* **Concept:** Cairnloop merely fires `:telemetry` events (e.g., `[:cairnloop, :conversation, :resolved, :bug]`). The host app pipes these to Segment/Customer.io to handle the actual email sending.
* **Pros:** Perfect global frequency capping. Marketing and Support don't collide.
* **Cons:** Forces solo SaaS operators to pay for and integrate a third-party CDP/MAP just to send a "We fixed your bug" email. This breaks the "embedded" value proposition.

### Approach C: Ecto-Native Scheduled Outbound (The Cairnloop Recommendation)
* **Concept:** Cairnloop uses **Oban** to schedule specific, highly contextual outbound support actions. Delivery is abstracted through **Chimeway** (for routing) and **Mailglass** (for email). 
* **Pros:** Leverages idiomatic Elixir. Keeps data in the host DB. No third-party dependencies. Keeps outbound strictly scoped to support events.

## 4. Idiomatic Elixir / Phoenix Architecture

To achieve Approach C, we rely on the established "SaaS in a Box" primitives:

1. **Oban for Scheduling:** 
   When a bug is fixed, or a conversation is marked for "Follow Up", we insert an Oban job:
   ```elixir
   %{conversation_id: id, template: :bug_fixed, context: %{version: "1.2"}}
   |> Cairnloop.Workers.DeliverLifecycleMessage.new(schedule_in: {2, :hours})
   |> Oban.insert()
   ```
2. **Chimeway & Mailglass for Delivery:**
   Cairnloop doesn't reinvent email delivery. It defines a `Cairnloop.Notifier` behaviour. The host app wires this up to Mailglass (for rendering transaction templates) and Chimeway (for actual delivery, potentially routing to email or in-app widget based on user preference).
3. **Ecto Multi & Append-Only State:**
   Outbound lifecycle messages are treated as `SupportOS.Message` records with a specific `system_outbound` type. They are appended to the conversation history, ensuring the operator has full context if the user replies.
4. **Scoria Policy Gates:**
   If AI is used to draft the mass "Bug Fixed" email, it must pass through the `SupportOS.AutomationPolicy` gate (e.g., `:require_approval` for mass outbound).

## 5. Feature Breakdown

### Table Stakes
* **Transactional Follow-ups:** "Did this fix your issue?" sent 48 hours after a ticket is soft-closed.
* **Idempotency & Safety:** Strict limits preventing a user from receiving the same lifecycle message twice (managed via Ecto unique indexes on an `outbound_deliveries` table).
* **Operator Visibility:** The outbound message appears natively in the LiveView conversation timeline.

### Differentiators
* **Bulk Incident Recovery (Macro Outbound):** An operator selects a "Tag" (e.g., `bug:export-fails`), types a single resolution message, and Cairnloop fans out the message to all 50 linked conversations, reopening them gently to ensure satisfaction.
* **Support-Signal Onboarding Rescue:** If a user opens 3 tickets in their first 7 days, trigger an Oban job to send an "Onboarding Rescue" check-in from the founder. 
* **AI-Drafted Recovery:** Using the host context (via `ContextProvider`), the AI drafts a personalized "We fixed this" message referencing the user's specific workspace data, but queues it for one-click operator approval.

### Anti-Features (Do Not Build)
* **Visual drip-campaign builder.**
* **Marketing unsubscribes** (These are transactional support messages, though basic opt-out of "check-ins" should be respected via the host's user preferences).
* **Open/Click Tracking analytics** (Leave this to Mailglass or the MAP).

## 6. UX/DX Ergonomics

**Developer Experience (DX):**
Developers don't need to configure complex webhooks. They simply implement the `Cairnloop.Notifier` behaviour and ensure Oban is running. Cairnloop provides Mix tasks (`mix cairnloop.gen.lifecycle_template`) to scaffold Mailglass templates in the host app.

**Operator UX:**
In the Cairnloop LiveView Dashboard, operators see a "Pending Outbound" queue. If a mass incident recovery is triggered, the operator sees:
> "Drafted 42 resolution messages for tag `incident:db-down`. [Review & Send All]"
The UI clearly differentiates between normal operator replies and system-scheduled outbound check-ins using the established Cairnloop design tokens.

## 7. The One-Shot Recommendation

Build a **"Targeted Broadcast & Scheduled Check-in"** engine backed by Ecto and Oban, rather than a continuous lifecycle engine. 

Keep it tightly coupled to the `Conversation` and `Tag` schemas. If an outbound message does not directly relate to an existing support conversation, a known knowledge-gap, or a specific product incident, it belongs in the marketing tool, not Cairnloop.