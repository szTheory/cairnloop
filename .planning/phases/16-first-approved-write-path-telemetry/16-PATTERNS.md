# Phase 16: First Approved Write Path & Telemetry — Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 11 new/modified files
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/workers/tool_execution_worker.ex` | worker | request-response (async Oban) | `lib/cairnloop/workers/approval_resume_worker.ex` | exact |
| `lib/cairnloop/tools/internal_note.ex` | tool / service | CRUD (append-only write) | `lib/cairnloop/tool.ex` (behaviour) + any existing tool via `use Cairnloop.Tool` | role-match |
| `lib/cairnloop/governance.ex` (modify) | facade | CRUD + request-response | self — extend `approve/3` L603, `update_approval_with_event/3` L103, `safe_enqueue/1` L86 | exact |
| `lib/cairnloop/governance/tool_approval.ex` (modify) | model | CRUD | self — extend `@status_values` L34, `decision_changeset/6` L94 | exact |
| `lib/cairnloop/governance/tool_proposal.ex` (modify) | model | CRUD | self — reserved columns already present L43-46 | exact |
| `lib/cairnloop/governance/tool_action_event.ex` (modify) | model | event-driven (append-only) | self — extend `@event_type_values` L23 | exact |
| `lib/cairnloop/governance/telemetry.ex` (modify) | utility / observability | event-driven | self — extend `@events` L21, `@allowed_*`, `normalize_*` | exact |
| `lib/cairnloop/workers/approval_resume_worker.ex` (modify) | worker | request-response (async Oban) | self — additive enqueue at success branch L83 | exact |
| `lib/cairnloop/web/tool_proposal_presenter.ex` (modify) | presenter | transform | self — `status_group/1` L55, `approval_outlook_for_approval/1` L135, `history_line/1` L301 | exact |
| `lib/cairnloop/web/conversation_live.ex` (modify) | component / LiveView | request-response | self — `handle_info/2` reload pattern L26, `approve_action` handler L204 | exact |
| `priv/repo/migrations/YYYYMMDD_add_execution_states.exs` | migration | — | `priv/repo/migrations/20260524120001_add_tool_approvals.exs` | exact |
| `priv/test_host/migrations/…_add_run_key_to_messages.exs` | migration (test-host) | — | `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs` | exact |
| `test/integration/tool_execution_worker_test.exs` | test (integration) | — | `test/integration/approval_flow_test.exs` | exact |
| `test/support/fixtures.ex` (modify) | test support | — | self — extend `approval_fixture/2`, add `message_fixture/1` | exact |

---

## Pattern Assignments

---

### `lib/cairnloop/workers/tool_execution_worker.ex` (NEW — worker, async Oban)

**Analog:** `lib/cairnloop/workers/approval_resume_worker.ex`

**Module declaration + unique + repo indirection** (lines 34-42):
```elixir
use Oban.Worker,
  queue: :default,
  unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]

defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end
```

**`perform/1` shell — status-guard + idempotent no-op** (lines 44-67):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"approval_id" => approval_id}}) do
  case repo().get(ToolApproval, approval_id) do
    nil ->
      # Deleted — idempotent no-op (mirrors SlaCountdownWorker nil branch)
      :ok

    %ToolApproval{status: :execution_pending} = approval ->
      # ...
      :ok

    _ ->
      # Already executed, wrong status — idempotent no-op
      :ok
  end
end
```

**`revalidate_and_transition/1` shape** (lines 71-95) — copy verbatim, then extend the success branch to call `run/3` instead of STOPping:
```elixir
defp revalidate_and_transition(approval) do
  proposal = repo().get!(ToolProposal, approval.tool_proposal_id)
  context = rebuild_context_from_snapshot(proposal)

  case Cairnloop.Governance.validate(proposal.tool_ref, proposal.actor_id, context) do
    {:ok, _validated} ->
      # Phase 16: success branch calls run/3 (contrast: resume worker stops here)
      ...

    {:blocked, _outcome, reason} ->
      transition_approval(approval, :invalidated, :revalidation_failed,
                          humanize_reason(reason), "system")
  end
end
```

