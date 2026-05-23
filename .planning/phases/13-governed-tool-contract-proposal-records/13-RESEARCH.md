# Phase 13: Governed Tool Contract & Proposal Records - Research

**Researched:** 2026-05-23
**Domain:** Elixir/Phoenix/Ecto/Oban governed-action contract, durable proposal records, fail-closed validation pipeline
**Confidence:** HIGH (all findings drawn from direct codebase inspection + locked CONTEXT.md decisions)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All 31 decisions D-01..D-31 are locked. Exact module/table names are planner discretion; shapes are fixed. Key shape locks:
- D-01: Evolve `Cairnloop.Tool` in place — one governed contract, no parallel behaviour.
- D-02: `use Cairnloop.Tool, ...` carries declarative metadata; `__tool_spec__/0` returns `%Cairnloop.Tool.Spec{}`; validate enums at compile time, raise `CompileError` on bad value.
- D-03: Spec carries `risk_tier`, `approval_mode`, `idempotency`, `result_states`, `title`, `description` — pure data.
- D-04: Typed input stays as `changeset/2` Ecto embedded-schema callback.
- D-05: Rename `execute/3` → `run/3`; `run/3` NOT called in Phase 13.
- D-06: Remove `can_execute?/2`; add `scope/0`, `authorize/2` (deny-by-default), `preview/1` (optional); keep `custom_ui/0`.
- D-07: Validate each declared tool at boot (implements behaviour + valid `__tool_spec__/0`).
- D-08/D-09/D-10: Orthogonal `risk_tier` (`[:read_only,:low_write,:high_write,:destructive]`) + `approval_mode` (`[:auto,:requires_approval,:always_block]`).
- D-11: Fail-closed derivation: `read_only→:auto`, `low_write|high_write→:requires_approval`, `destructive→:always_block`, unknown/missing→`:always_block`.
- D-12: One resolver function (`tool override || host config || tier default`) is the Phase 15 seam.
- D-13: Host override is tighten-only by default.
- D-14: Snapshot resolved `risk_tier` + `approval_mode` + `policy_snapshot` at propose time.
- D-15: Central `Cairnloop.Governance` context with one re-callable pure `with` pipeline; persistence is a thin wrapper.
- D-16: Per-tool `scope/0` + `authorize/2` deny-by-default (`{:error, :no_policy_defined}`).
- D-17: Outcome taxonomy `{:ok, validated} | {:blocked, outcome, reason}`; precedence `unsupported→needs_input→scope_invalid→policy_denied`.
- D-18: Unknown tool name = telemetry-only, no row persisted.
- D-19: Resolve tools by matching registry modules, NOT `String.to_existing_atom/1`.
- D-20: Mirror `ReviewTask` + `ReviewTaskEvent` idiom exactly.
- D-21: Two schemas: `ToolProposal` + `ToolActionEvent` (append-only, `timestamps(updated_at: false)`, FK `on_delete: :delete_all`).
- D-22: Defer `ToolRun` to Phase 16; reserve `attempt`, `oban_job_id`, `result_state`, `result_summary` columns on `ToolProposal`.
- D-23: Phase 13 proposal statuses: `[:proposed,:needs_input,:scope_invalid,:policy_denied]`.
- D-24: Snapshot into discrete bounded typed fields: `input_snapshot`, `scope_snapshot`, `policy_snapshot`.
- D-25: Idempotency key on `ToolProposal` (unique index); duplicate → return existing.
- D-26: Proposal created synchronously in a transaction (proposal + `proposal_created` event). No Oban, no execution.
- D-27: Replace `execute_tool` handler with `Governance.propose/3`; `{:ok,_}→:info` flash; `{:blocked,outcome,reason}→:error` flash; return proposal id.
- D-28: Registry visibility filter is advisory only; `Governance.validate/3` is the gate.
- D-29: `:telemetry` observability only — alongside, never instead of, `ToolActionEvent` inserts.
- D-30: Narrow paved-road facade: `Cairnloop.Governance` with `propose/3`, `validate/3`, read helpers.
- D-31: Shift implementation choices left; re-escalate only trust/scope/fail-closed boundary issues.

### Claude's Discretion
- Exact module/table names (recommended: `Cairnloop.Governance`, `Cairnloop.Governance.ToolProposal`, `Cairnloop.Governance.ToolActionEvent`, tables `cairnloop_tool_proposals`/`cairnloop_tool_action_events`).
- Exact `Spec` field names and macro option keys.
- Idempotency key composition details and `dedupe_window_token` choice.
- Exact `policy_snapshot` map keys.
- Exact `event_type` value names, reason/outcome copy, flash wording.
- Whether `scope/0` is named `scope/0` or `required_scopes/0` — as long as `scope_invalid` and `policy_denied` are separately distinguishable and `authorize/2` is deny-by-default.

### Deferred Ideas (OUT OF SCOPE)
- Separate `ToolRun` execution-attempt table — Phase 16.
- `ToolApproval` record, approval state machine, Oban resume — Phase 15.
- Operator timeline, human-readable preview card rendering — Phase 14.
- Actual approved write execution + bounded execution telemetry — Phase 16.
- Optional Scoria/OpenInference evidence hooks, read-only MCP seam — Phase 17.
- `:destructive`-tier execution and high-risk/destructive mutations — deferred past vM011.
- Central host-authored policy DSL / OPA-style external policy — out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOOL-01 | Host developer can define a governed support tool with typed input validation, declared risk tier, approval mode, idempotency metadata, and structured result states. | Realized by evolving `Cairnloop.Tool` behaviour in place with `use Cairnloop.Tool, risk_tier: ..., approval_mode: ...` macro that generates `__tool_spec__/0`; compile-time enum validation raises `CompileError`; `changeset/2` for typed input. |
| TOOL-02 | System can propose a governed tool call from scoped conversation and account context without executing it inline. | `ConversationLive.handle_event("execute_tool",...)` → `Governance.propose/3` synchronous path; returns `{:ok, proposal}` or `{:blocked, outcome, reason}`; no `run/3` called. |
| TOOL-03 | Governed tool proposal fails closed with explicit `needs_input`, `scope_invalid`, `policy_denied`, or `unsupported` outcomes. | Central `with` pipeline in `Governance.validate/3` with explicit precedence; `unsupported` pre-persistence (telemetry only); all others persisted with reason. |
| TOOL-04 | Governed tool execution stores durable proposal and execution records plus append-only action events separate from transient UI state. | `ToolProposal` + `ToolActionEvent` schemas mirroring `ReviewTask`/`ReviewTaskEvent`; co-committed in one transaction; denormalized status + append-only event table. |
| MCP-01 | (Forward-compat seam only) Core governed-tool metadata can map cleanly to an optional read-only MCP seam. | Pure-data `%Cairnloop.Tool.Spec{}` is the projection point; Phase 17 maps `Spec` fields to MCP `{name, title, description, inputSchema, outputSchema}` with no model change. |
</phase_requirements>

---

## Summary

