---
milestone: vM011
audited: 2026-05-24T15:27:25Z
status: gaps_found
verdict: incomplete-milestone  # gaps are UNBUILT phases (15–17), not defects in delivered work
scores:
  requirements: 6/15        # satisfied / total v1 requirements
  phases: 2/5               # verified-passed / total phases
  integration: 1/1          # built E2E slices wired clean / built E2E slices
  flows: 1/1                # complete user-visible flows that exist / exist
built_phases: [13, 14]
unbuilt_phases: [15, 16, 17]
gaps:
  requirements:
    - id: "FLOW-03"
      status: "unsatisfied"
      phase: "Phase 15 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 15 directory does not exist; reject/defer-with-persisted-reason not built."
    - id: "APRV-01"
      status: "unsatisfied"
      phase: "Phase 15 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Durable approval record / no-inline-execution not built (Phase 15)."
    - id: "APRV-02"
      status: "unsatisfied"
      phase: "Phase 15 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Oban resume-with-revalidation not built (Phase 15)."
    - id: "APRV-03"
      status: "unsatisfied"
      phase: "Phase 15 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Approval expiry/invalidation + timeline state not built (Phase 15)."
    - id: "APRV-04"
      status: "unsatisfied"
      phase: "Phase 15 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "One-active-approval-lane + append-only decision events not built (Phase 15)."
    - id: "ACT-01"
      status: "unsatisfied"
      phase: "Phase 16 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "First narrow approved write workflow not built (Phase 16)."
    - id: "OBS-01"
      status: "unsatisfied"
      phase: "Phase 16 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Bounded governed-action telemetry across lifecycle not built (Phase 16). NOTE: Phase 13 shipped a bounded Governance.Telemetry seam for the proposal event only — full lifecycle coverage is Phase 16."
    - id: "OBS-02"
      status: "unsatisfied"
      phase: "Phase 16 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Optional audit/evidence attribution (who approved/denied + policy snapshot) not built (Phase 16)."
    - id: "MCP-01"
      status: "unsatisfied"
      phase: "Phase 17 (not started)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Read-only MCP seam over governed-tool contract not built (Phase 17). NOTE: Phase 13 deliberately kept Tool.Spec a pure defstruct as the MCP-01 projection point (D-03) — the seam is reserved but not exposed."
  integration: []   # no broken cross-phase wiring among built phases
  flows: []         # no broken flows among built slices
tech_debt:
  - phase: 13-governed-tool-contract-proposal-records
    items:
      - "WR-01 carry-forward: :needs_input blocked path persists inspect(changeset) (raw #Ecto.Changeset<...>) into policy_snapshot + ToolActionEvent.reason via sealed insert_blocked_proposal/10 (governance.ex:313). Re-confirmed by integration checker. Resolve when Phase 15 reopens propose/approval persistence: humanize via Ecto.Changeset.traverse_errors and add a test asserting policy_snapshot has no '#Ecto.Changeset<' substring. (D-16 additive promotion already recorded as Phase 15 guardrail in STATE.md.)"
      - "WR-05 (pre-existing, outside Phase 13 scope): bare `rescue _ -> :ok` in Oban insert at application.ex:45-49 silently swallows a failed Oban job enqueue."
      - "Stale Nyquist bookkeeping: 13-VALIDATION.md is still status:draft / nyquist_compliant:false with all task rows ⬜ pending, despite 13-VERIFICATION.md showing 108 tests green. Doc never updated post-execution. Run /gsd:validate-phase 13 to reconcile (likely closes retroactively, no new code)."
  - phase: 14-operator-timeline-preview-surface
    items:
      - "Stale Nyquist bookkeeping: 14-VALIDATION.md is still status:draft / nyquist_compliant:false with all task rows ⬜ pending, despite 14-VERIFICATION.md showing full FLOW-01/FLOW-02 coverage green (367 tests). Run /gsd:validate-phase 14 to reconcile."
      - "AR-14-02 (accepted risk): governed-actions rail is a bounded per-conversation list with no pagination. Re-evaluate at Phase 16 when write actions increase proposal volume."
  - phase: cross-cutting
    items:
      - "Root SECURITY.md is Phase 10's verification and still carries 5 OPEN threats (T-10-09..T-10-13) — pre-existing debt from vM010, untouched by vM011. Phase 14's own security audit is clean (14-SECURITY.md: threats_open 0)."
      - "REPO-UNAVAILABLE: Cairnloop.Repo is unavailable in this workspace, so DB round-trip proofs (JSONB atom→string key survival, real migration execution, constraint enforcement) are covered by MockRepo + string-keyed fixtures + # REPO-UNAVAILABLE stubs. Documented environment caveat, not a defect — run repo-backed lanes when available for stronger live proof."
