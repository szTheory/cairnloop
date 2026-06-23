---
phase: 46
slug: brand-fidelity-audit-token-consolidation
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-23
---

# Phase 46 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **Phase character:** This phase ships **documentation/audit artifacts** (a discrepancy
> ledger, a canonical-source designation, and a WCAG-AA contrast baseline table) plus a
> single **throwaway, uncommitted** relative-luminance script (CONTEXT D-07). There is no
> library code change and no `mix.exs` change. "Validation" here is therefore
> **artifact-completeness verification** — every canonical token is accounted for, every
> enumerated fg/bg pairing is scored, and provenance is recorded — not unit tests.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — no library code changes; deliverables are markdown artifacts. A throwaway Python (stdlib-only) relative-luminance script computes contrast ratios, then is deleted (D-07). |
| **Config file** | none |
| **Quick run command** | `python3 <throwaway-luminance-script>` (during authoring only; recomputes ratios) |
| **Full suite command** | `mix compile --warnings-as-errors` (sanity — confirms no library code was touched) |
| **Estimated runtime** | ~5 seconds (script); ~30 seconds (compile sanity) |

---

## Sampling Rate

- **After every task commit:** Confirm the artifact under edit parses as clean Markdown and the relevant completeness check (below) holds for the rows added.
- **After every plan wave:** Re-run the artifact-completeness checks across all three deliverables.
- **Before `/gsd-verify-work`:** All completeness gates green; `mix compile --warnings-as-errors` still clean (proves the library was not mutated).
- **Max feedback latency:** ~5 seconds (checks are grep/read over the artifacts).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | FIDELITY-01 | — / — | N/A (doc artifact) | artifact-completeness | `grep -c '^| ' 46-DISCREPANCY-LEDGER.md` ≥ canonical token count (both themes) | ❌ W0 | ⬜ pending |
| 46-01-02 | 01 | 1 | FIDELITY-02 | — / — | N/A (doc artifact) | artifact-review | provenance/derivative note present for `app.css` `@theme`, `cairnloop.tokens.json`, brand-book prose | ❌ W0 | ⬜ pending |
| 46-01-03 | 01 | 1 | FIDELITY-03 | — / — | N/A (doc artifact) | artifact-completeness | every enumerated pairing × {light,dark} has a Verdict cell; failures carry a remediation note | ❌ W0 | ⬜ pending |
| 46-01-04 | 01 | 1 | FIDELITY-03 | — / — | N/A (no committed tool) | hygiene | `git status` shows no committed script / no `mix.exs` change (D-07) | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Plan/task IDs are indicative; the planner sets the authoritative breakdown.*

---

## Wave 0 Requirements

- [ ] `46-DISCREPANCY-LEDGER.md` — created in the phase dir (stub → filled)
- [ ] `46-CONTRAST-BASELINE.md` — created in the phase dir (stub → filled)
- [ ] No test-framework install — none required (documentation phase)

*Existing infrastructure (markdown + a throwaway stdlib script) covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Ledger covers every canonical `--cl-*` token (both themes) with a drift verdict vs each derivative | FIDELITY-01 | Completeness is a judgement over the canonical token inventory; no runtime to assert it | Cross-check ledger rows against the RESEARCH token-inventory tables; confirm no canonical token is unlisted |
| Canonical-source designation recorded; the two file derivatives + brand-book prose each carry a provenance note | FIDELITY-02 | Provenance is documentary intent, not observable behavior | Read the designation section; confirm each derivative is named as a derivative-of-`:root` (cite the existing `app.css` "keep in sync" comment) |
| Contrast table scores every shipped fg/bg pairing per theme; copper route-marker scored at both 3.0 (UI/large) and 4.5 (text) thresholds; failures + near-misses flagged with remediation notes routed to Phase 47/48 | FIDELITY-03 | WCAG verdicts require human reading of the pairing context; the table is reused verbatim in Phase 51 | Recompute ratios with the throwaway script; confirm each pairing row has fg/bg hex, theme, ratio, threshold, verdict; confirm `text-muted` near-miss (4.52:1) is flagged |

---

## Validation Sign-Off

- [x] All tasks have an artifact-completeness check or Wave 0 dependency
- [x] Sampling continuity: each deliverable has at least one completeness gate
- [x] Wave 0 covers all MISSING references (no test-framework install required; artifact files created in the single wave by Tasks 1–2)
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-23
