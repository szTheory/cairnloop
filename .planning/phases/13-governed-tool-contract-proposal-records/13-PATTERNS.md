# Phase 13: Governed Tool Contract & Proposal Records - Pattern Map

**Mapped:** 2026-05-23
**Files analyzed:** 11 (3 modified in place, 8 new)
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/tool.ex` | behaviour/macro | compile-time transform | `lib/cairnloop/automation/workers/draft_worker.ex` (Oban.Worker `use` macro pattern) | role-match |
| `lib/cairnloop/tool/spec.ex` | model (pure struct) | — | `lib/cairnloop/knowledge_automation/article_suggestion.ex` (embedded evidence schema as spec data) | partial-match |
| `lib/cairnloop/tool_registry.ex` | service | request-response | `lib/cairnloop/tool_registry.ex` itself (evolve in place) | exact |
| `lib/cairnloop/governance.ex` | context facade | CRUD + request-response | `lib/cairnloop/knowledge_automation.ex` + `lib/cairnloop/retrieval.ex` | exact |
| `lib/cairnloop/governance/tool_proposal.ex` | model/schema | CRUD | `lib/cairnloop/knowledge_automation/review_task.ex` | exact |
| `lib/cairnloop/governance/tool_action_event.ex` | model/schema | append-only event | `lib/cairnloop/knowledge_automation/review_task_event.ex` | exact |
| `lib/cairnloop/governance/policy.ex` | service | request-response | `lib/cairnloop/retrieval.ex` `validate_scope` arm | role-match |
| `lib/cairnloop/governance/telemetry.ex` | utility/telemetry | event-driven | `lib/cairnloop/knowledge_automation/telemetry.ex` | exact |
| `priv/repo/migrations/TIMESTAMP_add_tool_proposals_and_action_events.exs` | migration | — | `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` | exact |
| `lib/cairnloop/web/conversation_live.ex` (modified) | component/LiveView | request-response | itself (evolve in place) + `lib/cairnloop/knowledge_automation.ex` flash pattern | exact |
| `test/cairnloop/governance*` + `test/cairnloop/tool_test.exs` + `test/cairnloop/web/conversation_live_test.exs` | test | — | `test/cairnloop/knowledge_automation/review_task_test.exs` | exact |

---

## Pattern Assignments

### `lib/cairnloop/tool.ex` (behaviour/macro, evolve in place)

**Analog:** `lib/cairnloop/automation/workers/draft_worker.ex` (Oban.Worker declarative `use` macro) and the current `lib/cairnloop/tool.ex` itself.

**Current state — full file (lines 1-47):**
```elixir
defmodule Cairnloop.Tool do
  @type actor_id :: String.t()
  @type context :: map()

  @callback can_execute?(actor_id(), context()) :: boolean()
  @callback execute(tool :: struct(), actor_id(), context()) :: {:ok, any()} | {:error, any()}
  @callback changeset(tool :: struct(), attrs :: map()) :: Ecto.Changeset.t()
  @callback custom_ui() :: module() | nil

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @behaviour Cairnloop.Tool

      @impl Cairnloop.Tool
      def custom_ui, do: nil

      defoverridable custom_ui: 0
    end
  end
end
```

**Oban.Worker declarative opts analog** (`lib/cairnloop/automation/workers/draft_worker.ex` lines 1-6):
```elixir
defmodule Cairnloop.Automation.Workers.DraftWorker do
  use Oban.Worker,
    queue: :default,
    unique: [period: 60, states: [:scheduled]],
    replace: [scheduled: [:scheduled_at]]
  # ...
