---
phase: 29
slug: brand-token-css-extraction-d-10-closure
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-27
---

# Phase 29 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Source file → build output | CSS token block verbatim-copied from `prompts/cairnloop.css` (checked-in source artifact) into `examples/cairnloop_example/assets/css/app.css` | Static string literals only; no user input, no runtime config, no network traffic, no persisted data |
| Render source → compiled BEAM | Hex-fallback strings replaced with bare var() references in 4 LiveView/LiveComponent files | Byte-replacement of source-code string literals; no dynamic interpolation |
| Test assertions → ExUnit | Integration test assertion literals re-pinned from `var(--cl-<token>, #hex)` to `var(--cl-<token>)` | Test-only file edits; no production surface |

This phase introduced **no new trust boundaries**. All changes are static source-code substitutions.

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-29-01-V14 | Tampering | `app.css` configuration drift between `prompts/cairnloop.css` and the example app | mitigate | Verbatim copy per D-04; 15-token count cross-checked in acceptance_criteria (SUMMARY-01 confirms "15 acceptance criteria verified", commit `f979b89`); BRAND-04 gate test (Plan 02) prevents re-introduction of hex fallbacks. | closed |
| T-29-01-CSS | Spoofing | Visual spoofing via brand-token misalignment (e.g., success-colored danger button) | accept | Out of scope for Plan 01 — `app.css` only defines tokens; render-site usage governed by Plan 02 and existing never-color-alone tests. See Accepted Risks Log. | closed |
| T-29-01-SC | Tampering | Supply chain (npm/pip/cargo installs) | n/a | No new packages installed; no install surface to audit. | closed |
| T-29-02-V14 | Tampering | Re-introduction of hex fallbacks in sealed render code (regression) | mitigate | BRAND-04 gate test at `test/cairnloop/web/brand_token_gate_test.exs` runs in default `mix test` lane and fails the build on any `var(--cl-<token>, #<hex>)` re-appearing in `lib/cairnloop/web/` or example app live dirs. | closed |
| T-29-02-Sealed | Tampering | Sealed render code semantic drift during hex-drop edits | mitigate | Tasks 2–5 enforce byte-for-byte preservation of every non-fallback construct: module heads, `use` directives, `def`/`defp`, `handle_event`/`handle_info`, assigns keys, render structure. `mix compile --warnings-as-errors` per task. Existing per-file tests continued to pass. | closed |
| T-29-02-Render | Spoofing | Visual misalignment after hex drop (e.g., `--cl-on-primary` unresolved → button text invisible) | mitigate | `--cl-on-primary: var(--cl-primary-text);` alias added in `:root` (Pitfall 3); `--cl-error` renamed to `--cl-danger` (Pitfall 6) so example app's danger color resolves correctly. | closed |
| T-29-02-SC | Tampering | Supply chain (npm/pip/cargo installs) | n/a | No new packages installed; no install surface to audit. | closed |
| T-29-03-Strict | Tampering | Loss of test strictness (admitting hex-fallback regressions silently) | mitigate | Pitfall 8 mandates closing parenthesis in every re-pinned literal: `"var(--cl-primary)"` not `"var(--cl-primary"`. Acceptance_criteria assert closing-paren form present AND prefix-only form absent, keeping tests strict against `"var(--cl-primary, #foo)"` re-introduction. | closed |
| T-29-03-Spoof | Spoofing | Never-color-alone contract weakening (token swap without text-label cross-check) | accept | Brand §7.5 enforcement unchanged. Each re-pinned assertion still appears alongside the corresponding text-label or icon assertion at the same call site. Acceptance_criteria explicitly assert surrounding assertions are preserved. See Accepted Risks Log. | closed |
| T-29-03-SC | Tampering | Supply chain (npm/pip/cargo installs) | n/a | No new packages installed; no install surface to audit. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party) · n/a (not applicable)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-29-01 | T-29-01-CSS | Visual spoofing via brand-token misalignment is out of scope for Plan 01 (which only defines tokens, not render-site usage). Render-site enforcement is governed by Plan 02 (hex-fallback drops) and the pre-existing never-color-alone test suite. Re-evaluate if render-site token usage is refactored outside Phase 29. | gsd-security-auditor / orchestrator | 2026-05-27 |
| AR-29-02 | T-29-03-Spoof | Never-color-alone contract weakening risk is accepted because re-pinned test assertions retain all surrounding text-label and icon assertions per acceptance_criteria; the BRAND §7.5 contract is unchanged in the passing test suite. | gsd-security-auditor / orchestrator | 2026-05-27 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-27 | 10 | 10 | 0 | gsd-secure-phase (short-circuit: register_authored_at_plan_time=true, threats_open=0) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer / n/a)
- [x] Accepted risks documented in Accepted Risks Log (AR-29-01, AR-29-02)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-27
