# Phase 48 — Contrast Re-Verification

**Produced:** 2026-06-24
**Baseline:** `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`
**Method:** WCAG 2.x relative-luminance algorithm, matching `test/cairnloop/web/token_drift_test.exs`.
**Canonical tokens:** `priv/static/cairnloop.css`

Selected palette: Refined
Selected type: current stack
Canonical source: priv/static/cairnloop.css :root
Derivative status: zero drift
Contrast status: AA re-verified
Logo assets remain Phase 49

Dark warning/primary equality: intentional. In dark mode `--cl-warning` and `--cl-primary` both resolve to
`#D98A4A`; warning states still carry text/icon meaning through `--cl-warning-text` on
`--cl-warning-surface`, and route-marker use remains distinguishable by placement, text, and active-state
structure rather than color alone.

## Summary

| Category | Count | Result |
| --- | ---: | --- |
| AA text passes checked in this reverify | 8 | PASS |
| UI/large passes checked in this reverify | 8 | PASS |
| Resolved real Phase 46 failures | 3 | Rows 13 dark, 14 light, and 22 light now pass |
| Fragile Phase 46 pass hardened | 1 | Row 4 light increased from 4.52 to 5.14 |
| Decorative border classifications | 11 | Row 25 light and rows 28a-e light/dark |
| Remaining remediation rows | 0 | No meaningful text or required UI boundary remains below threshold |

## Re-Verified Text Rows

| Baseline row | Pairing | FG token | FG hex | BG token | BG hex | Theme | Ratio | Threshold | Verdict | Phase 48 evidence |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| Row 4 | Muted/secondary text on canvas | `--cl-text-muted` | `#5E665D` | `--cl-bg` | `#F4EEE2` | Light | 5.14 | 4.5 | PASS | Hardened from fragile 4.52 baseline by refined muted text. |
| Row 4 | Muted/secondary text on canvas | `--cl-text-muted` | `#B7C0B2` | `--cl-bg` | `#101614` | Dark | 9.76 | 4.5 | PASS | No remediation needed. |
| Row 13 | Danger button text on danger | `--cl-danger-button-text` | `#FFFFFF` | `--cl-danger` | `#B54C36` | Light | 5.18 | 4.5 | PASS | Additive button text token preserves existing light behavior. |
| Row 13 | Danger button text on danger | `--cl-danger-button-text` | `#141B19` | `--cl-danger` | `#C96A55` | Dark | 4.73 | 4.5 | PASS | Remediates Phase 46 dark white-on-danger failure via additive token. |
| Row 14 | Ghost/nav muted text on sunken | `--cl-text-muted` | `#5E665D` | `--cl-surface-sunken` | `#EFE9DC` | Light | 4.91 | 4.5 | PASS | Remediates Phase 46 light muted-on-sunken failure. |
| Row 14 | Ghost/nav muted text on sunken | `--cl-text-muted` | `#B7C0B2` | `--cl-surface-sunken` | `#0C110F` | Dark | 10.15 | 4.5 | PASS | No remediation needed. |
| Row 22 | Neutral chip text on neutral surface | `--cl-neutral-text` | `#5E665D` | `--cl-neutral-surface` | `#EFEADF` | Light | 4.95 | 4.5 | PASS | Remediates Phase 46 light neutral chip text failure. |
| Row 22 | Neutral chip text on neutral surface | `--cl-neutral-text` | `#B7C0B2` | `--cl-neutral-surface` | `#1C2622` | Dark | 8.30 | 4.5 | PASS | No remediation needed. |

## Re-Verified Border And UI Rows

| Baseline row | Pairing | FG token | FG hex | BG token | BG hex | Theme | Ratio | Threshold | Classification | Verdict |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| Row 24 | Quiet border on canvas | `--cl-border` | `#8E8068` | `--cl-bg` | `#F4EEE2` | Light | 3.34 | 3.0 | Meaningful boundary capable | PASS |
| Row 24 | Quiet border on raised input/button surface | `--cl-border` | `#8E8068` | `--cl-surface-raised` | `#FFFFFF` | Light | 3.86 | 3.0 | Meaningful input/button boundary | PASS |
| Row 24 | Quiet border on surface | `--cl-border` | `#8E8068` | `--cl-surface` | `#FAF5EB` | Light | 3.55 | 3.0 | Decorative separator, still passes | PASS |
| Row 24 | Quiet border on dark canvas | `--cl-border` | `#5B7066` | `--cl-bg` | `#101614` | Dark | 3.45 | 3.0 | Meaningful boundary capable | PASS |
| Row 25 | Strong border on surface hover | `--cl-border-strong` | `#BFB6A2` | `--cl-surface` | `#FAF5EB` | Light | 1.85 | 3.0 | Decorative hover reinforcement; base boundary is Row 24 | EXEMPT |
| Row 25 | Strong border on dark surface hover | `--cl-border-strong` | `#627A6E` | `--cl-surface` | `#141B19` | Dark | 3.77 | 3.0 | Meaningful hover boundary capable | PASS |
| Row 29 | Focus ring on surface | `--cl-focus` | `#A8492A` | `--cl-surface` | `#FAF5EB` | Light | 5.29 | 3.0 | Meaningful focus indicator | PASS |
| Row 29 | Focus ring on surface | `--cl-focus` | `#D98A4A` | `--cl-surface` | `#141B19` | Dark | 6.40 | 3.0 | Meaningful focus indicator | PASS |

