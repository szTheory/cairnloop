# Phase 3: Alerting & Runbooks - Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/cairnloop/install.slos.ex` (or similar) | generator | file-I/O | `lib/mix/tasks/cairnloop/install.parapet.ex` | exact |
| `lib/my_app/cairnloop/slos.ex` | config | configuration | `MyApp.CairnloopInstrumenter` (generated) | role-match |
| `lib/my_app/cairnloop/doctor.ex` | config | diagnostic | `MyApp.CairnloopInstrumenter` (generated) | role-match |
| `priv/runbooks/cairnloop_queue_backup.md` | documentation | static text | `lib/mix/tasks/cairnloop/install.parapet.ex` (via Igniter) | partial |

## Pattern Assignments

### `lib/mix/tasks/cairnloop/install.slos.ex` (generator, file-I/O)

**Analog:** `lib/mix/tasks/cairnloop/install.parapet.ex`

**Generator Task Pattern** (lines 1-13):
```elixir
defmodule Mix.Tasks.Cairnloop.Install.Parapet do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :cairnloop,
      schema: [],
      defaults: []
    }
  end
```

**Module Scaffolding Pattern** (lines 15-21, 51-52):
```elixir
  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_module = Igniter.Project.Application.app_module(igniter)
    module_name = Module.concat(app_module, CairnloopInstrumenter)

    contents = """
    # ... module contents ...
    """
    
    Igniter.Project.Module.create_module(igniter, module_name, contents)
  end
```

---

### `lib/my_app/cairnloop/slos.ex` & `lib/my_app/cairnloop/doctor.ex` (config, configuration/diagnostic)

**Analog:** `lib/mix/tasks/cairnloop/install.parapet.ex` (generated content pattern)

**Generated Content Pattern** (lines 22-50):
```elixir
    contents = """
    import Telemetry.Metrics

    @doc "Returns the telemetry metrics definitions for Cairnloop SLIs."
    def metrics do
      [
        # Resolution Time SLI
        summary("cairnloop.support_resolution_time",
          event_name: [:cairnloop, :conversation, :resolve, :stop],
          measurement: fn _measurements, metadata ->
            Map.get(metadata, :business_duration_seconds, 0)
          end,
          description: "Time taken to resolve a support conversation",
          tags: [:status]
        )
      ]
    end
    """
```

---

### `priv/runbooks/cairnloop_queue_backup.md` (documentation, static text)

**Analog:** N/A (Standard Igniter core API pattern)

**Pattern to Apply** (Igniter File Creation):
No exact analog in codebase for generating `.md` files, so we default to the Igniter primitive `Igniter.create_or_update_file`:
```elixir
  def igniter(igniter) do
    contents = """
    # Cairnloop Queue Backup Runbook
    
    ## Symptoms
    - Queue backup SLI triggered
    
    ## Diagnosis
    Run `mix parapet.doctor`
    """
    
    Igniter.create_or_update_file(
      igniter,
      "priv/runbooks/cairnloop_queue_backup.md",
      contents,
      fn _existing -> contents end
    )
  end
```

## Shared Patterns

### Igniter Generation (Artifact Distribution)
**Source:** `lib/mix/tasks/cairnloop/install.parapet.ex`
**Apply to:** All generated files (SLOs, Doctor, Runbooks).
We do not use `use Cairnloop.SLOs` (hidden macros), we exclusively use Igniter to place physical `.ex` and `.md` files into the host application.

### Telemetry Scaffolding
**Source:** `lib/mix/tasks/cairnloop/install.parapet.ex`
**Apply to:** SLO definition file (TTFR, Resolution Time, Cairnloop System Health). Ensure we use standard Telemetry maps/aggregations.

## Metadata

**Analog search scope:** `lib/mix/tasks/cairnloop/*.ex`
**Files scanned:** 5
**Pattern extraction date:** 2026-05-12
