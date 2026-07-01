# Phase 61: CI/CD Efficiency and Release Confidence - Context

**Gathered:** 2026-06-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Keep Cairnloop's CI/CD fast, deterministic, least-privilege, and useful while preserving release
trust for an OSS Phoenix/Ecto library. This phase owns GitHub Actions workflow posture, Mix CI
aliases, source-contract tests for workflow drift, CI timing/cache/failure evidence, release
publish preflight, and the docs that explain those gates.

This is not a product-surface phase, not a runtime trust-boundary phase, not a schema-prefix phase,
and not broad public documentation cleanup. Phase 58 owns trust/ingress/side-effect runtime
behavior, Phase 59 owns the dedicated Postgres schema contract, and Phase 60 owns public
install/docs/upgrade truth.

</domain>

<decisions>
## Implementation Decisions

### Action Runtime and Workflow Contracts

- **D-01:** Refresh action runtime facts from primary sources at implementation time, then lock the
  chosen versions in DB-free workflow source-contract tests. As of this context, GitHub's Node 24
  transition is active; `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` is the official transition knob
  and `ACTIONS_RUNNER_NODE_VERSION` must not be used. Do not add
  `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`.
- **D-02:** First-party actions should use current maintained Node 24-capable majors unless primary
  release notes show a concrete incompatibility. The current local workflows already use
  `actions/checkout@v6`, `actions/setup-node@v6`, and `actions/upload-artifact@v6`; official sources
  should be re-checked during execution because `actions/cache` and `upload-artifact` have newer
  current majors than the local audit text records. If an older Node 24-ready major is kept, record
  the reason in `docs/ci-cd-audit.md` and in the workflow contract test.
- **D-03:** Add source-contract coverage for `.github/workflows/ci.yml` and
  `.github/workflows/release-please.yml`, mirroring
  `test/cairnloop/demo_smoke_workflow_contract_test.exs`. These tests should assert permissions,
  concurrency, Node 24 posture, checkout credential handling, action majors, job names, lane
  commands, release job permissions, Hex token preflight, dry run, package inspection, and Hex/HexDocs
  verification.

### Permissions, Secrets, and Checkout Credentials

- **D-04:** Keep workflow-level permissions read-only by default. Grant write permissions only to the
  `release-please` job that creates or updates release PRs. Keep `publish-hex` read-only except for
  its `HEX_API_KEY` secret, and keep publish secrets unavailable to untrusted PR code.
- **D-05:** Keep `persist-credentials: false` on every checkout unless a job demonstrably needs git
  credentials after checkout. Jobs that need to write must pass a scoped token explicitly at the
  command/action boundary instead of relying on persisted checkout credentials.
- **D-06:** Do not introduce `pull_request_target`, issue/comment-triggered release behavior, or any
  workflow that runs untrusted PR code with release, package, or write credentials.

### Gate Topology and Runner Time

- **D-07:** Keep the always-required PR/main gate small and stable: `fast`, `quality`, `integration`,
  and one aggregate required gate. `fast`, `quality`, and `integration` should continue to run by
  default on PRs because they map directly to the library's release risk model.
- **D-08:** Browser E2E should be path-gated on PRs to UI/web/static/example/E2E/workflow-relevant
  changes, and should run on `main` or manual dispatch when release confidence needs the full browser
  proof. If `e2e` becomes optional, the aggregate gate must treat a path-guarded skip as acceptable
  while still failing on actual `e2e` failure or cancellation.
- **D-09:** Docker demo smoke stays separate from `mix ci`. Keep it for wrapper/demo/docs/example
  changes, scheduled proof, manual dispatch, and release validation. Demote broad PR overlap such as
  unconditional `lib/**` and `priv/**` demo-smoke triggers unless planning finds a specific demo-only
  risk that normal CI and E2E do not cover.
- **D-10:** Preserve the local command split: `mix ci` means `ci.fast`, `ci.integration`, and
  `ci.quality`; `mix ci.full` adds example E2E; `./bin/demo smoke` remains the Docker adoption smoke.
  Do not put Docker smoke inside the default local `mix ci` alias.

### Timing, Caches, and Failure Evidence

- **D-11:** Add CI step-summary evidence that helps maintainers act without guessing: lane duration,
  Elixir/OTP/Node versions where relevant, cache hits, slowest headless tests, and E2E phase timing
  for dependency install, Playwright install, setup/migrate, and browser tests.
- **D-12:** Do not remove `_build` caches blindly. The Phase 57 audit measured a roughly 2.7s forced
  compile locally, so `_build` cache restore/save may cost more than recompilation, but Phase 61
  should first make timing visible. Remove or demote `_build` caches only when the evidence says they
  are low-value. Dependency, npm, and Playwright browser caches remain higher-value by default.
