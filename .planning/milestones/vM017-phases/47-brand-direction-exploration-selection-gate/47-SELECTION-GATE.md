# Phase 47 Selection Gate

**Status:** Locked owner selection, recorded for downstream execution.

This document is a durable handoff record, not a new decision prompt. The subjective selection
already happened in `47-DISCUSSION-LOG.md`; Phase 47 formalizes it so Phases 48 and 49 can proceed
without reopening the gate.

## Locked Selection

| Gate item | Locked choice |
| --- | --- |
| Logo | C3.6 crowning-loop cairn |
| Palette | Refined |
| Type | current type stack: Atkinson Hyperlegible + Fraunces + Martian Mono |

The logo selection is D-47-LOGO: a crowning-loop cairn where the open copper ring is the top stone,
the stone stack is wider and flatter, and the ring is compact enough to read at favicon scale.

The palette selection is D-47-PALETTE: the Refined basalt, trailpaper, copper, muted, and dark-danger
tuning. The exact canonical values are Phase 48-owned.

The type selection is D-47-TYPE: keep the existing Atkinson Hyperlegible workhorse, Fraunces display
and wordmark, and Martian Mono ID/code stack.

## Rationale

C3.6 survived the 16px proof and still reads as one cairn: the ring is the top stone, not a separate
halo or decorative loop. The mark keeps the loop structural, so the feedback/return idea is present
without turning into an infinity symbol, a chat bubble, or a rectangular cage.

The C3.6 geometry also supports D-47-LOCKUP: tight horizontal lockup, vertical/stacked lockup,
plain Fraunces wordmark, and mono one-color cuts for print. The owner rejected the looser icon-left
spacing and the integrated `oo` wordmark echo during finalization.

Refined was selected because it evolves the existing basalt/trailpaper/copper system without
discarding the quiet, durable identity. It also carries the Phase 46 accessibility work forward:
Phase 48 must fix the known contrast failures rather than merely restyling the brand.

## Board Artifact

The board artifact is `logo/_contest/direction-boards.html` per D-47-BOARDS.

It records the selected C3.6 direction, shows the four explored roster directions from D-47-ROSTER,
and keeps the Phase 48/49 boundaries visible:

- `Selected: C3.6 crowning-loop cairn`
- `Selected: Refined palette`
- `Selected: current type stack`
- `Preview only: canonical tokens change in Phase 48`
- `Concept only: production asset family is Phase 49`

The board is self-contained and opens from `file://`. It is contest evidence, not a production logo
or token source.

## Downstream Handoff

Phase 48 consumes the Refined palette and current type selection. It must resolve the Phase 46
contrast findings: the 3 real text failures, the 4.52:1 muted-text fragile pairing, the dark danger
failure, and classification of the 12 border failures.

Phase 49 consumes the C3.6 concept geometry and D-47-LOCKUP defaults to produce the production SVG
asset family: primary horizontal lockup, vertical/stacked lockup, icon-only mark, mono variants,
favicon, and OG/social source.

Phases 51 and 52 consume the finalized outputs, not this contest artifact, for brand-book rendering
and app/README wiring.

## Rejected Directions

- Direction B: negative-space loop, explored and rejected.
- Direction D: waymark/contour glyph, explored and rejected.
- C10: open-arch family, explored and rejected after comparison with C3.6.
- Conservative palette: rejected as too static.
- Bolder palette: rejected because it risks the quiet, durable thesis.
- Spectral: rejected/context only; Fraunces remains selected.
- `oo-ring typemark`: explored and rejected; the final wordmark remains plain `cairnloop`.

## Scope Boundaries

D-47-HYGIENE remains in force for this phase.

Phase 47 does not edit canonical tokens, README, example-app logo/favicon, `brandbook/`, `mix.exs`,
or production logo assets. Those surfaces remain untouched until their owning phases:

- Phase 48: canonical `priv/static/cairnloop.css`, example app `@theme`, and
  `prompts/cairnloop.tokens.json`.
- Phase 49: optimized production logo asset family, favicon, and OG source.
- Phase 50/51: `brandbook/` scaffold and full HTML brand book.
- Phase 52: README and example-app wiring.

Rejected contest directions remain as evidence in Phase 47 and are deleted later only when Phase 49
produces the final asset family.
