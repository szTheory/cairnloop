# Phase 46: Brand Fidelity Audit & Token Consolidation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-23
**Phase:** 46-Brand Fidelity Audit & Token Consolidation
**Areas discussed:** Consolidation strategy (owner-surfaced); all other gray areas auto-decided per repo shift-left policy

---

## Consolidation strategy (reconcile-now vs. document-only)

| Option | Description | Selected |
|--------|-------------|----------|
| Document-only (defer edits to 48) | Ledger + canonical designation + contrast table; zero file edits. Phase 48 ("Lock & Propagate") rewrites all derivatives with evolved values anyway, so fixing pre-evolution drift now is churn. Keeps 46 pure-analysis as the roadmap states. | ✓ |
| Reconcile non-evolving drift now | Additionally edit derivatives to match canonical for tokens not slated for evolution. More literal "consolidation" but touches files in an analysis phase and overlaps Phase 48. | |

**User's choice:** Document-only (defer edits to 48)
**Notes:** This sets D-01. The drift items in the ledger become Phase 48's worklist; 46 reconciles on paper, not in files.

---

## Claude's Discretion (auto-decided per CLAUDE.md shift-left + discuss-phase override)

These gray areas were resolved without asking — recorded rationale lives in CONTEXT.md `<decisions>`:

- **Canonical source = `priv/static/cairnloop.css` `:root`** (ships; ~470 refs). tokens.json + app.css `@theme` + brand-book prose are documented derivatives; none deleted. (D-02/D-03)
- **Artifacts:** `46-DISCREPANCY-LEDGER.md` + `46-CONTRAST-BASELINE.md` in the phase dir; contrast table authored as clean Markdown for verbatim reuse in Phase 51. (D-04)
- **Contrast scope:** both light + dark themes; every used fg/bg pairing; WCAG 2.x thresholds (4.5 / 3.0 large / 3.0 non-text UI incl. the copper route marker). (D-05/D-06)
- **Tooling:** throwaway luminance script; nothing committed to the lib. (D-07)
- **AA failures:** documented with remediation notes as inputs to Phase 47/48; palette not touched in 46. (D-08)
- **No new automated drift-guard test in 46** — that is Phase 48's diff-check responsibility.

## Deferred Ideas

- Automated drift-guard / derivative-diff test → Phase 48 (its SC2).
- Editing/regenerating derivatives to remove drift → Phase 48 (per D-01).
- Type/font-stack inventory & evolution → Phase 47 (TOKEN-01).
- `tokens.json` / `tokens.css` true derivation pipeline → Phase 50 (BOOK-02).
