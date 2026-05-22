# Phase M009-S03 Verification

## Scope

This artifact backfills the execution proof that Phase M009-S03 did not receive when grounded
drafting originally shipped. It closes `M009-REQ-06` and `M009-REQ-07` through a fresh rerun of
the focused Phase 3 suite plus one attempted realism lane, while preserving the difference between
what was proven by fresh execution on 2026-05-21 and what is inferred from implementation review.

## Requirement Coverage Summary

| Requirement | Closure posture | Fresh proof | Notes |
|-------------|-----------------|-------------|-------|
| `M009-REQ-06` | Closed with residual verification risk | Focused suite rerun passed; realism lane attempted but environment-blocked | Retrieval-to-draft contract, persistence, and worker policy seams are exercised by tests; no live DB-backed proof completed in this shell |
| `M009-REQ-07` | Closed with residual verification risk | Focused suite rerun passed; manual editorial checks completed from implementation and LiveView test review | Evidence rail, clarification copy, escalation copy, and citation semantics are covered by code/tests, with realism lane still blocked |

## M009-REQ-06

### Implementation evidence

- `lib/cairnloop/retrieval.ex`
  `ground_for_draft/2` normalizes draft context, performs canonical-first retrieval, preserves
  canonical and assistive evidence separately, records diagnostics, and returns explicit grounding
  assessment states for `:strong`, `:clarification`, and `:escalation`.
- `lib/cairnloop/automation/scoria_engine.ex`
  The engine no longer performs its own lookup. It converts the grounding bundle into a structured
  proposal with `proposal_type`, `operator_summary`, `customer_reply`, evidence, grounding
  metadata, and bounded clarification attempts.
- `lib/cairnloop/automation/workers/draft_worker.ex`
  The worker fetches grounding before proposal generation, enforces the one-clarification-then-
  escalate rule, records weak-grounding gap signals, and persists reply / clarification /
  escalation branches through one durable draft path.
- `lib/cairnloop/automation.ex`
  `create_draft/2` persists the structured proposal as a durable record instead of a raw content
  blob, keeping the operator-facing reply text aligned with stored grounding metadata.
- `.planning/milestones/M009-phases/M009-S03/M009-S03-01-SUMMARY.md`
  Confirms the original implementation added `ground_for_draft/2`, structured proposals, draft
  persistence, and explicit branching as the core backend contract for grounded drafting.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs test/cairnloop/web/conversation_live_test.exs`
- Observed outcome: `39 tests, 0 failures` in `0.8 seconds`.
- Historical note: this did not reproduce the 2026-05-20 `35 tests, 0 failures` result from the
  original summary. The current observed count is higher, so this artifact records the actual
  2026-05-21 result instead of normalizing it.
- Startup caveat preserved exactly once as required:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- Coverage proved by this rerun includes:
  `test/cairnloop/retrieval_test.exs` for strong canonical grounding, clarification-limit
  escalation, weak-grounding diagnostics, assistive-only behavior, empty recall, and retrieval
  exception classification.
- Coverage proved by this rerun also includes:
  `test/cairnloop/automation/scoria_engine_test.exs`,
  `test/cairnloop/automation/workers/draft_worker_test.exs`, and
  `test/cairnloop/automation_test.exs` for structured proposal generation, worker branching, and
  durable draft persistence.

### Manual checks

- Clarification-question tone remains bounded and calm in both implementation and tests:
  `ScoriaEngine.generate_draft/2` asks one narrow follow-up question,
  "Before I confirm the next step, could you share the specific error message or screen you see
  when this happens?", and the clarification path increments the bounded attempt counter rather
  than looping silently.
- Escalation behavior stays explicit and non-defensive:
  the escalation reply says, "I don't have enough verified guidance to answer confidently..."
  and the operator summary tells the reviewer to escalate instead of bluffing.
- The grounded-drafting contract keeps `Knowledge Base` evidence separate from `Resolved case`
  evidence all the way through retrieval and persisted evidence snapshots, rather than flattening
  both into one generic support signal.
- Supporting evidence is stored beside the draft and not merged into the editable reply body; the
  operator-facing `customer_reply` remains distinct from stored evidence and grounding metadata.

### Residual risk

The strongest proof here is still the focused suite plus implementation review, not a completed
DB-backed realism run. The contract is well-covered at the seam level, but fresh proof of
production-like retrieval queries in this shell remained blocked by repo/runtime setup.

## M009-REQ-07

### Implementation evidence

- `lib/cairnloop/web/conversation_live.ex`
  The draft audit rail renders `proposal_type`, `operator_summary`, grounding reason copy,
  `customer_reply`, and an always-visible `Supporting evidence` section separate from the editable
  reply composer.
- `lib/cairnloop/web/conversation_live.ex`
  `proposal_state_label/1` and `draft_operator_summary/1` make clarification and escalation
  states explicit instead of presenting them as ordinary grounded replies.
- `lib/cairnloop/web/conversation_live.ex`
  Each evidence row is rendered through `SearchResultPresenter`, which preserves `Knowledge Base`
  versus `Resolved case` and `Canonical guidance` versus `Supporting evidence` semantics.
- `.planning/milestones/M009-phases/M009-S03/M009-S03-02-SUMMARY.md`
  Confirms the Phase 3 UI work deliberately reused the search trust model in the evidence rail and
  added explicit clarification / escalation presentation.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/automation_test.exs test/cairnloop/web/conversation_live_test.exs`
