# Phase 60: Installer, Docs, Upgrade, and OSS Trust - Context

**Gathered:** 2026-06-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Cairnloop's public adoption path truthful, current, skimmable, and supportable after the
vM019 trust-boundary and dedicated-schema work. This phase owns README, guides, ExDoc/package docs,
installer output, example-app docs, SECURITY, UPGRADING, CHANGELOG/package metadata, screenshots/
assets references, and source-scanned docs/package guardrails.

This is not a runtime prefix implementation phase, not a CI workflow optimization phase, not a new
operator workflow, and not a marketing-site build. Runtime trust fixes belong to Phase 58,
dedicated-schema behavior belongs to Phase 59, and CI/CD efficiency/release-confidence changes
belong to Phase 61 unless a narrow docs/package test needs a small supporting assertion.

</domain>

<decisions>
## Implementation Decisions

### Adoption Story and Install Truth

- **D-01:** Treat public docs as an adopter trust surface, not marketing copy. The phase should make
  live behavior, install commands, compatibility claims, and support expectations match the current
  source tree.
- **D-02:** Preserve the vM018 Docker-first evaluation story: README and Quickstart should lead with
  `./bin/demo`, printed URLs, dynamic localhost ports, seeded Trailmark data, and `./bin/demo smoke`
  as a route smoke check. Host-app install comes after the demo path.
- **D-03:** For real host apps, the Igniter installer is the primary install path and manual setup is
  the fallback. `lib/mix/tasks/cairnloop/install.ex` is the closest live source of truth for the
  intended generated migration and next-step output.
- **D-04:** Align README, Quickstart, Troubleshooting, Host Integration, example README, and
  UPGRADING with the Phase 59 schema-prefix contract: new installs use
  `config :cairnloop, :schema_prefix, "cairnloop"`; existing public-schema installs should use
  explicit `config :cairnloop, :schema_prefix, "public"` while migrating. Legacy `nil` may be
  mentioned only as accepted legacy compatibility, not as the recommended or pinned path.
- **D-05:** Do not instruct adopters to run
  `mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop`.
  The Phase 59 contract says Cairnloop qualifies its own objects in source; the docs should teach
  ordered host migrations followed by dependency migrations without the CLI `--prefix` shortcut.
- **D-06:** Keep host-owned responsibilities explicit: the host owns repo config, route auth,
  operator identity injection, Oban placement, secret storage, production monitoring, and any
  public-schema data migration timing. Cairnloop supplies safe defaults, docs, doctor checks, and
  explicit seams.

### Upgrade, Security, and Compatibility Claims

- **D-07:** `UPGRADING.md` should be concrete but honest. It should cover the dedicated-schema
  default, explicit public compatibility, a maintenance-window data move outline, verification of
  row counts/indexes/constraints/FKs/functions/triggers, rollback posture, and the boundaries that
  Oban and shared extensions such as `vector` stay host-owned.
- **D-08:** `SECURITY.md` should remain a public security policy, not an internal planning artifact:
  latest-release/main support posture, private vulnerability reporting, impacted version/config
  details to include, embedded-library host responsibilities, and Cairnloop security-sensitive areas.
- **D-09:** Compatibility claims should be source-backed and modest. Do not claim broad production,
  compliance, multi-tenant, hosted-demo, or enterprise support posture beyond what the repo proves.
  If a version is named, derive it from `mix.exs` or keep tests that compare docs to the project
  version.
- **D-10:** The docs should call out "when not to use Cairnloop" in practical terms: not a hosted
  helpdesk, not a replacement for host auth/authorization, not autonomous customer-visible support,
  not a tenant-isolation layer, and not a managed outbound campaign system.

### Package, ExDoc, and Verification Guardrails

- **D-11:** `mix.exs` is the authoritative package/ExDoc surface. Keep README, LICENSE, SECURITY,
  UPGRADING, CHANGELOG, and all shipped guides in `package[:files]`; keep the same public docs in
  `docs[:extras]`; keep guide assets deliberately handled by ExDoc assets and package rules.
- **D-12:** Add or update DB-free source-scan tests for docs/install/upgrade truth. Existing patterns
  in `test/cairnloop/tasks/install_test.exs`, `test/cairnloop/docs_trust_test.exs`,
  `test/cairnloop/docs/docker_first_docs_test.exs`, `test/cairnloop/demo_runtime_contract_test.exs`,
  and `test/cairnloop/web/collateral_wiring_test.exs` are the right model.
- **D-13:** Tests should reject stale install guidance across public docs: dependency versions that
  drift from `mix.exs`, recommended `schema_prefix: nil`, dependency migrations with
  `--prefix cairnloop`, obsolete pre-v0.5 package claims, missing shipped docs, and screenshots or
  assets referenced from docs but absent on disk.
- **D-14:** Verification for this phase should include targeted docs/install tests, `mix ci.fast`,
  and `mix ci.quality` because docs, package metadata, ExDoc, Hex build, and dependency audit are
  part of the trust surface. Run `mix ci.integration` only if implementation touches DB-backed
  behavior or the planner decides a docs claim needs runtime prefix proof.

