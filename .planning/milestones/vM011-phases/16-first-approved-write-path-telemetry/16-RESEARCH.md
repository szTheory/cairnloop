# Phase 16: First Approved Write Path & Telemetry - Research

**Researched:** 2026-05-25
**Domain:** Oban worker execution, at-most-once idempotency, Ecto multi/with co-commit,
bounded telemetry, governed-write example tool
**Confidence:** HIGH — all claims verified directly against live codebase (Oban 2.22.1,
`ApprovalResumeWorker`, `Governance.Telemetry`, schemas) plus official Oban hexdocs

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D16-01 [OWNER-CONFIRMED]:** First approved write action = internal operator-only note
  appended to conversation. Append-only, never customer-visible.
- **D16-02:** Ship as `use Cairnloop.Tool`, `risk_tier: :low_write` governed-write example
  (name at planner discretion, e.g. `Cairnloop.Tools.InternalNote`). Writes to host
  `cairnloop_messages` via `Application.fetch_env!(:cairnloop, :repo)`. Note row carries
  run-level idempotency key in `metadata`.
- **D16-03:** New dedicated `ToolExecutionWorker` Oban worker. Only place `run/3` is called.
  Do NOT fold into `ApprovalResumeWorker` (contract sealed).
- **D16-04:** Resume worker enqueues `ToolExecutionWorker` on `:approved` + re-validation pass
  (additive — still never calls `run/3`).
- **D16-05:** At-most-once in three layers: Oban uniqueness on proposal/approval id, pre-execution
  terminal guard on `result_state == :succeeded`, run-level idempotency key passed via context.
- **D16-06:** Re-validate via `Governance.validate/3` + lazy `expires_at` guard before each
  `run/3` attempt. Fail-closed to `:invalidated` on failure — never write.
- **D16-07:** Transient `{:error, reason}` → Oban backoff retry. Host-configurable
  `max_attempts`, fail-closed bounded default. Increment `ToolProposal.attempt`, emit per-attempt
  `ToolActionEvent`. Permanent failure → terminal `:execution_failed`, `{:cancel, reason}` or
  recorded-`:ok`.
- **D16-08:** Extend `ToolApproval.@status_values` with `:executed` + `:execution_failed`.
  Populate reserved `ToolProposal` columns (`result_state`, `result_summary`, `attempt`,
  `oban_job_id`). Extend `ToolActionEvent.@event_type_values` with execution events. No separate
  `ToolRun` table.
- **D16-09 (OBS-02 alignment):** Make attribution reconstructable from durable records only.
  No Scoria/evidence adapter (Phase 17).
- **D16-10:** Route execution telemetry through `Cairnloop.Governance.Telemetry` allow-list
  module. New events: `[:cairnloop, :governance, :action_executed]` and
  `[:cairnloop, :governance, :action_failed]`. Measurements: `count` + `duration_ms`.
  Enum-bounded labels only (`risk_tier`, `approval_mode`, `result_state`, `tool_ref` registry-
  validated → `:unknown`). Never input payloads, actor_id, conversation_id, reason strings.
  Emit after success, never inside `with` clause list.
- **D16-11:** Map `:executed` → Done (success chip); `:execution_failed` → Done (failure chip,
  brand token, text + color). Show humanized `result_summary` on success; humanized reason +
  attempt count on failure. Read from snapshotted card fields. Reflect via existing thin-PubSub
  → `reload_conversation_with_context` path.
- **D16-12:** Keep plain-assign reload. No `Phoenix.LiveView.stream/3`.
- **D16-13:** Durable records are truth; telemetry is observability. All reads through narrow
  `Cairnloop.Governance` facade. Calm, fail-closed, humanized operator copy. Brand tokens over hex.
- **D16-14:** Use Phase 15 DB-backed integration harness (`MIX_ENV=test mix test.integration`)
  for write + idempotency-under-replay + retry + at-most-once proof. Fast headless `mix test`
  stays DB-free for worker branch logic with mock repo.

### Claude's Discretion
- Worker/module/queue names, exact terminal-status spellings (`:executed` vs `:completed`),
  `event_type` names, run-level idempotency key composition, `max_attempts` default and backoff,
  `result_summary` formatting, whether execution APIs live on `Cairnloop.Governance` or thin
  submodule, `Ecto.Multi` vs sequential `with` co-commit structure.
- Whether `:execution_failed` is in Done group or a distinct group.
- Exact placement of success/failure chip in Phase 14 card layout.

### Deferred Ideas (OUT OF SCOPE)
- Auto (`:auto` / read-only) execution.
- Scoria / OpenInference evidence adapter + read-only MCP seam (Phase 17).
- `Phoenix.LiveView.stream/3` for timeline.
- `:destructive` / high-risk / financial writes, rollback, multi-step runbooks (ACT-02/FLOW-04).
- Four-eyes / segregation-of-duties enforcement (host policy hook only).
- A second governed write tool / broad tool catalog.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ACT-01 | System ships at least one narrow low-blast-radius write workflow after approval | D16-01/02: internal note tool; D16-03/04: ToolExecutionWorker + resume enqueue; example tool pattern §5 |
| OBS-01 | Bounded telemetry for execution/failure without high-cardinality labels | D16-10: extend `Cairnloop.Governance.Telemetry`; §4 telemetry extension pattern |
| OBS-02 | Optional audit integrations can attribute approver + policy snapshot | D16-09: attribution reconstructable from `ToolApproval.decided_by`, `policy_snapshot`, attempt events; §2 durable trail |
</phase_requirements>

---

## Summary

Phase 16 builds the SUCCESS branch off `:execution_pending` — the first real `run/3` call in
Cairnloop's history. Every prior phase deliberately stopped short of writing any side effect. The
execution lane is fully seamed: `approve → resume (re-validate → :execution_pending) → execute
(re-validate → run/3 → record outcome)`. All three segments are independently retryable durable
Oban jobs; each is a no-op on replay.

The primary implementation challenge is composing three at-most-once layers correctly (Oban
uniqueness + pre-execution terminal guard + run-level idempotency key) without creating
over-coupling between the re-validation gate and the side effect. The Oban 2.22.1 API (already
in the project) provides `{:cancel, reason}` for terminal failure, `{:error, reason}` for
transient retry, and `unique: [period: :infinity, keys: [...]]` for no-double-enqueue — all
verified in live deps. The example note tool demonstrates the idiom a host developer copies; it
must be idempotent on the run-level key (existence check on `metadata` before insert).

