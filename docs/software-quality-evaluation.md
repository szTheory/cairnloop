# Software Quality Evaluation

**Milestone:** vM019 OSS Trust Baseline
**Date:** 2026-06-29
**Scope:** Repo evidence for Cairnloop as an embedded Phoenix/Ecto OSS library. This is not a feature wishlist.

## Executive Summary

Cairnloop's product substrate is stronger than its adopter trust boundary. The repo has serious
engineering assets: host-owned Ecto facades, durable governance state, bounded telemetry in several
lanes, an example app, Docker-first demo proof, split CI, release-please, Hex packaging, and a real
operator design system. The weak point is not "does the app work in the demo"; it is "can a real
Phoenix host safely install this without inheriting surprising auth, schema, migration, side-effect,
or support burdens."

The approved vM019 hypothesis holds with one adjustment. The weakest quality dimension is still
host-app compatibility/adoption trust. DB/migration hygiene is still second. Install/docs/release
truth is still third, but the current dirty worktree already contains partial remediation work:
installer output now derives its dependency version from `mix.exs`, `SECURITY.md` is public-facing,
`UPGRADING.md` exists, CI has been reshaped around Node 24-capable actions, and schema-prefix code
has started. That narrows several problems; it does not close the adoption risk until integration
and example-app proof show the behavior works end to end.

The strongest dimensions are release automation, demo proof, UI system maturity, and core governance
idempotency. CI is materially better than expected: `.github/workflows/ci.yml`,
`.github/workflows/demo-smoke.yml`, and `.github/workflows/release-please.yml` have least-privilege
defaults, job separation, caching, summary output, release dry-run, tarball inspection, and HexDocs
verification. The remaining CI risk is not "no CI"; it is whether the action/runtime posture and
checkout credential defaults are exactly what the docs claim.

Assumptions:

- "36 requested dimensions" was not defined in the checked-in Phase 57 plan. I define the 36 below
  using project-relevant OSS/library quality dimensions and mark generic/low-value ones as low
  priority where appropriate.
- I evaluated the current working tree, which is already dirty with unrelated edits. I did not
  treat earlier reads of files that changed during this audit as authoritative.
- I ran DB-free local evidence commands during the audit: `mix test --exclude integration
  --warnings-as-errors`, `mix test --exclude integration --slowest 20 --warnings-as-errors`,
  `MIX_ENV=test mix compile --force --profile time --warnings-as-errors`, and
  `mix xref graph --format cycles --label compile-connected`. I did not run DB-backed integration,
  browser E2E, Docker smoke, or live GitHub checks for this document.
- External primary-source research is concentrated in `docs/ci-cd-audit.md` and
  `docs/postgres-schema-prefix.md`; this document cites those companion artifacts for GitHub
  Actions, Ecto, and Postgres behavior.

## Dimension Ranking

Ranked weakest to strongest for adoption risk, not theoretical importance.