Phase 13 installs the governance foundations for the entire vM011 milestone. It has three interlocking deliverables: (1) evolving the thin `Cairnloop.Tool` behaviour in place into a full governed contract carrying compile-time declarative metadata; (2) adding the `Cairnloop.Governance` context with durable `ToolProposal` and append-only `ToolActionEvent` records that mirror the proven `ReviewTask`/`ReviewTaskEvent` idiom exactly; and (3) replacing the synchronous inline `execute_tool` LiveView path with a proposal-first, fail-closed call to `Governance.propose/3`.

Every decision is already locked in CONTEXT.md. The research value here is precision: exact current signatures the planner must design the cutover against, exact idioms to mirror, exact forward-compatibility seams to reserve but not build.

**Primary recommendation:** Follow the ReviewTask/ReviewTaskEvent idiom exactly — denormalized status column + separate append-only events table + co-committed `with` pipeline transaction — and model the `Cairnloop.Tool` contract on the `Oban.Worker` declarative-opts pattern.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Governed tool contract definition (behaviour + spec) | Library Core | — | Host-developer integration seam; compile-time artefact. |
| Tool registry boot-time validation | Application startup | — | `Cairnloop.Application` already initialises services; validation belongs here. |
| Proposal validation pipeline (`validate/3`) | `Cairnloop.Governance` context | Per-tool callbacks (`scope/0`, `authorize/2`, `changeset/2`) | Pure function, no DB; can be called from LiveView AND future Oban resume worker. |
| Proposal persistence (`propose/3`) | `Cairnloop.Governance` context | `Cairnloop.Repo` (via `Application.fetch_env!`) | Thin wrapper around `validate/3`; transaction inserts `ToolProposal` + `ToolActionEvent`. |
| LiveView entrypoint swap | `ConversationLive` handler | `Cairnloop.Governance` | Handler owns flash; Governance owns proposal truth. |
| Telemetry emission | `Cairnloop.Governance.Telemetry` | `Cairnloop.Telemetry` | Observability only; alongside, never instead of, durable records. |
| Approval-mode resolver | `Cairnloop.Governance.Policy` (or inline in `Governance`) | `Cairnloop.Tool.Spec` | Phase 15 seam: only this function is extended; no schema/call-site change needed later. |
| Schema/migration | `Cairnloop.Governance.ToolProposal` + `ToolActionEvent` | Ecto migration | Follows existing `cairnloop_review_task*` naming and structure. |

---

## Existing Code Seams

This is the highest-value section. The planner must design the cutover against the exact current shapes below.

### `lib/cairnloop/tool.ex` — Current `Cairnloop.Tool` behaviour

**Current callbacks (all 4):**

```elixir
@callback can_execute?(actor_id(), context()) :: boolean()
@callback execute(tool :: struct(), actor_id(), context()) :: {:ok, any()} | {:error, any()}
@callback changeset(tool :: struct(), attrs :: map()) :: Ecto.Changeset.t()
@callback custom_ui() :: module() | nil
```

**Current `use Cairnloop.Tool` macro (`__using__/1`):**
- Calls `use Ecto.Schema` and `import Ecto.Changeset` on the using module.
- Sets `@behaviour Cairnloop.Tool`.
- Provides a default `custom_ui/0` returning `nil` (overridable).
- Provides NO default for `can_execute?/2`, `execute/3`, or `changeset/2` — these are required by implementing tools.

**Phase 13 cutover (D-01 through D-07):**

| Current | Phase 13 |
|---------|----------|
| `can_execute?/2` | Remove entirely — replace with `scope/0` + `authorize/2` |
| `execute/3` | Rename to `run/3` (NOT called in Phase 13) |
| `changeset/2` | Keep as-is |
| `custom_ui/0` | Keep as-is (optional, defaults to `nil`) |
| `__using__(_opts)` | Evolve to `__using__(opts)` consuming `risk_tier:`, `approval_mode:`, `idempotency:`, `result_states:`, `title:`, `description:` as compile-time opts; generate `__tool_spec__/0` |
| — | Add `scope/0` callback (or `required_scopes/0`) |
| — | Add `authorize/2 :: :ok \| {:error, reason}` callback with default `{:error, :no_policy_defined}` |
| — | Add optional `preview/1` callback (Phase 14 seam) |

**Compile-time enum validation technique (D-02):**

```elixir
# In Cairnloop.Tool.__using__/1:
@valid_risk_tiers [:read_only, :low_write, :high_write, :destructive]
@valid_approval_modes [:auto, :requires_approval, :always_block]

defmacro __using__(opts) do
  risk_tier = Keyword.get(opts, :risk_tier)
  approval_mode = Keyword.get(opts, :approval_mode)

  # Validate at compile time — raises CompileError, not runtime error:
  if risk_tier && risk_tier not in @valid_risk_tiers do
    raise CompileError,
      description: "invalid risk_tier #{inspect(risk_tier)}, expected one of #{inspect(@valid_risk_tiers)}"
  end
  if approval_mode && approval_mode not in @valid_approval_modes do
    raise CompileError,
      description: "invalid approval_mode #{inspect(approval_mode)}, expected one of #{inspect(@valid_approval_modes)}"
  end

  derived_approval_mode = approval_mode || derive_approval_mode(risk_tier)

  quote do
    use Ecto.Schema
    import Ecto.Changeset
    @behaviour Cairnloop.Tool

    @__tool_spec__ %Cairnloop.Tool.Spec{
      risk_tier: unquote(risk_tier),
      approval_mode: unquote(derived_approval_mode),
      # ... other spec fields from opts
    }

    def __tool_spec__, do: @__tool_spec__

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: {:error, :no_policy_defined}

    @impl Cairnloop.Tool
    def custom_ui, do: nil

    defoverridable authorize: 2, custom_ui: 0
    # preview/1 is optional — do NOT add a default that raises;
    # mark as @optional_callbacks in the behaviour.
  end
end
```

The `derive_approval_mode/1` helper lives in the `Cairnloop.Tool` module (not a macro), callable at macro-expansion time:

```elixir
defp derive_approval_mode(:read_only), do: :auto
defp derive_approval_mode(:low_write), do: :requires_approval
defp derive_approval_mode(:high_write), do: :requires_approval
defp derive_approval_mode(:destructive), do: :always_block
defp derive_approval_mode(_), do: :always_block  # D-11 fail-closed default
```

**`%Cairnloop.Tool.Spec{}` struct (D-03, MCP-01 forward-compat):**

```elixir
defmodule Cairnloop.Tool.Spec do
  @enforce_keys [:risk_tier, :approval_mode]
  defstruct [
    :risk_tier,       # Ecto.Enum value — :read_only | :low_write | :high_write | :destructive
    :approval_mode,   # Ecto.Enum value — :auto | :requires_approval | :always_block
    :idempotency,     # atom or map — strategy for idempotency key derivation
    :result_states,   # list of atoms — declared result vocabulary for this tool
    :title,           # string — human-readable name (Phase 14 preview, Phase 17 MCP "title")
    :description      # string — operator description (Phase 17 MCP "description")
  ]
end
```

Pure data struct — no behaviour, no DB — directly projectable to MCP `{name, title, description, inputSchema, outputSchema}` in Phase 17 with zero model change.

