---
phase: 32-readme-exdoc-guides-jtbd-walkthrough
plan: "04"
subsystem: documentation
tags: [docs, exdoc, mix.exs, hex-package, guides, distribution]
dependency_graph:
  requires: [32-01, 32-02, 32-03]
  provides: [mix.exs-guides-wiring, hex-tarball-includes-guides]
  affects:
    - mix.exs
    - README.md
    - HexDocs published guides navigation
    - Hex tarball package contents
tech_stack:
  added: []
  patterns:
    - ExDoc extras + groups_for_extras (Guides sidebar group)
    - Hex package :files explicit list (guides directory)
    - Igniter-first README LICENSE link pattern
key_files:
  created: []
  modified:
    - mix.exs
    - README.md
decisions:
  - "Used LICENSE (no extension) in package: files: ~w(...) — verified on-disk casing before edit"
  - "Used title: tuple form for extras entries — gives clean sidebar labels without relying on H1 derivation"
  - "README LICENSE link changed to absolute GitHub URL — avoids ExDoc relative-link resolution against docs output dir"
  - "# assets: 'guides/assets' kept commented (D-02) — mix docs would raise on a missing assets dir"
metrics:
  duration_minutes: 15
  completed_date: "2026-05-29"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 2
---

# Phase 32 Plan 04: mix.exs ExDoc + Hex Tarball Wiring Summary

mix.exs extended to ship all four guides in the Hex tarball and surface them in ExDoc navigation under a "Guides" sidebar group — DOC-03 proven locally with `mix docs` (four HTML pages generated) and `mix hex.build` (all four guide files + LICENSE listed in the included files).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add guides to docs: extras + groups_for_extras + commented :assets + package: :files | 80f46c8 | mix.exs |
| 2 | Verify mix docs renders + mix hex.build ships guides + LICENSE | d0b30f7 | README.md (LICENSE link fix) |

## What Was Built

### Task 1: mix.exs extended (commit 80f46c8)

The `docs:` block was extended (not replaced):
- `extras` replaced with a guides-first list using `{"path", title: "..."}` tuple form for clean sidebar labels:
  - `{"guides/01-quickstart.md", title: "Quickstart"}`
  - `{"guides/02-jtbd-walkthrough.md", title: "JTBD Walkthrough"}`
  - `{"guides/03-host-integration.md", title: "Host Integration"}`
  - `{"guides/04-troubleshooting.md", title: "Troubleshooting"}`
  - `"README.md"` and `"CHANGELOG.md"` (unchanged, appended after guides)
- `groups_for_extras: ["Guides": ~r/^guides\//]` added to create the sidebar group
- `# assets: "guides/assets"  # uncomment once PNG screenshots are captured` added commented (D-02)
- `main: "readme"` and all 6 `groups_for_modules` groups preserved byte-for-byte

The `package:` block gained a `:files` key:
- `files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md)`
- `LICENSE` with NO extension (on-disk file verified as `LICENSE` — `LICENSE.md` would silently drop it)
- Existing keys (`name`, `licenses`, `links`, `maintainers`) preserved

### Task 2: Verification + README LICENSE fix (commit d0b30f7)

**`mix compile --warnings-as-errors`:** Clean exit (no warnings).

**`mix docs` output:**
- Exits 0
- No "File not found" / missing-extra / missing-assets errors
- Four guide HTML pages generated under `doc/`:
  - `doc/01-quickstart.html`
  - `doc/02-jtbd-walkthrough.html`
  - `doc/03-host-integration.html`
  - `doc/04-troubleshooting.html`
- Pre-existing non-blocking warnings (unrelated to this plan): `Cairnloop.Tool.Spec.t()` type reference, `Cairnloop.Application.start/2` hidden function — these were present before this plan and are out of scope per deviation scope boundary rules.

**`mix hex.build` included files (guides excerpt):**
```
    guides/01-quickstart.md
    guides/02-jtbd-walkthrough.md
    guides/03-host-integration.md
    guides/04-troubleshooting.md
    ...
    LICENSE
    README.md
    CHANGELOG.md
```
All four guides and `LICENSE` (no extension) confirmed in the tarball.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed broken LICENSE.md reference in README.md**
- **Found during:** Task 2 — `mix docs` emitted `warning: documentation references file "LICENSE.md" but it does not exist` (then `LICENSE` after first fix attempt)
- **Issue:** The README restructure in plan 32-03 introduced `[LICENSE.md](LICENSE.md)` as the license link, but the on-disk file is `LICENSE` with no extension. ExDoc resolves the link relative to the docs output dir, so even `[LICENSE](LICENSE)` caused a warning (no `LICENSE` HTML page exists in `doc/`).
- **Fix:** Changed the link to an absolute GitHub URL: `[LICENSE](https://github.com/szTheory/cairnloop/blob/main/LICENSE)`. Absolute URLs bypass ExDoc's relative-link resolution and remain valid regardless of file naming.
- **Files modified:** `README.md` (1-line change)
- **Commit:** d0b30f7

## Verification Results

All plan acceptance criteria satisfied:

- [x] `grep -q "guides/01-quickstart.md" mix.exs` — PASS
- [x] `grep -q "groups_for_extras" mix.exs` — PASS
- [x] `grep -Eq "files:\s*~w\(.*\bguides\b.*\)" mix.exs` — PASS
- [x] `grep -Eq "files:\s*~w\(.*\bLICENSE\b.*\)" mix.exs` — PASS
- [x] `! grep -Eq "files:\s*~w\(.*LICENSE\.md.*\)" mix.exs` — PASS (LICENSE.md NOT present)
- [x] `grep -Eq "^\s*#\s*assets:\s*\"guides/assets\"" mix.exs` — PASS (commented, not active)
- [x] `grep -q 'main: "readme"' mix.exs` — PASS
- [x] `grep -q "groups_for_modules" mix.exs` — PASS (all 6 groups preserved)
- [x] `mix compile --warnings-as-errors` exits 0 — PASS
- [x] `mix docs` exits 0, no LICENSE/missing-file errors, four guide HTML pages exist — PASS
- [x] `mix hex.build` lists all four `guides/0N-*.md` files — PASS
- [x] `mix hex.build` lists `LICENSE` (no extension) — PASS

## Known Stubs

None. The `# assets: "guides/assets"` line is an intentional, scoped comment (D-02) — not a stub. The guides are complete and immediately useful.

## Threat Flags

Per the plan threat register, T-32-05 (Information Disclosure — package :files list) is mitigated: the `:files` list includes only intended public artifacts (`lib`, `priv`, `guides`, `mix.exs`, `README.md`, `LICENSE`, `CHANGELOG.md`) and explicitly excludes test artifacts, credentials, and secrets.

No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

Files modified:
- mix.exs: FOUND
- README.md: FOUND

Commits exist:
- 80f46c8 (Task 1 — mix.exs wiring): FOUND
- d0b30f7 (Task 2 — README LICENSE fix): FOUND

Phase 32 DOC-03 requirement satisfied: guides ship in the Hex tarball and surface in ExDoc navigation.
