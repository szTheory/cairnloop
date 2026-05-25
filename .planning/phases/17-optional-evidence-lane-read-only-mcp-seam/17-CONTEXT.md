# Phase 17: Optional Evidence Lane & Read-Only MCP Seam - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire two **lightweight companion adapters** over the sealed vM011 governance lane, neither of
which changes core approval or execution truth:

1. **Optional evidence lane (M011-S05-01):** Surface the existing durable governed-action trail
   (proposals, approvals, execution events, `policy_snapshot`, `decided_by` attribution) to optional
   external evidence/observability systems via OpenInference-conformant `:telemetry` events. Scoria
   and any OI-compatible observability system auto-attach via `:telemetry.attach_many` — Cairnloop
   ships no explicit Scoria dependency.

2. **Read-only MCP seam (M011-S05-02, MCP-01):** Project `Cairnloop.Tool.Spec` metadata and the
   tool registry into the MCP protocol as a `tools/list`-only read-only surface. Pure
   `Spec → MCP tool definition` data projection. No `tools/call` execution. An optional Plug the
   host mounts in their Phoenix router handles the JSON-RPC transport.

This phase does **NOT** build:
- **`tools/call` execution through MCP** — requires the `:auto` execution path explicitly deferred
  in D16-09; contradicts MCP-01 "advisory auth and mapping proof only"; deferred to future MCP-03
  or v2 milestone.
- **An explicit `Cairnloop.Evidence` behaviour or callback** — telemetry-only is the OI/Scoria
  integration contract; explicit callbacks add surface area the phase doesn't justify.
- **Any new governance schemas, records, or approval-lane modifications** — the durable trail that
  already exists (Phases 13–16) is the evidence source; this phase only projects it outward.
- **Any change to internal approval or execution truth** — both adapters are strictly read-side
  projections from sealed internals.

</domain>

<decisions>
## Implementation Decisions

> Calibration: owner profile is `opinionated` → `minimal_decisive`. Both gray areas confirmed
> by the owner; auto-decided items noted with rationale. Per repo CLAUDE.md shift-left policy:
> ordinary implementation details (module names, event name spellings, Plug structure, JSON-RPC
> framing) are planner/executor discretion as long as the shapes below hold.

### Evidence lane — OI-conformant telemetry (M011-S05-01)

- **D17-01 [OWNER-CONFIRMED]:** Ship a **new `Cairnloop.Governance.Telemetry.Traces` submodule**
  (or equivalent namespaced module) with its **own OI-conformant event namespace**:
  `[:cairnloop, :governance, :trace, ...]`. This is **strictly separate from** the bounded-metrics
  module (`Cairnloop.Governance.Telemetry`) — different event names, different payload shape,
  different cardinality contract. The bounded-metrics D-29 invariant (OBS-01: enum-only labels,
  no high-cardinality payload in metrics) remains sealed and untouched.

- **D17-02:** The OI trace events carry **richer context than the bounded metrics** — sufficient
  for Scoria (or any OI-compatible system) to reconstruct a span tree:
  - **OI span kind:** `:tool` for execution events (`:execution_started`,
    `:execution_succeeded`, `:execution_failed`); `:guardrail` for policy evaluation events
    (`:approval_requested`, `:revalidation_passed`, `:revalidation_failed`); `:agent` optional
    wrapper if a parent trace context is present.
  - **Attribution fields** (planner picks the exact map keys):
    - `tool_proposal_id` — the durable anchor
    - `actor_id` — from the `ToolActionEvent` trail
    - `policy_snapshot_ref` — reference to `ToolProposal.policy_snapshot` (not its content)
    - `decided_by` — from `ToolApproval.decided_by` when available
    - `attempt` — for execution spans
  - **Do NOT put `policy_snapshot` content, note content, or input payloads** into trace events
    (follow D-29 philosophy: detailed truth is in durable records; observability layers carry
    references, not copies).

- **D17-03:** Cairnloop **ships zero explicit Scoria dependency**. The host opts in by calling
  `Scoria.attach_cairnloop_governance_traces/0` (or the equivalent Scoria API) — a single
  `:telemetry.attach_many` call that binds to the `[:cairnloop, :governance, :trace, ...]`
  namespace. Cairnloop documents this in its guides; it does not call into Scoria directly.

