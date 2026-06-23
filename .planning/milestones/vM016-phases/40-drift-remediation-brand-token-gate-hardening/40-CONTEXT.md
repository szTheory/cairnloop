# Phase 40: Drift Remediation + Brand-Token Gate Hardening - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Remediate the two largest off-palette drift surfaces — `lib/cairnloop/web/conversation_live.ex`
and `lib/cairnloop/web/search_modal_component.ex` — so both carry zero off-palette hardcoded
hex/`rgba()`, then harden the brand-token gate so the same drift cannot re-enter silently.

In scope (fixed by ROADMAP/REQUIREMENTS — DRIFT-01, DRIFT-02, GATE-01, GATE-02):
- Apply the documented hex→token map in both files (border / text / danger / warning;
  info + success via `cl_source_card source_variant`).
- Rebuild the hand-rolled approve/reject/defer footer with `cl_button` variants + a shared
  textarea class; migrate bespoke inline-layout `style=` attributes to `.cl-` utilities.
- Harden the ExUnit gate to fail on inline `style="…#hex…"`, raw `rgba()`/`hsl()`, and
  helper-returned hex in render `.ex` files.
- Add a complementary dev-time Credo check; the ExUnit gate stays the CI source of truth.

Out of scope (own phases): rail progressive disclosure (P41), cross-screen threading (P42),
responsive normalization (P43), motion (P44). Drift in files **other than** the two named
surfaces is not remediated here — but the hardened gate will guard all render files going forward.
</domain>

<decisions>
## Implementation Decisions

### rgba / translucent strategy (the one fork — user-decided)
- **D-01:** **Snap to nearest existing solid tokens. Do NOT expand the shipped palette.**
  `search_modal_component.ex`'s frosted-glass treatment (~15 `rgba()` values) is itself off-system
  drift — the rest of the cockpit (Inbox/Home) uses solid `--cl-surface*`. Resolve it by snapping,
  not by adding alpha tokens:
  - White-alpha panels (`rgba(255,255,255,0.72/0.76/0.9)`) → `--cl-surface-raised` (or
    `--cl-surface`/`--cl-surface-sunken` per nesting depth).
  - The 5 basalt text-opacity steps (`rgba(47,36,29,0.62/0.68/0.76/0.82/0.84)`) collapse to the
    existing 3-tier text scale: `--cl-text` (≥0.82), `--cl-text-muted` (~0.62–0.76), `--cl-text-soft`
    (faint/placeholder). Planner picks the tier per usage; do not introduce a 4th text token.
  - Olive chip tint (`rgba(74,98,56,…)`) → success/info semantic surface; slate-blue chip tint
    (`rgba(63,111,128,…)`) → `--cl-info-*`; primary tints (`rgba(169,79,48,0.08/0.22)`) → primary
    semantic surface/border tokens. Prefer routing result/source chips through
    `cl_source_card source_variant` (per DRIFT-01) rather than re-deriving tints inline.
  - Border hairlines (`rgba(64,51,43,0.08)`) → `--cl-border`.
  - **Rationale:** additive-only, zero churn to the shipped `priv/static/cairnloop.css` public token
    surface (stays at 140 tokens), and it makes Search visually consistent with the rest of the
    cockpit. Trade-off accepted: the one-off glass aesthetic is dropped. **Owner can veto cheaply** —
    the alternative was adding ~6 `--cl-*-translucent/tint/faint` tokens to preserve glass.

### Hex→token map (locked by DRIFT-01 / SC1 — apply as documented)
- **D-02:** `#e5e7eb` → `--cl-border`; `#8b7355` → `--cl-text-muted`; `#4c4033` → `--cl-text`
  (body) / `--cl-text-soft` where clearly secondary; maroon reject (`#8b1a1a` border/text,
  `#fdecea` fill) → `--cl-danger-{text,border,surface}`; olive/cream defer (`#7a5c00`, `#fef9e5`)
  → `--cl-warning-{text,border,surface}`; tan textarea border `#c38f57` → `--cl-border-strong`
  (or `--cl-border`); near-white-on-primary `#fffdf8` → the on-primary/raised-surface token the
  primary button already uses elsewhere. Exact tier choices where the map is ambiguous are
  planner's call, but stay within the existing palette — no new tokens (per D-01).

