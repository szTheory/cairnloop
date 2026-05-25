<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** MIT license. Create a `LICENSE` file at the repo root with the standard MIT text, copyright holder: szTheory.
- **D-02:** **Manual publish for v0.1.0.** Developer runs `mix hex.publish` locally for the initial ownership claim.
- **D-03:** **Add a CI `release.yml` job immediately after the v0.1.0 manual publish** — triggered on `push: tags: v*`, requiring a `HEX_API_KEY` GitHub Secret.
- **D-04:** The `release.yml` job must run `mix hex.publish --yes` for the package and `mix hex.publish docs --yes` for hexdocs. It should only trigger on `v*` tags, run after CI is green.
- **D-05:** Single `## [0.1.0] - YYYY-MM-DD` entry (keep-a-changelog format) in CHANGELOG.md covering vM009–vM012 with ~13 bullet points. Milestone names are omitted.
- **D-06:** Keep-a-changelog header with `[Unreleased]` section above `[0.1.0]`.
- **D-07:** CHANGELOG bullet set covering the specific 13 capabilities defined in the context.
- **D-08:** All of the following must be added to `project/0` in `mix.exs`: `:description`, `:source_url`, `:homepage_url`, `:docs` block, and `:package` block.
- **D-09:** Add `{:ex_doc, "~> 0.34", only: :dev, runtime: false}` to deps.
- **D-10:** Module groups (`:groups_for_modules`) organized by namespace: "Governance", "Knowledge Base", "Retrieval", "MCP", "Web", "Core".
- **D-11:** `main: "readme"` in `:docs`.
- **D-12:** Both existing CI jobs must be green on `origin/main` before the v0.1.0 tag is pushed.
- **D-13:** Hygiene gate from STATE.md is complete.

### the agent's Discretion
- Exact `:description` wording — keep it under 300 chars, clear, adopter-facing.
- Exact ExDoc `groups_for_modules` regex patterns — match namespace conventions visible in `lib/`.
- Whether to add a `mix hex.build --dry-run` step to the existing CI jobs or keep it in the release job only.
- Ordering of `extras` within the `:docs` block.
- Whether to add a `LICENSE` link to the `:links` map in the `:package` block.

### Deferred Ideas (OUT OF SCOPE)
- Per-milestone CHANGELOG sub-entries (vM009, vM010, vM011 as separate dated h2 headings)
- Custom ExDoc guide pages / tutorial content
- Hex trusted publishing (keyless CI via OIDC)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | CI passes on main branch (both integration and standard jobs green before tagging) | Confirmed `mix test` and `mix test.integration` existing CI setup is active and runs correctly. |
| REL-02 | CHANGELOG.md covers vM009–vM012 with dates and feature summaries | Verified keep-a-changelog format and list of 13 features from Context. |
| REL-03 | v0.1.0 semver tag created and pushed to origin | Verified `git --version` locally, standard tagging practices. |
| REL-04 | mix.exs package metadata complete: `:description`, `:package` block with `:licenses`, `:links`, `:maintainers`; `:source_url`; `:homepage_url`; `:docs` block pointing at ExDoc | Established proper `:package` and `:docs` configuration format. |
| REL-05 | Package published to hex.pm and available at hex.pm/packages/cairnloop | Verified `cairnloop` name is available on hex.pm. |
| REL-06 | ExDoc configured; API docs published to hexdocs.pm alongside the hex release | Determined ExDoc setup dependencies (`ex_doc ~> 0.34`) and module regex structure. |
</phase_requirements>

# Phase 18: Release Gate & Hex.pm Publish - Research

**Researched:** 2026-05-25
**Domain:** Elixir package release, CI/CD, documentation
**Confidence:** HIGH

## Summary

This phase focuses entirely on release-engineering: publishing Cairnloop to Hex.pm, publishing ExDoc generated documentation, formalizing the MIT License, publishing a proper Keep-A-Changelog style changelog, and automating subsequent releases through GitHub Actions CI (`release.yml`).

