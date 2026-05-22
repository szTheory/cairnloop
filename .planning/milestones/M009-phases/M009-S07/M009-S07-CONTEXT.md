# Phase M009-S07: Grounded Drafting Verification Closure - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert the implemented M009 Phase 3 grounded-drafting work into auditable closure evidence for
`M009-REQ-06` and `M009-REQ-07`. This phase covers verification strictness, verification-artifact
shape, requirement traceability, and explicit manual trust/tone checks for the already-built
grounded drafting flow. It does not redesign grounded drafting behavior, expand the product scope,
or turn this closure phase into a broad QA or infrastructure-hardening program.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Shift routine gray-area decisions left inside GSD for this phase. Downstream agents
  should make strong defaults that fit Cairnloop's host-owned, evidence-first, least-surprise
  posture instead of re-escalating normal closure-shape questions.
- **D-02:** Re-escalate only for decisions that materially change trust semantics, milestone scope,
  or the host-owned support posture.
- **D-03:** Closure recommendations must be one coherent package: verification bar, verification
  artifact, and manual checks should reinforce each other instead of mixing incompatible proof styles.

### Verification strictness
- **D-04:** Do not treat Phase 7 as doc-only cleanup. Fresh executable evidence is required.
- **D-05:** The default verification bar is: rerun the focused M009-S03 automated evidence now and
  add one narrow realism proof lane for the grounded-drafting flow, or record an explicit
  blocked-proof note if that realism lane cannot run cleanly.
- **D-06:** The realism proof lane should stay phase-scoped and least-surprising for an
  Elixir/Phoenix/Ecto/Oban app:
  - one DB-backed or mounted-LiveView proof lane over the grounded-drafting contract, or
  - one explicit blocked-proof section that records the attempted command, blocking prerequisite,
    failure mode, and resulting residual risk.
- **D-07:** Do not raise the default closure bar to a full end-to-end system-test program. That
  would turn this gap-closure phase into infrastructure hardening and slow closure for the wrong
  reason.
- **D-08:** Existing summaries and historical green tests are supporting context only. They are not
  sufficient closure evidence by themselves.

### Verification artifact shape
- **D-09:** `M009-S03-VERIFICATION.md` must be a separate durable closure artifact, not a
  replacement for `M009-S03-VALIDATION.md`.
- **D-10:** `M009-S03-VALIDATION.md` remains the planned verification map; `VERIFICATION.md`
  records executed closure evidence and the current proof state.
- **D-11:** `M009-S03-VERIFICATION.md` should be structured requirement-by-requirement for
  `M009-REQ-06` and `M009-REQ-07`.
- **D-12:** Each requirement section should contain exactly:
  - `Implementation evidence`
  - `Automated evidence`
  - `Manual checks`
  - `Residual risk`
- **D-13:** The verification artifact should also include a short `Scope` section, a compact
  requirement-coverage summary table, and a short `Backfill Summary`.
- **D-14:** Keep the artifact grep-able and replayable. Do not duplicate the entire validation file
  or hide proof state inside narrative prose.

### Manual editorial checks
- **D-15:** Manual checks are required closure evidence for this phase, not optional polish.
- **D-16:** Keep manual review intentionally bounded to the two trust-sensitive surfaces that
  automation is least able to judge well:
  - clarification-question tone
  - evidence-rail trust semantics
- **D-17:** Manual checks should explicitly verify:
  - clarification copy is bounded, calm, and not falsely confident
  - escalation copy is explicit, non-defensive, and does not bluff
  - `Knowledge Base` versus `Resolved case` and `Canonical guidance` versus `Supporting evidence`
    remain visually and semantically distinct
  - supporting evidence is visible by default and does not pollute the editable reply body
- **D-18:** Do not expand the default closure scope into a broad release-style UX checklist across
  every layout and branch. That increases process cost without materially improving truthfulness for
  this gap phase.

### Evidence hygiene and status language
- **D-19:** Record exact commands, exact date, and exact observed outcomes rather than saying only
  that tests passed.
- **D-20:** Preserve environment caveats when they appear, including boot noise or blocked realism
  lanes, so future maintainers understand what was proven versus inferred.
- **D-21:** Residual-risk language must explicitly distinguish what is freshly proven, what remains
  partly mock-driven, and what is inferred from implementation structure rather than directly
  exercised.
- **D-22:** Do not blend `M009-REQ-06` and `M009-REQ-07` into one generic proof section. Separate
  requirement traceability is part of the closure value.

### the agent's Discretion
- Exact choice of the narrow realism proof lane, so long as it stays phase-scoped and supports the
  requirement story honestly
- Exact wording of residual-risk notes, so long as they remain factual and non-defensive
- Exact table/heading wording inside `M009-S03-VERIFICATION.md`, so long as the required sections
  above are present
- Exact focused command set, so long as it covers the retrieval-to-draft contract, worker/policy
  branching, persistence, and operator review surface

</decisions>

<specifics>
## Specific Ideas

- Treat Phase 7 as the Phase 3 sibling of M009-S06:
  same closure posture, but specialized for grounded drafting instead of retrieval corpus indexing.
- Use `.planning/milestones/M009-phases/M009-S02/M009-S02-VERIFICATION.md` as the nearest local
  model for verification artifact shape.
