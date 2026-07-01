# Phase 49: Chosen-Logo Finalization & Asset Family - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-25
**Phase:** 49-Chosen-Logo Finalization & Asset Family
**Areas discussed:** Asset Family Shape, Small-Size Reduction, OG/Social Card, Usage Rules Strictness

---

## User Direction

The owner selected all gray areas and requested a one-shot, research-backed recommendation set using
subagents. The owner specifically asked for pros/cons/tradeoffs, ecosystem lessons, developer
ergonomics, user-friendliness, UI/UX/graphic design lenses where applicable, JTBD/persona thinking,
and a cohesive recommendation that does not require further owner selection.

Accordingly, recommendations were locked into `49-CONTEXT.md` as Claude's synthesized decisions.

---

## Asset Family Shape

| Option | Description | Selected |
| --- | --- | --- |
| Horizontal lockup | Tight C3.6 mark + plain Fraunces `cairnloop`; default public/docs mark. | x |
| Stacked lockup | Mark above wordmark; secondary for square-ish or display contexts. | x |
| Icon-only | C3.6 mark for avatar/sidebar/social/favicon source, with separate favicon cut. | x |
| Mono/reverse variants | One-color basalt-on-paper and paper-on-basalt production assets. | x |
| Optional tagline lockup | Separate promotional lockup using "Support that leaves a trail." | x |

**User's choice:** Discuss all; Claude to recommend.

**Notes:** Recommendation is a compact SVG-first family in `logo/`. Primary horizontal is the default;
stacked and tagline are contextual. Avoid live-font drift in committed SVGs where possible.

---

## Small-Size Reduction

| Option | Description | Selected |
| --- | --- | --- |
| Purpose-built favicon reduction | Separately draw 16/32 icon reduction, plus SVG/ICO/PNG exports. | x |
| Full PWA icon pack | Apple touch, Android, maskable icons, manifest-size family. | |
| SVG-only favicon | Minimal SVG without ICO/PNG fallback. | |

**User's choice:** Discuss all; Claude to recommend.

**Notes:** Recommendation is a dedicated optical reduction: compact ring, two flattened stones, no
extra detail. Full PWA pack is over-scoped and fights the raster budget.

---

## OG/Social Card

| Option | Description | Selected |
| --- | --- | --- |
| Quiet logo-only | Clean brand proof, weak explanatory power. | |
| Tagline-led | Memorable but ambiguous without context. | |
| Product-positioned | Clear utility, risks generic marketing if overdone. | |
| Hybrid | Mark + wordmark + concise product line + optional secondary tagline. | x |

**User's choice:** Discuss all; Claude to recommend.

**Notes:** Recommendation is a hybrid card: `cairnloop`, C3.6 mark, "Embedded support automation for
Phoenix apps.", optional smaller "Support that leaves a trail." Use solid brand background and safe
zone.

---

## Usage Rules Strictness

| Option | Description | Selected |
| --- | --- | --- |
| Lightweight narrative guidance | Friendly but too vague for preventing visual drift. | |
| Strict brand-rule manual | Protective but too corporate/heavy for this OSS library. | |
| Tokenized + diagrammatic guidance | Concise policy plus measurable diagrams and do/don't panels. | x |

**User's choice:** Discuss all; Claude to recommend.

**Notes:** Recommendation is concise and measurable: clearspace, min-size table, approved asset usage,
light/dark examples, and explicit do/don't panels. This gives Phase 51 renderable content without an
enterprise-heavy brand manual.

---

## Claude's Discretion

- Exact SVG path geometry, optical spacing, export commands, and final file naming may be refined by
  the planner/executor while preserving the decisions in `49-CONTEXT.md`.
- If implementation constraints reveal a better lightweight export layout, use it, but avoid adding
  heavyweight design/build tooling.

## Deferred Ideas

- Phase 52: README/example-app wiring and gated rendered-behavior verification.
- Phase 50/51: `brandbook/` scaffold and rendered HTML brand book.
- Future: PWA/app-icon pack, animated logo, slide/sticker/swag collateral.
