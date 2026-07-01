# Phase 45: Seed Enrichment + Screenshot Regen + Verification Sweep - Context

Gathered: 2026-06-26T09:40:12Z
Status: Ready for planning

<domain>
Phase 45 is a closing evidence phase for the operator/admin cockpit. It should prove that the final vM017 brand direction, enriched demo data, screenshots, and verification gates hold together as one coherent product slice.

This phase is about SEED-01, VERIFY-01, and VERIFY-02:

- enrich deterministic example-app seeds so real product states are visible without manual setup
- regenerate operator/admin screenshots in explicit light and dark themes
- record per-screen visual acceptance evidence
- run the complete verification sweep before claiming the milestone green

Keep the scope narrow. Do not restyle the customer chat widget, demo index, marketing pages, or unrelated library surfaces. Do not introduce new product capabilities, vendor visual tooling, CI pixel gates, or generated/random fixture data. Phase 45 should consume the locked brandbook, tokens, and logo assets rather than revisiting brand direction.

The project vision still matters: Cairnloop is an embedded, host-owned Ecto/Phoenix customer-support automation library. The operator cockpit should make support work, knowledge maintenance, governed AI actions, auditability, and recovery understandable without exposing backend implementation details. Evidence should be useful to future maintainers and release reviewers, not just pretty pictures.
</domain>

<decisions>
## Seed Enrichment

### D-01: Use facade-first incremental builders in the existing seed script

Keep `examples/cairnloop_example/priv/repo/seeds.exs` as the Phase 45 entry point. Add small idempotent helper builders there unless readability becomes a real blocker. Prefer stable natural keys and existing public facades over direct schema inserts.

Pros:

- matches Phoenix/Ecto convention for example-app seeds
- keeps the demo reproducible with `mix run priv/repo/seeds.exs`
- avoids introducing a second seed DSL or fixture framework
- keeps seed behavior close to the example app that consumes it

Cons and tradeoffs:

- `seeds.exs` can grow long if helpers are not grouped well
- complex state setup may require a few direct updates where no facade exists
- planner must keep helper names and comments clear enough for future maintainers

Implementation guidance:

- create real behavior first through facades
- only backdate or tweak passive presentation fields after records exist
- keep every seeded object deterministic and re-runnable
- add tests in `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs`

### D-02: Fill only the missing state coverage

Existing seeds already cover conversation cohorts, pending AI draft, pending and executed `InternalNote` governed actions, outbound recovery, gaps, one ready article suggestion, published and archived article revisions, and chunks.

Add the missing states that make Phase 45 screenshots and verification meaningful:

- rejected and deferred governed-action audit events with human-readable reasons
- varied audit timestamps across roughly 14 days for realistic chronology
- rejected, deferred, and published knowledge review-task states
- one draft knowledge article with a draft revision left unpublished
- one or two active MCP token rows for Settings UI proof
- one example-app-only higher-risk governed tool proposal

Do not inflate the seed volume just to look busy. Better state coverage beats more rows.

### D-03: Represent knowledge suggestion states through ReviewTask

Use `Cairnloop.KnowledgeAutomation.ReviewTask.status` for rejected, deferred, approved-ready, and published knowledge-review states. Do not invent new `ArticleSuggestion` statuses or model states.

Use public functions such as `reject_review_task/2`, `defer_review_task/2`, approval, and publish flows where possible. If a state cannot be reached through a facade, document the direct seed-only manipulation and test the resulting UI/state contract.

### D-04: Seed MCP tokens through the MCP facade

Create example tokens with `Cairnloop.MCP.issue_token/1` only when a stable token name is absent. Discard the raw token immediately. The Settings UI should show masked identifiers such as `cl_mcp_***`; tests should assert count, presence, and masking behavior, not raw secret values.

This keeps the seed aligned with library security behavior and avoids teaching contributors to insert token hashes by hand.

### D-05: Keep higher-risk tool coverage example-app-only

Add a demo-only governed tool in the example app if the current `InternalNote` low-write tool cannot show the desired approval/risk state. Prefer `:high_write` with approval required unless the plan proves a `:destructive` no-op tool is necessary to show a boundary condition.

The tool should make policy/risk visible without performing a real destructive side effect. Do not broaden the public library API for this phase.

### D-06: Use direct DB writes only for passive seed presentation

Direct DB manipulation is acceptable only when no facade exists and the field is passive display evidence, such as seed-owned timestamps, ordering, or explanatory audit metadata. It is not acceptable for bypassing behaviorful transitions when a public context function exists.

Document direct updates with short comments and tests so they are obviously seed-only.

