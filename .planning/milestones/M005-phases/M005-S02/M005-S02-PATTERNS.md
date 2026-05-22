# Phase M005-S02: SRE Observability (SLIs) - Pattern Map

**Mapped:** 2024
**Files analyzed:** 2
**Analogs found:** 1 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/cairnloop/install.parapet.ex` | mix task | code scaffolding | `lib/mix/tasks/cairnloop/install.ex` | exact |
| `test/cairnloop/tasks/install.parapet_test.exs` | test | N/A | None | no-match |

## Pattern Assignments

### `lib/mix/tasks/cairnloop/install.parapet.ex` (mix task, code scaffolding)

**Analog:** `lib/mix/tasks/cairnloop/install.ex`

**Imports pattern** (lines 1-2):
```elixir
defmodule Mix.Tasks.Cairnloop.Install do
  use Igniter.Mix.Task
```

**Core Mix Task Pattern** (lines 4-11):
```elixir
  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :cairnloop,
      schema: [],
      defaults: []
    }
  end
```

**Igniter Code Generation Pattern** (lines 13-15):
```elixir
  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
```
*(Note: Replace the Ecto migration generation in the analog with `Igniter.Project.Module.create_module/4` as specified in RESEARCH.md for creating the `CairnloopInstrumenter` module.)*

---

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/cairnloop/tasks/install.parapet_test.exs` | test | N/A | No existing tests for Mix tasks found in the codebase. |

## Shared Patterns

No cross-cutting shared patterns identified beyond the standard `Igniter.Mix.Task` behavior.

## Metadata

**Analog search scope:** `lib/mix/tasks/**/*.ex`, `test/**/*_test.exs`
**Files scanned:** 16
**Pattern extraction date:** 2024
