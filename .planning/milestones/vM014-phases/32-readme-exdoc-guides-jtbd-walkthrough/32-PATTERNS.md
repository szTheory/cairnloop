# Phase 32: README + ExDoc Guides + JTBD Walkthrough - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 7 (4 new guides, 3 modified config/docs)
**Analogs found:** 7 / 7 (all matched — this is a docs phase; "analogs" are content/format sources, not code analogs)

> **Phase nature:** Documentation-only. No Elixir source code is created. The only compiled file
> edited is `mix.exs` (config keys, not code paths). "Patterns" here are *content sources* and
> *format conventions* the new Markdown/config must copy from, plus verbatim `@callback`/`@moduledoc`
> facts the guides must mirror exactly. The failure mode is plausible-but-wrong prose — every code
> snippet, route, version pin, and config key has an authoritative in-repo source cited below.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `README.md` (modify) | doc / front-door | transform (restructure) | current `README.md` + `examples/cairnloop_example/README.md` | exact (self-restructure) |
| `guides/01-quickstart.md` (new) | doc / quickstart | transform | `examples/cairnloop_example/README.md` + `lib/mix/tasks/cairnloop/install.ex` | role-match |
| `guides/02-jtbd-walkthrough.md` (new) | doc / walkthrough | transform | `test/integration/golden_path_test.exs` + `docs/cairnloop-jtbd-and-user-flows.md` | exact (stage sequence) |
| `guides/03-host-integration.md` (new) | doc / integration ref | transform | 4 behaviour `@moduledoc`s + current `README.md` telemetry block | exact (verbatim `@callback`s) |
| `guides/04-troubleshooting.md` (new) | doc / troubleshooting | transform | `lib/mix/tasks/cairnloop/install.ex` + `mix.exs` `test.setup` alias + `examples/.../README.md` | role-match |
| `mix.exs` `docs:` block (modify) | config | config | current `mix.exs` `docs:` (lines 26-37) | exact (extend in place) |
| `mix.exs` `package:` block (modify) | config | config | current `mix.exs` `package:` (lines 17-25) | exact (extend in place) |
| `CHANGELOG.md` (modify) | doc / changelog | transform | current `CHANGELOG.md` `## [0.1.0]` block (lines 10-26) | exact (mirror format) |

## Pattern Assignments

### `mix.exs` `docs:` block (config) — VERIFIED line numbers

**Analog / source:** `/Users/jon/projects/cairnloop/mix.exs` lines 26-37 (the existing `docs:` block).
**Rule:** EXTEND in place — never rewrite. Preserve `main: "readme"` and the entire `groups_for_modules:`
list (6 module groups). Only `extras:` changes, and two keys are added (`groups_for_extras:` and a
commented `# assets:` line).

**Current state (lines 26-37) — what you are editing:**
```elixir
docs: [
  main: "readme",
  extras: ["README.md", "CHANGELOG.md"],
  groups_for_modules: [
    Governance: [~r/^Cairnloop\.Governance/, ~r/^Cairnloop\.Tool/],
    "Knowledge Base": [~r/^Cairnloop\.KnowledgeBase/, ~r/^Cairnloop\.KnowledgeAutomation/],
    Retrieval: [~r/^Cairnloop\.Retrieval/],
    MCP: [~r/^Cairnloop\.Web\.MCP/],
    Web: [~r/^Cairnloop\.Web/],
    Core: [~r/^Cairnloop/]
  ]
]
```

**Pattern to copy (target shape — guides before README, `groups_for_extras` + commented `:assets`):**
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
    # ... existing 6 groups UNCHANGED ...
  ]
]
```
**Notes for planner:** The `{"path", title: "..."}` tuple form is Claude's-discretion-recommended
(D-05 plain-string form is equally valid). `~r/^guides\//` matches both tuple and bare-string forms
(Pitfall 6). Keep `:assets` commented — uncommenting it without `guides/assets/` makes `mix docs`
raise (Pitfall 3).

---

### `mix.exs` `package:` block (config) — CRITICAL + CORRECTION

**Analog / source:** `/Users/jon/projects/cairnloop/mix.exs` lines 17-25 (existing `package:` block).
**Rule:** ADD a `:files` key. Do NOT remove `name`, `licenses`, `links`, or `maintainers`.

