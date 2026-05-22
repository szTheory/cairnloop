# Phase M009-S08: Gap Signal Semantics & Telemetry Closure - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Align Phase 4 telemetry and durable gap-storage semantics with Cairnloop's retrieval contract, then close the remaining audit gaps with auditable verification evidence. This phase covers durable scope naming/shape, assistive-only gap persistence policy, and the exact verification/validation bar needed to close `M009-REQ-08` and `M009-REQ-09`. It does not add a new analytics dashboard, a retrieval control plane, a broad runbook system, or a richer operator debugger surface.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Strengthen the existing shift-left preference inside GSD for Cairnloop. Downstream agents should make strong defaults that fit Cairnloop's host-owned, retrieval-first, least-surprise posture instead of re-escalating ordinary design choices.
- **D-02:** Re-escalate only for decisions that would create a semver-major public-contract change, materially expand retention/privacy posture, or change the canonical-versus-assistive trust model.
- **D-03:** Principle of least surprise beats semantic purity if purity would force unnecessary churn in a closure phase. Prefer coherent, boring, explicit contracts over a large rename/refactor.

### Durable scope semantics
- **D-04:** Keep the existing `tenant_scope` field in this phase, but repurpose its meaning to represent the bounded retrieval access contract rather than UI surface names.
- **D-05:** `tenant_scope` should store access/visibility semantics such as `host_user_scoped`, `public_only`, or `system_unscoped`, not `conversation`, `inbox`, or `settings`.
- **D-06:** Preserve `host_user_id` as the concrete scoped subject when the access contract is user-scoped.
- **D-07:** Add a separate bounded `ui_surface` field for operator/UI context such as `conversation`, `inbox`, and `settings` so product context remains queryable without polluting security semantics.
- **D-08:** Keep `surface` as the retrieval entrypoint (`search_modal`, `draft_generation`, `api`, etc.). Do not overload it with UI-mount or security meaning.
- **D-09:** Do not rename `tenant_scope` to `access_scope` or `visibility_scope` in this phase. The naming improvement is real, but the migration and compatibility churn are not worth spending in Phase 8.

### Assistive-only durable gap policy
- **D-10:** Durable gap evidence should persist assistive-only outcomes only when they represent a real canonical knowledge gap at a decision boundary, not whenever assistive evidence appears.
- **D-11:** For `draft_generation`, persist assistive-only outcomes as durable `weak_grounding` events with reason `assistive_only_results` whenever zero canonical results leave the draft flow unable to produce a trustworthy canonical-backed answer.
- **D-12:** For `search_modal`, persist assistive-only outcomes only when the final ranked result set has zero canonical hits and one or more assistive hits.
- **D-13:** Search assistive-only persistence must be deduplicated by normalized query fingerprint plus access contract and bounded UI context within a boring bounded window. Recommended default: a 24-hour window unless planning finds a better existing repo convention.
- **D-14:** Do not persist `mixed_results`, canonical-backed results, or assistive evidence that merely supplements canonical guidance. Telemetry may still describe those outcomes, but durable gap storage should not treat them as gaps.
- **D-15:** Keep telemetry and durable evidence intentionally asymmetric when product meaning requires it. Telemetry remains the broad observability seam; durable gap events remain the filtered evidence seam for future clustering.

### Verification and closure bar
- **D-16:** Use a balanced closure artifact rather than either a thin audit-only doc or a sprawling trust-review package.
- **D-17:** `M009-S04-VERIFICATION.md` must map `M009-REQ-08` and `M009-REQ-09` to fresh automated evidence, implementation evidence, and any residual verification risk using the same backfill style established by `M009-S01` and `M009-S03`.
- **D-18:** `M009-S04-VALIDATION.md` must be updated to reflect the real post-Phase-8 execution state, including explicit semantics coverage rather than leaving the phase in draft/planned status.
- **D-19:** Closure must include a small explicit semantics checklist verifying:
  - access-contract semantics are distinct from UI-surface metadata
  - assistive-only search outcomes are persisted only when canonical evidence is absent
  - telemetry remains the public observability seam while durable gap rows remain the evidence seam
  - canonical-versus-assistive distinctions remain preserved in storage, copy, and verification language
- **D-20:** Manual review must stay intentionally narrow: one check for search no-hit/retrieval-failure copy and one check for draft weak-grounding/escalation copy. Do not broaden manual review into a general UX audit or analytics review.
- **D-21:** Update milestone traceability so `M009-REQ-08` and `M009-REQ-09` no longer remain pending once the semantics fix and verification backfill are complete.

### Architecture and DX posture
- **D-22:** Keep durable gap writes boundary-owned through `GapRecorder` and `Ecto.Multi`; do not move semantic persistence into telemetry handlers.
- **D-23:** Keep the stable Cairnloop-native telemetry contract as the public seam and OpenInference/OpenTelemetry as adapters, not as the primary closure artifact.
- **D-24:** Optimize for future M010 knowledge-gap clustering quality, not vanity event volume. One trustworthy gap row is worth more than many noisy assistive-only pseudo-failures.
- **D-25:** Preserve a calm operator experience: product surfaces may explain weak grounding, but durable semantic changes should remain mostly invisible to operators unless they improve clarity.