### Footer rebuild (locked by DRIFT-02 / SC2)
- **D-03:** Replace the hand-rolled approve/reject/defer footer markup
  (`conversation_live.ex` ~lines 1071–1114) with `cl_button` variants (primary = approve;
  danger = reject; default/warning = defer) from `lib/cairnloop/web/components.ex`, and the two
  bespoke `<textarea style="…">` controls with the shared `.cl-textarea` class
  (`priv/static/cairnloop.css:384`). Bespoke inline-layout `style=` (margins, flex, padding) on
  this footer and surrounding blocks migrate to existing `.cl-` utilities (`.cl-row`,
  `.cl-stack`, spacing utils). Do not invent new utility classes if an existing one fits.

### Gate hardening (locked by GATE-01)
- **D-04:** Extend the existing gate test `test/cairnloop/web/brand_token_gate_test.exs` (don't
  create a parallel file). Add detection for: (a) inline `style="…#hex…"`, (b) raw
  `rgba(`/`hsl(`/`rgba(`-with-alpha in render `.ex` source, (c) helper-returned hex — caught
  naturally by scanning the full `.ex` source text for `#`-anchored color literals, since a helper
  returning `"#4A6238"` carries that literal in source.
- **D-05:** **Magic-comment allowlist IS required** (GATE-01 explicitly). Provide an inline
  escape-hatch annotation (e.g. a `# cl-allow-color` / sentinel comment on the offending line or
  block) so genuine, intentional exceptions are opt-in and auditable rather than silently merged.
  Anchor matches on `#` + color context to avoid false positives (e.g. ignore `#` in URLs/anchors,
  `phx-*` ids, comments without color). The `.css` file stays **unscanned** (it legitimately holds
  the canonical hex). Today there are no known legitimate exceptions in the two target files — the
  allowlist exists for future intentional cases, not to grandfather current drift.
- **D-06:** Gate scope = `lib/cairnloop/web/**/*.ex` (+ the example app live dir already covered).
  ExUnit gate is the **CI source of truth** (fast, no Credo dependency).

### Credo check (locked by GATE-02)
- **D-07:** Add a custom `Credo.Check` module (a project check, not a built-in — Credo has no
  color check) wired into `.credo.exs`, flagging hardcoded color literals in render files at
  dev time. It is **complementary / advisory** — duplicate coverage of the same rule is acceptable
  and harmless; the ExUnit gate remains authoritative. Keep its priority/category such that it
  guides during `mix credo` without becoming a second, divergent source of truth.

### Claude's Discretion
- Exact `.cl-` utility selection for each migrated inline-layout `style=` (researcher maps to the
  closest existing utility per `priv/static/cairnloop.css`).
- Precise text-tier assignment (`--cl-text` vs `--cl-text-muted` vs `--cl-text-soft`) per snapped
  rgba text value.
- Regex/AST mechanics of the hardened gate and the magic-comment sentinel's exact spelling.
- Credo check module name, category, and exit/priority configuration.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` §DRIFT-01, DRIFT-02, GATE-01, GATE-02 — authoritative scope.
  **Note: GATE-01 mandates a magic-comment allowlist, `#`+color-context anchoring, and that the
  `.css` file stays unscanned.**
- `.planning/ROADMAP.md` — Phase 40 entry + Success Criteria (the hex→token map source).

### Files to remediate (the two drift surfaces)
- `lib/cairnloop/web/conversation_live.ex` — hardcoded hex at ~792, 1002–1114; the
  approve/reject/defer footer to rebuild (~1071–1114); many inline-layout `style=`.
- `lib/cairnloop/web/search_modal_component.ex` — heavy `rgba()` usage (glass panels, 5 text-alpha
  steps, chip tints) at ~56–207, 614–634; chip helpers returning inline style strings.

