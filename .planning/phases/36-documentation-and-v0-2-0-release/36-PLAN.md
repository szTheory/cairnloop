---
phase: 36
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - guides/05-mcp-clients.md
  - guides/06-extending.md
  - CONTRIBUTING.md
  - docs/architecture.md
  - CHANGELOG.md
  - mix.exs
autonomous: false
requirements: [DOC-01, DOC-02, DOC-03, DOC-04, REL-01, REL-02]

must_haves:
  truths:
    - Adopter can read ExDoc guides covering MCP clients and extending Cairnloop
    - Contributor can find clear contribution guidelines in CONTRIBUTING.md
    - Adopter can understand system design via docs/architecture.md
    - Release v0.2.0 is published and documented in CHANGELOG.md
  artifacts:
    - path: guides/05-mcp-clients.md
      provides: MCP client configuration guide
    - path: guides/06-extending.md
      provides: Custom adapter and extension guide
    - path: CONTRIBUTING.md
      provides: Contributor onboarding and local setup guide
    - path: docs/architecture.md
      provides: System internals and architectural overview
    - path: CHANGELOG.md
      provides: v0.2.0 release notes
  key_links:
    - from: mix.exs
      to: guides/05-mcp-clients.md
      via: docs extras configuration
      pattern: "guides/05-mcp-clients\\.md"
---

<objective>
Author comprehensive architectural and extending guidance for adopters, finalize contribution guidelines, and cut the v0.2.0 release.

Purpose: Finalize the vM015 milestone by ensuring external adopters can properly operate, configure, and understand Cairnloop.
Output: New documentation files, updated CHANGELOG, and a bumped `mix.exs` version ready for tagging.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
@$HOME/.gemini/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/36-documentation-and-v0-2-0-release/36-PATTERNS.md
@.planning/phases/36-documentation-and-v0-2-0-release/36-RESEARCH.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author ExDoc Guides for MCP and Extensibility</name>
  <files>guides/05-mcp-clients.md, guides/06-extending.md</files>
  <action>
    Create `guides/05-mcp-clients.md` covering MCP router integration. Explain how to forward `/mcp` traffic to `Cairnloop.Web.MCP.Router`, how to create an MCP Bearer token in the `SettingsLive` UI, and how to configure clients (e.g., Cursor, Claude). Follow the structure of existing analog guides (`guides/01-quickstart.md`, `guides/03-host-integration.md`).
    Create `guides/06-extending.md` documenting the `@callback` extension points (`Cairnloop.ContextProvider`, `Cairnloop.Notifier`, `Cairnloop.AutomationPolicy`, `Cairnloop.SLAPolicyProvider`, `Cairnloop.Tool`, `Cairnloop.Embedder`, `Cairnloop.Auditor`). Provide brief explanations of each behaviour's purpose. Use `cl_mcp_***` placeholders for any secrets.
  </action>
  <verify>
    <automated>mix docs</automated>
  </verify>
  <done>ExDoc guides are written following existing patterns.</done>
</task>

<task type="auto">
  <name>Task 2: Author Contributor and Architecture Docs</name>
  <files>CONTRIBUTING.md, docs/architecture.md</files>
  <action>
    Create `CONTRIBUTING.md` in the root directory. Document the standard Elixir local development setup, specifically emphasizing `mix deps.get`, `mix test.setup` (which handles Ecto repo creation and host/library dual migrations), `mix test` (isolated unit suite), and `mix test.integration` (DB-backed E2E tests).
    Create `docs/architecture.md` using insights from `.planning/research/ARCHITECTURE.md` (and insights from `36-RESEARCH.md`). Keep the focus on how Cairnloop acts as an embedded support operations layer for Phoenix apps, following the format of analog document `docs/cairnloop-jtbd-and-user-flows.md`.
  </action>
  <verify>
    <automated>mix docs</automated>
  </verify>
  <done>Contribution guidelines and architecture docs are written and correctly path-located.</done>
</task>

<task type="auto">
  <name>Task 3: Bump Version and Update Release Files</name>
  <files>mix.exs, CHANGELOG.md</files>
  <action>
    Update `mix.exs` to include `{"guides/05-mcp-clients.md", title: "MCP Clients"}` and `{"guides/06-extending.md", title: "Extending Cairnloop"}` in the `docs` `:extras` list.
    Bump the `version` attribute in `mix.exs` to `"0.2.0"`.
    Update `CHANGELOG.md` following the Keep a Changelog format. Move the `## [Unreleased]` contents under a new `## [0.2.0] - YYYY-MM-DD` section and summarize the vM015 additions (Phase 33 Security Closure, Phase 34 Settings Surface, Phase 35 Audit & Operations). Add a new empty `## [Unreleased]` block at the top.
  </action>
  <verify>
    <automated>mix compile && grep 'version: "0.2.0"' mix.exs</automated>
  </verify>
  <done>Version is bumped to 0.2.0 and changes are cleanly documented in the changelog.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Checkpoint and Release Tagging</name>
  <what-built>Documentation files have been authored, version bumped to 0.2.0, and CHANGELOG updated.</what-built>
  <how-to-verify>
    1. Review the generated markdown files in `guides/`, `docs/`, and `CONTRIBUTING.md`.
    2. Check that `mix.exs` successfully compiles and docs list is correct by running `mix docs`.
    3. Once verified, the executor should run `git add .`, commit the changes with `git commit -m "chore(release): bump version to 0.2.0"`, create a tag `git tag v0.2.0`, and push the commit and tag `git push origin v0.2.0` to trigger the release pipeline.
  </how-to-verify>
  <resume-signal>Type "approved" once you are satisfied for the executor to commit and tag the release.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Documentation | No new trust boundaries introduced, static content. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-36-01 | Info Disclosure | Documentation | mitigate | Ensure no sensitive CI keys or internal production tokens are accidentally added in examples (use `cl_mcp_***` placeholders). |
| T-36-SC | Tampering | npm/pip/cargo installs | accept | No new dependencies introduced in this phase. |
</threat_model>

<verification>
- `mix compile` succeeds
- `mix docs` successfully generates the hexdocs
- All new files exist and are properly formatted
</verification>

<success_criteria>
- Comprehensive guides created for extending and MCP usage
- Architectural summary provided to adopters
- Contributing setup workflow documented
- `CHANGELOG.md` properly formatted for v0.2.0 release
- Application version bumped in `mix.exs`
- Release tag applied and pushed
</success_criteria>

<output>
Create `.planning/phases/36-documentation-and-v0-2-0-release/36-01-SUMMARY.md` when done
</output>
