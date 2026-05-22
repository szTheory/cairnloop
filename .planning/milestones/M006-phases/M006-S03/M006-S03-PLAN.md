---
phase: M006-S03
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/cairnloop/sla_policy_provider.ex
  - lib/cairnloop/default_sla_policy_provider.ex
  - lib/mix/tasks/cairnloop/install.sla_policies.ex
  - lib/cairnloop/router.ex
  - lib/cairnloop/web/settings_live.ex
autonomous: true
requirements:
  - M006-REQ-06
must_haves:
  truths:
    - "Operator can view active SLA policies in the UI"
    - "Operator can configure and update SLA policy settings"
    - "Settings are durably stored in the host application"
  artifacts:
    - path: "lib/cairnloop/sla_policy_provider.ex"
      provides: "Behaviour contract for SLA policies"
    - path: "lib/mix/tasks/cairnloop/install.sla_policies.ex"
      provides: "Igniter scaffold for host app"
    - path: "lib/cairnloop/web/settings_live.ex"
      provides: "Dashboard settings UI"
  key_links:
    - from: "lib/cairnloop/router.ex"
      to: "lib/cairnloop/web/settings_live.ex"
      via: "cairnloop_dashboard/2 macro"
      pattern: "live\\(\"/settings\""
    - from: "lib/cairnloop/web/settings_live.ex"
      to: "lib/cairnloop/sla_policy_provider.ex"
      via: "dynamic resolution"
      pattern: "Application\\.get_env\\(:cairnloop, :sla_policy_provider"
---

<objective>
Implement a host-owned, immutable SLA policy configuration system and LiveView UI for the Cairnloop dashboard.

Purpose: Allow operators to define SLA thresholds (First Response, Resolution) per priority without burying configuration inside Cairnloop's private tables, ensuring SRE auditability.
Output: A new Settings LiveView, a provider behaviour, and an Igniter task to scaffold the SLA schema in the host application.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/milestones/M006-ROADMAP.md
@.planning/milestones/M006-phases/M006-S03-CONTEXT.md
@.planning/milestones/M006-phases/M006-S03/M006-S03-RESEARCH.md
@.planning/milestones/M006-phases/M006-S03/M006-S03-PATTERNS.md
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Define SLA Policy Provider Behaviour</name>
  <files>lib/cairnloop/sla_policy_provider.ex, lib/cairnloop/default_sla_policy_provider.ex, test/cairnloop/default_sla_policy_provider_test.exs</files>
  <behavior>
    - Test 1: `DefaultSLAPolicyProvider.get_active_policies()` returns mock SLA defaults with priorities
    - Test 2: `DefaultSLAPolicyProvider.set_policy(priority, attrs)` returns a descriptive error as defaults are read-only
  </behavior>
  <action>Create `Cairnloop.SLAPolicyProvider` with `@callback get_active_policies() :: {:ok, list(map())} | {:error, term()}` and `@callback set_policy(priority :: atom(), attrs :: map()) :: {:ok, map()} | {:error, term()}`.
Create `Cairnloop.DefaultSLAPolicyProvider` implementing this behaviour as a fallback. Implement `get_active_policies` to return static defaults (e.g. `%{priority: :normal, target_first_response_minutes: 60, target_resolution_minutes: 1440}`).</action>
  <verify>
    <automated>mix test test/cairnloop/default_sla_policy_provider_test.exs</automated>
  </verify>
  <done>Behaviour defined and default provider passes tests.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create Igniter Task for Scaffolding</name>
  <files>lib/mix/tasks/cairnloop/install.sla_policies.ex, test/cairnloop/tasks/install.sla_policies_test.exs</files>
  <behavior>
    - Test 1: Igniter task sets up `Application.put_env` configuring `sla_policy_provider`.
    - Test 2: Igniter task generates a migration for `cairnloop_sla_policies` containing SLA metrics and priority.
  </behavior>
  <action>Create `Mix.Tasks.Cairnloop.Install.SlaPolicies` using `Igniter.Mix.Task`. 
Following patterns from `M006-S03-PATTERNS.md`, use `Igniter.Libs.Ecto.select_repo()` to find the host's repo.
Generate an Ecto Schema module for the host app (e.g., `MyApp.SLA.Policy`) that defines `priority` as an `Ecto.Enum` mapping to `[:low, :normal, :high, :urgent]`, along with the `target_first_response_minutes` and `target_resolution_minutes` integer fields.
Use `Igniter.Libs.Ecto.gen_migration()` to create a table `cairnloop_sla_policies`. 
Migration body must have:
- `priority` string column (with `null: false`)
- `target_first_response_minutes` integer column
- `target_resolution_minutes` integer column
- `timestamps(updated_at: false)` (insert-only for auditability)
- `create index(:cairnloop_sla_policies, [:priority, :inserted_at])`
Use `Igniter.Project.Config.configure` to set the `:sla_policy_provider` to the generated host provider module.</action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>Igniter recipe scaffolds correctly and compiles.</done>
</task>

<task type="auto">
  <name>Task 3: Build SettingsLive UI & Update Router</name>
  <files>lib/cairnloop/router.ex, lib/cairnloop/web/settings_live.ex, test/cairnloop/web/settings_live_test.exs</files>
  <action>Update `lib/cairnloop/router.ex` to inject `live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)` into the `cairnloop_dashboard/2` macro. CRITICAL: Place it BEFORE `live("/:id", ...)` to avoid route swallowing.
Create `Cairnloop.Web.SettingsLive`. 
In `mount/3`, dynamically resolve the provider: `provider = Application.get_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)` and load active policies. 
Create an insert-only settings form (modifying the SLA policy inserts a new row via `provider.set_policy/2` rather than updating). 
Priorities must be restricted to a static list `[:low, :normal, :high, :urgent]`.</action>
  <verify>
    <automated>mix compile</automated>
  </verify>
  <done>Router updated correctly, `/settings` LiveView successfully compiles and is reachable.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Operator to Settings UI | Operators submitting new SLA configurations |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M006-S03-01 | Spoofing | Router Macro | mitigate | Place `/settings` route before `/:id` route in macro to prevent URL spoofing capturing the `/settings` path as an ID |
| T-M006-S03-02 | Tampering | SettingsLive Form | mitigate | Enforce priority enum constraint (`[:low, :normal, :high, :urgent]`) and validate integer ranges for thresholds before passing to provider |
| T-M006-S03-03 | Repudiation | Database Storage | mitigate | Enforce append-only updates. `set_policy` inserts new rows instead of `UPDATE` to maintain SLA audit history. |
</threat_model>

<verification>
- `mix test` runs successfully.
- Code compiles correctly (`mix compile`).
- Router properly isolates `/settings` from the `/:id` LiveView.
</verification>

<success_criteria>
- The behaviour contract allows host integration for SLA configuration.
- The LiveView dashboard successfully handles SLA config updates.
- Igniter recipe successfully installs the schema pattern without errors.
</success_criteria>

<output>
After completion, create `.planning/milestones/M006-phases/M006-S03/M006-S03-SUMMARY.md`
</output>