---

### `lib/cairnloop/tool_registry.ex` — Current `Cairnloop.ToolRegistry`

**Current public API:**

```elixir
@spec get_available_tools(Cairnloop.Tool.actor_id(), Cairnloop.Tool.context()) :: [module()]
def get_available_tools(actor_id, context) do
  configured_tools = Application.get_env(:cairnloop, :tools, []) || []
  Enum.filter(configured_tools, fn tool_module ->
    tool_module.can_execute?(actor_id, context)
  end)
end
```

**Phase 13 cutover (D-07, D-19, D-28):**

1. `get_available_tools/2` must be updated to call `scope/0` + `authorize/2` instead of `can_execute?/2` (advisory UX filter only; `Governance.validate/3` is the authoritative gate).
2. Add `validate_configured_tools!/0` (called at boot) that iterates `Application.get_env(:cairnloop, :tools, [])` and checks each module implements `Cairnloop.Tool` behaviour AND `__tool_spec__/0` returns a valid `%Cairnloop.Tool.Spec{}`. Raises `ArgumentError` (or logs + halts) on failure.
3. Do NOT call `String.to_existing_atom/1` anywhere in the registry. Resolution from a string param uses `find_by_module_name/1` — matching `Atom.to_string(module)` against the configured list.

---

### `lib/cairnloop/web/conversation_live.ex` — `execute_tool` handler (line 173)

**Current handler (exact signature):**

```elixir
def handle_event("execute_tool", %{"tool" => tool_name} = params, socket)
```

**Current inline execution path (lines 173–205):**

```
1. String.to_existing_atom(tool_name)            ← SECURITY PROBLEM: D-19 removes this
2. tool_module.can_execute?(actor_id, context)    ← REMOVED in D-06
3. tool_module.changeset(struct(tool_module), tool_params)
4. if changeset.valid? → Ecto.Changeset.apply_changes → tool_module.execute(...)
5. try/rescue around execute                      ← REMOVED in D-27
6. {:ok, result} → put_flash(:info, result)
7. {:error, reason} → put_flash(:error, "Execution failed: #{inspect(reason)}")
8. rescue → put_flash(:error, "Tool execution failed: #{Exception.message(e)}")
```

**Phase 13 replacement (D-27):**

```elixir
def handle_event("execute_tool", %{"tool" => tool_ref} = params, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  context = socket.assigns.host_context

  case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
    {:ok, proposal} ->
      {:noreply, put_flash(socket, :info, "Proposed — pending review. (#{proposal.id})")}

    {:blocked, outcome, reason} ->
      {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}
  end
end
```

No `try/rescue`. No `run/3`. No `execute/3`. Returns `proposal.id` in the flash so Phase 14 can swap the flash for a real timeline card without touching `Governance`.

**`context_pane/1` component (lines 422–460):**
- Calls `Cairnloop.ToolRegistry.get_available_tools(assigns.actor_id, assigns.context)` at render time to populate `@available_tools` (advisory UX only).
- After Phase 13: this call still exists but filters on `scope/0` + `authorize/2` instead of `can_execute?/2`.

**`tool_renderer/1` component (lines 510–553):**
- Still passes `phx-click="execute_tool"` / `phx-submit="execute_tool"` as the event name.
- After Phase 13: the button still fires `execute_tool` — the handler is what changes, not the template event name (unless planner chooses to rename the event).
- `inspect(@tool)` is passed as `phx-value-tool` — this is the stringified module atom. The Phase 13 handler must resolve this string to a registry module without `String.to_existing_atom/1` (D-19).

---

### `lib/cairnloop/knowledge_automation/review_task.ex` + `review_task_event.ex` — Idiom to mirror exactly

**`ReviewTask` schema key patterns:**
- Status stored as `Ecto.Enum, values: @status_values` — `@status_values` is a module attribute list.
- Denormalized last-decision fields: `last_decision`, `last_reason`, `last_actor_id`, `last_decided_at`, `notes`.
- `has_many(:events, ReviewTaskEvent)`.
- Public accessor for enum value lists: `def status_values, do: @status_values`.
- Multiple named changesets for different transitions (`changeset/2`, `decision_changeset/6`).
- Partial unique index to enforce one-active-task semantics.

**`ReviewTaskEvent` schema key patterns:**
- `timestamps(type: :utc_datetime_usec, updated_at: false)` — append-only enforced by omitting `updated_at`.
- FK: `belongs_to(:review_task, ReviewTask)` with migration `on_delete: :delete_all`.
- `@event_type_values` list; `from_status`/`to_status` reference `ReviewTask.status_values()` (cross-schema enum reference).
- `changeset/2` requires `[:review_task_id, :event_type, :to_status, :actor_id]`.
- No `update/1` function — insert-only.
- `metadata` field: `:map` type, default `%{}`, validated to be a map.

**`update_task_with_event/3-4` transaction co-commit pattern (line 1771):**

```elixir
defp update_task_with_event(task, changeset, event_attrs, result_type \\ :ok) do
  with {:ok, updated_task} <- repo().update(changeset),
       {:ok, _event} <-
         %ReviewTaskEvent{}
         |> ReviewTaskEvent.changeset(Map.put(event_attrs, :review_task_id, task.id))
         |> repo().insert() do
    emit_review_task_event(updated_task, task, event_attrs)
    {result_type, updated_task}
  end
end
```

Key observations for `ToolProposal` + `ToolActionEvent`:
- Uses `with` — both the update and the event insert must succeed or the `with` short-circuits.
- Uses raw `repo().update` + `repo().insert` — NOT `Ecto.Multi` — for the two operations. This is intentional: `with` provides composable error propagation without a Multi wrapper.
- Telemetry emitted AFTER the successful `with` chain — never inside it.
- The `result_type` param allows callers to return `{:error, updated_task}` for fail-record-update paths (used in `approve_review_task` draft-conflict arm).

For `ToolProposal` the initial creation path differs slightly — it is an INSERT of both the proposal and the `proposal_created` event:

```elixir
defp insert_proposal_with_event(proposal_attrs, event_attrs) do
  with {:ok, proposal} <-
         %ToolProposal{}
         |> ToolProposal.changeset(proposal_attrs)
         |> repo().insert(),
       {:ok, _event} <-
         %ToolActionEvent{}
         |> ToolActionEvent.changeset(Map.put(event_attrs, :tool_proposal_id, proposal.id))
         |> repo().insert() do
    emit_proposal_telemetry(proposal, event_attrs)
    {:ok, proposal}
  end
end
```

---

### `lib/cairnloop/knowledge_automation/article_suggestion.ex` — Snapshot precedent

**`embeds_many(:evidence_snapshot, ArticleSuggestionEvidence, on_replace: :delete)`** is the snapshot-at-propose-time precedent.

For `ToolProposal`, D-24 uses **discrete bounded typed fields** (not `embeds_many`) because the three snapshot categories map to three trust levels:

```elixir
field(:input_snapshot, :map, default: %{})     # validated tool input at propose time
field(:scope_snapshot, :map, default: %{})     # actor scope values at propose time
field(:policy_snapshot, :map, default: %{})    # policy resolution provenance at propose time
```

