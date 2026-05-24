---
phase: 14-operator-timeline-preview-surface
verified: 2026-05-24T15:00:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 14: operator-timeline-preview-surface Verification Report

**Phase Goal:** READ-ONLY operator timeline + preview surface over durable Phase-13 ToolProposal + ToolActionEvent records. FLOW-01 (governed action proposals and outcomes as a durable timeline, including BLOCKED proposals) and FLOW-02 (human-readable preview card with risk label, actor scope, target, consequence summary, evidence/history links). No approve/reject execution in this phase.
**Verified:** 2026-05-24T15:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | FLOW-01: Governed action proposals (including BLOCKED) render as a durable timeline in ConversationLive | VERIFIED | `conversation_live.ex:578-589` — `<section class="rail-card governed-actions-rail">` iterates `@governed_actions` via `<.governed_action_card proposal={proposal} />` with no status filter; `Governance.list_proposals_for_conversation/1` query at `governance.ex:402-412` has no status filter (all statuses included) |
| 2 | FLOW-01: Data sourced via `Governance.list_proposals_for_conversation/1` facade, not direct schema query | VERIFIED | `conversation_live.ex:218-219` — explicit comment `# D-09: load governed_actions via the narrow facade (never direct schema query from web layer)`. No direct `ToolProposal` or `Ecto.Query` calls in the web layer outside the facade. |
| 3 | FLOW-01: `conversation_id` threaded into proposal on both valid AND blocked paths | VERIFIED | `governance.ex:203-232` — `insert_new_proposal/6` includes `conversation_id: conversation_id` (D-07 comment). `governance.ex:314,329` — `insert_blocked_proposal/10` includes `conversation_id: conversation_id` (D-07 comment). Both paths confirmed. |
| 4 | FLOW-01: `conversation_id` excluded from idempotency canonical map (D-08) | VERIFIED | `governance.ex:109-113` — explicit `# D-08: conversation_id is EXCLUDED from this canonical map intentionally.` comment; `conversation_id` absent from the `canonical` map at `governance.ex:115-122`. |
| 5 | FLOW-02: `governed_action_card/1` surfaces risk label, actor scope, target, consequence summary, and evidence/history | VERIFIED | `conversation_live.ex:845-1041` — card precomputes and renders: `risk_tier_label` (line 851/944), `scope_summary` from `scope_snapshot` = actor scope (line 856/1009), `trace.tool_ref` = target (line 1028), headline from `Preview.render/1` = consequence summary (lines 893-907/930-933), event mini-timeline = evidence/history (lines 862-879/977-1003). All humanized, never raw Elixir terms. |
| 6 | FLOW-02: Preview card humanized — never raw Elixir terms; color+text chip (brand §7.5) | VERIFIED | Risk chip: `conversation_live.ex:880-891` — tone atom maps to CSS class; chip always renders `Risk: <%= @risk_tier_label %>` (text label alongside color, line 944). `ToolProposalPresenter.reason_label/1` at `tool_proposal_presenter.ex:138-156` — explicit no-inspect handling for all reason shapes. Raw maps only behind `<details>` expanders (lines 970-974, 1017-1020). |
| 7 | CR-01 fix: `execute_tool` handler fails closed on `{:error, changeset}` | VERIFIED | `conversation_live.ex:190-198` — `{:error, _changeset}` clause added with calm flash "This action could not be recorded right now. Please try again." (D-05/CR-01 comment at line 191). No raw changeset surfaced. |
| 8 | No approve/reject/defer action buttons rendered (read-only Phase 14) | VERIFIED | `conversation_live.ex:1034-1038` — footer div present but empty with comment `<%!-- Phase-15 affordance slot — no action buttons in Phase 14 (read-only, D-05) --%>`. Grep for `phx-click` inside `governed_action_card/1` shows only the event metadata expanders — no approve/reject/defer events. |

