---
milestone: vM015
title: Operator Polish + Maintenance Gates (v0.2.0)
audited: 2026-05-29
status: gaps_found
scores:
  requirements: "13/17 satisfied · 3 broken/partial (AUDIT-01, OPS-01, OPS-02) · 1 falsely-claimed (REL-01)"
  phases: "4/4 executed; 0/4 carry a VERIFICATION.md"
  integration: "BROKEN — audit-event surfacing and OPS endpoints do not connect"
  flows: "2 broken E2E flows shipped in v0.2.0 (operator audit timeline; adopter /health + /metrics)"
build:
  compile_warnings_as_errors: "PASS (exit 0, this session)"
  mix_test: "not run (Repo-dependent; confirm in CI)"
release:
  tag: "v0.2.0 created + pushed (per 36-01-SUMMARY) — release ALREADY SHIPPED"
  changelog_0_2_0: "MISSING — no `## [0.2.0]` section exists despite 36-01-SUMMARY claiming it was added"
gaps:
  blockers:
    - id: "AUDIT-01"
      phase: 35
      status: "partial/broken"
      evidence: "AuditLogLive (47 lines) has NO search and NO filter (requirement: 'searchable, filterable timeline'); reads Cairnloop.Auditor (NoOp default → []) so it renders 'No audit events found.' out of the box; emits raw inspect(actor_id) + <pre>inspect(metadata) to operators (brand violation). audit_log_live.ex:5-6,33,36"
    - id: "OPS-01 / OPS-02"
      phase: 35
      status: "partial/broken"
      evidence: "HealthPlug/MetricsPlug exist and compile, but are mounted in NO router (lib router.ex, MCP router, example app) and NO guide documents a mount recipe (contrast the documented MCP router). Adopters cannot reach /health or /metrics as shipped."
    - id: "REL-01"
      phase: 36
      status: "unsatisfied (falsely claimed complete)"
      evidence: "CHANGELOG.md has no `## [0.2.0]` heading and no vM015 (33-35) entries; [Unreleased] still holds 27-32. 36-01-SUMMARY.md:18 claims the [0.2.0] section was added — it was not. v0.2.0 shipped with an inaccurate changelog."
    - id: "MISSING-VERIFICATION"
      phase: "33,34,35"
      status: "process-blocker"
      evidence: "No *-VERIFICATION.md for any executed vM015 phase (verification artifacts exist only through phase 32). Phases were marked complete via chore commits, and v0.2.0 was released, without verification."
  concerns:
    - "Released-with-defects: v0.2.0 is already tagged/pushed, so AUDIT-01/OPS-01/OPS-02/REL-01 are POST-RELEASE defects — remediate in 0.2.1, not pre-release."
    - "Facade-boundary drift: AuditLogLive bypasses Cairnloop.Governance; it neither surfaces governance ToolActionEvents nor uses the facade."
    - "Stale planning state: REQUIREMENTS.md traceability marks SET-*/AUDIT-01/OPS-*/TECH-01/DOC-*/REL-* as 'Pending' though their phases executed; STATE.md still says next step = execute phase 36 (already done); vM015-ROADMAP Progress table shows phases Not started."
    - "36-01-SUMMARY.md contains at least one inaccurate completion claim (CHANGELOG) — treat its other claims (e.g. 'mix docs successful') as needing independent confirmation."
nyquist:
  compliant_phases: 0
  partial_phases: 1   # phase 36 has a 36-VALIDATION.md (doc/manual checks)
  missing_phases: [33, 34, 35]
  overall: "MISSING for executed code phases 33-35"
tech_debt:
  - phase: repo-root
    items:
      - "Tracked junk: test.txt, test2.txt"
      - "Untracked scratch: .commit-hash, .commit-hash-task2, .git-check.sh, .git-check-task2.sh, CHECK.md, test_health.exs"
  - phase: planning
    items:
      - "Uncommitted churn: D 33/PLAN.md, ?? 33-INDEX.md, ?? 35 plans/patterns/research, ?? 36 dir, modified ROADMAP/STATE/execute_init"
      - "REQUIREMENTS.md traceability + STATE.md + vM015-ROADMAP Progress table all stale vs reality"
