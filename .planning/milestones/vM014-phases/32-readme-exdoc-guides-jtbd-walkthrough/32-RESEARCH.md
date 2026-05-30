# Phase 32: README + ExDoc Guides + JTBD Walkthrough - Research

**Researched:** 2026-05-28
**Domain:** Elixir library documentation — README front-door restructure, ExDoc `guides/` extras, Hex package `:files`, Keep-a-Changelog
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Screenshots):** Ship a **text-complete** `guides/02-jtbd-walkthrough.md` with full prose covering every JTBD stage (inbox view, conversation workspace, cmd+k search, draft approval, tool proposal, resolve, outbound, bulk recovery) plus code references and screen-region descriptions. NO placeholder PNG stubs committed. End the guide with one bounded block:
  ```
  <!-- SCREENSHOTS: boot the example app (`cd examples/cairnloop_example && mix setup && mix phx.server`),
       navigate each JTBD stage, capture PNGs to guides/assets/, update the image references above.
       See guides/02-jtbd-walkthrough.md for the labeled regions. -->
  ```
- **D-02 (`:assets`):** Do NOT configure `mix.exs` `:assets` until real PNG files exist. Do NOT create `guides/assets/`. Add a commented line in the `docs:` block: `# assets: "guides/assets"  # uncomment once PNG screenshots are captured`.
- **D-03 (README restructure):** Full restructure following Beacon/Igniter/Ash front-door pattern: (1) badges keep, (2) tighten one-line tagline, (3) **Installation leads with `mix cairnloop.install`** — secondary "Manual install (without Igniter)" subsection below, (4) trim "Why Cairnloop?" to 4–5 bullets, (5) 3–4 sentence "What it does" prose, **remove the Mermaid diagram**, (6) "Explore the guides" section linking the four HexDocs guides, (7) contribute + license at bottom. The inlined telemetry + Notifier code moves to `guides/03-host-integration.md`.
- **D-04:** `docs/cairnloop-jtbd-and-user-flows.md` kept as-is — NOT linked from ExDoc, NOT in `mix.exs` extras. Do NOT delete or rename.
- **D-05 (mix.exs ExDoc wiring):** Add four guide files to `extras` ordered before `README.md`; add `groups_for_extras: ["Guides": ~r/^guides\//]`; add `package:` `:files` key `~w(lib priv guides mix.exs README.md LICENSE.md CHANGELOG.md)`.
- **D-06 (CHANGELOG):** Add the vM014 entry under a `## [Unreleased]` section above `## [0.1.0]`, in Keep-a-Changelog format (verbatim text supplied in CONTEXT.md D-06).
- **D-07:** Exact file names — `guides/01-quickstart.md`, `guides/02-jtbd-walkthrough.md`, `guides/03-host-integration.md`, `guides/04-troubleshooting.md`. `guides/` created at project root (same level as `lib/`, `test/`, `priv/`).
- **D-08:** `02-jtbd-walkthrough.md` stage order matches the Phase 31 golden-path test exactly: inbox → conversation workspace + cmd+k search + citation chip → draft approval → governed tool proposal + approve → ToolExecutionWorker success → resolve → Outbound trigger → bulk recovery. Reference `test/integration/golden_path_test.exs`.
- **D-09:** `03-host-integration.md` covers `ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider` with inline code from `lib/cairnloop/` `@moduledoc` strings. The current README's inlined telemetry block moves here.
- **D-10:** `04-troubleshooting.md` covers install prerequisites (Igniter dep, Ecto repo detection), migration order (host tables before library tables — per `test.setup` alias), pgvector extension requirement, common mount errors (missing `ContextProvider`/`Notifier` config), `ChunkRevision` Oban worker timing (embeddings async, not instant after seed).
- **D-11:** `mix.exs` `package:` `:files` — add if absent (it is). Do NOT remove any existing `package:` keys.

### Claude's Discretion

- Prose tone of all four guides (must follow `prompts/cairnloop_brand_book.md` — calm, reason-forward, honest, no raw Elixir terms to operators).
- Exact wording of the README "Why Cairnloop?" bullets and "What it does" paragraph.
- Internal section structure within each guide (headings, ordering of subsections) so long as D-08/D-09/D-10 content coverage holds.
- Whether to add per-extra `title:` metadata in `extras` (recommended — see Pattern 2).

### Deferred Ideas (OUT OF SCOPE)