| Rank | Dimension | State | Confidence | Consequence | Highest-leverage fix | Priority | Evidence |
|---:|---|---|---|---|---|---|---|
| 1 | Host-app compatibility/adoption trust | Weak | High | A real host can mount flows that accept fake customer identity, leak tool metadata, or enqueue side effects unexpectedly. | Add explicit host verification seams and fail-closed defaults for widget, email, MCP, logs, telemetry, and optional automation. | Must fix | `lib/cairnloop/channels/widget_socket.ex`, `lib/cairnloop/channels/widget_channel.ex`, `lib/cairnloop/ingress/email_webhook_plug.ex`, `lib/cairnloop/web/mcp/router.ex`, `.planning/REQUIREMENTS.md` |
| 2 | DB/schema isolation and migration hygiene | Weak/partial | High | The current tree has a prefix helper and schema attributes, but dedicated-schema install/runtime behavior is not yet proven across migrations, raw SQL, example app, and public compatibility. | Complete the `cairnloop` prefix contract and prove both dedicated-schema and explicit public modes with integration/example tests. | Must fix | `lib/cairnloop/schema_prefix.ex`, `priv/repo/migrations/20260516000000_create_knowledge_base.exs`, `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs`, `lib/cairnloop/retrieval.ex` |
| 3 | Install/docs/release truth | Mixed | High | Public `SECURITY.md`, `UPGRADING.md`, installer output, and CI docs have improved, but MCP module/token docs and several operational claims still drift from code. | Make docs executable truth: MCP module/token accuracy, compatibility matrix, installer/docs drift tests, and source-backed release claims. | Must fix | `SECURITY.md`, `UPGRADING.md`, `guides/05-mcp-clients.md`, `docs/architecture.md`, `guides/02-jtbd-walkthrough.md`, `CONTRIBUTING.md` |
| 4 | Ingress authentication boundaries | Weak | High | Customer/browser, email, and MCP ingress can be misunderstood as production-secure. | Split demo behavior from production auth contracts and require configured verifiers outside dev/test. | Must fix | `lib/cairnloop/channels/widget_socket.ex`, `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`, `lib/cairnloop/ingress/email_webhook_plug.ex` |
| 5 | Optional side effects and safe defaults | Weak | High | Resolving a conversation can enqueue Scrypath indexing even when the host did not opt in. | Gate Scrypath/external automation behind explicit config with boot-time/doctor validation. | Must fix | `lib/cairnloop/application.ex`, `lib/cairnloop/workers/ingest_scrypath.ex`, `.planning/STATE.md` |
| 6 | Sensitive logs/telemetry/privacy | Weak/Mixed | High | Support content can land in logs or high-cardinality telemetry if handlers are attached. | Keep bounded metadata everywhere; remove raw email logging and full conversation/metadata telemetry from default paths. | Must fix | `lib/cairnloop/workers/process_message.ex`, `test/cairnloop/workers/process_message_test.exs`, `lib/cairnloop/chat.ex`, `lib/cairnloop/retrieval/telemetry.ex`, `lib/cairnloop/governance/telemetry.ex` |
| 7 | Upgrade path and rollback safety | Mixed/Weak | High | `UPGRADING.md` now names the dedicated-schema/public-compatibility paths, but the actual data move, public-mode runtime proof, and rollback checks are not complete. | Keep `UPGRADING.md` aligned with migration helpers/tests for public compatibility and dedicated-schema migration. | Must fix | `UPGRADING.md`, `priv/repo/migrations/20260516000000_create_knowledge_base.exs`, `.planning/REQUIREMENTS.md` |
| 8 | Production readiness / SRE diagnostics | Mixed/Weak | High | `/health` is honest liveness but not readiness; doctor misses DB/Oban/pgvector/notifier/side-effect state. | Keep `/health` shallow, add readiness/doctor checks and precise troubleshooting. | Must fix | `lib/cairnloop/web/health_plug.ex`, `lib/cairnloop/doctor.ex`, `lib/cairnloop/retrieval.ex`, `guides/04-troubleshooting.md` |
| 9 | MCP auth/resource-server behavior | Mixed/Weak | High | `tools/call` rejects missing tokens, but `initialize` and `tools/list` are exposed without auth inside the router. | Require auth for token-required methods and align docs/module names/token format. | Must fix | `lib/cairnloop/web/mcp/auth_plug.ex`, `lib/cairnloop/web/mcp/router.ex`, `test/cairnloop/web/mcp/router_test.exs`, `guides/05-mcp-clients.md` |
| 10 | Config validation / boot-time checks | Mixed/Weak | Medium | Missing repo is caught by doctor, but many dangerous configs fail late or silently. | Validate side-effect, notifier, MCP, handoff secret, and prefix config in doctor/boot checks. | Should fix before 1.0 | `lib/cairnloop/doctor.ex`, `guides/04-troubleshooting.md`, `lib/cairnloop/application.ex` |
| 11 | Identity attribution and audit correctness | Mixed | High | Operator identity docs are good, but widget customer identity still reuses `host_user_id`; nil actor is tolerated. | Separate customer/session identity from operator/audit identity in runtime schema and UI reads. | Must fix | `guides/07-auth-and-operator-identity.md`, `lib/cairnloop/channels/widget_channel.ex`, `test/integration/widget_channel_test.exs`, `lib/cairnloop/router.ex` |
| 12 | Multi-tenancy / tenant isolation | Mixed/Weak | Medium | Search scopes by `host_user_id`, and the new schema-prefix direction is a single library prefix, not a tenant-isolation feature. | Define the supported single-host/single-prefix scope and avoid implying multi-tenant safety. | Should fix before 1.0 | `lib/cairnloop/retrieval/providers/resolved_cases.ex`, `guides/07-auth-and-operator-identity.md`, `.planning/REQUIREMENTS.md` |
| 13 | Security policy / vulnerability handling | Recently improved | High | `SECURITY.md` now reads like a public policy, but it must stay aligned with the trust fixes and supported-version reality. | Keep the public policy current as ingress, MCP, prefix, and telemetry fixes land. | Must fix | `SECURITY.md` |
| 14 | Dependency hygiene / supply chain | Mixed | Medium | `mix ci.quality` audits deps, but ignores known Hackney advisories because of optional Chimeway transitives. | Document the accepted advisory reason and remove ignore list when upstream resolves. | Should fix before 1.0 | `mix.exs`, `mix.lock` |
| 15 | CI/CD determinism and least privilege | Mixed/Strong | Medium | CI is split, read-only by default, and currently opts out of persisted checkout credentials; live timing and branch-protection evidence are still unavailable locally. | Keep `persist-credentials: false`, validate action runtime knobs, and add timing/gate evidence in `docs/ci-cd-audit.md`. | Should fix before 1.0 | `.github/workflows/ci.yml`, `.github/workflows/demo-smoke.yml`, `.github/workflows/release-please.yml` |
| 16 | Test coverage risk alignment | Mixed/Strong | High | 118 test files and 31 integration/example files exist, but prefix/auth-negative/SRE cases are missing. | Add tests for the exact vM019 trust gaps instead of broadening indiscriminately. | Must fix for changed areas | `test/`, `test/integration/`, `examples/cairnloop_example/test/` |
| 17 | Data privacy / retention | Mixed | Medium | Telemetry has good bounded patterns, but no retention/deletion story for support records, snapshots, or embeddings. | Document data categories and retention/deletion hooks; do not invent compliance process. | Should fix before 1.0 | `lib/cairnloop/governance/tool_proposal.ex`, `lib/cairnloop/outbound/bulk_envelope.ex`, `lib/cairnloop/retrieval/resolved_case_evidence.ex` |
| 18 | Operational observability | Mixed | Medium | Bounded telemetry and metrics plug exist; readiness/doctor depth is thin. | Extend doctor/readiness without bloating `/health`. | Should fix before 1.0 | `lib/cairnloop/telemetry.ex`, `lib/cairnloop/web/metrics_plug.ex`, `lib/cairnloop/doctor.ex` |
| 19 | Error handling / fail-closed behavior | Mixed/Strong | Medium | Many paths fail closed; some failures are swallowed or logged with raw data. | Keep existing fail-closed patterns; tighten side effects and sensitive logging. | Should fix before 1.0 | `lib/cairnloop/retrieval.ex`, `lib/cairnloop/outbound.ex`, `lib/cairnloop/application.ex`, `lib/cairnloop/workers/process_message.ex` |
| 20 | Public API and contract stability | Strong | High | Sealed public contracts and additive opts are project invariants and visible in code comments. | Preserve sealed signatures; add compatibility tests for new prefix/config behavior. | Maintain | `.planning/PROJECT.md`, `lib/cairnloop/outbound.ex`, `lib/cairnloop/governance.ex` |
| 21 | Backward compatibility / semver | Mixed/Strong | Medium | release-please and CHANGELOG exist; older release history shows post-release remediation. | Add explicit compatibility matrix and upgrade notes. | Should fix before 1.0 | `.github/workflows/release-please.yml`, `CHANGELOG.md`, `.planning/RETROSPECTIVE.md` |
| 22 | Packaging / HexDocs completeness | Mixed/Strong | Medium | Package includes guides/priv/lib and release workflow verifies tarball/docs; docs content still has truth gaps. | Keep tarball checks; fix docs truth rather than packaging mechanics. | Should fix before 1.0 | `mix.exs`, `.github/workflows/release-please.yml`, `guides/` |
| 23 | Example/demo truth | Strong | High | Docker demo, smoke wrapper, route checks, docs tests, and example app dogfood the local dependency. | Keep demo as proof, but label demo auth as demo-only. | Maintain | `README.md`, `bin/demo`, `examples/cairnloop_example/README.md`, `test/cairnloop/demo_smoke_workflow_contract_test.exs` |
| 24 | Developer/contributor onboarding | Mixed | Medium | `CONTRIBUTING.md` explains lanes and now points at the current test-host migration path, but local DB/E2E prerequisites still require judgment. | Keep the "which check should I run" guidance current as CI lanes evolve. | Should fix before 1.0 | `CONTRIBUTING.md`, `mix.exs` |
| 25 | Maintainability / modularity | Mixed/Strong | Medium | Facades and components exist; some LiveViews still carry large inline render/style blocks. | Refactor only where it removes real drift: search modal/conversation style chunks and config seams. | Nice later except trust paths | `lib/cairnloop/web/search_modal_component.ex`, `lib/cairnloop/web/conversation_live.ex`, `lib/cairnloop/web/components.ex` |
| 26 | Performance / scalability | Mixed | Medium | Scoped counts and caps exist; pgvector/full-text usage exists; no broad load profile. | Focus on query/index correctness after schema-prefix work; avoid premature load testing. | Low until adopter load | `lib/cairnloop/web/home_live.ex`, `lib/cairnloop/outbound.ex`, `priv/repo/migrations/` |
| 27 | Accessibility | Mixed/Strong | Medium | Component tests cover color+icon status, table scroll regions, tap target contracts, and focusable patterns. | Keep adding focused a11y tests when touching UI. | Maintain | `docs/operator-ui-principles.md`, `test/cairnloop/web/components_test.exs`, `test/cairnloop/web/responsive_markup_test.exs` |
| 28 | UI/UX consistency and design system | Strong with drift | Medium | `.cl-*` system is real; inline styles remain in search modal and conversation. | Move repeated inline layouts into `.cl-*` utilities when touching those screens. | Nice later | `priv/static/cairnloop.css`, `lib/cairnloop/web/components.ex`, `test/cairnloop/web/brand_token_gate_test.exs` |
| 29 | Browser/mobile responsiveness | Strong | Medium | Mobile-first and geometry tests exist. | Preserve existing E2E geometry checks. | Maintain | `test/cairnloop/web/responsive_markup_test.exs`, `examples/cairnloop_example/test/e2e/` |
| 30 | AI safety / grounding | Strong | Medium | Deterministic default engine, strong-grounding Anthropic adapter, and fallback behavior are explicit. | Keep model paths opt-in and human-reviewed. | Maintain | `lib/cairnloop/automation/draft_generator/anthropic.ex`, `guides/06-extending.md` |
| 31 | Extensibility/tool contracts | Strong | Medium | Behaviours and `Cairnloop.Tool` contract are documented and tested. | Add trust notes for high-risk tool examples. | Maintain | `guides/03-host-integration.md`, `guides/06-extending.md`, `lib/cairnloop/tool.ex` |
| 32 | Data integrity / idempotency | Strong | High | Three-layer at-most-once patterns, Oban unique keys, and durable event rows are established. | Preserve pattern during vM019 changes. | Maintain | `.planning/PROJECT.md`, `lib/cairnloop/workers/tool_execution_worker.ex`, `lib/cairnloop/workers/outbound_worker.ex`, `lib/cairnloop/outbound.ex` |
| 33 | Compliance/auditability | Mixed/Strong | Medium | Durable audit state exists; public security/retention docs lag. | Fix public trust docs and sensitive telemetry before claiming compliance posture. | Should fix before 1.0 | `lib/cairnloop/auditor.ex`, `lib/cairnloop/web/audit_log_live.ex`, `SECURITY.md` |
| 34 | Disaster recovery / rollback | Mixed/Weak | Medium | `UPGRADING.md` now gives high-level rollback posture, but DB rollback and data-move procedures still need implementation proof. | Keep rollback guidance tied to tested schema-prefix behavior and avoid dropping shared extensions. | Should fix before 1.0 | `priv/repo/migrations/20260516000000_create_knowledge_base.exs`, `UPGRADING.md` |
| 35 | Internationalization/localization | Low priority / N/A now | High | Product is English-only operator tooling; no requirement suggests i18n work. | Do nothing now; avoid baking user-visible technical atoms into copy. | Low | `lib/cairnloop/web/`, `docs/operator-ui-principles.md` |
| 36 | Project/GSD hygiene | Mixed | High | Planning is explicit and useful, but prior retrospectives show shipped-with-defects and stale-summary drift. | Keep audit against live source before release; do not treat summaries as evidence. | Must maintain | `.planning/RETROSPECTIVE.md`, `.planning/milestones/vM015-MILESTONE-AUDIT.md`, `.planning/STATE.md` |

