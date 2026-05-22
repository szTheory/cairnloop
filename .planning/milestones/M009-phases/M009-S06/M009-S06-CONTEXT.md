# Phase M009-S06: Retrieval Corpus Verification Closure - Context

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert the implemented M009 Phase 1 retrieval-corpus work into auditable closure evidence for
`M009-REQ-01`, `M009-REQ-02`, and `M009-REQ-03`. This phase covers verification strictness,
evidence format, requirement traceability, and validation-status language for the already-built
retrieval corpus. It does not redesign retrieval behavior, expand feature scope, or turn this
closure phase into a full infrastructure-hardening phase.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Shift routine gray-area decisions left inside GSD for this phase. Downstream agents
  should make strong, coherent defaults that fit Cairnloop's host-owned, evidence-first,
  least-surprise posture instead of re-escalating normal verification-shape decisions.
- **D-02:** Re-escalate only if new evidence suggests a trust-boundary failure, product-truth
  change, or meaningful scope expansion rather than normal closure work.

### Verification strictness
- **D-03:** Do not treat Phase 6 as doc-only cleanup. Fresh executable evidence is required.
- **D-04:** The default verification bar is: rerun the focused M009-S01 automated evidence now,
  record exact commands and outcomes, and add one realistic proof lane for the retrieval substrate.
- **D-05:** The realistic proof lane should be either:
  - one narrow DB-backed integration check over the real retrieval corpus/query path, or
  - an explicit blocked-proof section that records the attempted command, blocking prerequisite,
    failure mode, and resulting residual risk.
- **D-06:** Do not hold closure open by default for a full test-infrastructure redesign. This
  phase is a closure phase, not a broad hardening or redesign phase.

### Verification artifact shape
- **D-07:** `M009-S01-VERIFICATION.md` should be a durable closure artifact, not a terse planner
  matrix and not a prose-heavy postmortem.
- **D-08:** The file should be structured requirement-by-requirement for `M009-REQ-01`,
  `M009-REQ-02`, and `M009-REQ-03`.
- **D-09:** Each requirement section should include:
  - `Implementation evidence`
  - `Automated evidence`
  - `Manual checks`
  - `Residual risk`
- **D-10:** The file should also include a short `Scope` section, a small requirement-coverage
  summary table, and a short `Backfill Summary`.
- **D-11:** `VERIFICATION.md` must not duplicate `VALIDATION.md`. Validation remains the planned
  verification map; verification records closure evidence and the current proof state.

### Closure posture and status language
- **D-12:** The recommended closure posture is `closed with residual verification risk`, not
  unconditional full closure and not a default hold.
- **D-13:** Requirement closure must be separated from proof completeness. It is acceptable to mark
  `M009-REQ-01`, `M009-REQ-02`, and `M009-REQ-03` closed for milestone traceability when the code
  path, focused suites, migration/schema review, and worker/job traceability support those claims.
- **D-14:** The closure language must explicitly state when proof remains partly mock-driven or not
  fully DB-backed, especially for retrieval-provider query semantics such as FTS ranking, pgvector
  ordering, and filter-before-rank behavior.
- **D-15:** If the realistic proof lane reveals possible tenant/scope leakage, broken transactional
  enqueueing, or collapse of canonical-vs-assistive trust semantics, do not close with caveat.
  Treat that as a high-impact exception and escalate.

### Evidence hygiene
- **D-16:** Record exact commands, exact date, and observed outcomes rather than only saying
  “tests passed.”
- **D-17:** Preserve environment caveats when they appear. For example, the focused rerun on
  2026-05-20 passed `29 tests, 0 failures` but emitted repeated startup connection errors for
  `Chimeway.Repo`; this kind of noise should be recorded as part of the evidence story rather than
  smoothed over.
- **D-18:** Prefer boring, grep-able evidence over clever narrative. Future maintainers and agents
  should be able to replay the closure proof quickly.

### the agent's Discretion
- Exact wording of the requirement-coverage summary table
- Exact commands used for the realistic proof lane, so long as they stay narrow and phase-scoped
- Exact residual-risk phrasing, so long as it remains factual and non-defensive
- Exact formatting details of the verification artifact, so long as the required sections above are present

</decisions>

<specifics>
## Specific Ideas

- Use `.planning/milestones/M009-phases/M009-S02/M009-S02-VERIFICATION.md` as the nearest in-repo
  model for the closure artifact shape: explicit scope, requirement sections, implementation
  evidence, automated evidence, manual checks, and backfill summary.