The Phase 15 integration harness (`test/integration/`, `MIX_ENV=test mix test.integration`,
`Cairnloop.DataCase`, `Cairnloop.Fixtures`) is the correct proof vehicle: at-most-once under
replay, idempotent re-enqueue, retry/backoff, and terminal-guard no-op are all properties that
require a real Postgres + Oban worker round-trip to prove. Fast headless `mix test` covers branch
logic with mock repo.

**Primary recommendation:** Mirror `ApprovalResumeWorker` for `ToolExecutionWorker`; mirror the
`Governance.Telemetry` allow-list module for two new execution events; mirror the Phase 15
integration harness test structure for the DB-backed proof.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `run/3` invocation + outcome record | Oban Worker (async) | — | Never inline in LiveView (APRV-01); independently retryable |
| Pre-execution re-validation gate | Oban Worker (sync inside perform/1) | — | Must fire immediately before each attempt; zero side effects |
| At-most-once idempotency (job uniqueness) | Oban scheduler | — | Prevents double-enqueue before the job runs |
| At-most-once idempotency (terminal guard) | Oban Worker (DB read) | — | Guards replays after success is already recorded |
| Run-level idempotency key (tool deduplication) | Library (key derivation) + Tool (existence check) | — | Stripe-style: library derives key, tool uses it for dedup write |
| Approval status transitions (`:executed`, `:execution_failed`) | API/Backend (`Cairnloop.Governance` facade) | — | Durable records are workflow truth |
| Append-only `ToolActionEvent` for each attempt | API/Backend (Governance.Telemetry / facade) | — | One timeline per proposal; per-attempt reconstructable |
| Bounded execution telemetry | Observability (`Cairnloop.Governance.Telemetry`) | — | Emit after success; never instead of events |
| Outcome display (chips, result_summary) | Frontend LiveView (`ToolProposalPresenter`) | — | Read from snapshotted columns; never live render |
| Example write tool (`InternalNote`) | Library (example) + Host runtime (DB write) | — | Host owns `cairnloop_messages`; library owns tool contract |

---

## Standard Stack

No new external dependencies. Everything below is already in `mix.lock`.

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `oban` | 2.22.1 [VERIFIED: mix.lock] | Async job scheduling, retry, uniqueness | Already in use for ApprovalResumeWorker, SlaCountdownWorker |
| `ecto_sql` | ~3.10 [VERIFIED: mix.exs] | Postgres persistence, co-commit transactions | Core data layer |
| `jason` | ~1.2 [VERIFIED: mix.exs] | JSON encode for idempotency key derivation | Already used in `derive_idempotency_key/4` |

### No New Packages

This phase is entirely additive to the existing stack. No packages to install.

---

## Package Legitimacy Audit

No packages are installed in this phase. All required libraries are already present in
`mix.lock`. Audit not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
[ConversationLive: approve_action] 
  → Governance.approve/3 (record :approved + event, enqueue ResumeWorker)
      → [ApprovalResumeWorker.perform/1]
           lazy expires_at guard → if stale: :expired (no-op path)
           Governance.validate/3 (re-validate against current context)
             → on fail: :invalidated + event (STOP)
             → on pass: :execution_pending + event
                  → enqueue ToolExecutionWorker  ←── NEW Phase 16 seam
                        ↓
          [ToolExecutionWorker.perform/1]            ←── NEW worker
               terminal guard (result_state == :succeeded → no-op)
               lazy expires_at guard
               Governance.validate/3 (re-validate AGAIN)
                 → on fail: :invalidated + event + :execution_failed → {:cancel, reason}
                 → on pass:
                      start_time = System.monotonic_time(:millisecond)
                      run/3 (tool.run(input_struct, actor_id, ctx_with_run_key))
                        → {:ok, result}:
                             co-commit: ToolApproval :executed + ToolProposal result_state :succeeded
                                        + ToolActionEvent :execution_succeeded
                             Governance.Telemetry.emit(:action_executed, %{duration_ms: ...}, ...)
                             PubSub broadcast → ConversationLive reload
                        → {:error, reason}:
                             increment attempt, emit :execution_attempt_failed event
                             return {:error, reason} → Oban retries (up to max_attempts)
                             on final exhaustion: Oban marks discarded; facade records :execution_failed
```

### Recommended Project Structure

New files (all additive):

```
lib/cairnloop/workers/
├── tool_execution_worker.ex       # New Oban worker — the only place run/3 is called

lib/cairnloop/tools/
├── internal_note.ex               # Example governed-write tool (D16-01/02)

priv/repo/migrations/
├── 2026XXXX_add_execution_states.exs  # :executed + :execution_failed to tool_approvals;
                                        # no new columns needed (Phase 13 reserved them)
```

Modifications to existing files:

```
lib/cairnloop/governance.ex                  # execute/3 facade API, execute_tool/3 transition
lib/cairnloop/governance/tool_approval.ex    # @status_values += :executed, :execution_failed
lib/cairnloop/governance/tool_action_event.ex  # @event_type_values += execution event types
lib/cairnloop/governance/telemetry.ex        # @events += :action_executed, :action_failed
lib/cairnloop/workers/approval_resume_worker.ex  # additive: enqueue ToolExecutionWorker on success
lib/cairnloop/web/tool_proposal_presenter.ex     # status_group, approval_outlook_for_approval, history_line
lib/cairnloop/web/conversation_live.ex           # PubSub handler for execution outcomes
```

### Pattern 1: ToolExecutionWorker — at-most-once composition

**What:** Three layers compose sequentially. Oban uniqueness prevents double-enqueue before the
job runs. The terminal guard prevents re-running after success is recorded. The run-level key
prevents duplicate writes from the tool itself.

**When to use:** Any execution worker that writes a side effect exactly once.

```elixir
# Source: verified from ApprovalResumeWorker pattern in codebase + Oban 2.22.1 hexdocs
defmodule Cairnloop.Workers.ToolExecutionWorker do
  use Oban.Worker,
    queue: :governance,          # or :default — planner discretion
    max_attempts: 3,             # fail-closed bounded default (D16-07) — planner picks number
    unique: [
      period: :infinity,
      fields: [:worker, :args],
      keys: [:approval_id]       # unique per approval_id (mirrors resume worker pattern)
    ]

  defp repo, do: Application.fetch_env!(:cairnloop, :repo)

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, args: %{"approval_id" => approval_id}}) do
    case repo().get(ToolApproval, approval_id) do
      nil -> :ok   # deleted — idempotent no-op

      %ToolApproval{status: :execution_pending} = approval ->
        proposal = repo().get!(ToolProposal, approval.tool_proposal_id)

        # LAYER 2: Pre-execution terminal guard (D16-05).
        # If result_state is already :succeeded (replayed job), no-op.
        if proposal.result_state == :succeeded do
          :ok
        else
          execute_with_revalidation(approval, proposal, job_id)
        end

      _ ->
        # Wrong status — idempotent no-op (terminal states, already-executed, etc.)
        :ok
    end
  end