## Top 5 Weakness Deep Dives

### 1. Host-app trust boundaries are still demo-shaped in production code

The widget socket accepts any binary `"token"` and stores it as `socket.assigns[:user_token]` with
a comment saying a real app would verify it. `WidgetChannel.join/3` then creates a conversation
with `host_user_id: token`. The example chat hardcodes `data-token="demo_customer"`, and the
integration test asserts that the conversation created on join has `host_user_id="demo_customer"`.

That is fine as a demo, but it is not a production trust contract. `host_user_id` elsewhere means
operator identity and search/audit scope, while widget token means customer/session identity. The
Auth & Operator Identity guide correctly warns against a static operator session, but runtime
widget ingress still overloads a column/name that carries governance meaning.

Concrete consequence: a host can believe Cairnloop has a production widget-auth seam because the
demo works, while the library actually accepts any customer-provided string and persists it into a
governance-adjacent identity field.

Fix:

- Add a host-configured widget verifier behavior or callback, fail closed outside dev/test when absent,
  and return a separate customer/session identity shape.
- Stop using `Conversation.host_user_id` for widget customer identity. Preserve compatibility with
  an explicit migration or public-schema compatibility option.
- Update `guides/02-jtbd-walkthrough.md`, `guides/03-host-integration.md`, and the example app to
  label the demo token as demo-only.

