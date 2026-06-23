---
phase: 46-brand-fidelity-audit-token-consolidation
plan: 01
subsystem: ui
tags: [design-tokens, brand, wcag, contrast, audit, cairnloop-css, tokens-json]

requires: []

provides:
  - "Per-token canonical-vs-derivative drift ledger (15 primitives + semantic light/dark + status triads + scale groups) with Phase 48 worklist"
  - "Canonical-source designation: priv/static/cairnloop.css :root named as single source of truth with per-derivative provenance notes"
  - "WCAG-AA contrast baseline table: every shipped fg/bg pairing × both themes (light + dark), scored with ratios, thresholds, verdicts, and remediation notes"
  - "Confirmed 3 real AA text failures, 12 border failures (likely decorative), 1 fragile near-miss (text-muted on bg = 4.52:1)"
  - "14 precomputed RESEARCH anchors validated — regression reference for Phase 48 SC4 re-verify"
  - "A1 completeness: example-app HEEx Tailwind-utility grep found no additional pairings"

affects:
  - "Phase 47 (palette exploration must treat text-muted near-miss and row 13/14/22 failures as hard constraints)"
  - "Phase 48 (token evolution: drift worklist + SC4 re-verify this exact contrast matrix)"
  - "Phase 51 (brand book assembles 46-CONTRAST-BASELINE.md verbatim)"

tech-stack:
  added: []
  patterns:
    - "Throwaway stdlib-only Python script for WCAG relative-luminance computation (run-once, no commit, D-07)"
    - "Self-contained Markdown contrast table designed for verbatim Phase 51 reuse (D-04)"
    - "Drift ledger with per-token rows across all three derivative formats (D-01 document-only, defer edits to Phase 48)"

key-files:
  created:
    - ".planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md"
    - ".planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md"
  modified: []

key-decisions:
  - "D-01 (owner-selected): document-only — recorded all drift but edited no brand source file; Phase 48 zeroes out drift"
  - "D-02: priv/static/cairnloop.css :root designated single canonical token source"
  - "D-03: tokens.json + app.css @theme + brand-book §7 documented as derivatives with provenance notes; existing app.css lines 4-7 'keep in sync' comment cited"
  - "D-07: throwaway Python script written to session scratchpad only, deleted before commit; no new dependency introduced"
  - "D-08: all 3 real failures + 1 near-miss carry remediation notes routed to Phase 47/48 explicitly"

patterns-established:
  - "WCAG 2.x relative-luminance algorithm (not APCA) as the project contrast-scoring method"
  - "Dual-threshold scoring for copper route-marker (3.0 as UI indicator, 4.5 as text) — both roles documented"

requirements-completed: [FIDELITY-01, FIDELITY-02, FIDELITY-03]

duration: 8min
completed: 2026-06-23
status: complete
---

# Phase 46 Plan 01: Brand Fidelity Audit & Token Consolidation Summary

**WCAG-AA contrast baseline (every fg/bg pairing × both themes, 3 real failures + 12 likely-exempt border failures flagged) and a per-token drift ledger (15 primitives all CLEAN, shadow-raised VALUE DRIFT + 5 semantic COVERAGE GAPs in app.css) establishing priv/static/cairnloop.css :root as the single canonical source**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-23T19:01:15Z
- **Completed:** 2026-06-23T19:09:00Z
- **Tasks:** 3
- **Files created:** 2 (46-DISCREPANCY-LEDGER.md, 46-CONTRAST-BASELINE.md)
- **Files modified (brand sources):** 0 — pure analysis, no edits to any brand source

## Accomplishments

