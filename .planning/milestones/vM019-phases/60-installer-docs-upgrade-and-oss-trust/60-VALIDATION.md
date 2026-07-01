---
phase: 60
slug: installer-docs-upgrade-and-oss-trust
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-30
---

# Phase 60 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5; source-scan docs/package tests and ExDoc/package build checks |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/cairnloop/tasks/install_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/docs_trust_test.exs test/cairnloop/demo_runtime_contract_test.exs test/cairnloop/web/collateral_wiring_test.exs --exclude integration --warnings-as-errors` |
| **Full suite command** | `mix ci.fast && mix ci.quality`; add `mix ci.integration` only if execution edits DB-backed behavior or needs runtime prefix proof |
| **Estimated runtime** | ~60-180 seconds for focused docs/package scans; full lanes vary by local DB/docs build state |

---

## Sampling Rate

- **After every task commit:** Run the focused source-scan or docs/package test for the touched surface plus `mix compile --warnings-as-errors` when code changes.
- **After every plan wave:** Run `mix ci.fast`; add `mix ci.quality` for waves that touch README, guides, ExDoc extras/assets, package metadata, changelog, security policy, or upgrade docs.
- **Before `/gsd:verify-work`:** Run `mix ci.fast && mix ci.quality`; add `mix ci.integration` only if implementation changed DB-backed behavior or requires live Postgres proof for a documentation claim.
- **Max feedback latency:** Prefer focused ExUnit source scans under 180 seconds before broader CI lanes.

---

## Per-Requirement Verification Map

| Requirement | Expected Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|-------------------|-----------|-------------------|-------------|--------|
| DOC-01 | README and guides explain the problem, use/not-use fit, fastest install path, first useful example, production notes, and no stale version/config claims. | source-scan + docs review | `mix test test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/docs/install_upgrade_truth_test.exs --warnings-as-errors` | partial - Wave 0 | pending |
| DOC-02 | Installer output, generated dependency/config/migration instructions, and next steps match current package version and Phase 59 dedicated-schema contract. | installer source-scan | `mix test test/cairnloop/tasks/install_test.exs test/cairnloop/docs/install_upgrade_truth_test.exs --warnings-as-errors` | partial - Wave 0 | pending |
| DOC-03 | ExDoc extras, host integration, MCP/extending guides, troubleshooting, examples, and module/API references match live code paths and public behavior. | source-scan + docs build | `mix test test/cairnloop/docs_trust_test.exs test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors && mix docs --warnings-as-errors` | partial - Wave 0 | pending |
| DOC-04 | `SECURITY.md` is a public OSS policy with supported versions, private reporting guidance, host responsibilities, and no internal planning/process language. | source-scan | `mix test test/cairnloop/docs/security_policy_test.exs --warnings-as-errors` | no - Wave 0 | pending |
| DOC-05 | `UPGRADING.md`, README, Quickstart, Troubleshooting, and example docs present one coherent prefix/migration/rollback/compatibility story. | source-scan | `mix test test/cairnloop/docs/install_upgrade_truth_test.exs --warnings-as-errors` | no - Wave 0 | pending |
| DOC-06 | Package metadata, changelog, HexDocs extras/assets, example docs, screenshot references, and public trust signals are current and buildable. | source-scan + package/docs build | `mix test test/cairnloop/docs/package_docs_truth_test.exs test/cairnloop/web/collateral_wiring_test.exs --warnings-as-errors && mix hex.build && mix docs --warnings-as-errors` | partial - Wave 0 | pending |

---

## Wave 0 Requirements

- [ ] `test/cairnloop/docs/install_upgrade_truth_test.exs` - scans README, Quickstart, Troubleshooting, Host Integration, `UPGRADING.md`, installer output expectations, and example README for one aligned schema-prefix and migration story.
- [ ] `test/cairnloop/docs/package_docs_truth_test.exs` - compares dependency snippets to `Mix.Project.config()[:version]`, checks `mix.exs` package files against ExDoc extras/assets, and rejects missing Markdown asset references.
- [ ] `test/cairnloop/docs/security_policy_test.exs` - asserts `SECURITY.md` is public-facing, includes private reporting and supported-version guidance, states host responsibilities, and omits internal phase/process language.
- [ ] Extend `test/cairnloop/tasks/install_test.exs` if installer-generated text or Mix task output changes, especially dependency, config, migration ordering, source-qualified migration, and rollback guidance.
- [ ] Extend `test/cairnloop/docs_trust_test.exs` if MCP, extending, auth/operator identity, health/doctor, or module/API guide edits introduce new claims.

---

## Manual-Only Verifications

All Phase 60 deliverables should have automated proof through source scans, docs build, package build, or focused ExUnit tests. Manual review is limited to confirming public-facing copy is calm, truthful, skimmable, and not framed as internal planning process.

---

## Validation Sign-Off

- [x] All phase requirements have an automated verification target or Wave 0 dependency.
- [x] Sampling continuity avoids long stretches without focused automated feedback.
- [x] Wave 0 names missing docs/package/security source-scan files before trust-content edits proceed.
- [x] No watch-mode flags are required.
- [x] Feedback latency target is under 180 seconds for focused checks.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending execution
