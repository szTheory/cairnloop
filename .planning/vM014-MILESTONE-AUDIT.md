---
milestone: vM014
audited: 2026-05-28T19:00:00Z
status: gaps_found
scores:
  requirements: 17/24
  phases: 4/6
  integration: "22/22 cross-phase connections wired (phases 27–30); 7 warnings"
  flows: "3/3 E2E flows complete (completed phases)"
gaps:
  requirements:
    - id: "E2E-01"
      status: "unsatisfied"
      phase: "31"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 31 not yet started. golden_path_test.exs JTBD smoke test not written."
    - id: "E2E-02"
      status: "unsatisfied"
      phase: "31"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 31 not yet started. widget_channel_test.exs customer-ingress integration test not written."
    - id: "E2E-03"
      status: "unsatisfied"
      phase: "31"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 31 not yet started. mix test.integration lane registration not done."
    - id: "DOC-01"
      status: "unsatisfied"
      phase: "32"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 32 not yet started. Root README mix cairnloop.install update not done."
    - id: "DOC-02"
      status: "unsatisfied"
      phase: "32"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 32 not yet started. ExDoc guides/ with 4 guides + screenshots not written."
    - id: "DOC-03"
      status: "unsatisfied"
      phase: "32"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 32 not yet started. mix.exs ExDoc navigation config not done."
    - id: "DOC-04"
      status: "unsatisfied"
      phase: "32"
      claimed_by_plans: []
      completed_by_plans: []
      verification_status: "missing"
      evidence: "Phase 32 not yet started. CHANGELOG.md vM014 entry not written."
  integration:
    - "WARNING-01 (BRAND-04): brand_token_gate_test.exs uses non-recursive '*.ex' wildcard — misses knowledge_base_live/ (6 files) and mcp/ (4 files) subdirs. No hex fallbacks exist today; Phase 30 added 6 knowledge_base_live/ files unscanned by the gate. Fix: change '*.ex' → '**/*.ex' in test/cairnloop/web/brand_token_gate_test.exs lines 32–33."
    - "WARNING-02 (SEC-01, SEC-02): root SECURITY.md still records T-10-09 and T-10-11 as OPEN — Phase 30 closed both (editor_handoff.ex:18, knowledge_automation.ex:86-93). Documentation drift; no code impact."
    - "WARNING-03 (CHAT-03): README.md line 69 still reads 'mock customer ChatLive view' — stale from pre-Phase-28. Line 52 is correct; line 69 in Routing section was missed."
    - "WARNING-04 (SEC-01, SEC-02): CR-01 — ephemeral :persistent_term secret_key_base in editor_handoff.ex:59-67 invalidated on node restart. Single-node demo works; production multi-node or rolling-deploy will break handoff tokens. Restrict fallback to :test env or require config in non-test envs."
    - "WARNING-05 (KB-04, SEC-01): CR-02 — open_for_manual_edit in suggestion_review.ex:141,147-153,156 uses bare {ok, ...} = matches; DB/scope errors crash LiveView instead of showing a flash. Other handlers use with-else pattern correctly."
    - "WARNING-06 (SEC-01, SEC-02): CR-03 — editor.ex load_review_context/4 at line 150 reads return_to from raw URL params when only review_task_id is present (no suggestion_id), bypassing the verify! token check for the return_to field. Partial open-redirect risk; LiveView router partially mitigates."
    - "WARNING-07 (KB-04): CR-04 — review_task_presenter.ex:26 calls String.to_existing_atom on user-controlled queue= param; unrecognized value raises ArgumentError → 500. Fix: guard with bounded set before converting."
  flows: []
