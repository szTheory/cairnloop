# Phase 29: Brand-Token CSS Extraction (D-10 Closure) - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Land the canonical `cairnloop.css` `:root` block as the single source of truth for the example app; drop ALL `var(--cl-<token>, #hex)` inline fallback strings from `lib/cairnloop/web/` (all three files: `inbox_live.ex`, `conversation_live.ex`, `search_modal_component.ex`); re-pin all 6 affected test assertions (5 `--cl-primary` + 1 `--cl-danger`); add a negative-grep gate in the test lane that fails the build if any hex fallback survives. D-10 closure via **Option B** (drop fallback) — NOT Option A (named-class migration).

</domain>

<decisions>
## Implementation Decisions

### BRAND-02 scope (GA-1 resolution)

- **D-01:** BRAND-02 cleans **all three** web source files, not just the two named in REQUIREMENTS.md. The BRAND-04 gate scans the full `lib/cairnloop/web/` directory; leaving `search_modal_component.ex`'s 5 fallbacks would cause the gate to fail. Files and counts:
  - `lib/cairnloop/web/inbox_live.ex` — 10 hex fallbacks
  - `lib/cairnloop/web/conversation_live.ex` — 7 hex fallbacks
  - `lib/cairnloop/web/search_modal_component.ex` — 5 hex fallbacks
  - **Total: 22 fallback instances across 3 files.** All drop to bare `var(--cl-<token>)` form.
- **D-02:** Drop = delete the `, #hex` fallback suffix only. No structural change to the `style=` attributes, no reordering, no extraction to classes. Sealed render code is NOT churned.

### BRAND-03 assertion scope (GA-2 resolution)

- **D-03:** Re-pin **all 6** hex-fallback assertions, not just the 5 named in REQUIREMENTS.md. Actual locations:
  - `test/integration/approval_footer_live_test.exs:52` — `var(--cl-primary, #A94F30)` → `var(--cl-primary)`
  - `test/integration/tool_execution_outcome_live_test.exs:316,394,443` — same (3 occurrences)
  - `test/integration/bulk_recovery_live_test.exs:99` — `var(--cl-primary, #A94F30)` → `var(--cl-primary)`
  - `test/integration/bulk_recovery_live_test.exs:267` — `var(--cl-danger, #B54C36)` → `var(--cl-danger)`
  - **Note:** `test/cairnloop/web/inbox_live_test.exs` and `test/cairnloop/web/conversation_live_test.exs` have ZERO hex-fallback assertions — no changes needed in those files. REQUIREMENTS.md was wrong about their location.

### BRAND-01 — `app.css` and `@theme` extension

- **D-04:** Copy the full `:root` block from `prompts/cairnloop.css` (15 primitive color tokens + 14 semantic tokens + typography + spacing/radius/shadow) into `examples/cairnloop_example/assets/css/app.css` inside `@layer base { :root { … } }`.
- **D-05:** The `@theme` block extends with the **15 primitive color tokens only**, using Tailwind v4's `--color-cl-{name}` naming convention (matches the 4-token pattern already present). This generates `bg-cl-basalt`, `text-cl-trailpaper`, etc. utility classes for adopter use. Semantic tokens (`--cl-bg`, `--cl-primary`, etc.) stay in `:root` as CSS custom properties — not in `@theme`. No typography or spacing/radius tokens in `@theme` (not needed for Tailwind utility generation at this phase).
- **D-06:** Replace the existing 4-token `@layer base { :root { … } }` block and the 4-entry `@theme` stub in `app.css` entirely — don't append. The canonical tokens supersede the placeholder.
- **D-07:** Also add the `[data-theme="dark"]` overrides block from `cairnloop.css` to `app.css` (immediately after the `:root` block in `@layer base`). The dark theme values are part of the brand token contract.

### BRAND-04 — negative-grep gate mechanism

- **D-08:** Implement as an **ExUnit test** (`test/cairnloop/brand_token_gate_test.exs` or similar) that calls `System.cmd("grep", ["-r", "var(--cl-", "lib/cairnloop/web/"])` and asserts the output contains no `#` hex values. Runs in `mix test` (headless lane, no Repo required). Gate location: `test/cairnloop/` (unit lane, not integration).
- **D-09:** Exact grep pattern: `var(--cl-[a-z-]*, #` (regex matching `grep -E` or `--include` approach). The test fails if any match is found; passes if output is empty.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Brand token source of truth
- `prompts/cairnloop.css` — Canonical `:root` block (15 primitive colors + 14 semantic tokens + typography + spacing/radius/shadow + `[data-theme="dark"]` overrides). Copy this verbatim into the example app's `app.css`. **Primary source for BRAND-01.**
- `prompts/cairnloop.tokens.json` — Structured token definition with descriptions. Reference for understanding token intent and naming.
- `prompts/cairnloop_brand_book.md` — Brand voice, color rules (§7.3, §7.5), operator copy register.

