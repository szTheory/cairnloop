---
phase: 52
slug: collateral-wiring-qa-validation-sweep
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-26T03:48:38Z
---

# Phase 52 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| repo collateral -> GitHub README renderer | Committed SVG and Markdown are interpreted by GitHub and developer browsers. | Public brand SVG path and README HTML. |
| repo collateral -> Hex package build | `mix.exs` package files decide which collateral becomes shipped package payload. | Source-only brandbook/logo/script collateral must remain unshipped. |
| `logo/` source assets -> example app static tree | Approved repo collateral becomes browser-served public files. | Public logo, favicon, and OG image assets. |
| HEEx root layout -> browser/social crawlers | Metadata and favicon paths are interpreted by real browsers and preview agents. | Public favicon and OG metadata. |
| automated gates -> release confidence | QA report must reflect command results rather than replace failing tests. | Test, package, raster, SVG, and diff evidence. |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-52-01 | Tampering | tracked SVG files | mitigate | `Cairnloop.Web.CollateralWiringTest` scans all tracked SVGs and blocks script, `foreignObject`, raster embeds, external/data/active hrefs, inline handlers, and editor metadata; `xmllint` passed. | closed |
| T-52-02 | Information Disclosure | README logo source | mitigate | README uses repo-relative `logo/cairnloop-lockup-horizontal.svg`; focused guard rejects remote, root-relative, `file://`, and data URL logo sources. | closed |
| T-52-03 | Spoofing | README brand identity | mitigate | README guard asserts approved path and exact accessible name `Cairnloop`; old emoji identity is absent. | closed |
| T-52-04 | Repudiation | sign-off gate | mitigate | `52-LOGO-FAMILY-SIGNOFF.md` records subjective approval before collateral edits. | closed |
| T-52-05 | Information Disclosure | Hex package allowlist | mitigate | Static guard and Hex unpack proof confirm `brandbook/`, `logo/`, and `scripts/` are absent from the package. | closed |
| T-52-06 | Spoofing | example app visible logo | mitigate | Approved lockup is copied into the example app; source guard and E2E assert accessible name plus nonzero rendered/natural dimensions. | closed |
| T-52-07 | Information Disclosure | favicon and OG metadata | mitigate | Root layout uses local Phoenix static paths only; source guard and E2E verify local links and successful fetches. | closed |
| T-52-08 | Tampering | copied SVG favicon and logo | mitigate | Copied SVGs are included in the all-tracked-SVG XML and safe-subset checks. | closed |
| T-52-09 | Repudiation | browser verification | mitigate | E2E includes connected-page, DOM geometry, natural image, metadata, and asset-fetch preconditions. | closed |
| T-52-10 | Denial of Service | example static path config | accept | No new routes, Plugs, or static path entries were added; existing `images` and root `favicon.ico` paths serve the needed files. | closed |
| T-52-11 | Tampering | all tracked SVGs | mitigate | Final sweep records `xmllint` and the hardened safe-subset guard. | closed |
| T-52-12 | Information Disclosure | package build output | mitigate | `mix hex.build --unpack` output was inspected; unshipped collateral directories are absent. | closed |
| T-52-13 | Spoofing | wired brand surfaces | mitigate | Final source and E2E gates prove README, app logo, favicon, and OG metadata use approved Phase 49 assets. | closed |
| T-52-14 | Repudiation | QA report | mitigate | `52-QA-REPORT.md` records command evidence only after passing gates; review fixes refreshed the final counts. | closed |
| T-52-15 | Denial of Service | browser-rendered collateral | mitigate | Full E2E lane catches collateral-caused request/page/asset failures before closeout. | closed |
| T-52-16 | Spoofing | contrast evidence | mitigate | Final sweep records `mix test test/cairnloop/web/token_drift_test.exs` for TOKEN-04 contrast rows. | closed |
| T-52-SC | Tampering | npm/pip/cargo installs | mitigate | No dependency or package-manager install tasks were introduced; diff scope contains no lockfile/package-manager churn. | closed |

*Status: open / closed*
*Disposition: mitigate (implementation required) / accept (documented risk) / transfer (third-party)*

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-52-01 | T-52-10 | Reusing existing example app static paths avoids new route/Plug/static service surface area; validated by source guard and E2E fetch checks. | the agent | 2026-06-26 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-26 | 17 | 17 | 0 | the agent |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-26
