---
phase: 15
slug: approval-state-machine-oban-resume
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-24
---

# Phase 15 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Phase goal: risky governed actions move through durable approval, rejection, deferral,
> expiry, and resume paths with append-only decision history.
>
> Register origin: **authored at plan time** — all 5 PLAN files (15-00…15-04) carried a
> `<threat_model>` block with a STRIDE register. Mitigations were verified against the live
> implementation (not just self-reported SUMMARY claims) during this audit.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| operator (browser) → `ConversationLive` handle_event | Approve/Reject/Defer clicks cross from the UI into durable decisions; handlers must persist + enqueue, never execute inline. | Decision intent, operator reason strings |
| LiveView/host caller → `Cairnloop.Governance` approval facade | Decision requests cross from the host-trusted UI into durable workflow truth; must be guarded + reason-gated. | Approval/decision records |
| `propose/3` → durable `policy_snapshot` + `ToolActionEvent.reason` | Untrusted/internal error terms cross into durable operator-visible columns; must be humanized, never raw. | Error terms, changesets, atoms |
| Phase 14 preview render → approval surface trust facts | Live registry prose could drift from what was shown at propose time; must be snapshotted at decision time. | `rendered_consequence` / `title` prose |
| approved approval → execution (deferred to Phase 16) | An approval valid at decision time could be stale/expired at resume if policy or scope changed; must re-validate fail-closed. | Approval → execution authority |
| Oban job args (JSONB) → worker rehydration | String-keyed snapshot keys rehydrated to atoms could exhaust the atom table if attacker-influenced. | JSONB snapshot keys |
| host Oban runtime → library job enqueue | The host owns Oban; the library may run where Oban is unconfigured. | Job enqueue surface |
| `cairnloop_tool_approvals` one-active-lane | Concurrent `request_approval` calls could open >1 active lane without a DB constraint. | Approval lane uniqueness |
| approval state → operator perception | State conveyed by color alone is inaccessible/ambiguous; must pair color with text. | Status display |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-15-W0-01 | Tampering | Wave-0 tests referencing not-yet-existing modules | mitigate | Runtime aliases / `@tag :skip`; no compile-time macro expansion. Build stays `--warnings-as-errors` clean. | closed |
| T-15-01 (T-raw-terms) | Information Disclosure | `insert_blocked_proposal` reason persistence (`governance.ex`) | mitigate | `inspect(reason)` removed; humanized via `Ecto.Changeset.traverse_errors/2` (`governance.ex:404,410`). Only remaining `inspect/1` is on an exception in the `safe_enqueue` rescue log (`:91`). | closed |
| T-15-02 (T-trust-drift) | Spoofing / Integrity | Prose shown on approval surfaces | mitigate | `Preview.render/1` snapshots `rendered_consequence`/`title` at propose time (`governance.ex`, 3×); surfaces read the column only. | closed |
| T-15-03 (T-two-lane) | Tampering | `cairnloop_tool_approvals` one-active-lane | mitigate | Partial unique index `WHERE status = 'pending'` (`...add_tool_approvals.exs:31-35`, `:cairnloop_tool_approvals_one_active_lane_index`); `unique_constraint` surfaces conflict cleanly. | closed |
| T-15-04 (T-append-only) | Repudiation | `ToolActionEvent` for approval transitions | mitigate | Single append-only table; `timestamps(updated_at: false)` insert-only (`tool_action_event.ex:52`); 9 approval event types added without widening the proposal enum. | closed |
| T-15-05 (T-stale-exec) | Elevation of Privilege | `ApprovalResumeWorker` resume path | mitigate | Re-calls pure `Cairnloop.Governance.validate/3` against CURRENT context (`approval_resume_worker.ex:73`); pass → `:execution_pending` (no `run/3`); fail → `:invalidated`. | closed |
| T-15-06 (T-expired-exec) | Elevation of Privilege | Stale approval after a missed scheduled sweep | mitigate | Lazy `expires_at < now` guard fires BEFORE re-validation (`approval_resume_worker.ex:47-49`, `DateTime.before?`) — fail-closed even if `ApprovalExpiryWorker` never ran (D15-12). | closed |
| T-15-07 (T-double-enqueue) | Tampering | Duplicate resume jobs for one approval | mitigate | `unique: [period: :infinity, keys: [:approval_id]]` (`approval_resume_worker.ex:31`); `perform/1` re-checks status and no-ops if not `:pending`. | closed |
| T-15-08 (T-unbounded-atoms) | Denial of Service | JSONB snapshot key rehydration in the resume worker | mitigate | `String.to_existing_atom/1` + `ArgumentError` rescue for snapshot keys (`approval_resume_worker.ex:69,102`); never `String.to_atom/1`. | closed |
| T-15-09 (T-raw-terms) | Information Disclosure | Invalidation reason persisted to the event | mitigate | `humanize_reason/1` (traverse_errors / `Atom.to_string/1` / pass-through), never `inspect/1`; resume worker has 0 `inspect/1` calls. | closed |
| T-15-10 (T-inline-exec) | Availability / EoP | `Governance.approve/3` execution path | mitigate | `approve/3` persists decision + event then enqueues `ApprovalResumeWorker`; 0 `.run(` calls in governance approve path. | closed |
| T-15-11 (T-force-resolved) | Tampering | Forcing a decision on a resolved approval | mitigate | Every transition guards `%ToolApproval{status: :pending}` (`governance.ex:611,664,715,…`); non-pending → `{:error, :not_pending}`, writes nothing. | closed |
| T-15-12 (T-append-only) | Repudiation | Approval decision trail | mitigate | Each transition co-commits an append-only `ToolActionEvent`; full request→decision→resume trail reconstructable. | closed |
| T-15-13 (T-raw-terms) | Information Disclosure | Reasons persisted via reject/defer/expire | mitigate | Operator-supplied strings / humanized terms; no `inspect/1` on persisted reasons. | closed |
| T-15-14 (T-two-lane) | Tampering | `request_approval` racing two lanes | mitigate | Partial unique index + `unique_constraint` surfaced as `{:error, cs}`, not a crash. | closed |
| T-15-15 (T-inline-exec) | Availability | `handle_event("approve")` | mitigate | Handler calls `Cairnloop.Governance.approve/3` then reloads; 0 `.run(` calls in `conversation_live.ex`. | closed |
| T-15-16 (T-trust-drift) | Spoofing / Integrity | Approval card prose | mitigate | Card reads snapshotted `rendered_consequence`/`title` (`conversation_live.ex`, 3× reads); 0 `Preview.render/1` calls remain; NULL → structured-summary fallback. | closed |
| T-15-17 (T-raw-terms) | Information Disclosure | `history_line` / `approval_outlook` copy | mitigate | All operator copy humanized via presenter; presenter test refutes raw-term substrings. | closed |
| T-15-18 (T-color-alone) | Info Disclosure (a11y) | Status chip / affordances | mitigate | Status by text label AND color; brand token `var(--cl-primary, #A94F30)` (`conversation_live.ex:1149,…`). Live color+text pairing carried as a human-UAT visual check. | closed |
| T-15-19 (T-reason-required) | Tampering | Reject/Defer without a reason | mitigate | `decision_changeset` → `validate_reason_present/2` for `:rejected`/`:deferred` only (`tool_approval.ex:105-113`, FLOW-03); calm "A reason is required." error; nothing persisted. | closed |
| T-15-W0-02 | Information Disclosure | Repo-bound tests vs. unavailable Postgres in this workspace | accept | DB-round-trip legs written as `# REPO-UNAVAILABLE` stubs per CLAUDE.md; headless MockRepo path is the merge-blocking coverage. See Accepted Risks. | closed |
| T-15-SC | Tampering | mix / external installs (all waves: W0, 15-01…15-04) | accept | No package installs in Phase 15 (15-RESEARCH Package Legitimacy Audit: not applicable); no new deps introduced. See Accepted Risks. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-15-01 | T-15-SC (+ T-15-W0-SC) | Phase 15 introduces no new packages or external installs; supply-chain surface is unchanged. Verified across all five PLAN threat models. | szTheory (owner) | 2026-05-24 |
| AR-15-02 | T-15-W0-02 | `Cairnloop.Repo` is unavailable in this workspace; DB-round-trip test legs (partial unique index, JSONB key behavior, `expires_at`) are written but `# REPO-UNAVAILABLE`-stubbed. Headless MockRepo + source-assertion paths carry merge-blocking coverage; full DB legs run in CI. Per CLAUDE.md known environment caveat. | szTheory (owner) | 2026-05-24 |