### Requirements + Roadmap
- `.planning/REQUIREMENTS.md` — BRAND-01..BRAND-04 (§Brand-Token CSS Extraction). **Note D-01 and D-03 corrections to actual file locations.**
- `.planning/ROADMAP.md` §Phase 29 — Goal, success criteria (4 items).

### Files to modify (source)
- `examples/cairnloop_example/assets/css/app.css` — Replace 4-token stub with full canonical `:root` block + dark overrides; extend `@theme` with 15 primitive colors (BRAND-01).
- `lib/cairnloop/web/inbox_live.ex` — Drop 10 hex fallbacks (BRAND-02, D-01).
- `lib/cairnloop/web/conversation_live.ex` — Drop 7 hex fallbacks (BRAND-02, D-01).
- `lib/cairnloop/web/search_modal_component.ex` — Drop 5 hex fallbacks (BRAND-02, D-01 extension).

### Files to modify (tests)
- `test/integration/approval_footer_live_test.exs` — Re-pin 1 assertion (BRAND-03, D-03).
- `test/integration/tool_execution_outcome_live_test.exs` — Re-pin 3 assertions (BRAND-03, D-03).
- `test/integration/bulk_recovery_live_test.exs` — Re-pin 2 assertions: 1 primary + 1 danger (BRAND-03, D-03).

### Architecture posture
- `CLAUDE.md` — Build/test conventions; `mix compile --warnings-as-errors`; brand tokens (`var(--cl-primary, #A94F30)`); no raw hex to operators.

### Prior phase context
- `.planning/phases/28-customer-chat-wired-to-real-ingress/28-CONTEXT.md` — Prior phase decisions (no direct dependency but confirms test harness constraints and PubSub patterns).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `prompts/cairnloop.css` — Already the authoritative token source; copy verbatim into `app.css` `:root` block.
- `examples/cairnloop_example/assets/css/app.css` — Existing `@theme` and `@layer base` structure to replace, not append (see D-06). Also has `@custom-variant dark` for `[data-theme=dark]` — the dark override block from `cairnloop.css` slots in alongside this.
- Existing `@layer base { :root { … } }` in `app.css` — Replace with full block; drop the 4-token stub.

### Established Patterns
- **Hex fallback form:** All instances are `var(--cl-<token-name>, #<hex>)` — drop the `, #<hex>` suffix only. No other changes.
- **Test assertion pattern:** All 6 assertions use `assert html =~ "var(--cl-primary, #A94F30)"` form; re-pin to `assert html =~ "var(--cl-primary)"` (or `"var(--cl-danger)"` for the danger assertion).
- **ExUnit headless test pattern:** Existing tests in `test/cairnloop/` run without DB. Gate test follows the same pattern.

### Integration Points
- BRAND-04 gate test is standalone — no LiveView, no DB, no PubSub. Pure `System.cmd/2` check on the file tree.
- The 22 inline style `var()` drops are mechanical and non-structural — sealed render code paths are preserved byte-for-byte except for the removed hex suffix.

</code_context>

<specifics>
## Specific Ideas

- Gate grep pattern: `grep -rE 'var\(--cl-[a-z-]+, #' lib/cairnloop/web/` (ERE form). Planner may use `--include="*.ex"` for precision.
- Dark theme block goes immediately after `:root { … }` in the same `@layer base { }` block, or as a sibling `@layer base` block — either is fine.
- The 4 Tailwind `@theme` entries already present (`--color-cl-basalt`, `--color-cl-trailpaper`, `--color-cl-warm-stone`, `--color-cl-primary`) are superseded by the full 15-token replacement — replace, don't append.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. BRAND-02 scope expansion (adding `search_modal_component.ex`) is a correction, not scope creep; it's required for the gate to pass.

</deferred>

---

*Phase: 29-brand-token-css-extraction-d-10-closure*
*Context gathered: 2026-05-27*
