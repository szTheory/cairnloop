# Phase 18: Release Gate & Hex.pm Publish - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase makes Cairnloop publicly discoverable, installable, and documented on hex.pm. It covers: CI validation (both jobs green before tagging), CHANGELOG authorship, LICENSE creation, hex.pm package metadata in mix.exs, ExDoc configuration, the v0.1.0 semver tag, a manual first hex.pm publish (developer-run), and a CI release job wired up for all future releases. It does NOT build the example app (Phase 19), add MCP OAuth (Phase 20), or implement MCP write tools (Phase 21). No new Elixir feature code is introduced — this is entirely a release-engineering and documentation phase.

</domain>

<decisions>
## Implementation Decisions

### License
- **D-01:** MIT license. Create a `LICENSE` file at the repo root with the standard MIT text, copyright holder: szTheory. No LICENSE file exists today. MIT is the Elixir ecosystem standard (Phoenix, Ecto, Oban all use MIT) and appropriate for this stage.

### Hex.pm Publish Workflow
- **D-02:** **Manual publish for v0.1.0.** Developer runs `mix hex.publish` locally for the initial ownership claim. This satisfies the Hex v2.4 interactive 2FA requirement with zero CI plumbing risk on the first release. Hex v2.4 mandates interactive 2FA for key generation regardless — neither option is keyless from CI on first publish.
- **D-03:** **Add a CI `release.yml` job immediately after the v0.1.0 manual publish** — triggered on `push: tags: v*`, requiring a `HEX_API_KEY` GitHub Secret. This job handles all subsequent releases automatically. Phase 18 delivers this job as part of its scope so it's wired and ready before Phase 19 starts.
- **D-04:** The `release.yml` job must run `mix hex.publish --yes` for the package and `mix hex.publish docs --yes` for hexdocs. It should only trigger on `v*` tags (not all tags), run after CI is green, and include `if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')`.

### CHANGELOG
- **D-05:** Single `## [0.1.0] - YYYY-MM-DD` entry (keep-a-changelog format). All four pre-release milestones (vM009–vM012) fold into one consolidated "Added" section with ~13 adopter-facing capability bullets. Milestone names (vM009, vM010, vM011) are internal scaffolding — they carry zero meaning on hex.pm and are omitted as sub-headings. Milestone-dated sub-entries would also create a logical contradiction (those dates precede the v0.1.0 publish date).
- **D-06:** Keep-a-changelog header with `[Unreleased]` section above `[0.1.0]` so the format is correct for future releases. Reference: `https://keepachangelog.com`.
- **D-07:** CHANGELOG bullet set (executor will finalize wording but must cover all capabilities):
  - Host-owned hybrid retrieval corpus (pgvector + PG full-text) via `Cairnloop.Retrieval`
  - Operator search with trust, recency, and citation cues
  - Citation-backed grounded drafting with clarification and escalation states
  - Durable gap-event storage and ranked KB gaps dashboard
  - AI-prepared KB draft/revision suggestions with stale-revision gating and citation validation
  - Review-gated KB update workflow: approve, reject, defer, publish — with append-only task event history
  - In-thread quick-fix KB maintenance launched from live support conversations
  - Host-owned governed-action contract: compile-time `use Cairnloop.Tool` with risk tiers and deny-by-default `authorize/2`
  - Durable `ToolProposal` + `ToolActionEvent` records with Stripe-style idempotency
  - Approval state machine with Oban-backed resume, expiry, and deferral paths
  - Three-layer at-most-once execution: Oban unique + terminal guard + SHA-256 per-attempt run key
  - Bounded `[:cairnloop, :retrieval, …]` and `Cairnloop.Governance.Telemetry` event namespaces
  - Read-only MCP seam (`tools/list`, `initialize`) via optional `Cairnloop.Web.MCP.Router` Plug

### mix.exs Package Metadata (REL-04)
- **D-08:** All of the following must be added to the `project/0` return in `mix.exs`:
  - `:description` — one-sentence description of Cairnloop (e.g., "Host-owned customer support automation for Phoenix apps — governed drafting, retrieval-backed answers, and durable workflow tools.")
  - `:source_url` — `"https://github.com/szTheory/cairnloop"`
  - `:homepage_url` — `"https://github.com/szTheory/cairnloop"`
  - `:docs` block — `[main: "readme", extras: ["README.md", "CHANGELOG.md"]]`
  - `:package` block — `[name: "cairnloop", licenses: ["MIT"], links: %{"GitHub" => "https://github.com/szTheory/cairnloop", "Changelog" => "https://hexdocs.pm/cairnloop/changelog.html"}, maintainers: ["szTheory"]]`
- **D-09:** Add `{:ex_doc, "~> 0.34", only: :dev, runtime: false}` to deps. ExDoc is not currently present in mix.exs.

### ExDoc Configuration
- **D-10:** Module groups (`:groups_for_modules`) organized by namespace — no custom guide pages for v0.1.0 (too early for a tutorial structure). Groups:
  - `"Governance"` → modules matching `Cairnloop.Governance*`, `Cairnloop.Tool*`
  - `"Knowledge Base"` → modules matching `Cairnloop.KnowledgeBase*`, `Cairnloop.KnowledgeAutomation*`
  - `"Retrieval"` → modules matching `Cairnloop.Retrieval*`
  - `"MCP"` → modules matching `Cairnloop.Web.MCP*`
  - `"Web"` → remaining `Cairnloop.Web*` modules
  - `"Core"` → everything else
