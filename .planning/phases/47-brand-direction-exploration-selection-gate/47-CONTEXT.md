# Phase 47: Brand Direction Exploration [SELECTION GATE] - Context

**Gathered:** 2026-06-24
**Status:** Ready for planning — owner selection already made (see `<decisions>`)

<domain>
## Phase Boundary

The vM017 **selection gate**: hand-author the creative options — four SVG logo directions plus
palette and type variants — render them on a local `file://` "direction boards" page, and capture
the owner's recorded, subjective pick of **one logo + one palette + one type direction**. That pick
(LOGO-03 / TOKEN-01) unlocks Phase 48 (token lock & propagate) and Phase 49 (logo finalization).

This phase **produces choices and records the selection**. It does **NOT**: build the production
logo asset family (Phase 49), evolve/lock tokens in `:root` (Phase 48), or assemble the brand book
(Phases 50–51). Per repo policy, the subjective gate is a human decision — never auto-selected,
never E2E'd.

**Note:** the owner completed the selection during this discussion via an iterative visual
tournament (four rounds of throwaway scratchpad previews). The choice is locked below; Phase 47
execution therefore *formalizes* the direction-boards artifact (documenting the four explored
directions + the chosen one) rather than running an open exploration.
</domain>

<decisions>
## Implementation Decisions

### A. The locked owner selection (the gate — LOGO-03 / TOKEN-01)

- **D-47-LOGO (owner-selected): Crowning-loop cairn, "ring is the top stone," wider & flatter stones
  with a compact ring** (tournament id **C3·6**). A stacked cairn whose topmost element is an open
  copper waymark ring — the loop *is* the crown, structural to the mark, not a line hung behind it.
  The loop reads as feedback / routing / "the trail returns" — **never** an infinity symbol, **never**
  a chat bubble, **never** a rectangular cage. Base stone widest & calm; asymmetric stones; the
  copper ring is the single accent.
  - *Rationale:* survives to favicon size (proven at 16px in the tournament), is unmistakably one
    cairn (most resolved read), and carries the loop meaning without futurist clichés. Chosen over
    the open-arch alternative (C10) for its stronger small-size legibility and single-object unity.
  - *Reference geometry* (throwaway 48×48 SVG — Phase 49 hand-authors the optimized production mark
    from this; it is a concept reference, not the shipped asset): ring `cx24 cy15 r5.4` stroke-width
    2.8; mid stone `x12 y25 w24 h7 rx3.5`; base stone `x7 y34 w34 h8 rx4`. Full source embedded in
    `47-DISCUSSION-LOG.md`.

- **D-47-PALETTE (owner-selected): "Refined."** Keep the basalt / trailpaper / copper identity but
  tune it and fix every Phase-46 AA failure. Illustrative shifts (Phase 48 finalizes exact values):
  basalt `#18211F→#141B19`, paper `#F5F0E6→#F4EEE2`, **copper `#A94F30→#A8492A`** (AA-safe for white
  text), muted `#677066→#5E665D`, dark-danger `#E18C7D→#C96A55`. The chosen mark's copper accent is
  `#A8492A` (light) / `#D98A4A` (dark). **Hard constraint:** the evolved palette MUST zero out the
  Phase-46 contrast failures (see canonical refs).
  - *Rationale:* evolves the feel without changing brand identity; best match for the calm, durable
    mark. Chosen over "Conservative" (too static) and "Bolder" (risks the quiet/durable thesis).

- **D-47-TYPE (owner-selected): keep the current stack** — **Atkinson Hyperlegible** (UI workhorse)
  + **Fraunces** (display / wordmark) + **Martian Mono** (code/IDs). No alternative explored;
  Fraunces was confirmed for the wordmark in round 1.
  - *Rationale:* Fraunces is the owner's pick; the workhorse + mono are well-suited, and leaving the
    workhorse unchanged means **no font-binary-budget work in Phase 48**.