- **D17-04:** The trace events are emitted **after successful transitions** (alongside the existing
  `ToolActionEvent` co-commits — same ordering rule as D-29). They never replace `ToolActionEvent`
  inserts — the durable record is always written first; telemetry is observability only.

- **D17-05:** The evidence lane adapter is **fully optional and fail-closed**: if no
  `:telemetry` handler is attached, the `emit/3` calls no-op (Elixir `:telemetry` drops events
  with no handler). Cairnloop's Supervisor starts no Scoria process; host wires what they want.

### Read-only MCP seam — listing only (M011-S05-02, MCP-01)

- **D17-06 [OWNER-CONFIRMED]:** The MCP seam exposes **`tools/list` only** — no `tools/call`.
  This is a pure `%Cairnloop.Tool.Spec{} → MCP tool definition` data projection over the tool
  registry, with zero execution path. Rationale: `:auto` execution was explicitly deferred (D16-09),
  the codebase has a fail-closed guard against `:auto`-mode proposals in `request_approval/2`,
  and MCP-01 requires "advisory auth and mapping proof only." `tools/call` for `:read_only` tools
  is deferred to a future MCP-03 or v2 phase when the `:auto` execution lane can be designed with
  the same rigor as the `:requires_approval` lane received in Phases 15–16.

- **D17-07:** The `Spec → MCP tool definition` mapping follows the seam already documented in
  `lib/cairnloop/tool/spec.ex` `@moduledoc` (Phase 13 forward-compatibility note):
  - `Spec.title` → MCP `title`
  - `Spec.description` → MCP `description`
  - Tool module name (Atom.to_string) → MCP `name`
  - `tool_module.changeset/2` Ecto embedded schema → MCP `inputSchema` (JSON Schema projection)
  - Include `risk_tier` and `approval_mode` as non-standard `x-cairnloop-*` fields for MCP
    clients that want to understand Cairnloop's governance model (planner decides exact key names).
  - This projection is a **pure total function** — no database, no side effects.

- **D17-08:** Ship an **optional `Cairnloop.Web.MCP.Router` Plug** (or equivalent name — planner
  discretion) that handles:
  - `POST /` with `method: "tools/list"` (JSON-RPC 2.0) → return the projected tool registry
  - `POST /` with `method: "initialize"` → return server capabilities (tools only; read-only)
  - All other methods → standard JSON-RPC error response
  The host mounts it in their Phoenix router (e.g. `forward "/mcp", Cairnloop.Web.MCP.Router`).
  This mirrors how Oban Web and LiveDashboard expose optional Plug-based surfaces.

- **D17-09:** **Auth goes through the existing contract** — no new auth model. The `tools/list`
  endpoint does not expose tool inputs or execute anything, so the minimal auth bar is: the host
  guards the mounted Plug with their existing auth middleware (e.g. a `Plug.BasicAuth`, a session
  plug, or a Sigra-based guard). Cairnloop does not prescribe an auth mechanism for the Plug;
  the docs note that hosts SHOULD put auth middleware before it in the pipeline. The `authorize/2`
  + `Policy.resolve/3` seam is invoked at execution time — not relevant for listing-only.

- **D17-10:** `Cairnloop.Tools.InternalNote` is the **concrete proof artifact** for the MCP
  projection — the example tool from Phase 16 projects cleanly through D17-07's mapping and
  demonstrates the `inputSchema` derivation from its Ecto embedded schema. Planner should include
  a test asserting the projection of InternalNote's `Spec` to the expected MCP shape.

### Architecture & posture (carried)

- **D17-11:** Durable Ecto records are the evidence source — the OI trace events carry *references*
  to `tool_proposal_id` + `decided_by`; they never duplicate or replace the durable trail. Both
  adapters are strictly additive read-side projections (no new writes, no governance schema changes,
  no sealed-code churn).