- Real PNG screenshots for `02-jtbd-walkthrough.md` (bounded TODO block only; owner captures manually).
- ExDoc `:assets` configuration and `guides/assets/` directory (until PNGs exist).
- `mix docs` CI gate (nice-to-have; planner may note, do not add).
- Updating `docs/cairnloop-jtbd-and-user-flows.md` to reflect shipped state (internal memo, left as-is).
- Future guides `05-mcp-clients.md`, `06-extending.md`, `CONTRIBUTING.md`, `docs/architecture.md` (all vM015 — DOC-FUT-*).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | Root `README.md` leads with `mix cairnloop.install`, not the `{:cairnloop, "~> 0.1.0"}` snippet | Install task verified at `lib/mix/tasks/cairnloop/install.ex` (adds dep + generates `create_cairnloop_tables` migration via Igniter). README structure pattern in Standard Stack + Architecture Patterns. |
| DOC-02 | ExDoc `guides/` directory ships four guides (`01-quickstart`, `02-jtbd-walkthrough`, `03-host-integration`, `04-troubleshooting`) | Content sources mapped: golden-path test (stage sequence), JTBD memo (prose), four behaviour `@moduledoc`s (host integration), install task + `test.setup` alias (troubleshooting). Screenshot strategy per D-01. |
| DOC-03 | `mix.exs` package config ships `guides/` and `mix docs` surfaces them in navigation | ExDoc `extras` + `groups_for_extras` syntax VERIFIED against ExDoc 0.40.3 docs; Hex `:files` default VERIFIED to NOT include `guides` — explicit `:files` required. |
| DOC-04 | `CHANGELOG.md` carries a vM014 entry summarizing adopter-surface improvements | Current CHANGELOG uses Keep-a-Changelog 1.0 with empty `## [Unreleased]` above `## [0.1.0]`. D-06 supplies verbatim entry. |
</phase_requirements>

## Summary

Phase 32 is a **pure documentation phase** — no Elixir source changes, no new dependencies, no sealed primitives touched. The only compiled file edited is `mix.exs` (config keys, not code paths). The work is: (1) a full restructure of `README.md` to lead with the shipped `mix cairnloop.install` Igniter task, (2) four new Markdown guides under a new root-level `guides/` directory, (3) three additive `mix.exs` config edits so the guides publish to HexDocs and ship in the Hex tarball, and (4) a vM014 CHANGELOG entry.

Every technical claim in the CONTEXT decisions is verified correct against authoritative sources. The locally locked ExDoc is **0.40.3** (matches the current Hex release), whose `:extras` and `:groups_for_extras` options support exactly the configuration D-05 prescribes. Critically, the Hex package default `:files` list does **NOT** include a `guides` directory — so without the explicit `:files` key (D-05/D-11), the guides would render on a local `mix docs` run but would be **absent from the published Hex tarball and from HexDocs**. This is the single highest-value correctness item in the phase and is already captured by the locked decisions.

The content for the guides is fully available in-repo: the canonical JTBD stage sequence lives in `test/integration/golden_path_test.exs` (9 accumulating stages with `# Stage N:` comments), the prose source is `docs/cairnloop-jtbd-and-user-flows.md` (553-line memo), and the four host behaviours carry authoritative `@moduledoc`/`@callback` specs. One real ambiguity surfaced (route naming: golden-path test uses `/inbox` + `/governance/:id`; the shipped `cairnloop_dashboard` macro and example app mount at `/support` + `/support/:id`) — the guides must use the **macro/example-app routes**, not the test's internal routes (see Common Pitfall 1).

**Primary recommendation:** Treat the four CONTEXT decisions on `mix.exs` (D-05, D-11, D-02) as a single atomic edit and verify with `mix docs` (rendering) plus a dry-run `mix hex.build` check (tarball contents) — both are runnable without a database. Write all four guides from the in-repo sources cited below; do not invent API surface — cross-check every code example against the actual module.

## Architectural Responsibility Map

This phase is documentation-only; "tiers" here map to documentation surfaces rather than runtime tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Install path discovery (DOC-01) | README (front door) | `guides/01-quickstart.md` | README is the first thing adopters see; quickstart expands the steps. |
| Task-shaped onboarding (DOC-02) | `guides/` (ExDoc extras) | README "Explore the guides" links | Guides are the self-serve task surface; README points to them. |
| Package/docs distribution (DOC-03) | `mix.exs` `package:` + `docs:` | HexDocs (downstream of `mix hex.publish`) | `mix.exs` controls both the published tarball and the docs navigation. |
| Release narrative (DOC-04) | `CHANGELOG.md` | ExDoc `extras` (renders changelog at `changelog.html`) | CHANGELOG is the canonical change record; ExDoc surfaces it. |
| Host integration contract docs (DOC-02) | `guides/03-host-integration.md` | Module `@moduledoc` (ExDoc API reference) | Guide is the task-shaped narrative; `@moduledoc`s are the API reference. |

## Standard Stack

This phase introduces **no new dependencies**. The relevant tooling is already locked.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ex_doc` | `0.40.3` (locked) `[VERIFIED: hex.pm + local mix.lock]` | Generate HTML/EPUB docs from `@moduledoc` + Markdown extras | Canonical Elixir doc generator; already in `deps` (`~> 0.34`, locked to 0.40.3) |
| `hex` (build tooling) | bundled with Mix | `mix hex.build` / `mix hex.publish` — controls the published tarball via `package: :files` | Canonical Elixir package manager |
| `igniter` | `~> 0.5` (locked) `[VERIFIED: local mix.exs]` | Powers `mix cairnloop.install` (the DOC-01 install path) | Already a runtime dep; the install task uses `Igniter.Project.Deps.add_dep` + `Igniter.Libs.Ecto.gen_migration` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Keep a Changelog | spec 1.0.0 | CHANGELOG format already in use | The vM014 entry must follow the existing `### Added` subsection convention |
| Semantic Versioning | spec 2.0.0 | Versioning policy declared in CHANGELOG header | Unreleased entries accumulate until the next version tag |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `groups_for_extras` regex | `Path.wildcard("guides/*.md")` per group | Both valid `[VERIFIED: ExDoc docs]`. Regex (`~r/^guides\//`) per D-05 is simpler and has no filesystem dependency at config-eval time. Keep the regex. |
| Numeric-prefixed filenames (`01-quickstart.md`) | Clean names + `filename:`/`title:` metadata | Prefixes guarantee sidebar ordering even without `groups_for_extras`; metadata gives clean titles. Use BOTH (prefixes for files per D-07, `title:` metadata for display — see Pattern 2). |