end
```
Mirror this idiom: `use Cairnloop.Tool, risk_tier: :read_only, title: "...", description: "..."` — declarative opts at `use` time, behaviour callbacks for logic, `__tool_spec__/0` accessor mirrors `__oban_opts__/0`.

**Phase 13 cutover shape** (from RESEARCH.md — copy exactly):
```elixir
defmodule Cairnloop.Tool do
  @type actor_id :: String.t()
  @type context :: map()

  # REMOVED: @callback can_execute?/2
  # RENAMED: execute/3 → run/3 (NOT called in Phase 13)
  @callback run(tool :: struct(), actor_id(), context()) :: {:ok, any()} | {:error, any()}
  @callback changeset(tool :: struct(), attrs :: map()) :: Ecto.Changeset.t()
  @callback scope() :: [atom()]
  @callback authorize(actor_id(), context()) :: :ok | {:error, reason :: atom()}
  @callback custom_ui() :: module() | nil
  # preview/1 is @optional_callbacks — no default, Phase 14 seam
  @optional_callbacks [preview: 1, custom_ui: 0]

  @valid_risk_tiers [:read_only, :low_write, :high_write, :destructive]
  @valid_approval_modes [:auto, :requires_approval, :always_block]

  defmacro __using__(opts) do
    risk_tier = Keyword.get(opts, :risk_tier)
    approval_mode = Keyword.get(opts, :approval_mode)

    # Validate AT COMPILE TIME — inside defmacro body, before quote do
    if risk_tier && risk_tier not in @valid_risk_tiers do
      raise CompileError,
        description: "invalid risk_tier #{inspect(risk_tier)}, expected one of #{inspect(@valid_risk_tiers)}"
    end
    if approval_mode && approval_mode not in @valid_approval_modes do
      raise CompileError,
        description: "invalid approval_mode #{inspect(approval_mode)}, expected one of #{inspect(@valid_approval_modes)}"
    end

    derived_approval_mode = approval_mode || Cairnloop.Tool.derive_approval_mode(risk_tier)

    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @behaviour Cairnloop.Tool

      @__tool_spec__ %Cairnloop.Tool.Spec{
        risk_tier: unquote(risk_tier),
        approval_mode: unquote(derived_approval_mode),
        idempotency: unquote(Keyword.get(opts, :idempotency)),
        result_states: unquote(Keyword.get(opts, :result_states, [])),
        title: unquote(Keyword.get(opts, :title)),
        description: unquote(Keyword.get(opts, :description))
      }

      def __tool_spec__, do: @__tool_spec__

      @impl Cairnloop.Tool
      def authorize(_actor_id, _context), do: {:error, :no_policy_defined}

      @impl Cairnloop.Tool
      def custom_ui, do: nil

      defoverridable authorize: 2, custom_ui: 0
    end
  end

  # Called at macro-expansion time (not runtime) so it is a plain def, not defmacro
  def derive_approval_mode(:read_only), do: :auto
  def derive_approval_mode(:low_write), do: :requires_approval
  def derive_approval_mode(:high_write), do: :requires_approval
  def derive_approval_mode(:destructive), do: :always_block
  def derive_approval_mode(_), do: :always_block
end
```

**Key rule:** Compile-time validation (`raise CompileError`) MUST be inside the `defmacro __using__(opts)` body BEFORE the `quote do...end` block. If it is inside `quote do`, it runs at the calling module's compile time as dead code — it must run when the tool module is compiled.

---

### `lib/cairnloop/tool/spec.ex` (pure data struct, new)

**Analog:** `lib/cairnloop/knowledge_automation/article_suggestion.ex` (embedded schemas as typed data) — but `Spec` is a plain struct, not an Ecto schema. No DB, no behaviour.

**`ArticleSuggestionEvidence` embedded schema as closest precedent for typed spec data** — discrete, bounded, serializable fields. The `Spec` is even simpler: a plain `defstruct`.

**Pattern to copy:**
```elixir
defmodule Cairnloop.Tool.Spec do
  @moduledoc """
  Pure data struct carrying compile-time governed-tool metadata.
  No behaviour, no database. Forward-compatible with MCP tool definition projection (Phase 17).
  """

  @enforce_keys [:risk_tier, :approval_mode]
  defstruct [
    :risk_tier,      # atom — :read_only | :low_write | :high_write | :destructive
    :approval_mode,  # atom — :auto | :requires_approval | :always_block
    :idempotency,    # atom or map — idempotency key derivation strategy
    :result_states,  # list of atoms — declared result vocabulary
    :title,          # string — human-readable name (Phase 14 preview, Phase 17 MCP "title")
    :description     # string — operator description (Phase 17 MCP "description")
  ]
