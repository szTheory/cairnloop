# Phase 51: Full HTML Brand Book Assembly - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-25
**Phase:** 51-full-html-brand-book-assembly
**Areas discussed:** Document flow, Data/automation, Verification

---

## Document Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Single long page with sticky desktop nav | Best fit for an offline `file://` reference; all brand decisions inspectable in one artifact; needs careful mobile anchor and table handling. | yes |
| Simple anchored contents only | Most robust without JavaScript, but weaker for scanning a long mature reference document. | |
| Progressive disclosure sections | Useful for secondary provenance, but risky for core rules because find-in-page, print, and scan behavior suffer. | |
| Generated multi-page docs | Scales for public design-system docs, but adds routing/tooling complexity and conflicts with Phase 51's standalone artifact. | |

**User's choice:** Discuss all and let research-backed recommendations produce a cohesive direction.
**Notes:** Research recommendation: one ordered long page with sticky desktop in-page nav, static
mobile contents, and progressive disclosure only for secondary provenance/regeneration notes.

---

## Data/Automation

| Option | Description | Selected |
|--------|-------------|----------|
| Mostly hand-authored static HTML | Very reviewable and robust, but high drift risk across token, contrast, logo, and copy tables. | |
| Runtime JS reads local CSS/JSON | Helpful for nonessential enhancement, but `file://` JSON fetch is browser-fragile and can blank required sections. | |
| Repo-local Elixir generator/check script | Matches Phase 50 `mix run` pattern, deterministic, no new runtime dependency, emits plain static HTML. | yes |
| Node/design-token/docs platform | Mature for larger design systems, but adds dependency/tooling churn and conflicts with CSS as canonical token source. | |

**User's choice:** Discuss all and choose the one-shot recommendation.
**Notes:** Research recommendation: generate/check essential content at build time with repo-local
Elixir tooling; use tiny local JavaScript only for the theme toggle and nonessential enhancement.

---

## Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Manual smoke test | Cheap but false-pass prone and not acceptable for browser-required facts. | |
| Static ExUnit/source checks | Deterministic and idiomatic for source, package, token, inventory, and forbidden dependency checks. | yes |
| Token/generated-content checks | Prevents drift in `tokens.css`, `swatches.json`, contrast evidence, and logo/download inventory. | yes |
| Focused Playwright `file://` script | Proves browser-only behavior: console/network silence, theme toggle, focus, assets, and responsive smoke. | yes |
| Axe-core automated a11y scan | Useful first-line check but incomplete WCAG sign-off and adds dependency cost. | |
| Visual screenshot/pixel checks | Useful for targeted blank/clipping/theme checks; broad visual baselines are brittle. | partial |
| CI integration | Useful if scoped; risky if it slows unrelated Elixir release gates for unshipped collateral. | partial |

**User's choice:** Discuss all and choose a rigorous but pragmatic gate.
**Notes:** Research recommendation: layered gate with static ExUnit/source checks plus an extended
Playwright `file://` script. Use targeted geometry/pixel sanity checks, not broad screenshot diffs.
Defer axe-core unless the planner explicitly accepts the dependency and maintenance cost.

---

## Claude's Discretion

- Exact generator structure, parsing helpers, CSS class names, HTML formatting, and verification
  helper boundaries are planner/executor discretion.
- Keep generated output deterministic, data-first, and easy to review.

## Deferred Ideas

- Generated multi-page docs, hosted docs, search, versioned routes, print/PDF export, component
  playgrounds, analytics, and full-text filtering.
- Style Dictionary, Storybook, Docusaurus, zeroheight-style workflows, public Mix tasks, and a new
  design-token schema.
- README, example-app, favicon, OG, HexDocs, Phoenix route, and package metadata wiring.
- Broad screenshot visual-diff baselines and axe-core gating unless later accepted explicitly.