### the agent's Discretion
- Exact schema/module names for the new `ui_surface` field and any migration helpers
- Exact enum implementation details for the repurposed `tenant_scope` values
- Exact dedupe implementation shape for search assistive-only events, so long as it stays explicit, bounded, and easy to reason about
- Exact wording of the two manual verification checks, so long as they remain calm, source-aware, and tightly scoped

</decisions>

<specifics>
## Specific Ideas

- The coherent package for Phase 8 is:
  - repurpose `tenant_scope` into an access-contract field
  - add separate `ui_surface` metadata
  - persist assistive-only outcomes only when canonical evidence is absent at a real decision boundary
  - close the phase with a balanced audit artifact plus two narrow trust-language checks
- Learn from strong support/retrieval products without imitating their SaaS shape:
  - permissions/visibility semantics should be separate from page or UI context
  - low-confidence or unresolved outcomes are useful product signals
  - not every helpful assistive lookup should become a durable failure record
  - successful systems keep public telemetry broad and durable evidence selective
- Keep developer ergonomics high:
  - one boring rule for durable gap persistence: persist when canonical evidence is absent at a decision boundary
  - one boring rule for semantics: access contract, concrete subject, entrypoint, and UI surface are different fields with different jobs
  - one boring rule for closure: backfill proof with real test evidence plus only the minimum manual semantics review
- This phase should make M010 easier by improving the quality of future gap clustering inputs, not by trying to ship the clustering product early.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope and closure posture
- `.planning/M009-ROADMAP.md` — Phase 8 goal, requirements, success criteria, and closure boundary
- `.planning/PROJECT.md` — Product posture and retrieval-first framing
- `.planning/REQUIREMENTS.md` — Active requirement state and traceability target
- `.planning/STATE.md` — Current milestone state and accumulated architectural decisions
- `.planning/vM009-vM009-MILESTONE-AUDIT.md` — Exact audit findings Phase 8 is closing

### Prior phase decisions
- `.planning/milestones/M009-phases/M009-S02-CONTEXT.md` — Operator search trust model and result semantics
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Weak-grounding and escalation semantics for grounded drafting
- `.planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md` — Original Phase 4 contract for telemetry, durable evidence, and outcome taxonomy
- `.planning/milestones/M009-phases/M009-S04/M009-S04-03-SUMMARY.md` — Existing boundary-owned persistence decisions, including the current `tenant_scope` misuse
- `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md` — Existing validation contract that Phase 8 must bring to closure

### Existing closure patterns
- `.planning/milestones/M009-phases/M009-S01/M009-S01-VERIFICATION.md` — Backfill verification pattern for requirement mapping and residual-risk framing
- `.planning/milestones/M009-phases/M009-S03/M009-S03-VERIFICATION.md` — Backfill verification pattern that mixes automation with narrow editorial/manual checks

### Product, observability, and ecosystem guidance
- `.planning/M005-RESEARCH.md` — Host-owned instrumentation, evidence-vs-telemetry separation, and Parapet-safe contract design
- `prompts/cairnloop_brand_book.md` — Calm, explicit, evidence-first product posture
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Lessons on grounded support, knowledge gaps, and support-product UX/DX
- `prompts/scoria overview for integration ideas.txt` — OpenInference adapter posture and operator-grade tracing guidance
- `prompts/parapet overview for integration ideas.txt` — Stable telemetry, cardinality safety, and durable-evidence guidance

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/retrieval/gap_event.ex` — Current durable schema and the main semantic field-shape to repair
- `lib/cairnloop/retrieval/gap_recorder.ex` — Boundary-owned persistence seam that should stay the only durable write path
- `lib/cairnloop/retrieval/telemetry.ex` — Stable bounded telemetry vocabulary that already distinguishes assistive-only outcomes
- `lib/cairnloop/web/search_modal_component.ex` — Real search boundary where assistive-only search persistence policy should become explicit
- `lib/cairnloop/automation/workers/draft_worker.ex` — Real drafting boundary that already persists weak-grounding events
- `lib/cairnloop/web/search_result_presenter.ex` — Shared trust-language vocabulary that should remain consistent with stored semantics

### Established Patterns
- Boundary-owned durable writes, not telemetry-side persistence
- Stable bounded enums and explicit contracts over flexible but confusing metadata
- Canonical Knowledge Base truth first, assistive resolved cases second
- Host-owned observability wiring and Parapet-safe label discipline
- Minimal manual review layered on top of strong automated seam coverage

### Integration Points
- Add access-contract semantics and separate UI-surface metadata to the gap-event schema and recorder path
- Extend search-boundary persistence to record assistive-only outcomes only under the locked zero-canonical rule
- Update tests so telemetry semantics, durable semantics, and verification language all converge
- Backfill `M009-S04-VERIFICATION.md`, refresh `M009-S04-VALIDATION.md`, and reconcile `.planning/REQUIREMENTS.md`

</code_context>

<deferred>
## Deferred Ideas

- Renaming `tenant_scope` to a cleaner public name such as `access_scope` in a later semver-appropriate change
- Rich retrieval debugger surfaces, analytics dashboards, or operator-facing gap review UI
- Fully normalized multi-principal scope modeling beyond the current `host_user_id` + bounded access-contract posture
- Broader editorial or UX review programs for retrieval quality beyond the two narrow closure checks in this phase
- M010 clustering/product-gap experiences themselves; this phase only improves their future evidence quality

</deferred>

---

*Phase: M009-S08*
*Context gathered: 2026-05-21*
