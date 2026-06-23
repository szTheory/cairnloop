# vM016 — PARKED (not shipped)

**Status at park:** `executing`, **54% complete** — 7/13 phases done, 28/32 plans done.
**Parked:** 2026-06-23, to start **vM017 Brand Identity System, Token Evolution & HTML Brand Book** first.
**Parked by owner decision** (sequencing call: "Park vM016, start vM017 now").

> vM016 is **paused mid-flight, not completed**. Do NOT treat it as a shipped milestone or run
> `/gsd-complete-milestone` against it. Its phase directories are archived here for safekeeping and
> resume — not because the milestone finished.

## Why parked (and the load-bearing dependency)

vM017 **reopens and evolves the core palette + type** (decision D-A) and produces the real logo system.
vM016's **Phase 45 = seed enrichment + light/dark screenshot regen + verification sweep**. Regenerating
screenshots against the *current* brand and then evolving the brand in vM017 would waste the regen work.
**Therefore the brand evolution (vM017) must land before vM016's screenshot regen.** Parking vM016 here
and doing vM017 first sequences this correctly.

## Position at park

- **Phase 44 — Motion:** PLANNED & READY TO EXECUTE. 4 plans / 3 waves authored (`44-01..04-PLAN.md`),
  not started. UI-SPEC + RESEARCH + PATTERNS + VALIDATION present. CSS-only; transform+opacity;
  `prefers-reduced-motion` honored live; gated Playwright E2E (never human-verify).
- **Phase 45 — Seed enrichment + screenshot regen + verification sweep:** NOT YET PLANNED (no dir).
  **Must consume vM017's final brand** (evolved palette/type + chosen logo) when it runs.
- Completed phases 37–43 (component primitives → shell → Home/D1 → drift+gate → rail/D2 → threading →
  responsive/D3) are done and were shipping via release-please across the milestone.

## Where vM016 artifacts live (archived)

- Phase dirs: `.planning/milestones/vM016-phases/37-…` through `44-motion`.
- Roadmap snapshot: `.planning/milestones/vM016-ROADMAP.md` (9 phases 37–45, 29 v1 reqs).
- Requirements snapshot: `.planning/milestones/vM016-REQUIREMENTS.md`.
- vM016 ratified decisions (D1/D2/D3, gate hardening, motion, E2E-not-human-verify) remain in
  `.planning/STATE.md` "Accumulated Context → Decisions" (preserved across the milestone switch) and in
  `PROJECT.md`.

## How to resume vM016 (after vM017 ships)

1. Ensure `.planning/phases/` holds only the active milestone's dirs (archive vM017's the same way if needed).
2. Move vM016 phase dirs back:
   `for d in .planning/milestones/vM016-phases/*/; do git mv "$d" .planning/phases/; done`
3. Restore roadmap/requirements:
   `git mv .planning/milestones/vM016-ROADMAP.md .planning/ROADMAP.md` and
   `git mv .planning/milestones/vM016-REQUIREMENTS.md .planning/REQUIREMENTS.md` (or re-snapshot vM017's first).
4. Switch the active milestone back:
   `node "$HOME/.claude/gsd-core/bin/gsd-tools.cjs" query state.milestone-switch --milestone vM016 --name "Operator UI/UX Iteration"`
   then hand-set Current Position to **Phase 44, Ready to execute** and progress to 7/13 phases · 28/32 plans.
5. Continue: `/gsd-execute-phase 44` (motion is planned), then `/gsd-plan-phase 45` (regen screenshots
   against the **final vM017 brand**), then close the milestone.
6. Delete this PARKED marker once vM016 is active again.
