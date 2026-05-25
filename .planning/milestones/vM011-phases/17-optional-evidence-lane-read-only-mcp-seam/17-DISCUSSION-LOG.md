# Phase 17: Optional Evidence Lane & Read-Only MCP Seam - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 17-optional-evidence-lane-read-only-mcp-seam
**Areas discussed:** MCP seam scope, Scoria evidence hooks

---

## MCP Seam Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Listing-only (`tools/list`) | Pure `Spec → MCP tool definition` data projection. Advisory proof. `tools/call` deferred to future milestone. Zero new execution path. Honors D16-09 deferral and MCP-01 "advisory proof only" requirement. | ✓ |
| `tools/call` for `:read_only` tier | Build the deferred `:auto` execution path now. Requires reopening `request_approval/2` fail-closed guard, new Oban worker variant, approval-lane variant. Contradicts MCP-01 "advisory proof only" and D16-09. | |

**User's choice:** Listing-only (`tools/list`)
**Notes:** Research confirmed a hard fail-closed guard at `request_approval/2` against `:auto`-mode proposals already exists in the codebase. Building `tools/call` would require the entire `:auto` execution path explicitly deferred in Phase 16. Owner confirmed listing-only is correct for Phase 17.

---

## Scoria Evidence Hooks

| Option | Description | Selected |
|--------|-------------|----------|
| OI-conformant `:telemetry` events in new Traces submodule | New `Cairnloop.Governance.Telemetry.Traces` (or equivalent) with `[:cairnloop, :governance, :trace, ...]` namespace. OI span kinds (`:tool`, `:guardrail`). Scoria auto-attaches. Zero Scoria dep in Cairnloop. D-29 bounded-metrics invariant preserved by separate module. | ✓ |
| Explicit `Cairnloop.Evidence` behaviour | A typed callback contract the host wires to Scoria or any evidence backend. More coupling, adds new extensibility surface not used elsewhere. Scoria doesn't need it (auto-attaches via `:telemetry`). | |

**User's choice:** OI telemetry in new Traces submodule
**Notes:** Scoria documentation explicitly states OI-conformant `:telemetry` events are the integration contract. The key implementation constraint is keeping OI trace events in a SEPARATE submodule (different event namespace) from the existing bounded-metrics `Governance.Telemetry` to preserve the D-29 cardinality invariant. Owner confirmed this approach.

---

## Claude's Discretion

- Exact module names (`Cairnloop.Governance.Telemetry.Traces`, `Cairnloop.Web.MCP.Router`, etc.)
- JSON-RPC framing details (exact error codes, response envelope shape)
- OI trace event name spellings under `[:cairnloop, :governance, :trace, ...]`
- Exact `x-cairnloop-*` field names in the MCP `tools/list` response
- How `changeset/2` Ecto schema is projected to JSON Schema (reflection vs. explicit declaration)
- Whether `initialize` capability response is minimal or fuller
- Whether OI Traces module is a submodule or a parallel sibling module (as long as separate namespace)

## Auto-Decided (Claude, with recorded rationale)

- **MCP transport = optional Plug the host mounts** — standard Phoenix library DX pattern
  (mirrors Oban Web, LiveDashboard); no alternative was meaningfully better.
- **Auth model unchanged** — `tools/list` exposes no inputs; host guards the Plug route with
  existing middleware; `authorize/2` + `Policy.resolve/3` remain the execution-time gate.
- **`Tool.Spec` field mapping unchanged** — already seamed in `spec.ex` `@moduledoc`; no model
  change required.
- **InternalNote as proof artifact** — D16-02 explicitly named it as "the concrete tool Phase 17
  projects to MCP"; natural choice.
- **No new Ecto migrations, schemas, or Oban workers** — Phase 17 is entirely read-side projection.
- **Trace events emitted after successful transitions** — same D-29 ordering rule as bounded
  metrics; trace events never replace `ToolActionEvent` co-commits.

## Deferred Ideas

- `tools/call` for `:read_only` tier — requires `:auto` execution path; deferred to MCP-03/v2.
- MCP write operations — deferred past vM011 per REQUIREMENTS.md.
- Explicit `Cairnloop.Evidence` behaviour — telemetry model confirmed correct; callbacks not needed.
- Full MCP server capabilities (`resources/*`, `prompts/*`, streaming) — future milestone.