## Status Chip Border Classifications

Rows 28a-e are decorative chip outlines. Status meaning is carried by text plus icon and, where
applicable, visible status copy; the border is not the sole identifier for the component or state.

| Baseline row | Pairing | FG token | FG hex | BG token | BG hex | Theme | Ratio | Threshold | Classification | Verdict |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| Row 28a | Success chip border on success surface | `--cl-success-border` | `#C9D3A6` | `--cl-success-surface` | `#EDF1E2` | Light | 1.37 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28b | Info chip border on info surface | `--cl-info-border` | `#B7CDD4` | `--cl-info-surface` | `#DDE8E3` | Light | 1.32 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28c | Warning chip border on warning surface | `--cl-warning-border` | `#E3C9A0` | `--cl-warning-surface` | `#F6ECDD` | Light | 1.37 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28d | Danger chip border on danger surface | `--cl-danger-border` | `#E3B6AC` | `--cl-danger-surface` | `#F6E3DE` | Light | 1.47 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28e | AI chip border on AI surface | `--cl-ai-border` | `#CDB6CB` | `--cl-ai-surface` | `#ECE4EB` | Light | 1.51 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28a | Success chip border on success surface | `--cl-success-border` | `#38492E` | `--cl-success-surface` | `#1E2A1C` | Dark | 1.54 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28b | Info chip border on info surface | `--cl-info-border` | `#2E4750` | `--cl-info-surface` | `#16252A` | Dark | 1.60 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28c | Warning chip border on warning surface | `--cl-warning-border` | `#4A3A22` | `--cl-warning-surface` | `#2A2014` | Dark | 1.46 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28d | Danger chip border on danger surface | `--cl-danger-border` | `#4A302A` | `--cl-danger-surface` | `#2A1A16` | Dark | 1.39 | 3.0 | Decorative status-chip outline | EXEMPT |
| Row 28e | AI chip border on AI surface | `--cl-ai-border` | `#433A48` | `--cl-ai-surface` | `#241E29` | Dark | 1.50 | 3.0 | Decorative status-chip outline | EXEMPT |

## Copper Route-Marker Rows

| Baseline row | Pairing | FG token | FG hex | BG token | BG hex | Theme | Ratio | Threshold | Verdict |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- |
| CU-L-3 | Copper route-marker on canvas — UI/large role | `--cl-color-path-copper` | `#A8492A` | `--cl-bg` | `#F4EEE2` | Light | 4.98 | 3.0 | PASS |
| CU-L-4.5 | Copper route-marker on canvas — text role | `--cl-color-path-copper` | `#A8492A` | `--cl-bg` | `#F4EEE2` | Light | 4.98 | 4.5 | PASS |
| CU-D-3 | Dark copper route-marker on canvas — UI/large role | `--cl-primary` | `#D98A4A` | `--cl-bg` | `#101614` | Dark | 6.70 | 3.0 | PASS |
| CU-D-4.5 | Dark copper route-marker on canvas — text role | `--cl-primary` | `#D98A4A` | `--cl-bg` | `#101614` | Dark | 6.70 | 4.5 | PASS |

## Automated Verifier Alignment

The focused verifier `token_drift_test` pins the same meaningful remediation rows:

- Row 4 light: `--cl-text-muted` on `--cl-bg` must pass 4.5.
- Row 13 light/dark: `--cl-danger-button-text` on `--cl-danger` must pass 4.5.
- Row 14 light: `--cl-text-muted` on `--cl-surface-sunken` must pass 4.5.
- Row 22 light: `--cl-neutral-text` on `--cl-neutral-surface` must pass 4.5.
- Row 24 light and Row 25 dark: meaningful input/hover boundaries must pass 3.0.
- Row 29 light/dark and CU-L/CU-D route-marker rows must pass their 3.0 or 4.5 thresholds.

Ratios above are rounded to two decimals from the same relative-luminance formula used by the test.
