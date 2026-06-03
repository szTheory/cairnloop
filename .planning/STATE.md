---
gsd_state_version: 1.0
milestone: vM016
milestone_name: Operator UI/UX Iteration
status: planning
last_updated: "2026-06-03T22:21:53.618Z"
last_activity: 2026-06-03 — Roadmap created (phases 37–45, 29 requirements mapped)
progress:
  total_phases: 13
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-06-03 — vM016 active)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** **vM016 Operator UI/UX Iteration** (phases 37–45) — owner-pulled iteration/polish on the already-shipped operator dashboard: componentization dividends, drift remediation + gate hardening, IA threading, progressive disclosure, responsive, restrained motion, full state expression. Ratified brief: `.planning/vM016-UI-ITERATION-BRIEF.md`. Latest published release: `cairnloop` v0.5.1 on Hex.pm.

## Current Position

Phase: 37 — Component Primitives (not started)
Plan: —
Status: Roadmap defined; ready to plan Phase 37
Last activity: 2026-06-03 — Roadmap created (phases 37–45, 29 requirements mapped)

```
Progress [          ] 0/9 phases · 0/0 plans
```

## Accumulated Context

### Decisions (carried — project-level)

5 patterns are project-level architectural invariants (see `PROJECT.md` "## Architectural
Invariants"): (1) sealed-contract + additive-opts, (2) snapshot-at-decision, (3) fail-closed
envelope-boundary cap, (4) three-layer at-most-once, (5) Governance-facade reads from the web
layer. Subagents read these from `PROJECT.md`.

vM015 additions (see PROJECT.md Key Decisions): release-please release pipeline; audit-against-
live-source as the milestone gate (move it before the release tag); test-only security closure
for already-correct domain code; `release_gate` gates on the green integration suite.

vM016 ratified decisions (do not re-litigate):

- **D1 (Home):** two-tier primacy — hero "Work the queue" + secondary "Tend the trail" band;
  `cl_stat` de-polymorphized to numeric-only; `cl_hero` for the primary count; health as `cl_chip`;
  copper = route marker (70/20/10 palette); `safe/2` fail-closed counts retained; scoped count
  queries + throttle to avoid per-PubSub-tick re-query.

- **D2 (Rail):** native `<details>`/`<summary>` for all per-card progressive disclosure (no
  server assigns for open state — PubSub reloads must not snap panels shut); Tier 1 (safety
  quartet + pending footer) never collapses; `Phoenix.LiveView.JS` only for rail-level controls
  and localStorage density toggle.

- **D3 (Responsive):** mobile-first `min-width` authoring; breakpoints 640/768/1024 as literal
  constants in one CSS comment block — NOT tokenized as `var()` (silent no-op in `@media`);
  `--cl-content-max`/`--cl-rail-width`/`--cl-page-gutter` layout tokens added; CSS architecture
  stays BEM + `.cl-` utilities, no Tailwind, no build step.

- **Gate hardening:** brand-token gate extended to catch inline `style="…#hex…"`, raw `rgba()/hsl()`,
  and helper-returned hex in render `.ex` files; magic-comment allowlist; `.css` file stays unscanned;
  complementary Credo check is dev-time only — ExUnit gate is CI truth.

- **Motion:** transform + opacity only; `prefers-reduced-motion` honored live; never on reply-send,
  keystrokes, count ticks, or layout properties.

### Pending Todos

- None. (The vM016 demo/visual-proof work shipped via **PR #15** — merged to `main` 2026-05-30,
  merge commit `b625634`; CI green incl. `release_gate`. See `.planning/threads/vM016-demo-visual-proof.md`.
  Intentionally release-neutral — `chore`/`docs` only, no `lib/` change, so no release-please bump;
  the 14 screenshots reach hexdocs on the next `feat`/`fix` release.)

### Blockers/Concerns

- ~~Verification debt (33/34/35 missing VERIFICATION/VALIDATION)~~ — **RESOLVED:** backfilled at
  vM015 close by transcribing the existing green tests (`33-VALIDATION.md`, `34-VALIDATION.md`,
  `35-VERIFICATION.md`), now archived under `milestones/vM015-phases/`.

- ~~Integration CI suite red~~ — **RESOLVED in vM015 (v0.2.2):** suite greened and added to
  `release_gate`.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| ~~Verification~~ | ~~Phases 33/34/35 missing VERIFICATION/VALIDATION~~ | ✅ Resolved — backfilled at vM015 close | — |
| ~~Process~~ | ~~vM014 missing MILESTONES/RETROSPECTIVE entry~~ | ✅ Resolved — record backfilled at vM015 close | — |
| UAT (vM014) | Phase 27 `27-HUMAN-UAT.md` — 2 pending scenarios | Acknowledged/deferred (SATD: archived, not reconstructed) | vM015 close |
| UAT (vM014) | Phase 31 `31-HUMAN-UAT.md` — resolved (0 pending) | Resolved | vM015 close |
| Verification (vM014) | Phase 28 `28-VERIFICATION.md` — human_needed | Acknowledged/deferred | vM015 close |
| Verification (vM014) | Phase 30 `30-VERIFICATION.md` — human_needed | Acknowledged/deferred | vM015 close |
| Scope | Epic 13 Privacy-First Local AI (Nx/Bumblebee) | Deferred to vM016+ | vM015 planning |
| Scope | Epic 12 Advanced Routing & Team Collaboration | Deferred to vM016+ | vM015 planning |
| Scope | Epic 14 Mobile SDK Surface | Deferred to vM016+ | vM015 planning |
| Tech Debt | Centralize duplicated fail-closed search guards | Open | vM009 retrospective |
| v2 (vM016) | PHONE-01..04 phone-optimized patterns (tabbed layout, card-transform tables, off-canvas nav, container queries) | Deferred to v2 | vM016 planning |
| v2 (vM016) | AMOTION-01..02 advanced motion motifs (route-line draw, FLIP list reorder) | Deferred to v2 | vM016 planning |

## Session Continuity

**vM016 Operator UI/UX Iteration is active** (phases 37–45), roadmap defined 2026-06-03 from the
ratified `.planning/vM016-UI-ITERATION-BRIEF.md`. Latest published release: **v0.5.1** on Hex.pm.

**Roadmap:** 9 phases (37–45), 29 v1 requirements, all mapped. Phase ordering is deliberate:
primitives (37) → shell (38) → Home/D1 (39) → drift+gate (40, paired to eliminate regression
window) → rail/D2 (41) → threading (42) → responsive/D3 (43) → motion (44) → seed+verify (45).

**Release history reconciled** (the prior STATE/ROADMAP were stale at v0.3.0): since vM015 close,
three releases shipped outside formal GSD milestone numbering — **v0.4.0** (operator UI rebuilt on
a shipped design system: `priv/static/cairnloop.css` + `Cairnloop.Web.Components` + Cockpit
Home/nav; merged PR #17), **v0.5.0** (`Cairnloop.Automation.DraftGenerator` seam + Anthropic
adapter — the draft path is no longer a pure mock; PR #19), **v0.5.1** (operator-identity
`host_user_id` fix + installer fix; PR #22). vM016 formalizes the next iteration pass on that
operator surface. Per-phase `discuss`/`research`/`ui-phase` refine D1–D3 into UI-SPEC contracts —
the directions are ratified, do not re-litigate.

## Post-close maintenance (complete)

All shipped via the protected-`main` PR flow; nothing outstanding:

- **Tier 0** — vM015 close-out: 33/34/35 verification artifacts backfilled, vM014
  MILESTONES/RETROSPECTIVE record backfilled, phase dirs archived via `/gsd-cleanup` (PR #8).

- **Tier 1** — verify-before-publish (v0.2.3): fixed the `cairnloop_dashboard/2` compile break,
  added `dashboard_wiring_test.exs`, confirmed `RELEASE_PLEASE_TOKEN`, added the packaged-artifact
  contents check to `publish-hex` (PR #9).

- **Tier 2** — DX + quality (v0.3.0): credo --strict + mix_audit + docs `quality` CI lane (PR #11);
  `mix cairnloop.doctor`, NimbleOptions router opts + `:live_session_name`, installer next-steps
  (PR #12). Quality gate caught + fixed 2 HIGH CVEs (postgrex/plug) and 5 doc warnings.

- **Deferred (opt-in only):** dialyzer, sobelow, excoveralls, ex_check, full installer
  auto-router-injection. Plan archived at `~/.claude/plans/i-follow-ur-recommendations-kind-balloon.md`.

## Operator Next Steps

- **vM016 roadmap is defined.** 9 phases (37–45), 29 requirements mapped.
- Next: `/gsd:plan-phase 37` (plan Component Primitives directly, directions are ratified).
- Releases still flow through release-please: most phases are `feat:`/`fix:` → minor/patch releases
  across the milestone. Epics 12/13/14 stay opt-in / out of vM016 scope.