Each map is bounded by the `changeset/2` validators (no opaque blob). `policy_snapshot` should include at minimum `%{"resolution_source" => "tier_default|host_config|tool_override", "policy_version" => "..."}`.

---

### `lib/cairnloop/retrieval/gap_event.ex` — Additional `Ecto.Enum` + embedded-schema precedent

**Key patterns:**
- `@outcome_values`, `@reason_values` as module-level attributes, referenced in `Ecto.Enum, values: @outcome_values`.
- `embeds_many(:attempted_evidence_snapshots, GapEventSnapshot, on_replace: :delete)`.
- `timestamps(updated_at: false)` — the gap event table is also append-only (same technique as `ReviewTaskEvent`).
- Integer bounds: `validate_number(:canonical_hit_count, greater_than_or_equal_to: 0)`.
- Cardinality bound on embeds: custom `validate_change` checking `length(snapshots) <= @max_snapshots`.

The Phase 13 `ToolActionEvent` metadata field should follow this bounded-cardinality discipline: the `:map` field is shallow and bounded (not a nested blob). No unbounded lists inside the metadata map.

---

### Migration style (from `20260522093000_add_review_tasks_and_events.exs`)

**Exact template for the new migration:**

```elixir
defmodule Cairnloop.Repo.Migrations.AddToolProposalsAndActionEvents do
  use Ecto.Migration

  def change do
    create table(:cairnloop_tool_proposals) do
      # core identity
      add(:tool_ref, :string, null: false)         # stringified module name
      add(:tool_version, :string)                   # optional tool version tag
      add(:idempotency_key, :string, null: false)  # D-25: unique index

      # governance snapshot fields (D-24)
      add(:risk_tier, :string, null: false)
      add(:approval_mode, :string, null: false)
      add(:input_snapshot, :map, null: false, default: %{})
      add(:scope_snapshot, :map, null: false, default: %{})
      add(:policy_snapshot, :map, null: false, default: %{})

      # denormalized status (D-23)
      add(:status, :string, null: false, default: "proposed")

      # actor
      add(:actor_id, :string, null: false)
      add(:account_id, :string)   # for idempotency key scope and future multi-tenancy

      # Phase 16 seam columns (D-22) — reserved now, unused in Phase 13
      add(:attempt, :integer, null: false, default: 0)
      add(:oban_job_id, :integer)
      add(:result_state, :string, null: false, default: "not_executed")
      add(:result_summary, :string)

      timestamps(type: :utc_datetime_usec)
    end

    # D-25: idempotency unique constraint
    create(unique_index(:cairnloop_tool_proposals, [:idempotency_key]))

    # query indexes
    create(index(:cairnloop_tool_proposals, [:status, :inserted_at]))
    create(index(:cairnloop_tool_proposals, [:actor_id, :status]))
    create(index(:cairnloop_tool_proposals, [:tool_ref, :inserted_at]))

    create table(:cairnloop_tool_action_events) do
      add(:tool_proposal_id,
        references(:cairnloop_tool_proposals, on_delete: :delete_all), null: false)

      add(:event_type, :string, null: false)
      add(:from_status, :string)                    # nil for proposal_created
      add(:to_status, :string, null: false)
      add(:actor_id, :string, null: false)
      add(:reason, :string)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)  # append-only
    end

    create(index(:cairnloop_tool_action_events, [:tool_proposal_id, :inserted_at]))
    create(index(:cairnloop_tool_action_events, [:event_type, :inserted_at]))
  end
end
```

**Key migration style notes (from existing template):**
- Status enums stored as `:string` (not Postgres `ENUM` type) — Ecto.Enum validates in app.
- Append-only enforced by `timestamps(updated_at: false)` on the events table.
- FK `on_delete: :delete_all` so deleting a proposal cascades event cleanup.
- No Postgres partial index for Phase 13 proposals (unlike the one-active-task-per-suggestion partial unique index in ReviewTask) — the `idempotency_key` unique index provides the duplicate-prevention semantics.

---

### `lib/cairnloop/knowledge_automation.ex` + `lib/cairnloop/retrieval.ex` — Fail-closed return shapes

**`KnowledgeAutomation` pattern:**
- Public functions return `{:ok, result}` or `{:error, reason}`.
- No generic `{:error, :unknown}` — always a bounded reason atom.
- Fail-closed functions that cannot proceed return `{:error, :specific_reason}` not `false` or `nil`.

**`Retrieval.search/2` validate_scope pattern:**

```elixir
case validate_scope(opts) do
  :ok -> # proceed
  {:error, reason} -> {:error, reason}
end
```

**Phase 13 `Governance.validate/3` consistent shape:**

```elixir
# Return taxonomy (D-17):
{:ok, validated_proposal_attrs}          # all gates passed
{:blocked, :unsupported, reason}         # unknown tool — telemetry only, no DB row
{:blocked, :needs_input, reason}         # changeset invalid
{:blocked, :scope_invalid, reason}       # scope/0 check failed
{:blocked, :policy_denied, reason}       # authorize/2 returned {:error, _}
```

The `with` pipeline clause order enforces precedence deterministically — first failure wins:

```elixir
def validate(tool_ref, actor_id, context) do
  with {:ok, tool_module} <- resolve_tool(tool_ref),                  # gate 0: unsupported
       {:ok, input} <- validate_input(tool_module, context),           # gate 1: needs_input
       :ok <- check_scope(tool_module, actor_id, context),             # gate 2: scope_invalid
       :ok <- tool_module.authorize(actor_id, context) do              # gate 3: policy_denied
    {:ok, build_validated_attrs(tool_module, input, actor_id, context)}
  else
    {:error, :unknown_tool} -> {:blocked, :unsupported, :unknown_tool}
    {:error, :invalid_input, cs} -> {:blocked, :needs_input, cs}
    {:error, :scope_mismatch, reason} -> {:blocked, :scope_invalid, reason}
    {:error, reason} -> {:blocked, :policy_denied, reason}             # catch-all for authorize/2
  end
end
```

---

### `lib/cairnloop/knowledge_automation/telemetry.ex` + `lib/cairnloop/telemetry.ex` — Telemetry contract to mirror

**`Cairnloop.Telemetry` base layer:**
- `execute/3` wraps `:telemetry.execute([:cairnloop | event_suffix], measurements, metadata)`.
- `span/3` wraps `:telemetry.span([:cairnloop | event_suffix], metadata, fun)`.

**`KnowledgeAutomation.Telemetry` bounded metadata pattern:**
- Event name is a list: `[:cairnloop, :knowledge_automation, :gap_candidate]`.
- `metadata/2` normalizes every field against an allowed-values list, defaulting to `:unspecified` for unknown atoms.
- `normalize_count/1` caps integer values at 99 to avoid unbounded cardinality.
- Public `event_name/1` helper returns the full event list for handler registration.

**`Cairnloop.Governance.Telemetry` equivalent to build:**