end
```

No `use Ecto.Schema`. No callbacks. This struct is pure data that `__tool_spec__/0` returns and that `Governance.Policy.resolve/3` reads from.

---

### `lib/cairnloop/tool_registry.ex` (service, evolve in place)

**Analog:** Current `lib/cairnloop/tool_registry.ex` (evolve in place).

**Current full file (lines 1-18):**
```elixir
defmodule Cairnloop.ToolRegistry do
  @spec get_available_tools(Cairnloop.Tool.actor_id(), Cairnloop.Tool.context()) :: [module()]
  def get_available_tools(actor_id, context) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    Enum.filter(configured_tools, fn tool_module ->
      tool_module.can_execute?(actor_id, context)  # ← REMOVE: replace with scope/0 + authorize/2
    end)
  end
end
```

**Phase 13 cutover shape:**
```elixir
defmodule Cairnloop.ToolRegistry do
  # Called at boot (from Application.start/2) to fail fast on misconfigured tools.
  def validate_configured_tools! do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []
    Enum.each(configured_tools, fn tool_module ->
      unless function_exported?(tool_module, :__tool_spec__, 0) do
        raise ArgumentError, "Tool #{inspect(tool_module)} does not implement Cairnloop.Tool behaviour or is missing __tool_spec__/0"
      end
      spec = tool_module.__tool_spec__()
      unless is_struct(spec, Cairnloop.Tool.Spec) do
        raise ArgumentError, "Tool #{inspect(tool_module)}.__tool_spec__/0 must return %Cairnloop.Tool.Spec{}"
      end
    end)
  end

  # Advisory UX filter only — Governance.validate/3 is the authoritative gate.
  @spec get_available_tools(Cairnloop.Tool.actor_id(), Cairnloop.Tool.context()) :: [module()]
  def get_available_tools(actor_id, context) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []
    Enum.filter(configured_tools, fn tool_module ->
      Enum.all?(tool_module.scope(), &(&1 in Map.get(context, :scopes, []))) &&
        tool_module.authorize(actor_id, context) == :ok
    end)
  end

  # Resolves a string tool_ref to a module WITHOUT String.to_existing_atom/1.
  # Atom.to_string/1 and inspect/1 produce identical strings for modules: "Elixir.MyTool".
  @spec find_tool_module(String.t()) :: {:ok, module()} | {:error, :unknown_tool}
  def find_tool_module(tool_ref) when is_binary(tool_ref) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []
    case Enum.find(configured_tools, fn mod -> Atom.to_string(mod) == tool_ref end) do
      nil -> {:error, :unknown_tool}
      mod -> {:ok, mod}
    end
  end
end
```

---

### `lib/cairnloop/governance.ex` (context facade, new)

**Analog:** `lib/cairnloop/knowledge_automation.ex` (narrow public facade, `repo()` private helper, `with` pipeline, telemetry after success) and `lib/cairnloop/retrieval.ex` (`validate_scope` + fail-closed return shape).

**Facade structure from `lib/cairnloop/knowledge_automation.ex` (lines 1-38):**
```elixir
defmodule Cairnloop.KnowledgeAutomation do
  import Ecto.Query
  alias Cairnloop.KnowledgeAutomation.{ReviewTask, ReviewTaskEvent, Telemetry, ...}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)  # ← copy exactly
  end
  # ...
end
```

**Fail-closed return shape from `lib/cairnloop/retrieval.ex` (lines 12-33):**
```elixir
def search(query, opts \\ []) do
  case validate_scope(opts) do
    :ok ->
      # proceed
    {:error, reason} ->
      {:error, reason}  # bounded reason atom, never generic
  end
end
```

**Transaction co-commit from `lib/cairnloop/knowledge_automation.ex` (lines 142-157) — CREATE path:**
```elixir
with {:ok, task} <-
       %ReviewTask{}
       |> ReviewTask.changeset(attrs)
       |> repo().insert(),
     {:ok, _event} <-
       %ReviewTaskEvent{}
       |> ReviewTaskEvent.changeset(%{
         review_task_id: task.id,
         event_type: :task_created,
         to_status: task.status,
         actor_id: actor_id || "system",
         metadata: %{article_suggestion_id: suggestion.id}
       })
       |> repo().insert() do
  {:ok, task}
