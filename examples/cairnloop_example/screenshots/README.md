# Demo screenshots (Playwright capture)

Captures deterministic PNGs of the seeded Cairnloop demo for the docs (`guides/02-jtbd-walkthrough.md`)
and Phase 45 visual evidence. Operator/admin evidence lands in explicit theme directories:
`guides/assets/light/NN-name.png` and `guides/assets/dark/NN-name.png`. Root-level light copies in
`guides/assets/NN-name.png` are retained only for existing guide compatibility.

This is a **capture-only, non-gating** tool. It drives a real browser to take pictures; it asserts
nothing and is deliberately kept out of CI's gating lane. The project's locked decision — _no Wallaby,
no browser assertions in CI (Chrome-in-CI flake is real)_ — is unchanged: the deterministic
`test/integration/golden_path_test.exs` (`Phoenix.LiveViewTest`) remains the single source of CI truth.
A drifted screenshot can never break a build. Screenshots are evidence assets; behavior remains gated
by ExUnit, integration tests, and E2E tests.

## Prerequisites

- Node 18+ and a live, seeded demo app.
- A pgvector Postgres (see the example app README / repo `docker-compose.yml`).

## Usage

```bash
# 1. From examples/cairnloop_example/, boot the seeded demo (reset gives a clean, known state):
mix ecto.reset
mix phx.server                      # PORT=4010 mix phx.server  if 4000 is taken

# 2. From this directory, install + capture:
cd screenshots
npm install
BASE_URL=http://localhost:4000 npm run capture     # match your PORT
```

`npm run capture` installs the Chromium browser on first run, then writes
`guides/assets/light/NN-*.png` and `guides/assets/dark/NN-*.png`.
Use `npm run capture:no-install` to skip the browser download on repeat runs.

Dependency upgrades are outside Phase 45 unless reviewed separately; use the existing locked
Playwright workflow.

## Determinism

- Fixed viewport (1440×900) and device scale (2×).
- Reduced motion + an injected stylesheet that disables animations, transitions, and caret blink.
- Explicit light and dark passes force both the Playwright browser color scheme and Cairnloop's
  `phx:theme` / `data-theme` app state.
- Each shot waits on the LiveView being connected and a concrete target selector — never on sleeps.
- Capturing from the idempotent seed (`mix ecto.reset`) means a fixed dataset every run.

The one remaining source of variation is relative timestamps ("2 days ago"), which shift across day
boundaries because the seed dates resolved conversations relative to _now_. Re-capture on the same day
for byte-identical output; across days the wording of a few timestamps may differ.

## What gets captured

Phase 45 acceptance covers operator/admin states only: cockpit home, inbox triage, conversation
workspace, AI draft approval, governed-action states, recovery flows, knowledge-base screens, audit
log, audit empty state, and settings. Demo index and customer-chat captures may still be written as
root-level docs compatibility assets, but they do not count toward the Phase 45 evidence ledger.

Static captures are motion-stabilized. Live motion, navigation, geometry, and other browser-visible
behavior remain owned by automated tests.