```elixir
@events [:proposal_created, :proposal_blocked, :proposal_duplicate]
@allowed_outcomes [:proposed, :needs_input, :scope_invalid, :policy_denied, :unsupported, :duplicate]
@allowed_risk_tiers [:read_only, :low_write, :high_write, :destructive, :unknown]
@allowed_approval_modes [:auto, :requires_approval, :always_block, :unknown]

def emit(event, measurements, metadata) when event in @events do
  Cairnloop.Telemetry.execute(
    [:governance, event],
    normalize_measurements(measurements),
    metadata(event, metadata)
  )
end
```

Emitted alongside `ToolActionEvent` inserts, NEVER instead of them (D-29).

---

### Oban dependency confirmation

`mix.exs` line 31: `{:oban, "~> 2.17"}` — confirmed present. [VERIFIED: codebase grep]

The `Oban.Worker` pattern used in `DraftWorker` (`use Oban.Worker, queue: :default, unique: [...], replace: [...]`) is the mental model for `use Cairnloop.Tool, risk_tier: ..., approval_mode: ...` — declarative opts at the `use` call, behaviour callbacks for logic, introspection accessor (`__tool_spec__/0` mirrors `__oban_opts__/0`).

---

## Recommended Implementation Approach

### S01-01: Extend the Tool Contract

**File:** `lib/cairnloop/tool.ex` (evolved in place)
**New file:** `lib/cairnloop/tool/spec.ex` (`%Cairnloop.Tool.Spec{}` pure data struct)

1. Define `%Cairnloop.Tool.Spec{}` as a plain struct (no Ecto) with `@enforce_keys [:risk_tier, :approval_mode]`.
2. Define the new behaviour callbacks: `run/3`, `changeset/2`, `scope/0` (or `required_scopes/0`), `authorize/2`, `custom_ui/0`, `preview/1` (optional via `@optional_callbacks`).
3. Evolve `__using__(opts)` as a macro:
   - Extract `risk_tier`, `approval_mode`, `idempotency`, `result_states`, `title`, `description` from `opts`.
   - Validate `risk_tier` and `approval_mode` at **macro-expansion time** using `raise CompileError`. This runs during `mix compile`, not at runtime.
   - Derive `approval_mode` from `risk_tier` if not provided (D-11).
   - Generate `def __tool_spec__/0` returning the frozen `%Spec{}`.
   - Inject default impls: `authorize/2` → `{:error, :no_policy_defined}` (D-16), `custom_ui/0` → `nil`.
   - Mark `preview/1` as `@optional_callbacks` (no default — Phase 14 seam).
4. Do NOT remove `can_execute?/2` from the behaviour silently — remove it AND update the single existing tool reference in `ToolRegistry` (the only caller). The compiler will catch any missed callsite.

**Compile-time `CompileError` test pattern:**

```elixir
# In test:
assert_raise CompileError, ~r/invalid risk_tier/, fn ->
  Code.compile_string("""
  defmodule BadTool do
    use Cairnloop.Tool, risk_tier: :explodes
    def changeset(s, a), do: s
    def run(s, i, c), do: {:ok, nil}
    def scope, do: []
  end
  """)
end
```

### S01-02: Durable Records + Governance Facade

**New files:**
- `lib/cairnloop/governance.ex` — public facade (`propose/3`, `validate/3`, read helpers)
- `lib/cairnloop/governance/tool_proposal.ex` — `ToolProposal` schema
- `lib/cairnloop/governance/tool_action_event.ex` — `ToolActionEvent` schema
- `lib/cairnloop/governance/policy.ex` — approval-mode resolver (Phase 15 seam)
- `lib/cairnloop/governance/telemetry.ex` — bounded governance telemetry
- `priv/repo/migrations/TIMESTAMP_add_tool_proposals_and_action_events.exs`

**`ToolProposal` schema — `Ecto.Enum` values:**

```elixir
@status_values [:proposed, :needs_input, :scope_invalid, :policy_denied]
@risk_tier_values [:read_only, :low_write, :high_write, :destructive]
@approval_mode_values [:auto, :requires_approval, :always_block]
@result_state_values [:not_executed, :succeeded, :failed]

schema "cairnloop_tool_proposals" do
  field(:tool_ref, :string)
  field(:tool_version, :string)
  field(:idempotency_key, :string)
  field(:status, Ecto.Enum, values: @status_values, default: :proposed)
  field(:risk_tier, Ecto.Enum, values: @risk_tier_values)
  field(:approval_mode, Ecto.Enum, values: @approval_mode_values)
  field(:actor_id, :string)
  field(:account_id, :string)
  field(:input_snapshot, :map, default: %{})
  field(:scope_snapshot, :map, default: %{})
  field(:policy_snapshot, :map, default: %{})
  # Phase 16 reserved (D-22)
  field(:attempt, :integer, default: 0)
  field(:oban_job_id, :integer)
  field(:result_state, Ecto.Enum, values: @result_state_values, default: :not_executed)
  field(:result_summary, :string)

  has_many(:events, Cairnloop.Governance.ToolActionEvent)
  timestamps(type: :utc_datetime_usec)
end
```

**`ToolActionEvent` schema:**

```elixir
@event_type_values [:proposal_created, :proposal_blocked]

schema "cairnloop_tool_action_events" do
  field(:event_type, Ecto.Enum, values: @event_type_values)
  field(:from_status, Ecto.Enum, values: ToolProposal.status_values())
  field(:to_status, Ecto.Enum, values: ToolProposal.status_values())
  field(:actor_id, :string)
  field(:reason, :string)
  field(:metadata, :map, default: %{})

  belongs_to(:tool_proposal, ToolProposal)
  timestamps(type: :utc_datetime_usec, updated_at: false)  # append-only
end
```

**`Governance.propose/3` — synchronous transaction (D-26):**

```elixir
def propose(tool_ref, actor_id, context) do
  case validate(tool_ref, actor_id, context) do
    {:ok, validated} ->
      case idempotency_check_or_insert(validated) do
        {:ok, proposal} -> {:ok, proposal}
        {:error, :duplicate, existing} -> {:ok, existing}   # D-25 duplicate handling
        {:error, reason} -> {:blocked, :needs_input, reason}
      end

    {:blocked, :unsupported, reason} = blocked ->
      emit_telemetry(:proposal_blocked, %{outcome: :unsupported, reason: reason})
      blocked  # no DB row (D-18)

    {:blocked, outcome, reason} = blocked ->
      insert_blocked_proposal(outcome, reason, tool_ref, actor_id, context)
      blocked
  end
end
```

**Idempotency key derivation (D-25 Stripe-style):**

```elixir
defp derive_idempotency_key(tool_ref, actor_id, account_id, input, dedupe_token) do
  payload = Jason.encode!(%{
    tool_ref: tool_ref,
    actor_id: actor_id,
    account_id: account_id,
    input: sort_map_keys(input),   # canonical form
    dedupe_token: dedupe_token     # caller-supplied or derived from conversation context
  })
  :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
end
```

Duplicate detection: `repo().insert(changeset, on_conflict: :nothing, returning: true)` returns the existing row on unique constraint hit, OR use a `try/rescue` around the `Ecto.ConstraintError`. The `on_conflict: :nothing` approach is cleaner and avoids exception handling.