### Claude's Discretion

- No owner-level question was escalated. `CLAUDE.md` directs GSD discuss-phase to auto-decide
  ordinary trust-sensitive implementation calls and surface only genuinely very-impactful choices.
  Phase 60 has no unresolved expensive or irreversible choice: the roadmap, requirements, and prior
  contexts already lock the phase as a truthful public docs/install/upgrade pass.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning and Requirements

- `.planning/PROJECT.md` - vM019 focus, architectural invariants, carried docs-as-quality and
  dedicated-schema decisions, and current release/package context.
- `.planning/REQUIREMENTS.md` - DOC-01 through DOC-06 are Phase 60 scope; future/out-of-scope notes
  exclude hosted demo, advanced routing, local AI, mobile SDK, and broad new product surface.
- `.planning/ROADMAP.md` - Phase 60 goal and success criteria.
- `.planning/STATE.md` - carried decisions, current phase state, dirty-worktree warning, and Phase
  59 completion handoff.
- `.planning/phases/57-evidence-and-trust-audit/57-CONTEXT.md` - audit baseline naming install/docs/
  release truth as a must-fix adoption risk.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md` - trust-boundary docs
  and Phase 60 deferrals after runtime auth/side-effect/readiness hardening.
- `.planning/phases/59-dedicated-postgres-schema-contract/59-CONTEXT.md` - dedicated-schema and
  public-compatibility decisions Phase 60 must make public and consistent.
- `CLAUDE.md` - decision policy, sealed-contract posture, operator-copy rules, and verification
  expectations.

### Audit and Contract Docs

- `docs/software-quality-evaluation.md` - source-backed ranking that identifies install/docs/release
  truth, upgrade path, security policy, package completeness, and docs drift as adoption risks.
- `docs/postgres-schema-prefix.md` - primary source for schema-prefix install/upgrade/migration
  guidance; Phase 60 must align public docs with its final Phase 59 implementation.
- `docs/ci-cd-audit.md` - context for release/package/dry-run claims and for deferring workflow
  optimization to Phase 61.
- `docs/architecture.md` - public architecture overview that may need current schema-prefix,
  host-owned, and support-truth wording.

### Public Docs Surface

- `README.md` - public front door, Docker-first demo story, host-app install overview, problem/
  use-case framing, guide links, contribution checks, and license.
- `guides/01-quickstart.md` - detailed Docker demo, host install, migration order, manual install,
  dashboard mount, static assets, and example walkthrough.
- `guides/02-jtbd-walkthrough.md` - seeded product walk-through and screenshot references; ensure
  demo/auth claims remain demo-scoped and assets exist.
- `guides/03-host-integration.md` - callbacks, router mounting, operations endpoints, telemetry,
  Notifier, automation policy, SLA policy, Scrypath, and production notes.
- `guides/04-troubleshooting.md` - Docker demo failure taxonomy, install prerequisites, migration
  order, pgvector, doctor output, trust failure domains, and sensitive telemetry guidance.
- `guides/05-mcp-clients.md` - MCP auth/module/token documentation from Phase 58 that must stay
  aligned with current router/AuthPlug behavior.
- `guides/06-extending.md` - tool/embedder/draft-generator/auditor extension docs and examples.
- `guides/07-auth-and-operator-identity.md` - host-auth/operator identity contract and static
  session trap, relevant to README/Quickstart install wording.
- `SECURITY.md` - public security policy to keep current and non-internal.
- `UPGRADING.md` - upgrade-path surface for dedicated schema/default prefix, public compatibility,
  migration order, rollback, and shared extension posture.
- `CHANGELOG.md` - release history and public package claims; check for stale compare links,
  pre-v0.5 claims, and current unreleased notes as needed.
- `examples/cairnloop_example/README.md` - example-app adopter docs, Docker URL boundary, schema
  prefix explanation, and mounted route references.

### Installer, Package, and Docs Code

- `lib/mix/tasks/cairnloop/install.ex` - Igniter installer, generated host migration, dependency
  version derivation, schema-prefix guidance, and next-step notice.
- `lib/cairnloop.ex` - root module docs that point readers to README and guides.
- `lib/cairnloop/schema_prefix.ex` - public/internal wording around `"cairnloop"`, `"public"`, and
  legacy `nil` compatibility.
- `lib/cairnloop/doctor.ex` and `lib/mix/tasks/cairnloop.doctor.ex` - doctor behavior and output
  that docs should describe accurately without overclaiming `/health`.
- `mix.exs` - project version, package files, ExDoc extras/assets/module groups, CI aliases, and
  quality checks.
- `.github/workflows/release-please.yml` - release package/docs verification and Hex publishing
  path relevant to public release claims.
- `.github/workflows/demo-smoke.yml` - Docker demo docs-trigger path and smoke proof.
- `examples/cairnloop_example/config/config.exs` - example app schema-prefix and runtime defaults
  that example docs should match.
- `examples/cairnloop_example/mix.exs` - example aliases/migration order and local path dependency
  dogfood story.

### Existing Guardrail Tests

- `test/cairnloop/tasks/install_test.exs` - installer source-scan expectations for version,
  schema-prefix, no `--prefix` shortcut, `customer_ref`, and doctor guidance.
- `test/cairnloop/docs_trust_test.exs` - MCP/trust docs source scans and sensitive telemetry docs
  assertions from Phase 58.
- `test/cairnloop/docs/docker_first_docs_test.exs` - Docker-first docs source scans for README,
  Quickstart, Troubleshooting, example README, wrapper help, and route smoke.
- `test/cairnloop/demo_runtime_contract_test.exs` - source-scan checks for dependency split,
  migration order, printed URL boundary, and Trailmark docs consistency.
- `test/cairnloop/web/collateral_wiring_test.exs` - README logo/package-file guardrails and package
  file list expectations.
- `test/cairnloop/schema_prefix_test.exs` - prefix helper semantics and source-scan expectations
  around `"public"` vs `nil`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Mix.Tasks.Cairnloop.Install` already derives the dependency version from
  `Mix.Project.config()[:version]`, generates prefix-aware host-support migrations, prints explicit
  `"cairnloop"` and `"public"` schema-prefix guidance, and warns against `--prefix cairnloop`.
