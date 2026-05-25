# Phase 13: Governed Tool Contract & Proposal Records - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish one native, host-owned governed-tool contract and the durable proposal/event records behind it, so host developers can define governed support tools and Cairnloop can create **fail-closed proposals without executing them inline**. This phase covers: (1) the tool contract carrying risk tier, approval mode, idempotency, preview, and structured result metadata; (2) durable `ToolProposal` + append-only `ToolActionEvent` records plus the public governed-action facade; (3) replacing the synchronous `execute_tool` LiveView path with proposal-first, fail-closed creation and scope validation.

It does **not** build: the operator timeline/preview UI (Phase 14), the approval state machine + Oban resume (Phase 15), any real write execution (Phase 16), or the MCP seam (Phase 17). In Phase 13 nothing executes — even read-only/`:auto` tools only produce a durable proposal record. Execution lands in Phase 16. Records and seams here are designed to be forward-compatible with all four later phases without rework.

This phase covers requirements **TOOL-01, TOOL-02, TOOL-03, TOOL-04** and supersedes the synchronous `execute_tool` path noted as a pending todo in STATE.md.

</domain>

<decisions>
## Implementation Decisions

> These decisions were derived from four parallel research passes (idiomatic Elixir/Phoenix/Ecto/Oban + lessons from MCP, Anthropic/OpenAI tool-use, LangChain, AWS IAM, GitHub environment protection, OPA, Stripe idempotency, Temporal, event-sourcing). They are reconciled to be mutually coherent. Exact names are the planner's discretion unless flagged; the *shapes* are locked.

