---
phase: 60-installer-docs-upgrade-and-oss-trust
verified: 2026-06-30T20:06:01Z
status: passed
score: 9/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 60: Installer, Docs, Upgrade, and OSS Trust Verification Report

**Phase Goal:** Make the public adoption path truthful, current, skimmable, and supportable.
**Verified:** 2026-06-30T20:06:01Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | README and guides explain the problem, when to use/not use Cairnloop, install/config/migration steps, first useful example, troubleshooting, compatibility, and production notes. | VERIFIED | `README.md` has problem framing, "When not to use Cairnloop", Docker demo first, host install, schema-prefix config, migration order, guide links, and production notes. `guides/01-quickstart.md`, `guides/03-host-integration.md`, `guides/04-troubleshooting.md`, and `examples/cairnloop_example/README.md` carry the same install/troubleshooting story. `install_upgrade_truth_test` and `docker_first_docs_test` passed. |
| 2 | Installer output, generated deps/config/migration instructions, ExDoc, MCP/extending guides, and example docs match live code and current package version. | VERIFIED | `lib/mix/tasks/cairnloop/install.ex` derives `@cairnloop_version` from `Mix.Project.config()[:version]`, emits `"cairnloop"` and `"public"` prefix guidance, and omits the dependency migration `--prefix` shortcut. `mix.exs` version is `0.5.1`; README/Quickstart snippets match. MCP/auth/extending guides are source-scanned against router/AuthPlug/behavior modules. |
| 3 | `SECURITY.md`, `UPGRADING.md`, CHANGELOG/package metadata, and public trust signals are suitable for a real OSS library without corporate ceremony. | VERIFIED | `SECURITY.md` is public-facing with supported versions, private reporting, scope, host responsibilities, and response posture. `UPGRADING.md` covers compatibility, schema-prefix choices, data move, verification, and rollback. `mix.exs` includes public docs/package files and ExDoc assets. `CHANGELOG.md` has current Unreleased docs/package/security trust notes. `mix ci.quality` passed. |
| 4 | DOC-01: README explains problem, fit/non-fit, fastest first success path, and avoids stale version/config claims. | VERIFIED | README contains "What Cairnloop Is For", "When not to use Cairnloop", `./bin/demo`, dynamic local port guidance, Trailmark seed data, `./bin/demo smoke`, `mix igniter.install cairnloop`, and `{:cairnloop, "~> 0.5.1"}`. Tests reject stale pre-v0.5 snippets and passed. |
| 5 | DOC-02: Installer output and generated snippets match current version and setup contract, including repo config and ordered migrations. | VERIFIED | Installer source uses `Igniter.Project.Deps.add_dep({:cairnloop, "~> #{@cairnloop_version}"})`, prints `config :cairnloop, :repo`, prefix snippets, host migration first, dependency migration second, and `mix cairnloop.doctor`. `test/cairnloop/tasks/install_test.exs` passed. |
| 6 | DOC-03: Quickstart, host integration, MCP, extending, troubleshooting, example README, ExDoc groups, and package guides match code paths and public APIs. | VERIFIED | `guides/05-mcp-clients.md` matches `lib/cairnloop/web/mcp/router.ex` token-required methods and proposal-first writes. `guides/06-extending.md` matches `Cairnloop.Tool`, `Cairnloop.Embedder`, `Cairnloop.Automation.DraftGenerator`, `Cairnloop.Auditor`, and `Cairnloop.Notifier`. `guides/07-auth-and-operator-identity.md` matches `Cairnloop.Router.cairnloop_dashboard/2`. `docs_trust_test` passed. |
| 7 | DOC-04: `SECURITY.md` is a public security policy, not an internal phase artifact. | VERIFIED | `SECURITY.md` contains `Supported Versions`, `Reporting a Vulnerability`, `Scope`, host responsibilities, route/auth exposure reporting detail, and no internal `.planning`/enterprise/compliance/SLA ceremony. `security_policy_test` passed. |
| 8 | DOC-05: `UPGRADING.md` documents versioning, DB prefix migration choices, deprecations, rollback posture, and compatibility claims. | VERIFIED | `UPGRADING.md` includes the compatibility matrix, `schema_prefix: "cairnloop"` default, `schema_prefix: "public"` compatibility, maintenance-window data move, row-count/index/constraint/FK/function/trigger checks, Oban/vector host ownership, and rollback limits. `install_upgrade_truth_test` passed. |
| 9 | DOC-06: Package metadata, changelog, examples, screenshots/assets avoid stale paths, missing assets, and pre-v0.5 claims. | VERIFIED | `mix.exs` package files and ExDoc extras include README, LICENSE, SECURITY, UPGRADING, CHANGELOG, and all seven guides; ExDoc assets map `guides/assets` and `logo`. `guides/02-jtbd-walkthrough.md` references existing `assets/02b-operator-inbox.png`; asset scans passed. `mix hex.build` via `mix ci.quality` succeeded. |

