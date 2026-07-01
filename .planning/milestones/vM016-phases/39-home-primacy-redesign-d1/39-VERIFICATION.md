---
phase: 39-home-primacy-redesign-d1
verified: 2026-06-04T07:44:56Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: null
  previous_score: null
---

# Phase 39: Home Primacy Redesign (D1) Verification Report

**Phase Goal:** Home honestly represents the operator's primary job — "Work the queue" — with a full-width hero that draws the eye first, Recover-resolved folded in as a quiet sub-line (and linking to the filtered inbox correctly), a calmer secondary "Tend the trail" band with neutral counts, system health expressed as a chip, the dead sixth grid cell removed, and a calm all-caught-up zero state.

**Verified:** 2026-06-04T07:44:56Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Home leads with full-width copper count hero + primary cl_button CTA; Recover-resolved sub-line visible only when count > 0 and links to `/inbox?status=resolved` (resolved filter), not raw inbox | ✓ VERIFIED | `home_live.ex:124` `<.cl_hero job="Work the queue" count={@open_count}>`; `:cta_slot` (137) wraps `<.cl_button variant="primary" size="lg">Open inbox</.cl_button>` in `<.link navigate="/inbox">`; resolved sub-line (129-133) gated on `@resolved_count > 0 and not @resolved_count_unavailable?` with `href="/inbox?status=resolved"`. Distinct destinations: 1× `/inbox?status=resolved`, 0× bare `href="/inbox"`. InboxLive `handle_params/3` (118-129) → `normalize_status("resolved") -> :resolved` (141) → `Chat.list_conversations(status: :resolved)` lands a filtered list. Tests green. |
| 2 | Secondary band shows Tend knowledge, Audit, System health with neutral (non-copper) counts; System health renders as cl_chip "Healthy"/"Degraded", never a numeric count slot | ✓ VERIFIED | `home_live.ex:143-168` grid has exactly 3 children: cl_stat "Tend knowledge", cl_stat "Audit trail", and a hand-built `<div class="cl-stat">` health cell with `<.cl_chip variant={@health_variant} label={@health_label} />`. `system_health/0` (186-208) returns `{true,"Healthy"}` / `{false,"Degraded"}`. Test (home_live_test.exs:129-153) asserts `cl-chip--success`/`--warning` + label and explicitly NOT `cl-stat__count`. Band stat counts use neutral copy/classes (no `cl-hero__count`). |
| 3 | Empty queue → calm success state (icon + text); no confetti; no dead sixth grid cell | ✓ VERIFIED | `home_live.ex:119-122` `@open_count == 0 and not @open_count_unavailable?` → `<.cl_empty icon="check-circle" title="All caught up">Nothing is waiting on you right now.</.cl_empty>`. Grid (143) holds exactly 3 tiles. Test asserts band persists in zero-state and grid has exactly 3 `cl-stat` root tiles (home_live_test.exs:176, ~221). No `confetti` token anywhere in phase files (grep: none). |
| 4 | Brand-token gate (mix test) passes — Home markup has no hardcoded hex | ✓ VERIFIED | `mix test test/cairnloop/web/brand_token_gate_test.exs` → 1 test, 0 failures. `.cl-applied-filter` CSS rule (cairnloop.css:454-457) is token-only (`var(--cl-space-3)`, `var(--cl-surface)`), no raw hex. Home render is class/token-only. |
| 5 | Count queries scoped (not full assign_counts re-query per PubSub tick); safe/2 fail-closed preserved — simulated error returns 0, not exception | ✓ VERIFIED | `chat.ex:29-33` `count_conversations/1` uses `repo().aggregate(:count, :id)` (cheap SELECT count(\*)), no Enum.count. `home_live.ex:70-74` open/resolved via `safe_count(fn -> Chat.count_conversations(status: :open/:resolved) end) \|> split()`. Throttle (50-66): `pending_recount?` coalesce + `Process.send_after(self(), :recount, @recount_ms)` connected-only — one recount per 500ms, not per tick. `safe/2` preserved verbatim (230-236). Spot-check: `safe_count(raise)\|>split = {0,true}`, `safe_count(throw)\|>split = {0,true}`, `safe_count(7)\|>split = {7,false}`. Error returns 0 + unavailable flag, never an exception, never the celebratory zero state (D-06). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/chat.ex` | list_conversations/1 + count_conversations/1 + scope_status/2 | ✓ VERIFIED | All present (20-46). Sealed 0-arity `list_conversations/0` preserved as distinct clause (10-14). Whitelist `[:open, :resolved, :archived]` (43). Parameterized `^status` pin (44). No `to_existing_atom`. |
| `lib/cairnloop/web/inbox_live.ex` | handle_params/3 + normalize_status/1 + filter-aware PubSub + applied-filter row + split-empty | ✓ VERIFIED | handle_params/3 (118-129), normalize_status/1 fail-closed (141-142), filter-aware PubSub (355-359), applied-filter row (165-171), split-empty (177-189), catch-all handle_info/2 (363, WR-01). |
| `lib/cairnloop/web/home_live.ex` | hero + 3-up band + zero-state; scoped assign_counts; throttle; safe_count/1 + split/1; health_variant | ✓ VERIFIED | All present. safe_count/1 (216-222), split/1 (226-227), safe/2 preserved (230-236), no count_or_dash. |
| `priv/static/cairnloop.css` | definite .cl-applied-filter rule, no raw hex | ✓ VERIFIED | Rule at 454-457, token-only. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| home_live assign_counts/1 | Chat.count_conversations/1 | scoped SELECT count(*) per status | ✓ WIRED | `count_conversations(status: :open)` + `(status: :resolved)` at home_live.ex:71,74 → chat.ex:29-33 aggregate. |
| home_live handle_info({:conversations_changed}) | handle_info(:recount) | Process.send_after coalesced by pending_recount? (connected-only) | ✓ WIRED | home_live.ex:50-64. |
| home_live hero sub-line | /inbox?status=resolved | anchor href, shown only when resolved_count > 0 | ✓ WIRED | home_live.ex:129-133. |
| inbox_live handle_params/3 | Chat.list_conversations/1 | list_conversations(status: normalize_status(...)) | ✓ WIRED | inbox_live.ex:119-120. |
| inbox_live handle_params + PubSub | prune_selected_ids/2 | selection reconciliation on every list change | ✓ WIRED | inbox_live.ex:121, 357. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| home_live hero/band | @open_count, @resolved_count, @gaps_count, @audit_count | Chat.count_conversations / KnowledgeAutomation / Governance via safe_count \|> split | ✓ Yes (real query/aggregate; CR-01 fixed — band counts now use safe_count, not bare safe/2) | ✓ FLOWING |
| inbox_live list | @conversations | Chat.list_conversations(status:) via handle_params | ✓ Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Fail-closed count (SC #5) | `safe_count(raise/throw/7/nil) \|> split` | `{0,true},{0,true},{7,false},{0,true}` | ✓ PASS |
| Phase test suites | `mix test chat_test + inbox_live_test + home_live_test` | 124 tests, 0 failures | ✓ PASS |
| Brand-token gate (SC #4) | `mix test brand_token_gate_test.exs` | 1 test, 0 failures | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| HOME-01 | 39-03 | Full-width "Work the queue" hero with copper count + primary cl_button CTA | ✓ SATISFIED | home_live.ex:124-139 |
| HOME-02 | 39-02, 39-03 | Recover-resolved sub-line links to /inbox with resolved filter applied, omitted when zero | ✓ SATISFIED | home_live.ex:129-133 + inbox_live handle_params/normalize_status |
| HOME-03 | 39-03 | Calmer "Tend the trail" band, neutral counts, system health as cl_chip (success/warning), never numeric | ✓ SATISFIED | home_live.ex:143-168; test:129-153 |
| HOME-04 | 39-03 | Dead 6th cell removed, all-caught-up is calm success (icon+text), no confetti | ✓ SATISFIED | home_live.ex:119-122, 143; no confetti |
| HOME-05 | 39-01, 39-03 | Scoped count queries (not per-tick full re-query), throttled, fail-closed safe/2 preserved | ✓ SATISFIED | chat.ex:29-33; home_live.ex:50-74, 216-236; spot-check |

All five declared requirement IDs (HOME-01..05) are present in REQUIREMENTS.md and covered. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TODO/FIXME/XXX/TBD/HACK/PLACEHOLDER/confetti in phase-modified source files. |

### Code-Review Fixes Confirmed

- **CR-01 (BLOCKER, fixed aff4029):** Band counts `gaps_count`/`audit_count` now route through `safe_count(...) |> split()` (home_live.ex:81-87), not bare `safe/2`. The earlier bug (bare value piped into the tuple-only `split/1`, collapsing to `{0, true}`) is gone — `split/1` receives `{:ok, n}`. A regression test composing `safe_count |> split` is present. ✓ CONFIRMED.
- **WR-01 (WARNING, fixed aff4029):** InboxLive has a fail-closed catch-all `def handle_info(_msg, socket), do: {:noreply, socket}` (inbox_live.ex:363), symmetric with HomeLive. ✓ CONFIRMED.

### Human Verification Required

None for goal sign-off (automated evidence covers all 5 success criteria). The plan's manual-only notes (live two-browser recount "feels calm ~500ms, no flicker"; resolved deep-link bookmark/back-button correctness) are UX-feel checks the orchestrator may optionally route to a human, but they are not blocking and the underlying wiring is verified programmatically.

### Gaps Summary

No gaps. All five ROADMAP success criteria are observably true in the codebase, all artifacts exist and are wired with real data flowing, all five requirement IDs are satisfied, the brand-token gate and fail-closed behavior pass, and both code-review findings (CR-01 BLOCKER, WR-01 WARNING) are confirmed fixed. Phase 39 tests: 124 passing, 0 failures. Note: the documented baseline `OutboundWorkerTest` flake and `# REPO-UNAVAILABLE` integration-lane tests are accepted project conventions and not phase-39 regressions.

---

_Verified: 2026-06-04T07:44:56Z_
_Verifier: Claude (gsd-verifier)_
