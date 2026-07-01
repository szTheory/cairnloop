---
phase: 41
slug: conversation-rail-progressive-disclosure-d2
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-04
audited: 2026-06-26
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `41-RESEARCH.md` §"Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`use ExUnit.Case, async: true` for component tests) + `Phoenix.LiveViewTest` |
| **Config file** | none custom — standard `test/test_helper.exs` |
| **Quick run command** | `mix test test/cairnloop/web/components_test.exs test/cairnloop/web/conversation_live_test.exs` |
| **Full suite command** | `mix test` (default; **excludes `:integration`**) |
| **Estimated runtime** | ~5–15 seconds (DB-free; headless `render_component`) |
| **Build gate** | `mix compile --warnings-as-errors` (mandatory per CLAUDE.md) |

**Repo caveat (CLAUDE.md):** `Cairnloop.Repo` may be unavailable in this workspace. **No Phase 41
rail-render test needs it** — `governed_action_card/1` renders from a plain `%ToolProposal{}` struct
fixture via `render_component`. Therefore **no `# REPO-UNAVAILABLE` markers are required** for this
phase's validation tests.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/web/components_test.exs test/cairnloop/web/conversation_live_test.exs` + `mix compile --warnings-as-errors`
- **After every plan wave:** Run `mix test` (full default suite)
- **Before `/gsd:verify-work`:** Full default suite green + warnings-clean build. `mix test.integration` is NOT required (no DB/integration surface in this phase).
- **Max feedback latency:** ~15 seconds
- **Baseline flakes (do not count as regressions):** OutboundWorkerTest + a SettingsLive order-flake — verify-in-isolation per MEMORY.

---

## Server-Testable vs. Client-Only Boundary (the honest floor)

| Success criterion / requirement | Server-testable? | Assertion strategy |
|----|----|----|
| Tier-1 never collapses (RAIL-01) | **YES** | Quartet + pending footer markup renders *outside* any `<details>` (structural sibling assertion) |
| 3 separate Tier-2 `<details>` (Inputs/History/Policy) | **YES** | 3 `cl_disclosure` groups present with `data-tier="2"` + correct summaries |
| Trace moved to standalone collapsed Tier-3 (D-02) | **YES** | "Identifiers & trace" `cl_disclosure` present, default-closed (no `open`), NOT `data-tier="2"` |
| Survives PubSub re-render (RAIL-02) | **PROXY** | Each rail `<details>` carries `phx-update="ignore"` AND `open` is static-only (mechanism assertion) |
| Auto-expand pending/blocked at initial render (D-08) | **YES (positive)** | Pending/blocked fixture → Inputs group emits static `open`; `policy_denied` → Policy group also `open` |
| No mid-session re-snap-open (D-09) | **PROXY (render-purity)** | Source assertion: no `handle_event`/assign flips `open`; companion `cl_disclosure` static-only unit test |
| Expand-all/Collapse-all via `JS`, not touching Tier 1/3 (RAIL-03) | **PARTIAL** | Rendered `phx-click` carries `JS.set_attribute({"open",""})`/`remove_attribute("open")` scoped to `[data-tier="2"]`; Tier-3/Trace lack `data-tier` |
| `cl_disclosure` proves no server assign controls open (criterion 4) | **YES (exists)** | `components_test.exs:258-314` already; extend with card-level "every `<details>` is patch-safe" test |
| Density localStorage round-trip + applied on mount (RAIL-03) | **NO (client-only)** | Floor: assert `data-density="comfortable"` default + toggle control markup + (if shipped) colocated hook script. localStorage round-trip = deferred E2E. |

---

## Per-Task Verification Map

> Task IDs are placeholders until the planner assigns plan/wave numbers. The planner MUST keep an automated `<verify>` (or Wave 0 dep) on every row.