- Designated `priv/static/cairnloop.css :root` as the single canonical token source (FIDELITY-02); documented all three derivatives with provenance notes; cited the existing `app.css` lines 4–7 "keep both in sync" comment as the informal provenance marker
- Built a complete per-token drift ledger (FIDELITY-01): 15 primitives all CLEAN, semantic-light/dark layers fully audited, status triads documented as COVERAGE GAP in all derivatives, 1 confirmed VALUE DRIFT (`--cl-shadow-raised` in `app.css`), 5 semantic COVERAGE GAPs in `app.css`, `tokens.json` confirmed CLEAN on all 15 primitives and 14 semantic keys it carries
- Produced a self-contained WCAG-AA contrast table (FIDELITY-03) scoring 29 component pairings + 8 brand-book §7.5 pairings × both light and dark themes; copper route-marker dual-scored at 3.0 (UI) and 4.5 (text); 14 RESEARCH precomputed anchors validated 100%
- Identified 3 real AA text failures for Phase 47/48 resolution: white on dark danger (2.55:1), text-muted on surface-sunken ghost-button hover (4.25:1), neutral chip text (4.28:1); 1 fragile near-miss (text-muted on canvas = 4.52:1)
- All 12 border failures documented with WCAG 1.4.11 decorative-vs-informational context for Phase 47 classification
- Completed A1 completeness check (grep example-app HEEx for Tailwind utility pairings) → no additional pairings found
- Deleted throwaway script; confirmed zero mutation of any brand source file or mix.exs (D-01, D-07)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write throwaway luminance script + discrepancy ledger** — `db156d5` (docs)
2. **Task 2: Build WCAG-AA contrast baseline table** — `266ea60` (docs)
3. **Task 3: Hygiene gate — delete throwaway script, confirm zero library mutation** — `e6c86d0` (docs)

## Files Created

- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md` — canonical-source designation (Part A) + per-token drift rows (Part B) + phase hygiene attestation; Phase 48 worklist
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md` — self-contained WCAG-AA table; Phase 51 liftable verbatim; Phase 48 SC4 re-checkable

## Decisions Made

- D-01 honored: zero edits to any brand source file — all drift is documented as Phase 48's worklist
- D-07 honored: throwaway Python 3 stdlib script written to session scratchpad, used, deleted before commit — no registry lookup, no install, no committed artifact
- Dark `--cl-warning == --cl-primary` (#D98A4A) flagged as OPEN QUESTION for Phase 47 explicit sign-off (Research A3) — not assumed bug or intentional
- `text-soft` pairing on canvas/surface confirmed as decorative (WCAG 1.4.11 exempt); flagged for Phase 47 review if usage context ever changes
- All chip border failures (rows 28a–e) classified as likely-decorative under WCAG 1.4.11 with remediation route for Phase 47

## Deviations from Plan

None — plan executed exactly as written. Three tasks completed in order; all prohibitions honored (D-01/D-07); no brand source file edited; no script committed; no dependency introduced.

## Issues Encountered

None. All token values were directly readable from the four source files. Contrast ratios computed cleanly with a 25-line throwaway script; all 14 RESEARCH precomputed anchors matched exactly. The single unexpected finding (white on dark danger = 2.55:1, a real AA failure) was documented with a remediation note as specified by D-08.

## Known Stubs

None. This phase produces documentation artifacts only; no data sources, UI components, or stub values.

## Threat Flags

None. This phase introduces no runtime, network, auth, or persistence surface. The only tooling was a throwaway stdlib-only script deleted before commit (T-46-02 mitigated). All four brand source files confirmed unchanged (T-46-01 mitigated).

## Next Phase Readiness

Phase 47 (palette exploration + logo directions + type exploration) is ready to begin. It should:

1. Treat `--cl-text-muted #677066 on --cl-bg #F5F0E6 = 4.52:1` as a hard palette constraint — any bg lightening or text-muted lightening risks an AA failure on the most frequently-used muted-text pairing
2. Resolve the dark-mode danger button failure: white on `#E18C7D` = 2.55:1 (well below even 3.0)
3. Obtain explicit sign-off on `--cl-warning == --cl-primary` in dark theme (both `#D98A4A`)
4. Classify which borders are decorative vs. informational UI-component boundaries under WCAG 1.4.11
5. Consume the `46-CONTRAST-BASELINE.md` table as the Phase 47 palette constraint checklist and the Phase 48 SC4 re-verify template
6. Consume `46-DISCREPANCY-LEDGER.md` drift items as the Phase 48 derivative-reconciliation worklist

---
*Phase: 46-brand-fidelity-audit-token-consolidation*
*Completed: 2026-06-23*