tech_debt:
  - phase: "27-realistic-demo-fixtures"
    items:
      - "WR-01: seed_conversation_row/2 idempotency uses subject-only key; partial insert silently re-skips on re-run"
      - "WR-02..WR-06: seeds_test.exs breadth gaps — per-cohort distribution, per-article revision count, operator-scope host_user_id, content stability across runs not asserted"
  - phase: "28-customer-chat-wired-to-real-ingress"
    items:
      - "INFO-01: chat_live_test.exs lacks direct coverage for handle_event('channel_status') and handle_event('send_error')"
      - "INFO-02: widget_socket.ex token verification is stub (demo posture; adopter-supplied in real deployment)"
      - "Note: all 6 CRs/WRs from 28-REVIEW.md were fixed (28-REVIEW-FIX.md: all_fixed, commits e503a4c..8c242cd)"
  - phase: "29-brand-token-css-extraction-d-10-closure"
    items:
      - "WR-01 (HIGH, pre-Phase-31): BRAND-04 gate non-recursive wildcard — fix before Phase 31 executes (covered by WARNING-01)"
      - "WR-02 (info): color:white on primary buttons in conversation_live.ex:992 and search_modal_component.ex:195 — inconsistent with --cl-on-primary; dark-mode contrast risk (vM015)"
  - phase: "30-kb-editorial-polish-t-10-09-t-10-11-closure"
    items:
      - "CR-01: Ephemeral secret_key_base via :persistent_term — production deployment concern (WARNING-04)"
      - "CR-02: open_for_manual_edit bare-match crash on DB/scope error (WARNING-05)"
      - "CR-03: return_to open-redirect risk via raw URL params when only review_task_id present (WARNING-06)"
      - "CR-04: String.to_existing_atom DoS on queue= param (WARNING-07)"
      - "WR-01: normalize_id/1 accepts partial integer parses ('42abc' → 42); inconsistent with normalize_integer/1"
      - "WR-02: Timestamp skew between DB manual_edit_opened_at and signed token (double DateTime.utc_now())"
      - "WR-03: Editor.mount/3 calls repo() directly — violates Governance facade arch invariant; use KnowledgeBase.get_article/1"
      - "Note: no 30-REVIEW-FIX.md exists; all 30-REVIEW.md findings are unresolved"
nyquist:
  compliant_phases: [27, 28, 29, 30]
  partial_phases: []
  missing_phases: [31, 32]
  overall: "4/4 completed phases COMPLIANT; phases 31-32 not yet started (MISSING by definition)"
checkbox_drift:
  - {id: "CHAT-03", current: "[ ] Pending", correct: "[x] Complete", phase: 28}
  - {id: "BRAND-04", current: "[ ] Pending", correct: "[x] Complete", phase: 29}
  - {id: "KB-01", current: "[ ] Pending", correct: "[x] Complete", phase: 30}
  - {id: "KB-02", current: "[ ] Pending", correct: "[x] Complete", phase: 30}
  - {id: "KB-03", current: "[ ] Pending", correct: "[x] Complete", phase: 30}
  - {id: "KB-04", current: "[ ] Pending", correct: "[x] Complete", phase: 30}
  - {id: "SEC-01", current: "[ ] Pending", correct: "[x] Complete", phase: 30}
  - {id: "SEC-02", current: "[ ] Pending", correct: "[x] Complete", phase: 30}
human_verification_pending:
  - phase: 27
    items:
      - "Adopter-visible dashboard: inbox 16 convos + KB 5 articles + 3 gaps + 1 suggestion after mix setup (REPO-UNAVAILABLE)"
      - "Brand voice spot-check on seeded copy"
  - phase: 28
    items:
      - "Two-tab round trip (operator inbox + customer /chat) — requires live Phoenix + Postgres"
      - "Multi-message-stack UAT (UI-SPEC step 11)"
      - "No mock 'Bot reply' copy at runtime"
      - "Operator inbox refreshes when new customer joins /chat (D-09/D-10 PubSub)"
  - phase: 30
    items:
      - "Open all 4 KB routes in browser and confirm shared nav renders with active route marked"
      - "Owner decision on CR-01..CR-04: remediate or accept/defer (trust-sensitive calls)"
---

# vM014 Adoption Proof — Milestone Audit Report

**Milestone:** vM014 Adoption Proof (Phases 27–32)
**Audited:** 2026-05-28T19:00:00Z
**Status:** ⚠ gaps_found — phases 31 and 32 not yet started
**Score:** 17/24 requirements satisfied · 4/6 phases complete

---

## Summary

**Phases 27–30 are done and structurally wired.** All 17 requirements assigned to completed
phases are satisfied. 22/22 cross-phase connections are intact; 0 broken flows; 3/3 E2E adopter
flows chain end-to-end at the code level. All 4 completed phases are Nyquist-compliant.

The 7 unsatisfied requirements all belong to **phases 31 and 32, which have not been started
yet** — expected state for an in-progress milestone, not a gap in completed work.

**7 warnings found, 0 blockers.** The most time-sensitive is **WARNING-01** (BRAND-04 gate
wildcard fix — one line in a test file) which should land before Phase 31 executes. Four
security review findings from Phase 30 (CR-01..CR-04) are unresolved and the owner needs to
decide remediate-or-defer before the phase is sealed.

---

## Phase Verification Status

