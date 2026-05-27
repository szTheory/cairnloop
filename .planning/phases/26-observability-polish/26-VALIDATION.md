---
phase: 26
slug: observability-polish
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) |
| **Config file** | `test/test_helper.exs` (default suite excludes `:integration` tag — lines 11-12) |
| **Quick run command** | `mix test <touched-file>` |
| **Full suite command** | `mix test` (headless — `# REPO-UNAVAILABLE` integration arms are tagged `@tag :integration` and excluded by default) |
| **Build gate** | `mix compile --warnings-as-errors` MUST be clean (CLAUDE.md mandatory) |
| **Estimated runtime** | ~10s headless full suite |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors && mix test <touched-file>`
- **After every plan wave:** Run `mix compile --warnings-as-errors && mix test` (full headless suite)
- **Before `/gsd:verify-work`:** Full headless suite must be green; the known baseline `Automation.DraftTest` pre-existing failure is NOT a Phase 26 regression (per memory)
- **Max feedback latency:** ~10 seconds (headless suite)

---

## Per-Task Verification Map

> Populated by the planner during plan creation. Each task row binds a `<task_id>` → `<requirement>` → `<automated_command>` → `<file_exists>` decision so executors and verifiers can sample feedback without re-deriving the map.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-01-01 | 01 | 1 | OBS-01 | T-26-01 | enum-only telemetry labels; OI trace metadata is attribution-refs-only (no `:content`, no `:rendered_body`, no `:refused_reason`); fail-closed guard clause for unknown atoms; disjoint 4-segment namespace `[:cairnloop, :outbound, :trace, <event>]` | unit | `mix test test/cairnloop/outbound/telemetry/traces_test.exs` | ❌ W0 (Plan 01 Task 1 CREATES this file — mirrors `governance/telemetry/traces_test.exs`) → ✅ once Task 1 runs | ⬜ pending |
| 26-01-02 | 01 | 1 | OBS-01 | T-26-02 | bounded-metrics delivery events emit enum-only labels (`:outcome`, `:count`, `:reason`); OI trace events carry attribution refs; sealed Phase 25 D-11 unique-clause untouched | unit | `mix test test/cairnloop/workers/outbound_worker_test.exs` | ✅ existing | ⬜ pending |
| 26-01-03 | 01 | 1 | OBS-01 | T-26-05 | additive OI trace emissions around the sealed `:telemetry.span/3` bounded-metrics blocks in `Outbound.trigger/2` and `bulk_trigger/2` lanes; rescue path emits `:trigger_failed` and reraises so the OI lane reflects the raise without swallowing it | unit | `mix test test/cairnloop/outbound_test.exs` | ✅ existing | ⬜ pending |
| 26-02-01 | 02 | 2 | OBS-02 | T-26-06, T-26-08 | narrow `Cairnloop.Governance` facade (no direct `Cairnloop.Repo` references — only `repo()` indirection); 500-row hard cap raised via `ArgumentError`; MockRepo dispatch arm mirrors the `cairnloop_conversations` template at `test/cairnloop/governance_test.exs:64-96` (query-inspection approach — no `Process.put` filter alternative) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ existing | ⬜ pending |
| 26-02-02 | 02 | 2 | OBS-02 | T-26-07 | auditor metadata key SET for `:outbound_trigger` (`[:conversation_id, :template_id]`) and `:bulk_outbound_trigger` (`[:bulk_envelope_id, :count, :template_id]`) pinned via `Enum.sort()` equality + negative `refute Map.has_key?` for PII-rich keys | unit | `mix test test/cairnloop/outbound_test.exs` | ✅ existing | ⬜ pending |
| 26-03-01 | 03 | 3 | Polish (D-08) | T-26-10, T-26-11, T-26-14 | calm reason-forward operator copy ("No conversations yet."); `aria-label="Close"` + 44px tap target on modal `×`; brand-token muted color via `var(--cl-text-muted, …)`; `has_visible_eligible?/1` regression gate preserved on non-resolved cohorts | unit (headless render) | `mix test test/cairnloop/web/inbox_live_test.exs` | ✅ existing | ⬜ pending |
| 26-03-02 | 03 | 3 | Polish (D-09) | T-26-10, T-26-12, T-26-13 | failed-bubble subhead ("Delivery did not complete. Try again from the Outbound recovery card.") renders ONLY on `outbound_status_label(msg) == "Failed"`; existing chip + `outbound_recovery_card/1` `aria-label="Outbound recovery"` untouched (sealed Phase 22/24); Phase 25 `has_visible_eligible?/1` (Phase 25 plan 03 D-14) is the dependency for the non-resolved-cohort empty-bulk-header assertion in Plan 03 Task 1 Test 8 (sibling regression) | unit (headless render) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> **Mapping note:** Plan 01 has 3 tasks (Task 1 = traces module + test, Task 2 = OutboundWorker delivery telemetry, Task 3 = Outbound.trigger/2 + bulk lanes + moduledoc). Plan 02 has 2 tasks (Task 1 = Governance facade reads, Task 2 = auditor metadata regression). Plan 03 has 2 tasks (Task 1 = InboxLive empty state + modal `×`, Task 2 = ConversationLive failed subhead + a11y verification). Per-task rows above correspond 1:1.

---

## Wave 0 Requirements

- [x] `test/cairnloop/outbound/telemetry/traces_test.exs` — new file covering OBS-01 OI trace module. **Created by Plan 01 Task 1 (26-01-01) as part of the RED-GREEN cycle (TDD).** Mirrors `test/cairnloop/governance/telemetry/traces_test.exs` verbatim with namespace + event atom + attribution-ref swap.
- [x] ExUnit framework — Elixir stdlib, already installed.
- [x] `:telemetry` library — already in `mix.exs`.
- [x] `MockRepo` test substitution pattern — exists at `test/support/mock_repo.ex` (used by `governance_test.exs` + `outbound_worker_test.exs`).
- [x] **Confirmed during planning:** `test/cairnloop/telemetry_test.exs` does NOT exist; the D-04 moduledoc gate is reviewed inline at task-commit time per RESEARCH Open Question 1 (RESOLVED — no pinning test, follows existing precedent).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Integration assertions on `Cairnloop.Governance.list_recent_bulk_outbound_envelopes/1` returning real `BulkEnvelope` rows after a `bulk_trigger/2` round-trip | OBS-02 | `Cairnloop.Repo` is REPO-UNAVAILABLE in this workspace — tagged `@tag :integration` and excluded from default headless run | Operator runs `mix test.integration --only integration` on a Postgres host once Phase 25 BLOCKING gates have been cleared (mirrors Phase 25 BLOCKING checkpoint pattern) |
| InboxLive empty-state appearance (visual confirmation that "No conversations yet." copy lands under the `<h1>` with brand-token muted color and no toolbar/bulk header) | Polish (D-08) | Brand-token visual outcome is not asserted by headless tests (only inline-style strings are asserted) — operator confirms final visual via dev server | Operator runs `mix phx.server`, visits the example app's inbox route with zero conversations, confirms calm copy + no toolbar |
| Modal close-button affordance (44px tap target, ghost styling, calm color, `aria-label="Close"`) — visual confirmation | Polish (D-08) | Tap-target + visual prominence are not asserted by headless tests | Operator opens the bulk-send confirm dialog in the example app, confirms the top-right `×` is discoverable and tappable |
| ConversationLive failed-bubble subhead appearance ("Delivery did not complete. Try again from the Outbound recovery card.") with calm muted color, sitting under the chip | Polish (D-09) | Brand-token visual outcome — see above | Operator triggers a notifier failure on a resolved conversation, confirms the calm subhead renders alongside the `"Failed"` chip and points to the Outbound recovery card |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — populated above (every task row binds an `<automated>` command; the only Wave 0 file is created by 26-01-01 itself per TDD RED-GREEN)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — confirmed (every task row has `<automated>`; no gaps)
- [x] Wave 0 covers all MISSING references — confirmed (one new file: `traces_test.exs`, created in 26-01-01 RED step)
- [x] No watch-mode flags — confirmed (`mix test` is one-shot, no `--watch` anywhere)
- [x] Feedback latency < 30s — confirmed (~10s headless full suite)
- [x] `nyquist_compliant: true` set in frontmatter — flipped (line 5)

**Approval:** approved 2026-05-27