## Screenshot and Visual Acceptance

### D-07: Build an evidence pack, not a pixel gate

Extend the screenshot pipeline for explicit light and explicit dark operator/admin captures. Do not add a CI pixel/snapshot gate, Percy, Chromatic, or Storybook visual review in Phase 45.

This is the least-surprise approach for this repo: screenshots are milestone evidence and docs assets; behavior is gated by tests. Browser rendering can vary by platform, fonts, GPU, and headless mode, so CI pixel comparisons would need a separate ownership model and pinned environment before they are worth the maintenance cost.

### D-08: Capture operator/admin states only

Recommended screenshot matrix:

- cockpit home
- inbox/list triage
- conversation workspace
- AI draft approval state
- pending governed action
- executed governed action
- resolved/outbound recovery state
- bulk recovery modal or refusal state if seeded
- knowledge index
- knowledge gaps
- knowledge review/suggestions states
- article editor with draft article
- audit log
- settings with masked MCP tokens

Capture each required state in light and dark themes. Exclude demo index, marketing, and customer chat from Phase 45 acceptance unless the planner finds a direct Phase 45 requirement that says otherwise.

### D-09: Force both Playwright color scheme and app theme state

For dark screenshots, set browser `colorScheme: "dark"` and also force the application theme mechanism, likely `document.documentElement.dataset.theme = "dark"` plus any relevant localStorage value. `colorScheme` alone is not enough if Cairnloop uses a `data-theme` toggle.

For light screenshots, explicitly set the light theme rather than relying on host/system defaults.

### D-10: Keep static captures motion-stabilized

Static screenshot capture should continue to inject reduced/stabilized motion styles and wait for stable end states. Live animation behavior belongs in E2E tests such as `examples/cairnloop_example/test/e2e/motion_test.exs`.

Acceptance for screenshots is visual state clarity, brand fidelity, readable hierarchy, dark/light correctness, and absence of layout overlap. It is not animation timing.

### D-11: Add a compact visual acceptance ledger

Produce a Phase 45 visual acceptance artifact, for example `45-VISUAL-ACCEPTANCE.md`, with one row per captured screen and theme. Include screenshot path, pass/fail, notes, and the relevant checks:

- final brand tokens and logo usage are respected
- light and dark themes are both intentional
- state is visible without relying only on color
- hierarchy and density fit the operator cockpit
- microcopy is calm, reason-forward, and user-facing
- focus/tap affordances remain conventional where visible
- no backend implementation detail leaks into user-facing labels
- no off-brand gradients, old palettes, or stale logo assets appear

This ledger should be concise enough to review during milestone closeout.

## Verification and Release Gates

### D-12: Use tiered verification while working, then run the full sweep before green

Inner-loop tests can be focused while editing. Before claiming Phase 45 complete, run the full local sweep:

- root `mix test`
- root `PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration`
- root `mix check`
- example app `PGPORT=5432 MIX_ENV=test mix test.e2e`
- screenshot regeneration
- milestone audit/release gate review

Keep `PGPORT=5432` explicit because prior phases established it as necessary for this environment.

### D-13: Do not weaken the release gate

`.github/workflows/ci.yml` and the existing release gate remain canonical. Phase 45 should not loosen CI, skip meaningful checks, or move screenshot evidence into a fake pass condition.

Run a full local mirror only before the final green claim. Do not require every small seed edit to run every expensive lane.

### D-14: Browser-visible behavior is gated by E2E, not human UAT

Follow the established "automate the world / 0 human UAT" decision. Browser-visible behavior, theme switching, geometry, navigation, focus, and motion should be covered by E2E/integration tests. Screenshots are evidence and docs output, not a substitute for automated behavioral checks.

### D-15: Use traces and screenshots as debugging evidence

Keep Playwright traces/screenshots available for E2E failure debugging, especially in CI. They are diagnostic artifacts, not product acceptance assets.

## Planner Discretion

The planner may decide:

- exact wave/slice decomposition
- exact screenshot file layout, as long as light/dark are explicit and easy to review
- exact fixture copy, human reasons, and timestamps
- whether to extract seed helper modules if `seeds.exs` becomes hard to maintain
- exact name/location for the visual acceptance ledger

Do not reopen the larger architecture choices unless implementation proves one of these recommendations impossible.
</decisions>

<canonical_refs>
## Phase and Milestone Sources

