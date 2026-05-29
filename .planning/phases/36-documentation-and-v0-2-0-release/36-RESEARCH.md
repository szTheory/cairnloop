<user_constraints>
## User Constraints (from CONTEXT.md)

*(No CONTEXT.md present, applying general GEMINI.md project mandates: deep architectural synthesis, idiomatic Elixir/Phoenix patterns, clear UX/DX)*
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | ExDoc `guides/05-mcp-clients.md` is authored, explaining how to connect and use MCP clients. | Verified `Cairnloop.Web.MCP.Router` and token management via `SettingsLive`. Clients authenticate using Bearer tokens against the `/mcp` route. |
| DOC-02 | ExDoc `guides/06-extending.md` is authored, covering custom adapters and extensions. | Mapped all `@callback` extension points (Tool, ContextProvider, Notifier, AutomationPolicy, SLAPolicyProvider, Embedder, Auditor). |
| DOC-03 | Root `CONTRIBUTING.md` is added to guide external maintainers/adopters. | Identified Elixir ecosystem standard setup (`mix test.setup` for host DB, `mix test.integration` for full suite). |
| DOC-04 | `docs/architecture.md` is authored for adopters needing deeper internals. | Verified existing `.planning/research/ARCHITECTURE.md` can be adapted to public-facing documentation. |
| REL-01 | `CHANGELOG.md` is updated with a summary of the vM015 surface area. | Verified vM015 feature set (Phases 33-35: Security Closure, Settings, Audit/Ops) from `.planning/milestones/vM015-ROADMAP.md`. |
| REL-02 | The v0.2.0 tag is cut and pushed, triggering the release workflow. | Confirmed `.github/workflows/release.yml` triggers on `v*` tags from prior phase (Phase 18). |
</phase_requirements>

# Phase 36: Documentation & v0.2.0 Release - Research

**Researched:** 2026-05-29
**Domain:** Documentation, ExDoc, GitHub Actions release process
**Confidence:** HIGH

## Summary

This phase finalizes the vM015 milestone by ensuring adopters have clear, comprehensive documentation on how to operate and extend Cairnloop, how to connect MCP clients, and how to contribute to the project. Finally, it cuts the `v0.2.0` release package. The technical foundation (ExDoc, hex publish GitHub Action) was laid out in Phase 18, so the scope here is purely documentation authoring and version bumping.

**Primary recommendation:** Write comprehensive, Elixir-idiomatic ExDoc guides covering the MCP router integration, token management, and `@callback` behavior implementations. Update the existing `mix.exs` `docs` config to include the new guides, update `CHANGELOG.md` reflecting vM015 additions, and cut the release.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Package Documentation | ExDoc | GitHub | HexDocs hosts the primary documentation, compiled from `guides/` markdown. |
| Release Process | CI/CD (GitHub Actions) | `mix.exs` | `.github/workflows/release.yml` handles `mix hex.publish` autonomously on tag push. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ex_doc | ~> 0.34 | Documentation generation | Official standard for Elixir libraries; generates hexdocs. |

**Installation:**
No new installations required. `ex_doc` is already configured in `mix.exs`.

## Package Legitimacy Audit

> **Required** whenever this phase installs external packages.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| None | — | — | — | — | — | No external packages installed in this phase. |

## Architecture Patterns

### Recommended ExDoc Documentation Structure
`mix.exs` must be updated to include the new guides in the `docs` `:extras` list:

```elixir
docs: [
  main: "readme",
  extras: [
    {"guides/01-quickstart.md", title: "Quickstart"},
    {"guides/02-jtbd-walkthrough.md", title: "JTBD Walkthrough"},
    {"guides/03-host-integration.md", title: "Host Integration"},
    {"guides/04-troubleshooting.md", title: "Troubleshooting"},
    {"guides/05-mcp-clients.md", title: "MCP Clients"},       # NEW
    {"guides/06-extending.md", title: "Extending Cairnloop"}, # NEW
    "README.md",
    "CHANGELOG.md"
  ],
  # ...
]
```

