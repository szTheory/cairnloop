# Phase 45 Discussion Log

Phase: 45 - Seed Enrichment + Screenshot Regen + Verification Sweep
Gathered: 2026-06-26T09:40:12Z
Mode: Discuss

## Initial Prompt

The user invoked `$gsd-discuss-phase 45` and then chose to consider all ambiguous areas. They requested subagent-backed research across software architecture, idiomatic Elixir/Phoenix/Ecto practice, comparable ecosystem lessons, DevOps/SRE verification, DX, UX, accessibility, graphic design, user psychology, JTBD, and project-specific prompt/brand guidance.

The user also asked for a decisive one-shot recommendation set so the plan phase would not require them to think through tradeoffs again.

## Areas Considered

### Fixture State Coverage

Question: How should Phase 45 enrich the example-app data without turning seeds into a brittle fixture system?

Options considered:

- keep enriching `priv/repo/seeds.exs` with deterministic helper builders
- extract a richer seed module/fixture library
- generate larger synthetic demo data
- directly insert every desired state

Recommendation:

Use the existing `seeds.exs` entry point with small grouped helpers, stable natural keys, and public facades wherever possible. Add direct DB updates only for passive seed presentation gaps, with comments and tests.

Why:

This is idiomatic for a Phoenix example app, keeps setup obvious, supports repeatable local demos, and avoids adding a fixture abstraction whose main value would only appear after Phase 45.

Key decisions:

- fill missing states, not volume
- use `ReviewTask.status` for KB review/suggestion states
- create MCP tokens through `MCP.issue_token/1`
- keep higher-risk tool coverage example-app-only
- test idempotency and visible state coverage

### Screenshot and Visual Acceptance Strategy

Question: What should prove final-brand UI quality without creating a brittle visual-testing burden?

Options considered:

- dual-theme screenshot evidence pack plus acceptance ledger
- CI pixel snapshot gate
- manual human UAT
- vendor visual review tooling such as Chromatic or Percy
- a larger route/theme/device matrix

Recommendation:

Create a dual-theme operator/admin screenshot evidence pack and a concise visual acceptance ledger. Keep behavior gates in E2E/integration tests. Do not add CI pixel baselines or vendor visual tooling in this phase.

Why:

The project already treats screenshots as non-gating visual evidence. Playwright pixel assertions can be valuable later, but rendering variance and baseline ownership make them too costly for this closing phase. The acceptance ledger gives release reviewers a human-readable proof trail without weakening automated behavior gates.

Key decisions:

- capture explicit light and dark themes
- force both browser `colorScheme` and app theme state
- exclude demo index/customer chat unless a direct requirement says otherwise
- stabilize motion in static captures
- verify live motion separately through E2E

### Verification and Release Gates

Question: How much verification should Phase 45 require before completion?

Options considered:

- focused tests only
- full local mirror before final green
- rely on CI only
- weaken or narrow release gate due screenshot/data focus

Recommendation:

Use focused lanes during implementation, then run the full local sweep before claiming completion: root tests, integration tests with explicit Postgres env, `mix check`, example-app E2E, screenshot regeneration, and milestone audit/release-gate review.

Why:

Phase 45 is a release confidence phase. Its value comes from proving the final demo/data/visual state and not from rushing through a partial gate. At the same time, requiring expensive lanes after every small seed edit would slow iteration without improving quality.

Key decisions:

- keep `release_gate` canonical
- do not weaken CI
- use Playwright traces/screenshots for debugging
- screenshots are evidence, not behavior gates

## Research Inputs

### Local Project Inputs

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/vM016-UI-ITERATION-BRIEF.md`
- `.planning/phases/44-motion/44-CONTEXT.md`
- `.planning/phases/43-responsive-desktop-first-cockpit-d3/43-CONTEXT.md`
- `.planning/phases/42-cross-screen-threading/42-CONTEXT.md`
- `brandbook/TOKENS.md`
- `logo/USAGE.md`
- `prompts/elixir-lib-customer-support-automation-deep-research.md`
- `prompts/scoria overview for integration ideas.txt`
- `prompts/parapet overview for integration ideas.txt`
- `prompts/cairnloop_brand_book.md`
- `prompts/cairnloop.css`

### Code Inputs

- `examples/cairnloop_example/priv/repo/seeds.exs`
- `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs`
- `examples/cairnloop_example/screenshots/capture.mjs`
- `examples/cairnloop_example/screenshots/README.md`
- `examples/cairnloop_example/mix.exs`
- `mix.exs`
- `.github/workflows/ci.yml`
- `lib/cairnloop/knowledge_base.ex`
- `lib/cairnloop/knowledge_automation.ex`
- `lib/cairnloop/knowledge_automation/review_task.ex`
- `lib/cairnloop/mcp.ex`
- `lib/cairnloop/mcp/token.ex`
- `lib/cairnloop/web/settings_live.ex`
- `lib/cairnloop/tools/internal_note.ex`
- `lib/cairnloop/tool.ex`

### External Sources

- Playwright visual comparisons: https://playwright.dev/docs/test-snapshots
- Playwright emulation: https://playwright.dev/docs/emulation
- Playwright trace viewer: https://playwright.dev/docs/trace-viewer
- Phoenix Ecto SQL Sandbox: https://phoenix-ecto.hexdocs.pm/Phoenix.Ecto.SQL.Sandbox.html
- Phoenix LiveViewTest: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveViewTest.html
- Phoenix seeding guide: https://phoenix.hexdocs.pm/1.3.0-rc.2/seeding_data.html
- Storybook visual tests: https://storybook.js.org/docs/writing-tests/visual-testing

## Final Recommendation

Plan Phase 45 around three coherent workstreams:

- seed missing state coverage with deterministic facade-first data and seed tests
- regenerate explicit light/dark operator screenshots and record visual acceptance
- run the full verification sweep without weakening release gates

The work should improve confidence in the release, not expand product scope. Where a tradeoff is ambiguous, prefer the option that is idiomatic for Phoenix/Ecto, visible to users as a clearer cockpit state, and maintainable by a future contributor rerunning the example app locally.
