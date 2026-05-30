# Cairnloop Retrospective

## Cross-Milestone Trends

| Milestone | Date | Phases | Plans |
|-----------|------|--------|-------|
| vM015     | 2026-05-30 | 4 | 6 |
| vM013     | 2026-05-27 | 5 | 9 |
| vM012     | 2026-05-26 | 4 | 7 |
| vM011     | 2026-05-25 | 5 | 17 |
| vM010     | 2026-05-23 | 4 | 15 |
| vM009     | 2026-05-21 | 8 | 14 |
| M005      | 2026-05-13 | 3      | 2     |
| M004      | 2026-05-12 | 2      | 2     |
| M001      | -    | -      | -     |
| M002      | -    | -      | -     |
| M003      | 2024-05-11 | 3      | 3     |

## Milestone: vM015 — Operator Polish + Maintenance Gates

**Shipped:** 2026-05-30 (v0.2.0 → v0.2.1 → v0.2.2 on Hex.pm)
**Phases:** 4 (33–36) | **Plans:** 6

### What Was Built
- Final KnowledgeAutomation security closure (T-10-10/12/13) — pinned with regression tests; the domain already enforced the invariants, so no production logic changed.
- `SettingsLive` operator cockpit: MCP token CRUD (masking/validation, raw shown once), Notifier reachability, retrieval health (pgvector + Oban failed jobs), persisted dark-mode toggle.
- `Cairnloop.Web.AuditLogLive` (`/audit-log`), `HealthPlug` (`/health`), `MetricsPlug` (`/metrics`, Prometheus), `Auditor.list_events/1`, and governed-actions rail pagination (TECH-01).
- ExDoc guides 05 (MCP clients) + 06 (extending), `CONTRIBUTING.md`, `docs/architecture.md`.
- Migration onto the canonical szTheory release-please pipeline; integration CI suite greened and added to `release_gate`.

### What Worked
- The same-day `/gsd-audit-milestone` pass caught three broken/partial shipped features (AUDIT-01 no-op stub, OPS-01/02 unrouted plugs) and a falsely-claimed CHANGELOG (REL-01) that the phase summaries had reported as done — the audit was the safety net that turned a defective v0.2.0 into a clean v0.2.1.
- release-please made the remediation cycle cheap: a `fix:` commit on `main` cut and published v0.2.1 and v0.2.2 with zero manual tag/publish steps.
- Treating the security closure as test-only pinning (rather than refactoring already-correct domain code) honored the "seal completed phases" posture and avoided churn.

### What Was Inefficient
- **Released-with-defects:** v0.2.0 shipped AUDIT-01/OPS-01/OPS-02 broken and REL-01 unmet. Phase 35/36 were marked complete and the package was tagged/published *before* any verification — the audit ran after release, so the defects were post-release rather than caught pre-ship.
- **Verification debt (recurring):** phases 33/34/35 have no `VERIFICATION.md`; only phase 36 has a `*-VALIDATION.md`. Same "ship without GSD verification artifacts" gap flagged in prior retrospectives.
- **Inaccurate summary:** `36-01-SUMMARY.md` claimed the `[0.2.0]` CHANGELOG section was added when it was not — a summary that can't be trusted at face value undermines the audit-aggregation step.
- **Stale planning state at close (recurring):** REQUIREMENTS.md checkboxes, STATE.md "next step", and the vM015-ROADMAP progress table were all stale vs reality at close time — the exact drift pattern called out in the vM013 retrospective. Reality also advanced past STATE.md (v0.2.2 + integration-suite-green) before this close ran.
- **Lightweight-close debt (recurring):** vM014 never got a MILESTONES.md or RETROSPECTIVE.md entry (nor a trends-table row) — the same untracked-close debt vM012 incurred. Surfaced again here at vM015 close.

### Patterns Established
- **Audit-after-ship as a real gate:** `/gsd-audit-milestone` against live source (not summaries) is load-bearing — run it *before* tagging, not after. Phase summaries are claims, not evidence.
- **release-please remediation loop:** post-release defects are remediated by a `fix:` commit on `main`; the bot handles versioning, tagging, CHANGELOG, and hex publish. No manual release steps survive.
- **Test-only security closure:** when the domain already enforces an invariant, close the threat by pinning it with regression tests rather than refactoring — preserves sealed-path stability.

### Key Lessons
- **Verify before you publish.** A hex release is effectively irreversible (yank ≠ undo). Phase verification + milestone audit must precede the release tag, not follow it. v0.2.0's three broken features would have been caught by a pre-release audit.
- **Don't trust a SUMMARY's completion claims** — REL-01 was reported done and wasn't. The milestone audit must check claims against live source/tree, which is exactly what caught it.
- **The stale-state-at-close pattern is now chronic** (vM011, vM013, vM015). A phase-completion gate that flips REQUIREMENTS boxes + reconciles STATE/ROADMAP at phase close (not milestone close) is overdue.
- **Always run `/gsd-complete-milestone` end-to-end** — vM012 and vM014 both incurred lightweight-close debt (missing archives / MILESTONES / RETROSPECTIVE entries) that the next close had to absorb.