end
```
Mirror this exactly for `propose/3`: insert `ToolProposal` first, then insert `ToolActionEvent` with the new `tool_proposal_id`. Telemetry AFTER the `with` succeeds.

**`update_task_with_event` pattern from `lib/cairnloop/knowledge_automation.ex` (lines 1771-1779):**
```elixir
defp update_task_with_event(task, changeset, event_attrs, result_type \\ :ok) do
  with {:ok, updated_task} <- repo().update(changeset),
       {:ok, _event} <-
         %ReviewTaskEvent{}
         |> ReviewTaskEvent.changeset(Map.put(event_attrs, :review_task_id, task.id))
         |> repo().insert() do
    emit_review_task_event(updated_task, task, event_attrs)  # telemetry AFTER with
    {result_type, updated_task}
  end
end
```

**`Governance.validate/3` pure pipeline shape** (from RESEARCH.md — ordered `with` clauses enforce precedence):
```elixir
def validate(tool_ref, actor_id, context) do
  with {:ok, tool_module} <- Cairnloop.ToolRegistry.find_tool_module(tool_ref),
       {:ok, input} <- validate_input(tool_module, context),
       :ok <- check_scope(tool_module, actor_id, context),
       :ok <- tool_module.authorize(actor_id, context) do
    {:ok, build_validated_attrs(tool_module, input, actor_id, context)}
  else
    {:error, :unknown_tool}         -> {:blocked, :unsupported, :unknown_tool}
    {:error, :invalid_input, cs}    -> {:blocked, :needs_input, cs}
    {:error, :scope_mismatch, r}    -> {:blocked, :scope_invalid, r}
    {:error, reason}                -> {:blocked, :policy_denied, reason}
  end
end
```
Clause order is the precedence enforcement: unsupported → needs_input → scope_invalid → policy_denied. Never reorder.

---

### `lib/cairnloop/governance/tool_proposal.ex` (schema, new)

**Analog:** `lib/cairnloop/knowledge_automation/review_task.ex` — exact idiom to mirror.

**`@status_values` module attribute + `Ecto.Enum` pattern** (lines 8-15):
```elixir
@status_values [
  :pending_review,
  :review_needed,
  :approved_ready_to_publish,
  :deferred,
  :rejected,
  :published
]
# ...
field(:status, Ecto.Enum, values: @status_values, default: :pending_review)
```

**Public accessor for enum value lists** (line 90):
```elixir
def status_values, do: @status_values
def decision_values, do: @decision_values
```
Copy: `def status_values, do: @status_values` — `ToolActionEvent` references `ToolProposal.status_values()` for its `from_status`/`to_status` Ecto.Enum values.

**Multiple named changesets pattern** (lines 61-111):
```elixir
def changeset(review_task, attrs) do
  review_task
  |> cast(attrs, [...])
  |> validate_required([:article_suggestion_id, :status, :tenant_scope])
  |> validate_host_scope()
  |> validate_decision_metadata()
  |> unique_constraint(:article_suggestion_id,
    name: :cairnloop_review_tasks_one_active_task_per_suggestion_index
  )
end

def decision_changeset(review_task, status, decision, reason, actor_id, decided_at, attrs \\ %{}) do
  ...
end
```
Phase 13 `ToolProposal` needs: `changeset/2` (initial create) + `blocked_changeset/3` (for non-`:proposed` terminal outcomes). Keep changesets named and targeted.

**`has_many` + `belongs_to` FKs** (lines 56):
```elixir
has_many(:events, ReviewTaskEvent)
```
Mirror: `has_many(:events, Cairnloop.Governance.ToolActionEvent)`.

**Conditional `validate_required` pattern** (lines 129-136):
```elixir
defp validate_decision_metadata(changeset) do
  if get_field(changeset, :status) in @decision_required_statuses do
    changeset
    |> validate_required([:last_decision, :last_reason, :last_actor_id, :last_decided_at])
  else
    changeset
  end
end
```

**Full `ToolProposal` schema shape** (from RESEARCH.md):
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
  # Phase 16 reserved (D-22):
  field(:attempt, :integer, default: 0)
  field(:oban_job_id, :integer)
  field(:result_state, Ecto.Enum, values: @result_state_values, default: :not_executed)
  field(:result_summary, :string)

  has_many(:events, Cairnloop.Governance.ToolActionEvent)
  timestamps(type: :utc_datetime_usec)
end
```

