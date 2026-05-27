---
phase: 25
slug: bulk-selection-fan-out
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-27
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: distilled from `25-RESEARCH.md` § "Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + `Phoenix.LiveViewTest` + `Cairnloop.ConnCase` (integration) |
| **Config file** | `mix.exs` aliases (mix.exs:54-71) — `test.setup`, `test.integration`, default `mix test` |
| **Quick run command** | `mix test test/cairnloop/<changed-file>` |
| **Full suite command** | `mix test` (headless suite; excludes `:integration` tag) |
| **Estimated runtime** | ~30s headless; full integration unavailable here per D-16 (REPO-UNAVAILABLE) |

Build invariant per D-15: `mix compile --warnings-as-errors` MUST be clean before any commit.

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors && mix test test/cairnloop/<changed-file>`
- **After every plan wave:** Run `mix test` (full headless suite — REPO-UNAVAILABLE tests skip via `:integration` tag)
- **Before `/gsd:verify-work`:** Full suite must be green; `mix test.integration` is best-effort under D-16 (must pass on a host with `Cairnloop.Repo`)
- **Max feedback latency:** ~30s for headless suite

Per-test boundary explosion is avoided (Nyquist): cap is tested at `cap` and `cap+1` only; recipient count is sampled at 1, cap-boundary, cap+1; row mix is sampled at "all resolved" / "mixed" / "all open" — not exhaustively.

---

## Per-Task Verification Map

> Tasks granular IDs are placeholder pending PLAN.md generation. Each row maps a REQ-ID
> to the concrete test command from RESEARCH.md § "Phase Requirements → Test Map".

| Req | Behavior | Test Type | Automated Command | File Exists | Headless |
|-----|----------|-----------|-------------------|-------------|----------|
| BULK-01 | `toggle_select` adds/removes id from `@selected_ids` MapSet | LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_toggle_select` | ❌ W0 | ✅ |
| BULK-01 | "Select all visible" toggles all rendered eligible ids | LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_select_all_visible` | ❌ W0 | ✅ |
| BULK-01 | Navigate-away clears `@selected_ids` (D-04) | LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_navigate_away_clears_selection` | ❌ W0 | ✅ |
| BULK-01 | Cohort eligibility read goes through `Cairnloop.Governance` (D-14) | unit | `mix test test/cairnloop/governance_test.exs:test_list_eligible_conversation_ids_for_bulk_recovery` | ❌ W0 | ✅ |
| BULK-02 | Modal renders count + first-5 sample + "+N more" tail + rendered body | component | `mix test test/cairnloop/web/inbox_live_test.exs:test_modal_renders_preview` | ❌ W0 | ✅ |
| BULK-02 | Cancel modal preserves `@selected_ids` (D-08) | LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_cancel_preserves_selection` | ❌ W0 | ✅ |
| BULK-02 | `bulk_trigger/2` snapshots `rendered_body` (no re-render at worker) | unit | `mix test test/cairnloop/outbound_test.exs:test_bulk_trigger_snapshots_body` | ❌ W0 | ✅ |
| BULK-02 | `bulk_trigger/2` writes ONE `BulkEnvelope` row + N `Outbound.trigger/2` via `Ecto.Multi.merge` | unit (DB) | `# REPO-UNAVAILABLE` — `mix test.integration` | ❌ W0 | ❌ tag and gate |
| BULK-03 | `length(ids) > max_batch_size` → `{:error, :batch_too_large}`; persists nothing | unit | `mix test test/cairnloop/outbound_test.exs:test_bulk_trigger_cap_refusal` | ❌ W0 | ✅ |
| BULK-03 | LiveView refuses with calm copy + icon (D-10) when oversized | LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_oversized_refusal_copy` | ❌ W0 | ✅ |
| BULK-03 | Oban job args carry `bulk_envelope_id`, `conversation_id`, `template_id` | unit | `mix test test/cairnloop/outbound_test.exs:test_bulk_trigger_threads_envelope_id` | ❌ W0 | ✅ |
| BULK-03 | Oban `unique:` dedup prevents double-enqueue under same `(conversation_id, template_id, bulk_envelope_id)` | integration | `# REPO-UNAVAILABLE` — `mix test.integration` | ❌ W0 | ❌ tag and gate |
| UI-03 | Sticky bar visibility tracks `MapSet.size > 0` | component | `mix test test/cairnloop/web/inbox_live_test.exs:test_sticky_bar_visibility` | ❌ W0 | ✅ |
| UI-03 | Sticky bar uses `var(--cl-primary, #A94F30)` + icon-not-color-alone | render | grep on rendered HTML for token + icon SVG | ❌ W0 | ✅ |
| UI-03 | Modal traps focus via `<.focus_wrap>` | markup | `assert has_element?(view, "[id$=-focus-wrap]")` after open | ❌ W0 | ✅ |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky.*

---

## What each test layer catches

- **Pure / total-function tests** (preferred per D-16): MapSet math, cap-validation function, refusal-copy string, telemetry label shape. Catches: pure-logic bugs, off-by-one, copy regressions, telemetry label leakage.
- **Headless `Phoenix.LiveViewTest`** (against `InboxLive` with stubs for `Outbound`/`Governance`): selection state, sticky-bar visibility, modal render, refusal banner, focus markup. Catches: assigns drift, focus/keydown wiring, a11y markup regressions.
- **Headless `Outbound` unit tests** (`MockRepo` per existing `test/cairnloop/outbound_test.exs`): `bulk_trigger/2` shape, `{:error, :batch_too_large}`, snapshot persistence, telemetry emit. Catches: contract regressions, snapshot drift.
- **Integration-only (`mix test.integration`, REPO-UNAVAILABLE here)**: Oban uniqueness constraint actually rejecting a duplicate enqueue; `Ecto.Multi` atomicity (rollback when envelope insert fails); FKs. Mocks can't faithfully reproduce these — they MUST be written and tagged `# REPO-UNAVAILABLE` so they run on a Postgres-available host.

---

## Wave 0 Requirements

- [ ] `test/cairnloop/outbound/bulk_envelope_test.exs` — schema validation, required fields, `count > 0` invariant.
- [ ] `test/cairnloop/outbound_test.exs` — extend with `bulk_trigger/2` happy path, cap refusal, snapshot persistence, telemetry emit.
- [ ] `test/cairnloop/governance_test.exs` — verify `list_eligible_conversation_ids_for_bulk_recovery/1` (and any cohort-preview function) return the documented shape (headless against MockRepo).
- [ ] `test/cairnloop/workers/outbound_worker_test.exs` — extend to assert new `unique:` clause and `bulk_envelope_id` arg threading.
- [ ] `test/cairnloop/web/inbox_live_test.exs` — extend for selection MapSet handlers, sticky-bar render, modal open/cancel, refusal banner, `<.focus_wrap>` markup.

*Pure infra deps (`ExUnit`, `Phoenix.LiveViewTest`, `Mox`, MockRepo): already installed. Wave 0 is fixture/skeleton scaffolding only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bulk send produces N `system_outbound` cards on each conversation timeline (D-A) | BULK-02 | Requires a `Cairnloop.Repo` round-trip + browser inspection; REPO-UNAVAILABLE per D-16 | After running `bulk_trigger/2`, open each affected conversation in dev; confirm a single `system_outbound` card per send, with snapshotted template body. |
| Tab order through modal: Cancel → Confirm send → first sample row (keyboard a11y) | UI-03 | Focus order is asserted via `<.focus_wrap>` markup test, but real tab order requires a browser. | Open inbox in dev, select 3 conversations, press the bulk action button, tab through the modal. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (headless suite)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
