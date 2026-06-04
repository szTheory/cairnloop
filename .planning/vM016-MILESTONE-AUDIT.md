---
milestone: vM016
milestone_name: Operator UI/UX Iteration
audited: 2026-06-04T18:40:00Z
status: gaps_found
audit_kind: mid-milestone (6/9 phases complete — run before phases 43/44/45 built)
supersedes: "2026-06-03 premature audit (was 1/9 phases)"
scores:
  requirements: 21/29 satisfied (1 partial, 7 unsatisfied)
  phases: 6/9 complete
  integration: 21/22 seams clean (1 warning)
  flows: 5/6 threading flows clean
gaps:
  requirements:
    - id: "HOME-02"
      status: "partial"
      phase: "39-home-primacy-redesign-d1"
      claimed_by_plans: ["39-02-PLAN.md", "39-03-PLAN.md"]
      completed_by_plans: ["39-03-SUMMARY.md"]
      verification_status: "passed (single-phase) — integration WARNING"
      evidence: "home_live.ex:130 resolved sub-line uses bare <a href=\"/inbox?status=resolved\"> instead of <.link navigate>. Under the library's only documented mount (cairnloop_dashboard(\"/support\", ...)) the bare anchor does a full-page load to absolute /inbox (404 / host catch-all), not /support/inbox. Sibling primary CTA at home_live.ex:137 correctly uses <.link navigate>. The phase verifier checked the href string value but not the element type under prefixed mount."
    - id: "RESP-01"
      status: "unsatisfied"
      phase: "43-responsive-desktop-first-cockpit-d3 (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 43 not started — no plans, no VERIFICATION.md. Requirement orphaned (assigned, never built)."
    - id: "RESP-02"
      status: "unsatisfied"
      phase: "43-responsive-desktop-first-cockpit-d3 (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 43 not started."
    - id: "MOTION-01"
      status: "unsatisfied"
      phase: "44-motion (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 44 not started."
    - id: "MOTION-02"
      status: "unsatisfied"
      phase: "44-motion (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 44 not started."
    - id: "SEED-01"
      status: "unsatisfied"
      phase: "45-seed-enrichment-screenshot-verification (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 45 not started."
    - id: "VERIFY-01"
      status: "unsatisfied"
      phase: "45-seed-enrichment-screenshot-verification (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 45 not started — light+dark screenshot regen + visual acceptance owed here; also absorbs P38/P42 deferred human-verify items."
    - id: "VERIFY-02"
      status: "unsatisfied"
      phase: "45-seed-enrichment-screenshot-verification (NOT STARTED)"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 45 not started — full mix test + integration + quality green sweep owed here."
  integration:
    - from: "home_live (P39 HOME-02)"
      to: "/inbox?status=resolved"
      severity: warning
      issue: "Bare <a href> breaks in-session live nav under prefixed /support mount; should be <.link navigate>."
      affected_requirements: ["HOME-02"]
  flows:
    - flow: "Home resolved sub-line → filtered inbox"
      breaks_at: "click of resolved sub-line under /support mount (full reload to nonexistent /inbox)"
      affected_requirements: ["HOME-02"]
nyquist:
  compliant_phases: ["37", "38", "42"]
  partial_phases: ["39", "40", "41"]
  missing_phases: []
  not_started_phases: ["43", "44", "45"]
  overall: partial
tech_debt:
  - phase: 39-home-primacy-redesign-d1
    items:
      - "HOME-02 resolved sub-line: bare <a href> → migrate to <.link navigate> (also see integration WARNING)."
  - phase: "39/40/41 (validation hygiene)"
    items:
      - "VALIDATION.md frontmatter still status: draft / nyquist_compliant: false despite green VERIFICATION + passing tests. Run /gsd:validate-phase 39 40 41 to formally close, or accept as documentation debt."
  - phase: "all (summary hygiene)"
    items:
      - "SUMMARY.md `requirements_completed` frontmatter is empty in 24/25 summaries (only 37-05 populated). VERIFICATION.md is the authoritative coverage source; frontmatter is a metadata-hygiene gap, not a coverage gap."
  - phase: "doc drift (RESOLVED in this audit)"
    items:
      - "ROADMAP.md Phase 40 checkbox was [ ] and REQUIREMENTS.md DRIFT-01/DRIFT-02 marked Pending despite P40 passing — corrected to complete during this audit."