**Snapshot field note:** NOT `embeds_many` (unlike `ArticleSuggestion.evidence_snapshot`). Use three separate `:map` fields: `input_snapshot`, `scope_snapshot`, `policy_snapshot`. Each map holds one trust category; no opaque blob mixing trust levels (D-24).

---

### `lib/cairnloop/governance/tool_action_event.ex` (append-only schema, new)

**Analog:** `lib/cairnloop/knowledge_automation/review_task_event.ex` — exact idiom.

**Full analog file (lines 1-54):**
```elixir
defmodule Cairnloop.KnowledgeAutomation.ReviewTaskEvent do
  use Ecto.Schema
  import Ecto.Changeset
  alias Cairnloop.KnowledgeAutomation.ReviewTask

  @event_type_values [
    :task_created,
    :decision_recorded,
    :publish_recorded,
    :reindex_recorded,
    :material_edit_after_approval
  ]

  schema "cairnloop_review_task_events" do
    field(:event_type, Ecto.Enum, values: @event_type_values)
    field(:from_status, Ecto.Enum, values: ReviewTask.status_values())
    field(:to_status, Ecto.Enum, values: ReviewTask.status_values())
    field(:decision, Ecto.Enum, values: ReviewTask.decision_values())
    field(:reason, Ecto.Enum, values: ReviewTask.reason_values())
    field(:actor_id, :string)
    field(:notes, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:review_task, ReviewTask)

    timestamps(type: :utc_datetime_usec, updated_at: false)  # ← append-only: no updated_at
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:review_task_id, :event_type, :from_status, :to_status,
                    :decision, :reason, :actor_id, :notes, :metadata])
    |> validate_required([:review_task_id, :event_type, :to_status, :actor_id])
    |> validate_metadata()
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      value when is_map(value) -> changeset
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end
  # NOTE: No update/1 or delete/1 — insert-only API enforces append-only invariant.
end
```

**Phase 13 `ToolActionEvent` mirrors exactly:**
- `timestamps(type: :utc_datetime_usec, updated_at: false)` — mandatory, enforces append-only
- Cross-schema enum reference: `field(:from_status, Ecto.Enum, values: ToolProposal.status_values())`
- `validate_metadata/1` pattern copied verbatim
- No `update/1`, no `delete/1` in module or public facade
- `@event_type_values [:proposal_created, :proposal_blocked]` (Phase 16 extends with execution events)

**`from_status` is nil for `proposal_created` events** — first event has no prior status. The changeset must NOT require `from_status` (only `:to_status` is required).

---

### `lib/cairnloop/governance/policy.ex` (service, new)

**Analog:** `lib/cairnloop/retrieval.ex` `validate_scope` arm — a single bounded function that is the Phase 15 extension seam.

**Pattern from `lib/cairnloop/retrieval.ex` (lines 12-33) — fail-closed validate function:**
```elixir
case validate_scope(opts) do
  :ok -> # proceed
  {:error, reason} -> {:error, reason}
end
```

**Phase 13 `Governance.Policy` shape:**
```elixir
defmodule Cairnloop.Governance.Policy do
  @moduledoc """
  Approval-mode resolver. Phase 15 seam: extend ONLY this module to factor in
  actor scope + runtime context. No schema or call-site change needed.
  """

  def resolve(tool_module, _actor_id, _context) do
    spec = tool_module.__tool_spec__()
    # Precedence: tool declaration → host config override → tier default
    spec.approval_mode
    || host_config_override(spec.risk_tier)
    || Cairnloop.Tool.derive_approval_mode(spec.risk_tier)
  end

  defp host_config_override(risk_tier) do
    overrides = Application.get_env(:cairnloop, :approval_mode_overrides, %{})
    Map.get(overrides, risk_tier)
  end
end
```

Phase 15 extends ONLY `resolve/3` — no other function or schema changes.

---

### `lib/cairnloop/governance/telemetry.ex` (utility, new)

**Analog:** `lib/cairnloop/knowledge_automation/telemetry.ex` — exact idiom.

**`KnowledgeAutomation.Telemetry` full file (lines 1-107) — key patterns:**

Module-level allow-lists (lines 11-52):
```elixir
@events [:gap_candidate, :suggestion_outcome, :review_decision, :publish_outcome, :reindex_outcome]
@allowed_surfaces [:conversation_thread, :review_lane, :worker, :api, :unspecified]
@allowed_outcomes [:created, :reused, :queued, :ready, :failed, ...]
@allowed_reasons [:unspecified, :ready_to_publish, :rejected, ...]
```