**`rebuild_context_from_snapshot/1`** (lines 100-134) — copy verbatim from `ApprovalResumeWorker`; do NOT re-implement. Extract or duplicate with `# NOTE: mirrors ApprovalResumeWorker.rebuild_context_from_snapshot/1`:
```elixir
defp rebuild_context_from_snapshot(proposal) do
  scopes =
    case proposal.scope_snapshot do
      %{"scopes" => scope_list} when is_list(scope_list) ->
        Enum.flat_map(scope_list, fn s ->
          if is_binary(s) do
            try do [String.to_existing_atom(s)]
            rescue ArgumentError -> [] end
          else [s] end
        end)
      %{scopes: scope_list} when is_list(scope_list) -> scope_list
      _ -> []
    end
  tool_params = case proposal.input_snapshot do
    params when is_map(params) -> params
    _ -> %{}
  end
  %{scopes: scopes, tool_params: tool_params}
end
```

**`transition_approval/5` sequential `with` co-commit** (lines 144-176):
```elixir
defp transition_approval(approval, new_status, event_type, reason, actor_id) do
  cs = Ecto.Changeset.change(approval, %{status: new_status, decided_at: DateTime.utc_now()})

  with {:ok, updated} <- repo().update(cs),
       {:ok, _event} <-
         %ToolActionEvent{}
         |> ToolActionEvent.changeset(%{
           tool_proposal_id: approval.tool_proposal_id,
           event_type: event_type,
           from_status: nil,
           to_status: nil,
           actor_id: actor_id,
           reason: reason,
           metadata: %{approval_status: approval.status, new_approval_status: new_status}
         })
         |> repo().insert() do
    # Telemetry AFTER with success — never inside the with clause list (D-29)
    Cairnloop.Telemetry.execute(
      [:governance, :approval_transition],
      %{count: 1},
      %{event_type: event_type, new_status: new_status}
    )
    {:ok, updated}
  end
end
```

**`humanize_reason/1`** (lines 180-201) — copy verbatim; handles `%Ecto.Changeset{}`, atoms, binaries, fallback:
```elixir
defp humanize_reason(reason) do
  case reason do
    %Ecto.Changeset{} = cs ->
      cs
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
      end)
      |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
      |> Enum.join("; ")
    atom when is_atom(atom) -> Atom.to_string(atom)
    binary when is_binary(binary) -> binary
    _ -> "blocked"
  end
end
```

**`safe_enqueue/1` — duplicate with comment** (governance.ex lines 86-94):
```elixir
# NOTE: mirrors Governance.safe_enqueue/1 — host may have no Oban runtime
defp safe_enqueue(job) do
  try do
    Oban.insert(job)
  rescue
    e ->
      Logger.warning("Oban enqueue failed: #{inspect(e)}")
      :ok
  end
end
```

**Oban `attempt`/`max_attempts` exhaustion detection** — use `%Oban.Job{attempt: attempt, max_attempts: max, args: args}` pattern match in `perform/1` head; compare `attempt >= max` in transient failure branch to decide `{:cancel, reason}` vs `{:error, reason}`.

**`{:cancel, reason}` vs `{:error, reason}` rule (D16-07):**
- Transient (DB hiccup, tool `{:error, ...}`, attempt < max): return `{:error, reason}` — Oban retries
- Permanent (re-validation fail, exhausted retries): return `{:cancel, reason}` after recording `:execution_failed` — no further retry (`:discard` is deprecated since Oban 2.17; use `{:cancel, reason}`)

---

### `lib/cairnloop/tools/internal_note.ex` (NEW — tool/service, append-only CRUD)

**Analog:** `lib/cairnloop/tool.ex` behaviour + integration-test `PassTool` module (lines 20-41 of `test/integration/approval_flow_test.exs`)

**`use Cairnloop.Tool` declaration + `embedded_schema`** — from `PassTool` in `test/integration/approval_flow_test.exs` lines 21-40:
```elixir
defmodule Cairnloop.Tools.InternalNote do
  use Cairnloop.Tool,
    risk_tier: :low_write,      # derives approval_mode: :requires_approval (D-09/D-10)
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
  def scope, do: []   # no special scopes (D16-01: operator-only, low blast radius)

  @impl Cairnloop.Tool
  def authorize(_actor_id, _context), do: :ok  # open to any authenticated operator (overrides deny-default)
```

