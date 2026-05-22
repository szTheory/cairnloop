<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Architecture: Scaffold via Igniter (Host-Owned Instrumenter)**
- **Decision:** We will provide an Igniter task (`mix cairnloop.install.parapet`) to scaffold a `HostApp.CairnloopInstrumenter` into the host application.
- **Rationale:** Aligns with Parapet's "Host-Owned Over Magical Black-Boxes" core tenet. Adopters get a visible, auditable, and easily customizable mapping of telemetry to metrics without hidden DSLs or black-box modules.
- **Reference:** Confirmed in `.gsd/DECISIONS.md`.

### the agent's Discretion
None explicitly stated in CONTEXT.md.

### Deferred Ideas (OUT OF SCOPE)
None explicitly stated in CONTEXT.md.
</user_constraints>

# Phase M005-S02: SRE Observability (SLIs) - Research

**Researched:** 2024
**Domain:** Elixir Telemetry, Parapet (SRE SRO tool), Code Generation (Igniter)
**Confidence:** HIGH

## Summary

The goal of this phase is to expose Cairnloop's internal operational metrics (Time to Resolution, Reply Time, CSAT) as quantitative SLIs (Service Level Indicators) for the host application's SRE substrate (Parapet). Adhering to Parapet’s “Host-Owned Over Magical Black-Boxes” principle, we will avoid hidden macros or automatic runtime injection. 

Instead, we will build an Igniter mix task (`mix cairnloop.install.parapet`) that physically generates a `HostApp.CairnloopInstrumenter` module into the adopter's codebase. This explicitly maps telemetry events to `Telemetry.Metrics` definitions, allowing operators to see the exact label configurations and prevent cardinality explosions.

**Primary recommendation:** Use `Igniter.Project.Module.create_module/4` to scaffold a file (e.g., `lib/host_app/cairnloop_instrumenter.ex`) that relies strictly on standard `:telemetry_metrics` definitions (which Parapet natively consumes).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Telemetry Emission | API / Backend (Library) | — | `Cairnloop.Telemetry` handles raw emission of library events with flat metadata, unaware of external SRE systems. |
| Metrics Definition | API / Backend (Host App) | — | SRE tooling and metrics routing belong to the host application (operator), not the library. |
| Code Scaffolding | Mix Task (Igniter) | — | Igniter task executes once at dev-time to bridge the library and the host app. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Igniter | ~> 0.5 | Code Scaffolding | Standard ecosystem tool for AST-aware code generation. Idempotent and safe. |
| Telemetry.Metrics | ~> 1.0 | Metrics DSL | The Elixir standard for converting raw telemetry events into SRE-ready metrics. Parapet consumes this. |

**Installation:**
```bash
# These are already in the stack or the host app's stack.
mix deps.get
```

## Architecture Patterns

### Recommended Project Structure
```text
lib/mix/tasks/cairnloop/install.parapet.ex # The generator task in the library
lib/host_app/cairnloop_instrumenter.ex     # The target output in the user's project
```

### Pattern 1: Igniter Module Scaffolding
**What:** Generating a module in the host application containing the standard metrics definitions.
**When to use:** When providing default SRE wiring that the host application must own and potentially customize.
**Example:**
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

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_module = Igniter.Project.Application.app_module(igniter)
    module_name = Module.concat(app_module, CairnloopInstrumenter)

    # Scaffolds standard Telemetry.Metrics definitions
    contents = """
      import Telemetry.Metrics

      @doc "Returns the telemetry metrics definitions for Cairnloop SLIs."
      def metrics do
        [
          # Resolution Time SLI
          summary("cairnloop.support_resolution_time",
            event_name: [:cairnloop, :conversation, :resolve, :stop],
            # Extract measurement from metadata (based on Cairnloop.Telemetry docs)
            measurement: fn _measurements, metadata -> 
              Map.get(metadata, :business_duration_seconds, 0)
            end,
            description: "Time taken to resolve a support conversation",
            tags: [:status] 
          ),
          
          # Reply Time SLI
          summary("cairnloop.support_reply_time",
            event_name: [:cairnloop, :conversation, :reply, :stop],
            measurement: :duration,
            description: "Time taken to reply to a support conversation",
            tags: [:role]
          ),
          
          # CSAT Score SLI
          summary("cairnloop.support_csat_score",
            event_name: [:cairnloop, :feedback, :csat, :stop],
            # Extract measurement from metadata
            measurement: fn _measurements, metadata -> 
              Map.get(metadata, :rating, 0)
            end,
            description: "Customer Satisfaction score",
            tags: []
          )
        ]
      end
    """

    Igniter.Project.Module.create_module(igniter, module_name, contents)
  end
