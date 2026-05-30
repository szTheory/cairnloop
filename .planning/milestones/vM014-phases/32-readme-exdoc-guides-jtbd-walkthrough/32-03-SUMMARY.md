---
phase: 32-readme-exdoc-guides-jtbd-walkthrough
plan: "03"
subsystem: documentation
tags: [readme, changelog, igniter, exdoc, vM014]
dependency_graph:
  requires: []
  provides: [restructured-README, vM014-changelog-entry]
  affects: [README.md, CHANGELOG.md]
tech_stack:
  added: []
  patterns: [Keep-a-Changelog, Igniter-first front door]
key_files:
  created: []
  modified:
    - README.md
    - CHANGELOG.md
decisions:
  - "README restructured: installer leads Installation (mix cairnloop.install first), Mermaid/hedge/telemetry removed"
  - "CHANGELOG [Unreleased] populated with 7-bullet vM014 entry in Phase 27-32 order"
metrics:
  duration: "1m 51s"
  completed: "2026-05-29T01:10:42Z"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 32 Plan 03: README + CHANGELOG Summary

README restructured as an Igniter-first front door (`mix cairnloop.install` leads Installation) with four HexDocs guide links and CHANGELOG populated with the 7-bullet vM014 entry under the existing `[Unreleased]` header.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Restructure README.md (Igniter-first front door) | 5eba0c7 | README.md |
| 2 | Populate the [Unreleased] CHANGELOG entry | 6665275 | CHANGELOG.md |

## What Was Built

### Task 1: README.md restructured (DOC-01)

The README was fully rewritten following the D-03 section order from the context decisions:

1. **Title + badges** — kept verbatim (all three shields.io badges)
2. **One-line tagline** — tightened to "An embedded, Phoenix-native customer support automation layer for Elixir applications."
3. **Installation** — leads with the two-step Igniter installer (`mix deps.get` then `mix cairnloop.install`), with a `### Manual install (without Igniter)` subsection below carrying the bare deps block
4. **Why Cairnloop?** — 5 crisp bullets (host-owned, safe automation, KB substrate, additive, observable)
5. **What it does** — 4-sentence prose paragraph, no Mermaid diagram
6. **Explore the guides** — all four HexDocs links (01-quickstart, 02-jtbd-walkthrough, 03-host-integration, 04-troubleshooting)
7. **Contributing + License** — at the bottom

Removed: Mermaid diagram, "If [available in Hex]" hedge, "Documentation can be generated with ExDoc" boilerplate, inline telemetry + Notifier code sections (that content now lives in `guides/03-host-integration.md`).

### Task 2: CHANGELOG.md vM014 entry (DOC-04)

Populated the existing empty `## [Unreleased]` section (no second header added) with a `### Added` subsection containing all 7 verbatim vM014 bullets in Phase 27→32 order. The `## [0.1.0] - 2026-05-25` block was not modified.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

All acceptance criteria satisfied:

- `mix cairnloop.install` present in README, appears before `def deps do` (line 16 vs line 27)
- Version pin `~> 0.1.0` present
- All four `hexdocs.pm/cairnloop/0N-*.html` guide links present
- "available in Hex" hedge: absent
- Mermaid diagram: absent
- `cairnloop-apm-tracker` inline telemetry: absent
- All three existing badges present (hexpm, hexdocs, CI)
- Exactly one `## [Unreleased]` header in CHANGELOG
- All 7 vM014 bullets present (Phases 27–32, EditorHandoff, golden_path_test.exs, README rewritten)
- `## [0.1.0] - 2026-05-25` block unchanged

## Known Stubs

None. Both files are complete and do not contain placeholder text or broken links (guide links will resolve once plans 32-01, 32-02 ship and plan 32-04 wires mix.exs).

## Threat Flags

None. Documentation-only plan with no executable attack surface. No real secrets/tokens appear in code examples — all installer snippets use `~> 0.1.0` version pin only.

## Self-Check: PASSED

Files exist:
- README.md: FOUND
- CHANGELOG.md: FOUND
- 32-03-SUMMARY.md: FOUND (this file)

Commits exist:
- 5eba0c7 (Task 1 — README restructure): FOUND
- 6665275 (Task 2 — CHANGELOG entry): FOUND