**`run/3` callback signature** — from `lib/cairnloop/tool.ex` line 42:
```elixir
@callback run(tool :: struct(), actor_id(), context()) :: {:ok, any()} | {:error, any()}
```

**`run/3` idempotency existence-check idiom** — use `run_key` column (indexed, O(1)) not JSONB containment:
```elixir
@impl Cairnloop.Tool
def run(%__MODULE__{conversation_id: conv_id, content: content}, _actor_id, context) do
  repo = Application.fetch_env!(:cairnloop, :repo)
  run_key = Map.get(context, :run_idempotency_key)

  # Idempotency: existence check on indexed run_key column (D16-05, Pattern 2)
  # NEVER: repo.get_by(Message, metadata: %{run_key: run_key}) — JSONB @> not generated by Ecto
  case run_key && repo.get_by(Cairnloop.Message, run_key: run_key) do
    %Cairnloop.Message{} -> {:ok, %{idempotent: true, note: "already written"}}
    _ ->
      attrs = %{
        conversation_id: conv_id,
        content: content,
        role: "internal_note",   # distinct role — never customer-visible (D16-01)
        run_key: run_key,
        metadata: %{source: "cairnloop_governed_action", run_key: run_key}
      }
      case repo.insert(Cairnloop.Message.changeset(%Cairnloop.Message{}, attrs)) do
        {:ok, msg} -> {:ok, %{message_id: msg.id}}
        {:error, cs} -> {:error, cs}
      end
  end
end
```

**Tool registry config** — from `lib/cairnloop/tool_registry.ex` lines 20, 43, 61: host registers via `Application.put_env(:cairnloop, :tools, [Cairnloop.Tools.InternalNote])` in config; `ToolRegistry.validate_configured_tools!/0` runs at boot; `find_tool_module/1` resolves by `Atom.to_string(mod)` comparison (never `String.to_existing_atom`).

---

### `lib/cairnloop/governance.ex` (MODIFY — facade, CRUD + request-response)

**Analog:** self — existing `approve/3`, `update_approval_with_event/3`, `safe_enqueue/1`, `validate/3`, `get_proposal/1`, `get_active_approval/1`, `list_events/1`

**`approve/3` record-before-enqueue ordering** (lines 603-641) — mirror exactly for `execute/3`:
```elixir
def approve(approval_id, actor_id, opts \\ []) do
  enqueue_fn = Keyword.get(opts, :enqueue_fn, &safe_enqueue/1)
  ...
  # co-commit: update approval + insert :approved event (record BEFORE enqueue — APRV-01)
  with {:ok, updated} <- update_approval_with_event(approval, changeset, event_attrs) do
    # Enqueue AFTER the record is persisted
    enqueue_fn.(ApprovalResumeWorker.new(%{"approval_id" => updated.id}))
    {:ok, updated}
  end
end
```

**`update_approval_with_event/3` sequential `with` co-commit** (lines 103-122):
```elixir
defp update_approval_with_event(approval, changeset, event_attrs) do
  with {:ok, updated_approval} <- repo().update(changeset),
       {:ok, _event} <-
         %ToolActionEvent{}
         |> ToolActionEvent.changeset(
           Map.put(event_attrs, :tool_proposal_id, approval.tool_proposal_id)
         )
         |> repo().insert() do
    # Telemetry AFTER with success (D-29)
    Cairnloop.Telemetry.execute(
      [:governance, :approval_transition],
      %{count: 1},
      %{event_type: Map.get(event_attrs, :event_type), new_status: updated_approval.status}
    )
    {:ok, updated_approval}
  end
end
```

**`safe_enqueue/1`** (lines 86-94): already exists; re-use for `ToolExecutionWorker` enqueue.

**`validate/3`** (lines 227-239): pure, side-effect-free, re-callable. Call before each `run/3` attempt unchanged.

**Existing read APIs** (lines 494-507, 792-797): `get_proposal/1`, `get_active_approval/1`, `list_events/1` — mirror their shape for any new execution read APIs. New APIs needed: `get_execution_state/1` (reads `ToolProposal.result_state`/`attempt`) if required; follow same `repo().get` / `repo().get_by` pattern.

