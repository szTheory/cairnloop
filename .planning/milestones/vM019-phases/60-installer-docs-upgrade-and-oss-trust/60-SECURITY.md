---
phase: 60-installer-docs-upgrade-and-oss-trust
status: secured
threats_total: 17
threats_open: 0
verified: 2026-06-30
asvs_level: 1
block_on: open
---

# Phase 60 - Security

Per-phase security contract: verify every plan-time STRIDE threat by disposition against code,
tests, package metadata, docs, and phase evidence. This audit verified mitigations only; it did not
perform a fresh vulnerability scan beyond the plan register and summary threat flags.

## Audit Scope

- Plans audited: `60-01-PLAN.md`, `60-02-PLAN.md`, `60-03-PLAN.md`, `60-04-PLAN.md`.
- Register origin: plan-time `<threat_model>` blocks.
- Threat count: 17 unique threat IDs. `T-60-SC` appears in all four plan registers with the same
  accepted no-new-dependency disposition and is tracked once by ID.
- Config: `.planning/config.json` has no explicit ASVS or block-on security setting; this artifact
  uses the project default ASVS level 1 and blocks on open threats.
- Summary threat flags: none in all four summaries
  (`60-01-SUMMARY.md:101`, `60-02-SUMMARY.md:133`, `60-03-SUMMARY.md:124`,
  `60-04-SUMMARY.md:128`).

## Threat Verification