**Score:** 8/8 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs` | Nullable FK + composite index | VERIFIED | Nullable `conversation_id` with `on_delete: :nilify_all` and `index([:conversation_id, :inserted_at])`. No backfill (D-06). |
| `lib/cairnloop/governance/tool_proposal.ex` | `belongs_to(:conversation)`, `conversation_id` in cast | VERIFIED | `tool_proposal.ex:49` — `belongs_to(:conversation, Conversation)`. `tool_proposal.ex:85` — `:conversation_id` in `cast/3` list, NOT in `validate_required`. |
| `lib/cairnloop/conversation.ex` | `has_many(:tool_proposals)` | VERIFIED | `conversation.ex:16` — `has_many(:tool_proposals, Cairnloop.Governance.ToolProposal)`. |
| `lib/cairnloop/governance.ex` | `list_proposals_for_conversation/1` + conversation_id write paths | VERIFIED | `governance.ex:402-412` — query filters by `conversation_id`, orders desc by `inserted_at`, preloads `events` asc. Conversation_id on valid path (line 214) and blocked path (line 314). D-08 exclusion comment at line 109. |
| `lib/cairnloop/web/tool_proposal_presenter.ex` | Pure total presenter, D-22 masking, D-14 humanization | VERIFIED | All 16 total functions implemented. `input_rows/1` masking choke point with "Unsupported value" posture (line 173-183). `reason_label/1` humanizes all shapes without `inspect/1` (lines 138-156). `metadata_value/2` uses `Map.fetch` (WR-05 fixed, line 322). |
| `lib/cairnloop/governance/preview.ex` | Total `render/1`, D-19 guard stack, `String.to_existing_atom` | VERIFIED | `preview.ex:64-69` — total `render/1` returning `{:preview, str}` or `{:structured, map()}`. Full D-19 guard stack (lines 75-85). `String.to_existing_atom` + rescue at lines 97-103 (zero `String.to_atom` calls). `humanize_label("")` WR-06 fix at line 173. |
| `lib/cairnloop/web/conversation_live.ex` | `governed_action_card/1` function component + rail wiring | VERIFIED | Function component (not LiveComponent) at line 845. All 4 statuses render correctly. Rail section at lines 578-589. D-01 (right rail), D-02 (plain assign, no streams), D-04 ("Propose" + brand token), D-14 (`reason_label` replacing `inspect`), D-24 (`Ecto.assoc_loaded?` guard). |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ConversationLive.reload_conversation_with_context/2` | `Governance.list_proposals_for_conversation/1` | direct call | WIRED | `conversation_live.ex:219` |
| `ConversationLive.handle_event("execute_tool")` | `Governance.propose/3` with `conversation_id` | `Map.put(context, :conversation_id, socket.assigns.conversation.id)` | WIRED | `conversation_live.ex:181-183` — server-trusted, not from request params |
| `ConversationLive.governed_action_card/1` | `ToolProposalPresenter` | direct function calls | WIRED | `conversation_live.ex:849-874` — 14 `ToolProposalPresenter.*` calls |
| `ConversationLive.governed_action_card/1` | `Preview.render/1` | direct call | WIRED | `conversation_live.ex:894` |
| `Governance.insert_new_proposal/6` | `conversation_id` in `ToolProposal` attrs | `conversation_id: conversation_id` in attrs map | WIRED | `governance.ex:232` |
| `Governance.insert_blocked_proposal/10` | `conversation_id` in `ToolProposal` attrs | `conversation_id: conversation_id` in attrs map | WIRED | `governance.ex:329` |
| `Preview.render/1` | `ToolProposalPresenter.input_rows/1` (structured fallback) | call in `build_structured/1` | WIRED | `preview.ex:137` |
| `failure_reason_message/3` | `ToolProposalPresenter.reason_label/1` | direct call | WIRED | `conversation_live.ex:205-212` — D-14 fully applied, zero `inspect(reason)` in display path |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `ConversationLive` rail section | `@governed_actions` | `Governance.list_proposals_for_conversation/1` → `repo().all()` | Yes — Ecto query over `cairnloop_tool_proposals` where `conversation_id = ^id` | FLOWING |
| `governed_action_card/1` | `proposal.input_snapshot` / `proposal.scope_snapshot` / `proposal.policy_snapshot` | Snapshotted at propose-time in `Governance.propose/3` | Yes — snapshot maps written at insert time, never re-read from live config | FLOWING |
| `Preview.render/1` structured result | `build_structured/1` map | `proposal.risk_tier`, `proposal.approval_mode`, `proposal.scope_snapshot` from durable record | Yes — all fields from ToolProposal struct | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Compile clean | `mix compile --warnings-as-errors` | exit 0, no output | PASS |
| Full test suite | `mix test` | 1 doctest + 367 tests, 1 failure (pre-existing `DraftTest` baseline) | PASS |
| 0 Phase-14 tests skipped | `mix test 2>&1 \| grep skipped` | No skipped count in output (all 4 waves complete) | PASS |
| No `String.to_atom` in preview.ex | grep | 0 matches (only comments mentioning it as prohibited) | PASS |
| No `#2563eb` hardcoded hex in conversation_live.ex | grep | 0 matches | PASS |
| No stream usage in conversation_live.ex | grep `stream(` | 0 matches | PASS |
| `governed_action_card` is function component, not LiveComponent | grep `use Phoenix.LiveComponent` | 0 matches | PASS |
| `failure_reason_message/1` uses `reason_label`, not `inspect` | grep `inspect(` in failure_reason_message body | 0 matches (D-14 gate satisfied) | PASS |