**New `execute/3` or `enqueue_execution/1` public API** — mirror `approve/3`'s signature and injectable `enqueue_fn` option for testability:
```elixir
def execute_approved(approval_id, opts \\ []) do
  enqueue_fn = Keyword.get(opts, :enqueue_fn, &safe_enqueue/1)
  ...
  with {:ok, updated} <- update_approval_with_event(...) do
    enqueue_fn.(ToolExecutionWorker.new(%{"approval_id" => updated.id}))
    {:ok, updated}
  end
end
```

---

### `lib/cairnloop/governance/tool_approval.ex` (MODIFY — model, CRUD)

**Analog:** self — `@status_values` line 34, `decision_changeset/6` lines 94-106

**`@status_values` extension** (line 34) — add before the list closes:
```elixir
@status_values [
  :pending, :approved, :execution_pending, :rejected, :deferred, :expired, :invalidated,
  :executed,           # NEW Phase 16 — success terminal (D16-08)
  :execution_failed    # NEW Phase 16 — failure terminal (D16-08)
]
```

**`decision_changeset/6`** (lines 94-113) — already handles arbitrary status; no structural change needed. The `validate_reason_present/2` private clause ensures reason is required for `:rejected`/`:deferred` only; `:executed`/`:execution_failed` carry reason as an optional humanized string (not enforced via `validate_required`).

**No migration for the status column** — stored as `:string` (confirmed in `20260524120001_add_tool_approvals.exs` line 11: `add(:status, :string, ...)`). Adding new atoms to `@status_values` is sufficient; Postgres accepts any string value.

---

### `lib/cairnloop/governance/tool_proposal.ex` (MODIFY — model, CRUD)

**Analog:** self — reserved columns lines 43-46

**Reserved columns already present** — confirmed in schema lines 42-46 and migration `20260524000000` lines 21-24:
```elixir
# Phase 16 reserved columns (D-22) — populate in execution (no re-migration needed)
field(:attempt, :integer, default: 0)          # increment per attempt in co-commit
field(:oban_job_id, :integer)                   # advisory/nullable; leave nil in Phase 16
field(:result_state, Ecto.Enum, values: @result_state_values, default: :not_executed)
field(:result_summary, :string)
```

**`@result_state_values`** (line 25): `[:not_executed, :succeeded, :failed]` — these are already the correct values. Populate via `Ecto.Changeset.change(proposal, %{result_state: :succeeded, result_summary: humanized, attempt: n})` in the execution co-commit.

**`changeset/2`** (lines 74-98) — already casts all reserved columns; use it to update `attempt`/`result_state`/`result_summary`. No structural change needed.

---

### `lib/cairnloop/governance/tool_action_event.ex` (MODIFY — model, event-driven append-only)

**Analog:** self — `@event_type_values` lines 23-37, `changeset/2` lines 62-76

**`@event_type_values` extension** (lines 23-37) — add execution events ABOVE the closing `]`:
```elixir
@event_type_values [
  :proposal_created,
  :proposal_blocked,
  # Phase 15 approval lifecycle
  :approval_requested, :approved, :rejected, :deferred, :expired, :invalidated,
  :resume_scheduled, :revalidation_passed, :revalidation_failed,
  # Phase 16 execution lifecycle — NEW (D16-08)
  :execution_started,           # optional; emitted before run/3 for latency tracing
  :execution_succeeded,         # run/3 returned {:ok, result}
  :execution_attempt_failed,    # transient failure; Oban will retry
  :execution_failed             # terminal; no further retry
]
```

**Append-only invariant** (line 52) — `updated_at: false` must remain:
```elixir
timestamps(type: :utc_datetime_usec, updated_at: false)
```

**`from_status`/`to_status` nil convention** (lines 78-88) — execution events follow the same pattern as approval events: leave both `nil`, carry transition in `event_type` + `metadata`. Do NOT put `:executed`/`:execution_failed` (ToolApproval statuses) into `to_status` — it is typed against `ToolProposal.status_values/0`. From RESEARCH.md Pitfall 7.

