# Phase 18: Release Gate & Hex.pm Publish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 18-release-gate-hex-pm-publish
**Areas discussed:** Hex.pm publish method, CHANGELOG scope (license auto-decided by user as MIT)

---

## License

| Option | Description | Selected |
|--------|-------------|----------|
| MIT | Standard Elixir ecosystem license (Phoenix, Ecto, Oban); simpler | ✓ |
| Apache-2.0 | Adds patent clause; occasionally preferred for commercial projects | |

**User's choice:** MIT (stated directly in area selection response: "license MIT")
**Notes:** No LICENSE file exists today. User confirmed MIT without needing a full discussion — treated as auto-decided.

---

## Hex.pm Publish Method

| Option | Description | Selected |
|--------|-------------|----------|
| Manual v0.1.0, CI after | Run `mix hex.publish` locally for ownership claim; add `release.yml` CI job immediately after for future releases | ✓ |
| CI-automated from day one | Add `HEX_API_KEY` GitHub Secret + GitHub Actions release workflow now; still requires interactive 2FA for key generation | |

**User's choice:** Manual v0.1.0, CI after (Recommended)
**Notes:** Hex v2.4 mandates interactive 2FA for write-key generation regardless of approach. Manual for v0.1.0 avoids secrets management at the highest-risk moment; CI release job ships immediately after for all subsequent releases.

---

## CHANGELOG Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single v0.1.0 entry with full bullets | One `## [0.1.0]` heading, ~13 adopter-facing "Added" bullets covering all milestones. Ecosystem standard. | ✓ |
| Per-milestone sub-entries | Separate dated sub-entries for vM009–vM012 under v0.1.0 umbrella; non-standard; exposes internal milestone names | |

**User's choice:** Single v0.1.0 entry with full bullets (Recommended)
**Notes:** Research confirmed 100% of observed Elixir library first releases used a single consolidated entry. Milestone dates (2026-05-21, 2026-05-23) also predate the v0.1.0 publish date, making per-milestone sub-entries logically contradictory.

---

## Claude's Discretion

- ExDoc module groupings (Governance, MCP, KnowledgeBase, Core, Web) — auto-decided based on lib/ namespace conventions
- ExDoc `:extras` structure (README.md as main, CHANGELOG.md as extra) — standard ExDoc pattern
- mix.exs `:description` wording — operator-facing single sentence, under 300 chars
- Maintainer info: szTheory / qiksnare13@gmail.com — inferred from git remote + session context
- Source URL and homepage_url: https://github.com/szTheory/cairnloop — inferred from git remote

## Deferred Ideas

- Per-milestone CHANGELOG sub-entries — non-standard; internal milestone detail lives in `.planning/milestones/`
- Custom ExDoc guide pages / tutorial content — premature at v0.1.0; revisit on adoption signals
- Hex trusted publishing (keyless CI via OIDC) — planned by Hex team but not yet shipped as of 2025