**Current state (lines 17-25) — NO `:files` key:**
```elixir
package: [
  name: "cairnloop",
  licenses: ["MIT"],
  links: %{
    "GitHub" => "https://github.com/szTheory/cairnloop",
    "Changelog" => "https://hexdocs.pm/cairnloop/changelog.html"
  },
  maintainers: ["szTheory"]
],
```

**Pattern to copy — add `:files` listing `guides`:**
```elixir
package: [
  name: "cairnloop",
  files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md),
  licenses: ["MIT"],
  links: %{
    "GitHub" => "https://github.com/szTheory/cairnloop",
    "Changelog" => "https://hexdocs.pm/cairnloop/changelog.html"
  },
  maintainers: ["szTheory"]
],
```

> **⚠️ CORRECTION TO CONTEXT/RESEARCH — license filename casing (resolves Assumption A2):**
> CONTEXT D-05 and RESEARCH Pattern 3 propose `~w(lib priv guides mix.exs README.md LICENSE.md CHANGELOG.md)`.
> The on-disk license file is **`LICENSE`** (no extension) — `[VERIFIED: ls LICENSE* → "LICENSE"]`,
> NOT `LICENSE.md`. An explicit `:files` list is an exact match (no glob), so listing `LICENSE.md`
> would **silently drop the license from the published Hex tarball**. The planner MUST use `LICENSE`
> (no extension). This was the MEDIUM-risk item flagged in RESEARCH A2; it is now resolved.

**Why this is the load-bearing edit (Pitfall 2):** Hex's default `:files` does NOT include `guides`.
Without this key, `mix docs` renders guides locally but `mix hex.publish` omits them from the tarball
— so they never reach HexDocs. `[VERIFIED: hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]`

---

### `CHANGELOG.md` (doc / changelog, transform)

**Analog / source:** `/Users/jon/projects/cairnloop/CHANGELOG.md` — Keep-a-Changelog 1.0 header (lines 1-6),
empty `## [Unreleased]` (line 8), and the `## [0.1.0] - 2026-05-25` `### Added` block (lines 10-26) as
the format exemplar.

**Format pattern to copy (from the existing `## [0.1.0]` block, lines 10-26):**
```markdown
## [0.1.0] - 2026-05-25

### Added
- Host-owned hybrid retrieval corpus (pgvector + PG full-text) via `Cairnloop.Retrieval`
- ...
```
- `## [X]` section header, `### Added` subsection, `- ` bullets, backtick-wrapped module/path names.

**Edit pattern:** Populate the EXISTING empty `## [Unreleased]` (line 8) — do not insert a new header
above it; it already sits above `## [0.1.0]`. Use the verbatim vM014 bullet text supplied in CONTEXT
D-06 (7 bullets, Phases 27-32). Keep `### Added` subsection style consistent with the `[0.1.0]` block.

---

### `README.md` (doc / front-door, transform — full restructure D-03)

**Analog / source A (self):** current `/Users/jon/projects/cairnloop/README.md` — keep badges
(lines 3-5), reuse the tagline prose (lines 7-9), trim the "Why Cairnloop?" bullets (lines 13-18).
**Analog / source B (relocate FROM):** the telemetry + Notifier sections (lines 50-137) — these MOVE
to `guides/03-host-integration.md` (D-09); do not keep them in README.
**Analog / source C (install steps):** `lib/mix/tasks/cairnloop/install.ex` — the install task is the
source of truth for the install one-liner and version pin.

**Keep verbatim — badges block (README lines 3-5):**
```markdown
[![Hex.pm Version](https://img.shields.io/hexpm/v/cairnloop.svg)](https://hex.pm/packages/cairnloop)
[![HexDocs](https://img.shields.io/badge/hexdocs-online-blue.svg)](https://hexdocs.pm/cairnloop)
[![GitHub Actions CI](https://github.com/szTheory/cairnloop/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/cairnloop/actions)
```

**REMOVE — the "If [available in Hex]" hedge (README lines 38-46) and the Mermaid diagram (lines 24-34).**
Both are stale/incorrect (package is live on Hex; diagram predates outbound lane + governed tools + MCP).

**Install-section pattern to copy (lead with the installer; from RESEARCH Pattern 1, version pin
VERIFIED against `install.ex` line 16):**
````markdown
## Installation