deferred_to_phase_45:
  - "P38 human-verify: visual header/width/title consistency across screens (screenshot pipeline)."
  - "P38 human-verify: live conversation→editor breadcrumb back-link round-trip."
  - "P42 human-verify: 42-06 browser E2E thread-navigation spec on CI e2e lane (pgvector)."
---

# vM016 Operator UI/UX Iteration — Milestone Audit

**Audited:** 2026-06-04 · **Status:** `gaps_found` · **Kind:** mid-milestone audit (6/9 phases complete)
_Supersedes the 2026-06-03 audit, which ran at 1/9 phases._

## Headline

**vM016 is not ready for completion.** This audit was run after Phase 42, with **3 of 9 phases not
yet started** — Phase 43 (Responsive/D3), Phase 44 (Motion), Phase 45 (Seed + Screenshot +
Verification Sweep). Those phases own **7 requirements** that are therefore unsatisfied/orphaned.

The **completed 6-phase surface (37–42) is in excellent shape**: every one of its 22 requirements is
code-verified, cross-phase integration is clean across 21/22 seams, and the architectural invariants
hold (no direct `Cairnloop.Repo` in the web layer, snapshot-at-decision, token-only render output,
sealed paths untouched). One genuine WARNING-level bug surfaced in integration that the single-phase
verifier missed (HOME-02 bare-anchor under prefixed mount).

## Requirements Coverage (3-source cross-reference)

29 v1 requirements. Sources cross-referenced: phase `VERIFICATION.md` (authoritative), `SUMMARY.md`
frontmatter (mostly unpopulated — hygiene gap), and `REQUIREMENTS.md` traceability.

| # | Status | Requirements |
|---|--------|-------------|
| 21 | ✅ **Satisfied** | UIC-01..05, SHELL-01/02, HOME-01/03/04/05, DRIFT-01/02, GATE-01/02, RAIL-01/02/03, THREAD-01/02/03 |
| 1 | ⚠️ **Partial** | HOME-02 (wired but bare-anchor breaks under `/support` mount — see Integration) |
| 7 | ❌ **Unsatisfied** | RESP-01/02 (P43), MOTION-01/02 (P44), SEED-01, VERIFY-01/02 (P45) — phases not started |

### Phase verification roll-up

| Phase | Status | Score | Requirements | Notes |
|-------|--------|-------|--------------|-------|
| 37 Component Primitives | `passed` | 5/5 | UIC-01..05 ✅ | 0 critical/3 warning review, all resolved |
| 38 Shared Page-Shell | `human_needed` | 11/11 code | SHELL-01/02 ✅ | visual + live back-link deferred → P45/human |
| 39 Home Primacy D1 | `passed` | 5/5 | HOME-01..05 | HOME-02 has integration WARNING (below) |
| 40 Drift + Gate | `passed` | 8/8 | DRIFT-01/02, GATE-01/02 ✅ | 1 orchestrator deviation assessed+accepted |
| 41 Conversation Rail D2 | `passed` | 4/4 | RAIL-01/02/03 ✅ | client behaviors covered by CI e2e lane |
| 42 Cross-Screen Threading | `human_needed` | 4/4 | THREAD-01/02/03 ✅ | 42-06 browser E2E CI-gated → P45/human |
| 43 Responsive D3 | — | — | RESP-01/02 ❌ | **not started** |
| 44 Motion | — | — | MOTION-01/02 ❌ | **not started** |
| 45 Seed + Verify | — | — | SEED-01, VERIFY-01/02 ❌ | **not started** |

## Cross-Phase Integration (completed surface)

Verdict: **21/22 seams clean, 1 warning.** Full report from `gsd-integration-checker`.

