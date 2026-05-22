<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Artifact Distribution**: Exclusively use Igniter Generation to place SLO definitions (`lib/my_app/cairnloop/slos.ex`), Doctor checks (`MyApp.Cairnloop.Doctor`), and Runbooks physically into the host application. Reject the "hidden library macro" approach (e.g. `use Cairnloop.SLOs`).
2. **Runbook Location**: Igniter will generate Markdown runbooks (e.g., `cairnloop_queue_backup.md`) directly into `priv/runbooks/`.
3. **Default SLO Scaffolding**: Scaffold a complete trinity of metrics: Time to First Response (TTFR), Resolution Time, and Cairnloop-scoped System Health (e.g., AI drafting latency or stale handoffs).
</user_constraints>

# Phase M005-S03: Alerting & Runbooks - Research

**Researched:** 2024
**Domain:** Elixir Observability, Parapet Integration, Igniter Code Generation
**Confidence:** HIGH

## Summary

This phase focuses on integrating Cairnloop with the Parapet SRE substrate. We will leverage `Igniter` to explicitly scaffold SLO definitions, Doctor checks, and runbooks directly into the host application rather than hiding them behind opaque macros. This ensures that operators have full visibility into and ownership of the reliability wiring for Cairnloop features within their Phoenix SaaS applications. 

**Primary recommendation:** Use `Igniter.Project.Module.create_module/3` for scaffolding Elixir modules (`SLOs` and `Doctor`) and `Igniter.create_new_file/3` or `Igniter.include_or_create_file/3` for writing Markdown runbooks into the `priv/runbooks/` directory.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SLO Definitions | API / Backend | — | Compiled into Prometheus alerts/rules using Parapet DSL. Belongs in application code (`lib/`). |
| Doctor Diagnostics | API / Backend | — | Scaffolds logic to assert system health (queues, DB, webhooks). Run via Mix task natively in the host environment. |
| Runbooks | Application Data | — | Markdown files deployed as part of the OTP release. Stored in `priv/runbooks/` to keep them alongside the code without polluting `lib/`. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Igniter | ~> 0.3 | Code Generation & Patching | Parapet and Cairnloop rely heavily on Igniter for host-owned artifact injection. |
| Parapet | latest | SRE & Reliability Layer | Defines the DSLs for SLOs (`Parapet.SLO`) and standardizes Doctor checks and deploy markers. |

## Architecture Patterns

### Recommended Project Structure (Scaffolded)
```
my_app/
├── lib/
│   └── my_app/
│       └── cairnloop/
│           ├── slos.ex     # Contains Parapet.SLO.define/2 for TTFR, Resolution Time, Health
│           └── doctor.ex   # Contains Parapet.Doctor definitions
└── priv/
    └── runbooks/
        ├── cairnloop_ttfr_breach.md
        ├── cairnloop_resolution_breach.md
        └── cairnloop_system_health.md
```

### Pattern 1: Scaffolded Runbooks with Igniter
**What:** Writing Markdown runbooks directly to the host application's `priv/runbooks/` folder.
**When to use:** During the Cairnloop Igniter installation task (`install.parapet.ex` or a new specific task).
**Example:**
```elixir
# Source: Igniter documentation
runbook_contents = """
# Cairnloop System Health Breach
## Symptoms
...
## Actions
...
"""

igniter
|> Igniter.create_new_file(
  "priv/runbooks/cairnloop_system_health.md",
  runbook_contents
)
```

### Pattern 2: Explicit Host-Owned Modules
**What:** Generating `MyApp.Cairnloop.SLOs` and `MyApp.Cairnloop.Doctor` directly into the host `lib/` directory using `Igniter.Project.Module.create_module/3`.
**When to use:** To scaffold the initial configuration while allowing the host application developers to easily customize thresholds or escalation rules.
**Example:**
```elixir
app_module = Igniter.Project.Application.app_module(igniter)
slo_module_name = Module.concat([app_module, Cairnloop, SLOs])

slo_contents = """
defmodule #{inspect(slo_module_name)} do
  # Scaffolded Parapet SLOs
  # Parapet.SLO.define(...)
end
"""

Igniter.Project.Module.create_module(igniter, slo_module_name, slo_contents)
```

## Anti-Patterns to Avoid
- **"Hidden" Library Macros:** Do not use `use Cairnloop.SLOs` to define SLOs implicitly. The exact parameters (time windows, burn rates, thresholds) must be transparent and modifiable by the end-user.
- **Putting Runbooks in `lib/`:** Markdown files do not belong in `lib/`. They must go to `priv/runbooks/` where they can be tracked alongside the application and packaged into OTP releases.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Burn-rate Alerting | Custom PromQL queries | `Parapet.SLO.define/2` | Mathematically correct multi-window burn-rate alerts are extremely complex to build manually. |
| Code Patching / File creation | `File.write/2` | `Igniter.create_new_file/3` | Igniter handles idempotency, diffs, and formatting out-of-the-box. |

## Runtime State Inventory

> Omitted as this is a feature addition/scaffolding phase, not a rename/refactor phase.

## Common Pitfalls

### Pitfall 1: Overwriting Customized Runbooks/SLOs
**What goes wrong:** Rerunning the Igniter installation task overwrites user customizations in their SLO definitions or runbooks.
**Why it happens:** Using `File.write!` or a forceful Igniter flag without respecting existing files.
**How to avoid:** Use `Igniter.create_new_file/3` with its default behavior or `:skip` on exists, or `Igniter.include_or_create_file/3` which is inherently safe for new file generation.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Opaque Macros | Host-owned Code via Igniter | Recent Parapet & Ash Conventions | Adopters can see, version, and tweak their SLOs natively in their repo. |

## Sources

### Primary (HIGH confidence)
- `prompts/parapet overview for integration ideas.txt` - Context for Parapet DSL and design philosophy.
- Context7 Igniter Hexdocs (`/websites/hexdocs_pm_igniter`) - Verifying the `Igniter.create_new_file` and `Igniter.Project.Module.create_module` APIs.

## Metadata
**Confidence breakdown:**
- Standard stack: HIGH - Aligning exactly with Parapet and Igniter's current paradigms.
- Architecture: HIGH - Fully compliant with the defined context and constraints.
- Pitfalls: HIGH - Well-known properties of code generators and idempotency.