**Idempotency `on_conflict` pattern:**

```elixir
case repo().insert(changeset, on_conflict: :nothing, returning: true) do
  {:ok, %ToolProposal{id: nil}} ->
    # Row existed — fetch and return the existing proposal
    {:ok, :duplicate, repo().get_by!(ToolProposal, idempotency_key: key)}
  {:ok, proposal} ->
    {:ok, proposal}
  {:error, cs} ->
    {:error, cs}
end
```

**`Governance.Policy` — approval-mode resolver (D-12, Phase 15 seam):**

```elixir
defmodule Cairnloop.Governance.Policy do
  def resolve(tool_module, _actor_id, _context) do
    spec = tool_module.__tool_spec__()
    # Today: tool declaration wins over host config wins over tier default.
    # Phase 15 extends ONLY this function to factor in actor scope + runtime context.
    spec.approval_mode || host_config_override(spec.risk_tier) || derive_approval_mode(spec.risk_tier)
  end

  defp host_config_override(risk_tier) do
    overrides = Application.get_env(:cairnloop, :approval_mode_overrides, %{})
    Map.get(overrides, risk_tier)
  end
end
```

### S01-03: Replace `execute_tool` LiveView Entrypoint

**File:** `lib/cairnloop/web/conversation_live.ex`

Changes:
1. Replace `handle_event("execute_tool", ...)` body entirely — no try/rescue, no `run/3`.
2. Update `context_pane/1` to call `get_available_tools/2` which now uses `scope/0`+`authorize/2`.
3. Remove the `String.to_existing_atom(tool_name)` call — the new handler passes `tool_ref` string directly to `Governance.propose/3`, which resolves via registry module matching.
4. Add a `failure_reason_message/2` private function for `{outcome, reason}` pairs to mirror the existing `failure_reason_message/1` style in `KnowledgeAutomation`.

**Boot-time validation wiring:**

In `lib/cairnloop/application.ex` (or wherever `Cairnloop.Application` is defined), call `Cairnloop.ToolRegistry.validate_configured_tools!()` during startup so a misconfigured tool fails fast at boot, not at first user interaction.

---

## Forward-Compatibility Seams

### Phase 14 (Operator Timeline)
- `Governance.propose/3` returns `{:ok, proposal}` including `proposal.id` — the LiveView handler stores/flashes this id.
- Phase 14 swaps the flash for a timeline card using the proposal id without touching `Governance`.
- `preview/1` optional callback on the tool is the seam for human-readable consequence text.

### Phase 15 (Approval State Machine + Oban Resume)
- `Governance.validate/3` is a **pure function** — no side effects, no DB. The Phase 15 resume worker calls it directly against current context: `Governance.validate(proposal.tool_ref, actor_id, current_context)`. No new validation path needed.
- `Governance.Policy.resolve/3` is the **only** function Phase 15 extends to factor in actor scope + runtime context (PDP). No schema or call-site change.
- `ToolProposal` statuses `:proposed`, `:needs_input`, `:scope_invalid`, `:policy_denied` are Phase 13 terminal states. Phase 15 adds `:pending_approval` and related states to a new `ToolApproval` record (not to `ToolProposal` columns directly — per APRV-04).

### Phase 16 (Execution)
- `attempt`, `oban_job_id`, `result_state`, `result_summary` columns on `ToolProposal` are reserved but unused in Phase 13. Phase 16 updates them without schema migration for most fields (columns already exist).
- The idempotency key on `ToolProposal` is the parent key. Phase 16 derives per-attempt run-level keys as `sha256(proposal_idempotency_key + ":" + attempt_number)`.
- `ToolActionEvent` `event_type` enum will be extended with execution events (`:execution_started`, `:execution_succeeded`, `:execution_failed`) — adding to `@event_type_values` is a non-breaking migration.

