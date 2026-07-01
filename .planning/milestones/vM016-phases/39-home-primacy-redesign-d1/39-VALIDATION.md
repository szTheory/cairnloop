---
phase: 39
slug: home-primacy-redesign-d1
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
audited: 2026-06-26
---

# Phase 39 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `39-RESEARCH.md` § Validation Architecture. Test framework: **ExUnit**.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 pinned for format/CI) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/cairnloop/web/home_live_test.exs test/cairnloop/web/inbox_live_test.exs test/cairnloop/chat_test.exs` |
| **Brand gate command** | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| **Full suite command** | `mix test` (excludes `:integration`); CI adds `mix test.integration` |
| **Estimated runtime** | ~10 seconds (headless lane); round-trip tests run only in CI |

**Repo caveat (CLAUDE.md):** `Cairnloop.Repo` may be unavailable in this workspace. Headless
`render/1` and mock-Repo + bare-socket tests are the local pre-merge truth; DB-round-trip tests
are written but marked `# REPO-UNAVAILABLE` and validated in the CI `:integration` lane.

---

## Sampling Rate

- **After every task commit:** Run the quick run command (the touched file's test module).
- **After every plan wave:** Run `mix test` (headless lane, excludes `:integration`).
- **Before `/gsd:verify-work`:** `mix test` green AND brand-token gate green.
- **Max feedback latency:** ~10 seconds (headless lane).

---

## Per-Task Verification Map

| Req ID | Behavior (observable signal) | Test Type | Automated Command | File Exists |
|--------|------------------------------|-----------|-------------------|-------------|
| HOME-01 | Rendered Home has `cl-hero` section with `cl-hero__count` + primary `cl_button` "Open inbox"; hero present only when `open_count > 0` | headless render | `mix test test/cairnloop/web/home_live_test.exs` | ✅ extend |
| HOME-02a | Resolved sub-line `<a href="/inbox?status=resolved">` present when `resolved_count > 0`, ABSENT when `0` | headless render | home_live_test.exs | ✅ extend |
| HOME-02b | `normalize_status("resolved") == :resolved`; garbage/nil/injection → `nil` (fail-closed whitelist, no `String.to_existing_atom`) | pure unit | `mix test test/cairnloop/web/inbox_live_test.exs` | ❌ W0 |
| HOME-02c | `scope_status/2` builds `where status == ^:resolved` (assert via `Ecto.Query` inspect, no Repo) | query-builder unit | `mix test test/cairnloop/chat_test.exs` | ✅ extend |
| HOME-02d | `handle_params(%{"status"=>"resolved"},…)` sets `@status=:resolved` + loads filtered list; PubSub re-query with `@status` so open can't leak | DB-round-trip | `mix test.integration` | ❌ W0 `# REPO-UNAVAILABLE` |
| HOME-03 | Band has exactly 3 tiles; health renders `cl-chip--success`/`--warning` + label, NOT a `cl-stat__count`; band counts neutral (no copper class) | headless render | home_live_test.exs | ✅ extend |
| HOME-04a | `open_count == 0 and not unavailable?` → `cl-empty` + "All caught up"; band still rendered below | headless render | home_live_test.exs | ✅ extend |
| HOME-04b | No phantom 6th cell: `.cl-home-grid` contains exactly 3 `.cl-stat` children | headless render | home_live_test.exs | ❌ W0 assertion |
| HOME-05a | `count_conversations(status: …)` issues a single `count` aggregate over scoped query (no full load) | query-builder + round-trip | chat_test.exs (`# REPO-UNAVAILABLE` for value) | ✅ extend |
| HOME-05b | Burst of N `{:conversations_changed}` arms AT MOST one `:recount`; `:recount` clears `pending_recount?` + recomputes | deterministic message-injection | home_live_test.exs | ❌ W0 |
| D-06 | count helper `:error` → integer renders `0` AND "Count unavailable" sub-line; genuine `0` renders "All caught up" NOT "Count unavailable" | headless render + pure unit | home_live_test.exs | ❌ W0 |
| BRAND | Rendered Home/Inbox markup has no `var(--cl-…, #…)` (existing gate) AND no raw `#[0-9A-Fa-f]{6}` (recommended new assertion) | ExUnit gate | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ extend |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — executor stamps per task.*

**Throttle without flakiness (no `sleep`):** on a connected/mock socket, send
`{:conversations_changed}` once → assert `pending_recount?: true`; send 4× more → assert flag
stays `true` and counts unchanged (coalesce); send `:recount` → assert `pending_recount?: false`
and counts recomputed. On a bare/disconnected socket, assert `{:conversations_changed}` arms no
timer and the flag stays `false` (proves the `connected?/1` guard).

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/inbox_live_test.exs` — new `describe "normalize_status/1"` (pure whitelist) + `handle_params/3` mock-repo tests.
- [ ] `test/cairnloop/chat_test.exs` — `scope_status/2` query-shape assertions (inspect `Ecto.Query`) + `# REPO-UNAVAILABLE` count tests.
- [ ] `test/cairnloop/web/home_live_test.exs` — extend assigns helper with new keys (`open_count_unavailable?`, `resolved_count_unavailable?`, band-tile unavailable flags, `health_variant`); add hero / zero-state / 3-cell / Count-unavailable / throttle describes. **Existing tests at lines 26–61 WILL break** (job label "Recover resolved" removed; "—" dash path → "Count unavailable"; 5-card assertion → 3 tiles + hero) — update them as part of the work, do not leave stale.
- [ ] No framework install needed (ExUnit present).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live PubSub recount latency feels calm (~500ms, no flicker) under real traffic | HOME-05 | Perceptual timing not asserted in tests (deterministic coalesce proof covers correctness) | Open Home in two browsers; resolve/open conversations in one; confirm the other's counts settle smoothly without per-tick flicker |
| Resolved deep-link is bookmarkable / back-button-correct in a real browser | HOME-02 | URL/history behavior is browser-level | Click Recover-resolved → `/inbox?status=resolved`; refresh + back button retain filter state |

---

## Validation Sign-Off

- [ ] All tasks have an automated verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s (headless lane)
- [ ] `nyquist_compliant: true` set in frontmatter (planner/executor sets when map is complete)

**Approval:** pending

## Validation Audit 2026-06-26

Post-execution closeout reconciled this draft strategy against `39-VERIFICATION.md` and Phase 45's
final sweep.

| Metric | Count |
|--------|-------|
| Requirements audited | 5 (HOME-01..05) |
| Requirements satisfied in phase verification | 5 |
| Blocking validation gaps | 0 |
| Superseded manual-only items | 2 |

**Evidence:** `39-VERIFICATION.md` records 5/5 must-haves verified, the phase test suites passing
124 tests with 0 failures, and the brand-token gate passing. Phase 45 later records the full root
suite, integration lane, example E2E, and screenshot capture all passing.

**Verdict:** NYQUIST-COMPLIANT. The unchecked planning boxes above are historical draft-plan
state; the shipped phase has automated coverage for all HOME requirements.
