# M003-S03: Extensibility Components & Actions

## Status
- **Phase:** Discuss / Plan
- **Result:** Architectural decisions finalized. `M003-S03-PLAN.md` created.

## Overview
This slice enables host applications to inject custom interactive components (e.g., "Refund User") directly into the Cairnloop Context Pane. We have successfully researched and aligned on an architecture that provides strict error isolation for the main dashboard while paving a perfectly auditable path for future AI tool-calling.

## Key Decisions

1. **Hybrid Tool Registry:** We rejected injecting raw Phoenix `LiveComponent` modules because they share the parent LiveView's process, meaning a crash in a host tool would kill the entire Cairnloop dashboard. Instead, we use a hybrid approach: tools are declarative by default, but host apps can supply a `LiveView` module for complex interfaces, which Cairnloop mounts using `live_render` to guarantee process-level error isolation.
2. **Dedicated Tool Modules:** Following the successful patterns of Oban Workers and Ash Actions, every tool is an isolated module (`use Cairnloop.Tool`). Tools are registered globally but filtered dynamically per-actor via a `can_execute?/2` callback. This prevents `Cairnloop.ContextProvider` from becoming a monolithic bottleneck.
3. **Embedded Ecto Schemas for Inputs:** Tools define their arguments using standard `embedded_schema` and `changeset/2`. This provides best-in-class DX with free casting/validation. Crucially, Cairnloop will use `Phoenix.Component.to_form/1` to auto-generate a UI for these inputs, providing a "Zero-Config UI" for simple tools. Furthermore, Cairnloop can use Elixir reflection on these schemas to auto-derive JSON Schemas for AI agents in future milestones.

## Next Steps
Proceed to the execution phase using `.planning/phases/M003-S03/M003-S03-PLAN.md`.