- **D-47-LOCKUP (defaults; finalized in Phase 49):** horizontal primary lockup (mark + `cairnloop`,
  **tight kern**, mark optically centered to the wordmark's cap height — round-3's wide gap was
  rejected); vertical / stacked lockup; mono one-color cut for print; favicon proven at 16px.
  **The `oo`-ring echo / integrated-typemark wordmark treatment was explored and REJECTED by the
  owner** — the mark stands alone, plain `cairnloop` wordmark. (D-C's "explore one integrated
  typemark direction" was satisfied by the exploration; shipping it was not required.)

### B. Auto-decided implementation choices (shift-left — recorded, not owner-surfaced)

- **D-47-BOARDS:** the direction-boards artifact is `logo/_contest/direction-boards.html`; opens from
  `file://` with **relative paths only**, no network/console errors; renders all four directions at
  **16 / 24 / 48 / 256px**, in **horizontal + vertical** lockups, on **light AND dark** surfaces,
  with explicit **no-cage proof** rows and **16px-legibility proof** rows; palette and type variants
  shown alongside each direction so choices read cohesively.
- **D-47-ROSTER:** the four directions are the milestone-plan starting set — (A) stacked-cairn +
  wrapping loop, (B) negative-space loop, (C) integrated typemark, (D) waymark/contour glyph — with
  the *chosen* direction being the C3·6 crowning-loop refinement that emerged from exploring (A)/(C).
- **D-47-HYGIENE:** `logo/_contest/` is git-tracked but **out of the hex package** (`mix.exs` `files`
  unchanged); rejected directions are deleted in **Phase 49** (not here); the selection + rationale
  live in `47-DISCUSSION-LOG.md` (durable human record, not an automated check).

### Scoping note for the planner
The owner pre-selected during discussion. Scope Phase 47 execution to **formalize** the boards page
as documentation of the four directions + the chosen C3·6 mark, plus the recorded selection — not as
a fresh open-ended exploration. The heavy creative search is already done.

### Claude's Discretion
Exact boards-page layout/markup, how the proof rows are arranged, and the precise reference-SVG
redraw are planner/executor discretion within the constraints above.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Brand source of truth
- `prompts/cairnloop_brand_book.md` — **§6 Visual identity** (logo direction, wordmark, lockups,
  shape language), **§7 Color system** (palette, proportions, §7.5 accessibility / never
  state-by-color-alone), **§8 Typography** (Atkinson / Fraunces / Martian stack, type scale).
- `priv/static/cairnloop.css` — canonical `:root` token source (light + dark). **Evolved in Phase
  48** with the Refined palette; not edited in Phase 47.

### What this phase consumes / feeds
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md` — the
  WCAG-AA baseline; **the Refined palette MUST resolve the 3 real text failures + the fragile
  4.52:1 muted-text + classify the 12 border failures + the dark danger button (2.55:1)** listed
  there. Phase 48 SC4 re-verifies this exact table against the evolved palette.
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTEXT.md` — canonical-source
  designation (D-02: `:root` is the one true source) and derivative provenance.
- `.planning/ROADMAP.md` — §Phase 47 (this gate), §Phase 48 (lock & propagate), §Phase 49 (logo
  finalization) for what the selection feeds.
- `.planning/REQUIREMENTS.md` — **LOGO-01, LOGO-02, LOGO-03, TOKEN-01** (the requirements this phase
  closes).
- `.planning/STATE.md` — vM017 locked decisions **D-A** (core palette/type reopened), **D-B**
  (collateral wired in at Phase 52), **D-C** (4 logo directions; one mandatory integrated typemark);
  sealed brand-token gate contract (value-changes + additive only, no token renames).
- `~/.claude/plans/brand-book-pressure-test-abundant-dragonfly.md` — the approved milestone plan
  (Phase 47 brief, the four directions, the two human selection gates, `brandbook/` structure).

### Project posture
- `CLAUDE.md` / `.planning/PROJECT.md` "Architectural Invariants" — brand tokens over hardcoded hex
  (`var(--cl-primary, #A94F30)`); calm/honest operator copy; sealed-contract + additive-opts.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No brand logo exists yet. The only logo asset today is the stock Phoenix
  `examples/cairnloop_example/priv/static/images/logo.svg` — **replaced in Phase 52** (D-B), not in
  Phase 47.
- No `logo/` or `brandbook/` directory exists yet; Phase 47 introduces `logo/_contest/`.

### Established Patterns
- **Sealed brand-token gate** (vM016 Phase 40): scans render `.ex` files for inline hex / raw
  `rgba()` / helper-returned hex; the `.css` file stays unscanned. Phase 47 adds no gate logic.
- Tokens authored as `var(--cl-*, #fallback)`; both light + dark theme blocks live in `:root`.

### Integration Points
- The chosen C3·6 mark is the forward dependency for **Phase 49** (asset family), **Phase 51**
  (brand-book logo section), and **Phase 52** (example-app logo/favicon + README header).
- The Refined palette is the forward dependency for **Phase 48** (apply to `:root` + propagate to
  `examples/.../assets/css/app.css` `@theme` and `prompts/cairnloop.tokens.json`).
</code_context>

<specifics>
## Specific Ideas

- **C3·6 reference geometry** (48×48 viewBox; concept reference for Phase 49, full SVG in the
  DISCUSSION-LOG): open copper ring `cx24 cy15 r5.4` sw2.8 as the top stone; mid stone
  `x12 y25 w24 h7 rx3.5`; base stone (widest, calm) `x7 y34 w34 h8 rx4`.
- **Refined hex set** (illustrative; Phase 48 finalizes): basalt `#141B19`, paper `#F4EEE2`, surface
  ~`#FAF5EB`, copper `#A8492A` (light) / `#D98A4A` (dark), muted `#5E665D`, dark-danger `#C96A55`.
- The copper route-marker (`--cl-path-copper` / `--cl-primary`) is the highest-AA-risk pairing —
  the Refined copper `#A8492A` is chosen specifically to pass white-text contrast.
</specifics>

<deferred>
## Deferred Ideas

- **Production optimized-SVG asset family** (primary/vertical/icon/mono lockups), **favicon** (16/32
  + `.ico`/PNG), **OG card** — **Phase 49**.
- **Apply the Refined palette to canonical `:root`** + propagate to `app.css` `@theme` and
  `cairnloop.tokens.json`, then re-verify gates/contrast — **Phase 48**.
- **`brandbook/` scaffold + token-derivation pipeline + full HTML assembly** — **Phases 50–51**.
- **Replace example-app logo/favicon + README SVG header** — **Phase 52**.
- **"Bolder" palette** and **alternate display-type (e.g. Spectral)** — explored/offered, not chosen;
  not revisited unless the owner reopens.
- The open-arch logo direction (**C10**) and the other round-2/round-3 marks — rejected; deleted
  from the contest in Phase 49.
- The **`oo`-ring echo / integrated typemark** — explored and initially liked, **dropped by the owner
  at finalization**; the wordmark stays plain `cairnloop`.
</deferred>

---

*Phase: 47 — Brand Direction Exploration [SELECTION GATE]*
*Context gathered: 2026-06-24 · owner selection: logo C3·6 + palette Refined + type current stack*
