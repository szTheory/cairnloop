# Phase 50: Brandbook Scaffold & Token-Derivation Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-25
**Phase:** 50-brandbook-scaffold-token-derivation-pipeline
**Areas discussed:** Token derivation method, Swatch JSON shape, Scaffold proof content, Verification strictness

---

## Token Derivation Method

| Option | Description | Selected |
|--------|-------------|----------|
| Repo-local Elixir script | `mix run scripts/derive_brandbook_tokens.exs`; generated outputs plus `--check`; unshipped helper. | ✓ |
| Custom Mix task | Best command ergonomics and idiomatic `mix help`, but likely shipped from `lib/mix/tasks`. | |
| POSIX shell extraction | Small and transparent, but brittle across CSS shape, JSON output, and macOS/GNU differences. | |
| Documented manual mirror | Smallest immediate change, but weak provenance and high drift risk. | |
| Style Dictionary / Node pipeline | Mature multi-platform token tooling, but overbuilt and adds dependency surface for Phase 50. | |

**User's choice:** Discuss all areas, research deeply with subagents, and produce cohesive recommendations.
**Notes:** Recommendation selected the Elixir script because it matches Phoenix/Elixir DX while preserving
package hygiene and avoiding a new token platform.

---

## Swatch JSON Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal rows | Token/value only; fastest, but too little structure for Phase 51. | |
| Grouped primitive/semantic rows | File-level provenance plus `primitive`, `semantic_light`, `semantic_dark` rows with lean metadata. | ✓ |
| Rich contrast/provenance rows | Most self-documenting, but overbuilds BOOK-01/BOOK-02 and risks stale metadata. | |

**User's choice:** Discuss all areas and make expert recommendations.
**Notes:** Recommendation keeps `swatches.json` useful for Phase 51 without making it a contrast engine or
fourth palette source.

---

## Scaffold Proof Content

| Option | Description | Selected |
|--------|-------------|----------|
| Bare folder/status proof | Lowest scope, but looks like internal plumbing and under-proves token usefulness. | |
| Compact professional shell | Title/provenance, status cells, token chips, type samples, light/dark proof, folder map. | ✓ |
| Rich Phase 51 preview | Strong first impression, but blurs full brandbook assembly into Phase 50. | |

**User's choice:** Discuss all areas and make expert recommendations.
**Notes:** Recommendation preserves Phase 50's scaffold boundary while giving maintainers and OSS inspectors
a credible artifact that proves local loading and token availability.

---

## Verification Strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Automated `file://` browser check plus source greps | Proves console/network/local path behavior directly without app wiring. | ✓ |
| PhoenixTest/Playwright through example app | Reuses existing E2E lane, but requires serving brandbook and blurs the package boundary. | |
| Mostly source checks plus smoke note | Lowest overhead, but misses real browser failures and conflicts with no-human-UAT policy. | |

**User's choice:** Discuss all areas and make expert recommendations.
**Notes:** Recommendation requires a focused Playwright `file://` proof and source greps, but does not
casually expand CI or route the brandbook through Phoenix.

---

## Claude's Discretion

- Exact Elixir script structure and parser implementation.
- Exact stable ordering and field names in generated `swatches.json`, within the grouped schema.
- Exact scaffold CSS class names and layout details, within the locked UI-SPEC.
- Exact Playwright harness location, as long as it proves `file://` console/network behavior without app/package coupling.

## Deferred Ideas

- Public Mix task for package consumers.
- Style Dictionary or broader multi-platform token tooling.
- Full Phase 51 brand book assembly and Phase 52 collateral wiring.