end
```

### Pattern 2: Run-level idempotency key derivation (D16-05)

**What:** Deterministic key derived from proposal's P13 idempotency key + attempt-stable
component. Passed into `run/3` via context. Tool uses it for existence-check-before-insert.

```elixir
# Source: derived from governance.ex derive_idempotency_key/4 + D16-05 spec
defp derive_run_key(proposal) do
  # attempt-stable: use attempt field (incremented on each transient failure).
  # The key is stable for a given attempt number so a replay of the same attempt
  # deduplicates at the tool level (Stripe-style). A new attempt gets a new key
  # so retries are not blocked by a key already consumed by a failed attempt.
  canonical = "#{proposal.idempotency_key}::attempt::#{proposal.attempt}"
  :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
end
```

The key is passed in context:

```elixir
ctx_with_run_key = Map.put(context, :run_idempotency_key, run_key)
tool_module.run(input_struct, actor_id, ctx_with_run_key)
```

The example note tool uses it:

```elixir
# In InternalNote.run/3:
run_key = Map.get(context, :run_idempotency_key)
existing = repo().get_by(Message, [conversation_id: ..., metadata: %{"run_key" => run_key}])
if existing, do: {:ok, %{idempotent: true}}, else: repo().insert(note_changeset)
```

**PITFALL — JSONB metadata existence check:** `get_by` with a `%{metadata: %{...}}` map does
NOT work for Postgres JSONB containment queries in standard Ecto. Use a raw fragment or
`fragment("metadata @> ?", ^Jason.encode!(%{run_key: run_key}))` instead, or store the run_key
in a dedicated indexed column to make the existence check O(1).

**Recommended approach (simpler):** Store `run_key` in a separate indexed column on
`cairnloop_messages` in the test-host migration (e.g. `add :run_key, :string`), then
`get_by(Message, run_key: run_key)`. This avoids JSONB operator complexity entirely and is
idiomatic Ecto. Since the host owns the messages table, the test-host migration in
`priv/test_host/migrations/` already exists and can be extended.

### Pattern 3: Co-commit on execution outcome

**What:** Sequential `with` (NOT `Ecto.Multi`) mirrors the existing `update_approval_with_event`
idiom throughout `governance.ex` and `approval_resume_worker.ex`.

```elixir
# Source: governance.ex update_approval_with_event/3 (verified in codebase)
# Emit telemetry AFTER the with — never inside the clause list (D-29)
defp record_execution_success(approval, proposal, result, duration_ms) do
  approval_cs = ToolApproval.decision_changeset(
    approval, :executed, "executed", nil, "system", DateTime.utc_now()
  )
  proposal_cs = Ecto.Changeset.change(proposal, %{
    result_state: :succeeded,
    result_summary: humanize_result(result),
    attempt: proposal.attempt + 1
  })

  with {:ok, _updated_approval} <- repo().update(approval_cs),
       {:ok, _updated_proposal} <- repo().update(proposal_cs),
       {:ok, _event} <- repo().insert(
         ToolActionEvent.changeset(%ToolActionEvent{}, %{
           tool_proposal_id: proposal.id,
           event_type: :execution_succeeded,    # name at planner discretion
           actor_id: "system",
           metadata: %{attempt: proposal.attempt + 1}
         })
       ) do
    # Telemetry AFTER success — never inside with (D-29, D16-10)
    Cairnloop.Governance.Telemetry.emit(:action_executed, %{count: 1, duration_ms: duration_ms}, %{
      risk_tier: proposal.risk_tier,
      approval_mode: proposal.approval_mode,
      result_state: :succeeded,
      tool_ref: proposal.tool_ref
    })
    :ok
  end
end
```

**Transient failure path (retry):**

```elixir
defp record_attempt_failure(proposal, reason) do
  proposal_cs = Ecto.Changeset.change(proposal, %{attempt: proposal.attempt + 1})
  with {:ok, _} <- repo().update(proposal_cs),
       {:ok, _} <- repo().insert(
         ToolActionEvent.changeset(%ToolActionEvent{}, %{
           tool_proposal_id: proposal.id,
           event_type: :execution_attempt_failed,
           actor_id: "system",
           reason: humanize_reason(reason),
           metadata: %{attempt: proposal.attempt + 1}
         })
       ) do
    {:error, reason}   # return {:error, reason} so Oban retries (D16-07)
  end
end
```

**Terminal failure path (exhausted or permanent):**

```elixir
defp record_terminal_failure(approval, proposal, reason) do
  approval_cs = ToolApproval.decision_changeset(
    approval, :execution_failed, "execution_failed", humanize_reason(reason), "system", DateTime.utc_now()
  )
  with {:ok, _} <- repo().update(approval_cs),
       {:ok, _} <- repo().insert(
         ToolActionEvent.changeset(%ToolActionEvent{}, %{
           tool_proposal_id: proposal.id,
           event_type: :execution_failed,
           actor_id: "system",
           reason: humanize_reason(reason),
           metadata: %{attempt: proposal.attempt}
         })
       ) do
    Cairnloop.Governance.Telemetry.emit(:action_failed, ...)
    {:cancel, reason}  # Oban 2.22: marks job cancelled, no further retry (D16-07)
  end
