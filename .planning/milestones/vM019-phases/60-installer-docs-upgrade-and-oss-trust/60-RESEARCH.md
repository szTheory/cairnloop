# Phase 60: Installer, Docs, Upgrade, and OSS Trust - Research

**Researched:** 2026-06-30
**Domain:** Elixir/Phoenix OSS adoption docs, Igniter installer truth, Hex/ExDoc package trust
**Confidence:** HIGH for repo-source inventory; MEDIUM for external documentation lookups via official web docs

<user_constraints>
## User Constraints (from CONTEXT.md)

All content in this section is copied from `.planning/phases/60-installer-docs-upgrade-and-oss-trust/60-CONTEXT.md`. [VERIFIED: codebase grep]

### Locked Decisions

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

### the agent's Discretion

- No owner-level question was escalated. `CLAUDE.md` directs GSD discuss-phase to auto-decide
  ordinary trust-sensitive implementation calls and surface only genuinely very-impactful choices.
  Phase 60 has no unresolved expensive or irreversible choice: the roadmap, requirements, and prior
  contexts already lock the phase as a truthful public docs/install/upgrade pass.

### Deferred Ideas (OUT OF SCOPE)

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
</user_constraints>

## Project Constraints (from AGENTS.md)

- Read `CLAUDE.md` first for all work in this repo. [VERIFIED: AGENTS.md]
- For UI work, also read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`. [VERIFIED: AGENTS.md]
- The shipped dashboard uses Cairnloop's tokenized `.cl-*` / BEM CSS system, not Tailwind. [VERIFIED: AGENTS.md]
- Keep adopter-facing UI changes inside the component system so spacing, motion, color, and accessibility improve globally instead of drifting screen by screen. [VERIFIED: AGENTS.md]
- `CLAUDE.md` requires decisions to be researched and made without asking the owner except for very impactful irreversible calls. [VERIFIED: CLAUDE.md]
- `CLAUDE.md` requires warnings-clean builds with `mix compile --warnings-as-errors`, `mix ci.fast` before declaring headless work done, and `mix ci.quality` for docs/package changes. [VERIFIED: CLAUDE.md]
- `examples/cairnloop_example/AGENTS.md` requires root `CLAUDE.md`, root `AGENTS.md`, and `docs/operator-ui-principles.md` before example UI or E2E work. [VERIFIED: examples/cairnloop_example/AGENTS.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | README explains what problem Cairnloop solves, when to use it, when not to use it, and the fastest first success path without stale version/config claims. [VERIFIED: .planning/REQUIREMENTS.md] | README currently leads with Docker demo but lacks a practical "when not to use" section and still contains stale `schema_prefix: nil` / `--prefix cairnloop` guidance. [VERIFIED: codebase grep] |
| DOC-02 | Installer output and generated snippets match the current package version and complete setup contract, including repo config and ordered host/library migrations. [VERIFIED: .planning/REQUIREMENTS.md] | `lib/mix/tasks/cairnloop/install.ex` derives `~> #{@cairnloop_version}` from `Mix.Project.config()[:version]`, prints repo config, prints `"cairnloop"` and `"public"` schema-prefix guidance, and omits the dependency-migration `--prefix` command. [VERIFIED: codebase grep] |
| DOC-03 | Quickstart, host integration, MCP, extending, troubleshooting, example README, ExDoc groups, and package guides match current code paths and public APIs. [VERIFIED: .planning/REQUIREMENTS.md] | Quickstart and Troubleshooting still teach stale migration/prefix guidance; MCP/auth/extending docs need source scans against router/AuthPlug/tool/behavior modules. [VERIFIED: codebase grep] |
| DOC-04 | `SECURITY.md` is a public security policy, not an internal phase artifact. [VERIFIED: .planning/REQUIREMENTS.md] | Current `SECURITY.md` is already public-facing and includes supported versions, private reporting, impacted details, scope, host responsibilities, and response posture. [VERIFIED: codebase grep] |
| DOC-05 | `UPGRADING.md` documents versioning, DB prefix migration choices, deprecations, rollback posture, and compatibility claims for Elixir/OTP/Phoenix/Ecto/Postgres. [VERIFIED: .planning/REQUIREMENTS.md] | Current `UPGRADING.md` covers the schema default, explicit public compatibility, high-level data move, shared extension posture, and verification commands, but it should add compatibility matrix and fuller verification/rollback detail. [VERIFIED: codebase grep] |
| DOC-06 | Public package metadata, changelog, examples, and screenshots/assets do not contain stale paths, missing assets, or pre-v0.5 claims. [VERIFIED: .planning/REQUIREMENTS.md] | `mix.exs` includes public docs in package files and ExDoc extras, Hex reports `cairnloop` `0.5.1`, and `guides/02-jtbd-walkthrough.md` references missing `guides/assets/02-operator-inbox.png`. [VERIFIED: codebase grep] [VERIFIED: Hex CLI] |
</phase_requirements>

## Summary

