# Requirements — vM017 Brand Identity System, Token Evolution & HTML Brand Book

**Milestone goal:** Turn the text-only brand seed into a crafted identity — a distinctive hand-authored
logo system (owner-selected from 4 directions incl. an integrated typemark), an evolved core palette/type,
and a self-contained professional HTML brand book — then wire the chosen mark into the real shipped surfaces.
Repo-hygienic and drift-free.

**Source:** approved plan `~/.claude/plans/brand-book-pressure-test-abundant-dragonfly.md` +
`prompts/cairnloop_brand_book.md` (text seed). Locked decisions: **D-A** reopen/evolve core palette+type;
**D-B** wire collateral into README + example app + favicon + OG; **D-C** 4 hand-authored logo directions
(one integrated typemark). Logo constraints: no rectangular cage, unified mark+type, no subtitle on primary
lockup, hand-authored SVG. Hygiene: `brandbook/` self-contained, SVG-first, raster only for favicon/OG
(≤~150KB), out of the hex package.

> Two human gates: (1) **brand-direction selection** (logo + palette + type) at the end of the exploration
> phase; (2) **logo-family sign-off** before wiring. Selection is subjective — never auto-decided or E2E'd.

## v1 Requirements

### Fidelity & Token Consolidation
- [ ] **FIDELITY-01**: A discrepancy ledger documents every drift between `prompts/cairnloop_brand_book.md`, `prompts/cairnloop.tokens.json`, and the live `--cl-*` values in `priv/static/cairnloop.css`.
- [ ] **FIDELITY-02**: A single canonical token source is established (`priv/static/cairnloop.css` `:root`); the example-app `app.css` block and `cairnloop.tokens.json` are documented as derivatives of it.
- [ ] **FIDELITY-03**: A WCAG-AA contrast baseline table covers every foreground/background brand pairing used in the brand book and operator UI, flagging any failures.

### Logo System
- [ ] **LOGO-01**: Four genuinely distinct, hand-authored SVG logo directions exist — one a fully-integrated custom typemark — each with a transparent background and no rectangular cage.
- [ ] **LOGO-02**: A local HTML "direction boards" page renders all four directions at 16/24/48/256px, horizontal + vertical lockups, on light and dark surfaces, with explicit no-cage and 16px-legibility proof rows.
- [ ] **LOGO-03**: The owner selects one logo direction at the selection gate; the choice and rationale are recorded durably.
- [ ] **LOGO-04**: The chosen direction is finalized into a full optimized-SVG asset family — primary horizontal (no subtitle), vertical/stacked, icon-only, mono basalt-on-paper + paper-on-basalt, and a separate optional tagline lockup — with mark and logotype visually unified.
- [ ] **LOGO-05**: A separately-authored simplified favicon (16/32) and an OG/social card (1200×630 SVG master) exist, with raster exports (favicon `.ico`/PNG, OG PNG) within the ≤~150KB total budget.
- [ ] **LOGO-06**: Logo usage rules — clearspace, minimum sizes, and do/don't panels (incl. no-cage and no-icon-left-of-text) — are documented and rendered in the brand book.

### Token Evolution (D-A)
- [ ] **TOKEN-01**: Palette and type variants are presented alongside the logo directions; the owner selects the evolved palette + type direction.
- [ ] **TOKEN-02**: The chosen palette/type is applied to the canonical `:root` source via value-changes and additive tokens — no token renames that break the sealed brand-token contract.
- [ ] **TOKEN-03**: The evolved tokens are propagated to the example app (`assets/css/app.css` `@theme`) and `cairnloop.tokens.json` with zero drift between the canonical source and its derivatives.
- [ ] **TOKEN-04**: After propagation, the brand-token gate, golden-path smoke, and gated Playwright E2E are green, and the contrast baseline is re-verified against the evolved palette.

### HTML Brand Book
- [ ] **BOOK-01**: A self-contained `brandbook/` folder opens from `file://` with no network dependency and no console or failed-network errors.
- [ ] **BOOK-02**: `brandbook/assets/css/tokens.css` is derived (not forked) from the canonical `cairnloop.css` `:root`, documented in `brandbook/TOKENS.md` with a regeneration note.
- [ ] **BOOK-03**: The brand book renders all sections as live HTML — color swatches (hex + token name + AA contrast badges), real-font type specimens, spacing/radius/shadow/motion tokens, and voice/microcopy/imagery guidance.
- [ ] **BOOK-04**: The brand book presents the chosen logo system — lockup gallery, clearspace/min-size diagrams, do/don't panels — with download links to the committed SVG assets.
- [ ] **BOOK-05**: The brand book supports a light/dark toggle and never communicates state by color alone.

### Collateral Wiring (D-B)
- [ ] **WIRE-01**: The example app's placeholder logo (`examples/cairnloop_example/priv/static/images/logo.svg`) is replaced with the chosen mark, and favicon + `og:image` meta are updated in the example app's `root.html.heex`.
- [ ] **WIRE-02**: `README.md` leads with the chosen SVG logo header using a repo-relative path that also renders on GitHub.
- [ ] **WIRE-03**: Rendered-behavior verification (example app renders the new logo + favicon) is authored as a gated Playwright E2E, not a human-verify task.

### Repo Hygiene & QA
- [ ] **HYGIENE-01**: Every committed SVG is valid (well-formed XML, valid `viewBox`, no external references, no embedded raster) and optimized (no editor metadata cruft).
- [ ] **HYGIENE-02**: Total raster footprint (favicon + OG only) is within the ≤~150KB budget, no PNG fallbacks are committed for logos, and rejected logo directions are deleted after selection.
- [ ] **HYGIENE-03**: `brandbook/` is git-tracked but excluded from the hex package (`mix.exs` `files` unchanged); the QA report records the repo-size delta and confirms changes are confined to `brandbook/` plus the intended wiring files.

## Future Requirements (deferred)
- Animated/interactive brand book (motion specimens, live token playground) — defer; static HTML first.
- Marketing landing-page build-out (beyond README header + OG card) — separate effort.
- Self-hosted web-font subsetting for true offline specimens — defer unless the chosen type direction requires it.
- Logo motion/lottie variants, presentation/slide templates, sticker/swag assets — out of this milestone.

## Out of Scope
- Any product feature scope (the product stays "done enough for stated scope"; Epics 12/13/14 remain opt-in).
- Reworking already-shipped operator UI behavior — vM017 evolves tokens/brand, not component logic.
- Shipping the brand book inside the hex package (it stays git-tracked but unshipped).
- Resuming or completing vM016 (parked; resumed after vM017 ships).
- Committing large binary artifacts (AI raster source, `.fig`/`.ai`/`.sketch`, unsubsetted font binaries).

## Traceability
*(filled by roadmap — every REQ-ID maps to exactly one phase)*
