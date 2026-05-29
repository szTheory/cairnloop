# Phase 32: README + ExDoc Guides + JTBD Walkthrough - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite the library's front door (README) as a concise Igniter-first entry point, ship four ExDoc guides under `guides/`, wire `mix.exs` to include the guides directory in the published package and ExDoc navigation, and write the vM014 CHANGELOG entry. This is a pure documentation phase — no Elixir source changes, no new dependencies, no sealed primitives touched.

**What ships:**
- `README.md` — full restructure: `mix cairnloop.install` one-liner → short pitch → guide links. Removes "If [available in Hex]" artifact and inlined telemetry/notifier code (those belong in the host-integration guide).
- `guides/01-quickstart.md` — step-by-step from clone to first LiveView route
- `guides/02-jtbd-walkthrough.md` — prose walkthrough of every JTBD stage in the seeded example, with code references and screen-region descriptions; bounded `<!-- SCREENSHOTS: ... -->` block at the end for a follow-on manual capture step
- `guides/03-host-integration.md` — `ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider` behaviours with inline code examples
- `guides/04-troubleshooting.md` — common adoption errors, config pitfalls, DB migration issues
- `mix.exs` `docs:` extras updated to include `guides/` files; `:assets` key added if images dir exists
- `CHANGELOG.md` — vM014 entry summarizing the 6-phase adopter-surface improvements

</domain>

<decisions>
## Implementation Decisions

### Screenshot strategy (DOC-02, guides/02-jtbd-walkthrough.md)

- **D-01:** Ship a **text-complete guide with a bounded TODO block** for screenshots. The executor writes `guides/02-jtbd-walkthrough.md` with full prose covering every JTBD stage (inbox view, conversation workspace, cmd+k search, draft approval, tool proposal, resolve, outbound, bulk recovery), with code references and screen-region descriptions ("The inbox shows 12–16 conversations across all status states — new (blue), open, awaiting customer, resolved"). No placeholder PNG stubs are committed. At the end of the guide, include one bounded block:
  ```
  <!-- SCREENSHOTS: boot the example app (`cd examples/cairnloop_example && mix setup && mix phx.server`),
       navigate each JTBD stage, capture PNGs to guides/assets/, update the image references above.
       See guides/02-jtbd-walkthrough.md for the labeled regions. -->
  ```
  **Rationale:** Ash, Broadway, and Req convey UI and flow through prose + code — no screenshots in ExDoc guides. Placeholder stubs publish broken images to real HexDocs adopters. Text-complete guide is immediately useful.

- **D-02:** Do **not** configure `mix.exs` `:assets` until real PNG files exist. The `guides/assets/` directory is not created by the executor. Remove the `:assets` key from `docs:` if it was previously absent (it is — current `mix.exs` has no `:assets` key). Add a comment to the `docs:` block: `# assets: "guides/assets"  # uncomment once PNG screenshots are captured`.

### README restructure (DOC-01)

