---
phase: 14
slug: operator-timeline-preview-surface
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-24
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `14-RESEARCH.md` › Validation Architecture. Trust surface: governed-action
> preview cards. The COMMON path (no tool implements `preview/1` yet) is the snapshot-built
> structured summary — design tests around that reality, not the rare live leg.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest (already configured) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/cairnloop/governance/preview_test.exs test/cairnloop/web/tool_proposal_presenter_test.exs` |
| **Full suite command** | `mix test` |
| **Compile gate** | `mix compile --warnings-as-errors` (MANDATORY — warnings fail the build) |
| **Estimated runtime** | ~10–25 seconds (presenter/Preview tests are headless, no DB) |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors && {quick run command}`
- **After every plan wave:** `mix compile --warnings-as-errors && mix test`
- **Before `/gsd:verify-work`:** Full suite green
- **Max feedback latency:** ~25 seconds

---

## Per-Task Verification Map

Provisional task IDs (the planner refines to real IDs); each row is a behavior the plan's
`<automated>` verify block MUST satisfy. `T-*` threat refs link to the planner's `<threat_model>`.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-W0-01 | W0 | 0 | FLOW-02 | — | — | scaffold | `mix test test/cairnloop/governance/preview_test.exs` | ❌ W0 | ⬜ pending |
| 14-W0-02 | W0 | 0 | FLOW-02 | — | — | scaffold | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ W0 | ⬜ pending |
| 14-W0-03 | W0 | 0 | FLOW-01 | — | — | scaffold | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ⬜ pending |
| 14-W0-04 | W0 | 0 | FLOW-01 | — | — | scaffold | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ⬜ pending |
| 14-01-a | M011-S02-01 | 1 | FLOW-01 | — | `list_proposals_for_conversation/1` returns proposals `desc: inserted_at`, events preloaded `asc` | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ⬜ pending |
| 14-01-b | M011-S02-01 | 1 | FLOW-01 | T-idem | `conversation_id` written on **valid AND blocked** paths (D-07); EXCLUDED from `derive_idempotency_key/4` canonical map (D-08) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ⬜ pending |
| 14-01-c | M011-S02-01 | 1 | FLOW-02 | — | `Preview.render/1` → `{:structured, _}` when no `preview/1` (common path, D-17); falls back when `preview/1` raises / returns non-string / tool unregistered | unit (no DB) | `mix test test/cairnloop/governance/preview_test.exs` | ❌ W0 | ⬜ pending |
| 14-01-d | M011-S02-01 | 1 | FLOW-02 | T-jsonb | `Preview.render/1` handles **string-keyed** snapshot (simulated JSONB round-trip); atomization via `String.to_existing_atom/1` + rescue, never `String.to_atom/1` (D-19) | unit (no DB) | `mix test test/cairnloop/governance/preview_test.exs` | ❌ W0 | ⬜ pending |
| 14-01-e | M011-S02-01 | 1 | FLOW-02 | T-pii | `ToolProposalPresenter.status_label/status_group/risk_tier_label/approval_outlook/reason_label/history_line` total; `reason_label` humanizes `{:missing_scopes, [...]}` without `inspect`; `history_line` catch-all → "Workflow updated" (D-24) | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ W0 | ⬜ pending |
| 14-01-f | M011-S02-01 | 1 | FLOW-02 | T-pii | `input_rows/1` never dumps a raw map — humanized rows or "Unsupported value" (D-22); masking choke point | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ W0 | ⬜ pending |
| 14-02-a | M011-S02-02 | 2 | FLOW-02 | — | `governed_action_card/1` renders all four statuses without crashing; status chip pairs color **and** text (never color-alone, brand §7.5); empty events → calm "No history yet" (`Ecto.assoc_loaded?` guard) | unit (render_component) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ⬜ pending |
| 14-02-b | M011-S02-02 | 2 | FLOW-02 | T-pii | Card surfaces consequence/structured-summary, risk⊥approval⊥status as separate axes (D-13); raw maps only behind expander; footer action slot present but empty (D-05) | unit (render_component) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ⬜ pending |
| 14-03-a | M011-S02-03 | 3 | FLOW-01 | — | `handle_event("execute_tool")` threads `conversation_id`; `reload_conversation_with_context/2` assigns `governed_actions`; rail section renders the timeline | unit (LiveView) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ⬜ pending |
| 14-03-b | M011-S02-03 | 3 | FLOW-01 | T-pii | Blocked proposals (`:needs_input`, `:scope_invalid`, `:policy_denied`) appear durably in the rail (Support-Truth Gate); `failure_reason_message/1` no longer calls `inspect` on scope/policy reason (D-14) | unit (LiveView + source assertion) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ⬜ pending |
| 14-03-c | M011-S02-03 | 3 | FLOW-01 | — | "Execute" → "Propose" rename; hardcoded `#2563eb` replaced with brand token `var(--cl-primary, #A94F30)` (D-04) | source assertion | `grep -n "Propose" lib/cairnloop/web/conversation_live.ex` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/governance/preview_test.exs` (new) — `Preview.render/1` headless: structured-summary common path, all four fallback triggers, string-keyed snapshot variant
- [ ] `test/cairnloop/web/tool_proposal_presenter_test.exs` (new) — all presenter total functions, pure, no DB
- [ ] `test/cairnloop/governance_test.exs` (extend) — `list_proposals_for_conversation/1`; `conversation_id` on valid + blocked paths; `conversation_id` excluded from idempotency key
- [ ] `test/cairnloop/web/conversation_live_test.exs` (extend) — `governed_action_card` rendering; blocked proposals visible in rail; MockRepo returns `governed_actions`
- [ ] No framework install required (ExUnit + Phoenix.LiveViewTest already configured)

Shared fixture: inline `%ToolProposal{}` struct factory per test file (existing repo idiom — no
shared factory module). Each `input_snapshot`/`policy_snapshot` test must include **both** an
atom-keyed and an explicit string-keyed (`%{"k" => v}`) variant to partially simulate the JSONB
round-trip without a live DB.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full JSONB atom→string round-trip on `input_snapshot`/`policy_snapshot` | FLOW-02 (D-19 Footgun 1) | `Cairnloop.Repo` unavailable in this workspace (STATE.md); the real footgun only surfaces on a Postgres INSERT+SELECT | When a repo-backed lane is available: insert a proposal, reload from Postgres, assert `Preview.render/1` + `input_rows/1` behave identically to the string-keyed unit fixtures. Mark stub tests `# REPO-UNAVAILABLE`. |
| Visual brand compliance of the card (rail placement, calm tone, chip color+text pairing) | FLOW-02 | Visual judgement | Run the app, open a conversation with proposals, confirm the "Governed actions" rail section matches brand §10.2 and never conveys state by color alone (§7.5). |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (2 new test files + 2 extensions)
- [ ] No watch-mode flags
- [ ] Feedback latency < 25s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner aligns task `<automated>` blocks)

**Approval:** pending