| Threat ID | Category | Component | Disposition | Status | Evidence |
|-----------|----------|-----------|-------------|--------|----------|
| T-60-01 | Tampering | install docs source scans | mitigate | closed | Install/upgrade source scan rejects stale public-prefix recommendations and dependency `--prefix` migration instructions: `test/cairnloop/docs/install_upgrade_truth_test.exs:109`, `test/cairnloop/docs/install_upgrade_truth_test.exs:142`, `test/cairnloop/docs/install_upgrade_truth_test.exs:287`. Installer warning and generated command are pinned: `lib/mix/tasks/cairnloop/install.ex:138`, `lib/mix/tasks/cairnloop/install.ex:141`. |
| T-60-02 | Repudiation | package/docs source scans | mitigate | closed | Package, ExDoc, version, changelog, and asset guardrails are present: `test/cairnloop/docs/package_docs_truth_test.exs:51`, `test/cairnloop/docs/package_docs_truth_test.exs:76`, `test/cairnloop/docs/package_docs_truth_test.exs:101`, `test/cairnloop/docs/package_docs_truth_test.exs:119`. `mix.exs` is the package/ExDoc authority: `mix.exs:24`, `mix.exs:51`, `mix.exs:67`. |
| T-60-03 | Information Disclosure | SECURITY.md reporting guidance | mitigate | closed | Public policy test requires private reporting and rejects public exploit ceremony: `test/cairnloop/docs/security_policy_test.exs:14`, `test/cairnloop/docs/security_policy_test.exs:71`, `test/cairnloop/docs/security_policy_test.exs:80`. Policy tells reporters not to put working exploit details in public issues: `SECURITY.md:8`, `SECURITY.md:11`. |
| T-60-04 | Denial of Service | docs quality gates | mitigate | closed | Guardrail tests are explicitly DB-free and avoid Repo/Docker/Phoenix/browser/network startup: `test/cairnloop/docs/install_upgrade_truth_test.exs:3`, `test/cairnloop/docs/install_upgrade_truth_test.exs:5`, `test/cairnloop/docs/package_docs_truth_test.exs:3`, `test/cairnloop/docs/package_docs_truth_test.exs:6`, `test/cairnloop/docs/security_policy_test.exs:3`, `test/cairnloop/docs/security_policy_test.exs:5`. Final focused source scans and CI lanes passed: `60-VERIFICATION.md:83`, `60-VERIFICATION.md:84`, `60-VERIFICATION.md:85`. |
| T-60-05 | Tampering | README/Quickstart/Troubleshooting migration commands | mitigate | closed | Public-doc source scan rejects the forbidden dependency migration prefix: `test/cairnloop/docs/install_upgrade_truth_test.exs:29`, `test/cairnloop/docs/install_upgrade_truth_test.exs:142`. README, Quickstart, Troubleshooting, and installer show ordered migrations without the broad dependency `--prefix` shortcut and warning text: `README.md:78`, `README.md:79`, `guides/01-quickstart.md:145`, `guides/01-quickstart.md:148`, `guides/01-quickstart.md:156`, `guides/04-troubleshooting.md:305`, `guides/04-troubleshooting.md:306`, `guides/04-troubleshooting.md:313`, `lib/mix/tasks/cairnloop/install.ex:138`, `lib/mix/tasks/cairnloop/install.ex:139`, `lib/mix/tasks/cairnloop/install.ex:141`. |
| T-60-06 | Spoofing | Host auth/operator identity docs | mitigate | closed | Host responsibility and operator identity injection are explicit in docs and pinned by source scans: `guides/03-host-integration.md:16`, `guides/07-auth-and-operator-identity.md:69`, `guides/07-auth-and-operator-identity.md:96`, `guides/07-auth-and-operator-identity.md:140`, `test/cairnloop/docs_trust_test.exs:67`, `test/cairnloop/docs_trust_test.exs:74`. |
| T-60-07 | Denial of Service | Upgrade data-move guidance | mitigate | closed | UPGRADING documents explicit public compatibility, backups, maintenance window, data move, verification, smoke checks, and rollback posture: `UPGRADING.md:37`, `UPGRADING.md:45`, `UPGRADING.md:57`, `UPGRADING.md:89`. Source scans require the same upgrade and rollback boundaries: `test/cairnloop/docs/install_upgrade_truth_test.exs:211`, `test/cairnloop/docs/install_upgrade_truth_test.exs:231`. |
| T-60-08 | Information Disclosure | Troubleshooting/doctor docs | mitigate | closed | Health is documented as liveness only and richer readiness goes to doctor: `guides/03-host-integration.md:296`, `guides/03-host-integration.md:303`. The docs trust test rejects overclaims about health checking DB, Oban, pgvector, notifier, MCP, or Scrypath: `test/cairnloop/docs_trust_test.exs:127`, `test/cairnloop/docs_trust_test.exs:142`. |
| T-60-09 | Repudiation | JTBD guide assets | mitigate | closed | The JTBD walkthrough points to the existing operator inbox asset, and the package docs test asserts both positive and negative asset targets: `guides/02-jtbd-walkthrough.md:44`, `test/cairnloop/docs/package_docs_truth_test.exs:119`, `test/cairnloop/docs/package_docs_truth_test.exs:141`, `test/cairnloop/docs/package_docs_truth_test.exs:142`. |
| T-60-10 | Tampering | mix.exs package files and ExDoc extras | mitigate | closed | `mix.exs` includes the public docs in package files, ExDoc extras, and assets: `mix.exs:24`, `mix.exs:31`, `mix.exs:32`, `mix.exs:51`, `mix.exs:57`, `mix.exs:59`, `mix.exs:61`, `mix.exs:67`. Source scans assert the package files and ExDoc extras: `test/cairnloop/docs/package_docs_truth_test.exs:51`, `test/cairnloop/docs/package_docs_truth_test.exs:76`. |
| T-60-11 | Information Disclosure | SECURITY.md vulnerability reporting | mitigate | closed | SECURITY.md tells reporters to use private reporting and not put working exploit details in a public issue: `SECURITY.md:8`, `SECURITY.md:11`. The security policy guardrail requires those sections and rejects public-exploit disclosure instructions: `test/cairnloop/docs/security_policy_test.exs:14`, `test/cairnloop/docs/security_policy_test.exs:72`. |
| T-60-12 | Spoofing | public package trust metadata | mitigate | closed | Version and changelog claims are source-backed by `mix.exs` and source scans: `mix.exs:7`, `test/cairnloop/docs/package_docs_truth_test.exs:101`, `test/cairnloop/docs/package_docs_truth_test.exs:145`, `CHANGELOG.md:13`, `CHANGELOG.md:128`. |
| T-60-13 | Spoofing | guides/07-auth-and-operator-identity.md | mitigate | closed | Auth guide teaches host route auth plus per-request session MFA and labels static session maps demo-only: `guides/07-auth-and-operator-identity.md:69`, `guides/07-auth-and-operator-identity.md:96`, `guides/07-auth-and-operator-identity.md:122`, `guides/07-auth-and-operator-identity.md:140`. Guardrail pins both requirements: `test/cairnloop/docs_trust_test.exs:67`, `test/cairnloop/docs_trust_test.exs:74`. |
| T-60-14 | Information Disclosure | guides/05-mcp-clients.md | mitigate | closed | MCP router runs AuthPlug, requires token assignment before token-required methods, gates `initialize`, `tools/list`, and `tools/call`, and routes writes through proposals: `lib/cairnloop/web/mcp/router.ex:49`, `lib/cairnloop/web/mcp/router.ex:55`, `lib/cairnloop/web/mcp/router.ex:70`, `lib/cairnloop/web/mcp/router.ex:107`. MCP guide documents Bearer auth, public discovery boundary, opaque copy-once tokens, proposal-first writes, and 401 fail-closed behavior: `guides/05-mcp-clients.md:11`, `guides/05-mcp-clients.md:24`, `guides/05-mcp-clients.md:33`, `guides/05-mcp-clients.md:78`, `guides/05-mcp-clients.md:82`. |
| T-60-15 | Tampering | guides/06-extending.md | mitigate | closed | Extending guide aligns with current governed tool and behavior module seams, including proposal-first writes and worker-only `run/3`: `guides/06-extending.md:21`, `guides/06-extending.md:80`, `guides/06-extending.md:83`, `guides/06-extending.md:94`, `guides/06-extending.md:125`, `guides/06-extending.md:143`. Source scans reject stale API shapes and assert current callbacks: `test/cairnloop/docs_trust_test.exs:100`, `test/cairnloop/docs_trust_test.exs:112`. |
| T-60-16 | Repudiation | final verification evidence | mitigate | closed | Final verification records focused source scans, `mix ci.fast`, and `mix ci.quality` passing: `60-VERIFICATION.md:83`, `60-VERIFICATION.md:84`, `60-VERIFICATION.md:85`. Plan 60-04 summary also records `mix ci.fast` and `mix ci.quality` pass evidence: `60-04-SUMMARY.md:89`, `60-04-SUMMARY.md:90`. |
| T-60-SC | Tampering | package installs | accept | closed (accepted) | Accepted risk documented below. All four summaries declare no added tech stack dependency: `60-01-SUMMARY.md:17`, `60-02-SUMMARY.md:20`, `60-03-SUMMARY.md:16`, `60-04-SUMMARY.md:19`. Final threat flags state no external dependency was introduced: `60-04-SUMMARY.md:130`. |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Evidence | Accepted By | Date |
|---------|------------|-----------|----------|-------------|------|
| AR-60-01 | T-60-SC | The plan explicitly accepted the no-new-package-install supply-chain item because Phase 60 used existing Mix/ExUnit/ExDoc/Hex tooling and did not add dependency-install tasks. Any future new dependency or lockfile/package-manager churn must be threat-modeled separately. | `60-01-SUMMARY.md:17`, `60-02-SUMMARY.md:20`, `60-03-SUMMARY.md:16`, `60-04-SUMMARY.md:19`, `60-04-SUMMARY.md:130` | the agent | 2026-06-30 |

## Unregistered Flags

None. All four summary `## Threat Flags` sections report no new endpoint, auth path, file access
pattern, schema boundary, runtime side effect, or external dependency:

- `60-01-SUMMARY.md:101`
- `60-02-SUMMARY.md:133`
- `60-03-SUMMARY.md:124`
- `60-04-SUMMARY.md:128`

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-30 | 17 | 17 | 0 | the agent (inline gsd-secure-phase verification) |

## Sign-Off

- [x] All plan-time threats classified by disposition.
- [x] All `mitigate` dispositions verified against code, docs, package metadata, tests, or phase evidence.
- [x] Accepted risk documented in the accepted risks log.
- [x] Summary threat flags incorporated.
- [x] `threats_open: 0` confirmed.