Evidence: `lib/cairnloop/channels/widget_socket.ex`, `lib/cairnloop/channels/widget_channel.ex`,
`examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`,
`test/integration/widget_channel_test.exs`, `guides/07-auth-and-operator-identity.md`.

### 2. DB/migration hygiene is not ready for respectful host-app adoption

Library migrations create tables, indexes, functions, triggers, and raw SQL against unqualified
names. Schemas use plain `schema "cairnloop_*"` declarations without a configured prefix. Retrieval
fragments hardcode table names such as `cairnloop_chunks.search_vector`. `Retrieval.system_health/0`
queries `cairnloop_chunks` and `oban_jobs` directly. The first KB migration creates `vector` and
drops it on rollback.

This is the opposite of the vM019 decision to default new Cairnloop support-domain tables to a
dedicated `cairnloop` Postgres schema while keeping `public` as an explicit compatibility path.
It is not only table clutter. Raw trigger/function SQL and rollback behavior are the expensive
parts because they can collide with or remove host-owned database objects.

Concrete consequence: a real app installing Cairnloop into an existing Postgres database gets a
large public-schema footprint and no tested path to move Cairnloop-owned support tables into a
dedicated schema.

Fix:

- Introduce a single configured Cairnloop DB prefix with default `"cairnloop"` for new installs.
- Qualify migrations, references, indexes, functions, triggers, fragments, structural checks, and
  schema modules.