**Clean seams (verified with file:line evidence):**
1. `cl_page` (P37) consumed by all 8 screens (P38), home redesign renders inside it (P39). ✅
2. `cl_disclosure` `attr(:rest, :global)` → `data-tier="2"` passthrough drives P41 Expand-all JS scoping. ✅
3. `BreadcrumbPresenter.editor_items/2` (P38) + `/3` overload (P42) **compose additively, no collision** — P42 added the 3-arity origin variant, 2-arity fallback untouched. ✅
4. Chat facade (`count/list_conversations` P39 + `next_open_conversation` P42) all via `repo()` indirection — **zero direct `Cairnloop.Repo` in web layer.** ✅
5. Threading deep-links resolve against the router: audit row → `/:id`, gov-action → `/audit-log?proposal=`, next-in-queue → `/:id`; `?proposal` string parses cleanly via `Integer.parse`. ✅
6. `conversation_live.ex` is edited by **P40 + P41 + P42** — the three sets of edits (token footer, Tier structure, next-in-queue/deep-link) **compose coherently**, additive and non-overlapping. ✅

**⚠️ WARNING — HOME-02 resolved-filter CTA breaks under prefixed mount**
`lib/cairnloop/web/home_live.ex:130` uses a bare `<a href="/inbox?status=resolved">` instead of
`<.link navigate="/inbox?status=resolved">`. A bare anchor performs a full-page browser load to the
**absolute** `/inbox`, which does not exist under the library's only documented mount pattern
(`cairnloop_dashboard("/support", ...)`) — only `/support/inbox` exists. The sibling primary
"Open inbox" CTA (line 137) correctly uses `<.link navigate>`. This is the **only bare-href internal
link in the web layer.** Fix: one-line swap to `<.link navigate>`. (This is the kind of cross-cutting
break a per-phase verifier structurally cannot see — it only manifests under the host's mount prefix.)

## Nyquist Compliance

| Phase | VALIDATION.md | `nyquist_compliant` | Action |
|-------|---------------|---------------------|--------|
| 37 | exists | ✅ true | none |
| 38 | exists | ✅ true | none |
| 39 | exists | ❌ false (`draft`) | `/gsd:validate-phase 39` to formally close (tests already green) |
| 40 | exists | ❌ false (`draft`) | `/gsd:validate-phase 40` |
| 41 | exists | ❌ false (`draft`) | `/gsd:validate-phase 41` |
| 42 | exists | ✅ true (`audited`) | none |
| 43–45 | — | — | n/a (not started) |

Overall: **partial.** 39/40/41 passed VERIFICATION with green tests but their VALIDATION frontmatter
is still `draft`/`nyquist_compliant: false` — documentation debt, not a test-coverage gap.

## Tech Debt & Hygiene

- **HOME-02 bare anchor** → migrate to `<.link navigate>` (also the integration WARNING above).
- **VALIDATION hygiene (39/40/41)** — formally close via `/gsd:validate-phase` or accept as debt.
- **SUMMARY `requirements_completed` frontmatter empty** in 24/25 summaries — VERIFICATION.md is the
  authoritative coverage source; this is metadata hygiene only.
- **Doc drift — RESOLVED in this audit:** ROADMAP Phase 40 checkbox and REQUIREMENTS.md
  DRIFT-01/DRIFT-02 status were stale (Pending) despite P40 passing; corrected to complete.

## Deferred to Phase 45 (the verification sweep, by design)

- P38 visual consistency (screenshot pipeline) + live conversation→editor back-link round-trip.
- P42 browser E2E `thread_navigation_test.exs` on the CI `e2e` lane (needs pgvector).

These are correctly owned by Phase 45's `VERIFY-01`/`VERIFY-02` and are not independent gaps.

## Decision

Per the shift-left policy, this is **not a VERY-impactful escalation** — it is simply an honest
mid-milestone status: **continue the milestone, do not complete it.** Recommended path:

1. Fix the HOME-02 bare-anchor now (one-line, cheap, do not wait for a phase) — or fold it into Phase 43 (responsive) which is the next conversation/home-screen touch.
2. Plan and execute the remaining phases: `/gsd:plan-phase 43` → 44 → 45.
3. Phase 45 closes the deferred P38/P42 human-verify items and runs the full green sweep.
4. Re-run `/gsd:audit-milestone` after Phase 45 before `/gsd:complete-milestone vM016`.

_Audited by Claude (gsd-audit-milestone orchestrator) — integration check by gsd-integration-checker._
