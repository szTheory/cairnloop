# Phase 29: Brand-Token CSS Extraction (D-10 Closure) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 29-brand-token-css-extraction-d-10-closure
**Areas discussed:** BRAND-02/04 file scope, BRAND-03 assertion count

---

## BRAND-02/04 File Scope

Codebase scan found 3 web source files with inline hex fallbacks — but REQUIREMENTS.md only named 2 in BRAND-02. The BRAND-04 gate runs on the full `lib/cairnloop/web/` directory, creating a conflict: cleaning only 2 files would cause the gate to fail on the third.

| Option | Description | Selected |
|--------|-------------|----------|
| Clean all 3 files | `inbox_live.ex` (10) + `conversation_live.ex` (7) + `search_modal_component.ex` (5) = 22 total drops. Gate passes cleanly. | ✓ |
| Narrow gate to 2 files | Scope BRAND-04 grep to only `inbox_live.ex` + `conversation_live.ex`. Leaves `search_modal_component.ex` dirty. | |

**User's choice:** Create context (accepted recommendation — clean all 3 files)
**Notes:** Recommendation was decisive: the gate specification covers `lib/cairnloop/web/` precisely to enforce the full surface. Partial cleanup creates a permanent exception and a weaker contract.

---

## BRAND-03 Assertion Count

REQUIREMENTS.md stated 5 assertions in `inbox_live_test.exs`, `conversation_live_test.exs`, and integration files. Actual grep found 0 assertions in those first two test files; all 5 primary (`--cl-primary, #A94F30`) are in integration tests. A 6th assertion (`--cl-danger, #B54C36`) was also found in `bulk_recovery_live_test.exs`.

| Option | Description | Selected |
|--------|-------------|----------|
| Re-pin all 6 assertions | 5 primary + 1 danger. Test suite stays green; gate contract is complete. | ✓ |
| Re-pin only 5 primary | Matches literal BRAND-03 spec. `bulk_recovery_live_test.exs:267` breaks after `inbox_live.ex` drops `--cl-danger` fallback. | |

**User's choice:** Create context (accepted recommendation — re-pin all 6)
**Notes:** Requirements.md had an error in the listed test file paths (inbox/conversation unit test files have no hex assertions). Planning agent should use the corrected file list from CONTEXT.md D-03.

---

## Claude's Discretion

- **BRAND-01 `@theme` extension scope** — Decided: 15 primitive color tokens in `@theme` only (matching existing 4-token pattern), semantic/typography/spacing tokens stay in `:root`. Not discussed with user — clear from existing pattern and phase goal.
- **BRAND-04 gate mechanism** — Decided: ExUnit test in the headless `mix test` lane using `System.cmd/2`. Consistent with existing headless test convention; no new deps.
- **Dark theme block placement** — Decided: include the `[data-theme="dark"]` overrides from `cairnloop.css` alongside the `:root` block in `app.css`. Required for brand completeness; obvious from the source file.

## Deferred Ideas

None — discussion stayed within phase scope.