- Do not drop shared extensions such as `vector` on rollback.
- Add tests for dedicated-schema new installs and explicit public-schema compatibility.

Evidence: `priv/repo/migrations/20260516000000_create_knowledge_base.exs`,
`priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs`,
`priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`,
`lib/cairnloop/knowledge_base/article.ex`,
`lib/cairnloop/retrieval/providers/knowledge_base.ex`, `lib/cairnloop/retrieval.ex`,
`.planning/REQUIREMENTS.md`.

### 3. Docs/install/release truth is improving but still not OSS-trustworthy

The current installer source is better than earlier evidence: it derives `~> #{@cairnloop_version}`
from `mix.exs`, prints repo config, prints both host and dependency migration commands, and has a
source-scan regression test. Keep that.

Several docs truth gaps were adoption blockers at the start of vM019:

- `SECURITY.md` was an internal Phase 10/30 threat verification artifact, not a public security
  policy. It is now a public disclosure policy.
- `UPGRADING.md` was absent. It now documents the dedicated-schema default, public compatibility,
  and extension rollback posture.
- `guides/05-mcp-clients.md` tells users to plug `Cairnloop.Web.MCP.Auth`, but the code defines
  `Cairnloop.Web.MCP.AuthPlug`.
- The same MCP guide says raw tokens begin with `cl_mcp_...`, but `Cairnloop.MCP.issue_token/1`
  returns a bare URL-safe Base64 token; only the Settings UI displays the mask `cl_mcp_***`.
- `docs/architecture.md` describes `Cairnloop.Web.MCP.Auth` and `conn.private`, while the code uses
  `AuthPlug` and assigns `conn.assigns.mcp_token`.
- `guides/02-jtbd-walkthrough.md` says Settings shows Oban job state, but `SettingsLive` shows
  Notifier and Retrieval health only.
- `CONTRIBUTING.md` pointed at `priv/test_host/repo/migrations`; that path has been corrected to
  `priv/test_host/migrations`.

Concrete consequence: adopters who read carefully can still follow a wrong MCP module name, expect
the wrong token format, or overestimate operational diagnostics. Security and upgrade posture now
have public entry points, but they must stay current as schema-prefix work lands.

Fix:

- Keep `SECURITY.md` and `UPGRADING.md` public-facing as the prefix work evolves.
- Add source-scan docs tests for MCP module names, token prefix truth, Settings health claims,
  compatibility matrix, and current version snippets.

Evidence: `lib/mix/tasks/cairnloop/install.ex`, `test/cairnloop/tasks/install_test.exs`,
`SECURITY.md`, `guides/05-mcp-clients.md`, `lib/cairnloop/mcp.ex`,
`lib/cairnloop/web/mcp/auth_plug.ex`, `docs/architecture.md`,
`guides/02-jtbd-walkthrough.md`, `lib/cairnloop/web/settings_live.ex`, `CONTRIBUTING.md`.

### 4. Production/SRE story is too shallow around readiness and side effects