*Accepted risks do not resurface in future audit runs.*

---

## Observations (out of Phase 15 scope — informational, not open threats)

- **Pre-existing `String.to_atom/1` usages elsewhere in `lib/`** (`web/settings_live.ex:23`,
  `knowledge_automation/workers/backfill_gap_candidates.ex:14`,
  `knowledge_automation/workers/refresh_gap_candidates.ex:14`). These are outside the Phase 15
  threat register and the approval resume path (which correctly uses `String.to_existing_atom/1`).
  They are potential unbounded-atom (DoS) vectors in their own components if their key sources are
  attacker-influenced. Recommend a follow-up review in the owning phase/milestone; **does not block
  Phase 15** (T-15-08 is closed for the resume worker).

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-24 | 22 | 22 | 0 | gsd-secure-phase (orchestrator code spot-verification; register authored at plan time) |

**Method:** Register authored at plan time (`register_authored_at_plan_time: true`) across all 5
PLAN files; per the short-circuit rule the full auditor spawn was not required. Rather than
rubber-stamp self-reported SUMMARY claims on a security-sensitive phase, the orchestrator
independently spot-verified the highest- and mid-severity mitigations against the live
implementation (DoS atom-exhaustion, EoP stale/expired-exec, inline-exec, two-lane unique index,
raw-terms humanization, double-enqueue, force-resolved guard, reason-required, trust-drift snapshot,
append-only, color+text). All verified present. Cross-checked against `15-VERIFICATION.md`
(10/10 truths) and `15-REVIEW.md` (CR-01, CR-02 both resolved pre-verification).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-24
