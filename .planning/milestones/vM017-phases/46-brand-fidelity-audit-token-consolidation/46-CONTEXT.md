# Phase 46: Brand Fidelity Audit & Token Consolidation - Context

**Gathered:** 2026-06-23
**Status:** Ready for planning

<domain>
## Phase Boundary

The first vM017 phase — **pure analysis + file reconciliation, no palette/type evolution and no
runtime code changes.** It pressure-tests the shipped brand system against the text seed and
establishes a single canonical token source so the later token-evolution phase (48) can run once
and right. Three deliverables, all documentation/audit artifacts:

1. A **discrepancy ledger** capturing every drift between the three brand sources.
2. A **canonical-source designation** — `priv/static/cairnloop.css` `:root` is the one true source;
   the other copies are documented as derivatives of it.
3. A **WCAG-AA contrast baseline table** covering every foreground/background brand pairing in the
   operator UI and brand book, with failures flagged. This table is reused verbatim as brand-book
   content in Phase 51.

**Explicitly NOT in this phase:** changing any `--cl-*` value, evolving the palette or font stack
(that is Phase 47 exploration → Phase 48 lock & propagate), editing derivative files, adding a
drift-guard test, or touching the sealed brand-token gate. Type/font inventory is a Phase 47
concern (TOKEN-01), not Phase 46.

</domain>

<decisions>
## Implementation Decisions

