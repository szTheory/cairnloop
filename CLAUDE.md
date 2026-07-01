# Cairnloop — Project Instructions

Elixir / Phoenix LiveView / Ecto host-owned customer-support automation library. These
instructions apply to all work in this repo, including GSD subagents (researcher, planner,
checker, executor, verifier) — which read this file but do **not** read the user's personal
`~/.claude` memory.

## Decision policy (shift-left — IMPORTANT)

The owner wants decisions **made for them**, not surfaced as questions. For any "gray area" /
discretionary / trust-sensitive call:

1. **Research deeply first** (use subagents / web / `prompts/` + `.planning/` docs as warranted),
   then **decide and proceed**. Produce one coherent, cohesive set of recommendations that move
   toward the project vision — don't make the owner think.
2. **Do NOT ask the owner to choose** between options you can resolve yourself. Default to the
   strongest option, state what you decided and why, and continue.
3. **Escalate ONLY VERY impactful decisions** — ones that are expensive/irreversible to undo,
   materially change product scope or the trust/governance model, or that the owner would plausibly
   feel strongly about. A normal "trust-sensitive" implementation call is NOT automatically
   VERY-impactful; research it and decide. When in doubt, decide and clearly flag the decision in
   your summary so the owner can veto cheaply.
4. **Record decisions durably** where the relevant agents will see them: the phase `CONTEXT.md`
   ratification notes, `.planning/STATE.md` "Decisions", and forward-compat guardrails carried to
   the phase that will need them.

(GSD discuss-phase: surface at most the single genuinely VERY-impactful call, if any; auto-decide
the rest with recorded rationale.)

## Build / test conventions

- **Warnings-clean builds are mandatory.** Code must pass `mix compile --warnings-as-errors`.
- Run `mix ci.fast` before declaring headless work done. For DB-backed, docs/package, or browser
  changes, also run the corresponding lane: `mix ci.integration`, `mix ci.quality`, or
  `cd examples/cairnloop_example && mix test.e2e`. Report failures honestly with output.
- Known environment caveat: **`Cairnloop.Repo` may be unavailable in this workspace.** Prefer
  headless/pure tests (presenters, total functions) that don't need a live DB; tests that genuinely
  require a Postgres round-trip (e.g. JSONB atom→string key behavior) should be written but marked
  with a `# REPO-UNAVAILABLE` note where they can't run here. Some focused runs emit unrelated
  `*.Repo` missing-database boot noise — that is pre-existing baseline, not your regression.

## Architecture posture (carried decisions)

- **Durable Ecto records + events are workflow truth; `:telemetry` is observability only** — never a
  UI/display source.
- New reads go through the **narrow `Cairnloop.Governance` facade**, not direct schema queries from
  the web layer.
- **Snapshot trust facts at decision time; never re-read live config at render time.** (Interpretive
  display prose is a separate category — see Phase 14 D-15.)
- **Seal completed phases.** Don't churn sealed code paths (e.g. `propose/3`, idempotency,
  co-commit) for downstream display concerns; prefer additive changes.
- Operator copy is calm, fail-closed, reason-forward, honest — never raw Elixir terms / raw JSON to
  operators (humanize; raw only behind an explicit expander). Never state-by-color-alone (brand §7.5).
- Brand tokens over hardcoded hex (primary `var(--cl-primary, #A94F30)`).
- Operator UI work follows `docs/operator-ui-principles.md`: shipped dashboard CSS is tokenized
  `.cl-*` / BEM, not Tailwind; component reuse beats one-off styles; UI/e2e specs must be fast,
  deterministic, and non-flaky.

## Where the good context lives

- `prompts/cairnloop_brand_book.md` — brand voice, copy register, rail layout, color rules.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned architecture posture.
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` —
  vision, requirements, phase map, carried decisions.
