# Phase 52: Collateral Wiring + QA/Validation Sweep - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-26
**Phase:** 52-collateral-wiring-qa-validation-sweep
**Areas discussed:** Logo sign-off precondition, README header treatment, example app metadata wiring, QA gate shape

---

## Logo Sign-Off Precondition

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve explicit sign-off gate | Treat subjective logo-family approval as the only pre-wiring human gate; implementation waits until sign-off is recorded. | ✓ |
| Assume sign-off from completed assets | Let planners proceed directly because Phase 49 and 51 assets exist. | |
| Add post-implementation human UAT | Ask owner to visually inspect rendered README/app behavior after wiring. | |

**User's choice:** Discuss and consider all areas with research-backed recommendations so the user does not need to arbitrate.
**Notes:** Recommendation keeps the subjective owner gate, then requires automated implementation verification only.

---

## README Header Treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Restrained OSS logo header | First visible README line is approved horizontal SVG with `alt="Cairnloop"`; badges stay below; install/docs stay near top. | ✓ |
| Product-marketing hero | Larger launch-style README with expanded brand copy and visual storytelling. | |
| Brandbook-forward README | Surface brandbook/design-system maturity prominently in README. | |

**User's choice:** User asked for the most cohesive recommendation considering OSS DX, design, JTBD, and brand.
**Notes:** Research favored restrained collateral wiring: credible brand signal without burying install/docs or implying the brandbook ships.

---

## Example App Metadata Wiring

| Option | Description | Selected |
|--------|-------------|----------|
| Approved collateral with Phoenix-native static paths | Copy approved favicon/OG/logo assets into example `priv/static`, reference from root layout, no new asset-serving abstraction. | ✓ |
| Light README-only metadata | Improve repo first impression but leave example browser chrome mostly generated. | |
| Full example-app rebrand | Rework example app as a polished standalone demo product. | |
| Library-served assets | Centralize branding in the library package or a new Plug/static delivery layer. | |

**User's choice:** User asked for idiomatic Elixir/Phoenix recommendations with least surprise and strong DX.
**Notes:** Research favored example-app-owned static assets and root-layout metadata. Avoid over-branding the example as a SaaS product.

---

## QA Gate Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Static ExUnit/source guards | Fast deterministic checks for README path, SVG hygiene, raster budget, package files, and brandbook/package boundary. | ✓ |
| Dedicated script/Mix validator | Centralized report-oriented validator for awkward asset/package checks. | |
| Gated PhoenixTest Playwright E2E | Real browser proof for logo rendering and favicon/OG static paths. | ✓ |
| CI summary evidence only | Human-readable release evidence without hard assertions. | |

**User's choice:** User asked for SRE/devops/software-engineering lens and strong false-pass prevention.
**Notes:** Recommendation is a hybrid: ExUnit for deterministic gates, one focused E2E for browser-only facts, and summary evidence generated from passing gates.

---

## Claude's Discretion

- Exact copied asset filenames under example `priv/static`.
- Exact ExUnit module split and helper shape.
- Whether to extend existing brandbook source/package tests or create a Phase 52 collateral test.
- Exact Playwright selectors, as long as tests assert real rendered/static-path behavior and include anti-false-pass preconditions.

## Deferred Ideas

- Full marketing landing page or screenshot-led public launch treatment.
- Shipping `logo/` or `brandbook/` in the Hex package.
- Reusable branded asset Plug/API.
- Full PWA/apple-touch/android icon pack.
