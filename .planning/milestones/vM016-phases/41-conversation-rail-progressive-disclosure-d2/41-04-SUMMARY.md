---
phase: 41-conversation-rail-progressive-disclosure-d2
plan: "04"
subsystem: web/conversation_live + example-app E2E + CI
tags: [rail, RAIL-03, density, colocated-hook, JS, localStorage, e2e, playwright, ci, D-06, D-09]
dependency_graph:
  requires: ["41-01", "41-02", "41-03"]
  provides:
    - "Rail control bar: Expand-all/Collapse-all (Phoenix.LiveView.JS, [data-tier='2']-scoped) + density toggle (RAIL-03)"
    - "data-density default + compact/comfortable CSS; colocated RailDensity localStorage hook; example app.js wiring"
    - "Browser E2E suite (phoenix_test_playwright) + gated CI e2e lane — automated replacement for the human-verify checkpoint"
  affects:
    - "lib/cairnloop/web/conversation_live.ex"
    - "lib/cairnloop/mix.exs"
    - "priv/static/cairnloop.css"
    - "examples/cairnloop_example/** (E2E harness)"
    - ".github/workflows/ci.yml"
tech_stack:
  added:
    - "phoenix_test_playwright (~> 0.14) — example app test-only"
    - "playwright (npm, example assets/) — Chromium driver"
  patterns:
    - "Colocated LiveView 1.1 hook (RailDensity) referenced via leading-dot phx-hook='.RailDensity'"
    - "Phoenix.LiveView.JS.set_attribute/remove_attribute scoped to [data-tier='2'] (no server event for open state)"
    - "Ecto-sandbox acceptance on_mount injected into the dashboard live_session (test-only) via cairnloop_dashboard's :on_mount passthrough"
    - "Transactional governed-action fixture (no seed dep); in-BEAM PubSub broadcast to exercise phx-update=ignore"
key_files:
  created:
    - examples/cairnloop_example/lib/cairnloop_example_web/live_acceptance.ex
    - examples/cairnloop_example/test/support/rail_fixtures.ex
    - examples/cairnloop_example/test/e2e/rail_disclosure_test.exs
    - examples/cairnloop_example/assets/package.json
    - examples/cairnloop_example/assets/package-lock.json
  modified:
    - lib/cairnloop/web/conversation_live.ex
    - lib/cairnloop/mix.exs
    - lib/cairnloop/credo_checks/no_hardcoded_color.ex
    - priv/static/cairnloop.css
    - examples/cairnloop_example/mix.exs
    - examples/cairnloop_example/config/test.exs
    - examples/cairnloop_example/config/runtime.exs
    - examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex
    - examples/cairnloop_example/lib/cairnloop_example_web/router.ex
    - examples/cairnloop_example/test/test_helper.exs
    - .github/workflows/ci.yml
decisions:
  - "OWNER-VETOABLE ship-and-wire decision: RATIFIED. The operator directive to E2E-verify the colocated hook in a real browser and gate it in CI inherently ratifies shipping + wiring the hook (you cannot browser-test a hook you didn't ship). The library ships the RailDensity colocated hook; the example app wires phoenix-colocated/cairnloop."
  - "Human-verify checkpoint (Task 3) REPLACED by automation: a phoenix_test_playwright suite asserts all client-only behaviors (expand/collapse JS scoping, density+localStorage, reload persistence, open-survives-PubSub) + a keyboard-a11y check. No 41-HUMAN-UAT.md is created; the e2e CI lane gates release_gate. Zero human UAT going forward."
  - "E2E lives in the example app only (not the published library) — honors the carried 'library harness = LiveViewTest only, no PhoenixTest dep' decision; adopters never inherit a browser dep."
  - "Behavior-4 (open-survives-PubSub) triggered via in-BEAM Phoenix.PubSub.broadcast(:message_created) rather than the operator reply form, avoiding an unrelated example-app host-migration gap (cairnloop_conversation_slas missing in the demo's own migrations — flagged below, not fixed here)."