- Use the focused Phase 1 suite as the baseline automated evidence:
  `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs`
- The fresh rerun on 2026-05-20 passed with `29 tests, 0 failures`, but emitted repeated
  `Chimeway.Repo` missing-`:database` startup errors. This is a useful example of why closure must
  distinguish “green suite” from “clean realism proof.”
- Keep the strongest additional proof close to the real Phase 1 surface: corpus separation,
  transactional enqueueing, recovery primitives, and at least one real retrieval-substrate check or
  an explicit blocked-proof note.
- Write status language that says what is proven, what is inferred, and what remains unproven.
  Avoid overclaiming certainty.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements and closure scope
- `.planning/M009-ROADMAP.md` — Phase 6 goal, requirements, gap-closure framing, and success criteria
- `.planning/PROJECT.md` — Current product posture: host-owned, evidence-first, retrieval-first
- `.planning/REQUIREMENTS.md` — Requirement mapping for `M009-REQ-01..03`
- `.planning/STATE.md` — Current milestone state and closure context

### Original Phase 1 decisions and artifacts
- `.planning/milestones/M009-phases/M009-S01-CONTEXT.md` — Locked retrieval semantics and trust boundaries from the original phase
- `.planning/milestones/M009-phases/M009-S01/M009-S01-RESEARCH.md` — Research rationale for the original retrieval-corpus implementation
- `.planning/milestones/M009-phases/M009-S01/M009-S01-VALIDATION.md` — Existing validation contract, including currently stale/pending proof posture
- `.planning/milestones/M009-phases/M009-S01/M009-S01-01-SUMMARY.md` — Execution summary for storage/indexing work
- `.planning/milestones/M009-phases/M009-S01/M009-S01-02-SUMMARY.md` — Execution summary for retrieval facade, ranking, and recovery primitives

### Local verification pattern and observability posture
- `.planning/milestones/M009-phases/M009-S02/M009-S02-VERIFICATION.md` — Best in-repo pattern for a closure-phase verification artifact
- `.planning/M005-RESEARCH.md` — Durable evidence vs telemetry posture, host-owned proof, and least-surprise operator expectations
- `.planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md` — Host-owned instrumentation and explicit evidence-contract patterns

### Product and ecosystem direction
- `prompts/cairnloop_brand_book.md` — “Support that leaves a trail,” “Show your sources,” and explicit trust posture
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Product wedge, operator-grade DX, and host-owned library posture
- `prompts/scoria overview for integration ideas.txt` — Evidence-first AI quality and inspectability posture
- `prompts/parapet overview for integration ideas.txt` — Stable telemetry contracts, host ownership, and evidence-vs-telemetry separation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/retrieval.ex` — Central retrieval facade already defines the public Phase 1 boundary and recovery primitives to verify
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` — Real KB indexing worker for deterministic chunk persistence
- `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` — Real assistive-evidence indexing worker for resolved conversations
- `lib/cairnloop/retrieval/providers/knowledge_base.ex` — Real FTS/vector query path for canonical KB results
- `lib/cairnloop/retrieval/providers/resolved_cases.ex` — Real FTS/vector query path for assistive resolved-case results
- `test/cairnloop/retrieval_test.exs` — Current mock-driven retrieval/ranking verification surface
- `test/cairnloop/tasks/retrieval_tasks_test.exs` — Current recovery-command verification surface

### Established Patterns
- Cairnloop prefers host-owned, explicit proof over hidden magic
- Requirement closure artifacts should show sources, commands, and trust caveats clearly
- Existing verification artifacts in this repo are requirement-structured rather than narrative-only
- The current test surface is layered: worker/context assertions are concrete, while some retrieval-provider proof remains mock-driven

### Integration Points
- `M009-S06` planning should update `M009-S01-VALIDATION.md` to reflect the actual proof state instead of leaving stale Wave 0 placeholders
- `M009-S06` execution should create `M009-S01-VERIFICATION.md` as the closure artifact
- Planning should account for the current environment signal: focused tests pass, but the suite emits `Chimeway.Repo` startup errors and there is no obvious dedicated DB-backed retrieval test harness in the repo

</code_context>

<deferred>
## Deferred Ideas

- Full test-environment redesign for all sibling repos and all database-backed dependencies
- Broad retrieval-hardening work beyond what is needed to close Phase 1 truthfully
- New product UX or telemetry features unrelated to Phase 1 closure evidence

</deferred>

---

*Phase: M009-S06*
*Context gathered: 2026-05-20*