Cairnloop ships an [Igniter](https://hexdocs.pm/igniter) installer. If Cairnloop is
already in your deps, run it directly:

```bash
mix deps.get
mix cairnloop.install
```

The installer adds `{:cairnloop, "~> 0.1.0"}` to `mix.exs` and generates a
`create_cairnloop_tables` migration against your detected Ecto repo.

### Manual install (without Igniter)

```elixir
def deps do
  [
    {:cairnloop, "~> 0.1.0"}
  ]
end
```
````
**Version pin is load-bearing (Pitfall 5):** use `{:cairnloop, "~> 0.1.0"}` — matches
`Igniter.Project.Deps.add_dep({:cairnloop, "~> 0.1.0"})` `[VERIFIED: install.ex line 16]` and
`version: "0.1.0"` `[VERIFIED: mix.exs line 7]`. Do NOT guess a different version.

**"Explore the guides" links pattern (point at HexDocs extra slugs):**
```markdown
## Explore the guides

- [Quickstart](https://hexdocs.pm/cairnloop/01-quickstart.html)
- [JTBD Walkthrough](https://hexdocs.pm/cairnloop/02-jtbd-walkthrough.html)
- [Host Integration](https://hexdocs.pm/cairnloop/03-host-integration.html)
- [Troubleshooting](https://hexdocs.pm/cairnloop/04-troubleshooting.html)
```
(ExDoc derives the `.html` slug from the extra's filename, prefix included.)

---

### `guides/01-quickstart.md` (new, doc / quickstart)

**Analog / source A:** `/Users/jon/projects/cairnloop/examples/cairnloop_example/README.md` —
clone-to-boot steps + the dashboard mount snippet.
**Analog / source B:** `lib/mix/tasks/cairnloop/install.ex` — what `mix cairnloop.install` actually does.
**Analog / source C:** `lib/cairnloop/router.ex` — the `cairnloop_dashboard/2` macro (mount routes).

**Setup-steps pattern to copy (example README lines 18-31):**
```bash
# Make sure your database has pgvector installed.
mix setup
mix phx.server
```

**Mount pattern to copy (example README lines 59-66 — this is the authoritative dashboard wiring):**
```elixir
import Cairnloop.Router, only: [cairnloop_dashboard: 2]

scope "/support", CairnloopExampleWeb do
  pipe_through :browser

  cairnloop_dashboard("/", host_user_id: "demo_operator")
end
```

> **⚠️ Route convention (Pitfall 1 — applies to 01-quickstart AND 02-jtbd-walkthrough):**
> The macro mounts inbox at `<path>/` and conversation at `<path>/:id`
> `[VERIFIED: lib/cairnloop/router.ex lines 10, 22]`. With `scope "/support"`, the inbox is
> **`/support`** and a conversation is **`/support/:id`** `[VERIFIED: example router + README]`.
> Use `/support` and `/support/:id` in adopter guides. NEVER use the test's `/inbox` or
> `/governance/:id` — those are integration-test-host routes, not shipped routes.

---

### `guides/02-jtbd-walkthrough.md` (new, doc / walkthrough) — stage sequence is EXACT

**Analog / source A (canonical stage order — D-08):** `/Users/jon/projects/cairnloop/test/integration/golden_path_test.exs`.
The `# Stage N:` comments define the locked sequence; copy stage *names and order* from here.
**Analog / source B (prose tone + flow depth):** `docs/cairnloop-jtbd-and-user-flows.md` (553-line memo,
internal — D-04: NOT exposed in ExDoc; use only as a prose source).

**Stage sequence to copy verbatim (from golden_path_test.exs `@moduledoc` lines 6-15 and inline
`# Stage N:` comments):**
```
1. Seed (conversation + customer message)            — golden_path_test.exs Stage 1 (lines 137-152)
2. Inbox sees the conversation                       — Stage 2 (lines 154-158)
3. ConversationLive + cmd+k search + citation chip   — Stage 3 (lines 160-201)
4. Approve AI draft                                   — Stage 4 (lines 203-226)
5. Tool proposal approve (via Governance facade)      — Stage 5 (lines 228-249)
6. ToolExecutionWorker :success                       — Stage 6 (lines 251-268)
7. Resolve                                            — Stage 7 (lines 270-276)
8. Outbound.trigger/2 from sidebar                    — Stage 8 (lines 278-308)
9. Bulk recovery (multi-select → confirm_bulk_send)   — Stage 9 (lines 310-346)
```
**Screen-region description style (per D-01) example:** "The inbox shows 12-16 conversations across all
status states — new (blue), open, awaiting customer, resolved." Prose + code references only; NO PNG
references committed.

**Bounded screenshot TODO block to copy verbatim at the END of the guide (D-01):**
```
<!-- SCREENSHOTS: boot the example app (`cd examples/cairnloop_example && mix setup && mix phx.server`),
     navigate each JTBD stage, capture PNGs to guides/assets/, update the image references above.
     See guides/02-jtbd-walkthrough.md for the labeled regions. -->
```
> **Use the test ONLY for stage sequence + behaviour/event names — NOT for routes.** The test drives
> `/inbox` and `/governance/:id`; the guide must use `/support` and `/support/:id` (Pitfall 1).

---

### `guides/03-host-integration.md` (new, doc / integration ref) — `@callback`s are EXACT

**Analog / source (verbatim contracts):** the four behaviour modules. Copy `@moduledoc` prose and
the FULL current `@callback` set from each — do NOT copy the README's stale 2-callback Notifier
subset (Pitfall 4). Document behaviours in adopter-implementation order (D-09):

**1. `Cairnloop.ContextProvider`** — `[VERIFIED: lib/cairnloop/context_provider.ex lines 34-35]`
```elixir
@callback get_context(actor_id :: String.t(), opts :: keyword()) ::
            {:ok, map()} | {:error, term()}
```
Prose to carry (moduledoc lines 9-24): returned map is recursively rendered as categorized UI sections
("Zero-Config UI"); return `{:ok, map}`/`{:error, term}` — never raise — so the dashboard degrades to
"Context Unavailable" rather than crashing.

**2. `Cairnloop.Notifier`** — THREE callbacks `[VERIFIED: lib/cairnloop/notifier.ex lines 10, 15-16, 21-22]`
```elixir
@callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()
@callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) ::
            :ok | {:error, term()} | any()
@callback on_outbound_triggered(message :: struct(), conversation :: struct()) ::
            :ok | {:error, term()} | any()
```
> **Pitfall 4 — do NOT inherit the README's stale example.** Current README (lines 110-131) shows only
> `on_conversation_resolved/2` + `on_sla_breach/3`. The behaviour ALSO defines `on_outbound_triggered/2`.
> The guide must document all THREE. Mention the generator escape hatch `mix cairnloop.gen.notifier`
> (README line 102) which scaffolds the module and injects `config :cairnloop, :notifier, MyApp...`.

**3. `Cairnloop.AutomationPolicy`** — `[VERIFIED: lib/cairnloop/automation_policy.ex lines 11-12]`
```elixir
@callback decide(proposal :: map(), opts :: map()) ::
            :allow | :draft_only | :require_approval | :deny
```
> **Security (RESEARCH Security Domain):** the headline example MUST default to `:require_approval`,
> NOT `:allow` — matching the project's "approval-gated only / HITL by default" invariant. Do not
> document `:allow` as the recommended posture.

**4. `Cairnloop.SLAPolicyProvider`** — `[VERIFIED: lib/cairnloop/sla_policy_provider.ex lines 12, 17]`
```elixir
@callback get_active_policies() :: {:ok, list(map())} | {:error, term()}
@callback set_policy(priority :: atom(), attrs :: map()) :: {:ok, map()} | {:error, term()}
```

**Telemetry section to MOVE here (from README lines 54-94 — D-09):** the dual-emission prose +
`[:cairnloop, :conversation, :resolve, :stop]` span example and `[:cairnloop, :conversation, :resolved]`
domain-event example. Becomes a "Telemetry (observability only)" subsection. Per arch posture:
telemetry is observability only, never a UI/display source.

---

### `guides/04-troubleshooting.md` (new, doc / troubleshooting) — D-10 coverage

**Analog / source A (install prerequisites):** `lib/mix/tasks/cairnloop/install.ex` — the
"No Ecto repo found" issue path (lines 19-23) is a real, documented failure mode; the migration
body (lines 30-53) shows what tables get created.
**Analog / source B (migration order):** `mix.exs` `test.setup` alias (lines 64-67) + the comment
block (lines 56-63) — host-owned tables (`20260101…`) must precede library migrations so FKs to
`cairnloop_conversations` resolve.
**Analog / source C (pgvector + mount config):** `examples/cairnloop_example/README.md` lines 9-13
(pgvector requirement) and lines 47-52 (required integrations: ContextProvider/Notifier config).

**Required topics to cover (D-10), each grounded in the cited source:**
- `mix cairnloop.install` prerequisites: Igniter dep present; Ecto repo detection (the install task
  emits "No Ecto repo found. Please create a migration manually..." when `select_repo` returns nil —
  `[VERIFIED: install.ex lines 19-23]`).
- Migration order: host tables before library tables (`test.setup` alias, mix.exs lines 64-67 + comment).
- pgvector extension requirement (example README "Postgres 16+ with pgvector").
- Common mount errors: missing `:context_provider` / `:notifier` config (the golden-path test wires
  `Application.put_env(:cairnloop, :context_provider, ...)` — test lines 100-103 show the required keys).
- `ChunkRevision` Oban worker timing: embeddings are async (enqueued), not instant after seed.

## Shared Patterns

### Brand voice / copy register (applies to ALL four guides + README prose)
**Source:** `prompts/cairnloop_brand_book.md` (per CLAUDE.md + CONTEXT canonical_refs). Calm,
reason-forward, honest. Never raw Elixir terms / raw JSON to operators (humanize). Brand tokens over
hardcoded hex. Guides are adopter-facing developer docs, so code is expected — but operator-facing
*UI copy quoted in the guides* should match the calm register.

### Version pin consistency (applies to README + 01-quickstart)
**Source:** `lib/mix/tasks/cairnloop/install.ex` line 16 + `mix.exs` line 7. Always `{:cairnloop, "~> 0.1.0"}`.
A single drifted version pin across README/quickstart is the Pitfall 5 failure.

### Route convention (applies to README, 01-quickstart, 02-jtbd-walkthrough)
**Source:** `lib/cairnloop/router.ex` (macro) + `examples/cairnloop_example/lib/cairnloop_example_web/router.ex`.
Use `/support` (inbox) and `/support/:id` (conversation). NEVER the test routes `/inbox`, `/governance/:id`.

### Keep-a-Changelog format (applies to CHANGELOG)
**Source:** `CHANGELOG.md` header (lines 1-6) + `[0.1.0]` block (lines 10-26). `### Added` subsections,
backtick-wrapped identifiers, populate the existing `## [Unreleased]`.

### Verification commands (DB-free — applies after the mix.exs edit; for planner's test tasks)
**Source:** RESEARCH Validation Architecture.
- `mix docs` — guides render under a "Guides" sidebar group; no `:assets` error.
- `mix hex.build` — confirm `guides/01-quickstart.md` … `guides/04-troubleshooting.md` AND `LICENSE`
  appear in the listed files (proves DOC-03 + license-casing fix).
- `grep -n "mix cairnloop.install" README.md` — DOC-01.
- `grep -n "Phase 32\|README rewritten" CHANGELOG.md` — DOC-04.
- `mix compile --warnings-as-errors` — the `mix.exs` edit must still compile clean (CLAUDE.md mandate;
  applies to `mix.exs`, moot for Markdown).

## No Analog Found

None. Every file has an authoritative in-repo source. This is a documentation phase; there are no
"missing pattern" gaps requiring RESEARCH.md fallback — all content sources exist in the repo.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | — | — | All 7 files map to existing in-repo sources. |

## Corrections to Upstream Inputs (for planner attention)

1. **License filename (Assumption A2 RESOLVED):** `:files` must list `LICENSE` (no extension), NOT
   `LICENSE.md` as written in CONTEXT D-05 / RESEARCH Pattern 3. `[VERIFIED: ls LICENSE* → LICENSE]`.
   Using `LICENSE.md` silently drops the license from the published tarball.

2. **`## [Unreleased]` already exists** (CHANGELOG line 8, currently empty). Populate it in place;
   do not insert a new header above `## [0.1.0]` — D-06's "above [0.1.0]" intent is already satisfied
   by the existing structure.

## Metadata

**Analog search scope:** repo root (`README.md`, `CHANGELOG.md`, `mix.exs`, `LICENSE`),
`lib/cairnloop/` (4 behaviour modules + router), `lib/mix/tasks/cairnloop/install.ex`,
`test/integration/golden_path_test.exs`, `examples/cairnloop_example/`.
**Files scanned:** 11 (README, CHANGELOG, mix.exs, LICENSE listing, install.ex, 4 behaviours, router.ex, golden_path_test.exs, example README).
**Skills checked:** `.claude/skills` and `.agents/skills` — neither exists; no skill rules loaded.
**Pattern extraction date:** 2026-05-28