bugs_found_and_fixed:
  - "RailDensity hook never loaded in a browser: library mix.exs lacked the :phoenix_live_view compiler (colocated hook never extracted) AND phx-hook used the non-namespaced 'RailDensity' instead of the colocated '.RailDensity'. Both fixed (commits b8beb98). Caught only by actually bundling + driving the app in a real browser — exactly the gap the manual checkpoint was meant to catch."
  - "cairnloop NoHardcodedColor Credo check hard-failed compilation for any Credo-less consumer (every adopter + the example app's test build) via unconditional `use Credo.Check`; guarded with Code.ensure_loaded? (commit aa6cb6c). Latent adopter-breaking bug surfaced while compiling the lib in the example's :test env."
  - "runtime.exs set the example endpoint HTTP port (PORT||4000) in ALL envs, clobbering config/test.exs's 4002 and colliding with a running dev server. Now gated to non-:test."
open_followups:
  - "Example-app host-migration drift: priv/repo/migrations does not create cairnloop_conversation_slas, so operator reply (Chat.reply_to_conversation) raises in the demo. Pre-existing, unrelated to Phase 41; flagged for a separate fix."
metrics:
  duration: "~3.5 hrs (incl. research + harness infra)"
  completed: "2026-06-04"
  tasks_completed: 3
---

# Plan 41-04 — Rail controls + density + automated client-behavior verification

## What shipped

**Tasks 1–2 (rail controls + density, committed earlier in the phase):** the `.cl-rail-controls`
bar with Expand-all / Collapse-all (`Phoenix.LiveView.JS`, scoped to `[data-tier='2']`), the
`data-density` default + compact/comfortable CSS (token-pure, ≥44px tap targets), the colocated
`RailDensity` localStorage hook, and the example app's `app.js` library-namespace wiring.

**Task 3 (this closure): the human-verify checkpoint was automated away.** Per the operator
directive ("automate the world — real-browser verification in CI, zero human UAT"), a real-browser
`phoenix_test_playwright` E2E suite now verifies every client-only behavior the checkpoint covered:

| Behavior | E2E assertion |
|----------|---------------|
| Expand/Collapse-all scoping | `open` toggles on exactly the 3 `details[data-tier='2']`; never the Tier-3 trace group; Tier-1 footer always visible |
| Density + localStorage | toggle flips `data-density`; `localStorage['cl:rail:density']` updated |
| Reload persistence | after `reload_page`, the hook re-applies the stored density |
| Open-survives-PubSub | an expanded panel stays open across a real `:message_created` re-render (`phx-update="ignore"`) |
| Accessibility | a Tier-2 `<summary>` opens via keyboard (Enter); Approve/Reject/Defer never hidden |

The suite runs locally via `mix test.e2e` and as a gated `e2e` CI lane (added to `release_gate`).

## Ship-and-wire decision: RATIFIED

The recorded default (ship the colocated hook + wire the example app + document for adopters) is
ratified by the automation directive itself — a browser test of the hook presupposes the hook is
shipped and wired. The library ships `RailDensity`; the example consumes
`phoenix-colocated/cairnloop`.

## Defects the automation caught (and we fixed)

Building + driving the app in a real browser exposed three real bugs that markup-only verification
(and 41-04's grep-based self-check) had missed — see `bugs_found_and_fixed` above. The headline:
the `RailDensity` hook **never actually loaded** (missing LV compiler in the library + wrong
`phx-hook` form). This is the concrete payoff of replacing eyeball-UAT with a real-browser gate.

## Self-Check: PASSED

- `mix compile --warnings-as-errors` (library) — clean.
- Library targeted suite (conversation_live + components + brand-token gate) — 112 tests, 0 failures.
- Example app fast suite — 30 tests, 0 failures (e2e excluded).
- `mix test.e2e` (real Chromium) — 4 tests, 0 failures; the colocated hook mounts (no "unknown hook").
- `mix credo` still loads `CL_NoHardcodedColor`; `mix format` clean.