### Pattern 1: Extending Cairnloop via Callbacks (guide/06-extending.md)
**What:** Cairnloop uses the `@callback` (Behaviour) pattern for inversion of control. Adopters implement these behaviors in their own Phoenix applications to extend the library.
**When to use:** In `guides/06-extending.md`, document the following established behaviors:
- `Cairnloop.ContextProvider`: Injecting host domain state into the prompt.
- `Cairnloop.Notifier`: Alerting operators to SLA breaches or conversation resolution.
- `Cairnloop.AutomationPolicy`: Gatekeeping knowledge automation proposals.
- `Cairnloop.SLAPolicyProvider`: Dynamic SLA thresholds for support channels.
- `Cairnloop.Tool`: Defining new agent capabilities exposed to MCP and internals.
- `Cairnloop.Embedder`: Customizing embedding models (OpenAI vs local).
- `Cairnloop.Auditor`: Capturing system logs and custom audit trails.

### Pattern 2: Connecting MCP Clients (guide/05-mcp-clients.md)
**What:** Explaining how external MCP clients (Cursor, Claude) consume `Cairnloop.Web.MCP.Router`.
**When to use:** In `guides/05-mcp-clients.md`, document the integration steps:
1. Ensure the router forwards `/mcp` traffic: `forward "/mcp", Cairnloop.Web.MCP.Router`
2. Create an MCP Bearer token in the `SettingsLive` UI.
3. Configure the client (e.g. Cursor) to use the endpoint URL and pass the Bearer token.
4. Tools populate via `tools/list` projection of `Cairnloop.Tool.Spec`.

### Pattern 3: Local Development Guide (CONTRIBUTING.md)
**What:** Define a standard Elixir setup routine for external contributors.
**Example:**
```bash
mix deps.get
mix test.setup       # Bootstraps host DB AND library migrations
mix test             # Runs isolated fast unit suite
mix test.integration # Runs DB-backed E2E/Integration tests
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Release automation | Manual `mix hex.publish` script | `release.yml` GitHub Action | Standardized securely with `HEX_API_KEY`, already built in Phase 18. |
| Code documentation structure | Hand-rolled HTML / external wiki | `ex_doc` + `guides/` folder | Official ecosystem tool with automatic hexdocs integration. |

## Common Pitfalls

### Pitfall 1: Forgetting to bump the version in mix.exs
**What goes wrong:** The v0.2.0 tag is pushed to GitHub, but the package metadata in Hex still shows 0.1.0, failing the publish pipeline or creating confusion.
**How to avoid:** Ensure `mix.exs` `version` property is updated to `"0.2.0"` *before* tagging and pushing the release commit.

### Pitfall 2: Overlooking test database bootstrap instructions in CONTRIBUTING.md
**What goes wrong:** Contributors run `mix test` out of the box and get Ecto connection errors or missing table errors.
**Why it happens:** Cairnloop relies on a unique host-owned database structure where host tables (`cairnloop_conversations`) are migrated *before* library tables.
**How to avoid:** Clearly document `mix test.setup` (which handles Ecto repo creation and dual-path migrations) in the `CONTRIBUTING.md` file.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ex_doc | HexDocs | ✓ | ~> 0.34 | — |

**Missing dependencies with no fallback:**
- None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` / `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test.integration` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOC-* | Syntax checks in documentation code snippets | doc_test | `mix test` (runs doctests) | ✅ Wave 0 |
| REL-* | Valid compilation | build | `mix compile` | ✅ Wave 0 |

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not applicable to documentation. |

### Known Threat Patterns for Documentation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Leaking sensitive CI tokens | Info Disclosure | Never document actual CI keys; use placeholder `cl_mcp_***` tokens in examples. |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Scattered readmes | `ex_doc` guides directory | Phase 32 | Hexdocs natively serves all long-form prose. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | All claims verified via local file inspection | — | — |

## Open Questions (RESOLVED)

1. None — Phase is well defined and constrained to documentation authoring and version tagging.

## Sources

### Primary (HIGH confidence)
- `mix.exs` - Verified `ex_doc` is installed and `guides/` is the expected documentation path.
- `.planning/milestones/vM015-ROADMAP.md` - Verified feature additions for `CHANGELOG.md`.
- `.planning/research/ARCHITECTURE.md` - Base template for DOC-04 system architectural document.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - ExDoc is the undisputed standard in Elixir.
- Architecture: HIGH - Follows existing project trajectory laid down in Phase 18 and vM015 Roadmap.
- Pitfalls: HIGH - Version bump mismatch and DB setup issues are common open-source friction points.

**Research date:** 2026-05-29
**Valid until:** 2026-06-29