| Phase | Name | VERIFICATION.md | Status | Score | Nyquist |
|-------|------|----------------|--------|-------|---------|
| 27 | Realistic Demo Fixtures | ✅ Present | passed | 4/4 | COMPLIANT |
| 28 | Customer Chat Wired to Real Ingress | ✅ Present | human_needed¹ | 23/23 | COMPLIANT |
| 29 | Brand-Token CSS Extraction | ✅ Present | passed | 4/4 | COMPLIANT |
| 30 | KB Editorial Polish + T-10-09/11 | ✅ Present | human_needed² | 4/4 | COMPLIANT |
| 31 | Golden-Path JTBD Smoke Test | ❌ Missing | not started | — | MISSING |
| 32 | README + ExDoc Guides | ❌ Missing | not started | — | MISSING |

¹ Phase 28: 23/23 source-level truths verified; 4 human UAT tests require live Phoenix + Postgres (REPO-UNAVAILABLE in workspace).  
² Phase 30: 4/4 success criteria verified; pending (1) visual nav continuity UAT, (2) owner decision on CR-01..CR-04 security findings from 30-REVIEW.md.

---

## Requirements Coverage (3-Source Cross-Reference)

### ✅ Phase 27 — Complete (FIX-01..04)

| REQ-ID | VERIFICATION.md | REQUIREMENTS.md | Final |
|--------|----------------|-----------------|-------|
| FIX-01 | SATISFIED (structural; pending visual) | `[x]` | **satisfied** |
| FIX-02 | SATISFIED (structural; pending visual) | `[x]` | **satisfied** |
| FIX-03 | SATISFIED (structural; pending visual) | `[x]` | **satisfied** |
| FIX-04 | SATISFIED (structural; pending visual) | `[x]` | **satisfied** |

All 4 carry pending human visual confirmation (dashboard sweep); structural success criteria
verified by seeds_test.exs (4 tests, 0 failures, commit 0bf3937).

### ✅ Phase 28 — Complete (CHAT-01..03)

| REQ-ID | VERIFICATION.md | REQUIREMENTS.md | Final |
|--------|----------------|-----------------|-------|
| CHAT-01 | SATISFIED | `[x]` | **satisfied** |
| CHAT-02 | SATISFIED (source-level) | `[x]` | **satisfied** |
| CHAT-03 | SATISFIED | `[ ]` ← drift | **satisfied** (update checkbox) |

CHAT-03 drift: REQUIREMENTS.md `[ ] Pending` but Phase 28 VERIFICATION.md Truth 3 confirms
README Two-Tab Demo section at line 32 is present and verified.

All 6 CRs/WRs from 28-REVIEW.md were fixed (28-REVIEW-FIX.md: `all_fixed`).

### ✅ Phase 29 — Complete (BRAND-01..04)

| REQ-ID | VERIFICATION.md | REQUIREMENTS.md | Final |
|--------|----------------|-----------------|-------|
| BRAND-01 | SATISFIED | `[x]` | **satisfied** |
| BRAND-02 | SATISFIED | `[x]` | **satisfied** |
| BRAND-03 | SATISFIED | `[x]` | **satisfied** |
| BRAND-04 | SATISFIED (warning) | `[ ]` ← drift | **satisfied** (update checkbox) |

BRAND-04 drift: gate test passes (1 test, 0 failures) but non-recursive wildcard limitation
exists (WARNING-01).

### ✅ Phase 30 — Complete (KB-01..04, SEC-01..02)

| REQ-ID | VERIFICATION.md | REQUIREMENTS.md | Final |
|--------|----------------|-----------------|-------|
| KB-01 | SATISFIED | `[ ]` ← drift | **satisfied** (update checkbox) |
| KB-02 | SATISFIED | `[ ]` ← drift | **satisfied** (update checkbox) |
| KB-03 | SATISFIED | `[ ]` ← drift | **satisfied** (update checkbox) |
| KB-04 | SATISFIED (warning) | `[ ]` ← drift | **satisfied** (update checkbox) |
| SEC-01 | SATISFIED (warning) | `[ ]` ← drift | **satisfied** (update checkbox) |
| SEC-02 | SATISFIED (warning) | `[ ]` ← drift | **satisfied** (update checkbox) |

All 6 Phase 30 requirements are `[ ]` in REQUIREMENTS.md but all 4 success criteria verified in
30-VERIFICATION.md. No 30-REVIEW-FIX.md exists — CR-01..CR-04 security findings unresolved.

### ❌ Phase 31 — Not Started (E2E-01..03)

