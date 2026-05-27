---
phase: 26
slug: observability-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| 26-01-XX | 01 | 1 | OBS-01 | — | enum-only telemetry labels; no PII in metrics namespace | unit | `mix test test/cairnloop/outbound/telemetry/traces_test.exs` | ❌ W0 (new file — mirrors `governance/telemetry/traces_test.exs`) | ⬜ pending |
| 26-01-XX | 01 | 1 | OBS-01 | — | OI traces are sampled span-tree observability; attribution refs OK, free-text NOT | unit | `mix test test/cairnloop/workers/outbound_worker_test.exs` | ✅ existing | ⬜ pending |
| 26-01-XX | 01 | 1 | OBS-01 | — | additive emission alongside existing bounded-metrics spans (sealed) | unit | `mix test test/cairnloop/outbound_test.exs` | ✅ existing | ⬜ pending |
| 26-02-XX | 02 | 2 | OBS-02 | — | narrow `Cairnloop.Governance` facade (no direct `Ecto` queries from web layer) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ existing | ⬜ pending |
| 26-02-XX | 02 | 2 | OBS-02 | — | facade reads return snapshotted envelope rows (no re-derivation at read time) | unit | `mix test test/cairnloop/outbound_test.exs` | ✅ existing | ⬜ pending |
| 26-03-XX | 03 | 3 | Polish (D-08/D-09) | — | calm, reason-forward operator copy; never state-by-color-alone (brand §7.5); brand tokens over hardcoded hex | unit (headless render) | `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/conversation_live_test.exs` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> **Planner: replace `26-XX-XX` task IDs with the real task IDs once each plan is written. The rows above are the requirement-level scaffolding; per-task rows fan out from these.**

---

## Wave 0 Requirements

- [ ] `test/cairnloop/outbound/telemetry/traces_test.exs` — new file covering OBS-01 OI trace module (mirror `test/cairnloop/governance/telemetry/traces_test.exs` verbatim, swap namespace + event atoms + attribution refs).
- [x] ExUnit framework — Elixir stdlib, already installed.
- [x] `:telemetry` library — already in `mix.exs`.
- [x] `MockRepo` test substitution pattern — exists at `test/support/mock_repo.ex` (used by `governance_test.exs` + `outbound_worker_test.exs`).
- [ ] **Confirm during planning:** whether `test/cairnloop/telemetry_test.exs` exists (for D-04 moduledoc check) or whether the D-04 moduledoc gate is reviewed inline at task-commit time per RESEARCH Open Question #1 (planner recommendation: inline review, no pinning test).

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies — planner to populate
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify — planner to confirm
- [ ] Wave 0 covers all MISSING references — confirmed (one new file: `traces_test.exs`)
- [ ] No watch-mode flags — confirmed (`mix test` is one-shot)
- [ ] Feedback latency < 30s — confirmed (~10s headless full suite)
- [ ] `nyquist_compliant: true` set in frontmatter — flip once planner populates the per-task map

**Approval:** pending