**Score:** 9/9 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `README.md` | Public front door and install overview | VERIFIED | Explains purpose, fit/non-fit, Docker-first demo, host install, version, prefix, migration order, guide links, and production notes. |
| `guides/01-quickstart.md` | Detailed Docker demo and host install | VERIFIED | Preserves `./bin/demo`, printed URLs, dynamic ports, Trailmark data, smoke, Igniter install, schema-prefix settings, migrations, static assets, and auth warning. |
| `guides/02-jtbd-walkthrough.md` | Current JTBD walkthrough assets | VERIFIED | All local asset links resolve; operator inbox image points to `assets/02b-operator-inbox.png`. |
| `guides/03-host-integration.md` | Host-owned production integration | VERIFIED | States host ownership for auth, repo, operator identity, Oban, secrets, monitoring, deployment, `/health` limits, and doctor diagnostics. |
| `guides/04-troubleshooting.md` | Install/prefix/doctor troubleshooting | VERIFIED | Uses explicit `"public"` compatibility, ordered migrations, no dependency `--prefix` instruction, `/health` liveness-only, and doctor for readiness/trust checks. |
| `guides/05-mcp-clients.md` | MCP auth and governed write docs | VERIFIED | Documents AuthPlug, Bearer auth for `initialize`, `tools/list`, `tools/call`, public well-known discovery, opaque raw tokens, SHA-256 persistence, and proposal-first writes. |
| `guides/06-extending.md` | Current extension/API docs | VERIFIED | References current behavior modules and avoids unsupported API claims. |
| `guides/07-auth-and-operator-identity.md` | Host auth/operator identity contract | VERIFIED | Shows host route auth, `on_mount`, per-request session MFA, and demo-only static session warning. |
| `SECURITY.md` | Public OSS security policy | VERIFIED | Public reporting policy with supported versions, private reporting, reporter details, host responsibilities, sensitive areas, and response posture. |
| `UPGRADING.md` | Upgrade and rollback guidance | VERIFIED | Concrete prefix choice, public compatibility, data move, verification, rollback, Oban/vector boundaries, and compatibility matrix. |
| `CHANGELOG.md` | Current release-trust notes | VERIFIED | Unreleased section includes docs/install/upgrade/security/package trust work and current compare metadata. |
| `examples/cairnloop_example/README.md` | Example app adoption docs | VERIFIED | Documents Docker demo, dynamic URLs, Trailmark seed, example schema-prefix default, and explicit public compatibility. |
| `lib/cairnloop.ex` | Root module docs | VERIFIED | Replaces placeholder root docs with navigation to README, guides, UPGRADING, SECURITY, and CHANGELOG. |
| `mix.exs` | Package/ExDoc/version/quality authority | VERIFIED | Version `0.5.1`, package files, ExDoc extras/assets/groups, and `ci.fast`/`ci.quality` aliases are present. |
| Phase 60 docs tests | Source-scan guardrails | VERIFIED | `install_upgrade_truth_test`, `package_docs_truth_test`, `security_policy_test`, `docs_trust_test`, installer, Docker-first, demo runtime, and collateral tests all passed together. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `README.md` | `guides/01-quickstart.md` | Docker-first path before host install | WIRED | Both put `./bin/demo` before host-app install; source-scan order tests passed. |
| `guides/01-quickstart.md` | `lib/mix/tasks/cairnloop/install.ex` | Host install commands mirror installer notice | WIRED | Quickstart uses Igniter first, direct task as rerun path, ordered migrations, and prefix guidance matching installer output. |
| `UPGRADING.md` | `lib/cairnloop/schema_prefix.ex` | Schema-prefix modes and legacy compatibility | WIRED | Upgrade docs match default `"cairnloop"`, explicit `"public"`, and legacy `nil` compatibility in source. |
| `guides/05-mcp-clients.md` | `lib/cairnloop/web/mcp/router.ex` | Token-required JSON-RPC methods and public well-known metadata | WIRED | Router requires token for `initialize`, `tools/list`, `tools/call`; guide states the same. |
| `guides/07-auth-and-operator-identity.md` | `Cairnloop.Router.cairnloop_dashboard/2` | LiveView session MFA and host auth examples | WIRED | Automated matcher over-escaped `session: \{`, but manual grep confirms guide and router both show `session: {MyAppWeb.UserAuth, :cairnloop_session, []}`. |
| `guides/06-extending.md` | Public behavior modules | Current module/API examples | WIRED | Guide references existing Tool, Embedder, DraftGenerator, Auditor, Notifier, MCP, and host seams; `docs_trust_test` covers stale API rejection. |
| `test/cairnloop/docs/package_docs_truth_test.exs` | `mix.exs` | Version, package files, ExDoc extras/assets | WIRED | Test parses package files and docs extras/assets and compares version snippets to `Mix.Project.config()[:version]`. |
| `test/cairnloop/docs/security_policy_test.exs` | `SECURITY.md` | Public reporting/support posture assertions | WIRED | Dedicated security policy source scans passed. |
| `lib/cairnloop.ex` | README and guides | Root module guide links | WIRED | Root module docs mention README, Quickstart, Host Integration, Troubleshooting, MCP Clients, Extending, Auth/Operator Identity, UPGRADING, SECURITY, and CHANGELOG. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `test/cairnloop/docs/install_upgrade_truth_test.exs` | Public docs and installer source | `File.read!/1` over README/guides/UPGRADING/example README/installer plus `Mix.Project.config()[:version]` | Yes | FLOWING |
| `test/cairnloop/docs/package_docs_truth_test.exs` | Package files, ExDoc extras/assets, asset refs, version snippets | `mix.exs`, tracked Markdown files, `guides/assets`, `Mix.Project.config()[:version]`, `git ls-files` | Yes | FLOWING |
| `test/cairnloop/docs/security_policy_test.exs` | Security policy requirements/prohibitions | `SECURITY.md` via `File.read!/1` | Yes | FLOWING |
| `test/cairnloop/docs_trust_test.exs` | MCP/auth/extending trust claims | MCP/auth/extending guides and live source modules | Yes | FLOWING |
| Public docs | Static documentation, not rendered dynamic app data | Source-backed Markdown and ExDoc/package build | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Focused Phase 60 docs/install/package/security source scans pass | `mix test test/cairnloop/docs/install_upgrade_truth_test.exs test/cairnloop/docs/package_docs_truth_test.exs test/cairnloop/docs/security_policy_test.exs test/cairnloop/docs_trust_test.exs test/cairnloop/tasks/install_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/demo_runtime_contract_test.exs test/cairnloop/web/collateral_wiring_test.exs --exclude integration --warnings-as-errors` | 60 tests, 0 failures | PASS |
| Fast CI lane passes | `mix ci.fast` | 1198 tests, 0 failures, 81 excluded | PASS |
| Docs/package quality lane passes | `mix ci.quality` | Credo found no issues; Hex package built `cairnloop-0.5.1.tar`; ExDoc generated; deps audit completed with configured advisory ignores and reported no vulnerabilities | PASS |
| Artifact frontmatter paths are present/substantive | `gsd-tools query verify.artifacts` for 60-01 through 60-04 plans | All four plans returned `valid` | PASS |
| Key links are wired | `gsd-tools query verify.key-links` for 60-01 through 60-04 plans plus manual grep for escaped 60-04 session pattern | 11 automated links valid; 1 automated false negative manually verified | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| None | Probe discovery over phase plans/summaries and `scripts/**/tests/probe-*.sh` | No declared or conventional probes for this docs/package phase | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DOC-01 | 60-01, 60-02, 60-04 | README explains problem, fit/non-fit, fastest first success path, no stale claims. | SATISFIED | README/Quickstart content verified; stale-version/config source scans passed. |
| DOC-02 | 60-01, 60-02, 60-04 | Installer output/snippets match current version and setup contract. | SATISFIED | Installer derives version from `mix.exs`; `install_test` and `install_upgrade_truth_test` passed. |
| DOC-03 | 60-01, 60-02, 60-03, 60-04 | Guides, ExDoc groups/package guides, and public APIs match code paths. | SATISFIED | MCP/auth/extending/package/ExDoc source scans and docs build passed. |
| DOC-04 | 60-01, 60-03, 60-04 | `SECURITY.md` is a public security policy. | SATISFIED | `security_policy_test` passed; manual scan found no internal/compliance/enterprise ceremony. |
| DOC-05 | 60-01, 60-02, 60-04 | `UPGRADING.md` documents versioning, prefix choices, rollback, compatibility. | SATISFIED | Upgrade source scans passed; content includes matrix, data move, verification, rollback, Oban/vector boundaries. |
| DOC-06 | 60-01, 60-03, 60-04 | Package metadata, changelog, examples, screenshots/assets have no stale paths or pre-v0.5 claims. | SATISFIED | Package/asset/version source scans passed; `mix hex.build` and ExDoc generation passed. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| None | - | - | - | No blocker debt markers found. `TBD` scan hits were the `JTBD` acronym; placeholder matches were intentional docs warnings, not unfinished implementation. |

### Human Verification Required

None. Phase policy and validation artifacts state Phase 60 deliverables should be proven by automated source scans, docs build, package build, and focused ExUnit tests. The verifier did not find a visual/runtime behavior that requires separate UAT for this docs/package phase.

### Gaps Summary

No blocking gaps found. The phase goal is achieved: the public adoption path is source-backed, current with v0.5.1, installer-aligned, package/ExDoc-buildable, and covered by durable docs/package/security source scans.

---

_Verified: 2026-06-30T20:06:01Z_
_Verifier: the agent (gsd-verifier)_
