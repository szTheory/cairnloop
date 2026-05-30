# Thread: vM016 — Demo sharpening + visual-proof (screenshots) layer

**Status:** Work done locally, **uncommitted** (working tree changes only). Not run through the
GSD phase structure — this was a user-initiated build off an approved plan, not a `/gsd-new-milestone`
cycle. Owner to review → commit/PR.

**Date:** 2026-05-30

## Why this exists

At a new milestone step the owner asked whether Cairnloop is "blocked on adoption evidence" and
whether it has a realistic demo app with seeds to stress-test install→onboarding→happy-path, give
click-around value, and produce UI screenshots for the website + docs.

**Key correction (ground-truthed on disk):** the premise was outdated. vM014 ("Adoption Proof")
already shipped the demo app (`examples/cairnloop_example/`, the two-tab Trailmark support desk),
a 1,273-line idempotent seed, and the deterministic 9-stage golden-path E2E (CI-gated). The one
genuinely-open gap that matched the ask was the **deferred visual-proof layer (D-01)** — the
`guides/02` SCREENSHOTS TODO, the commented-out `assets: "guides/assets"` in `mix.exs`, and the
absent `guides/assets/` dir. There was no automated capture pipeline.

## What was built (plan: sharpen demo + non-gating Playwright capture)

1. **Frozen showcase states** in `examples/.../priv/repo/seeds.exs` — four additive conversations
   (demo-17..20) pre-positioned via the REAL facades in each JTBD end-state the screenshots need:
   pending AI draft (`Automation.create_draft`), governed action pending approval + executed
   (`Governance.propose`→`request_approval`→`approve` + `ApprovalResumeWorker`/`ToolExecutionWorker`),
   and a durable `:system_outbound` recovery message. Honors the file's D-02/D-04/D-08/D-09 contracts;
   side effects run only on first creation. Bonus: this populates the audit log (was empty by default).
2. **Demo index / JTBD tour page** — replaced the default Phoenix home (`PageController` +
   `home.html.heex`) with a branded Trailmark scenario landing that deep-links each of the 9 JTBD
   stages to the seeded conversation showing it, plus the other operator surfaces. Brand tokens
   (`var(--cl-primary, #A94F30)`), calm copy, no state-by-color-alone.
3. **Deterministic Playwright capture harness** — new `examples/.../screenshots/` (self-contained
   Node project, NOT wired into `mix`). Captures 14 PNGs → `guides/assets/`. Fixed viewport+scale,
   reduced motion, animation-kill CSS, waits-on-condition. **Capture-only, non-gating** — the locked
   "no Wallaby / no browser assertions in CI" decision stands; `golden_path_test.exs` remains CI truth.
4. **Closed D-01** — wired all 14 screenshots into `guides/02-jtbd-walkthrough.md`, uncommented
   `assets: %{"guides/assets" => "assets"}` in the library `mix.exs` (ExDoc 0.40 map form), added
   pointers in the example README + `guides/01-quickstart.md`.

## Latent example-app bugs found + fixed along the way (valuable — these blocked a clean boot)

1. **`mix setup`/`ecto.reset` never migrated the library tables in path-dep mode.** The
   `ecto.setup`/`test` aliases chained two `ecto.migrate` calls; Mix runs a task once per
   invocation, so the second (library migrations) was silently skipped — it only "worked" before
   via a stale `deps/cairnloop` snapshot. Fixed: reenable `ecto.migrate` between two ordered phases
   (host tables first, then library tables — library migs reference host `cairnloop_conversations`,
   so global-version merging is wrong), with a `File.dir?` fallback so it resolves in both hex-dep
   (`deps/cairnloop/...`) and path-dep (`../../priv/...`) modes.
2. **`cairnloop_messages` had no `run_key` column.** It's host-owned (the library only declares it);
   the example never added it, so executing ANY governed write fails (`column run_key does not exist`).
   Added `20260525201624_add_run_key_to_messages.exs` mirroring the library's test-host migration.
3. **Hard-coded ports** made the demo collide with other local services. Added `PORT` (http) and
   `PGPORT` (db) env honoring in the example `config/dev.exs` + `config/test.exs` (matches the repo
   docker-compose + the library's own `config/test.exs`).
4. **Chimeway boot spam.** Chimeway (transitive dep) unconditionally starts its own Repo; unconfigured,
   it floods the dev log AND the browser console (LiveView dev log forwarding) with "missing :database".
   Pointed `Chimeway.Repo` at the demo DB per-env so it connects quietly.

## Verification (all green, against the live pgvector Postgres on :55432 in this workspace)

- `mix compile --warnings-as-errors` (example + library) — clean.
- `mix ecto.reset` — idempotent; seeds 20 conversations, 0 failures; re-run is a no-op.
- Example test suite — **26 tests, 0 failures** (incl. new showcase-states test + updated home test).
- Gating golden-path + widget-channel — **2 tests, 0 failures** (CI lane untouched).
- `mix docs --warnings-as-errors` — passes; all 14 PNGs ship to `doc/assets/`.
- Playwright capture — **14/14** deterministic PNGs.

## Graduation candidates / follow-ups

- The example-app boot-robustness fixes (migration alias, `run_key` migration, `PORT`/`PGPORT`) are
  **adopter-relevant** — worth reflecting in `guides/01-quickstart.md` install guidance (the
  two-step migrate caveat is already there but assumes hex-dep paths).
- The ⌘K search-palette screenshot is omitted: ⌘K/Ctrl+K are browser-reserved and swallowed headless,
  and synthetic keydown isn't honored. Shot 03 captures the conversation workspace instead. (Possible
  latent question: does the real-browser ⌘K shortcut actually fire in production, or only via the
  test's simulated `render_keydown`? Worth a manual check — not verified here.)
- If a website lands later, `guides/assets/*.png` are web-ready (1440×900 @2x).
