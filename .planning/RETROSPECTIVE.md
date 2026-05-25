# Cairnloop Retrospective

## Cross-Milestone Trends

| Milestone | Date | Phases | Plans |
|-----------|------|--------|-------|
| vM011     | 2026-05-25 | 5 | 17 |
| vM010     | 2026-05-23 | 4 | 15 |
| vM009     | 2026-05-21 | 8 | 14 |
| M005      | 2026-05-13 | 3      | 2     |
| M004      | 2026-05-12 | 2      | 2     |
| M001      | -    | -      | -     |
| M002      | -    | -      | -     |
| M003      | 2024-05-11 | 3      | 3     |

## Milestone: vM011 — AI Tool Governance & MCP Integration

**Shipped:** 2026-05-25
**Phases:** 5 (13–17) | **Plans:** 17

### What Was Built
- Compile-time-validated governed-tool contract (`use Cairnloop.Tool`) with durable `ToolProposal` + append-only `ToolActionEvent` records and fail-closed proposal pipeline.
- Humanized in-thread operator timeline with hybrid preview cards (snapshotted trust facts + best-effort live prose fallback) — zero raw Elixir terms in operator surface.
- `ToolApproval` state machine with approve/reject/defer/expiry/resume paths, one-active-lane invariant, and Oban re-validate-before-execute resume.
- First narrow approved write path (`ToolExecutionWorker` with three-layer at-most-once idempotency) and bounded `[:cairnloop, :governance, ...]` telemetry.
- Optional OpenInference-conformant evidence lane (`Cairnloop.Governance.Telemetry.Traces`) with payload-content exclusion and 7 call sites.
- Read-only MCP seam (`Cairnloop.Web.MCP.Router` + `ToolProjector`): `tools/list` + `initialize`, `-32601` for all write methods.

### What Worked
- Sequencing contract → timeline → approvals → write path → optional seams ensured each phase was additive; no phase reopened sealed earlier work.
- D15-14 (prose snapshot at propose time) was the key architectural decision that kept approval and execution surfaces stable without re-reading live config.
- DB-backed integration harness (added Phase 15) shifted 4 former Manual-Only UAT items to automated proof with zero friction.
- Three-layer at-most-once execution pattern (Oban unique + terminal guard + SHA-256 run key) was straightforward to test and prove headlessly.
- "MCP last, read-only first" reduced milestone risk — the seam was additive and required zero changes to core truth.

### What Was Inefficient
- Milestone audit was run prematurely (after only 2/5 phases); `gaps_found` required the note "this is a mid-flight audit" — set a convention to run the audit only after all phases are complete.
- MCP-01 checkbox in REQUIREMENTS.md was never updated to `[x]` after Phase 17 completed (stale doc); caught at milestone close.
- VALIDATION.md Nyquist bookkeeping for Phases 13 and 14 was never reconciled post-execution (stale `nyquist_compliant: false` despite green VERIFICATION.md).

### Patterns Established
- **Proposal-first action model:** `Governance.propose/3` is the single entrypoint; `run/3` only called by `ToolExecutionWorker` after full approval + re-validation.
- **Snapshot-then-serve:** trust facts and prose snapshotted at propose time; approval + execution surfaces read columns, never live `Preview.render`.
- **Integration harness pattern:** `test/support` test-only `Cairnloop.Repo` + `DataCase`/`ConnCase` + `priv/test_host/migrations`; fast headless suite stays DB-free; integration suite available on demand.
- **Bounded telemetry contract:** enum-only event names in `Cairnloop.Governance.Telemetry`; emitted after co-commit; no actor_id/payload in labels.
- **Additive seam pattern for optional adapters:** evidence lane and MCP Router added without touching core Governance, Approval, or Execution modules.

### Key Lessons
- Deferring the first write path until contract + timeline + approvals existed paid off: Phase 16 had zero surprises because all the invariants were already proven.
- The integration harness (docker-compose + pgvector + DataCase) should be added at the start of a milestone that will need DB-backed proof, not mid-flight.
- Run milestone audits only after all phases are complete; mid-flight audits are noise unless the goal is "do we need to change direction."
- Keep REQUIREMENTS.md traceability updated at each phase completion, not just at milestone close — the stale MCP-01 checkbox was cosmetic but reflects a gap in the update discipline.

## Milestone: M005 — Durable Auditing & SRE Observability

**Shipped:** 2026-05-13
**Phases:** 3 | **Plans:** 2

### What Was Built
- Integrated `Cairnloop.Auditor` behavior for immutable audit logging of critical operator actions.
- Integrated with Parapet to surface Service Level Indicators (SLIs) via Telemetry without cardinality explosions.
- Scaffolded SLO alerts and diagnostic runbooks via Igniter for enterprise compliance.

### What Worked
- TDD with Igniter generation provided safe, reproducible scaffolding.
- Decoupling auditing through behaviours maintained the 'SaaS in a box' philosophy.

### What Was Inefficient
- Minimal blockers encountered; however, managing parallel metrics outputs requires careful testing of telemetry payloads.

### Patterns Established
- Test-driven generation for complex setup tasks using `Igniter`.

### Key Lessons
- Providing explicit `.md` runbook generation as a default builds significant trust for enterprise adopters and positions Cairnloop as a true platform.

## Milestone: M004 — Customer Voice Activation

**Shipped:** 2026-05-12
**Phases:** 2 | **Plans:** 2

### What Was Built
- Core telemetry pipeline for conversation resolution events.
- Customer Satisfaction (CSAT) durable storage and UI integration in the widget.

### What Worked
- Firing high-signal events (`[:cairnloop, :conversation, :resolved]`) kept the package decoupled from host actions.

### Key Lessons
- Keeping UI interactions frictionless (rating dismisses prompt instantly) is crucial for support flows.

## Milestone: M003 — Deep Context Enrichment

**Shipped:** 2024-05-11
**Phases:** 3 | **Plans:** 3

### What Was Built
- Implemented robust `Cairnloop.ContextProvider` behaviour for zero API sync.
- Built a dynamic evidence rail and context pane UI in `ConversationLive`.
- Created Extensibility Components & Actions (`Cairnloop.Tool`) for custom action injection.

### What Worked
- Clear boundary definitions via behaviours enabled test-driven development.
- Splitting the work into logical slices (behaviour, UI, extensibility) kept scope contained.

### What Was Inefficient
- N/A

### Patterns Established
- Dependency injection via application env for contexts.
- Tagged tuples for resilient error handling in UI bounds.

### Key Lessons
- Deep integration requires defensive UI rendering to prevent host application data issues from crashing the embedded support dashboard.