end
```

### Pattern 4: Extending `Cairnloop.Governance.Telemetry`

**What:** Add two new events and a `result_state` allow-list, mirroring the existing
`@events`/`@allowed_*`/`normalize_*` posture exactly.

```elixir
# Source: lib/cairnloop/governance/telemetry.ex (verified in codebase)
@events [
  :proposal_created, :proposal_blocked, :proposal_duplicate,
  :action_executed,    # NEW Phase 16
  :action_failed       # NEW Phase 16
]

@allowed_result_states [:not_executed, :succeeded, :failed, :unknown]

# tool_ref: only emit if found in registry; otherwise normalize to :unknown
defp normalize_tool_ref(value) do
  configured = Application.get_env(:cairnloop, :tools, []) || []
  if Enum.any?(configured, fn mod -> Atom.to_string(mod) == value end) do
    value
  else
    :unknown
  end
end

# Execution metadata — enum-bounded only (D16-10)
# NEVER: input payloads, actor_id, conversation_id, reason strings
def metadata(:action_executed, metadata) when is_map(metadata) do
  %{
    risk_tier: normalize_risk_tier(Map.get(metadata, :risk_tier)),
    approval_mode: normalize_approval_mode(Map.get(metadata, :approval_mode)),
    result_state: normalize_result_state(Map.get(metadata, :result_state)),
    tool_ref: normalize_tool_ref(Map.get(metadata, :tool_ref))
  }
end
def metadata(:action_failed, metadata), do: metadata(:action_executed, metadata)
```

The duration_ms measurement flows through `normalize_measurements/1` unchanged (already handles
`:duration_ms`).

### Pattern 5: Example `InternalNote` tool

**What:** A concrete `use Cairnloop.Tool` module with `risk_tier: :low_write`. Writes an
operator-internal note row to `cairnloop_messages`. Idempotent on run-level key.

```elixir
# Source: Cairnloop.Tool behaviour (verified in lib/cairnloop/tool.ex)
defmodule Cairnloop.Tools.InternalNote do
  use Cairnloop.Tool,
    risk_tier: :low_write,      # derives approval_mode: :requires_approval (D16-02)
    title: "Add internal note",
    description: "Appends an operator-only note to the conversation."

  embedded_schema do
    field(:conversation_id, :string)
    field(:content, :string)
  end

  @impl Cairnloop.Tool
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:conversation_id, :content])
    |> validate_required([:conversation_id, :content])
    |> validate_length(:content, min: 1, max: 5_000)
  end

  @impl Cairnloop.Tool
  def scope, do: []   # no special scopes required (D16-01: operator-only, low blast radius)

  @impl Cairnloop.Tool
  def authorize(_actor_id, _context), do: :ok   # open to any authenticated operator

  @impl Cairnloop.Tool
  def run(%{conversation_id: conv_id, content: content}, _actor_id, context) do
    repo = Application.fetch_env!(:cairnloop, :repo)
    run_key = Map.get(context, :run_idempotency_key)

    # Idempotency existence check (D16-05) — see Pattern 2 for run_key column approach
    case run_key && repo.get_by(Cairnloop.Message, run_key: run_key) do
      %Cairnloop.Message{} ->
        {:ok, %{idempotent: true, note: "already written"}}

      _ ->
        attrs = %{
          conversation_id: conv_id,
          content: content,
          role: "internal_note",     # distinct role — operator-only, never customer-visible
          run_key: run_key,
          metadata: %{
            source: "cairnloop_governed_action",
            run_key: run_key
          }
        }
        case repo.insert(Cairnloop.Message.changeset(%Cairnloop.Message{}, attrs)) do
          {:ok, msg} -> {:ok, %{message_id: msg.id}}
          {:error, cs} -> {:error, cs}
        end
    end
  end
end
```

**Notes:**
- `role: "internal_note"` distinguishes operator notes from customer messages and AI drafts.
  The test-host migration already has `role :string` on `cairnloop_messages`.
- The `run_key` column needs to be added to the test-host migration so the existence check is
  an indexed O(1) query rather than a JSONB containment scan.
- The library declares this example but does NOT hardcode `Cairnloop.Message` as a required
  host schema — it is registered in config; the host wires it up. The test integration harness
  stands in as the host.

### Pattern 6: Resume worker additive enqueue (D16-04)

The `ApprovalResumeWorker` success branch (currently `~L83`, transitions `:execution_pending`
and STOPs) receives a single additive change: enqueue `ToolExecutionWorker` after the
transition, mirroring the approve→resume ordering exactly.

```elixir
# Source: approval_resume_worker.ex ~L71-95 (verified in codebase)
# ADDITIVE ONLY — the "STOP" comment becomes "STOP run/3 here; hand off to execute worker"
defp revalidate_and_transition(approval) do
  proposal = repo().get!(ToolProposal, approval.tool_proposal_id)
  context = rebuild_context_from_snapshot(proposal)

  case Cairnloop.Governance.validate(proposal.tool_ref, proposal.actor_id, context) do
    {:ok, _validated} ->
      transition_approval(approval, :execution_pending, :revalidation_passed, nil, "system")
      # NEW: enqueue execution worker (additive — still never calls run/3)
      safe_enqueue(ToolExecutionWorker.new(%{"approval_id" => approval.id}))

    {:blocked, _outcome, reason} ->
      transition_approval(approval, :invalidated, :revalidation_failed,
                          humanize_reason(reason), "system")
  end