nyquist:
  compliant_phases: []
  partial_phases: [13, 14]   # VALIDATION.md exists but nyquist_compliant:false (stale draft; substance is green per VERIFICATION)
  missing_phases: [15, 16, 17]  # unbuilt — no VALIDATION.md
  overall: partial
---

# vM011 — Milestone Audit

**Milestone:** AI Tool Governance & MCP Integration
**Audited:** 2026-05-24
**Status:** ⚠ `gaps_found` — but the gaps are the **unbuilt remainder of an in-progress milestone**, not defects in delivered work.

## Headline

This milestone is **40% built (2 of 5 phases)**. Phases 13 and 14 are complete, verified, and
cleanly integrated. Phases 15, 16, and 17 **have not been started** (no directories, no code). The
milestone has not yet reached its definition of done because most of its scope is still ahead.

**This is not a failed audit of finished work — it is a premature completion audit of an
in-flight milestone.** Everything that has been built passes. The correct next action is to keep
building (Phase 15 next), not to open closure phases.

| Dimension | Score | Read |
|-----------|-------|------|
| Requirements satisfied | **6 / 15** | All 9 unsatisfied belong to unbuilt phases 15–17 |
| Phases verified-passed | **2 / 5** | 13 (20/20), 14 (8/8); 15–17 not started |
| Built E2E slices wired clean | **1 / 1** | Propose → durable record → operator timeline |
| Broken cross-phase wiring | **0** | No dangling refs between built phases |
| Orphaned requirements | **0** | Every built-phase requirement is verified |

## Requirements Coverage (3-source cross-reference)

Sources: `REQUIREMENTS.md` traceability + checkbox · phase `*-VERIFICATION.md` requirements table ·
`*-SUMMARY.md` decisions/provides evidence. (This project's SUMMARY frontmatter encodes requirement
coverage in `decisions`/`dependency_graph`, not a `requirements-completed` field; verification tables
are the authoritative per-requirement source.)

| REQ-ID | Phase | VERIFICATION | SUMMARY evidence | REQUIREMENTS.md | **Final** |
|--------|-------|--------------|------------------|-----------------|-----------|
| TOOL-01 | 13 | passed · SATISFIED | 13-01 (Tool/Spec, compile-time enums) | `[x]` | ✅ satisfied |
| TOOL-02 | 13 | passed · SATISFIED | 13-03 (execute_tool → propose/3) | `[x]` | ✅ satisfied |
| TOOL-03 | 13 | passed · SATISFIED | 13-02 (validate/3 fail-closed) | `[x]` | ✅ satisfied |
| TOOL-04 | 13 | passed · SATISFIED | 13-02 (durable proposal + append-only events) | `[x]` | ✅ satisfied |
| FLOW-01 | 14 | passed · SATISFIED | 14-01/14-03 (facade + rail timeline) | `[x]` | ✅ satisfied |
| FLOW-02 | 14 | passed · SATISFIED | 14-01/14-02 (presenter + preview card) | `[x]` | ✅ satisfied |
| FLOW-03 | 15 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| APRV-01 | 15 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| APRV-02 | 15 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| APRV-03 | 15 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| APRV-04 | 15 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| ACT-01 | 16 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| OBS-01 | 16 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| OBS-02 | 16 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |
| MCP-01 | 17 | missing | — | `[ ]` | ❌ unsatisfied (unbuilt) |

**FAIL gate:** 9 `unsatisfied` requirements → milestone status forced to `gaps_found`.
**Orphan detection:** none. No requirement is present in traceability but missing from a phase that
was supposed to cover it; the 9 unsatisfied requirements are *assigned-to-unbuilt-phases*, a distinct
and expected category for an in-progress milestone.

## Phase Verification Summary

| Phase | Status | Score | Notes |
|-------|--------|-------|-------|
| 13 — Governed Tool Contract & Proposal Records | ✅ passed | 20/20 truths | All artifacts exist/substantive/wired; CR-01 & CR-02 fixed w/ regression tests |
| 14 — Operator Timeline & Preview Surface | ✅ passed | 8/8 truths | Read-only timeline + preview card; CR-01 fixed; WR-01 recorded carry-forward |
| 15 — Approval State Machine & Oban Resume | ⛔ not started | — | No directory/code |
| 16 — First Approved Write Path & Telemetry | ⛔ not started | — | No directory/code |
| 17 — Optional Evidence Lane & Read-Only MCP Seam | ⛔ not started | — | No directory/code |

## Cross-Phase Integration (built slice only)

Independent integration check (gsd-integration-checker) over the Phase 13 → 14 seam:

