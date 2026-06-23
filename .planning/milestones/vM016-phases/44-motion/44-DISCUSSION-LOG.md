# Phase 44: Motion - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 44-Motion
**Areas discussed:** List-enter stagger scope

**Discussion posture:** Phase 44 is heavily pre-specified (brand book §15, ROADMAP success criteria,
existing motion token block, existing global reduced-motion + `.cl-motion-state`). Per the repo
shift-left policy and the owner's `minimal_decisive` calibration, the mechanical / docs-determined calls
were decided directly (recorded as D-01..D-09 in CONTEXT.md) and only the single genuine product-feel
decision was surfaced.

---

## List-enter stagger scope

| Option | Description | Selected |
|--------|-------------|----------|
| Insert-only | Stagger plays on first paint and on real new-row insert; returning to a screen does NOT re-stagger existing rows. Calmest; motion always signals real change. Honoring it needs a small mount-once guard since LiveView re-mounts on live nav. | ✓ |
| Replay on navigation | Re-staggers the whole visible list on every arrival to the screen. Reinforces "you've arrived" (clarifies route per §15.1) but repeats the same motion every visit; can read as busy over a shift. | |

**User's choice:** Insert-only
**Notes:** Aligns with "restrained brand motion" and the negative success criteria (no motion on
mere navigation/count ticks). Captured as D-05. Planner caveat recorded: LiveView re-mount on live
navigation means a naive CSS-only animation would replay — a lightweight mount-once guard is needed.

---

## Claude's Discretion

Decided directly (docs/token-determined or implementation-level), recorded in CONTEXT.md `<decisions>`:
- D-01 Mechanism: pure CSS + sparing `phx-mounted={JS.transition}`; no new JS hooks / no WAAPI (v2 AMOTION).
- D-02 CSS authored under `.cl-app`, mirrored across lib + example CSS files.
- D-03 Hero count: fade + ~4px translate-up, one-shot, <180ms, no count-up; text node carries no transition.
- D-04 List stagger: CSS `nth-child(-n+5)` delays, transform+opacity, fires on DOM insert.
- D-06 Gate state-flip reuses `.cl-motion-state` (the reduced-motion-preserved cross-fade).
- D-07 Rail/drawer reveal via `translateX`+`opacity`, 260ms `--cl-ease-drawer`; no layout-prop transitions.
- D-08 Toast enter/exit via `phx-mounted`/`phx-remove` JS.transition; lib-vs-example placement is a planner research item.
- D-09 Reduced motion already global; ensure new animations sit under `.cl-app`, gate flip is the surviving cross-fade.

## Deferred Ideas

- Route-line draw + marker-travel motif; source-card stack reveal / FLIP list reorder — WAAPI/`phx-hook`,
  already tracked as **AMOTION-01 / AMOTION-02**, deferred to **v2**. Not pulled into Phase 44.
- Cockpit-wide density tuning — separate concern (noted in P41 context).