- `.planning/ROADMAP.md` - Phase 45 goal and success criteria
- `.planning/REQUIREMENTS.md` - SEED-01, VERIFY-01, VERIFY-02
- `.planning/PROJECT.md` - project scope, current milestone, invariants
- `.planning/STATE.md` - carried decisions and verification policy
- `.planning/vM016-UI-ITERATION-BRIEF.md` - verification loop, critical files, screenshot policy
- `.planning/vM016-MILESTONE-AUDIT.md` - deferred visual proof absorbed by Phase 45

## Prior Phase Context

- `.planning/phases/44-motion/44-CONTEXT.md`
- `.planning/phases/43-responsive-desktop-first-cockpit-d3/43-CONTEXT.md`
- `.planning/phases/42-cross-screen-threading/42-CONTEXT.md`

## Final Brand Inputs

- `priv/static/cairnloop.css` - canonical runtime tokens
- `brandbook/TOKENS.md`
- `brandbook/index.html`
- `brandbook/color/swatches.json`
- `logo/USAGE.md`
- `logo/cairnloop-lockup-horizontal.svg`
- `logo/cairnloop-mark.svg`
- `logo/favicon.svg`
- `examples/cairnloop_example/priv/static/images/logo.svg`
- `examples/cairnloop_example/priv/static/images/favicon.svg`
- `examples/cairnloop_example/priv/static/images/cairnloop-og.png`

## Seed, State, and Governance Code

- `examples/cairnloop_example/priv/repo/seeds.exs`
- `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs`
- `lib/cairnloop/knowledge_base.ex`
- `lib/cairnloop/knowledge_base/article.ex`
- `lib/cairnloop/knowledge_base/revision.ex`
- `lib/cairnloop/knowledge_automation.ex`
- `lib/cairnloop/knowledge_automation/review_task.ex`
- `lib/cairnloop/mcp.ex`
- `lib/cairnloop/mcp/token.ex`
- `lib/cairnloop/web/settings_live.ex`
- `lib/cairnloop/tools/internal_note.ex`
- `lib/cairnloop/tool.ex`
- `lib/cairnloop/tool/spec.ex`
- `examples/cairnloop_example/config/config.exs`

## Screenshots, E2E, and Verification

- `examples/cairnloop_example/screenshots/capture.mjs`
- `examples/cairnloop_example/screenshots/README.md`
- `examples/cairnloop_example/test/e2e/motion_test.exs`
- `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`
- `examples/cairnloop_example/test/e2e/thread_navigation_test.exs`
- `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs`
- `examples/cairnloop_example/test/e2e/collateral_wiring_test.exs`
- `test/integration/golden_path_test.exs`
- `test/cairnloop/web/brand_token_gate_test.exs`
- `mix.exs`
- `examples/cairnloop_example/mix.exs`
- `.github/workflows/ci.yml`

## Prompt and Research Inputs

- `prompts/elixir-lib-customer-support-automation-deep-research.md`
- `prompts/scoria overview for integration ideas.txt`
- `prompts/parapet overview for integration ideas.txt`
- `prompts/cairnloop_brand_book.md` - older creative direction, superseded by current brandbook/token docs where visual details conflict
- `prompts/cairnloop.css` - pointer only; canonical CSS source moved to `priv/static/cairnloop.css`

## External Sources Consulted

- Playwright visual comparisons: https://playwright.dev/docs/test-snapshots
- Playwright emulation and color scheme: https://playwright.dev/docs/emulation
- Playwright trace viewer: https://playwright.dev/docs/trace-viewer
- Phoenix Ecto SQL Sandbox: https://phoenix-ecto.hexdocs.pm/Phoenix.Ecto.SQL.Sandbox.html
- Phoenix LiveViewTest: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveViewTest.html
- Phoenix seeding guide: https://phoenix.hexdocs.pm/1.3.0-rc.2/seeding_data.html
- Storybook visual tests: https://storybook.js.org/docs/writing-tests/visual-testing
</canonical_refs>

<code_context>
## Existing Assets to Reuse

- `examples/cairnloop_example/priv/repo/seeds.exs` already has idempotent helper patterns such as stable lookup/insert behavior and facade-backed setup.
- `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` is the right home for seed idempotency and coverage assertions.
- `Cairnloop.MCP.issue_token/1` hashes and stores MCP tokens while returning the raw token once.
- `Cairnloop.Web.SettingsLive` loads token rows and displays masked token handles.
- `Cairnloop.KnowledgeAutomation.ReviewTask` already has the review statuses Phase 45 needs.
- `Cairnloop.KnowledgeBase` has draft and publish flows that should be preferred over hand-written state.
- `Cairnloop.Tools.InternalNote` is the reference governed tool implementation.
- `examples/cairnloop_example/screenshots/capture.mjs` already starts the app, captures pages, injects screenshot stabilization CSS, and writes docs images.
- Existing E2E tests cover motion, geometry, navigation, rail disclosure, and collateral wiring.
- `test/cairnloop/web/brand_token_gate_test.exs` protects against token drift.