**`changeset/2`** (lines 62-76) — `actor_id` required; `from_status`/`to_status` optional; pass `metadata: %{attempt: n}` for per-attempt reconstructability. No structural change needed.

---

### `lib/cairnloop/governance/telemetry.ex` (MODIFY — utility/observability, event-driven)

**Analog:** self — complete file (82 lines)

**`@events` extension** (line 21):
```elixir
@events [:proposal_created, :proposal_blocked, :proposal_duplicate,
         :action_executed,    # NEW Phase 16
         :action_failed]      # NEW Phase 16
```

**`emit/3` guard clause** (lines 42-48) — unchanged; `when event in @events` guard silently drops unknown events. New events join `@events` to be accepted.

**New `@allowed_result_states` allow-list** — add beside the existing `@allowed_*` module attributes:
```elixir
@allowed_result_states [:not_executed, :succeeded, :failed, :unknown]
```

**`metadata/2` pattern-matched clause for execution events** (lines 51-61) — add a new head before the catch-all:
```elixir
def metadata(event, metadata) when event in [:action_executed, :action_failed] and is_map(metadata) do
  %{
    risk_tier: normalize_risk_tier(Map.get(metadata, :risk_tier)),
    approval_mode: normalize_approval_mode(Map.get(metadata, :approval_mode)),
    result_state: normalize_result_state(Map.get(metadata, :result_state)),
    tool_ref: normalize_tool_ref(Map.get(metadata, :tool_ref))
  }
end
```

**`normalize_*` private function shape** (lines 70-79) — mirror exactly:
```elixir
defp normalize_result_state(value) when value in @allowed_result_states, do: value
defp normalize_result_state(_), do: :unknown

# tool_ref: registry-validated → :unknown for anything not in Application.get_env(:cairnloop, :tools, [])
defp normalize_tool_ref(value) when is_binary(value) do
  configured = Application.get_env(:cairnloop, :tools, []) || []
  if Enum.any?(configured, fn mod -> Atom.to_string(mod) == value end), do: value, else: :unknown
end
defp normalize_tool_ref(_), do: :unknown
```

**`normalize_measurements/1`** (lines 63-67) — already handles `duration_ms`; unchanged:
```elixir
defp normalize_measurements(measurements) do
  %{
    duration_ms: measurements[:duration_ms] || 0,
    count: normalize_count(measurements[:count] || 1)
  }
end
```

**Telemetry emit position rule** (D-29) — always call `Cairnloop.Governance.Telemetry.emit/3` (or `Cairnloop.Telemetry.execute/3`) AFTER the `with` pipeline succeeds, never inside the clause list.

---

### `lib/cairnloop/workers/approval_resume_worker.ex` (MODIFY — worker, additive enqueue)

**Analog:** self — success branch lines 79-83

**Additive change only** — one line added at line 83 (after `transition_approval(:execution_pending)`). The "STOP" comment becomes "hand off to execution worker":
```elixir
# Current (line 83):
transition_approval(approval, :execution_pending, :revalidation_passed, nil, "system")
# Phase 16 additive (D16-04): enqueue execution worker — still never calls run/3
transition_approval(approval, :execution_pending, :revalidation_passed, nil, "system")
safe_enqueue(ToolExecutionWorker.new(%{"approval_id" => approval.id}))
```

`safe_enqueue/1` is already defined as a private function in this module (not needed — verified: `ApprovalResumeWorker` uses `Cairnloop.Telemetry.execute/3` directly and does NOT have its own `safe_enqueue`). Cross-check: `governance.ex` has `safe_enqueue/1` as `defp`; workers do not share it. Add the same three-line `defp safe_enqueue/1` verbatim with comment `# NOTE: mirrors Governance.safe_enqueue/1`.

---

### `lib/cairnloop/web/tool_proposal_presenter.ex` (MODIFY — presenter, transform)

**Analog:** self — `status_group/1` lines 55-69, `approval_outlook_for_approval/1` lines 135-156, `history_line/1` lines 301-348