- **D-13:** Prefer cache behavior that is safe under untrusted PRs. Keep avoiding privileged PR
  triggers, keep cache keys narrow, keep cache summaries visible, and consider restore-only/cache-save
  separation only if the implementation can prove it improves security or runtime without adding
  brittle workflow complexity.

### Release Publish Confidence

- **D-14:** `publish-hex` must prove the exact release SHA before irreversible publishing. Do not rely
  only on invisible branch-protection settings. Run `mix ci.quality` or an equivalent compact release
  preflight on the checked-out release SHA before `mix hex.publish --yes`.
- **D-15:** Keep the existing release protections: release-please only from trusted `main`/manual
  contexts, `publish-hex` gated on `release_created == 'true'`, Hex token preflight before publish
  work, `mix hex.publish --dry-run`, packaged tarball top-level inspection, `mix hex.info`, and
  `mix hex.docs fetch`.
- **D-16:** Branch protection should be documented as an assumption, not the only safety mechanism.
  If release PR auto-merge remains enabled, downstream work should leave comments/tests/docs that make
  the required CI dependency visible from the repository, not only from GitHub settings.

### Artifacts and Debugging

- **D-17:** Make Playwright artifacts useful or remove them. The current workflow uploads traces while
  `PW_TRACE` is `"false"`. Prefer enabling trace/screenshot capture in CI with short retention
  (`retention-days: 3`) unless measured overhead is too high; empty artifact uploads are not useful
  release evidence.
- **D-18:** Keep generated evidence bounded. Step summaries, traces, screenshots, and packaged
  artifact inspections should help diagnose CI failures without leaking secrets, support content, or
  unnecessarily long logs.

### Claude's Discretion

- No owner-level question was escalated. `CLAUDE.md` directs GSD discuss-phase to auto-decide routine
  trust-sensitive implementation calls and surface only genuinely expensive or irreversible choices.
  Phase 61 has no such unresolved owner choice: the roadmap and Phase 57 audit already lock the
  direction as current action posture, least privilege, useful timing evidence, low-signal job
  demotion, and release preflight.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning and Requirements

- `.planning/PROJECT.md` - vM019 focus, CI evidence-backed decision policy, architectural invariants,
  current package/release context, and post-done adoption-maintenance posture.
- `.planning/REQUIREMENTS.md` - CI-02 through CI-06 are Phase 61 scope; future/out-of-scope notes
  exclude new product surface and enterprise process.
- `.planning/ROADMAP.md` - Phase 61 goal and success criteria.
- `.planning/STATE.md` - carried vM019 decisions, dirty-worktree warning, current phase state, and
  local verification expectations.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md` - confirms runtime
  trust/side-effect hardening is prior-phase scope, not Phase 61 scope.
- `.planning/phases/59-dedicated-postgres-schema-contract/59-CONTEXT.md` - confirms DB prefix runtime
  behavior is prior-phase scope, not Phase 61 scope.
- `.planning/phases/60-installer-docs-upgrade-and-oss-trust/60-CONTEXT.md` - confirms broad public
  docs/install/upgrade truth is prior-phase scope; CI workflow optimization remains Phase 61.
- `CLAUDE.md` - decision policy, warning-clean build expectations, and repo-specific GSD
  discuss-phase behavior.

### CI Audit and Docs

- `docs/ci-cd-audit.md` - primary local audit for workflows, Mix aliases, timing gaps, cache
  questions, release preflight, Playwright artifact mismatch, and proposed target pipeline.
- `docs/software-quality-evaluation.md` - vM019 audit ranking CI/CD determinism, least privilege,
  release confidence, and maintainer friction.
- `README.md` - public CI badge and contributor command references.
- `CONTRIBUTING.md` - contributor-facing local lane guidance; update only if command semantics change.

### Workflow and Release Sources

- `.github/workflows/ci.yml` - fast, quality, integration, e2e, and aggregate release gate jobs.
- `.github/workflows/demo-smoke.yml` - Docker demo smoke workflow, path filters, read-only posture,
  and wrapper delegation.
- `.github/workflows/release-please.yml` - release PR automation and Hex publish workflow.
- `.github/dependabot.yml` - weekly `github-actions` update cadence and dependency update posture.
- `mix.exs` - `ci`, `ci.full`, `ci.fast`, `ci.integration`, `ci.quality`, package docs, Hex build,
  and audit aliases.
- `test/cairnloop/demo_smoke_workflow_contract_test.exs` - existing DB-free workflow source-contract
  test pattern to reuse for CI and release workflows.

### External Primary Sources

- `https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/` -
  GitHub's Node 20 deprecation/Node 24 migration schedule and official transition variables.
- `https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/` -
  current GitHub cache least-privilege behavior for untrusted triggers.
- `https://github.com/actions/checkout/releases` - official checkout action major/version and
  credential behavior notes.