`HealthPlug` correctly returns a tiny liveness response. That should stay honest. The problem is
that the repo also needs a readiness/doctor story that tells a host whether DB, migrations,
pgvector, Oban, notifier, MCP, and optional side effects are wired correctly. Current doctor checks
repo config, router mount, dashboard mount, metrics dependency, auditor, tools, context provider,
and notifier presence. It does not check whether Cairnloop tables exist, whether the library
migrations ran, whether `vector` is present, whether Oban can accept jobs, whether retrieval health
is degraded for a known reason, or whether Scrypath is enabled safely.

The side-effect issue is sharper: `Cairnloop.Application.start/2` attaches a telemetry handler for
`[:cairnloop, :conversation, :resolved]` and unconditionally builds an `IngestScrypath` Oban job.
`IngestScrypath` defaults to `https://api.scrypath.local/v1/index` and `"dummy"` API key. vM019
state explicitly says optional external/Scrypath automation must be inert unless the host opts in.

Concrete consequence: a host can resolve conversations and get background jobs for an external
automation path it never chose, while `/health` still says OK and doctor may not explain the issue.

Fix:

- Add `:scrypath_enabled?` or equivalent explicit opt-in; do not attach/enqueue unless enabled.
- Make misconfigured enabled side effects fail early in doctor/boot checks.
- Keep `/health` as liveness; add readiness/doctor output for DB tables, `vector`, Oban, notifier,
  MCP, prefix, and optional side effects.

Evidence: `lib/cairnloop/application.ex`, `lib/cairnloop/workers/ingest_scrypath.ex`,
`lib/cairnloop/web/health_plug.ex`, `lib/cairnloop/doctor.ex`, `lib/cairnloop/retrieval.ex`,
`.planning/STATE.md`, `guides/04-troubleshooting.md`.

### 5. Sensitive support content still crosses observability boundaries

There are good patterns: retrieval telemetry normalizes metadata without raw query/citation payloads,
governance telemetry allow-lists low-cardinality values, and outbound tests assert enum-only
bounded metadata. But the defaults are inconsistent.

The email branch in `ProcessMessage.perform/1` logs the full parsed email content at warning level,
and the test pins that behavior. `Chat.resolve_conversation/2` builds telemetry metadata containing
`actor`, arbitrary `metadata`, and then adds the full `conversation` struct to the resolved event.
Those are risky defaults for support software because support bodies, customer identifiers, and
operator context are exactly what host teams try to keep out of logs and metrics.

Concrete consequence: a host attaching telemetry/log export can accidentally export customer
support content or identifiers even if the more recent retrieval/governance/outbound lanes are
careful.

Fix:

- Remove raw email content from logs. Log counts/outcome/reason only.
- Bound conversation telemetry metadata like retrieval/governance/outbound: IDs and bodies belong
  in durable DB/audit rows, not metric labels or generic telemetry metadata.
- Add tests that reject `:content`, `:conversation`, raw `:metadata`, raw token/secret, and payload
  body keys in default logs/telemetry.

Evidence: `lib/cairnloop/workers/process_message.ex`, `test/cairnloop/workers/process_message_test.exs`,
`lib/cairnloop/chat.ex`, `lib/cairnloop/retrieval/telemetry.ex`,
`test/cairnloop/retrieval/telemetry_test.exs`, `lib/cairnloop/governance/telemetry.ex`,
`test/cairnloop/outbound_test.exs`.

## Adoption Friction Audit

What works:

- Fresh-clone demo path is strong. README and Quickstart lead with `./bin/demo`, dynamic ports,
  private pgvector Postgres, printed URLs, reset/log/status/smoke commands, and credential-free
  first-run scope. Evidence: `README.md`, `guides/01-quickstart.md`,
  `examples/cairnloop_example/README.md`, `test/cairnloop/docs/docker_first_docs_test.exs`.
- The example app dogfoods local source and the shipped dashboard macro. Evidence:
  `examples/cairnloop_example/mix.exs`, `examples/cairnloop_example/lib/cairnloop_example_web/router.ex`.
- Installer output currently includes repo config and dependency migrations. Evidence:
  `lib/mix/tasks/cairnloop/install.ex`, `test/cairnloop/tasks/install_test.exs`.
- Auth/operator identity guide is unusually clear about the static-map trap. Evidence:
  `guides/07-auth-and-operator-identity.md`, `lib/cairnloop/router.ex`,
  `examples/cairnloop_example/lib/cairnloop_example_web/operator_auth.ex`.

What blocks trust:

- Production widget verification is not a real seam yet. Evidence:
  `lib/cairnloop/channels/widget_socket.ex`.