### Phase 17 (MCP Seam)
- `%Cairnloop.Tool.Spec{}` fields map directly to MCP `tool` definition: `title` → `title`, `description` → `description`, tool module name → `name`, `changeset/2` Ecto embedded schema → `inputSchema` (JSON Schema projection). Zero model change needed.
- The projection function in Phase 17 will be a pure `Spec` → map transformation with no behaviour or DB involvement.

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from `.planning/config.json` — treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in to Elixir/OTP) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/cairnloop/governance/` |
| Full suite command | `mix test` |

### DB Availability Context

`Cairnloop.Repo` is unavailable in this workspace. All tests must use the established **MockRepo pattern** (as demonstrated in `review_task_test.exs`) — a `MockRepo` module using `Process.get/put` for in-process state, injected via `Application.put_env(:cairnloop, :repo, MockRepo)` in test setup.

**What can be proven without a live DB (most tests):**
- `ToolProposal` changeset validity, enum validation, required-field enforcement.
- `ToolActionEvent` changeset insert-only semantics.
- `Governance.validate/3` pure pipeline: all four fail-closed outcomes with correct precedence.
- Compile-time `CompileError` for invalid enum values.
- `authorize/2` deny-by-default.
- `scope/0` scope-mismatch detection.
- Idempotency key determinism (same inputs → same key, different inputs → different key).
- Tool registry module-resolution safety (no `String.to_existing_atom/1`).
- Telemetry metadata boundedness (validate `metadata/2` output has no unknown atoms).

**What requires a live DB (deferred or environment-blocked):**
- Full `Governance.propose/3` integration (inserts + transaction).
- Idempotency unique-constraint duplicate detection via `on_conflict: :nothing`.
- Append-only enforcement at the DB level (no UPDATE on event rows).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-01 | `use Cairnloop.Tool, risk_tier: :bad` raises `CompileError` | unit | `mix test test/cairnloop/tool_test.exs::compile_error` | ❌ Wave 0 |
| TOOL-01 | Valid spec fields frozen on `__tool_spec__/0` | unit | `mix test test/cairnloop/tool_test.exs` | ❌ Wave 0 |
| TOOL-01 | `authorize/2` default returns `{:error, :no_policy_defined}` | unit | `mix test test/cairnloop/tool_test.exs` | ❌ Wave 0 |
| TOOL-02 | `Governance.propose/3` returns `{:ok, proposal}` for valid tool + actor | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-02 | `ConversationLive` handle_event no longer calls `execute/3` or `run/3` | unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 |
| TOOL-03 | `validate/3` returns `{:blocked, :unsupported, _}` for unknown tool, no DB row | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-03 | `validate/3` returns `{:blocked, :needs_input, _}` for invalid changeset | unit | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-03 | `validate/3` returns `{:blocked, :scope_invalid, _}` when scope not met | unit | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-03 | `validate/3` returns `{:blocked, :policy_denied, _}` when `authorize/2` rejects | unit | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-03 | Outcome precedence: scope_invalid before policy_denied (inject both failures) | unit | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-04 | `ToolProposal` changeset valid with required fields, rejects unknown statuses | unit | `mix test test/cairnloop/governance/tool_proposal_test.exs` | ❌ Wave 0 |
| TOOL-04 | `ToolActionEvent` changeset insert-only; no `updated_at` field | unit | `mix test test/cairnloop/governance/tool_action_event_test.exs` | ❌ Wave 0 |
| TOOL-04 | `propose/3` co-commits proposal + event in one transaction (MockRepo) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |
| TOOL-04 | Duplicate idempotency key returns existing proposal (MockRepo) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/governance/ test/cairnloop/tool_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps (all test files are new — none exist)

- [ ] `test/cairnloop/tool_test.exs` — covers TOOL-01: compile-time enum validation, `__tool_spec__/0` frozen, `authorize/2` deny-by-default
- [ ] `test/cairnloop/governance_test.exs` — covers TOOL-02/TOOL-03/TOOL-04: all four `validate/3` outcomes with correct precedence, `propose/3` co-commit, idempotency duplicate
- [ ] `test/cairnloop/governance/tool_proposal_test.exs` — covers TOOL-04: changeset validations, Ecto.Enum bounds, snapshot fields
- [ ] `test/cairnloop/governance/tool_action_event_test.exs` — covers TOOL-04: append-only changeset, insert-only API
- [ ] `test/cairnloop/web/conversation_live_test.exs` — covers TOOL-02: handler no longer calls `execute/3`

---

## Risks / Pitfalls / Landmines

### Pitfall 1: `String.to_existing_atom/1` Atom Cardinality (D-19)

**What goes wrong:** The current `execute_tool` handler (line 174) calls `String.to_existing_atom(tool_name)` where `tool_name` comes from the form `phx-value-tool={inspect(@tool)}`. `inspect(MyTool)` returns `"Elixir.MyTool"`. `String.to_existing_atom/1` will work for known modules but is a footgun: if the UI is ever manipulated with an unknown string, it raises `ArgumentError`. More critically, it signals "resolve arbitrary strings to atoms" which is the anti-pattern D-19 replaces.

**How to avoid:** In `Governance.validate/3`, gate 0 (`resolve_tool/1`) iterates the configured registry list and matches `Atom.to_string(module) == tool_ref`. Unknown string → `{:error, :unknown_tool}`. No atom creation from untrusted input.

**Warning signs:** Any use of `String.to_existing_atom` or `String.to_atom` in the governance code path.

---

### Pitfall 2: Telemetry vs. Durable Record Confusion (D-29)

**What goes wrong:** Emitting a telemetry event instead of — or as a substitute for — inserting a `ToolActionEvent` row. This is the Support-Truth Gate failure mode: the telemetry event is transient (restart = lost); the DB row is the audit trail.

**How to avoid:** Always insert the `ToolActionEvent` row first (inside the `with` pipeline). Emit telemetry AFTER the `with` succeeds, as `KnowledgeAutomation.update_task_with_event/3` does: `emit_review_task_event(updated_task, task, event_attrs)` is called after the `with` block, not inside it.

**Warning signs:** Any function that emits telemetry but has a code path that skips the DB insert.

---

### Pitfall 3: Snapshot Drift (D-14/D-24)

**What goes wrong:** Reading `tool_module.__tool_spec__()` at approval/render time (Phase 14+) instead of reading the `risk_tier`/`approval_mode`/`policy_snapshot` from the persisted `ToolProposal`. If the host changes a tool's `risk_tier` between proposal and approval, the live spec reflects the new tier but the proposal record reflects what was true at propose time. History is correct; live re-read is misleading.

**How to avoid:** At propose time, snapshot the resolved values into `ToolProposal` fields. All downstream reads of "what tier/mode applied to this proposal?" read from the row, never from `__tool_spec__/0`. The `validate/3` pipeline is the ONLY place that reads live spec; `propose/3` then snapshots the result.

**Warning signs:** Any Phase 14/15/16 code that calls `tool_module.__tool_spec__().risk_tier` to render a proposal's risk label.

---

### Pitfall 4: Append-Only Enforcement by Discipline

**What goes wrong:** Because Ecto does not have a "no-update" column constraint at the ORM level, the append-only guarantee of `ToolActionEvent` is enforced only by application discipline — no `update/1` or `delete/1` function in the public API. A developer adds a "fix event" helper that calls `repo().update` on an event row.

**How to avoid:** The `ToolActionEvent` module exposes only `changeset/2` (for inserts) and no update/delete functions. The `Cairnloop.Governance` context's public API has no function that updates or deletes `ToolActionEvent` rows. Document this as an append-only invariant in the module doc.

**Warning signs:** Any `repo().update` call that takes a `ToolActionEvent` struct.

---

### Pitfall 5: Compile-Time vs Runtime Validation Boundary

**What goes wrong:** Moving enum validation from compile time to runtime — e.g., using `if risk_tier not in @valid_risk_tiers, do: raise RuntimeError` inside a `def` instead of inside the `defmacro __using__` body. Runtime validation means a misconfigured tool compiles fine and fails only when first used.

**How to avoid:** The validation logic (`if risk_tier && risk_tier not in @valid_risk_tiers, do: raise CompileError`) must live inside the `defmacro __using__(opts)` body, BEFORE the `quote do...end` block. This runs at compile time when the tool module is compiled. The `raise CompileError` path also shows up in `mix compile` output, not in test failures.

**Warning signs:** Tests that verify bad enums by calling a runtime function rather than by compiling a string with `Code.compile_string/1` and asserting `CompileError`.

---

### Pitfall 6: `on_conflict: :nothing` Returns `{:ok, struct_with_nil_id}`

**What goes wrong:** Ecto's `repo().insert(changeset, on_conflict: :nothing, returning: true)` returns `{:ok, struct}` on conflict where the struct has `id: nil` (not all adapter versions behave identically). If the caller just pattern-matches `{:ok, proposal}` and uses `proposal.id`, it gets `nil`.

**How to avoid:** After `insert(on_conflict: :nothing)`, check `proposal.id == nil` as the duplicate signal and fetch the existing row via `repo().get_by!(ToolProposal, idempotency_key: key)`. Alternatively, use a `unique_constraint` changeset validator and catch `{:error, %Ecto.Changeset{errors: [idempotency_key: {"has already been taken", _}]}}` — then fetch and return the existing row.

**Warning signs:** `{:ok, %ToolProposal{id: nil}}` reaching a caller that dereferences `proposal.id`.

---

### Pitfall 7: The `:unsupported` Outcome Must Never Touch the DB (D-18)

**What goes wrong:** Persisting a `ToolProposal` row with `status: :proposed` or any other status when the `tool_ref` string does not resolve to a known governed tool. This allows an attacker (or buggy code) to fill `cairnloop_tool_proposals` with junk rows keyed on arbitrary strings.

**How to avoid:** Gate 0 of `validate/3` is the `resolve_tool/1` step — if it returns `{:error, :unknown_tool}`, `propose/3` emits telemetry and returns `{:blocked, :unsupported, :unknown_tool}` with no DB insert. This must be the first gate in the `with` pipeline. Do NOT insert a "blocked/unsupported" proposal row.

**Warning signs:** Any code path in `propose/3` that calls `repo().insert` before checking that the tool module resolved successfully.

---

### Pitfall 8: `inspect(@tool)` in the LiveView Template Produces Quoted Module Strings

**What goes wrong:** The existing `tool_renderer/1` component (line 528) passes `phx-value-tool={inspect(@tool)}` which produces `"Elixir.MyApp.Tools.RefundTool"` (the full qualified atom string). The Phase 13 handler receives this string as `tool_ref`. The registry resolver must match on `Atom.to_string(module)` which also produces `"Elixir.MyApp.Tools.RefundTool"` — these will match correctly.

**How to avoid:** Verify the string format explicitly. `Atom.to_string(MyApp.Tools.RefundTool)` == `"Elixir.MyApp.Tools.RefundTool"` == `inspect(MyApp.Tools.RefundTool)`. They are the same string. The test should assert `resolve_tool("Elixir.MyApp.Tools.RefundTool")` returns the correct module.

**Warning signs:** Using `Module.safe_concat/1` or `String.split(".", ...)` to reconstruct a module atom — these are unnecessary and error-prone given the direct string comparison approach.

---

## Standard Stack

No new external dependencies required. Phase 13 is pure Elixir/Phoenix/Ecto/Oban idioms.

| Library | Version (in mix.exs) | Purpose in Phase 13 |
|---------|---------------------|---------------------|
| `ecto_sql` | `~> 3.10` | `ToolProposal`/`ToolActionEvent` schemas, migration | [VERIFIED: codebase grep] |
| `oban` | `~> 2.17` | Mental model only in Phase 13; runtime dependency for Phase 15/16 | [VERIFIED: codebase grep] |
| `jason` | `~> 1.2` | Idempotency key canonical JSON serialization (`Jason.encode!`) | [VERIFIED: codebase grep] |
| `:crypto` | OTP stdlib | SHA-256 for idempotency key derivation | [ASSUMED] OTP standard library, always present |
| `:telemetry` | OTP/Hex | Observability emission via `Cairnloop.Telemetry.execute/3` | [ASSUMED] already in use throughout codebase |

**No packages to install.** All dependencies are already declared in `mix.exs`.

---

## Package Legitimacy Audit

> No new packages are installed in this phase — all tooling is existing project dependencies. Section not applicable.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All | ✓ | `~> 1.19` (mix.exs) | — |
| PostgreSQL / `Cairnloop.Repo` | Full integration tests | ✗ (workspace caveat) | — | MockRepo pattern (in-process, as used in `review_task_test.exs`) |
| Oban | Phase 15/16 Oban workers | ✓ (declared) | `~> 2.17` | — |
| Jason | Idempotency key derivation | ✓ (declared) | `~> 1.2` | — |

**Missing dependencies with no fallback:** None — `Cairnloop.Repo` unavailability is addressed by the established MockRepo pattern.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `can_execute?/2` boolean callback | `scope/0` + `authorize/2 :: :ok\|{:error,_}` | Phase 13 | Distinguishes `scope_invalid` from `policy_denied`; deny-by-default |
| Inline synchronous `execute` in LiveView | `Governance.propose/3` → durable record | Phase 13 | No inline execution; audit trail created even for blocked proposals |
| `String.to_existing_atom/1` for tool resolution | Registry module list matching | Phase 13 | Removes atom-cardinality footgun; fail-closed for unknown tool refs |
| Single `execute/3` callback combining validation + execution | Separate `changeset/2` (validation) + `run/3` (execution, Phase 16) | Phase 13 | Compiler-enforced boundary; `run/3` unused until Phase 16 |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `:crypto` module is available as OTP stdlib without declaration in mix.exs | Standard Stack | Low — `:crypto` is part of Erlang/OTP standard distribution and is always available in Elixir projects. |
| A2 | `Ecto.repo().insert(changeset, on_conflict: :nothing, returning: true)` with Postgrex returns `{:ok, %struct{id: nil}}` on conflict | Recommended Implementation | Medium — behaviour depends on Postgrex version; should be tested explicitly. Fallback: catch `{:error, %Ecto.Changeset{}}` with `unique_constraint` error instead. |
| A3 | `inspect(MyModule)` and `Atom.to_string(MyModule)` produce identical strings in all Elixir 1.19 contexts | Pitfall 8 | Low — this is a documented Elixir invariant, but worth asserting in the registry resolver test. |

---

## Open Questions

1. **`dedupe_window_token` for idempotency key (D-25 discretion)**
   - What we know: The key must include enough context to uniquely identify a propose-time intent.
   - What's unclear: Whether the `dedupe_window_token` is the `conversation.id` (natural deduplication window for most use cases), a caller-supplied UUID, or a time-window bucket.
   - Recommendation: Default to `conversation_id` as the deduplication token; expose as a `context` map key (e.g., `context[:idempotency_token]`). Callers who want finer granularity supply their own token.

2. **`scope/0` return shape (D-16, Claude's discretion)**
   - What we know: `scope/0` returns something compared to the actor's scope in context.
   - What's unclear: Is it a list of required scope atoms (e.g., `[:account_admin]`) that must all be present? A single scope atom? A function?
   - Recommendation: List of required scope atoms — `def scope, do: [:account_admin]`. `check_scope/3` in the pipeline verifies `Enum.all?(tool_module.scope(), &(&1 in Map.get(context, :scopes, [])))`. Simple and extensible.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `lib/cairnloop/tool.ex`, `lib/cairnloop/tool_registry.ex`, `lib/cairnloop/web/conversation_live.ex`, `lib/cairnloop/knowledge_automation/review_task.ex`, `lib/cairnloop/knowledge_automation/review_task_event.ex`, `lib/cairnloop/knowledge_automation/article_suggestion.ex`, `lib/cairnloop/retrieval/gap_event.ex`, `lib/cairnloop/knowledge_automation/telemetry.ex`, `lib/cairnloop/telemetry.ex`, `lib/cairnloop/knowledge_automation.ex`, `lib/cairnloop/automation/workers/draft_worker.ex`, `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs`, `mix.exs`
- `.planning/phases/13-governed-tool-contract-proposal-records/13-CONTEXT.md` — 31 locked decisions [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` — TOOL-01..TOOL-04, MCP-01, proof posture [VERIFIED: file read]
- `.planning/ROADMAP.md` — Phase 13-17 goals [VERIFIED: file read]
- `.planning/STATE.md` — carried-forward decisions, environment caveat [VERIFIED: file read]

### Secondary (MEDIUM confidence)
- Oban 2.17 `use Oban.Worker` declarative opts pattern — [ASSUMED: training knowledge + `draft_worker.ex` confirms the pattern is already in use]

---

## Metadata

**Confidence breakdown:**
- Existing code seams: HIGH — all signatures drawn from direct file inspection
- Standard stack: HIGH — all deps verified in mix.exs
- Architecture patterns: HIGH — all drawn from locked CONTEXT.md decisions + direct idiom inspection
- Pitfalls: HIGH — all landmines traced to specific lines in existing code or explicit decision rationale

**Research date:** 2026-05-23
**Valid until:** 2026-06-23 (stable Elixir/Ecto/Oban patterns; 30-day window)