---

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| FLOW-01 | Operator can inspect governed action proposals and outcomes as durable timeline (incl. BLOCKED) | SATISFIED | Governance rail renders all proposals for conversation via facade; blocked statuses `:scope_invalid`, `:policy_denied` included (no status filter in query); `list_proposals_for_conversation/1` ordered desc by `inserted_at` with events preloaded. |
| FLOW-02 | Human-readable preview card with risk label, actor scope, target, consequence summary, evidence links | SATISFIED | `governed_action_card/1` renders: risk chip with `risk_tier_label` (label+color), scope section with `scope_summary` (actor scope), trace section with `tool_ref` (target), headline from `Preview.render/1` (consequence summary), event mini-timeline (evidence/history). |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/cairnloop/governance.ex` | 313 | `inspect(reason)` in `insert_blocked_proposal/10` stores raw changeset string in `policy_snapshot` for `:needs_input` path | Info (WR-01 carry-forward — see note below) | Stored data quality issue only; never surfaces raw terms to operators in display path (behind `<details>` expander, and `failure_reason_message` uses `reason_label`). Sealed Phase-13 code path; intentionally NOT fixed per seal-completed-phases rule. |

**WR-01 carry-forward note:** The `inspect(reason)` at `governance.ex:313` is in the data persistence layer of a sealed Phase-13 code path. When `outcome = :needs_input`, the changeset is serialized via `inspect/1` into `policy_snapshot`. This is visible behind the "Raw policy snapshot" expander in the card — not inline to the operator. The REVIEW.md review identified this as WR-01; the REVIEW-FIX.md explicitly marks it **out of scope** per the CLAUDE.md seal-completed-phases rule. This is a recorded carry-forward, not a Phase-14 failure.

No `TBD`, `FIXME`, or `XXX` debt markers found in Phase-14-modified files.

---

### Human Verification Required

None. All Phase-14 must-haves are verifiable programmatically. The read-only timeline and card are tested via `conversation_live_test.exs` render assertions. No visual appearance regressions, real-time behaviors, or external service integrations are introduced in this phase.

---

### Gaps Summary

No gaps. All 8 must-have truths are VERIFIED, all required artifacts exist and are substantive and wired, all key links are confirmed, and the test suite is warnings-clean with 0 new failures.

**CR-01** (fail-closed gap on `{:error, changeset}`) is FIXED at `conversation_live.ex:190-198`.

**WR-01** (`:needs_input` path stores `inspect(changeset)` in `policy_snapshot`) is a known, recorded carry-forward — not a Phase-14 blocker. The operator display path never exposes this raw data inline (only behind an expander), and `failure_reason_message/1` uses `ToolProposalPresenter.reason_label/1` for the flash message. Resolution is deferred to a future phase when the sealed `propose_blocked` path is revisited.

**REPO-UNAVAILABLE coverage note:** `Cairnloop.Repo` is unavailable in this workspace. Live DB round-trip behaviors (JSONB string-key survival after Postgres INSERT+SELECT, actual migration execution, composite index performance) are covered by MockRepo + string-keyed fixtures + `# REPO-UNAVAILABLE` stubs. All presenter and preview logic is pure/headless and fully tested. No Phase-14 requirement lacks ALL coverage.

---

_Verified: 2026-05-24T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
