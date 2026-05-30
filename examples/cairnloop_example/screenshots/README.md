# Demo screenshots (Playwright capture)

Captures deterministic PNGs of the seeded Cairnloop demo for the docs (`guides/02-jtbd-walkthrough.md`)
and the project website. Output lands in `guides/assets/` at the repo root.

This is a **capture-only, non-gating** tool. It drives a real browser to take pictures; it asserts
nothing and is deliberately kept out of CI's gating lane. The project's locked decision — _no Wallaby,
no browser assertions in CI (Chrome-in-CI flake is real)_ — is unchanged: the deterministic
`test/integration/golden_path_test.exs` (`Phoenix.LiveViewTest`) remains the single source of CI truth.
A drifted screenshot can never break a build.

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

`npm run capture` installs the Chromium browser on first run, then writes `guides/assets/NN-*.png`.
Use `npm run capture:no-install` to skip the browser download on repeat runs.

## Determinism

- Fixed viewport (1440×900) and device scale (2×).
- Reduced motion + an injected stylesheet that disables animations, transitions, and caret blink.
- Each shot waits on the LiveView being connected and a concrete target selector — never on sleeps.
- Capturing from the idempotent seed (`mix ecto.reset`) means a fixed dataset every run.

The one remaining source of variation is relative timestamps ("2 days ago"), which shift across day
boundaries because the seed dates resolved conversations relative to _now_. Re-capture on the same day
for byte-identical output; across days the wording of a few timestamps may differ.

## What gets captured

The nine JTBD stages from `guides/02-jtbd-walkthrough.md` plus the knowledge-base, gaps, audit-log,
and settings surfaces. Edit the `SHOTS` array in `capture.mjs` to add or adjust shots.