| REQ-ID | Status | Notes |
|--------|--------|-------|
| E2E-01 | **unsatisfied** | golden_path_test.exs JTBD smoke test — phase not started |
| E2E-02 | **unsatisfied** | widget_channel_test.exs integration — phase not started |
| E2E-03 | **unsatisfied** | mix test.integration lane — phase not started |

### ❌ Phase 32 — Not Started (DOC-01..04)

| REQ-ID | Status | Notes |
|--------|--------|-------|
| DOC-01 | **unsatisfied** | Root README install path update — phase not started |
| DOC-02 | **unsatisfied** | ExDoc guides/ 4 guides + screenshots — phase not started |
| DOC-03 | **unsatisfied** | mix.exs ExDoc navigation — phase not started |
| DOC-04 | **unsatisfied** | CHANGELOG.md vM014 entry — phase not started |

---

## Cross-Phase Integration Report

**22/22 connections wired · 0 broken flows · 7 warnings**

### E2E Adopter Flow (Phases 27–30)

```
mix setup
  └─ seeds.exs (Ph27) — 16 convos, 5 articles, 3 gaps, 1 suggestion+ReviewTask

mix phx.server
  ├─ Cairnloop.PubSub + CairnloopExample.PubSub (Ph28)
  └─ endpoint.ex: socket "/widget" WidgetSocket (Ph28)

/support (InboxLive)
  ├─ 16 seeded conversations (Ph27) ✓
  ├─ PubSub "conversations" subscribe + handle_info (Ph28) ✓
  └─ Brand tokens: bare var(--cl-*) (Ph29) ✓

/chat (ChatLive)
  ├─ WidgetChat JS hook → /widget → WidgetChannel.join (Ph28) ✓
  ├─ Customer msg → ProcessMessage → ingest_widget_message → PubSub (Ph28) ✓
  ├─ Operator reply → OQ-1 broadcast → ChatLive appends :agent role (Ph28) ✓
  └─ Brand tokens: bare var(--cl-*) (Ph29) ✓

/knowledge-base (Index)
  ├─ 5 seeded articles via KnowledgeBase.list_articles/1 (Ph27+Ph30) ✓
  ├─ Shared kb_nav shell (Ph30) ✓
  └─ "New article" affordance (Ph30) ✓

/knowledge-base/suggestions (SuggestionReview)
  ├─ 1 seeded ArticleSuggestion :ready + ReviewTask (Ph27) ✓
  ├─ Shared kb_nav shell (Ph30) ✓
  └─ open_for_manual_edit → record_editor_handoff → EditorHandoff.sign (Ph30) ✓

/knowledge-base/:id/edit (Editor)
  ├─ EditorHandoff.verify!/2 gate (T-10-11 closure) (Ph30) ✓
  ├─ Gap evidence sidebar → get_gap_candidate (Ph30) ✓
  └─ Bare-URL raises → mount rescue → flash + redirect (Ph30) ✓

/knowledge-base/gaps (Gaps)
  ├─ 3 seeded GapCandidates (Ph27) ✓
  └─ Shared kb_nav shell (Ph30) ✓
```

Status: **COMPLETE** at code level. Live-browser UAT pending (REPO-UNAVAILABLE in workspace).

### Integration Warnings

| # | Req | Sev | Issue | Fix |
|---|-----|-----|-------|-----|
| W-01 | BRAND-04 | ⚠ HIGH | `brand_token_gate_test.exs` `"*.ex"` wildcard misses 10 files in `knowledge_base_live/` + `mcp/` subdirs. Phase 30 added 6 unscanned files. No violations today; silent regression risk for Phase 31+. | `"*.ex"` → `"**/*.ex"` (1 line) |
| W-02 | SEC-01, SEC-02 | ⚠ | Root `SECURITY.md` still lists T-10-09 + T-10-11 as OPEN. Phase 30 closed both. | Update SECURITY.md rows to CLOSED |
| W-03 | CHAT-03 | ℹ | `README.md` line 69 reads "mock customer ChatLive view" (stale; line 52 is correct). | One-line README fix |
| W-04 | SEC-01, SEC-02 | ⚠ | CR-01: `editor_handoff.ex:59-67` `:persistent_term` fallback secret is node-local; tokens break on restart / across cluster. Demo works; production multi-node or rolling deploy does not. | Restrict fallback to `:test` env only |
| W-05 | KB-04, SEC-01 | ⚠ | CR-02: `suggestion_review.ex` bare `{:ok,...}=` at lines 141, 147-153, 156 crash LV on DB/scope errors. Other handlers use `with…else` correctly. | Wrap in `with` chain |
| W-06 | SEC-01, SEC-02 | ⚠ | CR-03: `editor.ex:150` reads `return_to` from raw URL params when only `review_task_id` is present (no `suggestion_id`). `verify!` not consulted for that field. Partial open-redirect. | Extract from signed token payload |
| W-07 | KB-04 | ⚠ | CR-04: `review_task_presenter.ex:26` `String.to_existing_atom` on user-controlled `queue=` param. Unknown value → ArgumentError → 500. | Guard with bounded set |