- **Status: wired_clean.** 14/14 cross-phase links WIRED, 0 broken, 0 orphaned exports.
- **E2E flow (the only complete user-visible slice):** Operator clicks "Propose" →
  `execute_tool` threads server-trusted `conversation_id` → `Governance.propose/3` validates
  fail-closed and co-commits `ToolProposal` + `ToolActionEvent` (both valid AND blocked paths carry
  `conversation_id`; idempotency canonical map excludes it) → conversation reload reads via the
  narrow `Governance.list_proposals_for_conversation/1` facade (no direct schema query in web layer)
  → `governed_action_card/1` renders all 4 statuses humanized (no raw Elixir terms inline; raw only
  behind `<details>`). **Slice holds end-to-end.**
- **Build:** `mix compile --warnings-as-errors` clean; targeted suites green; full suite 367 tests /
  1 failure = pre-existing `Cairnloop.Automation.DraftTest` baseline (unrelated to vM011).
- The full milestone E2E (propose → **approve** → **execute write** → **evidence/MCP**) cannot exist
  yet because phases 15–17 are unbuilt; this was correctly **not** penalized.

## Nyquist Compliance (discovery only)

| Phase | VALIDATION.md | `nyquist_compliant` | Classification | Action |
|-------|---------------|---------------------|----------------|--------|
| 13 | exists (draft) | false | **PARTIAL** | `/gsd:validate-phase 13` — reconcile stale doc (108 tests already green) |
| 14 | exists (draft) | false | **PARTIAL** | `/gsd:validate-phase 14` — reconcile stale doc (full coverage already green) |
| 15 | missing | — | MISSING (unbuilt) | created during Phase 15 planning |
| 16 | missing | — | MISSING (unbuilt) | created during Phase 16 planning |
| 17 | missing | — | MISSING (unbuilt) | created during Phase 17 planning |

Both built phases' VALIDATION.md files are **planning-time strategy drafts** whose task rows were
never flipped to ✅ and whose `nyquist_compliant` was never set to `true` post-execution — even though
the authoritative VERIFICATION.md reports show the full Wave-0-first test suites written and passing.
This is **stale bookkeeping, not a coverage hole** (contrast Phase 10, whose validation doc *was*
reconciled — commit `5174db8`). Running `/gsd:validate-phase 13` and `14` will most likely close
these retroactively with no new code.

## Tech Debt Ledger

**Phase 13**
- **WR-01 (carry-forward):** `:needs_input` blocked path persists `inspect(changeset)` (raw
  `#Ecto.Changeset<...>`) into `policy_snapshot` + `ToolActionEvent.reason` via the sealed
  `insert_blocked_proposal/10` (governance.ex:313). Never shown inline to operators (only behind the
  "Raw policy snapshot" expander; flash/inline use `reason_label/1`). Re-confirmed by the integration
  checker. **Resolve when Phase 15 reopens propose/approval persistence:** humanize via
  `Ecto.Changeset.traverse_errors` (never `inspect/1`) + add a test asserting `policy_snapshot`
  contains no `#Ecto.Changeset<` substring. Already recorded as a Phase 15 guardrail in STATE.md.
- **WR-05 (pre-existing):** bare `rescue _ -> :ok` in Oban insert (application.ex:45-49) silently
  swallows a failed enqueue. Outside Phase 13 scope.

**Phase 14**
- **AR-14-02 (accepted risk):** governed-actions rail is a bounded per-conversation list with no
  pagination — re-evaluate at Phase 16 when write actions raise proposal volume.

**Cross-cutting**
- Root `SECURITY.md` is **Phase 10's** verification and still carries **5 OPEN threats
  (T-10-09..T-10-13)** — pre-existing vM010 debt, untouched by this milestone. (Phase 14's own
  `14-SECURITY.md` is clean: `threats_open: 0`.)
- **REPO-UNAVAILABLE:** DB round-trip proofs are MockRepo/fixture/stub-covered per the documented
  workspace caveat — run repo-backed lanes when available for stronger live proof.

## Verdict & Path Forward

`gaps_found` — driven entirely by the 9 unbuilt-phase requirements. **No remediation phases are
needed for what's been delivered.** The milestone is simply mid-flight. Resume normal execution at
Phase 15, then 16, then 17, and re-run this audit after Phase 17 verifies.

The only *inline* cleanups worth doing now are the two zero-risk bookkeeping reconciliations
(`/gsd:validate-phase 13` and `14`); WR-01 is best resolved inside Phase 15 (where the sealed persist
path legitimately reopens), exactly as its carry-forward guardrail prescribes.

---
_Audited by Claude (gsd-audit-milestone orchestrator) · 2026-05-24T15:27:25Z_