end
```

`safe_enqueue/1` is already private in the resume worker; it either needs to be extracted to a
shared helper or re-declared. The Governance facade already has `safe_enqueue/1` as a private
function — the planner may choose to either duplicate it in the worker (one-liner, low risk) or
extract a small shared module.

### Anti-Patterns to Avoid

- **Calling `run/3` inside `ApprovalResumeWorker`:** The contract is sealed. Never churn this.
- **Telemetry emit inside the `with` clause list:** If the DB update fails after telemetry fires,
  you get a phantom event. Always emit AFTER the `with` pipeline succeeds (D-29).
- **Putting `actor_id`, `conversation_id`, or reason strings in telemetry labels:** These are
  high-cardinality. They live in durable records. Telemetry gets enum-bounded atoms only (D16-10).
- **JSONB containment query for run-key existence check:** `repo.get_by(Message, metadata: %{run_key: x})`
  does not generate a Postgres `@>` operator in standard Ecto. Use an indexed column instead.
- **Emitting telemetry before the co-commit:** If the event and approval-status update are in the
  same `with`, telemetry should come after the final `{:ok, ...}` clause, not before.
- **`Ecto.Multi` for the co-commit:** The codebase deliberately uses sequential `with` (see
  `update_approval_with_event/3` throughout `governance.ex`). Do not introduce `Ecto.Multi`
  unless the planner has a specific reason; it diverges from the established idiom.
- **Increment `attempt` BEFORE checking the terminal guard:** The terminal guard reads
  `result_state == :succeeded`; `attempt` is only meaningful after the guard passes. Increment
  as part of the co-commit, not upfront.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Job uniqueness / no double-enqueue | Custom DB lock or "check before insert" | `Oban.Worker unique: [period: :infinity, keys: [:approval_id]]` | Race-condition-safe; Oban holds the lock atomically in `oban_jobs` |
| Transient retry / backoff | Custom retry counter + `Process.sleep` | Oban `{:error, reason}` return + `max_attempts` | Oban handles exponential backoff, reschedule, and final discard |
| Terminal failure (no further retry) | Custom "exhausted" flag in DB | `{:cancel, reason}` from `perform/1` | Oban 2.22 marks job as `cancelled`, no further attempt |
| At-most-once replay protection | Complex distributed lock | Pre-execution terminal guard on `result_state` (simple DB read before `run/3`) | Simple, cheap, testable; Oban uniqueness already handles the scheduling layer |
| Bounded telemetry cardinality | Ad-hoc `Cairnloop.Telemetry.execute` calls | Extend `Cairnloop.Governance.Telemetry` allow-list module | The module already enforces the allow-list; new events simply join `@events` |
| Tool input validation at execution time | Re-implement changeset logic in worker | Pass `input_snapshot` back through `Governance.validate/3` (already does input validation) | `validate/3` is pure, re-callable, side-effect-free (D-15) |

---

## Common Pitfalls

### Pitfall 1: `oban_job_id` capture — which job id to store?

**What goes wrong:** The planner stores the `ToolExecutionWorker` Oban job id in
`ToolProposal.oban_job_id` for traceability. But `safe_enqueue/1` wraps `Oban.insert` in a
`try/rescue` and silently returns `:ok` on failure — you never get the job id back.

**Root cause:** `safe_enqueue/1` discards the `{:ok, %Oban.Job{}}` return value.

**How to avoid:** When populating `oban_job_id` is required, use a version of `safe_enqueue`
that returns `{:ok, job}` on success and logs on failure (fall back to `nil` for the job id —
it is advisory, not required for correctness). The `oban_job_id` column is already nullable in
the schema.

**Simpler option:** Store `nil` for `oban_job_id` in Phase 16 (it is reserved but the column
is nullable and advisory). The durable event trail + `result_state` already make the outcome
reconstructable. Populate `oban_job_id` only if the planner decides traceability to the specific
Oban job row is worth the complexity of modifying `safe_enqueue`.

### Pitfall 2: Oban `unique:` uniqueness window and collision during the job's own execution

**What goes wrong:** `unique: [period: :infinity, ...]` means a duplicate job cannot be inserted
while the existing job is in any state (`available`, `executing`, `completed`, etc.). After Oban
marks the job `completed`, a new unique job with the same key CAN be inserted. This is correct
for Phase 16 (we want exactly one execution per approval), but the worker must not assume the
Oban unique constraint alone protects against retries after success — that is what the terminal
guard (`result_state == :succeeded`) handles.

**How to avoid:** Always check both layers: Oban uniqueness (prevents double-enqueue) AND the
terminal guard (prevents re-execute after a replayed/re-queued job arrives). Do not rely on
either layer alone.

### Pitfall 3: Re-validate context rebuild at execution time

**What goes wrong:** `ApprovalResumeWorker.rebuild_context_from_snapshot/1` (already in code)
rebuilds context from `proposal.scope_snapshot` and `proposal.input_snapshot`. The
`ToolExecutionWorker` must do the same. If it passes stale or empty context to `validate/3`,
the validation may pass when it should fail (e.g. scope_snapshot is empty, so `check_scope`
trivially passes for any tool with `scope/0 == []`).

**How to avoid:** Use the same `rebuild_context_from_snapshot/1` helper (copy it or extract it
to a shared module). For Phase 16 the note tool has `scope: []`, but future tools may require
non-empty scopes — the re-validation must use the actual snapshotted scopes.

**Pattern:** Extract `rebuild_context_from_snapshot/1` from `ApprovalResumeWorker` into a shared
private-module helper or duplicate it verbatim in `ToolExecutionWorker`.

### Pitfall 4: `{:cancel, reason}` vs `{:error, reason}` confusion

**What goes wrong:** Using `{:cancel, reason}` for transient failures (DB hiccup) permanently
cancels the job, with no retry. Using `{:error, reason}` for permanent failures (re-validation
fail) wastes all remaining attempts before giving up.

**How to avoid (D16-07 mapping):**

| Scenario | Return value | Effect |
|---|---|---|
| Transient: DB error, tool `{:error, reason}` (not re-validation) | `{:error, reason}` | Oban retries (up to `max_attempts`) |
| Permanent: re-validation failure, `expires_at` guard | `{:cancel, reason}` after recording `:execution_failed` | No further retry; job marked `cancelled` |
| Permanent: retries exhausted | Record `:execution_failed` in `handle_exhausted/1` or detect `attempt >= max_attempts` in `perform/1` | Terminal; no retry |

Oban 2.22: when `max_attempts` is exhausted and `{:error, reason}` is returned on the final
attempt, Oban marks the job `discarded`. There is no automatic callback. To ensure a durable
`:execution_failed` record is written on exhaustion, detect the final attempt in `perform/1`:

```elixir
# Source: Oban 2.22.1 hexdocs — job struct has attempt and max_attempts fields
def perform(%Oban.Job{attempt: attempt, max_attempts: max, args: args}) do
  ...
  # In the transient failure path:
  if attempt >= max do
    record_terminal_failure(approval, proposal, reason)  # returns {:cancel, reason}
  else
    record_attempt_failure(proposal, reason)  # returns {:error, reason}
  end