end
```

### Anti-Patterns to Avoid
- **Hiding Telemetry Definitions in Macros:** Do not create a `use Cairnloop.Parapet` macro to dynamically inject metrics at runtime. Parapet philosophy explicitly rejects this because it obfuscates the label schema from operators who need to tune it for cardinality safety.
- **High-Cardinality Tags in Metrics:** Never inject fields like `conversation_id`, `user_id`, or `message_id` into the `tags:` list of `summary()`. This will cause memory exhaustion in Prometheus (Parapet's underlying store). These fields belong in structured evidence/logs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File Creation | `File.write/2` | `Igniter.Project.Module.create_module/4` | Igniter handles AST-aware formatting, idempotency, and correct directory placement automatically. |

## Common Pitfalls

### Pitfall 1: Metadata vs. Measurements Extraction
**What goes wrong:** Setting `measurement: :business_duration_seconds` directly.
**Why it happens:** In `telemetry_metrics`, passing an atom to `measurement` extracts that key from the `measurements` map, NOT the `metadata` map. However, `Cairnloop.Telemetry` explicitly documents `:business_duration_seconds` and `:rating` as living in the *metadata*. 
**How to avoid:** You must use an anonymous function for the `measurement` option to pull values out of the metadata map when defining the `summary`:
`measurement: fn _measurements, metadata -> Map.get(metadata, :business_duration_seconds) end`

### Pitfall 2: Bypassing the App Module Prefix
**What goes wrong:** Generating `CairnloopInstrumenter` at the top level namespace.
**Why it happens:** Hardcoding the module name.
**How to avoid:** Always prepend the host app's base module using `Igniter.Project.Application.app_module(igniter)`.

## Code Examples

Verified patterns from official sources:

### Extracting Metadata for Metrics
```elixir
# Source: HexDocs for Telemetry.Metrics
summary("db.query.duration",
  event_name: [:my_app, :repo, :query],
  measurement: fn _measurements, metadata -> 
    metadata.query_time + metadata.queue_time 
  end
)
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-01 | Generates `HostApp.CairnloopInstrumenter` file | unit | `mix test test/cairnloop/tasks/install.parapet_test.exs` | ❌ Wave 0 |
| REQ-02 | Verifies generated module contains valid metrics definitions | integration | `mix test test/cairnloop/tasks/install.parapet_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/cairnloop/tasks/install.parapet_test.exs` — Covers module generation logic
- [ ] Helpers in `test_helper.exs` to simulate Igniter runs if not natively supported by Igniter testing utilities (though Igniter provides `Igniter.Test`).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Strict limits on generated file output. |
| V6 Cryptography | no | — |

### Known Threat Patterns for Elixir/Telemetry

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cardinality Explosion (DoS) | Denial of Service | Exclude user/conversation IDs from `tags:` list in generated metrics. |

## Sources

### Primary (HIGH confidence)
- Cairnloop Project Guidance (`GEMINI.md`) - SRE core tenets (Parapet)
- `prompts/elixir-lib-customer-support-automation-deep-research.md` - Context for metric constraints and cardinality safety.
- `lib/cairnloop/telemetry.ex` - Verified metadata fields for events.
- `Igniter` module source - AST-aware code generation patterns.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified via project dependencies and existing igniter tasks.
- Architecture: HIGH - Fully aligned with Parapet design principles from `prompts/`.
- Pitfalls: HIGH - Elixir telemetry_metrics API strictly requires function extraction for metadata.

**Research date:** 2024
**Valid until:** 30 days