- Keep the strongest proof close to the actual grounded-drafting seams:
  `Retrieval.ground_for_draft/2`, `DraftWorker`, `ScoriaEngine`, `Automation.create_draft/2`, and
  `ConversationLive`.
- Good ecosystem pattern to emulate:
  strong products in this space emphasize source quality, visible evidence, explicit fallback, and
  human handoff instead of bluffing from a green suite.
- Footguns to avoid:
  hiding source review, flattening canonical and assistive trust semantics, overclaiming closure
  from stale summaries, or turning this phase into a sprawling generic QA checklist.
- Preference to preserve across downstream planning:
  make strong cohesive defaults automatically, with escalation only for unusually high-impact trust
  or scope decisions.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements and closure scope
- `.planning/M009-ROADMAP.md` — Phase 7 goal, requirements, gap-closure framing, and success criteria
- `.planning/PROJECT.md` — Current product posture: embedded, host-owned, evidence-first support automation
- `.planning/REQUIREMENTS.md` — Requirement mapping for `M009-REQ-06` and `M009-REQ-07`
- `.planning/STATE.md` — Current milestone state and closure context
- `.planning/vM009-vM009-MILESTONE-AUDIT.md` — Audit findings that created this closure phase

### Original Phase 3 decisions and artifacts
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Locked grounded-drafting semantics, fallback posture, and evidence presentation rules
- `.planning/milestones/M009-phases/M009-S03/M009-S03-RESEARCH.md` — Phase 3 research rationale and implementation boundary
- `.planning/milestones/M009-phases/M009-S03/M009-S03-VALIDATION.md` — Existing validation contract and pending proof posture
- `.planning/milestones/M009-phases/M009-S03/M009-S03-01-SUMMARY.md` — Backend grounding-contract implementation summary
- `.planning/milestones/M009-phases/M009-S03/M009-S03-02-SUMMARY.md` — Operator evidence-rail implementation summary

### Local closure precedent
- `.planning/milestones/M009-phases/M009-S02/M009-S02-VERIFICATION.md` — Best in-repo model for requirement-structured closure evidence
- `.planning/milestones/M009-phases/M009-S06/M009-S06-CONTEXT.md` — Prior closure-phase decision pattern for fresh proof + realism lane

### Product and ecosystem direction
- `prompts/cairnloop_brand_book.md` — “Support that leaves a trail,” “show your sources,” explicit safety, and host-owner control
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Support-product strategy, ecosystem lessons, and DX posture
- `prompts/scoria overview for integration ideas.txt` — Evidence-first AI observability, operator-grade proof, and inspectable tracing posture
- `prompts/parapet overview for integration ideas.txt` — Strict telemetry/evidence separation, explicit contracts, and operator-first diagnostics

### Existing code seams
- `lib/cairnloop/retrieval.ex` — Host-owned retrieval boundary and draft-grounding entrypoint
- `lib/cairnloop/automation/draft.ex` — Durable grounded-draft schema
- `lib/cairnloop/automation/scoria_engine.ex` — Structured grounded proposal generation seam
- `lib/cairnloop/automation/workers/draft_worker.ex` — Retrieval-to-draft branching and gap-recording seam
- `lib/cairnloop/web/conversation_live.ex` — Operator review surface and evidence rail
- `test/cairnloop/automation/scoria_engine_test.exs` — Focused structured-proposal contract tests
- `test/cairnloop/automation/workers/draft_worker_test.exs` — Grounding branch and policy-path tests
- `test/cairnloop/automation_test.exs` — Durable draft persistence tests
- `test/cairnloop/web/conversation_live_test.exs` — Evidence-rail and proposal-state rendering tests

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/retrieval.ex` — Already owns the grounded-draft retrieval seam and should anchor `REQ-06` verification evidence
- `lib/cairnloop/automation/workers/draft_worker.ex` — Encodes the clarification/escalation state machine and gap recording
- `lib/cairnloop/automation/scoria_engine.ex` — Generates structured proposal types and copy branches that manual checks should inspect
- `lib/cairnloop/automation/draft.ex` and `lib/cairnloop/automation.ex` — Persist the durable draft artifact that the closure doc should reference
- `lib/cairnloop/web/conversation_live.ex` — Renders the operator evidence rail and proposal-state copy for `REQ-07`

### Established Patterns
- Cairnloop prefers host-owned, explicit proof over magical “trust the system” closure language
- Verification artifacts in this repo separate planning/validation from executed proof
- Focused ExUnit and LiveView tests are the normal proof surface; realism checks are narrow and deliberate rather than sprawling
- Trust semantics and source clarity are first-class product behavior, not incidental UI garnish

### Integration Points
- `M009-S07` planning should update `M009-S03-VALIDATION.md` to reflect the actual proof state instead of leaving draft-only status markers behind
- `M009-S07` execution should create `M009-S03-VERIFICATION.md` as the durable closure artifact
- Planning should account for the current environment pattern already seen in sibling phases:
  focused suites pass, but shell noise or realism-lane prerequisites may need explicit caveats rather than being silently ignored

</code_context>

<deferred>
## Deferred Ideas

- A broader reusable release checklist for all AI/operator UX surfaces across the project
- Full end-to-end realism harnesses for retrieval, Oban execution, persistence, and LiveView review beyond what this closure phase needs
- New grounded-drafting behavior, product UX redesign, or additional telemetry features outside the closure scope

</deferred>

---

*Phase: M009-S07*
*Context gathered: 2026-05-21*
