# Research: AI Tool Governance & MCP Integration for Cairnloop

**Project:** Cairnloop
**Domain:** Customer Support Automation Layer (Phoenix-native)
**Researched:** Current Year
**Overall Confidence:** HIGH (Based on szTheory ecosystem context, Elixir idiomatic patterns, and competitor analysis)

## Executive Summary

Cairnloop aims to provide AI drafting and intent classification using Scoria as its AI Application Quality Layer. The most critical risk in AI customer support is "runaway agency"—where an LLM hallucinates and executes destructive actions (e.g., unauthorized refunds, data deletion). To prevent this, Cairnloop requires a robust, async-first architectural pattern for exposing Model Context Protocol (MCP) tools with explicit risk tiers, coupled with a frictionless Human-in-the-Loop (HITL) approval UI in LiveView.

The recommended architecture relies on an **Asynchronous State Machine via Oban + Ecto**, treating the LLM as a stateless function. When a high-risk tool is invoked, execution halts, state is persisted to the database, and the operator is prompted via Phoenix LiveView to approve the payload.

## Competitor Ecosystem: Lessons Learned

| Platform | Approach | Key Takeaways & Footguns |
|----------|----------|--------------------------|
| **Pylon** | "Runbooks" for B2B. Human review step before sending. | **Do:** Implement strict domain guardrails (e.g., limit refund $ amounts). **Don't:** Allow tools to fire synchronously without limits. |
| **Intercom Fin**| Multi-step "Procedures" via MCP. Autonomous escalation. | **Do:** Use MCP for standardizing tool signatures. **Don't:** Rely purely on "confidence scores" for high-risk actions—always require humans for state-mutating actions initially. |
| **Zendesk AI** | "Action Builder" triggered by intent. | **Do:** Use adversarial testing/simulations. **Don't:** Build opaque black-box workflows; ensure auditability. |
| **Plain** | "BYOA" (Bring Your Own Agent) with strict KB grounding. | **Do:** Emphasize a "never guess" policy. Provide visual context alongside the drafted answer. |

## Recommended Architecture: Asynchronous HITL State Machine

To expose safe, policy-gated support tools (like Accrue billing lookups or Stripe refunds) in Elixir/Phoenix, we must embrace OTP's strengths and avoid blocking processes.

### 1. The MCP Gateway & Tool Definition (Contract)
Tools are defined as standard Elixir modules implementing a behaviour (e.g., `Scoria.MCP.Tool`).
*   **Typed Schemas:** Tools expose a strict JSON Schema for their arguments.
*   **Risk Levels:** Every tool must declare a risk level:
    *   `:read_only` (e.g., `lookup_invoice`): Executes automatically, trace recorded.
    *   `:requires_approval` (e.g., `refund_charge`): Halts execution, requires human operator approval.

### 2. Execution Flow (The "Pause and Resume" Pattern)
**Anti-Pattern:** Using a `Task.await` or `GenServer.call` to wait for human approval. The human might take hours to reply, leading to process timeouts and lost state.
**Idiomatic Pattern:**
1.  **Drafting Job:** An Oban job (`Scoria.Worker.DraftResponse`) runs the LLM loop.
2.  **Tool Call Intercept:** The LLM requests `refund_charge(%{amount: 50})`.
3.  **Policy Gate:** Scoria checks the tool's risk level. Seeing `:requires_approval`, it:
    *   Saves a `ToolApproval` Ecto record linked to the `Message`/`Trace`.
    *   Terminates the Oban job successfully (state is now "Paused").
    *   Broadcasts a PubSub event: `{:tool_approval_required, approval_id}`.

### 3. Operator DX & UX (LiveView Dashboard)
1.  **Context Pane:** The Cairnloop `ConversationLive` dashboard intercepts the PubSub event and dynamically renders an approval card in the timeline.
2.  **Rich Rendering:** Instead of showing raw JSON (`{"amount": 50}`), Cairnloop uses the `ContextProvider` to render a domain-specific component (e.g., an Accrue "Refund Preview" card showing the user's LTV and the refund impact).
3.  **Action:** The operator clicks "Approve" or "Reject (with feedback)".
4.  **Resumption:** Clicking "Approve" updates the `ToolApproval` record and enqueues a *new* Oban job. This new job injects the approved tool result into the LLM's message history and resumes generation.

## Feature Landscape

### Table Stakes
- **MCP Compatibility:** Defining tools using JSON Schema so standard LLMs (Claude, GPT-4) understand them.
- **Ecto-Native Audit Trail:** Every tool execution (approved or denied) is logged.
- **Process Isolation:** Tools execute in isolated `Task` boundaries with strict timeouts to prevent crashing the main web or worker nodes.

### Differentiators
- **Rich UI Tool Approvals:** Replacing raw JSON payloads with human-readable, domain-specific LiveComponents during the HITL phase.
- **Threadline Audit Integration:** Automatically pushing state-mutating approvals to the organization's immutable audit log.
- **LLM Context Injection on Rejection:** If an operator rejects a tool call (e.g., "Cannot refund more than $20"), feeding that natural language reason back to the LLM so it can draft an apology or alternative solution for the customer.

### Complexity & Dependencies
- **Complexity:** Medium-High. Building a robust "pause/resume" state machine for LLM generation requires careful Ecto state management.
- **Dependencies:** 
  - `Oban` (for async execution)
  - `Ecto` (for durable state)
  - `Scoria` (for tracing and policy enforcement)
  - `Phoenix.PubSub` (for UI reactivity)

## Implications for Roadmap (M003 & Beyond)

1. **Phase 1: Read-Only Tooling (Safe Default):** Start by implementing the MCP gateway for `:read_only` tools (e.g., "Get Billing Tier"). This proves the Scoria integration without the complexity of the HITL pause/resume logic.
2. **Phase 2: The HITL State Machine:** Implement the `ToolApproval` Ecto schema, the Oban pause/resume logic, and the raw JSON approval UI in `ConversationLive`.
3. **Phase 3: Rich UI Components:** Extend the `ContextProvider` behaviour so host applications can supply custom LiveComponents to render their specific tool payloads beautifully during approval.

## Conclusion
By treating the LLM as a stateless generator and relying on Ecto + Oban for durable state management, Cairnloop ensures that AI tool execution is safe, highly auditable, and resilient to timeouts. The operator remains firmly in control, reviewing potentially destructive actions via an ergonomic, embedded LiveView interface before any external system is mutated.