- **D-11:** `main: "readme"` — README.md serves as the hexdocs landing page. CHANGELOG.md also included as an extra so it appears in the sidebar.

### CI Release Gate (REL-01)
- **D-12:** Both existing CI jobs (`phase-12-shift-left` and `integration`) must be green on `origin/main` before the v0.1.0 tag is pushed. The executor must verify this (not assume). If either fails, the failure must be investigated and fixed before proceeding to tag and publish.
- **D-13:** The hygiene gate from STATE.md is considered complete (Node.js 24 already applied in ci.yml). No additional hygiene work is needed before tagging.

### Claude's Discretion
- Exact `:description` wording — keep it under 300 chars, clear, adopter-facing.
- Exact ExDoc `groups_for_modules` regex patterns — match namespace conventions visible in `lib/`.
- Whether to add a `mix hex.build --dry-run` step to the existing CI jobs or keep it in the release job only.
- Ordering of `extras` within the `:docs` block.
- Whether to add a `LICENSE` link to the `:links` map in the `:package` block.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone scope and requirements
- `.planning/ROADMAP.md` — Phase 18 goal, success criteria, REL-01–REL-06 requirements, and constraint note ("Do NOT start Phase 19, 20, or 21 before this phase closes")
- `.planning/REQUIREMENTS.md` — REL-01–REL-06 acceptance criteria and traceability table
- `.planning/PROJECT.md` — Current milestone posture and vM012 goal
- `.planning/STATE.md` — Hygiene gate status (completed), release gate checklist, carried decisions, and hard June 2, 2026 CI deadline

### Existing configuration files (read before modifying)
- `mix.exs` — Current package definition: version "0.1.0" set; `:description`, `:package`, `:source_url`, `:homepage_url`, `:docs` block ALL MISSING — must be added for REL-04
- `.github/workflows/ci.yml` — Existing two-job CI (Node.js 24 already applied); a third `release` job must be added triggered on `push: tags: v*`

### Hex.pm publish reference (external)
- `https://hex.pm/docs/publish` — Hex.pm publish guide (steps: `mix hex.user register`, `mix hex.publish`)
- `https://hexdocs.pm/ex_doc/` — ExDoc configuration reference

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mix.exs` `project/0`: Add metadata fields directly here — no separate config module needed.
- `.github/workflows/ci.yml`: The `release.yml` job should mirror the existing job structure (checkout@v4, setup-beam@v1, cache@v4, deps.get) then add `mix hex.publish --yes` and `mix hex.publish docs --yes`.

### Established Patterns
- CI already uses `ACTIONS_RUNNER_NODE_VERSION: "24"` env — the release job inherits this from the top-level `env:` block (no need to re-declare).
- `erlef/setup-beam@v1` with `elixir-version: "1.19.0"` + `otp-version: "27.2"` is the pinned version — use the same in the release job.
- `actions/cache@v4` with `deps/_build` keyed on `mix.lock` hash — same cache key pattern in the release job avoids redundant compilation.

### Integration Points
- `LICENSE` file goes at repo root (adjacent to `mix.exs`, `README.md`).
- `CHANGELOG.md` goes at repo root — referenced in `:extras` in the `:docs` block of `mix.exs`.
- ExDoc `:groups_for_modules` is specified inside the `:docs` block in `mix.exs` (not a separate config file).
- The `release.yml` job needs the `HEX_API_KEY` secret: `env: HEX_API_KEY: ${{ secrets.HEX_API_KEY }}`. Executor notes this in the plan so the developer knows to add the GitHub Secret before the job can run.

</code_context>

<specifics>
## Specific Ideas

- **Two-step publish** (from discussion): v0.1.0 is manually published by the developer (`mix hex.publish`), then the `release.yml` CI job is wired immediately after so all subsequent releases are automated. This is explicitly the chosen workflow — executor must not add `mix hex.publish` to the CI job that runs on v0.1.0 itself; the CI job is for future tags.
- **Hex v2.4 2FA caveat**: Developer will need to go through the interactive OAuth + 2FA flow when generating the API key for the CI secret (`mix hex.user key generate`). This is a manual one-time step documented in the plan.
- **Package availability check**: Before publishing, run `mix hex.info cairnloop` to confirm the package name is unclaimed. If it is claimed, stop and surface to owner immediately (this would be a very-impactful blocker).

</specifics>

<deferred>
## Deferred Ideas

- Per-milestone CHANGELOG sub-entries (vM009, vM010, vM011 as separate dated h2 headings) — non-standard, exposes internal scaffolding to adopters; internal milestone narratives live in `.planning/milestones/`
- Custom ExDoc guide pages / tutorial content — premature at v0.1.0; add in a later phase if adoption signals warrant it
- Hex trusted publishing (keyless CI via OIDC) — planned by the Hex team but not yet shipped as of 2025; revisit when available

</deferred>

---

*Phase: 18-Release Gate & Hex.pm Publish*
*Context gathered: 2026-05-25*