## Established Patterns

- Seeds are deterministic, idempotent, and human-readable.
- Behaviorful state transitions should use context functions/facades.
- Direct inserts/updates are seed-only escape hatches for passive presentation gaps.
- UI scope is operator/admin unless a requirement explicitly says otherwise.
- Runtime CSS uses BEM plus `.cl-` utilities and canonical tokens; no Tailwind/build-step dependency is introduced for the library.
- Screenshots are non-gating visual acceptance evidence.
- Browser-visible behavior is verified through E2E and integration tests.
- The release gate remains authoritative.

## Integration Points for Phase 45

- Extend seed helpers and seed tests together.
- Extend screenshot capture to light/dark loops and operator/admin state pages.
- Add or generate a visual acceptance ledger tied to screenshot paths.
- Run focused seed/screenshot tests during implementation, then the full verification sweep before completion.
</code_context>

<specifics>
## User Direction

The user explicitly selected all ambiguous discussion areas and asked for subagent-backed research, pros/cons/tradeoffs, idiomatic Elixir/Phoenix/Ecto guidance, lessons from comparable ecosystems, developer ergonomics, user ergonomics, UI/UX where applicable, SRE/DevOps verification considerations, and a cohesive recommendation set that minimizes further decision burden.

The resulting recommendation is intentionally opinionated: facade-first deterministic seeds, dual-theme operator screenshots, a concise visual acceptance ledger, E2E behavior gates, and no pixel-gate/vendor expansion in this phase.

## Subagent Research Outcomes

Seed/data researcher:

- recommended incremental idempotent builders in `seeds.exs`
- warned against a new fixture/generator layer for this phase
- recommended ReviewTask-backed KB states
- recommended seeding MCP tokens through `MCP.issue_token/1`
- recommended tests for statuses, token masking/counts, higher-risk action visibility, and double-run stability

Visual proof researcher:

- recommended a dual-theme Playwright evidence pack
- recommended around 15 operator/admin screenshots across light and dark themes
- warned against CI pixel gates and vendor visual review for Phase 45
- recommended excluding demo index/chat from Phase 45 acceptance
- recommended a written ledger for final visual acceptance

Verification/SRE researcher:

- recommended tiered local lanes plus canonical CI/release gate
- recommended full local sweep before any green claim
- warned not to weaken `release_gate`
- recommended traces/screenshots for debugging failures rather than product acceptance

## UX and Design Lenses Applied

For operator/admin screens, acceptance should consider:

- accessibility and contrast in both themes
- information hierarchy under cockpit density
- calm, specific, reason-forward microcopy
- state not communicated by color alone
- predictable controls and conventional affordances
- no hover/focus weirdness
- dark/light/system behavior that follows user expectations
- performance and screenshot stability
- final brandbook token/logo fidelity
- no exposure of backend architecture or internal table names

For developer experience, the plan should optimize for:

- normal Phoenix/Ecto workflows
- obvious seed reruns
- small, discoverable helpers
- deterministic fixtures
- tests that explain the intended fixture contract
- no new visual infrastructure unless ownership is real

## External Research Lessons

- Playwright supports screenshot assertions and stabilization options, but its docs call out rendering differences across OS, hardware, power source, headless mode, and other factors. This supports using screenshots as evidence now and deferring CI pixel gates until the environment and approval workflow are owned.
- Playwright emulation supports `colorScheme`; Cairnloop still needs app-level theme forcing because its UI uses a theme toggle/data attribute.
- Playwright traces are useful for CI failure debugging and should remain diagnostic artifacts.
- Phoenix convention keeps seed data in `priv/repo/seeds.exs`; modular extraction is available, but not necessary unless the file becomes hard to maintain.
- Phoenix Ecto SQL Sandbox and LiveViewTest reinforce that deterministic automated tests should gate behavior instead of manual browser checks.
- Storybook/Chromatic-style visual review works well for component libraries with owned baseline workflows, but that is outside the current Phase 45 scope.
</specifics>

<deferred>
- CI pixel/snapshot baseline gate
- Percy/Chromatic/Storybook visual review infrastructure
- generated or randomized demo data volume
- extracted seed module unless `seeds.exs` becomes genuinely hard to maintain
- third "system theme" screenshot set
- route-line/marker-travel motion and other AMOTION v2 items already deferred from Phase 44
- additional product capabilities beyond evidence/state coverage
</deferred>