---

## Nyquist Compliance

| Phase | VALIDATION.md | nyquist_compliant | Status |
|-------|--------------|-------------------|--------|
| 27 | ✅ | true | **COMPLIANT** |
| 28 | ✅ | true | **COMPLIANT** |
| 29 | ✅ | true | **COMPLIANT** |
| 30 | ✅ | true | **COMPLIANT** |
| 31 | ❌ | — | MISSING (not started) |
| 32 | ❌ | — | MISSING (not started) |

---

## Tech Debt Inventory

### Phase 27 — 6 items (test coverage breadth only)
- WR-01: `seed_conversation_row/2` subject-only idempotency key — partial insert silently re-skips
- WR-02..06: seeds_test.exs doesn't pin per-cohort distribution, per-article revision count, operator-scope, content stability

### Phase 28 — 2 items (all critical issues fixed in 28-REVIEW-FIX.md)
- INFO-01: chat_live_test.exs missing tests for `handle_event("channel_status")` + `handle_event("send_error")`
- INFO-02: widget_socket.ex token verification is stub (acceptable for demo)

### Phase 29 — 2 items
- **WR-01 (HIGH):** BRAND-04 gate non-recursive wildcard — must fix before Phase 31 (see W-01)
- WR-02 (info): `color:white` on primary buttons — dark-mode contrast risk (vM015)

### Phase 30 — 7 items (no 30-REVIEW-FIX.md; all 30-REVIEW.md findings unresolved)
- **CR-01 (⚠):** Ephemeral secret_key_base — production deployment concern (W-04)
- **CR-02 (⚠):** Bare-match crash in `open_for_manual_edit` (W-05)
- **CR-03 (⚠):** `return_to` open-redirect via raw URL params (W-06)
- **CR-04 (⚠):** `String.to_existing_atom` DoS on `queue=` param (W-07)
- WR-01: `normalize_id/1` partial integer parse inconsistency
- WR-02: Timestamp skew between DB and token `manual_edit_opened_at`
- WR-03: `Editor.mount/3` calls `repo()` directly — Governance facade invariant violation

---

## Human Verification Backlog

| Phase | Test | Blocker |
|-------|------|---------|
| 27 | Dashboard after `mix setup`: 16 convos + 5 articles + 3 gaps + 1 suggestion | REPO-UNAVAILABLE |
| 27 | Brand voice spot-check on seeded copy | Editorial |
| 28 | Two-tab round trip (operator ↔ customer) | REPO-UNAVAILABLE |
| 28 | Multi-message-stack UAT (UI-SPEC step 11) | REPO-UNAVAILABLE |
| 28 | No mock "Bot reply" copy at runtime | REPO-UNAVAILABLE |
| 28 | Operator inbox refreshes when new customer joins /chat | REPO-UNAVAILABLE |
| 30 | All 4 KB routes render consistent nav with active route marked | REPO-UNAVAILABLE |
| 30 | Decision on CR-01..CR-04: remediate or accept/defer | Owner decision |

---

## REQUIREMENTS.md Checkbox Drift

8 requirements satisfied in VERIFICATION.md but showing `[ ]` in REQUIREMENTS.md:

| REQ-ID | Current | Should Be | Phase |
|--------|---------|-----------|-------|
| CHAT-03 | `[ ]` Pending | `[x]` Complete | 28 |
| BRAND-04 | `[ ]` Pending | `[x]` Complete | 29 |
| KB-01 | `[ ]` Pending | `[x]` Complete | 30 |
| KB-02 | `[ ]` Pending | `[x]` Complete | 30 |
| KB-03 | `[ ]` Pending | `[x]` Complete | 30 |
| KB-04 | `[ ]` Pending | `[x]` Complete | 30 |
| SEC-01 | `[ ]` Pending | `[x]` Complete | 30 |
| SEC-02 | `[ ]` Pending | `[x]` Complete | 30 |

---

*Audited: 2026-05-28T19:00:00Z*  
*Auditor: Claude (gsd-audit-milestone)*  
*Supersedes: 2026-05-28T00:00:00Z (pre-Phase-30 audit)*