`event_name/1` guard pattern (line 54):
```elixir
def event_name(event) when event in @events, do: [:cairnloop, :knowledge_automation, event]
```

`emit/3` guard + `Cairnloop.Telemetry.execute/3` delegation (lines 56-62):
```elixir
def emit(event, measurements, metadata) when event in @events do
  Telemetry.execute(
    [:knowledge_automation, event],
    normalize_measurements(measurements),
    metadata(event, metadata)
  )
end
```

`metadata/2` normalization (lines 64-79):
```elixir
def metadata(_event, metadata) when is_map(metadata) do
  %{
    surface: normalize_surface(Map.get(metadata, :surface)),
    outcome: normalize_outcome(Map.get(metadata, :outcome)),
    reason: normalize_reason(Map.get(metadata, :reason)),
    # ...
  }
end
```

Normalize-with-default pattern (lines 87-106):
```elixir
defp normalize_outcome(value) when value in @allowed_outcomes, do: value
defp normalize_outcome(_), do: :failed  # fail-closed default

defp normalize_count(value) when is_integer(value) and value >= 0, do: min(value, 99)
defp normalize_count(_), do: 0
```

**`Cairnloop.Telemetry.execute/3` base layer** (`lib/cairnloop/telemetry.ex` lines 58-60):
```elixir
def execute(event_suffix, measurements, metadata) when is_list(event_suffix) do
  :telemetry.execute([:cairnloop | event_suffix], measurements, metadata)
end
```

**`Cairnloop.Governance.Telemetry` phase 13 shape:**
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

Telemetry is emitted AFTER `repo().insert()` succeeds — never inside the `with` pipeline (D-29, mirrors `emit_review_task_event` called after `with` on line 1777).

---

### `priv/repo/migrations/TIMESTAMP_add_tool_proposals_and_action_events.exs` (migration, new)

**Analog:** `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` — exact style.

**Full analog migration (lines 1-66):**
```elixir
defmodule Cairnloop.Repo.Migrations.AddReviewTasksAndEvents do
  use Ecto.Migration

  def change do
    create table(:cairnloop_review_tasks) do
      add(:article_suggestion_id,
        references(:cairnloop_article_suggestions, on_delete: :delete_all), null: false)
      add(:status, :string, null: false, default: "pending_review")
      add(:tenant_scope, :string, null: false)
      # ... more fields
      timestamps(type: :utc_datetime_usec)
    end

    create(index(:cairnloop_review_tasks, [:status, :inserted_at]))
    create(unique_index(:cairnloop_review_tasks, [:article_suggestion_id],
      name: :cairnloop_review_tasks_one_active_task_per_suggestion_index,
      where: "status IN ('pending_review', ...)"
    ))

    create table(:cairnloop_review_task_events) do
      add(:review_task_id, references(:cairnloop_review_tasks, on_delete: :delete_all), null: false)
      add(:event_type, :string, null: false)
      add(:from_status, :string)       # nullable — nil for first event
      add(:to_status, :string, null: false)
      # ...
      add(:metadata, :map, null: false, default: %{})
      timestamps(type: :utc_datetime_usec, updated_at: false)  # append-only
    end

    create(index(:cairnloop_review_task_events, [:review_task_id, :inserted_at]))
    create(index(:cairnloop_review_task_events, [:event_type, :inserted_at]))
  end
end
```

**Key style rules to copy exactly:**
- Status columns: `:string` type, NOT Postgres `ENUM` — Ecto.Enum validates in app
- `:map` fields: `null: false, default: %{}`
- Append-only events table: `timestamps(type: :utc_datetime_usec, updated_at: false)`
- FK on events: `references(:cairnloop_tool_proposals, on_delete: :delete_all), null: false`
- Idempotency index: `create(unique_index(:cairnloop_tool_proposals, [:idempotency_key]))` — not a partial index
- Phase 16 reserved columns: `attempt`, `oban_job_id`, `result_state`, `result_summary` — declare now, unused in Phase 13

---

### `lib/cairnloop/web/conversation_live.ex` (modify in place)

**Analog:** Itself — existing handler pattern + `lib/cairnloop/knowledge_automation.ex` fail-closed flash style.