- Email webhook auth is a literal default secret and the email path is only a logging stub. Evidence:
  `lib/cairnloop/ingress/email_webhook_plug.ex`, `lib/cairnloop/workers/process_message.ex`.
- MCP docs do not match module names or token format. Evidence: `guides/05-mcp-clients.md`,
  `lib/cairnloop/web/mcp/auth_plug.ex`, `lib/cairnloop/mcp.ex`.
- Dedicated-schema work has started in the current tree, but the install/runtime path is not yet
  proven end to end in the example app and public-compatibility mode. Evidence:
  `lib/cairnloop/schema_prefix.ex`, `priv/repo/migrations/`, `UPGRADING.md`.
- Public security posture has a real `SECURITY.md` entry point now; it still has to stay aligned
  with unresolved ingress/MCP/telemetry risks. Evidence: `SECURITY.md`.

Practical adoption bar for vM019: a host should be able to install into a real Phoenix app, choose
dedicated schema or explicit public compatibility, mount dashboard/ops/MCP/widget with clear auth
boundaries, run a doctor command, and know exactly which behavior is demo-only.

## Production/SRE Audit

Strengths:

- `HealthPlug` is honest liveness, not fake readiness.
- `MetricsPlug` returns Prometheus output when the optional dependency is present and 501 otherwise.
- `Cairnloop.Telemetry` documents event names and the newer retrieval/governance/outbound lanes
  emphasize bounded metadata.
- Release workflow verifies package dry-run, tarball contents, Hex publish, and HexDocs fetch.

Gaps:

- No readiness endpoint or doctor output that proves DB table presence, migration state, schema
  prefix, pgvector, Oban insertability, failed Oban jobs, notifier behavior, or side-effect config.
- `Retrieval.system_health/0` catches everything and returns `"Unreachable / Degraded"` without
  structured cause.
- `OutboundWorker` updates a message to `"sent"` when no notifier is configured while bounded
  telemetry says `:no_op`. The comment explains why, but operators may still read durable message
  state as delivery success unless UI/docs are precise.
- Scrypath side effects are attached by default.

SRE priority: add diagnostics that tell a host "your database is missing migration X" or "Oban is
not configured" rather than only "degraded." Avoid enterprise runbook ceremony until the checks are
real.

Evidence: `lib/cairnloop/web/health_plug.ex`, `lib/cairnloop/web/metrics_plug.ex`,
`lib/cairnloop/doctor.ex`, `lib/cairnloop/retrieval.ex`, `lib/cairnloop/workers/outbound_worker.ex`,
`.github/workflows/release-please.yml`.

## UI/UX Audit

The operator UI is not the main vM019 weakness.

Strengths:

- The repo has explicit operator UI principles and a tokenized `.cl-*` system. Evidence:
  `docs/operator-ui-principles.md`, `priv/static/cairnloop.css`, `lib/cairnloop/web/components.ex`.
- Component tests assert color+icon status, token-pure renders, shell navigation, and reusable
  primitives. Evidence: `test/cairnloop/web/components_test.exs`.
- Responsive/accessibility source gates assert scrollable table regions, mobile-first conversation
  layout, 44px tap targets, and E2E geometry wiring. Evidence:
  `test/cairnloop/web/responsive_markup_test.exs`.
- Brand/token drift gates catch hardcoded colors in render files. Evidence:
  `test/cairnloop/web/brand_token_gate_test.exs`, `test/cairnloop/web/token_drift_test.exs`.

Weaknesses:

- `SearchModalComponent` still has large inline style blocks. Evidence:
  `lib/cairnloop/web/search_modal_component.ex`.
- `ConversationLive` still carries inline layout/color snippets and raw `<pre>` technical expanders
  in governed action details. Some raw detail is useful, but it should stay behind explicit
  disclosure and not become default operator copy. Evidence: `lib/cairnloop/web/conversation_live.ex`.
- The example `/chat` uses Tailwind/Phoenix-default classes and inline styles. This is acceptable
  for the example host app, but the production widget guidance needs to avoid implying the example
  token/auth is reusable. Evidence:
  `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`.

UI recommendation: do not spend vM019 on broad polish. Touch UI only where it supports trust:
Settings/doctor truth, auth/identity copy, and removing raw leaked technical data from default
surfaces.

## Maintainer Friction Audit

What works:

- `mix.exs` has clear lanes: `ci.fast`, `ci.integration`, `ci.quality`, and test env routing.
- CI mirrors those lanes and adds example E2E and demo smoke.
- The repo contains many DB-free source-scan tests for docs, workflow, UI, and package contracts.
- release-please reduces manual release toil.