### Cost Observations
- Model mix: ~95% opus (4.7–4.8 / 1M context), small sonnet/haiku spot-checks
- Notable: the remediation arc (audit → fix → re-release → integration-suite green) spanned three same-day hex releases (0.2.0 → 0.2.1 → 0.2.2); release-please kept the marginal cost of each near zero.

## Milestone: vM013 — Support-Triggered Outbound Lifecycle

**Shipped:** 2026-05-27
**Phases:** 5 (22–26) | **Plans:** 9

### What Was Built
- Sealed `Cairnloop.Outbound.trigger/2` single-conversation facade + `system_outbound` Message type with required `template_id` metadata, immutable `Conversation` linkage, and persisted status transitions.
- Oban-backed `OutboundWorker` routing through a host-pluggable `Cairnloop.Notifier` behaviour (Chimeway-backed in v1); delivery failures resolve into a persisted `failed` status.
- Distinct outbound timeline bubble in `ConversationLive` with Pending/Sent/Failed chips + resolved-only sidebar "Send Recovery Follow-up" action.
- `Cairnloop.Outbound.bulk_trigger/2` envelope with durable `BulkEnvelope` audit row (`:submitted | :refused_cap_exceeded`), `max_batch_size = 25` fail-closed cap, per-recipient Oban `unique:` keys for at-most-once delivery, and a private `build_trigger_multi/2` shared with the sealed `trigger/2`.
- `InboxLive` checkbox-driven multi-select cockpit with sticky bottom action bar, `<.focus_wrap>` confirmation modal (snapshotted body + first-5 recipient sample + `+ N more` tail), and calm fail-closed refusal banner for oversized cohorts.
- OpenInference-conformant `Cairnloop.Outbound.Telemetry.Traces` on the disjoint `[:cairnloop, :outbound, :trace, …]` namespace + delivery-side bounded metrics on every terminal arm of `OutboundWorker.perform/1`, `trigger/2`, and `bulk_trigger/2`.
- Narrow `Cairnloop.Governance` audit READ facade for `BulkEnvelope`: `list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1` routed through `repo()` indirection with `:status` filter and hard cap; D-05 regression block pins auditor metadata key set.

### What Worked
- "Sealed `trigger/2`; new `bulk_trigger/2` envelope" pattern kept Phase 24 callers untouched and let Phase 25 add strictly additively — no churn to shipped contracts.
- D-14 negative-grep gate ("no direct `Conversation \|> where` in `inbox_live.ex`") forced cohort eligibility through the `Cairnloop.Governance` facade from day one; held cleanly through close.
- Persisting `:submitted` + `:refused_cap_exceeded` lanes on the same `BulkEnvelope` table meant the Phase 26 OBS-02 audit READ facade was a single-query read — both lanes visible from one place.
- Mirroring vM011 Phase 17 verbatim for the OI trace module (disjoint 4-segment namespace, 12-atom event registry) made Phase 26-01 essentially copy-shape-paste — zero design churn.
- Per-recipient Oban `unique:` keys `(conversation_id, template_id, bulk_envelope_id)` with `nil` envelope id for single-conversation callers let Phase 24 and Phase 25 callers share the same dedup lane without special-casing.
- CI shift-left on Phase 25 human-UAT items (commits `5bad851` → `23e700b`) closed the integration-test gap retroactively in the same milestone.

### What Was Inefficient
- REQUIREMENTS.md OUT-01..OUT-05 checkboxes were never flipped after Phase 22–24 shipped; only caught at vM013 close. Same staleness pattern flagged in vM011 retrospective — discipline gap is recurring.
- vM012 was originally "closed" by doc-flipping ROADMAP + STATE only (no archive files, no MILESTONES.md entry, no `vM012` git tag); had to backfill on 2026-05-27 during vM013 close. The lightweight close was untracked tech debt.
- Phases 22, 23, 24 didn't get standard phase directories under `.planning/phases/` (no CONTEXT.md / RESEARCH.md / SUMMARY.md per-phase folder); they shipped via inline plan + commits. Phase 25–26 went back to the full pattern. The inconsistency made the SDK `milestone.complete` think vM013 only had 2 phases.
- Code review WR-01..WR-07 surfaced a real failure-path observability honesty gap in bulk + trigger telemetry (unconditional `:stop` emission regardless of transaction outcome); the remediation was clean but the gap should have been caught at the spec stage.
- STATE.md frontmatter `progress.percent` stayed at 40% after Phase 26 verified — milestone-completion didn't reconcile it (manual SDK update needed at close).