- `https://github.com/marketplace/actions/cache` - official cache action current major, Node 24
  runtime requirements, restore/save action availability, and runner minimums.
- `https://github.com/actions/setup-node/releases` - official setup-node action releases.
- `https://github.com/actions/upload-artifact/releases` - official upload-artifact action releases
  and Node 24 support notes.
- `https://github.com/googleapis/release-please-action/releases` - official release-please action
  releases.
- `https://docs.github.com/en/actions/reference/security/secure-use` - GitHub Actions secure-use
  reference for untrusted code, secrets, and third-party action posture.
- `https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching` - GitHub
  dependency caching behavior and restrictions.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `mix.exs` already has the desired local command split: `mix ci` runs fast, integration, and quality;
  `mix ci.full` adds example E2E. Keep that shape.
- `.github/workflows/ci.yml` already separates `fast`, `quality`, `integration`, `e2e`, and
  `release_gate`, uses read-only default permissions, and writes cache/version summaries.
- `.github/workflows/demo-smoke.yml` already keeps Docker behavior in `./bin/demo smoke`, uses
  read-only permissions, and avoids duplicating wrapper internals.
- `.github/workflows/release-please.yml` already scopes write permission to the release PR job and
  performs real Hex package/docs verification after release creation.
- `test/cairnloop/demo_smoke_workflow_contract_test.exs` is the model for DB-free workflow source
  contracts. Add adjacent tests instead of starting Docker or GitHub Actions locally.
- `.github/dependabot.yml` already watches `github-actions` weekly, so action major refreshes can
  be guarded by tests without inventing new update automation.

### Established Patterns

- Warnings-clean builds are mandatory: planning should keep `mix compile --warnings-as-errors` and
  `mix ci.fast` central.
- Source-contract tests are acceptable when they guard public or release contracts. Keep assertions
  specific for workflows where stale YAML would break adopter/release trust.
- DB-backed behavior stays in `mix ci.integration`; browser geometry/rendered evidence stays in the
  example E2E lane; Docker adoption proof stays in `./bin/demo smoke`.
- Release automation follows release-please, conventional commits, release PR auto-merge, and Hex
  publish from trusted refs. Improve confidence around that shape rather than replacing it.

### Integration Points

- Workflow changes connect at `.github/workflows/ci.yml`, `.github/workflows/demo-smoke.yml`, and
  `.github/workflows/release-please.yml`.
- Local command changes connect at `mix.exs`, `README.md`, `CONTRIBUTING.md`, and
  `docs/ci-cd-audit.md`.
- Guardrail tests should live under `test/cairnloop/` as DB-free ExUnit source scans unless a change
  truly needs GitHub-hosted runner proof.
- Any E2E path-gating change must also update the aggregate gate logic so branch protection has a
  stable required check.

</code_context>

<specifics>
## Specific Ideas

- Add `test/cairnloop/ci_workflow_contract_test.exs` and
  `test/cairnloop/release_workflow_contract_test.exs` rather than overloading the existing demo smoke
  contract test.
- Re-check official action releases before patching; as of 2026-06-30, local `actions/cache@v5` and
  `actions/upload-artifact@v6` may no longer be the newest maintained first-party majors even though
  they are Node 24-capable.
- Add `$GITHUB_STEP_SUMMARY` sections that include cache hits plus runtime evidence, not just version
  banners.
- Add release preflight before `mix hex.publish --yes`, preferably `mix ci.quality` unless planning
  chooses a smaller `ci.release` alias with the same docs/package/audit guarantees.
- If E2E is path-gated, make the aggregate gate explicitly understand skipped optional jobs.
- If Playwright trace artifacts are kept, set trace/screenshot env vars and short retention so the
  artifact step is not an empty ritual.

</specifics>

<deferred>
## Deferred Ideas

- Full SHA pinning of every GitHub Action plus a Renovate/Dependabot SHA-update workflow is not
  required for Phase 61. It can be revisited if the project chooses a stricter supply-chain posture.
- Self-hosted runner support beyond documenting official minimum runner versions is out of scope
  unless current workflows actually target self-hosted runners.
- Live GitHub branch-protection inspection and organization-level Actions policy changes are outside
  local repo automation. Phase 61 can document assumptions and add local preflight, but cannot prove
  private repository settings from source alone.
- New product features, hosted demo work, advanced routing, local AI, mobile SDKs, and broad UI polish
  remain outside vM019.

</deferred>

---

*Phase: 61-CI/CD Efficiency and Release Confidence*
*Context gathered: 2026-06-30*