**Installation:** None — no packages installed this phase.

**Version verification:**
- `ex_doc` locked version confirmed `0.40.3` via `mix hex.info ex_doc` (Config: `{:ex_doc, "~> 0.40.3"}`, Locked version: 0.40.3) and latest-on-Hex confirmed 0.40.3 `[VERIFIED: hex.pm/packages/ex_doc]`.

## Package Legitimacy Audit

> Not applicable — **this phase installs zero external packages.** No `mix deps.get`, no registry fetch. The slopcheck/registry gate is inapplicable. All tooling referenced (`ex_doc`, `igniter`, `hex`) is already present in the locked `mix.exs`/`mix.lock` and was verified against hex.pm during research.

**Packages removed due to slopcheck [SLOP] verdict:** none (no installs)
**Packages flagged as suspicious [SUS]:** none (no installs)

## Architecture Patterns

### Documentation Surface Map (data flow: adopter → first integration)

```
                         ┌─────────────────────────────────────────┐
   Adopter lands on  ───▶│  README.md (front door)                  │
   GitHub / Hex.pm       │  badges → tagline → INSTALL (igniter) →  │
                         │  why → what → "Explore the guides" links │
                         └───────────────┬─────────────────────────┘
                                         │ links to hexdocs.pm/cairnloop/...
                          ┌──────────────┼───────────────┬──────────────────┐
                          ▼              ▼               ▼                  ▼
                  01-quickstart   02-jtbd-walkthrough  03-host-          04-trouble-
                  (clone→route)   (8 JTBD stages,      integration       shooting
                          │        text + TODO         (4 behaviours)    (install/db
                          │        screenshot block)        │            /pgvector)
                          │              │                  │                 │
                          └──────────────┴──────────────────┴─────────────────┘
                                         │  all 4 = ExDoc :extras
                                         ▼
                          ┌─────────────────────────────────────────┐
                          │  mix.exs                                  │
                          │  docs:    extras + groups_for_extras      │  ──▶ mix docs ──▶ HexDocs
                          │  package: files: ~w(... guides ...)       │  ──▶ mix hex.publish ──▶ tarball
                          └─────────────────────────────────────────┘
                                         │
                                         ▼
                          ┌─────────────────────────────────────────┐
                          │  CHANGELOG.md  ## [Unreleased] (vM014)    │  ──▶ ExDoc extra → changelog.html
                          └─────────────────────────────────────────┘
```

Trace the primary use case: adopter reads README install one-liner → runs `mix cairnloop.install` → follows `01-quickstart` to a mounted route → reads `02-jtbd-walkthrough` to understand the live demo → implements host behaviours from `03-host-integration` → resolves setup issues with `04-troubleshooting`. Every guide is reachable from the README and published via `mix.exs`.

### Recommended Project Structure
```
cairnloop/
├── README.md            # restructured (D-03)
├── CHANGELOG.md         # vM014 entry added (D-06)
├── mix.exs              # docs: + package: edits (D-05, D-11, D-02)
├── guides/              # NEW root-level directory (D-07) — NOT currently tracked in git
│   ├── 01-quickstart.md
│   ├── 02-jtbd-walkthrough.md   # ends with bounded <!-- SCREENSHOTS: ... --> block (D-01)
│   ├── 03-host-integration.md
│   └── 04-troubleshooting.md
│   └── (assets/ NOT created this phase — D-02)
├── docs/
│   └── cairnloop-jtbd-and-user-flows.md   # untouched (D-04)
└── lib/ test/ priv/     # untouched
```

### Pattern 1: Igniter-first README install section (DOC-01)
**What:** Lead the Installation section with the one-command installer, deps block demoted to a secondary "Manual install" subsection.
**When to use:** The library ships an Igniter install task (it does — `lib/mix/tasks/cairnloop/install.ex`).
**Example (recommended README structure — mirrors Ash/Igniter/Beacon front doors):**
````markdown
## Installation