---

# Milestone vM015 Audit — Operator Polish + Maintenance Gates (v0.2.0)

**Audited:** 2026-05-29 · **Verdict:** ⚠️ **GAPS FOUND — v0.2.0 shipped, but with broken Phase-35 features, a missing CHANGELOG entry, and zero phase verifications**

> **Audit integrity note.** Earlier drafts of this file were wrong (one claimed "no code
> exists"; one invented a "Deletion Execution Engine") — both were written from cancelled /
> mis-rendered tool output and have been discarded. Everything below is verified first-hand
> against live source, the real REQUIREMENTS.md, phase summaries, the git tree, and a
> `gsd-integration-checker` pass. The `mix compile --warnings-as-errors` result (PASS) is from
> an actual run this session (exit 0).

---

## Milestone Scope & Requirement Status (17 requirements)

| Req | Phase | Requirement | Real status |
|-----|-------|-------------|-------------|
| SEC-01/02/03 | 33 | KnowledgeAutomation rejects published-target / spoofed / caller-supplied-grounding inputs | ✅ executed (commit 27c6f35); traceability=Complete — *not re-verified line-by-line; no VERIFICATION.md* |
| SET-01..04 | 34 | SettingsLive: MCP token CRUD, notifier health, retrieval health, dark mode | ✅ executed (c8da351, 69d0351) — *not independently re-verified; no VERIFICATION.md* |
| AUDIT-01 | 35 | Searchable, filterable timeline of Auditor events | 🔴 **broken/partial** — no search, no filter, empty by default, raw `inspect` copy |
| OPS-01 | 35 | `/health` HTTP endpoint reachable by adopters | 🔴 **broken/partial** — plug exists, mounted nowhere, undocumented |
| OPS-02 | 35 | `/metrics` HTTP endpoint | 🔴 **broken/partial** — same as OPS-01 |
| TECH-01 | 35 | Governed-actions rail pagination | ✅ executed (f281122; `governance.ex:993` `:limit` + `load_more_actions`) |
| DOC-01..04 | 36 | guides 05/06, CONTRIBUTING.md, docs/architecture.md | ✅ files exist & tracked |
| REL-01 | 36 | CHANGELOG updated for 0.2.0 | 🔴 **not done** (no `## [0.2.0]`) — *summary falsely claims done* |
| REL-02 | 36 | v0.2.0 tag cut + pushed | ✅ tag exists; pushed per summary (release pipeline triggered) |

**Net: 13/17 satisfied; AUDIT-01, OPS-01, OPS-02 broken/partial; REL-01 not done.**

---

## Cross-Phase Integration — BROKEN (verified against live code)

### 🔴 AUDIT-01 — audit log is non-functional out of the box
`lib/cairnloop/web/audit_log_live.ex` (the whole module, 47 lines):
- `mount/3` reads `Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)` then
  `auditor.list_events([])`. `Cairnloop.Auditor.NoOp.list_events/1` returns `[]`
  (`lib/cairnloop/auditor.ex:38`), and **no `:cairnloop, :auditor` is configured anywhere**
  (incl. the example app) → the UI always shows "No audit events found."
- **No search, no filter** — the requirement demands a "searchable, filterable timeline"; the
  view is a static table with no `handle_event`/query params.
- **Brand violation** — renders `inspect(actor_id)` and `<pre>inspect(metadata, pretty: true)`
  to operators (CLAUDE.md/brand: never raw Elixir terms/JSON outside an explicit expander).
- **Facade bypass** — does not go through `Cairnloop.Governance`, and never surfaces the durable
  `ToolActionEvent` rows the governance/execution pipeline actually writes
  (`tool_execution_worker.ex:227`, `governance.ex:382,527`). The audit surface and the audit
  truth are disconnected.

### 🔴 OPS-01 / OPS-02 — health & metrics unreachable
`HealthPlug` (`web/health_plug.ex`, 20 lines) and `MetricsPlug` (`web/metrics_plug.ex`, 32
lines) compile but are mounted in **no router** and **no guide documents how to mount them**.
The MCP router, by contrast, ships a documented `forward "/mcp", …` recipe — OPS has no
equivalent. As shipped, an adopter cannot poll `/health` or scrape `/metrics`.

---

## What is solid

- **Build:** `mix compile --warnings-as-errors` → **PASS (exit 0)** this session.
- **TECH-01:** rail pagination implemented and facade-backed.
- **DOC-01..04:** guides 05/06, `CONTRIBUTING.md`, `docs/architecture.md` exist and are tracked.
- **SEC-01/02/03, SET-01..04:** executed and commit-backed (not independently re-verified here;
  no VERIFICATION.md exists to lean on).
- **Governance/execution substrate (prior milestones):** healthy — 601-line `ToolExecutionWorker`
  with three-layer at-most-once (Oban unique + terminal guard + SHA-256 `run_key` + partial
  unique index), co-committing `ToolActionEvent`. This is exactly the data AUDIT-01 should have
  surfaced but doesn't.

---

## Process / Hygiene Findings

- **No VERIFICATION.md for phases 33/34/35** — they were marked complete (and the package
  released) without the GSD verification artifacts this audit normally aggregates.
- **Inaccurate summary** — `36-01-SUMMARY.md:18` claims the CHANGELOG `[0.2.0]` section was
  added; it was not. Other claims in that summary ("mix docs successful", "human approval")
  should be independently confirmed.
- **Stale state everywhere** — REQUIREMENTS.md traceability marks SET/AUDIT/OPS/TECH/DOC/REL as
  "Pending"; STATE.md says next step = execute phase 36 (already done); vM015-ROADMAP Progress
  table shows phases Not started.
- **Repo-root debris** — tracked junk `test.txt`/`test2.txt`; untracked scratch
  `.commit-hash(.task2)`, `.git-check(.task2).sh`, `CHECK.md`, `test_health.exs`.
- **Nyquist** — only phase 36 has a VALIDATION.md (doc/manual checks); executed code phases
  33-35 have none.

---

## Verdict & Recommended Route

**⚠️ GAPS FOUND — and v0.2.0 is already released, so these are post-release defects.** The
milestone delivered SEC/SET/TECH/DOC and a clean compile, but **two of the headline Phase-35
operability features (AUDIT-01 audit log; OPS-01/02 health & metrics) do not work as shipped**,
the **CHANGELOG was never updated for 0.2.0** (contrary to the summary), and **no code phase was
ever verified**.

Recommended next actions (a **0.2.1 remediation** milestone/phase):
1. **Fix AUDIT-01:** add a Governance facade timeline read over `ToolActionEvent`
   (all-events, paginated) OR ship a default `Auditor` that surfaces governance events; add the
   required search + filter; humanize actor/metadata (drop raw `inspect`).
2. **Fix OPS-01/02:** mount `HealthPlug`/`MetricsPlug` in `Cairnloop.Router` and/or document +
   demonstrate host mounting in the example app and a guide.
3. **Fix REL-01:** write the real `## [0.2.0]` CHANGELOG section (Security closure, Settings
   surface, Audit & Ops, metrics) and correct `36-01-SUMMARY.md`.
4. **Retroactively verify 33/34/35** (`/gsd-verify-work` per phase) and add `*-VALIDATION.md` if
   Nyquist coverage is required.
5. **Confirm the published release:** verify `v0.2.0` actually built/published green on hex.pm
   (and run `mix test` in CI — not runnable here).
6. **Reconcile stale state:** REQUIREMENTS.md traceability, STATE.md, vM015-ROADMAP Progress.
7. **Housekeeping:** untrack `test.txt`/`test2.txt`; remove scratch files; commit/clean pending
   planning churn.

---

*Generated by `/gsd-audit-milestone` (after correcting two erroneous earlier drafts; build + integration verified first-hand)*