end
```

[VERIFIED: Oban 2.22.1 hexdocs — `Oban.Job` struct has `attempt` and `max_attempts` fields
available in `perform/1`]

### Pitfall 5: `tool_ref` telemetry cardinality — registry check at emit time

**What goes wrong:** If `normalize_tool_ref/1` calls `Application.get_env(:cairnloop, :tools, [])`
at each telemetry emit, an empty tools config (e.g. in a test) normalizes every `tool_ref` to
`:unknown`, which is correct but may hide real bugs in tests. More importantly: a misconfigured
registry could silently normalize a valid tool to `:unknown` in production.

**How to avoid:** The normalize pattern is already used for `risk_tier` and `approval_mode` in
the existing `Governance.Telemetry` module — apply the same pattern for `tool_ref`. In tests,
set `Application.put_env(:cairnloop, :tools, [PassTool])` (the integration suite already does
this for `ApprovalFlowTest`).

### Pitfall 6: `status_group/1` catch-all currently maps unknown atoms to `:blocked`

**What goes wrong:** `tool_proposal_presenter.ex` has `def status_group(_), do: :blocked`. When
`:executed` and `:execution_failed` are added to `ToolApproval.@status_values`, the presenter
must explicitly match them — otherwise `:executed` would display as "Blocked" until the clauses
are added.

**How to avoid:** Add the two new clauses to `status_group/1` BEFORE the catch-all:
```elixir
def status_group(:executed), do: :done
def status_group(:execution_failed), do: :done  # or :blocked if planner prefers visual distinction
```
The CONTEXT.md notes `:execution_failed` may sit in Done or a distinct group — both are valid,
the planner decides (D16-11).

### Pitfall 7: `ToolActionEvent` `to_status` enum scope

**What goes wrong:** `ToolActionEvent.from_status` and `to_status` are `Ecto.Enum` values typed
against `ToolProposal.status_values/0` (not `ToolApproval.status_values/0`). The Phase 15
approval event types already use `nil` for both fields (transition in `event_type` + metadata).
Phase 16 execution events should follow the same pattern — do NOT try to put `:executed` or
`:execution_failed` (ToolApproval statuses) into `to_status`.

**How to avoid:** For execution event types, leave `from_status` and `to_status` as `nil` (same
as approval events). Carry the transition in `event_type` + metadata.

---

## Runtime State Inventory

> Omitted — this is a greenfield additive phase, not a rename/refactor/migration.

---

## Code Examples

### ToolActionEvent `@event_type_values` extension

```elixir
# Source: lib/cairnloop/governance/tool_action_event.ex (verified in codebase)
# Phase 16 additions (names at planner discretion):
@event_type_values [
  :proposal_created, :proposal_blocked,
  # Phase 15 approval lifecycle
  :approval_requested, :approved, :rejected, :deferred, :expired, :invalidated,
  :resume_scheduled, :revalidation_passed, :revalidation_failed,
  # Phase 16 execution lifecycle — NEW
  :execution_started,           # emitted before run/3 (optional but useful for latency)
  :execution_succeeded,         # run/3 returned {:ok, result}
  :execution_attempt_failed,    # transient failure on this attempt; will retry
  :execution_failed             # terminal; no further retry
]
```

### `ToolApproval.@status_values` extension

```elixir
# Source: lib/cairnloop/governance/tool_approval.ex L34 (verified in codebase)
@status_values [
  :pending, :approved, :execution_pending, :rejected, :deferred, :expired, :invalidated,
  :executed,           # NEW Phase 16 — success terminal
  :execution_failed    # NEW Phase 16 — failure terminal
]
```

Requires a migration to add `:executed` and `:execution_failed` to the Postgres enum column
(stored as `:string` — just add the new values to the allowed strings). No existing row is
affected; the new states are forward-only transitions.

### Migration pattern for new terminal statuses

```elixir
# Source: priv/repo/migrations/20260524120001_add_tool_approvals.exs (verified, uses :string storage)
# No enum column to alter — statuses are stored as :string. No migration needed for the
# status column itself. Only a migration is needed if new indexes are added.
# The result_state, attempt, oban_job_id, result_summary columns already exist
# (Phase 13 reserved them — verified in 20260524000000_add_tool_proposals_and_action_events.exs).
```

The reserved columns (`attempt`, `oban_job_id`, `result_state`, `result_summary`) are already
in `cairnloop_tool_proposals` with correct types. No column migration needed — just populate.

A migration IS needed to add `run_key` to `cairnloop_messages` in the test-host migration
(`priv/test_host/migrations/`) for the note tool's idempotency existence check.

### `ToolProposalPresenter` execution outcome additions

```elixir
# Source: lib/cairnloop/web/tool_proposal_presenter.ex (verified in codebase)

# status_group/1 — add before catch-all (Pitfall 6)
def status_group(:executed), do: :done
def status_group(:execution_failed), do: :done

# approval_outlook_for_approval/1 — add after :execution_pending clause
def approval_outlook_for_approval(%{status: :executed, result_summary: summary}) do
  "Action completed: #{summary || "Done."}"
end
def approval_outlook_for_approval(%{status: :execution_failed, reason: reason, decided_by: _}) do
  "Action failed: #{reason || "An error occurred."}"
end

# history_line/1 — add before catch-all
def history_line(%ToolActionEvent{event_type: :execution_succeeded, metadata: meta}) do
  attempt = Map.get(meta || %{}, "attempt", 1)
  "Action completed (attempt #{attempt})."
end
def history_line(%ToolActionEvent{event_type: :execution_attempt_failed, reason: reason, metadata: meta}) do
  attempt = Map.get(meta || %{}, "attempt", 1)
  "Attempt #{attempt} failed: #{reason || "Transient error — will retry."}"
end
def history_line(%ToolActionEvent{event_type: :execution_failed, reason: reason}) do
  "Action failed permanently: #{reason || "All retry attempts exhausted."}"
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-----------------|--------------|--------|
| `{:discard, reason}` in Oban perform | `{:cancel, reason}` (`:discard` deprecated) | Oban 2.17+ | Use `{:cancel, reason}` throughout Phase 16 |
| `Oban.Worker max_attempts: 20` (default) | Explicit bounded default (e.g. 3–5) | Phase 16 design decision | Fail-closed: prefers NOT executing over exhausting 20 retries on a write action |
| Telemetry emitted ad-hoc via `Cairnloop.Telemetry.execute` | All governance telemetry through `Cairnloop.Governance.Telemetry` allow-list module | Phase 13/15 | Cardinality bounded; D16-10 extends this consistently |