**`status_group/1` extension** (add BEFORE the catch-all at line 69):
```elixir
# Add these two clauses before: def status_group(_), do: :blocked
def status_group(:executed), do: :done
def status_group(:execution_failed), do: :done  # (or :blocked if planner prefers visual distinction)
```
Critical: must appear BEFORE the catch-all `def status_group(_), do: :blocked` or `:executed` would display as "Blocked".

**`approval_outlook_for_approval/1` extension** (add after `:execution_pending` clause at line 142, before catch-all at line 156):
```elixir
def approval_outlook_for_approval(%{status: :executed} = approval) do
  summary = Map.get(approval, :result_summary) || Map.get(approval, "result_summary")
  "Action completed: #{summary || "Done."}"
end

def approval_outlook_for_approval(%{status: :execution_failed} = approval) do
  reason = Map.get(approval, :reason) || Map.get(approval, "reason")
  "Action failed: #{reason || "An error occurred."}"
end
```
Uses dual-key lookup pattern (atom + string) already present in `metadata_value/2` (lines 400-407) for JSONB string-key survival.

**`history_line/1` execution event clauses** (add BEFORE catch-all at line 348):
```elixir
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
String key `"attempt"` (not atom `:attempt`) because `metadata` comes from JSONB — same JSONB string-key posture as `metadata_value/2`.

---

### `lib/cairnloop/web/conversation_live.ex` (MODIFY — LiveView component, request-response)

**Analog:** self — `handle_info/2` reload pattern lines 25-26, `approve_action` handler lines 204-222

**`handle_info/2` for execution outcome PubSub** — mirror `{:draft_created, _}` handler (lines 25-26):
```elixir
# Existing pattern (line 25-26):
def handle_info({:draft_created, _draft_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end

# Phase 16 additions — mirror exactly:
def handle_info({:tool_executed, _approval_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end

def handle_info({:tool_execution_failed, _approval_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end
```

**PubSub broadcast topic** — `"conversation:#{conversation_id}"` (line 14). Phase 16 worker broadcasts to the same topic after co-commit; LiveView reloads via `reload_conversation_with_context/2`.

**Plain-assign reload** (line 282) — no streams; `reload_conversation_with_context/2` is already the standard pattern; no structural change needed (D16-12).

**Flash message copy** — mirror `approve_action` flash copy (lines 208-222); use calm, reason-forward operator copy (never raw terms):
```elixir
# Pattern from lines 208-212:
{:ok, _} ->
  {:noreply,
   socket
   |> put_flash(:info, "Action approved.")
   |> reload_conversation_with_context(socket.assigns.conversation.id)}
```

---

### `priv/repo/migrations/YYYYMMDD_add_execution_states.exs` (NEW — migration)

**Analog:** `priv/repo/migrations/20260524120001_add_tool_approvals.exs`

**Key finding from RESEARCH.md "Migration pattern":** No migration is needed for `ToolApproval.status` or `ToolProposal` reserved columns — both use `:string` storage (not a Postgres enum). New status atoms are accepted by Postgres automatically.

**Migration is needed only for:**
1. New indexes on `cairnloop_tool_approvals` if any are added (e.g., status filter for `:executed`/`:execution_failed` queries)
2. Any additional columns if the planner decides to add them

**Migration style** — from `20260524120001_add_tool_approvals.exs` lines 1-39:
```elixir
defmodule Cairnloop.Repo.Migrations.AddExecutionStates do
  use Ecto.Migration

  def change do
    # Example: add index for execution-outcome queries (if needed)
    create(index(:cairnloop_tool_approvals, [:status, :decided_at],
                 where: "status IN ('executed', 'execution_failed')"))
  end
end
```
Use `create/1`, `create(index(...))`, `create(unique_index(...))` — no `alter table` needed.

---

### `priv/test_host/migrations/…_add_run_key_to_messages.exs` (NEW — test-host migration)

**Analog:** `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs`

**Purpose:** Add `run_key :string` indexed column to `cairnloop_messages` for O(1) idempotency existence check. Without this, the `InternalNote` tool cannot do `repo.get_by(Message, run_key: run_key)`.

**Migration style** (from `20260101000000_create_host_owned_tables.exs` lines 1-10 + `20260524120001` index pattern):
```elixir
defmodule Cairnloop.TestHost.Migrations.AddRunKeyToMessages do
  use Ecto.Migration

  def change do
    alter table(:cairnloop_messages) do
      add(:run_key, :string)
    end
    create(unique_index(:cairnloop_messages, [:run_key],
                        where: "run_key IS NOT NULL"))
  end
end
```
Lives in `priv/test_host/migrations/` — NOT in `priv/repo/migrations/` (host-owned schema).

---

### `test/integration/tool_execution_worker_test.exs` (NEW — integration test)

**Analog:** `test/integration/approval_flow_test.exs` (lines 1-97)

**Module header + `use` + `setup`** (lines 1-47):
```elixir
defmodule Cairnloop.Integration.ToolExecutionWorkerTest do
  use Cairnloop.DataCase, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.{ToolApproval, ToolProposal}
  alias Cairnloop.Workers.{ApprovalResumeWorker, ToolExecutionWorker}

  import Cairnloop.Fixtures

  # Inline test tool — same pattern as PassTool in approval_flow_test.exs lines 20-41
  defmodule NoteWriteTool do
    use Cairnloop.Tool, risk_tier: :low_write, title: "Note", description: "Test"
    embedded_schema do
      field(:conversation_id, :string)
      field(:content, :string)
    end
    @impl Cairnloop.Tool
    def changeset(s, a), do: Ecto.Changeset.cast(s, a, [:conversation_id, :content])
    @impl Cairnloop.Tool
    def scope, do: []
    @impl Cairnloop.Tool
    def authorize(_a, _c), do: :ok
    @impl Cairnloop.Tool
    def run(_t, _a, _c), do: {:ok, %{message_id: 999}}
  end

  setup do
    Application.put_env(:cairnloop, :tools, [NoteWriteTool])
    on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
    :ok
  end
```

**Injectable `enqueue_fn` capturing pattern** (lines 51-52):
```elixir
test_pid = self()
capture = fn job -> send(test_pid, {:enqueued, job}); {:ok, job} end
```

**Worker invocation pattern** (lines 73-74):
```elixir
# Call perform/1 directly — no running Oban needed (project idiom from approval_flow_test.exs)
assert :ok = ToolExecutionWorker.perform(%Oban.Job{
  attempt: 1,
  max_attempts: 3,
  args: %{"approval_id" => approval.id}
})
```

**Fixture usage** (lines 54-67) — use `proposal_fixture/1`, `approval_fixture/2` from `test/support/fixtures.ex`:
```elixir
proposal = proposal_fixture(%{
  tool_ref: Atom.to_string(NoteWriteTool),
  approval_mode: :requires_approval,
  scope_snapshot: %{scopes: []}
})
```

**Key assertions to cover** (from RESEARCH.md "Observation Points"):
- `assert Repo.aggregate(Message, :count) == 1` — at-most-once write
- `assert Repo.get!(ToolApproval, id).status == :executed` — terminal guard on replay
- `assert Repo.get!(ToolProposal, id).attempt == 2` — attempt increment on transient failure
- `assert :execution_attempt_failed in event_types` — per-attempt events
- Telemetry bounded: `refute Map.has_key?(meta, :actor_id)` etc.

---

### `test/support/fixtures.ex` (MODIFY — test support)

**Analog:** self — `proposal_fixture/1` lines 27-48, `approval_fixture/2` lines 50-59

**Add `message_fixture/1`** — mirror `approval_fixture/2` shape:
```elixir
def message_fixture(attrs \\ %{}) do
  attrs = Map.new(attrs)
  defaults = %{
    content: "Test internal note",
    role: "internal_note",
    conversation_id: nil,
    run_key: nil,
    metadata: %{}
  }
  {:ok, message} =
    %Cairnloop.Message{}
    |> Cairnloop.Message.changeset(Map.merge(defaults, attrs))
    |> Repo.insert()
  message
end
```

---

## Shared Patterns

### Repo Indirection
**Source:** `lib/cairnloop/workers/approval_resume_worker.ex` lines 40-42; `lib/cairnloop/governance.ex` (throughout)
**Apply to:** `ToolExecutionWorker`, `InternalNote.run/3`, any new governance facade functions
```elixir
defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end
```
NEVER use `Cairnloop.Repo` directly inside library code.

### Sequential `with` Co-Commit (NOT `Ecto.Multi`)
**Source:** `lib/cairnloop/governance.ex` lines 103-122 (`update_approval_with_event/3`)
**Apply to:** `ToolExecutionWorker` execution success/failure recording, new governance facade APIs
```elixir
with {:ok, updated} <- repo().update(changeset),
     {:ok, _event} <- repo().insert(event_changeset) do
  # Telemetry AFTER — never inside the with clause list (D-29)
  Cairnloop.Governance.Telemetry.emit(...)
  {:ok, updated}
end
```

### Injectable `enqueue_fn` for Testability
**Source:** `lib/cairnloop/governance.ex` lines 603-604 (`approve/3`)
**Apply to:** Any new public facade API that enqueues an Oban worker
```elixir
def my_api(id, opts \\ []) do
  enqueue_fn = Keyword.get(opts, :enqueue_fn, &safe_enqueue/1)
  ...
  enqueue_fn.(SomeWorker.new(%{"id" => id}))
end
```

### Telemetry After `with`, Not Inside
**Source:** `lib/cairnloop/governance.ex` lines 111-121; `lib/cairnloop/workers/approval_resume_worker.ex` lines 167-174
**Apply to:** All execution outcome recording, all approval transitions in Phase 16
```elixir
with {:ok, _} <- ...,
     {:ok, _} <- ... do
  # Only here — AFTER all DB writes succeed
  Cairnloop.Governance.Telemetry.emit(:action_executed, %{count: 1, duration_ms: ms}, labels)
  :ok
end
```

### `humanize_reason/1` — Never `inspect/1` on Operator-Visible Reasons
**Source:** `lib/cairnloop/workers/approval_resume_worker.ex` lines 180-201
**Apply to:** `ToolExecutionWorker` failure recording, any new facade error returns
```elixir
defp humanize_reason(reason) do
  case reason do
    %Ecto.Changeset{} = cs -> cs |> Ecto.Changeset.traverse_errors(...) |> ...
    atom when is_atom(atom) -> Atom.to_string(atom)
    binary when is_binary(binary) -> binary
    _ -> "blocked"
  end
end
```

### `normalize_*` Allow-List Guard Pattern
**Source:** `lib/cairnloop/governance/telemetry.ex` lines 70-79
**Apply to:** New `normalize_result_state/1` and `normalize_tool_ref/1` in `Governance.Telemetry`
```elixir
defp normalize_risk_tier(value) when value in @allowed_risk_tiers, do: value
defp normalize_risk_tier(_), do: :unknown
```

### Append-Only Event with `nil` `from_status`/`to_status`
**Source:** `lib/cairnloop/workers/approval_resume_worker.ex` lines 153-165; `lib/cairnloop/governance/tool_action_event.ex` lines 78-88
**Apply to:** All Phase 16 execution `ToolActionEvent` inserts
```elixir
%ToolActionEvent{}
|> ToolActionEvent.changeset(%{
  tool_proposal_id: proposal.id,
  event_type: :execution_succeeded,
  from_status: nil,
  to_status: nil,
  actor_id: "system",
  reason: nil,
  metadata: %{attempt: n}
})
|> repo().insert()
```

### JSONB String-Key Dual Lookup
**Source:** `lib/cairnloop/web/tool_proposal_presenter.ex` lines 400-407 (`metadata_value/2`)
**Apply to:** All presenter functions that read `metadata` from JSONB-sourced maps
```elixir
defp metadata_value(map, key) when is_map(map) do
  case Map.fetch(map, key) do
    {:ok, value} -> value
    :error -> Map.get(map, Atom.to_string(key))
  end
end
```

---

## No Analog Found

No Phase 16 files are entirely without analog. All new files have at least a role-match.

---

## Metadata

**Analog search scope:** `lib/cairnloop/workers/`, `lib/cairnloop/governance/`, `lib/cairnloop/web/`, `lib/cairnloop/tool*.ex`, `priv/repo/migrations/`, `priv/test_host/migrations/`, `test/integration/`, `test/support/`
**Files scanned (direct reads):** 17
**Pattern extraction date:** 2026-05-25
