# Phase 13: Governed Tool Contract & Proposal Records - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-23
**Phase:** 13-governed-tool-contract-proposal-records
**Areas discussed:** Tool contract evolution, Risk tier & approval model, Durable record modeling, Fail-closed + policy seam

**Mode:** Research-driven, shift-left. The user asked me to research each gray area with parallel subagents (pros/cons/tradeoffs, idiomatic Elixir/Phoenix/Ecto/Oban, lessons from comparable libs/apps and other ecosystems, DX emphasis, and the repo's `prompts/`+`docs/` research) and one-shot a single coherent recommendation set, deciding for them on all but VERY impactful trust/scope calls. Four `gsd-advisor-researcher` agents ran in parallel; their recommendations cross-referenced each other's assumptions and were reconciled into CONTEXT.md.

---

## Tool contract evolution

| Option | Description | Selected |
|--------|-------------|----------|
| A — Evolve `Cairnloop.Tool` in place | One behaviour; add metadata; drop the sync execute path | (basis of choice) |
| B — New `GovernedTool` behaviour alongside legacy + adapter | Additive; two contracts coexist during migration | |
| C — Declarative `%Tool.Spec{}` struct + central runner | Metadata as pure data, easiest MCP serialization | (idea folded in) |
| **A′ — Hybrid (recommended)** | **Evolve in place; `Oban.Worker`-style `use` macro carrying declarative metadata via generated `__tool_spec__/0` → pure `%Cairnloop.Tool.Spec{}`; keep `changeset/2`; rename `execute/3`→`run/3`** | ✓ |

**Choice:** A′ hybrid. **Notes:** No production tool base to preserve (B's adapter cost buys nothing); pure-data C hurts host-author DX for tools with real `run` logic. A′ = the proven Oban.Worker pattern already used in this stack; pure-data `Spec` projects 1:1 to MCP in Phase 17. Replace `can_execute?/2` and split into `scope/0` + `authorize/2` (reconciled with the fail-closed area). Registry → boot-time validation of the declared config list.

## Risk tier & approval model

| Option | Description | Selected |
|--------|-------------|----------|
| A — Fixed tier enum with baked-in approval | One enum drives both blast-radius and the gate | |
| B — Orthogonal `risk_tier` + `approval_mode` | Blast-radius label separate from the gate; host-overridable | (core of choice) |
| C — Policy function only | Central module computes approval from tier + actor + context | (seam only) |
| **B + C-seam (recommended)** | **Orthogonal fields as the durable contract + a trivial `resolve/3` resolver as the Phase 15 PDP seam** | ✓ |

**Choice:** Orthogonal `risk_tier` `[:read_only,:low_write,:high_write,:destructive]` + `approval_mode` `[:auto,:requires_approval,:always_block]`, fail-closed default mapping, tighten-only host override, snapshot resolved values onto the proposal. **Notes:** Every mature governance system (AWS IAM, GitHub environments, OPA PDP/PEP) keeps risk separate from gate; coupling them forces tier explosion. Pure policy function (C) builds Phase 15 machinery a milestone early and can't be deterministically snapshotted — kept as the resolver seam only. Approval stays risk/policy-based, never confidence-based.

## Durable record modeling

| Option | Description | Selected |
|--------|-------------|----------|
| A — `ToolProposal` + append-only `ToolActionEvent`, status column | Mirrors existing ReviewTask idiom; simplest | (basis of choice) |
| B — Proposal + separate `ToolRun` + events | Cleanest intent/attempt split for Phase 16 retries | (seam reserved) |
| C — Event-sourced (Commanded-style) | Status projected purely from event stream | |
| **A now + B's seam reserved (recommended)** | **Ship A (mirror ReviewTask exactly); reserve `attempt`/`oban_job_id`/`result_state`/idempotency on the proposal so Phase 16 adds `ToolRun` without rework** | ✓ |

**Choice:** Two schemas now (`ToolProposal` + append-only `ToolActionEvent`), denormalized authoritative status + co-committed events, propose-time bounded typed snapshots, Stripe-style `idempotency_key` (unique index), defer `ToolRun` to Phase 16. **Notes:** C rejected — contradicts "durable records are workflow truth," fights LiveView read-your-writes, heavy dependency. B's empty table now would be designed against unverified Phase 16 assumptions.

## Fail-closed + policy seam

| Option | Description | Selected |
|--------|-------------|----------|
| A — Per-tool validation callbacks | Each tool self-validates and returns its own outcome | |
| **B — Central `Cairnloop.Governance` facade + ordered `with` pipeline (recommended)** | **Pure re-callable `validate/3` (reused by Phase 15 resume) + persistence wrapper; tools contribute narrow pieces** | ✓ |
| C — Plug/Bodyguard-style policy behaviour | Dedicated host-implemented policy behaviour | (shape borrowed) |

**Choice:** Central facade; outcome precedence `unsupported → needs_input → scope_invalid → policy_denied`; persist fail-closed outcomes EXCEPT unknown-tool (telemetry only, pre-persistence reject); split `can_execute?` → `scope/0` + deny-by-default `authorize/2`; minimal honest LiveView ("Proposed — pending review" / explicit blocked reason, no execution, no card). **Notes:** Bodyguard/OPA collapse to binary allow/deny — too coarse for TOOL-03's four operator-visible outcomes; borrow the `authorize/2` shape for the policy step only. `with` clause order *is* the precedence. Validation kept pure so the Phase 15 resume worker re-calls it.

---

## Claude's Discretion
- Exact module/table names (recommended: `Cairnloop.Governance` context; `ToolProposal`/`ToolActionEvent`; `cairnloop_tool_proposals`/`cairnloop_tool_action_events`).
- `Spec` field names + macro option keys; idempotency-key composition + dedupe-window token; `policy_snapshot` map keys.
- `event_type`/outcome/reason copy and flash wording; `scope/0` vs `required_scopes/0` naming and scope-comparison logic.

## Deferred Ideas
- `ToolRun` + retries/idempotency protections → Phase 16.
- `ToolApproval` + approval state machine + Oban resume → Phase 15.
- Operator timeline + preview card → Phase 14.
- Approved write execution → Phase 16.
- Scoria/OpenInference evidence hooks + read-only MCP seam → Phase 17.
- `:destructive`-tier execution / higher-risk mutations → past vM011 (ACT-02).
- Central host policy DSL / external OPA-style engine → out of scope (resolver + `authorize/2` is the seam).
</content>