**Current `execute_tool` handler to replace entirely (lines 173-205):**
```elixir
def handle_event("execute_tool", %{"tool" => tool_name} = params, socket) do
  tool_module = String.to_existing_atom(tool_name)  # ← REMOVE (D-19)
  actor_id = socket.assigns.conversation.host_user_id
  context = socket.assigns.host_context

  if tool_module.can_execute?(actor_id, context) do  # ← REMOVE (D-06)
    tool_params = params["tool_params"] || %{}
    changeset = tool_module.changeset(struct(tool_module), tool_params)
    if changeset.valid? do
      tool_struct = Ecto.Changeset.apply_changes(changeset)
      try do  # ← REMOVE try/rescue (D-27)
        case tool_module.execute(tool_struct, actor_id, context) do  # ← REMOVE execute (D-05)
          {:ok, result} -> {:noreply, put_flash(socket, :info, result)}
          {:error, reason} -> {:noreply, put_flash(socket, :error, "Execution failed: ...")}
        end
      rescue
        e -> {:noreply, put_flash(socket, :error, "Tool execution failed: ...")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid tool parameters.")}
    end
  else
    {:noreply, put_flash(socket, :error, "Not authorized to execute this tool.")}
  end
end
```

**Phase 13 replacement (D-27):**
```elixir
def handle_event("execute_tool", %{"tool" => tool_ref} = params, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  context = socket.assigns.host_context
  # Pass params as part of context so Governance.validate/3 can call changeset/2
  context = Map.put(context, :tool_params, params["tool_params"] || %{})

  case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
    {:ok, proposal} ->
      {:noreply, put_flash(socket, :info, "Proposed — pending review. (##{proposal.id})")}

    {:blocked, outcome, reason} ->
      {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}
  end
end

defp failure_reason_message(:unsupported, _reason), do: "Unknown tool — proposal rejected."
defp failure_reason_message(:needs_input, _cs), do: "Invalid tool parameters."
defp failure_reason_message(:scope_invalid, reason), do: "Tool not available in this context: #{reason}."
defp failure_reason_message(:policy_denied, reason), do: "Tool call not permitted: #{reason}."
defp failure_reason_message(outcome, reason), do: "Tool proposal blocked (#{outcome}): #{inspect(reason)}."
```

No `try/rescue`. No `run/3`. No `execute/3`. No `String.to_existing_atom/1`. Returns `proposal.id` in flash so Phase 14 can swap for a real timeline card (D-27).

**`context_pane/1` filter update (line 426):**
```elixir
# Before (line 426-427):
:available_tools,
Cairnloop.ToolRegistry.get_available_tools(assigns.actor_id, assigns.context)

# After: same call — ToolRegistry.get_available_tools/2 is updated to use scope/0+authorize/2
# No LiveView template change needed — the registry function itself changes.
```

**`tool_renderer/1` — no template change needed (lines 510-539):**
```elixir
# phx-value-tool={inspect(@tool)} still produces "Elixir.MyApp.Tools.RefundTool"
# Governance.validate/3 resolves via Atom.to_string(module) == tool_ref — these match.
# Do NOT change the template event name "execute_tool".
```

---

### Test files (new — `test/cairnloop/tool_test.exs`, `test/cairnloop/governance_test.exs`, `test/cairnloop/governance/tool_proposal_test.exs`, `test/cairnloop/governance/tool_action_event_test.exs`, `test/cairnloop/web/conversation_live_test.exs`)

**Analog:** `test/cairnloop/knowledge_automation/review_task_test.exs` — MockRepo / `Process.get/put` pattern.

**MockRepo module definition (lines 9-96):**
```elixir
defmodule Cairnloop.KnowledgeAutomation.ReviewTaskTest do
  use ExUnit.Case, async: false  # ← async: false required when using Process.put

  defmodule MockRepo do
    def insert(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        struct =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> maybe_put_id()
          |> Map.put_new(:inserted_at, DateTime.utc_now())
          |> Map.put_new(:updated_at, DateTime.utc_now())

        persist_inserted(struct)
        Process.put(:last_inserted, struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def update(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        struct = changeset |> Ecto.Changeset.apply_changes() |> Map.put(:updated_at, DateTime.utc_now())
        Process.put(:last_updated, struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    defp persist_inserted(%ToolProposal{} = proposal) do
      Process.put(:tool_proposals, [proposal | Process.get(:tool_proposals, [])])
    end
    defp persist_inserted(%ToolActionEvent{} = event) do
      Process.put(:tool_action_events, [event | Process.get(:tool_action_events, [])])
    end
    defp persist_inserted(_struct), do: :ok
  end
end
```