- Observed outcome: `39 tests, 0 failures` in `0.8 seconds`, with the same `Chimeway.Repo`
  missing-`:database` startup noise logged before the suite executed.
- `test/cairnloop/web/conversation_live_test.exs` asserts the evidence rail renders:
  `Grounding note`, `Supporting evidence`, `Knowledge Base`, `Resolved case`,
  `Canonical guidance`, and the action controls without leaking evidence into the composer text.
- The same test file also asserts clarification and escalation appear as explicit operator states,
  including the bounded clarification prompt and the escalation copy shown to operators.

### Manual checks

- Clarification copy is bounded, calm, and not falsely confident:
  the clarification branch asks for one specific missing detail rather than pretending the answer is
  ready.
- Escalation copy is explicit and non-defensive:
  the customer-facing copy says the system lacks enough verified guidance, and the operator summary
  instructs escalation instead of hedging with generic retry language.
- `Knowledge Base` and `Resolved case` remain visually and semantically distinct, and
  `Canonical guidance` remains distinct from `Supporting evidence`, because the rail renders source
  and trust labels separately on each evidence item.
- Supporting evidence is visible by default in the rail, while the editable reply body continues to
  use only `Draft.reply_content(draft)` in the separate composer flow.

### Residual risk

The operator-facing proof is still mostly seam-level and LiveView-test driven. The current shell
did not complete a realism lane that mounts the full retrieval-backed draft flow against a working
repo/runtime configuration, so the editorial semantics are closed with caveat rather than treated
as perfect end-to-end proof.

## Realistic Proof Lane

### Attempted command

`MIX_ENV=test mix run -e 'Application.put_env(:cairnloop, :repo, Cairnloop.Repo); IO.inspect(Cairnloop.Retrieval.ground_for_draft(%{conversation_id: 1, query: "billing export", clarification_attempts: 0}, host_surface: "conversation", host_user_id: "phase-7-proof"), label: "grounding_bundle")'`

### Observed outcome

- Date: `2026-05-21`
- Outcome: blocked before product behavior was exercised.
- The shell emitted the same `Chimeway.Repo` missing-`:database` startup noise seen in test runs,
  then failed with:
  `** (UndefinedFunctionError) function Cairnloop.Repo.all/1 is undefined (module Cairnloop.Repo is not available)`
- This is recorded as an environment-blocked proof lane, not as a product defect in the grounded
  drafting contract itself. The command attempted the exact required realism lane first and no new
  integration harness was introduced.

### Manual editorial closure checks

- Clarification-question tone: passes bounded-tone review from current implementation and tests.
  It asks one focused follow-up and does not present itself as a confident answer.
- Escalation copy: passes explicitness review from current implementation and tests.
  It is direct about insufficient verified guidance and avoids defensive language.
- `Knowledge Base` / `Resolved case` and `Canonical guidance` / `Supporting evidence` distinction:
  passes based on the current evidence rail rendering path and LiveView assertions.
- Supporting evidence visibility without leaking into editable reply body:
  passes based on `draft_audit_card/1` rendering evidence in the rail and keeping the composer text
  on the separate `Draft.reply_content(draft)` path.

### Residual risk impact

This blocked realism lane leaves residual verification risk because the freshest proof remains a
focused suite plus implementation review. It does not, by itself, show hidden weak grounding,
repeated clarification looping, collapsed canonical-versus-assistive semantics, or evidence
leaking into the editable customer reply, so this phase can close with residual verification risk
rather than "cannot close".

## Backfill Summary

This is a Phase 7 closure artifact for Phase 3. Freshly proven on `2026-05-21`: the focused
retrieval, engine, worker, persistence, and LiveView suite passed with `39 tests, 0 failures`, and
the realism lane was attempted exactly as planned. Inferred from implementation review rather than
fresh end-to-end execution: the full operator editing experience under a working repo-backed
runtime. Closure posture: closed with residual verification risk.