- **D-03:** **Full restructure** of `README.md` following the Beacon/Igniter/Ash front-door pattern:
  1. Badges (existing — keep)
  2. One-line tagline (tighten existing)
  3. **Installation** — lead immediately with `mix cairnloop.install` as the primary install command. Do NOT lead with the bare deps block. Keep a secondary "Manual install (without Igniter)" subsection below for completeness.
  4. Short "Why Cairnloop?" bullets (trim to 4–5 crisp bullets)
  5. Quick "What it does" — 3–4 sentence prose, no Mermaid diagram (remove the diagram; it's out of date and adds weight without clarity)
  6. **"Explore the guides"** section with links to the four ExDoc guides (`hexdocs.pm/cairnloop/…`)
  7. "Want to contribute?" + license (existing, move to bottom)
  **Rationale:** Full restructure is correct because guides co-ship in the same phase (no broken links). The current README has two correctness problems: "If [available in Hex]" on a live Hex.pm package, and Installation leading with deps. Inlined telemetry + Notifier code belongs in `guides/03-host-integration.md`.

- **D-04:** The existing `docs/cairnloop-jtbd-and-user-flows.md` (553-line internal evaluation memo) is **kept as-is** — it is not linked from ExDoc and not exposed in `mix.exs` extras. It remains a useful internal reference for planner and researcher agents. Do NOT delete it or rename it.

### mix.exs ExDoc wiring (DOC-03)

- **D-05:** Add the four guide files to `extras` in the `docs:` block, ordered before `README.md`:
  ```elixir
  extras: [
    "guides/01-quickstart.md",
    "guides/02-jtbd-walkthrough.md",
    "guides/03-host-integration.md",
    "guides/04-troubleshooting.md",
    "README.md",
    "CHANGELOG.md"
  ],
  ```
  Add a `groups_for_extras:` key to surface guides as a named section in the ExDoc sidebar:
  ```elixir
  groups_for_extras: [
    "Guides": ~r/^guides\//
  ],
  ```
  The `package:` `:files` key should include `"guides"` so guides ship with the Hex package:
  ```elixir
  files: ~w(lib priv guides mix.exs README.md LICENSE.md CHANGELOG.md)
  ```
  Check whether a `:files` key exists in `package:` — if absent (current state), add it with the above value.

### CHANGELOG entry (DOC-04)

- **D-06:** Add a `## [Unreleased]` section update (above the existing `## [0.1.0]` entry). The vM014 entry goes under `## [Unreleased]` using standard Keep-a-Changelog format:
  ```markdown
  ## [Unreleased]

  ### Added
  - Realistic demo fixtures: 12–16 seeded conversations spanning all JTBD states, 5 KB articles with revisions, 3 GapCandidates, 1 ArticleSuggestion ready for review (Phase 27)
  - Customer `/chat` widget wired to real ingress via `Cairnloop.Channels.WidgetSocket` + `WidgetChannel`; two-tab demo (Phase 28)
  - Brand-token CSS extraction: `prompts/cairnloop.css` `:root` block in example app; `var(--cl-token)` without hex fallback; negative-grep gate (Phase 29, D-10 closure)
  - KB editorial polish: shared nav shell across 4 KB routes, "Create new article" affordance, gap-evidence sidebar in Editor, calm copy on SuggestionReview handoff (Phase 30)
  - T-10-09 and T-10-11 closure: `EditorHandoff` double-layer gate (DB `manual_edit_opened_at` timestamp + signed token assertion) prevents preloading `proposed_markdown` without deliberate handoff (Phase 30)
  - Golden-path JTBD smoke test in CI: `golden_path_test.exs` (E2E-01) + `widget_channel_test.exs` (E2E-02) under `mix test.integration` (Phase 31)
  - README rewritten as an Igniter-first front door; four ExDoc guides (quickstart, JTBD walkthrough, host integration, troubleshooting) published to HexDocs (Phase 32)
  ```

### Auto-decided (no discussion needed — recorded for downstream agents)

- **D-07:** Guide file names exactly match the requirement: `guides/01-quickstart.md`, `guides/02-jtbd-walkthrough.md`, `guides/03-host-integration.md`, `guides/04-troubleshooting.md`. The `guides/` directory is created at the project root (same level as `lib/`, `test/`, `priv/`).

- **D-08:** `guides/02-jtbd-walkthrough.md` covers the JTBD stages in the order the Phase-27-seeded example demonstrates them: inbox → conversation workspace + cmd+k search + citation chip → draft approval → governed tool proposal + approve → ToolExecutionWorker success → resolve → Outbound trigger → bulk recovery. This is the same order as the Phase 31 golden-path test (E2E-01). Reference `test/integration/golden_path_test.exs` for the exact stage sequence.

- **D-09:** `guides/03-host-integration.md` covers the four required behaviours — `ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider` — with inline code examples extracted from `lib/cairnloop/` module `@moduledoc` strings where available. This is where the current README's inlined telemetry code block moves to.

- **D-10:** `guides/04-troubleshooting.md` covers: `mix cairnloop.install` prerequisites (Igniter dep, Ecto repo detection), migration order (host tables before library tables — per `test.setup` alias in `mix.exs`), pgvector extension requirement, common mount errors (missing `ContextProvider`/`Notifier` config), `ChunkRevision` Oban worker timing (embeddings are async, not instant after seed).

- **D-11:** The `mix.exs` `package:` `:files` key — if absent (it is), add it as described in D-05. Do NOT remove any existing `package:` keys.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements + Roadmap
- `.planning/REQUIREMENTS.md` §DOC — DOC-01, DOC-02, DOC-03, DOC-04 with full acceptance criteria. Read before writing any file.
- `.planning/ROADMAP.md` §Phase 32 — Goal, 4 success criteria, depends-on chain (Phase 31).

### Source files to update
- `README.md` — full restructure (D-03). Current content: badges, Mermaid diagram, "If [available in Hex]" Installation, feature bullets, host-integration + telemetry inline code.
- `mix.exs` — add `guides/` to `extras`, add `groups_for_extras:`, add `:files` to `package:` (D-05, D-11).
- `CHANGELOG.md` — add vM014 `## [Unreleased]` section above `## [0.1.0]` (D-06).

### New files to create
- `guides/01-quickstart.md`
- `guides/02-jtbd-walkthrough.md`
- `guides/03-host-integration.md`
- `guides/04-troubleshooting.md`

### Install task (for README and quickstart guide)
- `lib/mix/tasks/cairnloop/install.ex` — Igniter task; `mix cairnloop.install` adds dep + generates Ecto migration. Primary install path for DOC-01.

### ExDoc wiring reference
- `mix.exs` current `docs:` block — `main: "readme"`, `extras: ["README.md", "CHANGELOG.md"]`, `groups_for_modules:`. The planner must extend this, not replace it.

### Content sources for guides
- `docs/cairnloop-jtbd-and-user-flows.md` — 553-line internal evaluation memo covering every JTBD flow with confidence ratings. Primary content source for `guides/02-jtbd-walkthrough.md` and `guides/03-host-integration.md`. NOT exposed in ExDoc — internal reference only.
- `test/integration/golden_path_test.exs` — Phase 31 golden-path test covering the 8 JTBD stages in order. Use as the authoritative stage sequence for `guides/02-jtbd-walkthrough.md` (D-08).
- `examples/cairnloop_example/README.md` — Example app README; cross-reference for the quickstart guide.
- `prompts/cairnloop_brand_book.md` — Brand voice + copy register for guide prose tone.

### Phase history (for CHANGELOG)
- `.planning/phases/27-realistic-demo-fixtures/` — Phase 27 shipped realistic fixtures
- `.planning/phases/28-customer-chat-wired-to-real-ingress/` — Phase 28 shipped WidgetChannel
- `.planning/phases/29-brand-token-css-extraction-d-10-closure/` — Phase 29 shipped brand tokens
- `.planning/phases/30-kb-editorial-polish-t-10-09-t-10-11-closure/` — Phase 30 shipped KB polish + SEC
- `.planning/phases/31-golden-path-jtbd-smoke-test/` — Phase 31 shipped golden-path smoke test

### Architecture posture
- `CLAUDE.md` — Build/test conventions; warnings-clean build; arch invariants. This phase has no Elixir source changes, so no `mix compile` gate is needed — but the planner should verify `mix docs` runs clean after updating `mix.exs`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`docs/cairnloop-jtbd-and-user-flows.md`** — 553 lines of content covering every JTBD flow. The prose tone and structure can be adapted for the ExDoc guides. Particularly useful for `guides/02-jtbd-walkthrough.md` sections.
- **`examples/cairnloop_example/README.md`** — Example app setup instructions to cross-reference for the quickstart guide's "clone to first boot" section.
- **`lib/mix/tasks/cairnloop/install.ex`** — Igniter task source; use its `@moduledoc` (if any) and the steps it performs (adds dep, generates migration) as the authoritative description for DOC-01 README and quickstart.
- **`test/integration/golden_path_test.exs`** — Phase 31 test covers the 8-stage JTBD sequence. The test's `# Stage N: ...` comments define the canonical stage names for `02-jtbd-walkthrough.md`.

### Established Patterns
- **ExDoc extras ordering** — Current `extras:` lists `README.md` first (it's `main: "readme"`). Adding guides before README.md in the extras list puts them in the sidebar above "Read Me" — which is the right order for a "Guides" group in the ExDoc sidebar. The `groups_for_extras:` key in ExDoc will handle grouping regardless of ordering.
- **Keep-a-Changelog format** — `CHANGELOG.md` follows Keep-a-Changelog 1.0 with `## [Unreleased]` → `## [0.1.0] - 2026-05-25`. The vM014 entry goes in `## [Unreleased]` with subsections (`### Added`, `### Changed` if needed).
- **Hex package `:files` convention** — If absent, Hex defaults to everything not in `.gitignore`. Adding explicit `:files` is best practice for published libraries to avoid shipping test artifacts; the `guides/` dir must be listed explicitly.

### Integration Points
- `mix.exs` `docs:` block — two keys need updating: `extras:` (add 4 guide files) and `groups_for_extras:` (add Guides group)
- `mix.exs` `package:` block — add `:files` key including `"guides"` so guides ship with the Hex package
- `mix.exs` `docs:` — check if `:assets` key exists (it doesn't); add commented-out `:assets` line per D-02
- No LiveView or Elixir source changes — this phase is documentation only

</code_context>

<specifics>
## Specific Ideas

- The `guides/02-jtbd-walkthrough.md` JTBD stage order should match the Phase 31 golden-path test exactly: inbox → conversation workspace + cmd+k search + citation chip → AI draft approval → governed tool proposal approve → ToolExecutionWorker success → resolve → Outbound trigger → bulk recovery multi-select. This ensures the walkthrough guide and the CI smoke test tell the same story.
- The README's "Installation" section should show the two-step Igniter install clearly:
  ```bash
  # Step 1: Add Igniter if not already in deps
  mix deps.get
  # Step 2: Run the Cairnloop installer
  mix cairnloop.install
  ```
  Then the secondary "Manual install" subsection for users who prefer the deps block.
- `guides/03-host-integration.md` should open with the four behaviour module contracts in the order a new adopter would implement them: `ContextProvider` (always required for context snippets), `Notifier` (required for outbound), `AutomationPolicy` (governs AI drafting), `SLAPolicyProvider` (SLA rules). The current README's telemetry section should be condensed here.
- The README's Mermaid diagram is outdated (predates the outbound lane, governed tools, and MCP seam). Remove it rather than update it — the guides cover the architecture in prose with more accuracy.

</specifics>

<deferred>
## Deferred Ideas

- Real PNG screenshots for `guides/02-jtbd-walkthrough.md` — executor leaves a bounded `<!-- SCREENSHOTS: ... -->` block; owner captures PNGs in a manual browser session and uncommits the `:assets` key in `mix.exs` (D-02).
- ExDoc `:assets` configuration and `guides/assets/` directory — deferred until PNG files exist (D-02).
- `mix docs` CI gate (verify ExDoc renders cleanly) — not added to CI as part of this phase; planner may note this as a nice-to-have.
- Updating `docs/cairnloop-jtbd-and-user-flows.md` to reflect shipped state — it's an internal memo; left as-is.

</deferred>

---

*Phase: 32-readme-exdoc-guides-jtbd-walkthrough*
*Context gathered: 2026-05-28*