| Req | Behavior | Wave | Test Type | Automated Command | File Exists | Status |
|-----|----------|------|-----------|-------------------|-------------|--------|
| RAIL-01 | Quartet + pending footer render outside `<details>` | 0 | component (headless) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 (file exists, new test) | ⬜ pending |
| RAIL-02 | 3 Tier-2 + Trace groups all `phx-update="ignore"`, static-open only | 0 | component (headless) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 | ⬜ pending |
| RAIL-02 | `cl_disclosure` static-only `open` (criterion 4) | 0 | component (primitive) | `mix test test/cairnloop/web/components_test.exs` | ✅ exists (`:258-314`) — extend | ⬜ pending |
| RAIL-03 | Auto-expand positive (pending/blocked) + negative (non-pending closed) | — | component (headless) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 | ⬜ pending |
| RAIL-03 | D-09 no-resnap render-purity (source/structural) | — | component + source-grep | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 | ⬜ pending |
| RAIL-03 | Expand/Collapse-all `JS` command shape scoped to `[data-tier="2"]` | — | component (markup) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 | ⬜ pending |
| RAIL-03 | Density default `data-density` + control markup (localStorage round-trip deferred) | — | component (markup floor) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/web/conversation_live_test.exs` — add a `describe "governed_action_card/1 — Phase 41 rail disclosure"` block covering: Tier-1 isolation (RAIL-01), 3 Tier-2 groups + Trace group structure (RAIL-02), every-`<details>`-is-`phx-update=ignore` (RAIL-02), auto-expand positive/negative (D-08), D-09 render-purity, Expand/Collapse-all `JS` shape, density default + control markup (RAIL-03).
- [ ] `test/cairnloop/web/components_test.exs` — extend the existing `cl_disclosure` block IF a `:rest`/`data-tier` passthrough is added to the primitive (assert `data-tier="2"` reaches the `<details>`).
- [ ] Fixture: `tool_proposal_fixture/1` may need an `approval:` override path for the pending-auto-expand case (builder at `:1622` already merges arbitrary overrides — confirm the `:approval` assoc shape).
- [ ] Framework install: **none** — ExUnit + LiveViewTest present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Density preference survives a real page refresh (localStorage round-trip) | RAIL-03 | Client-only; no E2E/browser layer exists in the repo. Server tests can only assert the hook/markup is present, not that the browser persists the value. | In the example app, toggle Comfortable↔Compact, refresh the page, confirm the chosen density is reapplied. Confirm the colocated density hook is wired into the consumer `app.js`. |
| `<details>` open panel survives a live PubSub re-render without snapping shut | RAIL-02 | Open state is browser-native; server can only assert the `phx-update="ignore"` + static-`open` mechanism, not the live DOM outcome. | Open a Tier-2 panel, trigger a conversation PubSub update (e.g. a new event), confirm the panel stays open. |

*Server-side mechanism assertions (`phx-update="ignore"` present, `open` static-only) are the accepted automated floor for both rows above; the manual checks confirm the end-to-end client outcome.*

---

## Security Notes (carried from RESEARCH §"Security Domain")

This phase is UI restructuring with no new auth/crypto/access-control surface. Only V5 (Output Encoding) applies:
- All rail values render via HEEx `{...}` auto-escaping; `cl_fact_list` never uses `raw/1`.
- Raw snapshots use `inspect/2` (escaped string in `<pre>`), behind default-closed D-22 expanders.
- D-02 *strengthens* the masking choke point by collapsing the previously-always-visible trace `dl` into a default-closed Tier-3 group.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

## Validation Audit 2026-06-26

Post-execution closeout reconciled this draft strategy against `41-VERIFICATION.md` and Phase 45's
final sweep.

| Metric | Count |
|--------|-------|
| Requirements audited | 3 (RAIL-01..03) |
| Observable truths verified | 4/4 |
| Blocking validation gaps | 0 |
| Browser behaviors automated | 5 behaviors in the E2E rail suite |

**Evidence:** `41-VERIFICATION.md` records Tier-1 pinning, native `details` disclosure, static
auto-open behavior, scoped expand/collapse JS, density persistence, and E2E-backed reload behavior.
Phase 45 later records the full root suite, integration lane, example E2E, and screenshot capture all
passing.

**Verdict:** NYQUIST-COMPLIANT. The unchecked planning boxes above are historical draft-plan state;
the shipped phase has automated coverage for all rail requirements.
