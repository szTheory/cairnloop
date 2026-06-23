# Phase 40: Drift Remediation + Brand-Token Gate Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 40-Drift Remediation + Brand-Token Gate Hardening
**Areas discussed:** rgba/translucent token strategy (search_modal)

**Discussion mode:** Shift-left (CLAUDE.md decision policy + minimal_decisive calibration). Phase
40 is heavily pre-decided by its Success Criteria and REQUIREMENTS (DRIFT-01/02, GATE-01/02), so
the orchestrator auto-decided everything resolvable and surfaced exactly **one** genuinely
discretionary, brand/shipped-API-impacting call to the owner.

---

## rgba / translucent token strategy (search_modal)

`search_modal_component.ex` is built on a translucent "glass" aesthetic (~15 `rgba()` values:
white-alpha panels, 5 basalt text-opacity steps, olive/slate-blue chip tints). The shipped palette
has no alpha/tint tokens. GATE-01 forces raw `rgba()` out of render files, so these must resolve to
tokens — *how* changes both the visual result and the shipped public token surface.

| Option | Description | Selected |
|--------|-------------|----------|
| Snap to solid tokens | Map rgba → nearest existing solid tokens; panels → `--cl-surface-raised`; 5 text-alpha steps collapse to `--cl-text`/`-muted`/`-soft`; chip tints reuse semantic surfaces. No palette expansion. Search becomes consistent with the rest of the cockpit. Loses the frosted-glass look. | ✓ |
| Add alpha/tint tokens | Extend `cairnloop.css` with ~6 new alpha tokens (`--cl-surface-translucent`, `--cl-text-faint`, `--cl-primary-tint`, etc.) for light + dark. Preserves glass; expands shipped public token surface for ~one screen; more dark-mode tuning. | |

**User's choice:** Snap to solid tokens (the recommended option).
**Notes:** Owner confirmed Search should match the Inbox/Home solid-surface treatment rather than
preserve a one-off glass aesthetic. Palette stays at 140 tokens; zero churn to the shipped CSS API.
Alpha-token family deferred (see CONTEXT Deferred Ideas) in case a future glassmorphism direction
warrants a deliberate palette expansion.

---

## Claude's Discretion (auto-decided, recorded in CONTEXT.md)

- **Hex→token map (D-02):** Applied as documented in SC1; ambiguous text-tier choices left to planner within the existing palette.
- **Footer rebuild (D-03):** `cl_button` variants + `.cl-textarea`; inline-layout `style=` → existing `.cl-` utilities (DRIFT-02).
- **Gate hardening (D-04/05/06):** Extend the existing `brand_token_gate_test.exs`; full-source `#`-anchored scan catches inline-style hex, raw rgba/hsl, and helper-returned hex; **magic-comment allowlist included per GATE-01**; `.css` stays unscanned; ExUnit gate is CI source of truth.
- **Credo check (D-07):** Custom `Credo.Check` module wired into `.credo.exs`, complementary/advisory; ExUnit authoritative.

## Deferred Ideas

- Alpha/tint token family — rejected for this phase; revisit only as a deliberate future palette expansion.
- Drift remediation in render files beyond the two named surfaces — the hardened gate will surface them for a follow-up sweep.
