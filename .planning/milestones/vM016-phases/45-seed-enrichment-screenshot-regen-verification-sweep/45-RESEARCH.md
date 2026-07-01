# Phase 45: Seed Enrichment + Screenshot Regen + Verification Sweep - Research

**Researched:** 2026-06-26
**Domain:** Phoenix/Ecto seed enrichment, governed-action evidence, Playwright screenshot regeneration, ExUnit/PhoenixTest verification sweep
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

The following locked decisions, discretion areas, and deferred ideas are copied from `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-CONTEXT.md`. [VERIFIED: 45-CONTEXT.md]

### Locked Decisions

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

### the agent's Discretion

## Planner Discretion

The planner may decide:

- exact wave/slice decomposition
- exact screenshot file layout, as long as light/dark are explicit and easy to review
- exact fixture copy, human reasons, and timestamps
- whether to extract seed helper modules if `seeds.exs` becomes hard to maintain
- exact name/location for the visual acceptance ledger

Do not reopen the larger architecture choices unless implementation proves one of these recommendations impossible.

### Deferred Ideas (OUT OF SCOPE)

- CI pixel/snapshot baseline gate
- Percy/Chromatic/Storybook visual review infrastructure
- generated or randomized demo data volume
- extracted seed module unless `seeds.exs` becomes genuinely hard to maintain
- third "system theme" screenshot set
- route-line/marker-travel motion and other AMOTION v2 items already deferred from Phase 44
- additional product capabilities beyond evidence/state coverage
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEED-01 | Demo seed data must exercise the operator UI across meaningful states, including governed actions, knowledge suggestions, drafts, tokens, and dense/boundary data. | Use the existing deterministic `seeds.exs` entry point, extend seed tests, create state through `KnowledgeAutomation`, `KnowledgeBase`, `Governance`, and `MCP` facades, and keep direct DB writes limited to passive display fields. [VERIFIED: REQUIREMENTS.md] [VERIFIED: codebase grep] |
| VERIFY-01 | Screenshot proof must be regenerated for touched operator/admin screens using the final brand in light and dark modes. | Extend `examples/cairnloop_example/screenshots/capture.mjs` to loop explicit themes, force both Playwright `colorScheme` and Cairnloop `data-theme` state, and create a compact visual acceptance ledger. [VERIFIED: REQUIREMENTS.md] [CITED: https://playwright.dev/docs/emulation] |
| VERIFY-02 | Full milestone verification must be green before completion is claimed. | Run the locked full sweep from CONTEXT.md: root `mix test`, integration, `mix check`, example E2E, screenshot regeneration, and release-gate/milestone audit review. [VERIFIED: REQUIREMENTS.md] [VERIFIED: 45-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 45 should be planned as a closing evidence phase, not as a feature expansion phase. The seed work should enrich the existing example app through deterministic, facade-first builders in `examples/cairnloop_example/priv/repo/seeds.exs`; the visible proof should come from dual-theme operator/admin screenshots plus a concise ledger; and behavioral confidence should come from existing ExUnit, integration, E2E, quality, and brand-token gates. [VERIFIED: 45-CONTEXT.md] [VERIFIED: codebase grep]

The riskiest planning errors are bypassing behaviorful transitions with direct inserts, representing KB review states on `ArticleSuggestion` instead of `ReviewTask`, exposing raw MCP token material, treating Playwright screenshots as a CI pixel gate, and claiming completion before the full verification sweep runs. [VERIFIED: codebase grep] [CITED: https://playwright.dev/docs/test-snapshots]

**Primary recommendation:** Implement Phase 45 in three tight slices: seed enrichment plus seed contract tests, screenshot/theme capture plus visual ledger, then the complete verification sweep with failure evidence captured but no new visual infrastructure. [VERIFIED: 45-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Deterministic demo seed enrichment | Database / Storage | API / Backend | Seed data is persisted Ecto state, but behaviorful state must be produced through public contexts/facades rather than raw schema inserts. [VERIFIED: codebase grep] |
| Knowledge review states | API / Backend | Database / Storage | `Cairnloop.KnowledgeAutomation.ReviewTask` owns visible rejected, deferred, approved-ready, and published review states. [VERIFIED: codebase grep] |
| Governed-action audit states | API / Backend | Database / Storage | `Cairnloop.Governance` owns proposal, approval, reject, defer, execute, and event emission behavior. [VERIFIED: codebase grep] |
| MCP token proof | API / Backend | Database / Storage | `Cairnloop.MCP.issue_token/1` owns token hashing and raw-token return behavior; Settings UI reads stored token rows and displays masked handles. [VERIFIED: codebase grep] |
| Light/dark screenshot evidence | Browser / Client | Frontend Server (LiveView) | Playwright controls browser color-scheme emulation while the LiveView app theme is selected through document/theme state. [CITED: https://playwright.dev/docs/emulation] [VERIFIED: codebase grep] |
| Verification sweep | Test / CI Tooling | Browser / Client | ExUnit, integration aliases, PhoenixTest Playwright E2E, screenshot capture, and release-gate parity are the completion evidence. [VERIFIED: mix.exs] [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: .github/workflows/ci.yml] |

## Project Constraints (from CLAUDE.md)

- Make implementation decisions without stopping for owner input unless the decision is unusually impactful or high-risk. [VERIFIED: CLAUDE.md]
- Warnings-clean builds are mandatory; `mix compile --warnings-as-errors` is a completion expectation. [VERIFIED: CLAUDE.md]
- Run `mix test` before claiming done. [VERIFIED: CLAUDE.md]
- The local workspace may not have `Cairnloop.Repo` available for all contexts, so DB tests should be explicit about Postgres requirements and pure tests remain preferred where possible. [VERIFIED: CLAUDE.md]
- Durable Ecto records and events are workflow truth; telemetry is observability and must not become required state. [VERIFIED: CLAUDE.md]
- New governance reads should go through a narrow `Cairnloop.Governance` facade rather than ad hoc schema access. [VERIFIED: CLAUDE.md]
- Trust facts must be snapshotted at decision time; completed render paths must not re-read live configuration for prior decisions. [VERIFIED: CLAUDE.md]
- Completed phases are sealed; follow-up work should be additive and routed through a new phase. [VERIFIED: CLAUDE.md]
- Operator copy must be calm, fail-closed, reason-forward, honest, and user-facing; raw Elixir terms or JSON belong behind explicit expanders only. [VERIFIED: CLAUDE.md]
- UI state must not be communicated by color alone. [VERIFIED: CLAUDE.md]
- Use brand tokens rather than hardcoded colors where practical. [VERIFIED: CLAUDE.md]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | Elixir 1.19.5, Mix 1.19.5 locally | Run the root library and example-app test/build workflow. | The current environment reports these versions, and project aliases are Mix-based. [VERIFIED: local command] [VERIFIED: mix.exs] |
| Phoenix / Phoenix LiveView | Phoenix 1.8.7 in lockfiles; LiveView 1.1.30 root and 1.1.31 example app | Render the embedded operator/admin dashboard and example app routes. | The repo already uses Phoenix LiveView screens for operator/admin state, and Phase 45 should not add another UI stack. [VERIFIED: mix.lock] [VERIFIED: examples/cairnloop_example/mix.lock] |
| Ecto SQL / PostgreSQL | Ecto SQL 3.13.5 root; PostgreSQL 14.17 client available; local Postgres accepts port 5432 | Persist deterministic seed state and run integration/E2E tests. | Existing tests, CI services, and phase decisions depend on Postgres-backed Ecto data. [VERIFIED: mix.lock] [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml] |
| Oban | 2.22.1 root; 2.23.0 example lockfile | Drain background jobs created by KB revision chunking and governed actions. | `seeds.exs` already drains Oban default queue recursively after creating article revisions. [VERIFIED: mix.lock] [VERIFIED: examples/cairnloop_example/mix.lock] [VERIFIED: codebase grep] |
| PhoenixTest Playwright | 0.14.0 example lockfile | Browser-backed E2E tests for visible UI behavior. | The example app already uses `PhoenixTest.Playwright.Case` with `@moduletag :e2e`. [VERIFIED: examples/cairnloop_example/mix.lock] [CITED: https://hexdocs.pm/phoenix_test_playwright/] |
| `playwright` [WARNING: flagged as suspicious — verify before using.] | 1.60.0 in example screenshot/assets lockfiles; latest registry metadata was published recently | Regenerate screenshot evidence and run browser automation assets. | The existing lockfiles already resolve Playwright 1.60.0, and official Playwright docs define color emulation and screenshot APIs. [VERIFIED: package-lock.json] [CITED: https://playwright.dev/docs/screenshots] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Node.js / npm | Node v22.14.0, npm 11.1.0 locally | Run Playwright screenshot scripts and install locked JS dependencies. | Use for `examples/cairnloop_example/screenshots` and `assets` package workflows. [VERIFIED: local command] |
| pgvector-backed Postgres service | CI uses a pgvector Postgres service; local Postgres is reachable on 5432 | Support integration/E2E database setup. | Keep `PGPORT=5432` explicit in commands because the phase context requires it. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: 45-CONTEXT.md] |
| Brand token gate | Existing ExUnit test path `test/cairnloop/web/brand_token_gate_test.exs` | Protect final vM017 token usage. | Include in focused verification when visual/token changes are touched, and rely on `mix check` before completion. [VERIFIED: codebase grep] |
| Screenshot capture script | `examples/cairnloop_example/screenshots/capture.mjs` | Generate docs/evidence screenshots into `guides/assets`. | Extend this script rather than adding a new visual toolchain. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `seeds.exs` helpers | New fixture DSL or generator layer | Rejected for Phase 45 because context locks deterministic incremental builders in the existing script. [VERIFIED: 45-CONTEXT.md] |
| Playwright evidence screenshots | Percy, Chromatic, Storybook, or CI visual snapshots | Rejected for Phase 45 because screenshots are milestone evidence and behavior is test-gated. [VERIFIED: 45-CONTEXT.md] |
| `ReviewTask` statuses | New `ArticleSuggestion` statuses | Rejected because ReviewTask owns the visible KB review queue states and `ArticleSuggestion` has its own narrower status set. [VERIFIED: codebase grep] |
| Facade transitions | Direct schema inserts for proposals, approvals, review tasks, tokens, or revisions | Rejected because direct writes bypass audit events, hashing, queued jobs, and state-machine invariants. [VERIFIED: codebase grep] |

**Installation:**

No new packages should be installed for Phase 45. If JavaScript dependencies are missing locally, use the existing lockfile directories instead of upgrading:

```bash
cd examples/cairnloop_example/screenshots && npm install
cd ../assets && npm install
```

Use `npm ci` only if the current package-lock and package.json relationship allows it cleanly in the target directory; do not run `npm install playwright@latest`. [VERIFIED: package-lock.json] [VERIFIED: 45-CONTEXT.md]

**Version verification:**

| Package | Command Used | Verified Version / Date |
|---------|--------------|-------------------------|
| `playwright` | `npm view playwright@1.60.0 version time repository.url scripts.postinstall --json` | 1.60.0, published 2026-05-11, Microsoft GitHub repo, no postinstall script reported. [VERIFIED: npm registry] |
| `phoenix_test_playwright` | `mix hex.info phoenix_test_playwright`; lockfile check | 0.14.0 locked in example app; latest Hex info showed newer releases exist, so do not upgrade during this phase. [VERIFIED: Hex registry] [VERIFIED: examples/cairnloop_example/mix.lock] |
| `oban` | `mix hex.info oban`; lockfile check | 2.22.1 root, 2.23.0 example app. [VERIFIED: Hex registry] [VERIFIED: mix.lock] |
| `phoenix_ecto` | `mix hex.info phoenix_ecto`; lockfile check | 4.7.0 in example app. [VERIFIED: Hex registry] [VERIFIED: examples/cairnloop_example/mix.lock] |

## Package Legitimacy Audit

This phase should not introduce new external packages. The only package that may be touched operationally is the already-locked Playwright dependency used by the existing screenshot and E2E workflows. [VERIFIED: 45-CONTEXT.md] [VERIFIED: package-lock.json]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `playwright` [WARNING: flagged as suspicious — verify before using.] | npm | Created 2015-01-23; locked 1.60.0 published 2026-05-11 | 62,633,817 weekly downloads in legitimacy output | `github.com/microsoft/playwright` | SUS because the latest registry version was very recently published; no postinstall script reported | Approved only as the existing locked 1.60.0 dependency; planner must add a human checkpoint before changing or upgrading this package. [VERIFIED: npm registry] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: package-legitimacy seam]
**Packages flagged as suspicious [SUS]:** `playwright` latest-line metadata; keep the locked dependency and do not upgrade during Phase 45. [VERIFIED: package-legitimacy seam]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 45 input
  |
  v
Existing example seed script
  |
  +--> KnowledgeBase facade -> Article + draft/published revisions -> Oban chunk jobs
  |
  +--> KnowledgeAutomation facade -> ArticleSuggestion -> ReviewTask state/events
  |
  +--> Governance facade -> ToolProposal -> ToolApproval -> ToolActionEvent audit trail
  |
  +--> MCP facade -> Token hash row -> Settings masked token display
  |
  v
Oban.drain_queue(:default, with_recursion: true)
  |
  v
Operator/Admin LiveViews at /support
  |
  +--> Browser behavior checks through PhoenixTest Playwright E2E
  |
  +--> Screenshot capture script
         |
         +--> light context: colorScheme + data-theme/localStorage
         |
         +--> dark context: colorScheme + data-theme/localStorage
         |
         v
       guides/assets screenshots + Phase 45 visual acceptance ledger
  |
  v
Full verification sweep: mix test -> integration -> mix check -> E2E -> screenshots -> release gate review
```

This data flow matches the existing facade boundaries and screenshot workflow. [VERIFIED: codebase grep]

### Recommended Project Structure

```text
examples/cairnloop_example/
├── priv/repo/seeds.exs                         # Existing deterministic seed entry point
├── test/cairnloop_example/seeds_test.exs       # Seed idempotency and coverage contract
├── lib/cairnloop_example/tools/                # Example-app-only high-risk demo tool if needed
├── config/config.exs                           # Example-app tool registration
├── screenshots/capture.mjs                     # Dual-theme screenshot capture
├── screenshots/README.md                       # Updated capture instructions
└── test/e2e/                                   # Browser-visible behavior checks if added

guides/assets/                                  # Regenerated screenshot output
.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/
└── 45-VISUAL-ACCEPTANCE.md                     # Compact screenshot acceptance ledger
```

These paths are the current integration points or the locked Phase 45 evidence location. [VERIFIED: codebase grep] [VERIFIED: 45-CONTEXT.md]

### Pattern 1: Facade-First Idempotent Seed Builders

**What:** Add small helpers to `seeds.exs` that check stable natural keys, create state through public contexts, then optionally adjust passive presentation fields such as timestamps. [VERIFIED: codebase grep]
**When to use:** Use for review tasks, governance approvals, KB revisions, MCP tokens, and any screenshot-visible state that represents real product behavior. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: existing seeds.exs idempotency pattern + MCP facade contract.
defp ensure_demo_mcp_token(name) do
  case Repo.get_by(Cairnloop.MCP.Token, name: name) do
    nil ->
      {:ok, _token, _raw_token} = Cairnloop.MCP.issue_token(%{name: name})
      :ok

    _token ->
      :ok
  end
end
```

Discarding `_raw_token` is required because `issue_token/1` returns the secret once and Settings should only display masked stored data. [VERIFIED: codebase grep]

### Pattern 2: ReviewTask-Driven Knowledge States

**What:** Seed rejected, deferred, approved-ready, and published KB review states by creating `ArticleSuggestion` rows only as inputs and driving visible queue state through `ReviewTask` functions. [VERIFIED: codebase grep]
**When to use:** Use whenever the UI proof is the Knowledge suggestions/review queue. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: KnowledgeAutomation public functions and ReviewTask status model.
{:ok, review_task} =
  Cairnloop.KnowledgeAutomation.ensure_review_task_for_suggestion(
    suggestion.id,
    actor_id: "demo_operator"
  )

{:ok, _review_task} =
  Cairnloop.KnowledgeAutomation.defer_review_task(
    review_task.id,
    reason: :needs_manual_edit,
    actor_id: "demo_operator",
    note: "Seeded for demo review: source evidence needs a policy owner."
  )
```

Do not add rejected/deferred/published states to `ArticleSuggestion`; that schema has its own status set. [VERIFIED: codebase grep]

### Pattern 3: Governed High-Risk Example Tool

**What:** Add a demo-only tool under the example app, register it only in example config, and choose `risk_tier: :high_write` unless a destructive no-op boundary is explicitly required. [VERIFIED: 45-CONTEXT.md] [VERIFIED: codebase grep]
**When to use:** Use when `InternalNote` low-write coverage is insufficient to show higher-risk governed action behavior. [VERIFIED: 45-CONTEXT.md]

**Example:**

```elixir
# Source: Cairnloop.Tool behavior and InternalNote reference implementation.
defmodule CairnloopExample.Tools.HighRiskDemoAction do
  use Ecto.Schema
  use Cairnloop.Tool, risk_tier: :high_write

  embedded_schema do
    field :conversation_id, :integer
    field :reason, :string
  end

  def changeset(attrs), do: Ecto.Changeset.cast(%__MODULE__{}, attrs, [:conversation_id, :reason])
  def scope, do: nil
  def authorize(_actor, _params), do: :ok
  def run(_repo, _params, _context), do: {:ok, %{demo: true}}
end
```

Keep the tool example-app-only so Phase 45 does not widen the library API. [VERIFIED: 45-CONTEXT.md]

### Pattern 4: Dual-Theme Screenshot Loop

**What:** Reuse `capture.mjs`, but iterate over explicit light and dark themes, set Playwright `colorScheme`, and set app theme state through `data-theme` and `localStorage`. [VERIFIED: codebase grep] [CITED: https://playwright.dev/docs/emulation]
**When to use:** Use for every operator/admin screenshot in the Phase 45 matrix. [VERIFIED: 45-CONTEXT.md]

**Example:**

```javascript
// Source: Playwright emulation docs and existing capture.mjs structure.
const themes = [
  { name: "light", colorScheme: "light" },
  { name: "dark", colorScheme: "dark" }
];

for (const theme of themes) {
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: DEVICE_SCALE,
    reducedMotion: "reduce",
    colorScheme: theme.colorScheme
  });

  await context.addInitScript(({ themeName, css }) => {
    localStorage.setItem("phx:theme", themeName);
    document.documentElement.dataset.theme = themeName;

    const style = document.createElement("style");
    style.textContent = css;
    document.documentElement.appendChild(style);
  }, { themeName: theme.name, css: STABILIZE_CSS });
}
```

Playwright `colorScheme` only emulates the browser preference; Cairnloop's actual theme selection also uses application state. [CITED: https://playwright.dev/docs/emulation] [VERIFIED: codebase grep]

### Pattern 5: Automated Browser Evidence, Not Manual UAT

**What:** Put browser-visible behavior into PhoenixTest Playwright E2E tests and keep screenshot captures as reviewed evidence. [VERIFIED: STATE.md] [CITED: https://hexdocs.pm/phoenix_test_playwright/]
**When to use:** Use for theme switching, geometry, navigation, motion, focus, or other behavior that would otherwise be verified by a human. [VERIFIED: STATE.md]

### Anti-Patterns to Avoid

- **Direct behaviorful DB writes:** They can bypass events, approvals, token hashing, or Oban job creation; use public contexts and reserve direct updates for passive seed presentation. [VERIFIED: codebase grep]
- **ArticleSuggestion status inflation:** The visible KB queue state belongs on `ReviewTask`, not on invented suggestion statuses. [VERIFIED: codebase grep]
- **Raw MCP token evidence:** Raw token strings are returned once by the facade and must be discarded; screenshots/tests should verify masked UI only. [VERIFIED: codebase grep]
- **ColorScheme-only dark captures:** Playwright emulation does not necessarily set Cairnloop's `data-theme` state. [CITED: https://playwright.dev/docs/emulation] [VERIFIED: codebase grep]
- **CI pixel gates:** Phase 45 explicitly rejects pixel/snapshot gating and vendor visual tooling. [VERIFIED: 45-CONTEXT.md]
- **Dependency upgrades during evidence work:** The phase should use existing lockfiles; upgrading Playwright or Hex dependencies expands scope and risk. [VERIFIED: package-lock.json] [VERIFIED: 45-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MCP token hashing and masking | Manual token hash rows or fake token strings | `Cairnloop.MCP.issue_token/1` plus Settings UI masked display | The facade owns raw-token return and stored hash behavior. [VERIFIED: codebase grep] |
| KB review workflow | Custom status edits on `ArticleSuggestion` | `Cairnloop.KnowledgeAutomation` ReviewTask functions | ReviewTask owns queue status, reasons, and event history. [VERIFIED: codebase grep] |
| Governed-action approval trail | Manual ToolApproval/ToolActionEvent inserts | `Cairnloop.Governance.propose`, `request_approval`, `reject`, `defer`, `approve` | The facade enforces approval mode, reasons, and event emission. [VERIFIED: codebase grep] |
| Background job completion | Hand-updating chunk/job side effects | `Oban.drain_queue(queue: :default, with_recursion: true)` | Oban provides a test/drain path that runs jobs through their real worker code. [CITED: https://hexdocs.pm/oban/Oban.html] [VERIFIED: codebase grep] |
| Browser behavior checks | Human UAT notes | PhoenixTest Playwright E2E | The project state locks "automate the world / 0 human UAT". [VERIFIED: STATE.md] |
| Visual evidence tooling | New Percy/Chromatic/Storybook/pixel gate | Existing Playwright screenshot script plus ledger | Phase 45 locks evidence screenshots and rejects vendor visual infrastructure. [VERIFIED: 45-CONTEXT.md] |
| Brand-token verification | Manual color inspection only | Existing brand token docs/tests plus visual ledger | Runtime CSS and brand docs are final vM017 sources of truth. [VERIFIED: brandbook/TOKENS.md] [VERIFIED: codebase grep] |

**Key insight:** The phase is proof-oriented, so planners should prefer existing system surfaces that already encode invariants over new helper layers that create plausible-looking but behaviorally inaccurate data. [VERIFIED: 45-CONTEXT.md] [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: ReviewTask and ArticleSuggestion State Mismatch

**What goes wrong:** A plan adds rejected/deferred/published states to `ArticleSuggestion` and the Knowledge Review UI never shows the intended queue states. [VERIFIED: codebase grep]
**Why it happens:** `ArticleSuggestion` is the suggestion input, while `ReviewTask` is the operator review workflow surface. [VERIFIED: codebase grep]
**How to avoid:** Create suggestions, ensure review tasks, then use ReviewTask transition functions. [VERIFIED: codebase grep]
**Warning signs:** Tests assert `ArticleSuggestion.status` for rejected/deferred/published, or UI screenshots do not show queue filters with those states. [VERIFIED: codebase grep]

### Pitfall 2: Seed Data Exists But Is Invisible

**What goes wrong:** Seed records are created but `/support` screens do not show them. [VERIFIED: codebase grep]
**Why it happens:** Example dashboard sessions and queries are scoped to the host/operator context, including values such as `demo_operator`. [VERIFIED: codebase grep]
**How to avoid:** Seed with the same operator/tenant scope used by existing fixtures and LiveView sessions. [VERIFIED: codebase grep]
**Warning signs:** DB assertions pass, but screenshot pages are sparse or empty. [VERIFIED: codebase grep]

### Pitfall 3: Raw MCP Token Leakage

**What goes wrong:** A seed log, test assertion, screenshot, or ledger captures the raw token returned by `issue_token/1`. [VERIFIED: codebase grep]
**Why it happens:** The facade returns raw token material once so humans can copy it during creation. [VERIFIED: codebase grep]
**How to avoid:** Bind the raw value to `_raw_token` and never inspect or print it; assert masked `cl_mcp_***` UI handles instead. [VERIFIED: codebase grep]
**Warning signs:** `seeds.exs`, tests, or artifacts contain strings shaped like full API tokens. [VERIFIED: codebase grep]

### Pitfall 4: Dark Screenshots Are Not Actually Dark

**What goes wrong:** Playwright captures a browser with dark media preference but the Cairnloop app still renders light because app theme state was not set. [CITED: https://playwright.dev/docs/emulation] [VERIFIED: codebase grep]
**Why it happens:** Playwright `colorScheme` and the app's `data-theme`/localStorage mechanism are separate controls. [CITED: https://playwright.dev/docs/emulation] [VERIFIED: codebase grep]
**How to avoid:** Set both `colorScheme` and app theme before page navigation or hydration. [VERIFIED: codebase grep]
**Warning signs:** Dark screenshot filenames contain light backgrounds or theme toggle state disagrees with output. [VERIFIED: codebase grep]

### Pitfall 5: Screenshot Paths Depend On Fragile Numeric IDs

**What goes wrong:** Seed enrichment changes insert order and existing screenshot routes like `/support/17` point at the wrong conversation. [VERIFIED: codebase grep]
**Why it happens:** The current capture script includes numeric route IDs, while seed edits can alter deterministic IDs after reset. [VERIFIED: codebase grep]
**How to avoid:** Prefer stable seeded subjects/slugs where the app supports them; otherwise keep insert order deterministic and update screenshots/tests together. [VERIFIED: codebase grep]
**Warning signs:** A screenshot title or body does not match the intended matrix row. [VERIFIED: codebase grep]

### Pitfall 6: Full Sweep Runs With The Wrong Postgres Port

**What goes wrong:** Integration or E2E commands fail locally even though Postgres is running. [VERIFIED: 45-CONTEXT.md]
**Why it happens:** Prior phases established `PGPORT=5432` as necessary in this environment. [VERIFIED: 45-CONTEXT.md]
**How to avoid:** Keep the context's exact command prefixes for integration and E2E. [VERIFIED: 45-CONTEXT.md]
**Warning signs:** Connection refused or database setup errors from integration/E2E lanes. [VERIFIED: local command]

## Code Examples

Verified patterns from official sources and current code:

### Oban Drain After Seeded Revisions

```elixir
# Source: Oban docs and existing seeds.exs.
Oban.drain_queue(queue: :default, with_recursion: true)
```

`with_recursion: true` is appropriate when seeded jobs can enqueue follow-up jobs that must complete before screenshots/tests inspect derived state. [CITED: https://hexdocs.pm/oban/Oban.html] [VERIFIED: codebase grep]

### PhoenixTest Playwright Browser Fact

```elixir
# Source: existing example E2E tests and PhoenixTest Playwright docs.
defmodule CairnloopExampleWeb.ThemeEvidenceTest do
  use PhoenixTest.Playwright.Case, async: false

  @moduletag :e2e

  test "operator shell can render in dark theme", %{conn: conn} do
    conn
    |> visit("/support")
    |> evaluate("""
      () => {
        localStorage.setItem("phx:theme", "dark");
        document.documentElement.dataset.theme = "dark";
        return document.documentElement.dataset.theme;
      }
    """)
  end
end
```

Use E2E for browser-visible behavior; screenshots remain evidence assets. [VERIFIED: STATE.md] [CITED: https://hexdocs.pm/phoenix_test_playwright/]

### Playwright Full-Page Screenshot

```javascript
// Source: Playwright screenshots docs.
await page.screenshot({
  path: outputPath,
  fullPage: true
});
```

Playwright supports full-page screenshots, but Phase 45 should use them as reviewed artifacts rather than a pixel assertion gate. [CITED: https://playwright.dev/docs/screenshots] [VERIFIED: 45-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual browser UAT for visible behavior | PhoenixTest Playwright E2E plus diagnostic traces/screenshots | Locked in project STATE before Phase 45 | Planner should add automated browser checks for behavior and use screenshots as evidence only. [VERIFIED: STATE.md] |
| Single-theme screenshot proof | Explicit light and dark operator/admin captures | Locked by Phase 45 context | Planner must update capture loops and file layout so both themes are reviewable. [VERIFIED: 45-CONTEXT.md] |
| Direct fixture rows for complex workflows | Facade-first deterministic seed helpers | Existing seed/context pattern | Planner should generate real events and state transitions before adjusting passive display fields. [VERIFIED: codebase grep] |
| Suggestion status as review status | ReviewTask as operator review queue state | Existing KnowledgeAutomation model | Planner must test ReviewTask statuses, not invented suggestion statuses. [VERIFIED: codebase grep] |

**Deprecated/outdated:**

- CI pixel/snapshot gate for Phase 45: explicitly out of scope. [VERIFIED: 45-CONTEXT.md]
- Percy/Chromatic/Storybook visual review: explicitly out of scope. [VERIFIED: 45-CONTEXT.md]
- Random/generated seed volume: explicitly out of scope. [VERIFIED: 45-CONTEXT.md]
- Customer chat/demo index acceptance as Phase 45 proof: excluded unless a direct requirement says otherwise. [VERIFIED: 45-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No new external package should be installed during Phase 45. | Standard Stack / Package Legitimacy Audit | If implementation discovers a real missing dependency, planner must add package legitimacy, registry verification, and a human checkpoint before install. |

The assumption is low risk because the phase context explicitly rejects new visual tooling and the repo already contains the relevant Elixir and Playwright dependencies. [VERIFIED: 45-CONTEXT.md] [VERIFIED: package-lock.json]

## Open Questions (RESOLVED)

1. **What exact screenshot file layout should be used?**
   - RESOLVED: Use explicit light and dark screenshot path sets with theme directory/file naming: `guides/assets/light/...` and `guides/assets/dark/...`, as finalized in Plans 45-02 and 45-03.
   - What we know: Light and dark outputs must be explicit and easy to review. [VERIFIED: 45-CONTEXT.md]
   - Final decision: Theme directories are the Phase 45 acceptance source of truth; any root-level light copies are compatibility-only for existing docs references. [VERIFIED: 45-02-PLAN.md] [VERIFIED: 45-03-PLAN.md]

2. **Should the high-risk demo tool be a new example module or a seed-local helper?**
   - RESOLVED: Seed and screenshot work targets the existing example app module boundaries and facade-first seed patterns: keep deterministic seed builders in `examples/cairnloop_example/priv/repo/seeds.exs`, add the high-risk demo tool under `examples/cairnloop_example/lib/...`, and register it only in example config. [VERIFIED: 45-01-PLAN.md]
   - What we know: Higher-risk coverage must stay example-app-only and should not broaden the public API. [VERIFIED: 45-CONTEXT.md]
   - Final decision: Use facade-first seed helpers for behaviorful state and the example-app module for the governed tool, because this mirrors the existing `InternalNote` tool pattern without expanding the root library API. [VERIFIED: codebase grep] [VERIFIED: 45-01-PLAN.md]

3. **Should existing demo-index/customer-chat screenshots remain in capture output?**
   - RESOLVED: Demo and customer-chat flows are excluded from Phase 45 acceptance. Acceptance is operator/admin UI proof across happy, empty, error, dense, and boundary states. [VERIFIED: 45-02-PLAN.md] [VERIFIED: 45-03-PLAN.md]
   - What we know: Phase 45 acceptance excludes them unless a direct requirement says otherwise. [VERIFIED: 45-CONTEXT.md]
   - Final decision: Existing docs compatibility may keep old capture output if needed, but the Phase 45 visual acceptance ledger and completion evidence must cover operator/admin screens only. [VERIFIED: codebase grep] [VERIFIED: 45-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Root and example Mix workflows | Yes | 1.19.5 | None needed. [VERIFIED: local command] |
| Mix | Test, check, integration, E2E aliases | Yes | 1.19.5 | None needed. [VERIFIED: local command] |
| Node.js | Playwright screenshot and E2E support | Yes | v22.14.0 | None needed. [VERIFIED: local command] |
| npm | Screenshot/assets package installs | Yes | 11.1.0 | Use existing lockfiles; do not upgrade packages. [VERIFIED: local command] [VERIFIED: package-lock.json] |
| PostgreSQL client/server | Integration and E2E database tests | Yes | `psql` 14.17; local 5432 accepting connections | If unavailable in another environment, planner must add setup or mark DB-required tests explicitly. [VERIFIED: local command] |
| Docker | CI parity and service troubleshooting | Yes | 29.5.2 | Local Postgres is already available for this machine. [VERIFIED: local command] |
| Playwright CLI | Screenshot and E2E browser automation | Yes | 1.60.0 in screenshot/assets node_modules | Run locked package install in the relevant directory if missing. [VERIFIED: local command] |
| Git | Commit research and inspect changes | Yes | 2.41.0 | None needed. [VERIFIED: local command] |

**Missing dependencies with no fallback:** none found on this machine. [VERIFIED: local command]
**Missing dependencies with fallback:** none found on this machine. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit, Phoenix LiveView tests, PhoenixTest Playwright 0.14.0, Playwright 1.60.0. [VERIFIED: mix.exs] [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: package-lock.json] |
| Config file | Root `mix.exs`, example `examples/cairnloop_example/mix.exs`, example `config/test.exs`, screenshot `examples/cairnloop_example/screenshots/package.json`. [VERIFIED: codebase grep] |
| Quick run command | `cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test test/cairnloop_example/seeds_test.exs` [VERIFIED: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs] |
| Full suite command | `mix test && PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres MIX_ENV=test mix test.integration && mix check && (cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test.e2e)` [VERIFIED: 45-CONTEXT.md] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SEED-01 | Seed creates varied governed-action audit events, KB review states, draft article state, masked MCP tokens, and high-risk tool proposal while remaining idempotent. | DB/integration seed contract | `cd examples/cairnloop_example && PGPORT=5432 MIX_ENV=test mix test test/cairnloop_example/seeds_test.exs` | Yes, extend existing file. [VERIFIED: codebase grep] |
| VERIFY-01 | Dual-theme screenshot capture covers operator/admin matrix and output paths are recorded in a visual acceptance ledger. | Screenshot generation plus ledger review; optional E2E for theme behavior | `cd examples/cairnloop_example/screenshots && npm run capture` after seeded app setup | Script exists; ledger is Wave 0 gap. [VERIFIED: codebase grep] |
| VERIFY-02 | Root unit, integration, quality, E2E, screenshot, and release-gate checks pass before green claim. | Full verification sweep | Context-locked full sweep commands plus screenshot regeneration | Commands exist; planner must schedule final sweep. [VERIFIED: 45-CONTEXT.md] [VERIFIED: mix.exs] |

### Sampling Rate

- **Per task commit:** Run the focused command for the changed surface, such as seed test, brand token gate, or specific E2E module. [VERIFIED: 45-CONTEXT.md]
- **Per wave merge:** Run all tests covering the wave surface, including DB-required example seed tests for seed changes and screenshot capture smoke for screenshot changes. [VERIFIED: 45-CONTEXT.md]
- **Phase gate:** Run root `mix test`, root integration, root `mix check`, example E2E, screenshot regeneration, and release-gate/milestone audit review before claiming completion. [VERIFIED: 45-CONTEXT.md]

### Wave 0 Gaps

- [ ] Extend `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` to assert new Phase 45 seed coverage. [VERIFIED: codebase grep]
- [ ] Define `45-VISUAL-ACCEPTANCE.md` with one row per captured screen and theme. [VERIFIED: 45-CONTEXT.md]
- [ ] Update `examples/cairnloop_example/screenshots/capture.mjs` to force explicit light/dark app and browser theme state. [VERIFIED: codebase grep] [CITED: https://playwright.dev/docs/emulation]
- [ ] Add or extend E2E only if browser-visible behavior changes beyond screenshot generation. [VERIFIED: STATE.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | Yes, indirectly | Use existing example operator session/auth wiring; do not add authentication behavior in Phase 45. [VERIFIED: codebase grep] |
| V3 Session Management | Yes, indirectly | Keep Phoenix/Phoenix LiveView session handling unchanged. [VERIFIED: codebase grep] |
| V4 Access Control | Yes | Seed data must match operator/tenant scope and use `Cairnloop.Governance` facade reads/writes for governed actions. [VERIFIED: CLAUDE.md] [VERIFIED: codebase grep] |
| V5 Input Validation | Yes | Use Ecto changesets, tool schemas, and public context validation instead of raw params or manual status mutation. [VERIFIED: codebase grep] |
| V6 Cryptography | Yes | Use `Cairnloop.MCP.issue_token/1`; never hand-roll token hashes or expose raw token values. [VERIFIED: codebase grep] |
| V8 Data Protection | Yes | Keep secrets masked, user-facing labels calm, and raw metadata behind explicit expanders only. [VERIFIED: CLAUDE.md] [VERIFIED: codebase grep] |

### Known Threat Patterns for Phoenix/Ecto/Playwright Evidence

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Raw MCP token captured in seed output, screenshots, or tests | Information Disclosure | Discard raw token returned by `issue_token/1`; assert masked Settings UI only. [VERIFIED: codebase grep] |
| Direct DB writes bypass approval/review audit trails | Tampering / Repudiation | Use `Governance`, `KnowledgeAutomation`, `KnowledgeBase`, and `MCP` facades for behaviorful state. [VERIFIED: codebase grep] |
| Cross-scope demo data leaks or disappears | Information Disclosure / Authorization Bypass | Use the existing demo operator/tenant scope from current seed and route setup. [VERIFIED: codebase grep] |
| Dependency supply-chain drift during evidence work | Tampering | Do not add or upgrade packages; keep locked Playwright 1.60.0 unless a human checkpoint approves change. [VERIFIED: package-lock.json] [VERIFIED: package-legitimacy seam] |
| Screenshots expose implementation details or raw backend payloads | Information Disclosure | Keep raw details behind explicit expanders and use user-facing microcopy in visible surfaces. [VERIFIED: CLAUDE.md] |
| Browser behavior accepted manually instead of tested | Repudiation | Use PhoenixTest Playwright E2E for behavior and keep screenshots as evidence assets. [VERIFIED: STATE.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/45-seed-enrichment-screenshot-regen-verification-sweep/45-CONTEXT.md` - locked phase decisions, screenshot matrix, verification sweep, deferred scope. [VERIFIED: 45-CONTEXT.md]
- `.planning/REQUIREMENTS.md` - SEED-01, VERIFY-01, VERIFY-02 requirement IDs. [VERIFIED: REQUIREMENTS.md]
- `.planning/STATE.md` - automation policy and current phase/milestone context. [VERIFIED: STATE.md]
- `.planning/ROADMAP.md` - Phase 45 goal, dependencies, and success criteria. [VERIFIED: ROADMAP.md]
- `CLAUDE.md` - project coding, testing, governance, UI copy, and token constraints. [VERIFIED: CLAUDE.md]
- `examples/cairnloop_example/priv/repo/seeds.exs` and `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` - current seed architecture and test contract. [VERIFIED: codebase grep]
- `lib/cairnloop/knowledge_automation.ex`, `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/mcp.ex`, `lib/cairnloop/governance.ex`, and related schemas - facade and state-machine behavior. [VERIFIED: codebase grep]
- `examples/cairnloop_example/screenshots/capture.mjs` and `examples/cairnloop_example/screenshots/README.md` - existing screenshot workflow. [VERIFIED: codebase grep]
- `mix.exs`, `examples/cairnloop_example/mix.exs`, `.github/workflows/ci.yml` - verification aliases and CI release-gate parity. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Playwright emulation docs - `colorScheme` browser emulation. [CITED: https://playwright.dev/docs/emulation]
- Playwright screenshots docs - `page.screenshot` and `fullPage` capture behavior. [CITED: https://playwright.dev/docs/screenshots]
- Playwright visual comparison docs - screenshot comparison caveats and stabilization options. [CITED: https://playwright.dev/docs/test-snapshots]
- PhoenixTest Playwright HexDocs - browser-backed Phoenix testing helpers. [CITED: https://hexdocs.pm/phoenix_test_playwright/]
- Phoenix.Ecto.SQL.Sandbox docs - Phoenix SQL sandbox plug/test ownership patterns. [CITED: https://hexdocs.pm/phoenix_ecto/Phoenix.Ecto.SQL.Sandbox.html]
- Ecto SQL Sandbox docs - sandboxed database tests. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html]
- Oban docs - queue draining and test execution behavior. [CITED: https://hexdocs.pm/oban/Oban.html]

### Tertiary (LOW confidence)

- None used as authoritative research input. Assumptions are listed in the Assumptions Log. [VERIFIED: research notes]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - versions and paths were verified from lockfiles, local commands, registry probes, and official docs. [VERIFIED: local command] [VERIFIED: package-lock.json] [VERIFIED: npm registry]
- Architecture: HIGH - phase context and codebase boundaries align on facade-first seeds, ReviewTask KB state, Governance audit state, MCP token facade, and existing screenshot workflow. [VERIFIED: 45-CONTEXT.md] [VERIFIED: codebase grep]
- Pitfalls: HIGH - pitfalls come from current schemas, public contexts, existing screenshot script behavior, and locked phase decisions. [VERIFIED: codebase grep] [VERIFIED: 45-CONTEXT.md]

**Research date:** 2026-06-26
**Valid until:** 2026-07-26 for codebase-specific planning; recheck dependency versions and Playwright docs before any package upgrade. [ASSUMED]