- `UPGRADING.md` and `SECURITY.md` already exist and are included in both package files and ExDoc
  extras; planning should improve/align them rather than invent new locations.
- `mix.exs` already provides the quality lane for docs/package proof: `mix hex.build`,
  `mix docs --warnings-as-errors`, and package/extras lists.
- Source-scan docs tests are established and fast. They read files directly, avoid DB/browser work,
  and are suitable for keeping public docs aligned with installer/package/version/source contracts.
- The Docker demo wrapper and docs tests already preserve the vM018 evaluation story; Phase 60 can
  update install/upgrade sections without weakening the Docker-first boundary.

### Established Patterns

- Cairnloop is a host-owned Phoenix/Ecto library. Public docs should consistently say the host owns
  Repo, route auth, operator identity injection, Oban, secrets, monitoring, and deployment.
- Operator/support copy should be calm, fail-closed, reason-forward, and honest. Do not expose raw
  Elixir terms to operators; for public docs, avoid corporate ceremony and unsupported claims.
- Use source-backed claims. If docs mention current version, package files, docs extras, migration
  commands, or runtime module names, tests should compare against source where practical.
- Runtime contracts from Phases 58 and 59 are sealed enough for docs to describe them. Do not reopen
  runtime behavior unless a docs claim uncovers a tiny source-doc typo or a necessary test-only
  source-scan adjustment.

### Integration Points

- README, Quickstart, Host Integration, Troubleshooting, example README, and UPGRADING all describe
  installation/migration; they must converge on one command/config story.
- SECURITY, MCP clients, Auth & Operator Identity, Host Integration, and Troubleshooting all touch
  trust boundaries; they must align with Phase 58 without duplicating conflicting security posture.
- CHANGELOG, package metadata, ExDoc extras, release-please checks, and `mix ci.quality` form the
  public release/docs verification path.
- Screenshots and guide assets are referenced by docs and handled by ExDoc assets; Phase 60 should
  source-scan references before claiming assets/package completeness.

</code_context>

<specifics>
## Specific Ideas

- Fix the currently visible drift where README, Quickstart, and Troubleshooting still teach
  `schema_prefix: nil` as the public-compatibility recommendation or include
  `--prefix cairnloop` in dependency migration commands, while the installer and UPGRADING now teach
  explicit `"public"` compatibility and no `--prefix` shortcut.
- Add a docs truth test, likely under `test/cairnloop/docs/`, that scans README, Quickstart,
  Troubleshooting, Host Integration, UPGRADING, and example README for one aligned schema-prefix and
  migration-order story.
- Extend source scans to compare every `{:cairnloop, "~> ..."}`
  dependency snippet against `Mix.Project.config()[:version]`.
- Check ExDoc/package files for missing or stale public docs. If a guide is linked from README or
  ExDoc extras, ensure it exists and is intentionally shipped or intentionally asset-only.
- Keep "when not to use Cairnloop" near the top of the public docs rather than hiding trust caveats
  deep in troubleshooting.

</specifics>

<deferred>
## Deferred Ideas

- CI workflow action/runtime, permission, cache, artifact, and release-gate optimization remains
  Phase 61 scope.
- Runtime dedicated-schema fixes, raw SQL behavior, and DB-backed prefix proof remain Phase 59
  ownership and should already be complete before Phase 60 begins.
- Runtime trust-boundary behavior for widget/email/MCP/Scrypath/telemetry remains Phase 58
  ownership and should already be complete before Phase 60 begins.
- Hosted demo, marketing site, rich public landing page, enterprise compliance program, mobile SDK,
  advanced routing, and local AI are outside this milestone.
- Full automation of an existing install's data migration from `public` to `cairnloop` is out of
  scope; Phase 60 should document a safe sequence and verification responsibilities.

</deferred>

---

*Phase: 60-Installer, Docs, Upgrade, and OSS Trust*
*Context gathered: 2026-06-30*