### Design system — tokens, primitives, gate
- `priv/static/cairnloop.css` — canonical token source (140 tokens). Solid surface/text scale:
  `--cl-surface{,-raised,-sunken}`, `--cl-text{,-muted,-soft}`, semantic `--cl-{success,info,
  warning,danger,ai,neutral}-{surface,border,text}`, `--cl-border{,-strong}`. Shared input class
  `.cl-input/.cl-select/.cl-textarea` at :377/:384. **Stays unscanned by the gate; do not add
  tokens (per D-01).**
- `lib/cairnloop/web/components.ex` — `cl_button` (variants), `cl_source_card`/`source_variant`,
  `cl_disclosure` primitives used to absorb the drift markup.
- `test/cairnloop/web/brand_token_gate_test.exs` — existing BRAND-04 gate to **extend** (currently
  only catches `var(--cl-token, #hex)` fallbacks).
- `.credo.exs` — Credo config (strict, 120-col) to wire the new custom check into.

### Brand rules
- `prompts/cairnloop_brand_book.md` §7 Color system, §7.5 Accessibility (never state-by-color-
  alone), §7.6 UI state color meanings — governs the semantic-token mapping for danger/warning/
  info/success states.

### Prior-phase context
- `.planning/phases/37-component-primitives/37-CONTEXT.md` — primitives (`cl_button`,
  `cl_source_card`, `cl_disclosure`) these remediations consume.
- `.planning/phases/39-home-primacy-redesign-d1/39-CONTEXT.md` — Home migration; gate now spans
  all operator screens after this phase.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cl_button` variants + `.cl-textarea` (components.ex / cairnloop.css:384) — drop-in replacements
  for the hand-rolled footer buttons and styled textareas (DRIFT-02).
- `cl_source_card source_variant` — canonical home for result/source chip tints, removing the need
  for the inline `rgba()` chip-style helpers in search_modal (DRIFT-01).
- Existing solid token scale (surface/text 3-tier + 6 semantic families) fully covers every snapped
  rgba/hex value — no palette expansion needed (D-01).
- `brand_token_gate_test.exs` — the existing line-scan harness to extend; same File.read! +
  per-line regex shape, just broader patterns + an allowlist sentinel.

### Established Patterns
- Gate is a pure ExUnit `File.read!`-and-grep test over `lib/cairnloop/web/**/*.ex` (+ example
  live dir) — no DB, runs in default `mix test`. Hardening stays in this mold.
- Project posture: **seal completed phases, additive-only, don't churn sealed/shipped code**
  (CLAUDE.md) — directly motivates D-01 (no shipped-CSS token churn) and D-04 (extend, don't fork).
- `.credo.exs` runs `credo --strict` as a CI quality gate already; the new check joins it as
  complementary/advisory (D-07).

### Integration Points
- New custom Credo check module ↔ `.credo.exs` `checks:` list.
- Hardened gate ↔ all current and future `lib/cairnloop/web` render files (guards beyond the two
  remediated surfaces).
</code_context>

<specifics>
## Specific Ideas

- Owner explicitly prefers **consistency over preserving the search modal's one-off frosted-glass
  look** — Search should read like the rest of the cockpit (solid surfaces). This is the guiding
  aesthetic intent for the whole remediation.
- Fail-closed governance flavor carries into the gate: exceptions must be **explicit and auditable**
  (magic-comment opt-in), never silent.
</specifics>

<deferred>
## Deferred Ideas

- **Alpha/tint token family** (`--cl-*-translucent`, `--cl-text-faint`, `--cl-*-tint`) — considered
  and rejected for this phase (D-01). If a future phase genuinely needs translucency as a system
  primitive (e.g. a glassmorphism direction), revisit then as a deliberate palette expansion.
- **Remediating drift in render files beyond the two named surfaces** — out of scope here; the
  hardened gate will surface them, and they can be cleaned in a follow-up sweep.

None blocking — discussion stayed within phase scope.
</deferred>

---

*Phase: 40-Drift Remediation + Brand-Token Gate Hardening*
*Context gathered: 2026-06-04*