### Tool contract evolution (TOOL-01)
- **D-01:** Evolve the existing `Cairnloop.Tool` behaviour **in place** into the single governed contract. Do NOT introduce a parallel `GovernedTool` behaviour — there is no production tool base to preserve (the current path is a thin demo), and a second name implies an ungoverned contract still exists. The only contract is governed.
- **D-02:** Use the **`Oban.Worker` hybrid pattern**: `use Cairnloop.Tool, ...` carries governance metadata as **compile-time declarative data**, exposed via a generated `__tool_spec__/0` that returns a pure `%Cairnloop.Tool.Spec{}` data struct. Behaviour callbacks handle logic. Validate metadata enum values at compile time and raise `CompileError` on a bad value (fail-closed at build time).
- **D-03:** The `Spec` carries: `risk_tier`, `approval_mode` (optional — derived from tier when omitted), `idempotency` strategy, `result_states` (the tool's declared result vocabulary), `title`, `description`. Keeping it **pure data** is deliberate: Phase 17 projects `Spec` straight to an MCP `tool` definition with zero change to the approval/execution model (MCP-01).
- **D-04:** Typed input stays as the **`changeset/2` Ecto embedded-schema callback** — the idiomatic, least-surprise Elixir "vet a map into a trusted struct" seam already used by the current tool. Do not invent a parallel typed-input contract. Phase 17 can *derive* an MCP `inputSchema` from the embedded schema later (one source of truth for input shape).
- **D-05:** Rename the execution callback `execute/3` → **`run/3`** to signal the semantics changed (it produces a structured outcome, not an inline side effect) and to force a compiler-enforced cutover of any caller expecting synchronous execution. `run/3` is NOT called in Phase 13.
- **D-06:** **Remove `can_execute?/2`** (a single boolean cannot distinguish `scope_invalid` from `policy_denied`). Replace it with two callbacks (see D-15/D-16). Add an optional `preview/1` callback (human-readable consequence summary, used by Phase 14); keep the optional `custom_ui/0`.
- **D-07:** Registry: keep host-declared tools in config, but Cairnloop **validates each at boot** (implements the behaviour + has a valid `__tool_spec__/0`) and fails fast. Prefer explicit boot-time validation of a declared list over implicit compile-time auto-discovery (which can silently pick up unintended modules) — consistent with the fail-closed, explicit-failure posture.

### Risk tier & approval model (TOOL-01, seam for Phase 15)
- **D-08:** Use **orthogonal `risk_tier` + `approval_mode` fields**, not a single enum. Every mature governance system (AWS IAM intent vs permission boundary, GitHub environment vs protection rule, OPA PDP/PEP) keeps "what an action can affect" separate from "is it gated." Collapsing them forces tier explosion the moment a host wants the same blast radius with a different gate.
- **D-09:** `risk_tier` (operator-facing blast-radius label, `Ecto.Enum`): **`[:read_only, :low_write, :high_write, :destructive]`**. Named, not numbered (numbers invite false arithmetic and read poorly on a risk label). `:destructive` is declared now for enum stability but has **no execution path this milestone** (ACT-02 defers high-risk/destructive writes).
- **D-10:** `approval_mode` (the gate input Phase 15 consumes, `Ecto.Enum`): **`[:auto, :requires_approval, :always_block]`**. `:auto` = may proceed without human approval (still produces a durable proposal + events — nothing is ever silent); `:requires_approval` = opens an approval lane in Phase 15; `:always_block` = fail-closed terminal, surfaces `policy_denied` with an operator-visible reason.
- **D-11:** Fail-closed default derivation (so hosts usually declare only `risk_tier`): `read_only → :auto`, `low_write|high_write → :requires_approval`, `destructive → :always_block`, **unknown/missing → :always_block**.
- **D-12:** Approval requirement is resolved through **one resolver function** (`tool override || host config || tier default`) that is the **Phase 15 seam**. Today it returns the declared mapping; Phase 15 extends *only this function* to factor in actor scope + context (its PDP) — no schema or call-site change. Approval is policy/risk-based, **never confidence-score-based** (REQUIREMENTS out-of-scope).
- **D-13:** Host override of `approval_mode` is **tighten-only by default** (a host may make the gate stricter freely; loosening below the tier default is an explicit, logged config choice) — mirrors AWS permission boundaries.
- **D-14:** **Snapshot the resolved `risk_tier` + `approval_mode` + a small `policy_snapshot` map (resolution source + policy version) onto the proposal at propose time.** Never re-read live config/spec at approval/render time — that is how risk-tier drift sneaks into history (satisfies OBS-02 "which policy snapshot applied").

### Fail-closed semantics & policy seam (TOOL-03)
- **D-15:** Validation lives in a **central `Cairnloop.Governance` facade** running a single **re-callable, pure, ordered `with` pipeline** — not in per-tool callbacks. The pipeline is one function both the Phase 13 entrypoint and the **Phase 15 resume worker** call against current context (re-validation is free by construction). Persistence is a thin separate step wrapping it.
- **D-16:** Tools contribute only narrow pieces: `changeset/2` (input), a **`scope/0`** (or `required_scopes/0`) declaration of the static scope the tool needs, and a Bodyguard-shaped **`authorize/2` :: `:ok | {:error, reason}`** dynamic policy callback whose **default implementation is `{:error, :no_policy_defined}` (deny-by-default)** — the single most important footgun fix vs today's truthy `can_execute?/2`.
- **D-17:** Outcome taxonomy (runtime tagged tuple `{:ok, validated} | {:blocked, outcome, reason}`) with **precedence** (first failure wins): **`unsupported → needs_input → scope_invalid → policy_denied`**. Rationale: check the cheapest/most structural thing first and the most context-rich (host policy) last, so the operator always sees the root cause, never a downstream symptom.
- **D-18:** **Persist fail-closed outcomes** as durable proposal records with `outcome` + `reason` (REQUIREMENTS Support-Truth Gate: "Refuse execution and preserve proposal record"; TOOL-04). **One nuance:** a tool name that does NOT resolve to any registered governed tool (`unsupported`/`:unknown_tool`) is rejected **pre-persistence** (telemetry only, no row) — persisting attacker-supplied/buggy atoms as proposal rows is an unbounded-cardinality junk-data footgun. A *registered* tool that declares it cannot run in context is `scope_invalid`/`policy_denied` and IS persisted.
- **D-19:** Stop resolving tools via `String.to_existing_atom/1` on the raw param; **resolve by matching against the registry's known modules** (gate 0 of the pipeline).

### Durable record modeling (TOOL-04)
- **D-20:** Mirror the **existing `ReviewTask` + `ReviewTaskEvent` idiom** exactly (denormalized authoritative status column **plus** a separate append-only events table, co-committed in the same transaction). This is the locked trust-model pattern and the lowest-surprise choice. Reject pure event-sourcing (Commanded/EventStore) — it contradicts "durable records are workflow truth," fights LiveView read-your-writes, and adds a heavy dependency.
- **D-21:** Phase 13 ships **two schemas**: `ToolProposal` (intent + denormalized status + propose-time snapshots + idempotency key) and `ToolActionEvent` (append-only audit timeline: `event_type`, `from_status`, `to_status`, `actor_id`, `reason`, bounded `metadata`; `timestamps(updated_at: false)`; FK `on_delete: :delete_all`; indexed `[proposal_id, inserted_at]`). Append-only enforced by app discipline (insert-only changeset, no update/delete API) to match the existing `ReviewTaskEvent`.
- **D-22:** **Defer the separate `ToolRun` (execution-attempt) table to Phase 16** — Phase 13 never executes, so the table would sit empty and be designed against unverified assumptions. Reserve the seam on `ToolProposal` instead: `attempt` (default 0), `oban_job_id` (null), `result_state` (`:not_executed | :succeeded | :failed`, default `:not_executed`), `result_summary` (null). Phase 16 can add columns or extract `ToolRun` without rewriting history.
- **D-23:** Phase 13 proposal statuses (`Ecto.Enum`): **`[:proposed, :needs_input, :scope_invalid, :policy_denied]`**. `:proposed` = passed all gates (the Phase 13 terminal success state; nothing executes). `:unsupported` is a runtime outcome, **not** a persisted status (per D-18). Reserve `:pending_approval` + approval-transition states for Phase 15 (they live on the new `ToolApproval` record per APRV-04, not as `ToolProposal` columns). Keep states distinct — never collapse into a generic "done" (Phase 12 D-17).
- **D-24:** **Snapshot at propose time into discrete, bounded, typed fields** — `input_snapshot`, `scope_snapshot`, `policy_snapshot`, plus `risk_tier`/`approval_mode`/`tool_ref`/`tool_version`. Each map holds one trust category; **no single opaque blob mixing trust levels** (Phase 12 D-08). This baseline is exactly what Phase 15 resume re-validates current scope/policy against.
- **D-25:** **Idempotency key lives on `ToolProposal`** (unique index), derived deterministically Stripe-style (e.g. `sha256(tool_ref:tool_version:actor_id:account_id:canonical_json(input):dedupe_window_token)`). A duplicate propose hits the unique constraint → return the existing proposal. Phase 16 derives a per-attempt run-level key from the proposal key, so worker retries stay idempotent without Phase 13 rework.
- **D-26:** Proposals are created **synchronously at propose time** inside a transaction (proposal + `proposal_created` event). **No Oban job, no execution in Phase 13.** Oban enters in Phase 15 (resume worker) / Phase 16 (execution with job uniqueness keyed on the run-level idempotency key).

### LiveView entrypoint change (TOOL-02)
- **D-27:** Replace the synchronous `execute_tool` handler in `ConversationLive` entirely with `Governance.propose(tool_ref, actor_id, context)`: **no `try/rescue`-around-execute, no `run/3` call, no optimistic UI.** `{:ok, _}` → calm flash "Proposed — pending review."; `{:blocked, outcome, reason}` → explicit operator-visible reason (mirror the existing `failure_reason_message/1` style). The handler persists/returns a proposal id so Phase 14 can swap the flash for a real timeline card without touching `Governance`.
- **D-28:** `ToolRegistry.get_available_tools/2` filters visible tools on `scope/0` + `authorize/2` (advisory UX only). `Governance.validate/3` re-checks authoritatively at propose time — **never trust the visibility filter as the gate.**

### Architecture & shift-left posture
- **D-29:** Keep the entire lane Cairnloop-owned inside Phoenix, Ecto, Oban, LiveView, and `:telemetry`. Durable Ecto records are workflow truth; **`:telemetry` is observability only** — emitted alongside, never instead of, `ToolActionEvent` inserts. Do not introduce a second workflow engine; do not force Scoria into the critical path (Phase 17 is an optional adapter).
- **D-30:** Public surface is a **narrow paved-road facade** (the `Cairnloop.Governance` context: `propose/3`, `validate/3`, and read helpers). Keep the pipeline internals, policy resolution, snapshot builders, and idempotency derivation hidden (Phase 10 D-04 posture).
- **D-31:** Shift ordinary implementation choices left into downstream research/planning. Re-escalate only decisions that materially affect trust semantics, the no-inline-execution boundary, the fail-closed contract, or milestone scope.

### Claude's Discretion
- Exact module/table names (recommended defaults: `Cairnloop.Governance` context; `Cairnloop.Governance.ToolProposal` / `ToolActionEvent`; tables `cairnloop_tool_proposals` / `cairnloop_tool_action_events`, consistent with `cairnloop_review_task*`). Whether the approval-mode resolver lives in `Cairnloop.Governance.Policy` vs `Cairnloop.Tool.Policy`. Names may change as long as there is one narrow public facade and the schema/contract *shapes* above hold.
- Exact `Spec` field names and macro option keys, idempotency-key composition details and `dedupe_window_token` choice, and the precise `policy_snapshot` map keys — as long as metadata stays declarative/serializable and snapshots stay bounded and typed.
- Exact `event_type` value names, reason/outcome copy, and flash wording — as long as outcomes stay distinct, fail-closed, and operator-legible, and stay separate from durable workflow truth.
- Whether `scope/0` is named `scope/0` or `required_scopes/0`, and the precise scope-comparison logic — as long as `scope_invalid` and `policy_denied` remain separately distinguishable and `authorize/2` is deny-by-default.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary and active requirements
- `.planning/ROADMAP.md` — Phase 13 goal + plans M011-S01-01/02/03, and Phases 14-17 (what Phase 13 must stay forward-compatible with).
- `.planning/REQUIREMENTS.md` — `TOOL-01`..`TOOL-04`, `MCP-01`, capability rubric ("risk tier"), proof posture (per-outcome policy-denial/missing-input/missing-scope tests; durable event-history tests), Support-Truth Gate (preserve proposal record), out-of-scope (confidence-score-only approval; inline LiveView/blocked-worker approval).
- `.planning/PROJECT.md` — vM011 posture: extend the M009/M010 trust model, host-owned governed-action lane, MCP/Scoria as optional edge adapters.
- `.planning/STATE.md` — carried-forward decisions (workflow truth in Phoenix/Ecto/Oban; durable records over telemetry; MCP as adapter seam) and the "replace synchronous `execute_tool`" pending todo this phase closes; environment caveat (`Cairnloop.Repo` may be unavailable in this workspace).

### Prior phase decisions that constrain Phase 13
- `.planning/phases/12-in-thread-quick-fix-ops-closure/12-CONTEXT.md` — D-08 (no opaque trust-mixing blob), D-11 (fail-closed with explicit blocked state), D-14/D-17 (durable truth vs telemetry; don't collapse distinct states), D-18 (Cairnloop-owned lane, no second workflow engine).
- `.planning/phases/10-citation-backed-draft-suggestions/10-CONTEXT.md` — D-04 (narrow paved-road public API; hide internals), D-22..D-25 (host-owned Ecto state, durable facts over UI annotations, bounded telemetry, shift-left re-escalation rule).

### Existing code seams (read before implementing)
- `lib/cairnloop/tool.ex` — the `Cairnloop.Tool` behaviour to evolve in place (callbacks: `can_execute?/2` → remove; `execute/3` → rename `run/3`; `changeset/2` keep; `custom_ui/0` keep; add `__tool_spec__/0`, `scope/0`, `authorize/2`, `preview/1`).
- `lib/cairnloop/tool_registry.ex` — registry reading `Application.get_env(:cairnloop, :tools, [])`; evolve to boot-time validation + `scope`/`authorize` visibility filtering.
- `lib/cairnloop/web/conversation_live.ex` (~line 173, `handle_event("execute_tool", ...)`) — the synchronous inline path to replace with `Governance.propose/3`; also the `available_tools`/`tool_renderer` rendering (~line 426/510).
- `lib/cairnloop/knowledge_automation/review_task.ex` and `lib/cairnloop/knowledge_automation/review_task_event.ex` — **the exact append-only-events + denormalized-status idiom to mirror** for `ToolProposal`/`ToolActionEvent`.
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` and its `evidence_snapshot` embedded schema — snapshot-at-decision-time + grounding-metadata precedent.
- `lib/cairnloop/retrieval/gap_event.ex` / gap-event snapshot — additional `Ecto.Enum` + snapshot-embedded-schema precedent.
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` — migration style (status enum, append-only event table, indexes, partial/unique indexes) to copy.
- `lib/cairnloop/knowledge_automation.ex` and `lib/cairnloop/retrieval.ex` — existing fail-closed return-shape patterns (explicit blocked outcomes) to stay consistent with.
- `lib/cairnloop/knowledge_automation/telemetry.ex` and `lib/cairnloop/telemetry.ex` — bounded low-cardinality telemetry contract to mirror for governed-action events.

### Product and research posture
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned Phoenix support architecture, evidence-vs-telemetry separation, DX posture.
- `prompts/cairnloop_brand_book.md` — "show your sources," "support that leaves a trail," calm fail-closed UX language for operator-visible blocked/proposed states.
- `prompts/parapet overview for integration ideas.txt` — bounded telemetry contract, evidence-vs-telemetry separation, host-owned operational philosophy.
- `prompts/scoria overview for integration ideas.txt` — optional evidence/governance lane (Phase 17), operator-first observability posture.
- `docs/cairnloop-jtbd-and-user-flows.md` — embedded support-cockpit framing and in-thread workflow this governed-action lane plugs into.

### External references surfaced during research (orientation, not requirements)
- `Oban.Worker` (hexdocs) — the declarative-opts + callbacks + introspection-accessor hybrid to model the tool contract on.
- Model Context Protocol tool schema (`modelcontextprotocol.io`) — the `{name, title, description, inputSchema, outputSchema}` shape `Spec` should project to in Phase 17.
- Stripe idempotency keys + brandur "Implementing Stripe-like Idempotency Keys in Postgres" — idempotency-key derivation/storage pattern.
- AWS IAM permission boundaries / GitHub environment protection rules / OPA PDP-PEP — orthogonal risk-vs-gate + snapshot-at-decision-time precedent.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.Tool` / `Cairnloop.ToolRegistry` — the contract + registry to evolve in place (no parallel contract).
- `ReviewTask` + `ReviewTaskEvent` — the proven append-only-events + denormalized-status + transactional-co-commit pattern to clone for `ToolProposal` + `ToolActionEvent`.
- `ArticleSuggestion.evidence_snapshot` (embedded schema) — propose-time snapshot precedent for `input_snapshot`/`scope_snapshot`/`policy_snapshot`.
- `KnowledgeAutomation` / `Retrieval` fail-closed return shapes — consistent explicit-blocked-outcome style for the `{:blocked, outcome, reason}` taxonomy.
- `KnowledgeAutomation.Telemetry` / `Cairnloop.Telemetry` — bounded low-cardinality telemetry to emit governed-action events through (observability only).

### Established Patterns
- Host-owned Ecto state as workflow truth; `:telemetry` strictly observability.
- `Ecto.Enum` value-lists as module attributes paired with derivation helpers.
- Append-only event table + denormalized status column, co-committed in one transaction.
- Oban-backed async work introduced only when execution/resume is needed (Phase 15/16), not for proposal creation.
- Calm, fail-closed, review-first operator UX with explicit reasons.

### Integration Points
- New `Cairnloop.Governance` context exposing `propose/3` (persisting) wrapping a pure re-callable `validate/3` (validation), reused by the Phase 15 resume worker.
- `ConversationLive.handle_event("execute_tool", ...)` → `Governance.propose/3` (no inline execution); proposal id returned for Phase 14 to render a card off.
- New migration adding `cairnloop_tool_proposals` + `cairnloop_tool_action_events` mirroring the review-task migration.
- Tool contract `__tool_spec__/0` as the single declarative source the facade reads for risk/approval/idempotency and that Phase 17 maps to MCP.

</code_context>

<specifics>
## Specific Ideas

- Model the tool contract on `Oban.Worker` (the host's existing mental model): declarative `use` opts as data + behaviour callbacks for logic + an introspection accessor.
- Keep `Spec` pure data specifically so the Phase 17 MCP seam is a projection, not a rewrite (MCP-01).
- Express fail-closed outcome precedence as the clause order of one `with` pipeline — the first failing gate wins, deterministically.
- Treat `:proposed` as honestly inert in Phase 13: even read-only tools create a record and show "Proposed — pending review," because execution is deliberately deferred to Phase 16. Don't fake a result.
- Reuse the GitHub/required-checks lesson: a gate failure is *recorded and visible* (a durable blocked proposal with a reason), never silently dropped — except a truly unknown tool name, which is telemetry-only to avoid junk-row cardinality.
- Snapshot policy/risk at propose time (AWS/OPA/GitHub all evaluate-then-record) so later policy edits never rewrite history.

</specifics>

<deferred>
## Deferred Ideas

- Separate `ToolRun` execution-attempt table, per-attempt idempotency keys, retry/backoff protections — Phase 16 (reserve `attempt`/`oban_job_id`/`result_state` columns now).
- `ToolApproval` record, one-active-approval-lane semantics, approve/reject/defer/expire transitions, append-only decision events, Oban resume + re-validation — Phase 15 (the `validate/3` pipeline and `resolve/3` approval seam are built to be re-called there).
- Operator timeline + human-readable preview card rendering (risk label, actor scope, consequence, evidence links) — Phase 14 (the `preview/1` callback and returned proposal id are the seam).
- Actual approved write execution + bounded execution telemetry alignment — Phase 16.
- Optional Scoria/OpenInference evidence hooks and the read-only MCP seam over the contract — Phase 17 (the pure-data `Spec` is the projection point).
- `:destructive`-tier execution and higher-risk/destructive mutations — deferred past vM011 (ACT-02); enum value declared now only for stability.
- Central host-authored policy DSL / OPA-style external policy — out of scope; the `resolve/3` resolver + per-tool `authorize/2` deny-by-default is the seam if a richer policy engine is ever wanted.

</deferred>

---

*Phase: 13-governed-tool-contract-proposal-records*
*Context gathered: 2026-05-23*
</content>
</invoke>