Cairnloop ships an [Igniter](https://hexdocs.pm/igniter) installer that adds the
dependency and generates the database migration for you:

```bash
mix igniter.install cairnloop
```

Or, if Cairnloop is already in your deps, run the installer directly:

```bash
mix deps.get
mix cairnloop.install
```

The installer adds `{:cairnloop, "~> 0.1.0"}` to `mix.exs` and generates a
`create_cairnloop_tables` migration against your detected Ecto repo.

### Manual install (without Igniter)

Add `cairnloop` to your deps and create the migration yourself:

```elixir
def deps do
  [
    {:cairnloop, "~> 0.1.0"}
  ]
end
```
````
**Provenance note:** The install task source confirms it calls `Igniter.Project.Deps.add_dep({:cairnloop, "~> 0.1.0"})` then `Igniter.Libs.Ecto.select_repo()` → `gen_migration(repo, "create_cairnloop_tables", ...)` with `on_exists: :skip` `[VERIFIED: lib/mix/tasks/cairnloop/install.ex]`. The `mix igniter.install cairnloop` form is the standard Igniter convention for installers `[CITED: hexdocs.pm/igniter]` — verify it works for this package during planning; if uncertain, lead with the two-step `mix deps.get && mix cairnloop.install` form per CONTEXT "Specific Ideas" which is `[VERIFIED]` against the task source.

### Pattern 2: ExDoc extras with custom titles + group (DOC-03)
**What:** Register the four guides as `:extras` with display titles, grouped in a "Guides" sidebar section.
**When to use:** When file names carry ordering prefixes (`01-`) but you want clean sidebar labels.
**Example (recommended `docs:` block):**
```elixir
docs: [
  main: "readme",
  extras: [
    {"guides/01-quickstart.md", title: "Quickstart"},
    {"guides/02-jtbd-walkthrough.md", title: "JTBD Walkthrough"},
    {"guides/03-host-integration.md", title: "Host Integration"},
    {"guides/04-troubleshooting.md", title: "Troubleshooting"},
    "README.md",
    "CHANGELOG.md"
  ],
  groups_for_extras: [
    "Guides": ~r/^guides\//
  ],
  # assets: "guides/assets"  # uncomment once PNG screenshots are captured  (D-02)
  groups_for_modules: [
    # ... existing groups unchanged ...
  ]
]
```
**Provenance:** `:extras` accepts either a bare path string or a `{"path", title: "...", filename: "..."}` tuple `[VERIFIED: ExDoc 0.40.x docs — "you can specify keyword pairs to customize the generated filename and title of each extra page"]`. `groups_for_extras` accepts a keyword list mapping a group name to a regex (or `Path.wildcard`) matching extra paths `[VERIFIED: ExDoc docs]`. The plain D-05 form (bare path strings, no `title:`) is also valid — ExDoc derives a title from the first `# H1` heading. Adding `title:` is **Claude's discretion** and recommended for clean sidebar labels without relying on H1 derivation. **Either form satisfies DOC-03.**

### Pattern 3: Hex package `:files` must list `guides` (DOC-03 — critical)
**What:** The `package:` config must include `"guides"` in `:files` or the directory never ships.
**When to use:** Always, when publishing extra directories beyond Hex's defaults.
**Example:**
```elixir
package: [
  name: "cairnloop",
  files: ~w(lib priv guides mix.exs README.md LICENSE.md CHANGELOG.md),
  licenses: ["MIT"],
  links: %{ ... },          # existing — keep
  maintainers: ["szTheory"] # existing — keep
]
```
**Provenance — CRITICAL:** Hex's default `:files` is `["lib", "priv", ".formatter.exs", "mix.exs", "README*", "readme*", "LICENSE*", "license*", "CHANGELOG*", "changelog*", "src", "c_src", "Makefile*"]` — **`guides` is NOT in the default** `[VERIFIED: hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]`. Therefore: adding `extras` alone makes `mix docs` render guides **locally**, but the published Hex tarball (and thus HexDocs, which builds from the tarball) would **omit them** unless `:files` lists `guides`. This is the load-bearing edit for DOC-03's "visible on Hex.pm after the next release" success criterion.

**Caution on `:files` filename casing:** The repo's actual license file is `LICENSE.md` — confirm exact casing/filename before pinning `:files` (the default uses a `LICENSE*` glob; an explicit `:files` list is exact, so a typo silently drops the file). Verify `LICENSE.md`, `README.md`, `CHANGELOG.md` all exist with that exact casing during planning. (`README.md` and `CHANGELOG.md` confirmed present `[VERIFIED]`; `LICENSE.md` casing should be confirmed.)

### Anti-Patterns to Avoid
- **Committing placeholder/broken-link PNG references:** publishes broken images to real HexDocs adopters. Use the bounded TODO block (D-01) instead.
- **Adding `:assets` before `guides/assets/` exists:** `mix docs` warns/errors on a missing assets dir; D-02 keeps it commented out.
- **Editing the deps block or any `lib/` file:** out of scope — this is a docs-only phase; touching compiled code risks churning sealed primitives.
- **Documenting the test-internal routes (`/inbox`, `/governance/:id`) in adopter guides:** those are the integration-test host's routes, not the shipped mount points (see Pitfall 1).
- **Replacing `groups_for_modules`:** the `docs:` block must be **extended**, not rewritten — preserve the existing 6 module groups.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Guide sidebar grouping | Manual HTML/JS or custom nav | ExDoc `groups_for_extras` | Native, regex-driven, zero maintenance `[VERIFIED]` |
| Custom guide page titles | Renaming files to clean names (breaks D-07 ordering) | `{"path", title: "..."}` tuple in `:extras` | Keeps numeric prefixes for ordering AND clean labels `[VERIFIED]` |
| Determining what ships in the package | Guessing or copying another lib's `:files` | `mix hex.build` dry-run + the documented default list | Authoritative; catches the missing-`guides` trap before publish |
| Install steps prose for README/quickstart | Inventing the install flow | Read `lib/mix/tasks/cairnloop/install.ex` verbatim | The task is the source of truth for what `mix cairnloop.install` actually does |
| JTBD stage names/order | Re-deriving from memory or the memo | `# Stage N:` comments in `golden_path_test.exs` | The test IS the locked golden path (E2E-01); guide and CI must tell one story (D-08) |

**Key insight:** Every code snippet and step in these guides has an authoritative in-repo source. The failure mode for a documentation phase is *plausible-but-wrong* prose — API names, route paths, config keys, or install steps that read fine but don't match the shipped code. Cross-check every claim against its source file; do not paraphrase from training knowledge.

## Common Pitfalls

### Pitfall 1: Route mismatch between golden-path test and shipped mount points
**What goes wrong:** The JTBD walkthrough guide documents routes `/inbox` and `/governance/:id` (copied from the test) — but adopters who mount via `cairnloop_dashboard("/support", ...)` get `/support` and `/support/:id`. The guide's URLs would 404 for every reader.
**Why it happens:** `test/integration/golden_path_test.exs` drives `live(conn, "/inbox")` and `live(conn, "/governance/#{id}")` — those are the **integration-test host router's** routes, not the library's. The shipped `Cairnloop.Router.cairnloop_dashboard/2` macro mounts inbox at `<path>/` and conversation at `<path>/:id` `[VERIFIED: lib/cairnloop/router.ex]`. The example app mounts at `/support` → inbox is `/support`, conversation is `/support/:id` `[VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex]`.
**How to avoid:** In `01-quickstart.md` and `02-jtbd-walkthrough.md`, use the **macro/example-app routes** (`/support`, `/support/:id`). Use the golden-path test ONLY for the **stage sequence and behaviour names** (per D-08), not for URLs. State the route convention explicitly: "mounted under the path you pass to `cairnloop_dashboard/2`; this guide assumes `/support` as in the example app."
**Warning signs:** Any `/inbox` or `/governance/` literal in an adopter-facing guide.

### Pitfall 2: Guides render locally but vanish from HexDocs
**What goes wrong:** `mix docs` shows the guides; after `mix hex.publish` they're gone from hexdocs.pm.
**Why it happens:** `:extras` controls local doc generation; `package: :files` controls the published tarball. HexDocs builds from the tarball. Missing `guides` in `:files` → guides not in tarball → not on HexDocs.
**How to avoid:** Add `"guides"` to `:files` (D-05) AND verify the tarball with `mix hex.build` (it prints the included files; check `guides/` appears). Do this verification in the same task as the `mix.exs` edit.
**Warning signs:** `mix hex.build` output omits `guides/*.md`.

### Pitfall 3: `mix docs` errors on the commented `:assets` line or a missing dir
**What goes wrong:** An uncommented `assets: "guides/assets"` with no such directory makes `mix docs` raise.
**Why it happens:** ExDoc validates the assets path at generation time.
**How to avoid:** Keep `:assets` commented (D-02). Do not create `guides/assets/`. Verify `mix docs` runs clean after the edit (no DB needed).
**Warning signs:** `mix docs` raises a "no such file or directory" for `guides/assets`.

### Pitfall 4: Behaviour callback signatures drift from the README's old inline code
**What goes wrong:** Copying the README's existing `Cairnloop.Notifier` example into `03-host-integration.md` ships a stale 2-callback example, but the behaviour now defines **three** callbacks.
**Why it happens:** The current README shows `on_conversation_resolved/2` and `on_sla_breach/3` only. The actual behaviour also defines `on_outbound_triggered/2` `[VERIFIED: lib/cairnloop/notifier.ex]`.
**How to avoid:** Document the **full** current callback set from each behaviour module, not the README's older subset. Authoritative signatures (all `[VERIFIED]` from source):
  - `Cairnloop.ContextProvider`: `get_context(actor_id :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}`
  - `Cairnloop.Notifier`: `on_conversation_resolved/2`, `on_sla_breach/3`, `on_outbound_triggered/2`
  - `Cairnloop.AutomationPolicy`: `decide(proposal :: map(), opts :: map()) :: :allow | :draft_only | :require_approval | :deny`
  - `Cairnloop.SLAPolicyProvider`: `get_active_policies() :: {:ok, list(map())} | {:error, term()}`, `set_policy(priority :: atom(), attrs :: map()) :: {:ok, map()} | {:error, term()}`
**Warning signs:** A Notifier example in the guide with only two `@impl` functions.

### Pitfall 5: README config-snippet mismatch with the install task version pin
**What goes wrong:** README/quickstart shows `{:cairnloop, "~> 0.2.0"}` or similar while the install task pins `~> 0.1.0`.
**Why it happens:** Guessing the version instead of reading the task.
**How to avoid:** Match the version the install task actually adds: `{:cairnloop, "~> 0.1.0"}` `[VERIFIED: install.ex line 16]`. The `mix.exs` `version:` is also `0.1.0` `[VERIFIED]`.

### Pitfall 6: `groups_for_extras` regex doesn't match because of `extras` tuple form
**What goes wrong:** Using `{"guides/01-quickstart.md", title: ...}` tuples while the regex expects to match plain paths — guides don't group.
**Why it happens:** Misconception. The regex matches against the **path** (the tuple's first element / the key), so `~r/^guides\//` matches both the string and tuple forms.
**How to avoid:** No action needed — `~r/^guides\//` correctly matches `guides/01-quickstart.md` regardless of bare-string vs tuple form `[VERIFIED: ExDoc treats the path key uniformly]`. Just verify the rendered sidebar shows a "Guides" group with all four entries.

## Code Examples

Verified host-behaviour contracts for `guides/03-host-integration.md` (all from source `@moduledoc`/`@callback`, order per CONTEXT "Specific Ideas" — implement in this order):

### 1. ContextProvider (always required — context snippets)
```elixir
# Source: lib/cairnloop/context_provider.ex  [VERIFIED]
defmodule MyApp.CairnloopContext do
  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(actor_id, _opts) do
    case MyApp.Accounts.get_user(actor_id) do
      nil -> {:ok, %{}}
      user ->
        {:ok, %{
          "User Details" => %{name: user.name, lifetime_value: "$#{user.ltv}"},
          "Active Plan"  => %{tier: user.plan, status: user.billing_status}
        }}
    end
  end
end
```
Note for prose: the returned map is recursively rendered as categorized UI sections (zero-config UI). Return `{:ok, map}` / `{:error, term}` — never raise — so the dashboard degrades to "Context Unavailable" rather than crashing `[VERIFIED: moduledoc]`.

### 2. Notifier (required for outbound — three callbacks)
```elixir
# Source: lib/cairnloop/notifier.ex  [VERIFIED — three callbacks]
defmodule MyApp.CairnloopNotifier do
  @behaviour Cairnloop.Notifier

  @impl true
  def on_conversation_resolved(conversation, _metadata), do: :ok

  @impl true
  def on_sla_breach(_conversation, _sla, _metadata), do: :ok

  @impl true
  def on_outbound_triggered(_message, _conversation), do: :ok
end
```
Generator escape hatch to mention in the guide: `mix cairnloop.gen.notifier` scaffolds this module and injects `config :cairnloop, :notifier, MyApp.CairnloopNotifier` `[VERIFIED: lib/mix/tasks/cairnloop.gen.notifier.ex]`.

### 3. AutomationPolicy (governs AI drafting)
```elixir
# Source: lib/cairnloop/automation_policy.ex  [VERIFIED]
defmodule MyApp.CairnloopPolicy do
  @behaviour Cairnloop.AutomationPolicy

  @impl true
  def decide(_proposal, _opts), do: :require_approval
  # returns :allow | :draft_only | :require_approval | :deny
end
```

### 4. SLAPolicyProvider (SLA rules)
```elixir
# Source: lib/cairnloop/sla_policy_provider.ex  [VERIFIED]
defmodule MyApp.CairnloopSLA do
  @behaviour Cairnloop.SLAPolicyProvider

  @impl true
  def get_active_policies, do: {:ok, []}

  @impl true
  def set_policy(_priority, _attrs), do: {:error, :not_implemented}
end
```

### Telemetry block to MOVE from README into `03-host-integration.md` (D-09)
The current README (lines 54–94) carries the dual-emission telemetry section (`[:cairnloop, :conversation, :resolve, :stop]` span and `[:cairnloop, :conversation, :resolved]` domain event). Move this prose+code into `03-host-integration.md` as a "Telemetry (observability)" subsection. Per project arch posture: telemetry is observability only — never a UI/display source. Keep the existing example code; verify event names against the codebase if planning has budget (the README's names match the `Cairnloop.Governance.Telemetry` / `[:cairnloop, ...]` namespaces referenced in CHANGELOG `[VERIFIED: CHANGELOG.md]`).

### ExDoc extras + groups + package files (the DOC-03 edit, consolidated)
See Pattern 2 and Pattern 3 above for the verbatim `docs:` and `package:` blocks.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| README leads with `{:cairnloop, "~> 0.1.0"}` deps block + "If [available in Hex]" hedge on a live package | Lead with `mix cairnloop.install` (Igniter) | This phase (DOC-01) | Adopters see the path they should actually use first; removes the incorrect "if available" hedge |
| Architecture conveyed via Mermaid diagram in README | Architecture conveyed in guides as prose | This phase (D-03) | Mermaid diagram is stale (predates outbound lane, governed tools, MCP seam) — removed, not updated |
| Inline telemetry + Notifier code in README | Moved to `guides/03-host-integration.md` | This phase (D-09) | README stays a concise front door; integration depth lives in the task-shaped guide |
| `extras: ["README.md", "CHANGELOG.md"]` only | Four guides + grouped sidebar + shipped in tarball | This phase (DOC-03) | Guides published to HexDocs and included in the Hex package |

**Deprecated/outdated (in the current README — remove or relocate):**
- "If [available in Hex](https://hex.pm/docs/publish), the package can be installed by..." — incorrect; the package IS live on Hex. Remove the hedge.
- Mermaid architecture diagram — out of date. Remove (D-03).
- Inline `mix cairnloop.gen.notifier` + Notifier/telemetry sections — relocate to `03-host-integration.md` (D-09).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mix igniter.install cairnloop` is the canonical invocation form for the installer (vs only `mix cairnloop.install`) | Pattern 1 / DOC-01 | LOW — both forms can be shown; the two-step `mix deps.get && mix cairnloop.install` is VERIFIED against the task and is a safe fallback. Planner should pick the `[VERIFIED]` two-step form if uncertain. |
| A2 | `LICENSE.md` exists with that exact casing (needed for explicit `:files` list) | Pattern 3 | MEDIUM — if the file is named `LICENSE` (no extension), an explicit `:files` entry of `LICENSE.md` silently drops it from the tarball. Planner MUST confirm casing before pinning `:files`. |
| A3 | The README's existing telemetry event names (`[:cairnloop, :conversation, :resolved]` etc.) are still emitted by current code | Code Examples / D-09 | LOW — moving existing prose; CHANGELOG confirms `[:cairnloop, ...]` namespaces exist. If a name drifted, the guide inherits the same staleness the README already had (no regression). Optional verify during planning. |

**Note:** All other claims in this research are `[VERIFIED]` against in-repo source or `[CITED]` against ExDoc/Hex official docs. The three assumptions above are the only items needing confirmation, and all have safe fallbacks.

## Open Questions

1. **Igniter installer invocation form (A1)**
   - What we know: `mix cairnloop.install` exists and works (it's `use Igniter.Mix.Task`). The two-step `mix deps.get && mix cairnloop.install` is fully verified.
   - What's unclear: whether `mix igniter.install cairnloop` (the "install before adding to deps" form) is wired for this package.
   - Recommendation: README leads with the `[VERIFIED]` two-step form from CONTEXT "Specific Ideas"; optionally mention `mix igniter.install cairnloop` as a one-liner if the planner confirms it works. Not blocking.

2. **License filename casing (A2)**
   - What we know: `package: links` references MIT; `licenses: ["MIT"]` is set.
   - What's unclear: exact on-disk filename (`LICENSE.md` vs `LICENSE`).
   - Recommendation: Planner adds a one-line check (`ls LICENSE*`) before finalizing the `:files` list. Trivial to resolve at plan time.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `ex_doc` | `mix docs` verification (DOC-03) | ✓ (dev dep, locked) | 0.40.3 | — |
| `mix` / Elixir | All `mix.exs` edits + `mix docs` / `mix hex.build` checks | ✓ | Elixir `~> 1.19` | — |
| Postgres / pgvector | **NOT required** — docs phase is DB-free | n/a | — | Repo may be unavailable per CLAUDE.md; irrelevant here |
| Browser / screenshot tooling | Real PNG capture | ✗ (and intentionally deferred) | — | Bounded `<!-- SCREENSHOTS -->` TODO block (D-01) — no fallback needed; deferred to owner |

**Missing dependencies with no fallback:** none — every verification (`mix docs` rendering, `mix hex.build` tarball contents) runs without a database.
**Missing dependencies with fallback:** screenshot tooling — handled by the deferred TODO block, not a blocker.

**Verification commands the planner should include (all DB-free):**
- `mix docs` — confirms ExDoc renders, guides appear under a "Guides" group, no `:assets` error.
- `mix hex.build` — prints the files that will ship; confirm `guides/01-quickstart.md` … `guides/04-troubleshooting.md` are listed (proves DOC-03 "visible on Hex.pm").
- `ls LICENSE* README.md CHANGELOG.md` — confirm exact filenames before pinning `:files`.

## Validation Architecture

> `workflow.nyquist_validation` is absent from `.planning/config.json` → treated as enabled. This is a documentation phase, so "tests" are render/build checks, not unit tests.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExDoc + Hex build tooling (no ExUnit tests apply to docs content) |
| Config file | `mix.exs` `docs:` and `package:` blocks |
| Quick run command | `mix docs` (renders HTML; verify "Guides" group + 4 entries) |
| Full suite command | `mix docs && mix hex.build` (render + tarball contents) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOC-01 | README leads with `mix cairnloop.install` | manual/grep | `grep -n "mix cairnloop.install" README.md` then visual review of section order | ✅ (README exists) |
| DOC-02 | Four guides exist with required content | smoke | `ls guides/01-quickstart.md guides/02-jtbd-walkthrough.md guides/03-host-integration.md guides/04-troubleshooting.md` | ❌ Wave 0 (guides/ not yet created) |
| DOC-03 | Guides render in `mix docs` AND ship in tarball | build | `mix docs` (sidebar "Guides" group) + `mix hex.build` (guides listed) | ✅ (mix.exs exists) |
| DOC-04 | CHANGELOG has vM014 entry | grep | `grep -n "Phase 32\|README rewritten" CHANGELOG.md` under `## [Unreleased]` | ✅ (CHANGELOG exists) |

### Sampling Rate
- **Per task commit:** `mix docs` (fast; no DB).
- **Per wave merge:** `mix docs && mix hex.build` + grep checks for DOC-01/DOC-04.
- **Phase gate:** `mix docs` clean (no warnings about missing extras/assets), `mix hex.build` lists all four guides, all four `guides/*.md` present, README leads with installer, CHANGELOG carries the vM014 entry.

### Wave 0 Gaps
- [ ] `guides/` directory does not exist (not tracked in git) — created when the first guide is written. No framework install needed.
- [ ] No automated content-correctness test for guide prose — correctness is by review against cited source files (this is inherent to a docs phase; no harness gap to fill).

*Note: `mix compile --warnings-as-errors` (CLAUDE.md mandate) is moot for guide Markdown but DOES apply to the `mix.exs` edit — `mix.exs` must still compile cleanly. `mix test` is not required (no Elixir source changed); the planner may run `mix compile` to confirm `mix.exs` parses.*

## Security Domain

> `security_enforcement` not set in `.planning/config.json` (absent = enabled). This is a documentation-only phase with no executable surface, no input handling, no auth, no crypto, and no new dependencies — so the ASVS attack surface is effectively nil. Included for completeness.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth code touched |
| V3 Session Management | no | No session code touched |
| V4 Access Control | no | No access-control code touched |
| V5 Input Validation | no | No runtime input; Markdown is static content |
| V6 Cryptography | no | No crypto touched |
| V1 Architecture/Docs | yes (advisory) | Ensure guides do not leak secrets, internal hostnames, or real tokens in code examples |

### Known Threat Patterns for documentation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Example code embedding a real secret/token/credential | Information Disclosure | Use obvious placeholders (`MyApp`, `your-token`) — never real values; the existing telemetry/notifier examples already use placeholders |
| Documenting an insecure default as the recommended path | Tampering (downstream) | Mirror the codebase's secure defaults — e.g. `AutomationPolicy.decide/2` examples should show `:require_approval`/HITL posture, not `:allow`, consistent with the "approval-gated only" project invariant |
| Broken/external image refs pulling untrusted content into HexDocs | (minor) | Per D-01, no image refs committed until real local PNGs exist; assets stay local |

**One concrete security-relevant guidance for the guide author:** the `AutomationPolicy` example (Code Examples §3) defaults to `:require_approval`, matching the project's "Autonomous customer-visible replies … out of scope; Approval-gated only" invariant `[VERIFIED: REQUIREMENTS.md Out of Scope]`. Do not show `:allow` as the headline example — it would document a posture the project explicitly rejects.

## Sources

### Primary (HIGH confidence)
- `lib/mix/tasks/cairnloop/install.ex` — install task: `add_dep({:cairnloop, "~> 0.1.0"})`, `select_repo`, `gen_migration("create_cairnloop_tables", on_exists: :skip)`
- `lib/cairnloop/context_provider.ex`, `notifier.ex`, `automation_policy.ex`, `sla_policy_provider.ex` — behaviour `@moduledoc` + `@callback` specs
- `lib/cairnloop/router.ex` — `cairnloop_dashboard/2` macro (mount routes)
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` + `endpoint.ex` — example mount (`/support`, `/widget` socket, `/chat`)
- `test/integration/golden_path_test.exs` — canonical 9-stage JTBD sequence (D-08 source)
- `mix.exs` — current `docs:` (no `groups_for_extras`), `package:` (no `:files`), deps, version `0.1.0`
- `CHANGELOG.md` — Keep-a-Changelog 1.0, empty `## [Unreleased]` above `## [0.1.0]`
- `README.md` — current front door (Mermaid diagram, "If available in Hex" hedge, inline telemetry/notifier)
- `docs/cairnloop-jtbd-and-user-flows.md` — 553-line JTBD prose source (D-04: keep, not exposed)
- [ExDoc — mix docs (v0.40.3)](https://hexdocs.pm/ex_doc/Mix.Tasks.Docs.html) — `:extras`, `:main` confirmed
- [mix hex.build — Hex](https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html) — default `:files` list (no `guides`)
- `mix hex.info ex_doc` (local) — locked `0.40.3`

### Secondary (MEDIUM confidence)
- [ExDoc mix docs (v0.28.2)](https://hexdocs.pm/ex_doc/0.28.2/Mix.Tasks.Docs.html) — `groups_for_extras` regex/`Path.wildcard` syntax + `:extras` `title:`/`filename:` keyword form (stable across versions)
- [ex_doc on Hex.pm](https://hex.pm/packages/ex_doc) — latest version 0.40.3
- [Mix publish package — Hex.pm](https://hex.pm/docs/publish) — package `:files` semantics

### Tertiary (LOW confidence)
- [Igniter docs](https://hexdocs.pm/igniter) — `mix igniter.install <pkg>` convention (A1 — needs per-package confirmation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new deps; all tooling versions verified against local lock + Hex
- Architecture (README/guides/mix.exs structure): HIGH — ExDoc `extras`/`groups_for_extras` and Hex `:files` default all verified against official docs; the "must add `:files`" finding is the load-bearing claim and is firmly verified
- Pitfalls: HIGH — route mismatch, license casing, and behaviour-callback drift all cross-checked against source files
- Content sources: HIGH — JTBD sequence, behaviour specs, install steps all read from in-repo authoritative files

**Research date:** 2026-05-28
**Valid until:** 2026-06-27 (stable — docs tooling and in-repo sources change slowly; re-verify ex_doc version only if a major release lands)
