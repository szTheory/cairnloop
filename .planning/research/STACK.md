# M011 Stack Research: AI Tool Governance & MCP Integration

**Date:** 2026-05-23
**Milestone:** vM011 AI Tool Governance & MCP Integration

## Recommended Stack Shape

| Area | Recommendation | Why |
|------|----------------|-----|
| Workflow truth | `Ecto` schemas + `Ecto.Multi` | Durable approvals, replayable state transitions, and explicit fail-closed mutations fit Cairnloop's host-owned model. |
| Async orchestration | `Oban` workers and unique jobs | Human approval pause/resume and retryable execution belong in durable jobs, not in LiveView or transient processes. |
| Operator control plane | `Phoenix LiveView` + `Phoenix.PubSub` | Existing operator workflow already lives in-thread; UI updates should subscribe to durable state rather than own it. |
| Tool contract | Native Elixir behaviour plus embedded-schema changesets | Typed inputs, explicit validations, and host-owned extensibility fit the existing `Cairnloop.Tool` shape. |
| Policy seam | Host-owned behaviour module | Permission and risk posture must remain app-specific and actor-scoped, not hidden in a generic runtime. |
| Telemetry | Existing bounded telemetry helpers plus new governed-action events | Keeps metric labels low-cardinality while durable evidence stores high-detail action truth. |
| AI evidence lane | Optional `Scoria` integration | Good for OpenInference traces, evals, and tool evidence, but should not become required runtime truth. |
| Remote interoperability | Optional MCP adapter | Useful at the edge, but not as Cairnloop's core action model. Start read-only and user-scoped. |

## Keep

- `Ecto.Multi` for proposal, approval, deny, expire, and resume transitions.
- `Oban` for proposal execution, approval wakeup, timeout expiry, and replay.
- `Phoenix.PubSub` for waking operator surfaces after durable state changes.
- Embedded-schema input validation for tool arguments.
- Host-owned behaviours for policy, audit, and optional adapters.

## Add

- Durable records such as `automation_runs`, `tool_calls`, `tool_approvals`, and append-only action events.
- A governed-tool metadata contract covering risk tier, idempotency, preview rendering, redaction, and fallback semantics.
- A bounded telemetry helper for governed actions, modeled after retrieval and KB maintenance telemetry.
- Optional `cairnloop_scoria` and `cairnloop_mcp` companion seams rather than required runtime dependencies.

## Avoid

- Blocking approval inside LiveView or a long-running worker.
- Treating MCP transport/session state as workflow truth.
- Broad new infrastructure such as Temporal or external workflow engines.
- Generic macro-heavy tool DSLs that hide important host decisions.