### Consolidation strategy (the one owner-surfaced fork)
- **D-01 (owner-selected): Document-only — defer all edits to Phase 48.** When the ledger finds
  drift between canonical `:root` and its derivatives (`app.css` `@theme`, `cairnloop.tokens.json`),
  Phase 46 **records it but does not edit any file.** Rationale: Phase 48 ("Token Evolution: Lock &
  Propagate") rewrites every derivative with the *evolved* values and its SC2 already requires a
  diff confirming the derivatives match canonical exactly — so fixing pre-evolution drift now is
  churn that 48 redoes. Keeps Phase 46 pure-analysis as the roadmap states ("pure analysis + file
  reconciliation" = reconcile-on-paper, not reconcile-in-files). The drift items in the ledger
  become the explicit worklist Phase 48 must zero out.

### Canonical source & provenance
- **D-02:** `priv/static/cairnloop.css` `:root` is the **single canonical token source** (it ships,
  it carries the live ~470 `--cl-*` references, it is what the operator UI actually consumes).
- **D-03:** `prompts/cairnloop.tokens.json`, the example-app `assets/css/app.css` `@theme` block,
  and the prose color rules in `prompts/cairnloop_brand_book.md` are each documented in the ledger
  as **derivatives/expressions** of the canonical `:root` — **none are deleted or restructured** in
  this phase (SC2 says "documented as derivatives," not removed). The provenance is recorded in the
  ledger; `app.css` already carries a "keep both in sync with priv/static/cairnloop.css" comment,
  which the ledger should cite as the existing (informal) provenance marker.

### Audit artifacts (format & location)
- **D-04:** Two Markdown artifacts live in the phase dir:
  `46-DISCREPANCY-LEDGER.md` and `46-CONTRAST-BASELINE.md`. The contrast baseline is authored as a
  clean, self-contained Markdown table (hex + token name + pairing + ratio + AA pass/fail/large
  badge) so **Phase 51 can lift it verbatim** into the brand book — design it for downstream reuse,
  not just as a phase scratchpad.

### Contrast baseline scope & method
- **D-05:** Cover **both light AND dark themes** (the operator UI ships a dark mode; pairings differ
  per theme). Enumerate every fg/bg pairing actually used: body/secondary text on canvas + card
  surfaces, the copper route-marker (`--cl-path-copper #A94F30`) on its backgrounds, status cells,
  chips, and borders-used-as-UI-components.
- **D-06:** Apply WCAG 2.x thresholds: **4.5:1** normal text, **3.0:1** large text (≥24px, or
  ≥18.66px bold), **3.0:1** non-text UI components (borders, focus rings, the route marker as a
  semantic indicator). Note that "never state-by-color-alone" (brand §7.5) means color pairings are
  reinforced elsewhere — but the contrast table still scores them.
- **D-07 (tooling):** Compute ratios with a **throwaway relative-luminance script** (deterministic,
  run-once); **nothing is committed to the library** — the deliverable is the static table, not a
  tool or a new runtime dependency (repo hygiene).
- **D-08 (failures):** Any AA failure is documented in the baseline table **with a remediation
  note**, and surfaced as an explicit input to Phase 47 palette exploration / Phase 48 re-verify.
  The palette is **not** adjusted in this phase to fix failures.

### Claude's Discretion
- Exact ledger table columns/grouping, how pairings are enumerated, and the script implementation
  are planner/executor discretion within the above constraints.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The three brand sources being audited (the subjects of the ledger)
- `priv/static/cairnloop.css` — **canonical** `:root` token source (~470 `--cl-*` refs, light + dark themes).
- `prompts/cairnloop.tokens.json` — structured token derivative (primitives + semantic mappings).
- `prompts/cairnloop_brand_book.md` — text seed; prose color rules and the brand voice/§7.5
  "never state-by-color-alone" rule. Especially the color section and §7.5.
- `examples/cairnloop_example/assets/css/app.css` — Tailwind `@theme` derivative (already carries a
  "keep in sync" comment; mirrors the `--cl-*` palette).

### Milestone & phase governance
- `.planning/ROADMAP.md` §"Phase 46" — goal + 3 success criteria; §"Phase 47/48" for what this phase
  feeds (palette exploration + lock/propagate).
- `.planning/REQUIREMENTS.md` — FIDELITY-01 / FIDELITY-02 / FIDELITY-03 (the requirements this phase
  closes); D-A (palette/type reopened) framing.
- `.planning/STATE.md` §"Decisions" — vM017 locked decisions D-A/D-B/D-C; sealed brand-token gate
  contract (no token renames, value-changes + additive only).
- `~/.claude/plans/brand-book-pressure-test-abundant-dragonfly.md` — the approved milestone plan
  (source of D-A/D-B/D-C).

### Project posture
- `CLAUDE.md` / `.planning/PROJECT.md` "Architectural Invariants" — sealed-contract + additive-opts;
  brand tokens over hardcoded hex; calm/honest operator copy.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The example-app `app.css` `@theme` block already has a provenance comment ("keep both in sync with
  priv/static/cairnloop.css") — cite it as the existing informal derivative marker rather than
  inventing a new one.
- `cairnloop.tokens.json` already separates `color.primitive` (raw hex) from semantic mappings — the
  ledger can compare primitive-by-primitive against `:root` cleanly.

### Established Patterns
- **Sealed brand-token gate** (vM016 Phase 40): the gate scans render `.ex` files for inline hex /
  raw `rgba()` / helper-returned hex; the `.css` file itself stays unscanned. Phase 46 adds NO new
  gate logic — automated drift-checking is Phase 48's job (its SC2 "diff confirms values match").
- Tokens are authored as `var(--cl-*, #fallback)` with copper primary `#A94F30`; both light and dark
  theme blocks exist in `:root`/theme selectors.

### Integration Points
- The `46-CONTRAST-BASELINE.md` table is a forward dependency for **Phase 51** (brand-book content)
  and **Phase 48 SC4** (re-verify the same pairings against the evolved palette) — author it to be
  re-runnable/re-checkable, not one-shot prose.

</code_context>

<specifics>
## Specific Ideas

- Contrast table columns suggested: `Pairing | FG token (hex) | BG token (hex) | Theme | Ratio |
  Threshold | Verdict (AA / AA-large / FAIL)` — design once, reuse in 48 and 51.
- The copper route-marker (`--cl-path-copper`) is the highest-risk pairing for AA — flag it
  explicitly in both themes; it is a semantic indicator (3.0 non-text threshold) when used as a
  marker and 4.5 when used behind text.

</specifics>

<deferred>
## Deferred Ideas

- **Automated drift-guard test** (a test that diffs derivatives against canonical) — belongs in
  **Phase 48** (its SC2 already requires the diff). Noted as a forward-compat guardrail for 48.
- **Editing/regenerating derivatives to eliminate drift** — deferred to **Phase 48** per D-01.
- **Type/font-stack inventory & evolution** — **Phase 47** (TOKEN-01) explores type variants; not a
  fidelity/contrast concern for 46.
- **Making `tokens.json` a generated artifact** (true derivation pipeline) — the brand book's
  `tokens.css` derivation is **Phase 50** (BOOK-02); not in scope here.

</deferred>

---

*Phase: 46-Brand Fidelity Audit & Token Consolidation*
*Context gathered: 2026-06-23*