### Patterns Established
- **Sealed-public + additive-opt:** when a sealed contract needs to support a new caller (bulk fan-out), keep the original signature byte-for-byte stable and add an optional opt (`:bulk_envelope_id`). Phase 24 callers pass `nil` and participate in the same dedup lane as Phase 25.
- **Both-lanes-one-table audit:** record both successful submissions and fail-closed refusals on the same `BulkEnvelope` table with a `status` enum, so OBS-02 reads see both lanes from one query.
- **Envelope-boundary enforcement:** fail-closed safety caps (`max_batch_size`) live at the envelope function boundary, not at the operator surface — defense-in-depth that applies to LiveView, MCP, console, and future tool callers uniformly.
- **D-14 narrow facade gate:** any web-layer read from a domain table goes through `Cairnloop.Governance.<purpose>_<read>/1`; a negative grep on the LiveView file is the test that pins this architecturally.
- **OI traces alongside, never replacing:** emit OpenInference traces in parallel with the sealed `:telemetry.span/3` bounded-metrics; disjoint 4-segment namespace prevents collisions. Mirrors vM011 Phase 17.
- **CI shift-left after the fact:** former human-UAT items that needed a real Postgres host can be backfilled into the integration test lane within the milestone close window — don't carry them as deferred forever.

### Key Lessons
- Document hygiene rule: when a phase completes, the corresponding REQUIREMENTS.md checkboxes flip immediately. The same drift pattern surfaced in vM011 (MCP-01) and vM013 (OUT-01..05) — set a phase-completion gate that fails on unchecked req boxes.
- Don't "lightweight close" a milestone by doc-flipping ROADMAP + STATE only; the missing archive files become untracked debt that surfaces at the next close. Always run `/gsd-complete-milestone` end-to-end.
- Phase-directory discipline: even fast phases benefit from a CONTEXT.md + SUMMARY.md per plan — without them, the SDK can't reconstruct phase stats at close, and the rationale at decision-time is lost.
- Failure-path observability needs to be specced at design time, not patched in code review. WR-01..WR-03 were a real bug class, not a code-style nit — the bulk + trigger telemetry was unconditionally claiming success on a failed transaction.
- "Sealed public contracts + additive opts" is a reusable pattern across milestones — vM011 used it for `Governance.propose/3`, vM012 used it for the MCP write route, vM013 used it for `Outbound.trigger/2`. Lock it in as a project norm.

### Cost Observations
- Model mix: ~95% opus (4.7 / 1M context), ~5% sonnet/haiku spot-checks
- Sessions: ~12 across 2026-05-26 → 2026-05-27
- Notable: Phase 25 ran a meaningful research → discuss → plan → execute cycle for each of the 3 plans (heavier than vM012's per-plan budget), which was justified by the architectural seam (sealed trigger + new envelope) but a useful baseline for future bulk-action phases.

## Milestone: vM012 — Public Release & MCP Write Surface

**Shipped:** 2026-05-26 (retrospective backfilled 2026-05-27)
**Phases:** 4 (18–21) | **Plans:** 7

### What Was Built
- v0.1.0 published to Hex.pm via automated `.github/workflows/release.yml` on `v*` tag push (MIT-licensed; HEX_API_KEY in GitHub Secrets).
- Runnable example host at `examples/cairnloop_example`: pgvector + host + library migrations + seed data + dashboard at `/support` + mock customer `ChatLive` at `/chat`.
- Ecto-backed OAuth Bearer seam: `cairnloop_mcp_tokens` (SHA-256 hashed), `Cairnloop.MCP` context (`issue_token` / `validate_token` / `revoke_token`), `AuthPlug` + `WellKnownPlug` (RFC 9728), protocol version `2025-11-05`.
- MCP `tools/call` routed through `Cairnloop.Governance.propose/3` with `origin: :mcp`, `mcp_token_id`, and `tool_params`; JSON-RPC outcomes mapped to standard codes; idempotency-key reuse returns the same proposal; integration tests pass against real pgvector.

### What Worked
- Automating the initial publish via CI (rather than a manual `mix hex.publish`) made the release reproducible from day one.
- MCP write surface staying inside the `Governance.propose/3` proposal-first contract preserved vM011's three-layer at-most-once idempotency for free — no MCP-specific execution semantics.
- Documenting the `cairnloop_dashboard` macro `live/3` import caveat in the example app's README turned a potential adopter footgun into an explicit, copy-pasteable workaround.

### What Was Inefficient
- vM012 was closed by doc-flipping ROADMAP + STATE only — no archive files, no MILESTONES.md entry, no `vM012` git tag. This created untracked debt that surfaced at vM013 close and required a backfill operation.
- No retrospective written at close; this entry is reconstructed from commits + phase SUMMARYs after the fact.

### Patterns Established
- **Tag-driven release pipeline:** any `v*` tag push triggers package + docs publish via GitHub Actions. Reusable for all future minor/major releases.
- **`actor_id` prefix convention for MCP-originated proposals:** `mcp_token:<id>` keeps audit reconstruction unambiguous.
- **Example app as integration documentation:** a runnable host app is more honest documentation than prose — adopters can `mix setup` and see the integration work end-to-end.

### Key Lessons
- Always run `/gsd-complete-milestone` end-to-end; doc-flipping is a recipe for hidden debt that compounds at the next close.
- The published Hex package + example app together form a much stronger adopter story than either alone — keep both as a coordinated release artifact for future versions.

### Cost Observations
- Sessions: ~5 across 2026-05-25 → 2026-05-26
- Notable: Phase 19 (example app) had real Phoenix 1.7 dependency caveats (heroicons, dashboard macro) that consumed more cycles than expected; the documented workarounds were the actual deliverable.

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