**Primary recommendation:** Use exactly the specifications provided in the context to populate `mix.exs` and construct the CI workflows. First release (0.1.0) must be manual from the developer machine to satisfy Hex's interactive 2FA prompt, while the GitHub action handles `v*` tags from there onwards.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Package Metadata & Docs | Core (`mix.exs`) | — | Metadata is compiled by Hex to represent the package globally. |
| Automated Publishing | Infrastructure (CI) | — | Secure, repeatable, CI-gated deployment of releases to Hex.pm. |
| Versioning & Changelog | Core (`CHANGELOG.md`) | — | Tracks breaking changes and features per keepachangelog.com standard. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ex_doc` | `~> 0.34` | Documentation generator | Official Elixir documentation tool, deeply integrated with hex.pm. |
| `hex` | `v2.4+` | Package manager | Hex.pm is the canonical Elixir package registry. |

**Version verification:** 
- ExDoc's latest is `0.40.3`, but Context D-09 enforces `~> 0.34`. We will adhere to `~> 0.34`.
- Hex.info returned `No package with name cairnloop`, confirming the package name is available for registration!

## Architecture Patterns

### mix.exs Configuration
```elixir
  def project do
    [
      app: :cairnloop,
      version: "0.1.0",
      description: "Host-owned customer support automation for Phoenix apps — governed drafting, retrieval-backed answers, and durable workflow tools.",
      # ... existing ...
      package: package(),
      docs: docs(),
      source_url: "https://github.com/szTheory/cairnloop",
      homepage_url: "https://github.com/szTheory/cairnloop"
    ]
  end

  defp package do
    [
      name: "cairnloop",
      licenses: ["MIT"],
      maintainers: ["szTheory"],
      links: %{
        "GitHub" => "https://github.com/szTheory/cairnloop",
        "Changelog" => "https://hexdocs.pm/cairnloop/changelog.html"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Governance": [~r/^Cairnloop\.Governance/, ~r/^Cairnloop\.Tool/],
        "Knowledge Base": [~r/^Cairnloop\.KnowledgeBase/, ~r/^Cairnloop\.KnowledgeAutomation/],
        "Retrieval": [~r/^Cairnloop\.Retrieval/],
        "MCP": [~r/^Cairnloop\.Web\.MCP/],
        "Web": [~r/^Cairnloop\.Web/],
        "Core": [~r/^Cairnloop\.[^.]*$/]
      ]
    ]
  end
```

### GitHub Actions Release Workflow Pattern
A dedicated `.github/workflows/release.yml` for pushing packages on tags:
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    name: Publish to Hex.pm
    runs-on: ubuntu-latest
    env:
      ACTIONS_RUNNER_NODE_VERSION: "24"
      HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19.0"
          otp-version: "27.2"
      - name: Restore Mix cache
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('mix.lock') }}
      - run: mix deps.get
      - run: mix hex.publish --yes
      - run: mix hex.publish docs --yes
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CI CD Publish | Custom bash curl to Hex API | `mix hex.publish` in GH Actions | `mix` manages Hex 2FA tokens properly and bundles metadata smoothly. |
| Changelog Format | Custom ad-hoc markdown | Keep a Changelog | Adopter expectation in Elixir community is `keepachangelog.com` format. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Hex publish tasks | ✓ | 1.19.5 | — |
| Git | Tagging `v0.1.0` | ✓ | 2.41.0 | — |
| Hex Package | `cairnloop` on hex.pm | ✓ | Unclaimed | — |

## Common Pitfalls

### Pitfall 1: Interactive 2FA on first Hex publish blocking CI
**What goes wrong:** Adding `mix hex.publish` to a GitHub action for the first release fails because the user hasn't claimed the package, which requires an interactive 2FA challenge on Hex v2.4+.
**How to avoid:** Execute manual local publish first for `v0.1.0`, then set up GitHub Secrets (`HEX_API_KEY`) for `v*` automation moving forward.

### Pitfall 2: Forgetting to add CHANGELOG.md to ExDoc extras
**What goes wrong:** The changelog isn't included in hexdocs sidebar.
**How to avoid:** Ensure `:extras` inside the `docs: docs()` block in `mix.exs` contains `"CHANGELOG.md"`.

## Sources
### Primary (HIGH confidence)
- `18-CONTEXT.md` - Verified specific `mix.exs` options and formatting requirements.
- `mix hex.info cairnloop` - Confirmed package name is unclaimed in the public registry.
- `keepachangelog.com` standard formatting (referenced by context D-06).

## Metadata
**Confidence breakdown:**
- Standard stack: HIGH - Dictated fully by Elixir/Hex documentation and context.
- Architecture: HIGH - Basic CI pipeline mirroring existing CI setup.
- Pitfalls: HIGH - Documented Hex v2.4 2FA restrictions accurately reflect latest Hex registry updates.

**Research date:** 2026-05-25
**Valid until:** Stable