**MockRepo injection pattern (setup block):**
```elixir
setup do
  Application.put_env(:cairnloop, :repo, MockRepo)
  on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
  :ok
end
```

**`async: false`** is mandatory — `Process.put/get` is process-local; parallel tests would share the BEAM process dictionary unpredictably.

**Compile-time error test pattern** (from RESEARCH.md):
```elixir
test "raises CompileError for invalid risk_tier" do
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
end
```

**Deny-by-default test:**
```elixir
test "authorize/2 default returns {:error, :no_policy_defined}" do
  defmodule MinimalTool do
    use Cairnloop.Tool, risk_tier: :read_only, title: "Test"
    def changeset(s, a), do: Ecto.Changeset.cast(s, a, [])
    def run(s, _actor, _ctx), do: {:ok, s}
    def scope, do: []
  end
  assert MinimalTool.authorize("actor_1", %{}) == {:error, :no_policy_defined}
end
```

---

## Shared Patterns

### `repo()` private helper
**Source:** `lib/cairnloop/knowledge_automation.ex` line 37 and `lib/cairnloop/retrieval.ex` line 9
**Apply to:** `lib/cairnloop/governance.ex`
```elixir
defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end
```

### `Ecto.Enum` + module attribute value lists
**Source:** `lib/cairnloop/knowledge_automation/review_task.ex` lines 8-35 and `lib/cairnloop/retrieval/gap_event.ex` lines 7-23
**Apply to:** `ToolProposal`, `ToolActionEvent`
```elixir
@status_values [:proposed, :needs_input, :scope_invalid, :policy_denied]

field(:status, Ecto.Enum, values: @status_values, default: :proposed)

def status_values, do: @status_values  # public accessor for cross-schema references
```

### `validate_metadata/1` changeset helper
**Source:** `lib/cairnloop/knowledge_automation/review_task_event.ex` lines 47-53
**Apply to:** `ToolActionEvent`
```elixir
defp validate_metadata(changeset) do
  case get_field(changeset, :metadata) do
    nil -> put_change(changeset, :metadata, %{})
    value when is_map(value) -> changeset
    _ -> add_error(changeset, :metadata, "must be a map")
  end
end
```

### Telemetry AFTER `with` (never inside it)
**Source:** `lib/cairnloop/knowledge_automation.ex` line 1777 — `emit_review_task_event(...)` called after the `with` block, not inside it
**Apply to:** `lib/cairnloop/governance.ex` `propose/3` implementation
```elixir
with {:ok, proposal} <- repo().insert(...),
     {:ok, _event} <- repo().insert(...) do
  Cairnloop.Governance.Telemetry.emit(:proposal_created, %{count: 1}, %{...})  # AFTER
  {:ok, proposal}
end
```

### Bounded metadata normalization
**Source:** `lib/cairnloop/knowledge_automation/telemetry.ex` lines 87-106
**Apply to:** `lib/cairnloop/governance/telemetry.ex`
```elixir
defp normalize_outcome(value) when value in @allowed_outcomes, do: value
defp normalize_outcome(_), do: :failed

defp normalize_count(value) when is_integer(value) and value >= 0, do: min(value, 99)
defp normalize_count(_), do: 0
```

### Fail-closed bounded reason atoms
**Source:** `lib/cairnloop/retrieval.ex` lines 28-33 and `lib/cairnloop/knowledge_automation.ex` public API
**Apply to:** All `Cairnloop.Governance` public functions
```elixir
# Never generic {:error, :unknown} or {:error, nil}
# Always a bounded reason atom: {:blocked, :scope_invalid, :missing_account_scope}
```

---

## No Analog Found

All files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `lib/cairnloop/`, `test/cairnloop/`, `priv/repo/migrations/`
**Files scanned:** 12 source files + 1 migration + 1 test file
**Pattern extraction date:** 2026-05-23