Friction:

- The project accumulates many source-scan tests that are useful but easy to make stale if they pin
  implementation strings instead of behavior. The current installer test is appropriate because it
  guards public install truth; keep that level of specificity only for public contracts.
- `CONTRIBUTING.md` has stale path text for test host migrations.
- CI has multiple expensive lanes. That is acceptable for release trust, but maintainers need a
  documented "what runs on PR/main/release/demo" map with timing and cache behavior. Phase 57's
  separate `docs/ci-cd-audit.md` should cover that.
- Past GSD closeouts shipped with stale summaries and release defects. The vM015 audit explicitly
  says summaries are claims, not evidence.

Evidence: `mix.exs`, `.github/workflows/ci.yml`, `.github/workflows/demo-smoke.yml`,
`.github/workflows/release-please.yml`, `test/cairnloop/demo_smoke_workflow_contract_test.exs`,
`test/cairnloop/tasks/install_test.exs`, `CONTRIBUTING.md`, `.planning/RETROSPECTIVE.md`,
`.planning/milestones/vM015-MILESTONE-AUDIT.md`.

## GSD Sanity Check

The vM019 plan is directionally correct. It names the real adoption blockers and explicitly avoids
new product surface. The order is also right: audit first, then trust/ingress/side effects, then DB
prefix, then docs, then CI.

What to keep:

- Treat host compatibility and DB prefix as must-fix, not polish.
- Keep public signatures sealed and use additive options/config.
- Keep Oban host-owned; do not move Oban tables into the Cairnloop schema.
- Keep milestone audit against live source before release.

What to watch:

- Phase 57's full plan includes `docs/ci-cd-audit.md`, `docs/postgres-schema-prefix.md`, planning
  updates, and follow-on code/doc fixes. Those artifacts now exist, so keep them synchronized with
  live source instead of treating this document as the sole evidence source.
- Do not let docs fixes claim runtime fixes. Security/doc truth can improve before code, but
  widget/email/MCP/Scrypath/DB-prefix risks are not closed until tests prove behavior.
- Do not add enterprise process to compensate for missing code. The fix is verifiers, migrations,
  diagnostics, and precise docs.

Evidence: `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`,
`.planning/STATE.md`, `.planning/phases/57-evidence-and-trust-audit/57-CONTEXT.md`,
`.planning/phases/57-evidence-and-trust-audit/57-PLAN.md`.

## Top 10 Concrete Changes

1. Add a production widget identity verifier seam and fail closed outside demo/test when no verifier
   is configured. Stop persisting arbitrary widget token strings as operator-scoped `host_user_id`.
2. Replace the email webhook literal `"secret-token"` with host-configured signature/token
   verification, and make missing production auth a hard failure.
3. Require MCP auth for token-required metadata/list/call behavior or clearly split public
   discovery from protected tool metadata. Align module names and token-format docs with code.
4. Make Scrypath/external automation opt-in. Do not attach the conversation-resolved handler or
   enqueue `IngestScrypath` unless the host explicitly enables it.
5. Implement the dedicated `cairnloop` DB prefix contract across migrations, schemas, raw SQL,
   fragments, health checks, installer output, and example app. Add public-schema compatibility
   tests.
6. Remove `DROP EXTENSION IF EXISTS vector` from rollback behavior for Cairnloop library migrations.
   Treat shared extensions as host-owned.
7. Replace `SECURITY.md` with a public OSS security policy and add `UPGRADING.md` with version,
   prefix, migration, rollback, and compatibility guidance.
8. Add readiness/doctor diagnostics for repo config, table/migration presence, pgvector, Oban,
   notifier, MCP, prefix mode, and optional side-effect config. Keep `/health` as liveness.
9. Remove raw support content from default logs/telemetry. Specifically fix email logging and
   conversation-resolved telemetry metadata; add tests that reject raw bodies, arbitrary metadata,
   tokens, and full structs.
10. Add targeted regression tests for the trust gaps: unauthenticated MCP `initialize`/`tools/list`,
    missing widget verifier in prod mode, email missing/invalid secret, Scrypath disabled by
    default, dedicated-schema/public-schema install, and docs/code drift for MCP module/token claims.

## Bottom Line

Cairnloop is not low-quality; it is uneven in the exact places an OSS Phoenix library cannot be
uneven. The demo, UI system, governance core, and release mechanics are credible. The adoption risk
is that production hosts inherit demo-grade ingress, public-schema assumptions, shallow diagnostics,
and inaccurate public docs. vM019 should spend nearly all of its effort on those trust boundaries.