- **D17-12:** Both adapters follow the "optional companion" packaging posture: disabling either
  (by not mounting the Plug or not attaching Scoria's `:telemetry` handlers) leaves the host app
  fully functional. Cairnloop.Application supervises neither.
- **D17-13:** Proof posture is **"advisory proof only"** per the Capability Rubric:
  - Evidence lane: attach a handler to `[:cairnloop, :governance, :trace, ...]` and assert the
    correct OI span kind + attribution fields are emitted on a proposal → execution cycle.
  - MCP seam: assert the `tools/list` JSON-RPC response matches the expected schema for the
    configured tools (including InternalNote); no HTTP integration test required (pure data proof).

### Claude's Discretion

- Exact module names (`Cairnloop.Governance.Telemetry.Traces`, `Cairnloop.Web.MCP.Router`, etc.),
  JSON-RPC framing details (exact error codes, response envelope), OI trace event name spellings
  under `[:cairnloop, :governance, :trace, ...]`, exact `x-cairnloop-*` field names in the MCP
  response, how the `changeset/2` Ecto schema is projected to JSON Schema (reflection vs.
  explicit declaration), and whether `initialize` capability response is minimal or fuller.
- Whether `Cairnloop.Governance.Telemetry.Traces` lives as a submodule or a parallel sibling
  module — as long as it has its own event namespace that does NOT share names with the
  bounded-metrics module.
- Whether InternalNote's `inputSchema` projection uses Ecto reflection or an explicit `json_schema`
  declaration — as long as the output is valid JSON Schema `object` with typed properties.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary & active requirements
- `.planning/ROADMAP.md` — Phase 17 goal + plans **M011-S05-01, M011-S05-02**; Phases 13–16
  (what Phase 17 must stay forward-compatible with: sealed approval + execution model, no churn).
- `.planning/REQUIREMENTS.md` — **MCP-01** (the sole unfinished vM011 requirement; "advisory auth
  and mapping proof only"); Capability Rubric rows for "Optional Scoria/OpenInference evidence lane"
  ("advisory integration proof only") and "Optional read-only MCP bridge" ("advisory auth and
  mapping proof only"); out-of-scope ("broad external MCP server surface before governed-tool
  contract is proven").
- `.planning/PROJECT.md` — vM011 posture: "Treat Scoria as an optional evidence lane and MCP as an
  optional edge adapter, not the milestone's center." Sealed decision: "Expose MCP compatibility
  only through the governed-tool seam."

### Prior-phase decisions that constrain Phase 17
- `.planning/phases/16-first-approved-write-path-telemetry/16-CONTEXT.md` — **D16-09** (Phase 16
  makes attribution reconstructable from durable records; does NOT build the Scoria adapter or MCP
  seam → Phase 17 delivers both); **D16-02** (`InternalNote` is "the concrete tool Phase 17 projects
  to MCP"); **D16-10** (bounded `Governance.Telemetry` allow-list — D17-01 introduces a SEPARATE OI
  trace submodule to preserve this invariant); **D16-13** (durable records are workflow truth;
  telemetry is observability; reads through narrow facade).
- `.planning/phases/15-approval-state-machine-oban-resume/15-CONTEXT.md` — D15-03 (one
  `ToolActionEvent` timeline, the evidence source Phase 17 taps); D15-17 (telemetry alongside never
  instead of events); D15-09 (host-owned Oban posture — Phase 17 Plug has no Oban dependency).
- `.planning/phases/13-governed-tool-contract-proposal-records/13-CONTEXT.md` — **D-29** (telemetry
  observability-only, emitted after success, never instead of events → D17-04); **D-30** (narrow
  `Cairnloop.Governance` facade — Phase 17 reads through it); D-12 (`Policy.resolve/3` PDP seam —
  Phase 17 does not widen it; auth middleware is host responsibility for the Plug).

### Existing code seams (read before implementing)
- `lib/cairnloop/tool/spec.ex` — **the MCP projection seam** (already documented in `@moduledoc`:
  `title`, `description`, tool module name, `changeset/2` → JSON Schema); the struct Phase 17
  transforms (D17-07). Forward-compatibility comment explicitly flags Phase 17.
- `lib/cairnloop/tool_registry.ex` — `get_available_tools/2` (advisory UX filter) +
  `validate_configured_tools!/0`; the source of the tool list the MCP Plug projects (D17-08/10).
- `lib/cairnloop/tool.ex` — the `changeset/2` callback (D17-07 uses it for `inputSchema`
  derivation); `scope/0` and `authorize/2` (not invoked at listing time but should be noted in docs).
- `lib/cairnloop/governance.ex` — the narrow facade all reads go through (D17-11/D-30); `validate/3`
  (pure, not called by Phase 17 but read for context); `list_proposals_for_conversation/1` (evidence
  source pattern). **Do NOT call `run/3` or open the `:auto` execution path** (D17-06/D16-09).
- `lib/cairnloop/governance/telemetry.ex` — the bounded metrics module Phase 17 must **NOT modify**
  (D17-01); its `@events` list, `normalize_*` helpers, and `metadata/2` functions are the template
  for the new OI trace submodule's structure.
- `lib/cairnloop/governance/tool_action_event.ex` — `@event_type_values` — the durable event types
  whose lifecycle the OI trace events shadow (D17-02; do not extend this schema for Phase 17).
- `lib/cairnloop/governance/tool_proposal.ex` — `policy_snapshot` field (OI trace events carry
  the `tool_proposal_id` as ref, not the snapshot content — D17-02); `result_state`, `decided_by`
  context.
- `lib/cairnloop/governance/tool_approval.ex` — `decided_by` + decision fields (D17-02 attribution).
- `lib/cairnloop/tools/internal_note.ex` (Phase 16 artifact) — the **concrete proof tool** for the
  MCP `Spec → tool definition` projection test (D17-10); its `changeset/2` demonstrates the
  `inputSchema` derivation; its `__tool_spec__/0` is the round-trip proof.
- `lib/cairnloop/workers/approval_resume_worker.ex` — **read for understanding `request_approval/2`
  fail-closed guard against `:auto`** that confirms `tools/call` is out of scope (D17-06).

### Product & brand posture
- `prompts/scoria overview for integration ideas.txt` — §4 "Telemetry & Protocols": "Any future
  library that performs an AI-adjacent action should emit standard `:telemetry` events matching
  OpenInference span kinds (RETRIEVER, RERANKER, GUARDRAIL). Scoria will automatically catch
  these." → D17-01/02/03 rationale. §3 "MCP Gateway & Tool Governance": Scoria is positioned as
  the MCP gateway; Cairnloop exposes projection data, not its own full MCP server.
- `prompts/cairnloop_brand_book.md` — §5.3/5.6 (copy in docs/guides); §2.2/§7 (brand tokens if
  any UI surface is added, though Phase 17 is backend-only).
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned Phoenix/Ecto/Oban
  architecture; evidence-vs-telemetry separation; host-supplied-runtime DX posture.

### External references (orientation, not requirements)
- MCP protocol specification — JSON-RPC 2.0 framing, `tools/list` response structure,
  `ListToolsResult` shape, `initialize` handshake (D17-08). The Anthropic MCP spec at
  `https://modelcontextprotocol.io/specification` is the authoritative source.
- OpenInference semantic conventions — span kinds (`:tool`, `:guardrail`, `:agent`), attribute
  names (`openinference.span.kind`, `tool.name`, `tool.parameters`, `tool.output.value`),
  recommended attribute structure (D17-02). Reference: `https://openinference.ai/spec`.
- Oban Web / LiveDashboard — Plug-based optional surfaces mounted via `forward` in the host
  Phoenix router (the DX pattern D17-08 mirrors).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.Tool.Spec` — already has MCP projection field mapping in `@moduledoc`; pure struct,
  no side effects. The total transform function the planner writes is essentially `spec_to_mcp/1`.
- `Cairnloop.ToolRegistry` — `get_available_tools/2` returns the registered tools; the MCP Plug
  calls a variant of this (scope/actor not relevant for listing; planner decides whether to expose
  all registered tools or filter by scope context).
- `Cairnloop.Governance.Telemetry` — the bounded-metrics module is the structural template for
  the new `Cairnloop.Governance.Telemetry.Traces` submodule: `@events` list,
  `emit/3` guard-clause no-op, `metadata/2` dispatch, `normalize_*` helpers.
- `Cairnloop.Tools.InternalNote` (Phase 16) — concrete governed-write tool; its `__tool_spec__/0`
  + `changeset/2` are the proof round-trip for the MCP projection test (D17-10).
- Phase 15 integration harness (`test/integration/`, `docker-compose.yml`, `mix test.integration`)
  — available for the evidence lane emit test if a real Postgres round-trip is needed to trigger
  a full proposal → execution cycle; optional given "advisory proof only" bar.

### Established Patterns
- `:telemetry` modules in Cairnloop follow the `@events` allow-list + guard-clause `emit/3` no-op
  pattern (see `Governance.Telemetry`, `Cairnloop.Telemetry`). The new Traces submodule mirrors
  this structure.
- Optional companion surfaces (evidence lane, MCP Plug) are not supervised by `Cairnloop.Application`;
  the host wires them explicitly (same posture as Oban, LiveDashboard).
- Telemetry events are emitted **after** successful transitions, never inside `with` clause lists
  (D-29 rule, carried into Phase 17 for trace events).
- Pure data transforms over `Spec` structs follow the established Cairnloop idiom of module-level
  `@spec` + total functions with no side effects.

### Integration Points
- New `Cairnloop.Governance.Telemetry.Traces` module (or sibling) — emit calls added after the
  existing `ToolActionEvent` co-commits in `Cairnloop.Governance` (additive, after success).
- New `Cairnloop.Web.MCP.Router` Plug — host mounts via `forward "/mcp", Cairnloop.Web.MCP.Router`;
  reads from `Cairnloop.ToolRegistry` to build `tools/list` response; pure read-side, no writes.
- No new Ecto migrations, no new schemas, no new Oban workers — Phase 17 is entirely read-side.

</code_context>

<specifics>
## Specific Ideas

- The OI trace event shape should carry just enough context for Scoria to reconstruct a span tree
  (proposal_id as the trace root, approval and execution events as child spans) without duplicating
  the durable record content. Think "trace anchor + span kind + attribution refs", not a payload dump.
- The MCP Plug JSON-RPC framing should be minimal: `tools/list` returns the projected registry,
  `initialize` returns read-only capabilities, everything else returns standard JSON-RPC errors.
  Do not implement `tools/call`, `resources/*`, `prompts/*`, or any other MCP method.
- The `inputSchema` derivation from Ecto embedded schema is the trickiest part of D17-07.
  The planner should choose between: (a) Ecto reflection via `__schema__(:fields)` +
  type mapping, or (b) an explicit `json_schema/0` callback on the tool module. Option (a) is
  more automatic but less flexible; option (b) is more host-friendly but requires more tool authoring.
  Planner decides; either satisfies D17-07.
- `Cairnloop.Tools.InternalNote` makes an ideal proof because its changeset is simple enough to
  derive cleanly and it's already registered in the integration harness config.

</specifics>

<deferred>
## Deferred Ideas

- **`tools/call` for `:read_only` tier through MCP** — requires the `:auto` execution path
  deferred in D16-09; fail-closed guard in `request_approval/2` must be revisited; deferred to
  future MCP-03 milestone or v2. (Owner confirmed: not Phase 17 scope.)
- **MCP write operations through the governed-action pipeline** — broad remote MCP write surfaces
  are out of scope for the entire vM011 milestone (REQUIREMENTS.md "Broad remote MCP write
  surfaces: defer"). Phase 17 is listing-only.
- **Explicit `Cairnloop.Evidence` behaviour / callback protocol** — owner confirmed OI telemetry
  is the right model; explicit callbacks add surface area not justified by "advisory proof only".
- **Full MCP server capabilities** — `resources/*`, `prompts/*`, streaming, session management.
  Phase 17 is `tools/list` + `initialize` only. Full server capabilities are a future milestone.
- **Scoria operator dashboard / LiveView integration** — Scoria's dashboard is Scoria's problem;
  Cairnloop just emits OI-conformant events. No Cairnloop LiveView additions in Phase 17.
- **`:auto` execution path for non-approval tools** — deferred past vM011 (D16-09). Not touched
  by Phase 17.

</deferred>

---

*Phase: 17-optional-evidence-lane-read-only-mcp-seam*
*Context gathered: 2026-05-25*