**Deprecated/outdated:**
- `{:discard, reason}`: deprecated in Oban 2.17+; replaced by `{:cancel, reason}` [VERIFIED: Oban 2.22.1 hexdocs]
- Direct `Cairnloop.Telemetry.execute` calls for governance events: the `approval_resume_worker.ex`
  and `approval_expiry_worker.ex` still use it directly. D16-10 notes this may be cleaned up
  as a discretionary additive nicety; Phase 16 extends `Governance.Telemetry` for the new events
  and may optionally route the existing approval_transition emits through it.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir) |
| Fast headless config | `mix test` (excludes `:integration` tag) |
| Integration config | `mix.exs` alias `test.integration` = `test.setup` + `mix test --include integration test/integration` |
| Quick run command | `MIX_ENV=test mix test` |
| Full (integration) run command | `MIX_ENV=test mix test.integration` |
| Integration prerequisite | `docker-compose up -d postgres` (pgvector; see `docker-compose.yml`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Harness |
|--------|----------|-----------|-------------------|---------|
| ACT-01 | ToolExecutionWorker calls `run/3` and writes the note row | Integration | `MIX_ENV=test mix test.integration` | `test/integration/` |
| ACT-01 | Pre-execution terminal guard: second `perform/1` on a `:succeeded` proposal is a no-op | Integration | `MIX_ENV=test mix test.integration` | `test/integration/` |
| ACT-01 | Oban unique job: second `Governance.execute/3` enqueue is rejected (no duplicate job) | Integration | `MIX_ENV=test mix test.integration` | `test/integration/` |
| ACT-01 | Transient failure: `{:error, reason}` from `run/3` increments `attempt`, emits per-attempt event, returns `{:error, reason}` | Unit (headless) | `MIX_ENV=test mix test` | mock repo |
| ACT-01 | Terminal failure path: re-validation failure → `:execution_failed`, `{:cancel, reason}` | Unit (headless) | `MIX_ENV=test mix test` | mock repo |
| ACT-01 | `InternalNote.run/3` is idempotent: duplicate call with same `run_idempotency_key` returns `{:ok, %{idempotent: true}}` | Integration | `MIX_ENV=test mix test.integration` | `test/integration/` |
| OBS-01 | Telemetry events emitted with correct bounded labels (no high-cardinality) | Unit (headless) | `MIX_ENV=test mix test` | `:telemetry.attach` in test |
| OBS-01 | `normalize_tool_ref/1` maps unknown ref to `:unknown` | Unit (headless) | `MIX_ENV=test mix test` | pure function |
| OBS-02 | `ToolApproval.decided_by` + `policy_snapshot` present and attributable after execute | Integration | `MIX_ENV=test mix test.integration` | `test/integration/` |
| OBS-02 | `ToolActionEvent` trail carries attempt number and actor attribution | Integration | `MIX_ENV=test mix test.integration` | `test/integration/` |

### Observation Points for Each Guarantee

| Guarantee | Observation Point | Test Pattern |
|-----------|------------------|-------------|
| At-most-once (no double-write) | `cairnloop_messages` row count after two identical `ToolExecutionWorker.perform/1` calls | `assert Repo.aggregate(Message, :count) == 1` |
| Terminal guard (no-op on replay) | `ToolApproval.status` stays `:executed` after second perform | `assert Repo.get!(ToolApproval, id).status == :executed` |
| Attempt increment | `ToolProposal.attempt` increments on transient failure | `assert Repo.get!(ToolProposal, id).attempt == 2` |
| Per-attempt events | `ToolActionEvent` trail contains `:execution_attempt_failed` | `assert :execution_attempt_failed in event_types` |
| Telemetry bounded | Emitted metadata contains no `conversation_id`, `actor_id`, or `reason` keys | `assert_received {:telemetry, [:cairnloop, :governance, :action_executed], _, meta}; refute Map.has_key?(meta, :actor_id)` |
| OBS-02 attribution | `ToolApproval.decided_by` non-nil + `policy_snapshot` non-empty after execute | `assert approval.decided_by != nil` |

### Sampling Rate

- **Per task commit:** `MIX_ENV=test mix test` (headless, < 10s)
- **Per wave merge:** `MIX_ENV=test mix test.integration` (DB-backed, requires Docker Postgres)
- **Phase gate (before `/gsd:verify-work`):** Full integration suite green

### Wave 0 Gaps

New test files needed:

- [ ] `test/integration/tool_execution_worker_test.exs` — covers at-most-once, idempotent replay,
  transient retry, terminal failure, full event trail, `InternalNote.run/3` idempotency (ACT-01,
  OBS-02). Mirrors `test/integration/approval_flow_test.exs` structure.
- [ ] `test/cairnloop/governance/telemetry_test.exs` (or extend existing) — covers execution event
  names, bounded metadata (no high-cardinality leakage), `normalize_tool_ref/1` (OBS-01).

Existing infrastructure re-used without change:
- `Cairnloop.DataCase` — `use Cairnloop.DataCase, async: false`
- `Cairnloop.Fixtures` — extend with `message_fixture/1` if needed; `proposal_fixture/1` and
  `approval_fixture/1` already exist
- `docker-compose.yml`, `mix.exs` `test.integration` alias, `test_helper.exs` exclusion — all
  in place from Phase 15

---

## Security Domain

`security_enforcement` is enabled (not set to false in config).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|----------------|
| V2 Authentication | No | N/A — operator identity is host-supplied (`actor_id`); no auth logic in this phase |
| V3 Session Management | No | N/A — stateless worker; no session |
| V4 Access Control | Yes | `Governance.validate/3` re-validated before each attempt; `authorize/2` deny-by-default; never bypasses the approval gate |
| V5 Input Validation | Yes | Tool `changeset/2` runs inside `validate/3`; applied at propose time AND at execution re-validate; never raw params to `run/3` |
| V6 Cryptography | No | `derive_run_key` uses `:crypto.hash(:sha256, ...)` — standard, not hand-rolled |
| V7 Error Handling | Yes | Humanized errors only to operators; `{:error, reason}` and `{:cancel, reason}` never surface raw Elixir terms (D16-13) |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replay attack: duplicate job executes write twice | Tampering | Three-layer at-most-once (Oban unique + terminal guard + run-level key) |
| Stale approval executes after policy change | Tampering | Re-validate via `Governance.validate/3` + `expires_at` guard immediately before each `run/3` attempt |
| High-cardinality telemetry label injection | Information Disclosure | `normalize_tool_ref/1` + `@allowed_*` guards in `Governance.Telemetry`; never emit dynamic strings |
| Raw error terms exposed to operator | Information Disclosure | `humanize_reason/1` gate (already in `ApprovalResumeWorker`); presenter never calls `inspect/1` |
| Tool writes to unintended conversation | Tampering | `conversation_id` from trusted `input_snapshot` (not LiveView params); snapshotted at propose time |
| Attempt counter manipulation | Tampering | `attempt` incremented only in co-commit; no client-supplied value accepted |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Postgres (pgvector) | Integration harness DB writes | ✓ (docker-compose.yml) | per compose file | — (integration tests skipped headless) |
| Oban 2.22.1 | ToolExecutionWorker | ✓ | 2.22.1 [VERIFIED: mix.lock] | — |
| `MIX_ENV=test mix test.integration` alias | Phase 16 proof | ✓ | in mix.exs | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:**
- Live Oban job queue (for production-path testing): not available; all Phase 16 tests exercise
  workers by calling `perform/1` directly (same pattern as `approval_flow_test.exs`). This is
  the established project idiom.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `run_key` column added to `cairnloop_messages` test-host migration for O(1) existence check | Pattern 2, Pattern 5 | If not added, JSONB containment check is needed; more complex but functional |
| A2 | `Oban.Job` struct exposes `attempt` and `max_attempts` in `perform/1` for exhaustion detection | Pitfall 4 | If unavailable, use a separate `handle_exhausted` approach or check via `attempt == max_attempts` at caller |
| A3 | `safe_enqueue/1` return value (`:ok` on both success and failure) means `oban_job_id` must be treated as advisory/nullable | Pitfall 1 | If planner wants a non-nil `oban_job_id`, `safe_enqueue` must be modified to return `{:ok, job}` on success |

All other claims in this document are `[VERIFIED]` against the live codebase or `[VERIFIED: Oban 2.22.1 hexdocs]`.

---

## Open Questions (RESOLVED)

1. **Queue name for `ToolExecutionWorker`**
   - What we know: existing workers use `queue: :default`; the CONTEXT.md notes queue name is
     planner discretion.
   - What's unclear: whether a dedicated `:governance` queue is worth the operational overhead
     of configuring it in the host Oban config, vs. using `:default` like all other workers.
   - Recommendation: use `:default` (zero host config change required; consistent with all other
     workers); name a `:governance` queue only if a host shows priority concerns.

2. **`safe_enqueue` in `ApprovalResumeWorker` vs shared module**
   - What we know: `safe_enqueue/1` is private in both `governance.ex` and
     `approval_resume_worker.ex` (declared separately in each). The resume worker needs to call
     `safe_enqueue` to enqueue `ToolExecutionWorker`.
   - What's unclear: whether to extract to a shared helper module (cleaner) or duplicate the
     one-liner (simpler, consistent with current idiom).
   - Recommendation: duplicate it verbatim in the resume worker (it is a three-line function;
     DRY extraction adds module overhead). Add a `# NOTE: mirrors Governance.safe_enqueue/1`
     comment.

3. **`oban_job_id` population**
   - What we know: the column is reserved, nullable. Populating it requires modifying
     `safe_enqueue` to return the job id.
   - What's unclear: whether the planner decides it is worth the modification.
   - Recommendation: leave `nil` in Phase 16. The event trail and `result_state` already
     make outcomes fully reconstructable. `oban_job_id` can be populated in a future phase
     if operational needs surface.

---

## Sources

### Primary (HIGH confidence)
- Live codebase: `lib/cairnloop/workers/approval_resume_worker.ex` — worker idiom, unique:, safe_enqueue, humanize_reason pattern [VERIFIED: read in session]
- Live codebase: `lib/cairnloop/governance.ex` — update_approval_with_event/3, safe_enqueue, approve/3 enqueue-after-record ordering [VERIFIED: read in session]
- Live codebase: `lib/cairnloop/governance/telemetry.ex` — @events, @allowed_*, normalize_*, emit after with [VERIFIED: read in session]
- Live codebase: `lib/cairnloop/governance/tool_proposal.ex` — reserved Phase 16 columns (attempt, oban_job_id, result_state, result_summary) [VERIFIED: read in session]
- Live codebase: `lib/cairnloop/governance/tool_approval.ex` — @status_values, decision_changeset/6 [VERIFIED: read in session]
- Live codebase: `lib/cairnloop/governance/tool_action_event.ex` — @event_type_values, append-only invariant [VERIFIED: read in session]
- Live codebase: `lib/cairnloop/tool.ex` — run/3 callback contract, __using__ macro [VERIFIED: read in session]
- Live codebase: `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs` — reserved columns confirmed in DB schema [VERIFIED: read in session]
- Live codebase: `test/integration/approval_flow_test.exs` — harness pattern, enqueue_fn injection, perform/1 direct invocation [VERIFIED: read in session]
- `mix.lock`: `oban 2.22.1` [VERIFIED: read in session]
- Oban 2.22.1 hexdocs (`https://hexdocs.pm/oban/2.22.1/Oban.Worker.html`, `Oban.Job.html`): `{:cancel, reason}`, `{:error, reason}`, `max_attempts`, `unique:` options, `attempt`/`max_attempts` fields in `perform/1` [VERIFIED: fetched in session]

### Secondary (MEDIUM confidence)
- `.planning/phases/16-first-approved-write-path-telemetry/16-CONTEXT.md` — D16-01 through D16-14 implementation decisions [CITED: 16-CONTEXT.md]
- `.planning/STATE.md` — Phase 15 integration harness description, Repo-unavailable caveat [CITED: STATE.md]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Oban 2.22.1 locked in mix.lock; all usage patterns verified in codebase
- Architecture: HIGH — direct code inspection of all seam files; patterns are already proven in Phase 15
- Pitfalls: HIGH — derived from actual code (JSONB limitation, catch-all presenter order) and verified Oban 2.22 API

**Research date:** 2026-05-25
**Valid until:** 2026-07-01 (Oban 2.x API stable; codebase patterns sealed; recheck if Oban major version changes)