Phase 60 should be planned as a source-of-truth convergence pass across public docs, installer notices, package metadata, ExDoc extras/assets, upgrade/security artifacts, example docs, and DB-free guardrail tests. [VERIFIED: 60-CONTEXT.md] The primary live truth sources are `mix.exs`, `lib/mix/tasks/cairnloop/install.ex`, `lib/cairnloop/schema_prefix.ex`, `lib/cairnloop/doctor.ex`, `lib/cairnloop.ex`, the Phase 58/59 source-scan tests, and the current public docs set. [VERIFIED: codebase grep]

The highest-risk drift is already visible: README, Quickstart, and Troubleshooting still recommend `schema_prefix: nil` or dependency migrations with `--prefix cairnloop`, while the installer and `UPGRADING.md` now teach explicit `"public"` compatibility and ordered host/dependency migrations without the `--prefix` shortcut. [VERIFIED: codebase grep] The second concrete drift is asset truth: `guides/02-jtbd-walkthrough.md` references `assets/02-operator-inbox.png`, but that file is absent under `guides/assets/`. [VERIFIED: shell file-existence scan]

**Primary recommendation:** Plan one docs-truth wave that fixes README/Quickstart/Troubleshooting/UPGRADING/install wording first, then one package/ExDoc/assets/security/changelog wave, with DB-free source-scan tests added before or alongside each edit. [VERIFIED: 60-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Public adoption story | Docs/package tier | Example app | README/guides/example README are the adopter-facing surface and should describe live demo/install behavior. [VERIFIED: codebase grep] |
| Installer generated dependency and migration guidance | Mix task / installer tier | Docs/package tier | `Mix.Tasks.Cairnloop.Install` owns generated migration snippets and next-step notice; docs mirror it. [VERIFIED: codebase grep] |
| Schema-prefix install/upgrade contract | Database / migration tier | Docs/package tier | `Cairnloop.SchemaPrefix` and prefix-aware migrations are runtime truth; docs must not change runtime behavior. [VERIFIED: codebase grep] |
| ExDoc and Hex package contents | Package metadata tier | CI/release tier | `mix.exs` owns `package[:files]`, `docs[:extras]`, guide assets, and quality aliases. [VERIFIED: mix.exs] |
| Security reporting posture | Repository trust docs | GitHub security advisories | `SECURITY.md` should document reporting and support posture; GitHub advisories provide private collaboration for public repos. [CITED: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository] [CITED: https://docs.github.com/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories] |
| Verification guardrails | Test tier | CI quality lane | Existing docs tests are DB-free ExUnit source scans; `mix ci.quality` covers Hex build, docs, Credo, and audit. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library / Tool | Version / Constraint | Purpose | Why Standard |
|----------------|----------------------|---------|--------------|
| Cairnloop package | `0.5.1`; Hex reports recent release `0.5.1` on 2026-06-03. [VERIFIED: mix.exs] [VERIFIED: Hex CLI] | Public package and docs subject of this phase. | All version claims must derive from `mix.exs` or tests comparing docs to `mix.exs`. [VERIFIED: 60-CONTEXT.md] |
| Elixir / Mix | `~> 1.19`; local `1.19.5` / OTP 28. [VERIFIED: mix.exs] [VERIFIED: shell version probe] | Build, docs, tests, Hex packaging. | Project quality aliases and docs/package checks are Mix-based. [VERIFIED: mix.exs] |
| Igniter | `~> 0.5` in `mix.exs`. [VERIFIED: mix.exs] | Primary host-app installer path. | Official Igniter docs provide `Igniter.Mix.Task`, `Igniter.Project.Deps.add_dep/2`, `Igniter.Libs.Ecto.gen_migration/4`, and `Igniter.add_notice/2`. [CITED: https://hexdocs.pm/igniter/Igniter.Mix.Task.html] [CITED: https://hexdocs.pm/igniter/Igniter.Project.Deps.html] [CITED: https://hexdocs.pm/igniter/Igniter.Libs.Ecto.html] [CITED: https://hexdocs.pm/igniter/Igniter.html] |
| Ecto SQL | `~> 3.10` in `mix.exs`. [VERIFIED: mix.exs] | Migration semantics and schema-prefix claims. | Official Ecto docs say migrations are tracked in `schema_migrations` and table/index prefixes target schemas; this supports source-qualified DDL instead of a broad `--prefix` shortcut. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] |
| ExDoc | `~> 0.34` in `mix.exs`. [VERIFIED: mix.exs] | ExDoc extras, guide grouping, module grouping, docs assets. | Official ExDoc docs support `:groups_for_extras` and `:groups_for_modules`; Cairnloop already uses those options. [CITED: https://hexdocs.pm/ex_doc/0.28.2/Mix.Tasks.Docs.html] [VERIFIED: mix.exs] |
| Hex | Local Hex CLI used by `mix hex.build` / `mix hex.publish`. [VERIFIED: mix.exs] | Package tarball and docs publish verification. | Official Hex docs say `mix hex.build --unpack` is for inspecting package contents and `mix hex.publish --dry-run` performs local checks without publishing. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] |

### Supporting

| Library / Tool | Version / Constraint | Purpose | When to Use |
|----------------|----------------------|---------|-------------|
| Phoenix LiveView | `~> 1.0`; lock resolves `1.1.30`. [VERIFIED: mix.exs] [VERIFIED: mix.lock grep] | Router/session docs and dashboard host-auth examples. | Use official `live_session :session` MFA semantics when documenting per-request operator identity. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] |
| Oban | `~> 2.17`; lock resolves `2.22.1`. [VERIFIED: mix.exs] [VERIFIED: mix.lock grep] | Host-owned background jobs and upgrade boundaries. | Docs must state Oban remains host-owned and is not moved by Cairnloop schema prefix. [VERIFIED: 60-CONTEXT.md] |
| pgvector | `~> 0.3.1` in `mix.exs`. [VERIFIED: mix.exs] | Embeddings extension dependency. | Upgrade docs should state shared `vector` extension remains host/database infrastructure and is not dropped by Cairnloop rollback. [VERIFIED: UPGRADING.md] |
| Credo / mix_audit | `~> 1.7` / `~> 2.1` in `mix.exs`. [VERIFIED: mix.exs] | Quality lane for docs/package trust. | Run through `mix ci.quality` for this phase. [VERIFIED: mix.exs] |
| Node / npm | Local Node `22.14.0`, npm `11.1.0`. [VERIFIED: shell version probe] | Screenshot refresh tooling in `examples/cairnloop_example/screenshots/`. | Use only if planner chooses to refresh guide screenshots; capture is documented as non-gating. [VERIFIED: examples/cairnloop_example/README.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Source-scanned docs tests | Manual doc review only | Manual review cannot prevent future drift; existing DB-free ExUnit scan pattern is already established. [VERIFIED: codebase grep] |
| Igniter installer as source of truth | Duplicate install snippets manually across docs | Manual duplication caused current README/Quickstart/Troubleshooting drift. [VERIFIED: codebase grep] |
| Hex/ExDoc built-in package inspection | Custom tarball/docs scripts | `mix hex.build --unpack`, `mix docs --warnings-as-errors`, and `mix hex.publish --dry-run` are already supported by official tooling and project aliases. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [VERIFIED: mix.exs] |

**Installation:**

No new external packages should be installed for Phase 60. [VERIFIED: 60-CONTEXT.md] Use the existing locked deps and verification lanes:

```bash
mix deps.get --check-locked
mix ci.fast
mix ci.quality
```

**Version verification:** `mix.exs` reports Cairnloop version `0.5.1`; `mix hex.info cairnloop` reports current config `{:cairnloop, "~> 0.5.1"}`, recent release `0.5.1` dated 2026-06-03, MIT license, GitHub and Changelog links, 28 downloads in the last 7 days, and 345 all-time downloads. [VERIFIED: mix.exs] [VERIFIED: Hex CLI]

## Package Legitimacy Audit

This phase should not install new external packages. [VERIFIED: 60-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| No new package | Hex | n/a | n/a | n/a | n/a | Do not add dependencies for Phase 60. [VERIFIED: 60-CONTEXT.md] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: research scope]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: research scope]

## Architecture Patterns

### System Architecture Diagram

```text
Adopter / maintainer reads public docs
  -> README / guides / SECURITY / UPGRADING / CHANGELOG
  -> source-backed install story
      -> Docker demo path: ./bin/demo -> printed URLs -> ./bin/demo smoke
      -> host-app path: mix cairnloop.install -> generated host migration -> dependency migrations
  -> package/docs verification
      -> mix.exs package[:files] + docs[:extras] + docs[:assets]
      -> mix hex.build / mix docs --warnings-as-errors / mix ci.quality
  -> DB-free guardrails
      -> source-scan tests reject stale version, prefix, migration, package, and asset claims
  -> planner/executor edits docs and tests only unless a tiny source typo is uncovered
```

### Recommended Project Structure

```text
README.md                         # public front door and Docker-first adoption story
guides/                           # ExDoc guide extras and screenshots
SECURITY.md                       # public vulnerability reporting policy
UPGRADING.md                      # upgrade and schema-prefix migration guidance
CHANGELOG.md                      # public release history
mix.exs                           # package files, ExDoc extras/assets, version, CI aliases
lib/mix/tasks/cairnloop/install.ex # installer generated deps/migration/notice truth
lib/cairnloop.ex                  # root module docs
lib/cairnloop/schema_prefix.ex    # schema-prefix contract wording
lib/cairnloop/doctor.ex           # doctor behavior docs must describe accurately
examples/cairnloop_example/README.md # example-app adoption/demo docs
test/cairnloop/docs/              # preferred location for new docs source-scan tests
test/cairnloop/*docs*_test.exs    # existing docs/install/package guardrails
```

### Pattern 1: Source-Scanned Docs Truth

**What:** Add fast ExUnit tests that read Markdown/source files and assert allowed/forbidden install, version, prefix, package, and asset strings. [VERIFIED: codebase grep]

**When to use:** Use for every public claim that can drift from `mix.exs`, installer output, package files, guide assets, router modules, or source modules. [VERIFIED: 60-CONTEXT.md]

**Example:**

```elixir
# Source: test/cairnloop/tasks/install_test.exs [VERIFIED: codebase grep]
source = File.read!("lib/mix/tasks/cairnloop/install.ex")

assert source =~ ~s(config :cairnloop, :schema_prefix, "cairnloop")
assert source =~ ~s(config :cairnloop, :schema_prefix, "public")
refute source =~
         "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop"
```

### Pattern 2: `mix.exs` as Package and Version Authority

**What:** Treat `mix.exs` as the authoritative source for project version, package file allowlist, ExDoc extras, guide assets, docs groups, and quality aliases. [VERIFIED: mix.exs]

**When to use:** Use whenever docs mention version, shipped files, HexDocs pages, or release/package checks. [VERIFIED: 60-CONTEXT.md]

**Example:**

```elixir
# Source: mix.exs [VERIFIED: mix.exs]
version: "0.5.1",
package: [
  files: ~w(lib priv mix.exs README.md LICENSE SECURITY.md UPGRADING.md CHANGELOG.md guides/01-quickstart.md)
],
docs: [
  extras: ["UPGRADING.md", "README.md", "SECURITY.md", "CHANGELOG.md"],
  assets: %{"guides/assets" => "assets"}
]
```

### Pattern 3: Installer Notice Mirrors Public Docs

**What:** Let `lib/mix/tasks/cairnloop/install.ex` define the intended host-app install path and make README/Quickstart/Troubleshooting/UPGRADING mirror it. [VERIFIED: codebase grep]

**When to use:** Use for dependency snippets, repo config, schema-prefix examples, ordered migration commands, doctor check, router mounting, and customer_ref upgrade guidance. [VERIFIED: codebase grep]

**Example:**

```elixir
# Source: lib/mix/tasks/cairnloop/install.ex [VERIFIED: codebase grep]
config :cairnloop, :schema_prefix, "cairnloop"
config :cairnloop, :schema_prefix, "public"

mix ecto.migrate
mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations
mix cairnloop.doctor
```

### Anti-Patterns to Avoid

- **Teaching `schema_prefix: nil` as the public-compatibility recommendation:** use explicit `"public"` for compatibility and mention `nil` only as legacy accepted behavior. [VERIFIED: 60-CONTEXT.md]
- **Teaching `mix ecto.migrate --prefix cairnloop`:** Cairnloop qualifies its own objects in source; the docs should not tell adopters to move migrator bookkeeping with a broad prefix shortcut. [VERIFIED: 60-CONTEXT.md] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html]
- **Claiming broad production/compliance/multi-tenant/hosted-demo support:** compatibility claims must stay source-backed and modest. [VERIFIED: 60-CONTEXT.md]
- **Changing runtime schema-prefix or trust behavior during this docs phase:** runtime fixes belong to Phases 58/59 unless a tiny docs/source typo is uncovered. [VERIFIED: 60-CONTEXT.md]
- **Adding UI/CSS changes without UI instructions:** downstream agents must read `docs/operator-ui-principles.md` before touching `lib/cairnloop/web/**` or `priv/static/cairnloop.css`. [VERIFIED: AGENTS.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Package tarball inspection | Custom archive parser | `mix hex.build --unpack` or existing release workflow tarball check [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [VERIFIED: .github/workflows/release-please.yml] | Hex already builds the artifact that will be published. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] |
| Documentation generation | Custom docs renderer | ExDoc `mix docs --warnings-as-errors` [VERIFIED: mix.exs] | ExDoc already owns extras/groups/assets and HexDocs output. [CITED: https://hexdocs.pm/ex_doc/0.28.2/Mix.Tasks.Docs.html] |
| Installer dependency and migration edits | Manual text patching in host apps | Igniter helpers: `add_dep`, `gen_migration`, `add_notice` [CITED: https://hexdocs.pm/igniter/Igniter.Project.Deps.html] [CITED: https://hexdocs.pm/igniter/Igniter.Libs.Ecto.html] [CITED: https://hexdocs.pm/igniter/Igniter.html] | The existing installer is already an Igniter task and tests assert its source contract. [VERIFIED: codebase grep] |
| Schema-prefix explanation | New migration behavior | `Cairnloop.SchemaPrefix` and Phase 59 source-qualified migrations [VERIFIED: codebase grep] | Phase 60 documents the sealed contract; it should not reopen runtime DB behavior. [VERIFIED: 60-CONTEXT.md] |
| Asset link checks | Visual manual pass only | DB-free Markdown asset reference scan [VERIFIED: shell file-existence scan] | The repo already has a missing guide asset reference that a file scan catches. [VERIFIED: shell file-existence scan] |
| OSS vulnerability reporting model | Corporate process template | Concise `SECURITY.md` plus GitHub private security advisories [CITED: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository] [CITED: https://docs.github.com/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories] | GitHub docs define the expected public reporting surface and private advisory workflow. [CITED: https://docs.github.com/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories] |

**Key insight:** The hard part is not generating more docs; it is making public docs executable against live source so install, upgrade, package, and trust claims cannot drift again. [VERIFIED: 60-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Prefix Story Split-Brain

**What goes wrong:** README/Quickstart/Troubleshooting teach `nil` or `--prefix cairnloop` while installer/UPGRADING teach `"public"` and no dependency `--prefix`. [VERIFIED: codebase grep]
**Why it happens:** Install snippets are duplicated across public docs instead of tested against the installer. [VERIFIED: codebase grep]
**How to avoid:** Add one source-scan test over README, Quickstart, Troubleshooting, Host Integration, UPGRADING, and example README. [VERIFIED: 60-CONTEXT.md]
**Warning signs:** Any public doc contains `schema_prefix, nil`, `schema_prefix: nil`, or `--migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop`. [VERIFIED: codebase grep]

### Pitfall 2: Package Version Drift

**What goes wrong:** Docs hard-code `{:cairnloop, "~> 0.5.1"}` and can drift when `mix.exs` changes. [VERIFIED: codebase grep]
**Why it happens:** Version strings appear in README and Quickstart. [VERIFIED: codebase grep]
**How to avoid:** Use tests that read `Mix.Project.config()[:version]` or parse `mix.exs` and assert all touched docs match. [VERIFIED: 60-CONTEXT.md]
**Warning signs:** A docs dependency snippet contains `~> 0.` without a test tying it to `mix.exs`. [VERIFIED: codebase grep]

### Pitfall 3: ExDoc/HexDocs Asset Mismatch

**What goes wrong:** A guide links an asset that is absent or not carried into generated docs. [VERIFIED: shell file-existence scan]
**Why it happens:** `docs[:assets]` maps `guides/assets` for ExDoc, while `package[:files]` intentionally excludes guide assets from source package files. [VERIFIED: mix.exs]
**How to avoid:** Add an asset-reference scan and run `mix docs --warnings-as-errors` / `mix hex.build`. [VERIFIED: 60-CONTEXT.md] [VERIFIED: mix.exs]
**Warning signs:** `guides/02-jtbd-walkthrough.md` references `assets/02-operator-inbox.png`, which is missing. [VERIFIED: shell file-existence scan]

### Pitfall 4: Security Policy Overpromise

**What goes wrong:** `SECURITY.md` reads like an enterprise SLA or internal phase artifact. [VERIFIED: 60-CONTEXT.md]
**Why it happens:** Public OSS trust docs are easy to pad with ceremonial commitments. [VERIFIED: 60-CONTEXT.md]
**How to avoid:** Keep latest-release/main support posture, private reporting, impacted version/config details, host responsibilities, and security-sensitive areas. [VERIFIED: 60-CONTEXT.md] [CITED: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository]
**Warning signs:** Claims about compliance, enterprise response times, or broad version support not backed by release policy. [VERIFIED: 60-CONTEXT.md]

### Pitfall 5: Release/CI Scope Creep

**What goes wrong:** Phase 60 tries to optimize GitHub Actions, action runtime, permissions, or caching. [VERIFIED: 60-CONTEXT.md]
**Why it happens:** Package trust touches release workflows, but Phase 61 owns CI/CD efficiency and release-confidence changes. [VERIFIED: 60-CONTEXT.md]
**How to avoid:** Only change tests/docs/package assertions needed to prove Phase 60 truth; defer workflow optimization to Phase 61. [VERIFIED: 60-CONTEXT.md]
**Warning signs:** Plan tasks edit `.github/workflows/*.yml` for action/runtime/cache strategy instead of docs/package truth. [VERIFIED: 60-CONTEXT.md]

## Code Examples

Verified patterns from project source and official docs:

### ExDoc Extras, Groups, and Assets

```elixir
# Source: mix.exs [VERIFIED: mix.exs]
docs: [
  main: "readme",
  extras: [
    {"guides/01-quickstart.md", title: "Quickstart"},
    "UPGRADING.md",
    "README.md",
    "SECURITY.md",
    "CHANGELOG.md"
  ],
  groups_for_extras: [
    Guides: ~r/^guides\//
  ],
  assets: %{"guides/assets" => "assets"}
]
```

### Hex Package Files and Quality Lane

```elixir
# Source: mix.exs [VERIFIED: mix.exs]
package: [
  files: ~w(
    lib
    priv
    mix.exs
    README.md
    LICENSE
    SECURITY.md
    UPGRADING.md
    CHANGELOG.md
    guides/01-quickstart.md
    guides/02-jtbd-walkthrough.md
    guides/03-host-integration.md
    guides/04-troubleshooting.md
    guides/05-mcp-clients.md
    guides/06-extending.md
    guides/07-auth-and-operator-identity.md
  )
]
```

### LiveView Session MFA for Operator Identity

```elixir
# Source: guides/07-auth-and-operator-identity.md and Phoenix LiveView docs
# [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]
Cairnloop.Router.cairnloop_dashboard "/",
  on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
  session: {MyAppWeb.UserAuth, :cairnloop_session, []}
```

### Asset Reference Scan Pattern

```bash
# Source: research shell scan [VERIFIED: shell file-existence scan]
rg -o -N '\\]\\((assets/[^)# ]+)\\)' guides |
  sed -E 's/.*\\]\\((assets\\/[^)# ]+)\\).*/\\1/' |
  sort -u
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Docker demo buried behind host-app install. | README/Quickstart lead with `./bin/demo`, printed URLs, dynamic ports, Trailmark seed data, and `./bin/demo smoke`. [VERIFIED: codebase grep] | vM018 / Phase 55. [VERIFIED: ROADMAP.md] | Preserve evaluation-first adoption path. [VERIFIED: 60-CONTEXT.md] |
| Public-schema install guidance with `nil` / `--prefix`. | Dedicated `cairnloop` default plus explicit `"public"` compatibility, no dependency `--prefix` shortcut. [VERIFIED: 60-CONTEXT.md] | vM019 / Phase 59. [VERIFIED: ROADMAP.md] | Phase 60 must make public docs consistent with installer and UPGRADING. [VERIFIED: codebase grep] |
| `SECURITY.md` as internal artifact risk. | Current `SECURITY.md` is public-facing with support, reporting, scope, and response posture. [VERIFIED: codebase grep] | vM019 context already present. [VERIFIED: 60-CONTEXT.md] | Polish and source-scan, do not convert to corporate ceremony. [VERIFIED: 60-CONTEXT.md] |
| Package/docs trust by release workflow only. | Add DB-free source-scan docs tests plus `mix ci.quality` Hex/ExDoc checks. [VERIFIED: 60-CONTEXT.md] [VERIFIED: mix.exs] | Phase 60 scope. [VERIFIED: 60-CONTEXT.md] | Makes docs drift fail before release. [VERIFIED: 60-CONTEXT.md] |

**Deprecated/outdated:**

- `config :cairnloop, :schema_prefix, nil` as recommended public compatibility is outdated; use explicit `"public"` and mention `nil` only as legacy accepted compatibility. [VERIFIED: 60-CONTEXT.md]
- `mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop` as install guidance is outdated; use ordered host migration then dependency migration without `--prefix`. [VERIFIED: 60-CONTEXT.md]
- Missing `guides/assets/02-operator-inbox.png` reference is stale and must be corrected or the asset restored. [VERIFIED: shell file-existence scan]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No new external package should be introduced for Phase 60. This is based on phase scope and current context, not an explicit "never add packages" user sentence. [ASSUMED] | Standard Stack / Package Legitimacy Audit | If wrong, planner must run package-legitimacy checks before any install task. |

## Open Questions (RESOLVED)

1. **Should the missing `02-operator-inbox.png` be restored or should the guide reference change to an existing asset such as `02b-operator-inbox.png`?**
   - What we know: `guides/02-jtbd-walkthrough.md` references `assets/02-operator-inbox.png`, and that file is absent. [VERIFIED: shell file-existence scan]
   - What's unclear: Whether the current intended screenshot is the existing `02b-operator-inbox.png` or a deleted/uncaptured asset. [VERIFIED: shell file-existence scan]
   - Recommendation: Planner should assign a docs/assets task to choose the lowest-risk fix by comparing guide copy to existing asset names; no owner escalation is needed. [VERIFIED: CLAUDE.md]
   - **RESOLVED:** Retarget the missing JTBD walkthrough image reference to `guides/assets/02b-operator-inbox.png`; Plan 60-03 Task 1 owns the doc reference update and package-docs asset guardrail.

2. **Should Phase 60 run `mix ci.integration`?**
   - What we know: Context says run integration only if implementation touches DB-backed behavior or a docs claim needs runtime prefix proof. [VERIFIED: 60-CONTEXT.md]
   - What's unclear: Whether the planner will choose to add any DB-backed proof beyond source scans. [VERIFIED: research scope]
   - Recommendation: Default to targeted docs tests, `mix ci.fast`, and `mix ci.quality`; add `mix ci.integration` only for DB-behavior edits. [VERIFIED: 60-CONTEXT.md]
   - **RESOLVED:** Run `mix ci.integration` only if execution edits DB-backed behavior or needs runtime prefix proof; the default Phase 60 closeout remains targeted docs tests, `mix ci.fast`, and `mix ci.quality`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | compile/tests/docs | yes | 1.19.5 / OTP 28 [VERIFIED: shell version probe] | none |
| Mix | aliases, Hex, ExDoc | yes | 1.19.5 [VERIFIED: shell version probe] | none |
| Hex CLI | package info/build/publish dry-run | yes | `mix hex.info cairnloop` succeeded with expired-auth warning for public package. [VERIFIED: Hex CLI] | unauthenticated public reads work; publishing requires credentials. |
| Git | source scans/status | yes | 2.41.0 [VERIFIED: shell version probe] | none |
| Docker / Compose | demo smoke if needed | yes | Docker 29.5.2, Compose v5.1.3 [VERIFIED: shell version probe] | skip unless demo smoke/doc claim needs runtime proof. |
| Node / npm | screenshot refresh tool | yes | Node 22.14.0, npm 11.1.0 [VERIFIED: shell version probe] | avoid screenshot refresh unless necessary. |
| xmllint | SVG/package collateral tests | yes | libxml 2.9.13 [VERIFIED: shell version probe] | skip SVG-specific tests only if not touching collateral. |
| psql | manual DB inspection | yes | PostgreSQL client 14.17 [VERIFIED: shell version probe] | not needed for default docs-only plan. |
| ctx7 | Context7 CLI fallback | no | not found [VERIFIED: shell version probe] | used official web docs via built-in web search. [VERIFIED: research protocol] |

**Missing dependencies with no fallback:**

- None for a docs/package/source-scan Phase 60 plan. [VERIFIED: shell version probe]

**Missing dependencies with fallback:**

- `ctx7` is missing; official docs were fetched via web search/open and tagged `CITED`. [VERIFIED: shell version probe]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix; local Mix 1.19.5. [VERIFIED: shell version probe] |
| Config file | `mix.exs` aliases and `test/test_helper.exs`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/cairnloop/tasks/install_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/docs_trust_test.exs test/cairnloop/demo_runtime_contract_test.exs test/cairnloop/web/collateral_wiring_test.exs --exclude integration --warnings-as-errors` [VERIFIED: codebase grep] |
| Full suite command | `mix ci.fast && mix ci.quality` [VERIFIED: 60-CONTEXT.md] [VERIFIED: mix.exs] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| DOC-01 | README problem/use/not-use/fastest path and no stale version/config claims. [VERIFIED: .planning/REQUIREMENTS.md] | source-scan | `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors` plus new Wave 0 README trust scan. [VERIFIED: codebase grep] | partial; new Wave 0 needed. [VERIFIED: codebase grep] |
| DOC-02 | Installer output matches version, repo config, ordered migrations. [VERIFIED: .planning/REQUIREMENTS.md] | source-scan | `mix test test/cairnloop/tasks/install_test.exs --warnings-as-errors` [VERIFIED: codebase grep] | yes. [VERIFIED: codebase grep] |
| DOC-03 | Guides, MCP, extending, troubleshooting, example README, ExDoc groups/package guides match code paths. [VERIFIED: .planning/REQUIREMENTS.md] | source-scan + docs build | `mix test test/cairnloop/docs_trust_test.exs test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors && mix docs --warnings-as-errors` [VERIFIED: codebase grep] [VERIFIED: mix.exs] | partial; new Wave 0 needed for prefix/package/assets. [VERIFIED: codebase grep] |
| DOC-04 | `SECURITY.md` is a public policy. [VERIFIED: .planning/REQUIREMENTS.md] | source-scan | New docs trust test should assert supported versions, private reporting, host responsibilities, and no internal phase language. [VERIFIED: codebase grep] | no dedicated test yet. [VERIFIED: codebase grep] |
| DOC-05 | `UPGRADING.md` covers versioning, prefix migration choices, rollback, compatibility. [VERIFIED: .planning/REQUIREMENTS.md] | source-scan | New upgrade docs test should scan `UPGRADING.md`, README, Quickstart, Troubleshooting for aligned prefix/migration story. [VERIFIED: 60-CONTEXT.md] | no dedicated test yet. [VERIFIED: codebase grep] |
| DOC-06 | Package metadata, changelog, examples, screenshots/assets are current. [VERIFIED: .planning/REQUIREMENTS.md] | source-scan + package/docs build | `mix test test/cairnloop/web/collateral_wiring_test.exs --warnings-as-errors && mix hex.build && mix docs --warnings-as-errors` [VERIFIED: codebase grep] [VERIFIED: mix.exs] | partial; asset-link scan missing. [VERIFIED: shell file-existence scan] |

### Sampling Rate

- **Per task commit:** targeted source-scan test for touched surface. [VERIFIED: 60-CONTEXT.md]
- **Per wave merge:** `mix ci.fast` for headless docs/source changes; `mix ci.quality` for package/docs surfaces. [VERIFIED: 60-CONTEXT.md] [VERIFIED: mix.exs]
- **Phase gate:** `mix ci.fast && mix ci.quality`, and `mix ci.integration` only if DB-backed behavior changes or a docs claim needs runtime prefix proof. [VERIFIED: 60-CONTEXT.md]

### Wave 0 Gaps

- [ ] `test/cairnloop/docs/install_upgrade_truth_test.exs` - scans README, Quickstart, Troubleshooting, Host Integration, UPGRADING, and example README for unified schema-prefix and migration guidance. [VERIFIED: 60-CONTEXT.md]
- [ ] `test/cairnloop/docs/package_docs_truth_test.exs` - compares docs dependency snippets to `Mix.Project.config()[:version]`, checks `mix.exs` package files vs ExDoc extras, and rejects missing Markdown asset references. [VERIFIED: 60-CONTEXT.md]
- [ ] `test/cairnloop/docs/security_policy_test.exs` - asserts `SECURITY.md` is public-facing and does not contain internal phase/process language. [VERIFIED: .planning/REQUIREMENTS.md]
- [ ] Extend existing MCP/docs trust scans if guides/05 or guides/06 edits introduce new module/API references. [VERIFIED: codebase grep]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement: false`. [VERIFIED: .planning/config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Docs must preserve host-owned auth and explicit MCP/widget/email auth seams. [VERIFIED: 60-CONTEXT.md] |
| V3 Session Management | yes | Docs should teach LiveView session MFA for per-request operator identity and warn against static maps. [VERIFIED: guides/07-auth-and-operator-identity.md] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] |
| V4 Access Control | yes | Docs must state Cairnloop does not replace host route authorization. [VERIFIED: 60-CONTEXT.md] |
| V5 Input Validation | yes | Schema-prefix docs should align with `Cairnloop.SchemaPrefix` single-identifier validation and avoid arbitrary SQL interpolation. [VERIFIED: codebase grep] |
| V6 Cryptography | yes | MCP docs should accurately describe raw token storage as SHA-256 hashed and avoid claiming a fixed raw token prefix. [VERIFIED: docs_trust_test.exs] |

OWASP ASVS is a web application security verification standard that provides a basis for testing technical security controls. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Known Threat Patterns for Cairnloop Docs/Installer Trust

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale install docs tell adopters to use broad `--prefix`, moving migrator bookkeeping unexpectedly. [VERIFIED: 60-CONTEXT.md] | Tampering | Source-scan docs for forbidden command and teach source-qualified migrations. [VERIFIED: 60-CONTEXT.md] |
| Static dashboard session copied into production docs. [VERIFIED: guides/07-auth-and-operator-identity.md] | Spoofing | Use MFA session examples and label static maps demo-only. [VERIFIED: guides/07-auth-and-operator-identity.md] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] |
| Overstated `/health` readiness claim hides DB/Oban/pgvector/MCP/Scrypath failures. [VERIFIED: docs_trust_test.exs] | Information Disclosure / Denial of Service | Keep `/health` liveness-only and point readiness to doctor. [VERIFIED: docs_trust_test.exs] |
| Security reports posted publicly with exploit details. [CITED: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository] | Information Disclosure | `SECURITY.md` should point reporters to private vulnerability reporting and include affected version/config details. [VERIFIED: SECURITY.md] [CITED: https://docs.github.com/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories] |
| Missing docs assets weaken trust and break HexDocs walkthrough. [VERIFIED: shell file-existence scan] | Repudiation | Add asset-link source scan and fix missing file/reference before package build. [VERIFIED: shell file-existence scan] |

## Sources

### Primary (HIGH confidence)

- `CLAUDE.md` - decision policy, verification lanes, architecture posture, UI instructions. [VERIFIED: codebase grep]
- `AGENTS.md` and `examples/cairnloop_example/AGENTS.md` - project and example-app constraints. [VERIFIED: codebase grep]
- `.planning/phases/60-installer-docs-upgrade-and-oss-trust/60-CONTEXT.md` - locked decisions and deferred scope. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` - DOC-01 through DOC-06 requirement text. [VERIFIED: codebase grep]
- `.planning/ROADMAP.md` and `.planning/STATE.md` - Phase 60 scope and Phase 59 completion context. [VERIFIED: codebase grep]
- `mix.exs` - version, deps, package files, docs extras/assets/groups, aliases. [VERIFIED: codebase grep]
- `lib/mix/tasks/cairnloop/install.ex` - installer dependency, migration, prefix, and next-step notice. [VERIFIED: codebase grep]
- `lib/cairnloop/schema_prefix.ex`, `lib/cairnloop/doctor.ex`, `lib/cairnloop.ex` - schema-prefix, doctor, root docs truth. [VERIFIED: codebase grep]
- Existing source-scan tests under `test/cairnloop/tasks/install_test.exs`, `test/cairnloop/docs_trust_test.exs`, `test/cairnloop/docs/docker_first_docs_test.exs`, `test/cairnloop/demo_runtime_contract_test.exs`, and `test/cairnloop/web/collateral_wiring_test.exs`. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- ExDoc mix docs task - groups for extras/modules and source URL options. [CITED: https://hexdocs.pm/ex_doc/0.28.2/Mix.Tasks.Docs.html]
- Hex build/publish docs - package files, build/unpack, docs generation, dry run. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- Igniter docs - Mix task behavior, dependency helper, Ecto migration helper, notices. [CITED: https://hexdocs.pm/igniter/Igniter.Mix.Task.html] [CITED: https://hexdocs.pm/igniter/Igniter.Project.Deps.html] [CITED: https://hexdocs.pm/igniter/Igniter.Libs.Ecto.html] [CITED: https://hexdocs.pm/igniter/Igniter.html]
- Ecto SQL docs - migration tracking, prefixes, migrator tasks. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html]
- Phoenix LiveView Router docs - `live_session` session MFA and security considerations. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]
- GitHub security policy and repository advisory docs. [CITED: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository] [CITED: https://docs.github.com/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories]
- OWASP ASVS project page. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Tertiary (LOW confidence)

- None used as a planning basis except A1 in Assumptions Log. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH for local version/dependency/package facts; MEDIUM for official docs fetched through websearch because Context7/ctx7 was unavailable. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]
- Architecture: HIGH because responsibility map follows locked phase context and source tree. [VERIFIED: 60-CONTEXT.md]
- Pitfalls: HIGH for drift already observed in README/Quickstart/Troubleshooting/assets; MEDIUM for external OSS security-policy norms. [VERIFIED: codebase grep] [CITED: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository]

**Research date:** 2026-06-30
**Valid until:** 2026-07-30 for repo-source surfaces; re-check external docs and Hex package metadata before release. [ASSUMED]
