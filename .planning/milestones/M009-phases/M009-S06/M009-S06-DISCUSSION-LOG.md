# Phase M009-S06: Retrieval Corpus Verification Closure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `M009-S06-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-20
**Phase:** M009-S06 — Retrieval Corpus Verification Closure
**Areas discussed:** Verification strictness, Verification artifact format, Closure posture

---

## Verification strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Doc-only traceability | Close the phase from existing summaries, validation notes, and current mock-driven tests without fresh execution evidence | |
| Focused rerun only | Rerun the current focused suite and record the exact commands/results, but do not add a realistic proof lane | |
| Stronger rerun plus realistic proof lane | Rerun the focused suite, record exact evidence, and add one realistic retrieval-substrate proof or an explicit blocked-proof section | ✓ |
| Hard gate on full infra realism | Refuse closure until a clean DB-backed integration harness and stronger end-to-end realism proof exist | |

**User's choice:** Auto-selected recommended option based on the user's request for cohesive,
research-backed one-shot recommendations and a preference to shift routine decisions left.
**Notes:** This keeps Phase 6 strict enough to be trustworthy without turning it into a broad test
infrastructure redesign. The focused suite was rerun on 2026-05-20 and passed with `29 tests, 0
failures`, but emitted repeated `Chimeway.Repo` startup connection errors; that caveat should be
captured, not hidden.

---

## Verification artifact format

| Option | Description | Selected |
|--------|-------------|----------|
| Terse requirement matrix | Small requirement-to-test/code table optimized for traceability and diffability | |
| Rich audit artifact | Requirement-by-requirement closure doc with commands, outcomes, file refs, manual checks, and residual risks | ✓ |
| Narrative report with appendix | Human-readable narrative verification report with structured evidence tucked into an appendix | |

**User's choice:** Auto-selected recommended option based on the user's request for a cohesive,
low-friction recommendation set.
**Notes:** The in-repo model is `M009-S02-VERIFICATION.md`. The chosen format best matches
Cairnloop's “show your sources” posture and future maintainer ergonomics.

---

## Closure posture

| Option | Description | Selected |
|--------|-------------|----------|
| Full closure with no caveat | Mark `M009-S01` fully closed once focused tests and traceability pass, without special realism language | |
| Close with residual verification risk | Close the requirements while explicitly documenting the remaining realism gap and its impact | ✓ |
| Hold closure pending stronger realism | Keep the phase open until stronger DB-backed or runtime proof exists | |

**User's choice:** Auto-selected recommended option based on the user's request to shift the
decision burden left unless the issue is genuinely high impact.
**Notes:** The chosen posture separates requirement closure from proof completeness. It preserves
momentum while staying honest about mock-driven provider coverage and the lack of a clean DB-backed
retrieval proof lane today.

---

## the agent's Discretion

- Exact wording for residual-risk language in `VALIDATION.md` and `VERIFICATION.md`
- Exact requirement-coverage summary table shape
- Exact realistic-proof command selection, so long as it remains narrow and phase-scoped

## Deferred Ideas

- Full test harness redesign across sibling repos and all external repo dependencies
- Broad retrieval-hardening work that would meaningfully expand M009-S06 scope

