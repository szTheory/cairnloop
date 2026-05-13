---
phase: M005-S02
plan: 01
subsystem: mix_tasks
tags: [telemetry, sli, parapet, igniter]
requires: []
provides: [Mix.Tasks.Cairnloop.Install.Parapet]
affects: [Telemetry.Metrics]
tech-stack:
  added: []
  patterns: [Igniter.Project.Module.create_module/4]
key-files:
  created:
    - lib/mix/tasks/cairnloop/install.parapet.ex
    - test/cairnloop/tasks/install.parapet_test.exs
  modified: []
key-decisions:
  - "Use Igniter to scaffold the `CairnloopInstrumenter` file into the host app to ensure the metrics configuration remains explicit and host-owned, avoiding macros or hidden logic."
  - "Extract resolution time and CSAT scores using an anonymous function for the `measurement` option so it correctly targets the metadata map emitted by `Cairnloop.Telemetry`."
metrics:
  duration: 5m
  tasks-completed: 2
  files-created-or-modified: 2
---

# Phase M005-S02 Plan 01: Scaffold Parapet Telemetry Instrumenter Summary

**One-liner:** Implemented the `mix cairnloop.install.parapet` Igniter task to scaffold explicit, cardinality-safe SLI metric definitions into the host application.

## Overview
This plan created a new Mix task `cairnloop.install.parapet` which scaffolds a `HostApp.CairnloopInstrumenter` module in the adopter's Elixir project. This generated module translates Cairnloop's raw telemetry events into explicit `Telemetry.Metrics` definitions for Time to Resolution, Reply Time, and CSAT scores. Following Parapet's core tenets, the integration is host-owned and transparent, explicitly excluding high-cardinality fields like `conversation_id` and extracting metric values correctly from telemetry metadata.

## Execution Details

### Task 0: Create test scaffold for Parapet installer
- **Commit:** 7cca232
- **Action:** Created `Mix.Tasks.Cairnloop.Install.ParapetTest` using `Igniter.Test` to verify the generated code structure. Included assertions for correct metric types (`summary`), required metric paths, high-cardinality tag exclusions, and correct metadata extraction functions.

### Task 1: Implement Parapet Installer Mix Task
- **Commit:** 43e3deb
- **Action:** Implemented the `Mix.Tasks.Cairnloop.Install.Parapet` task. Used `Igniter.Project.Module.create_module/4` to write an explicit `Telemetry.Metrics` block, capturing the requested resolution, reply, and CSAT summaries in a fully transparent format.

## Threat Flags
None found. Code generation behaves strictly as specified and only emits static AST.

## Deviations from Plan
- None - plan executed exactly as written.

## Self-Check: PASSED
- `lib/mix/tasks/cairnloop/install.parapet.ex` found
- `test/cairnloop/tasks/install.parapet_test.exs` found
