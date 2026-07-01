# Phase 59: Dedicated Postgres Schema Contract - Context

**Gathered:** 2026-06-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Default new Cairnloop installs to a dedicated `cairnloop` Postgres schema while preserving an
explicit public-schema compatibility path for existing installs. This phase owns the DB contract
itself: configuration, Ecto schema/query behavior, migrations, raw SQL/fragments, structural checks,
installer substrate, example/test-host proof, and regression coverage.

This is not a multi-tenant prefix feature, not a new product-surface phase, and not broad docs
cleanup. Oban remains host-owned, `schema_migrations` remains under the host's normal migration
history strategy, and Phase 60 owns broad README/ExDoc/SECURITY/UPGRADING polish after this contract
is implemented.

</domain>

<decisions>
## Implementation Decisions

### Prefix Contract

- **D-01:** New installs default to the single Cairnloop support-domain prefix `"cairnloop"`.
  Existing public-schema installs remain supported only through explicit compatibility config.
- **D-02:** `Cairnloop.SchemaPrefix` is the canonical internal helper for prefix normalization,
  repo options, identifier quoting, and schema-qualified raw SQL table/function references. Do not
  create a parallel prefix abstraction in individual facades or workers.
- **D-03:** `nil` remains accepted as a legacy/public compatibility setting because current tests,
  installer output, and existing released guidance already use it. Prefer documenting `"public"` as
  the clearest explicit public-schema compatibility spelling where Ecto/runtime behavior supports it;
  tests should make the supported compatibility spelling unambiguous before docs are finalized.
- **D-04:** Do not support hot per-request or per-tenant prefix switching. The vM019 contract is a
  single configured Cairnloop support prefix per host app.

### Ecto Schema and Runtime Access

- **D-05:** Keep `@schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")`
  as the normal Ecto schema default for Cairnloop `schema "cairnloop_*"` modules, but do not assume
  `Repo` options alone override schema prefixes. Public compatibility must be proven under the
  actual compile/config mode the host will use.
- **D-06:** Runtime reads/writes must honor the configured support prefix across facades, workers,
  preloads, `Ecto.Multi`, `insert_all`/`update_all`/`delete_all`, and structural checks. For schema
  queries the schema prefix may do most of the work; raw SQL, fragments, table names, and direct SQL
  calls must use `Cairnloop.SchemaPrefix` or an equally validated helper path.
- **D-07:** Oban is explicitly outside Cairnloop's prefix contract. Queries or checks against
  `oban_jobs` must continue to target the host-owned Oban placement and must not be redirected by
  `:cairnloop, :schema_prefix`.

### Migration and Raw SQL Contract

- **D-08:** Prefix correctness must live in Cairnloop's migration source, not in a
  `mix ecto.migrate --prefix cairnloop` shortcut. Do not present `--prefix` as sufficient, because
  it can redirect migration metadata and still leaves raw SQL, trigger functions, fragments, and
  runtime queries unresolved.
- **D-09:** Cairnloop support-domain migrations must deliberately qualify tables, indexes,
  constraints, references, functions, triggers, and raw SQL. FKs between Cairnloop support-domain
  tables use the configured support prefix; any future FK to a host-owned non-Cairnloop table must
  specify that target prefix explicitly instead of inheriting the Cairnloop prefix.
- **D-10:** The support-domain table set includes host-scaffolded Cairnloop tables such as
  `cairnloop_conversations`, `cairnloop_messages`, `cairnloop_drafts`, and
  `cairnloop_conversation_slas`, plus Cairnloop-owned KB/retrieval/governance/MCP/outbound tables.
  It does not include arbitrary host app tables or Oban tables.
- **D-11:** Do not rely on `SET search_path` as the primary correctness mechanism. Dedicated-schema
  operation should remain inspectable through explicit qualification.
- **D-12:** Rollbacks must not drop shared database extensions such as `vector`. Creating the
  extension with `CREATE EXTENSION IF NOT EXISTS vector` can remain a convenience or move to host
  prerequisite/doctor guidance, but `DROP EXTENSION` is not acceptable in Cairnloop rollback paths.

### Installer, Example, and Tests

- **D-13:** The installer should generate prefix-aware host-support migrations by default and keep
  Oban setup separate. It should explain the dedicated-schema default and public compatibility
  switch without implying that CLI `--prefix` alone completes the contract.
- **D-14:** The example app and integration test host should become the proof path for new installs:
  configured `schema_prefix: "cairnloop"`, support tables created in that prefix, dependency
  migrations qualifying their own objects, and Oban remaining host-owned.
- **D-15:** Test coverage must prove both supported modes: dedicated-schema new install and explicit
  public-schema compatibility. Include negative/collision coverage where misleading same-name
  `public.cairnloop_*` tables exist while the configured prefix is `"cairnloop"`.
- **D-16:** Add or extend source-scan tests for migration/installer drift, but do not rely on source
  scans alone. DB-backed proof is required where behavior depends on Postgres object placement,
  triggers, functions, FKs, `vector`, or raw SQL.

### Claude's Discretion

- No owner-level question was escalated. `CLAUDE.md` directs GSD discuss-phase to auto-decide
  routine trust-sensitive implementation calls and surface only genuinely very-impactful choices.
  The dedicated-schema direction, public compatibility path, no-`--prefix` shortcut, and Oban
  boundary are already locked by vM019 project state and `docs/postgres-schema-prefix.md`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning and Requirements

- `.planning/PROJECT.md` - vM019 focus, architectural invariants, and carried dedicated-schema
  decision.
- `.planning/REQUIREMENTS.md` - DB-01 through DB-07 are Phase 59 scope; future/out-of-scope notes
  exclude multi-tenant prefixes and moving Oban.
- `.planning/ROADMAP.md` - Phase 59 goal and success criteria.
- `.planning/STATE.md` - carried vM019 decisions, dirty-worktree warning, and current phase state.
- `.planning/phases/57-evidence-and-trust-audit/57-CONTEXT.md` - audit handoff naming DB schema
  isolation as Phase 59 work.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/58-CONTEXT.md` - trust-boundary
  context and Phase 59 deferral from prior phase.
- `CLAUDE.md` - decision policy, sealed-contract posture, test expectations, and repo-specific
  prefix guidance.

### Prefix Contract and Audit Evidence

- `docs/postgres-schema-prefix.md` - primary implementation contract for Phase 59; includes
  primary-source Ecto/Postgres behavior, tradeoffs, test strategy, and acceptance criteria.
- `docs/software-quality-evaluation.md` - evidence-backed audit identifying DB/schema isolation and
  migration hygiene as a must-fix adoption risk.
- `UPGRADING.md` - public upgrade-path surface that must remain aligned with the implemented
  dedicated/public compatibility behavior.

### Prefix Helpers and Config

- `lib/cairnloop/schema_prefix.ex` - current prefix helper and identifier validation.
- `test/cairnloop/schema_prefix_test.exs` - current helper/schema-prefix regression coverage.
- `config/config.exs` - library default `:schema_prefix` config.
- `config/test.exs` - current public-compatibility test override that Phase 59 must revisit.
- `mix.exs` - integration aliases and migration ordering comments.

### Library Migration Surface

- `priv/repo/migrations/20260516000000_create_knowledge_base.exs` - extension and first KB tables.
- `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` - raw SQL, triggers,
  functions, resolved-case tables, and support-table FKs.
- `priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs` - retrieval gap event table.
- `priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs` - raw SQL
  update path already partly using `SchemaPrefix`.
- `priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs` - gap candidate
  support tables and indexes.
- `priv/repo/migrations/20260521020000_add_article_suggestions.exs` - article suggestion table and
  indexes.
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` - review task/event tables.
- `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs` - governance
  proposal/event tables.
- `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs` - FK back to
  `cairnloop_conversations`.
- `priv/repo/migrations/20260524120001_add_tool_approvals.exs` - approval tables and indexes.
- `priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs` - proposal snapshot
  columns.
- `priv/repo/migrations/20260524120200_relax_action_event_to_status_null.exs` - action-event alter.
- `priv/repo/migrations/20260525000000_add_execution_outcome_index.exs` - governance index.
- `priv/repo/migrations/20260526084518_create_cairnloop_mcp_tokens.exs` - MCP token table.
- `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs` - outbound bulk envelope
  table.

### Runtime and Raw SQL Integration Points

- `lib/cairnloop/chat.ex` - conversation/message writes and lifecycle reads.
- `lib/cairnloop/knowledge_base.ex` - KB article/revision/chunk facade operations.
- `lib/cairnloop/retrieval.ex` - structural health, Oban check, enqueue/rebuild paths.
- `lib/cairnloop/retrieval/providers/knowledge_base.ex` - full-text fragment/search-vector source.
- `lib/cairnloop/retrieval/providers/resolved_cases.ex` - resolved-case full-text fragment source.
- `lib/cairnloop/governance.ex` - proposal, approval, event, and audit reads/writes.
- `lib/cairnloop/outbound.ex` - outbound/bulk envelope reads and writes.
- `lib/cairnloop/web/settings_live.ex` - operator settings health reads.
- `lib/cairnloop/doctor.ex` and `lib/mix/tasks/cairnloop.doctor.ex` - structural/readiness checks
  that should report prefix state honestly.

### Installer, Example, and Test Host

- `lib/mix/tasks/cairnloop/install.ex` - generated host-support migration and next-step output.
- `test/cairnloop/tasks/install_test.exs` - installer source-scan expectations.
- `test/cairnloop/migrations_test.exs` - current migration raw-SQL/source-scan coverage.
- `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs` - integration host
  support tables.
- `priv/test_host/migrations/20260101000001_add_oban_jobs.exs` - host-owned Oban table proof.
- `examples/cairnloop_example/config/config.exs` - example app Cairnloop config.
- `examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs` -
  example extension migration currently drops `vector` on rollback and needs correction.
- `examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs` -
  example support-table migration currently public-style.
- `examples/cairnloop_example/priv/repo/migrations/20260525201623_create_cairnloop_drafts.exs` -
  example draft-table migration.
- `examples/cairnloop_example/priv/repo/migrations/20260525201624_add_run_key_to_messages.exs` -
  example message alter path.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Cairnloop.SchemaPrefix` already provides default prefix resolution, public compatibility via
  `nil`, repo option injection, and validated SQL identifier quoting.
- Current Cairnloop Ecto schemas already declare
  `@schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")`.
- `test/cairnloop/schema_prefix_test.exs`, `test/cairnloop/migrations_test.exs`, and
  `test/cairnloop/tasks/install_test.exs` provide source-scan guard patterns that can be broadened.
- `Cairnloop.Doctor.checks/2` from Phase 58 is the right place for prefix/readiness truth without
  changing `/health` liveness semantics.

### Established Patterns

- Cairnloop is a host-owned Phoenix/Ecto library: the host owns the Repo, Oban, router auth, and
  operational deployment. Cairnloop supplies safe defaults and explicit seams.
- Public function signatures from shipped phases are sealed; prefix work should be additive config,
  helpers, migration fixes, and tests rather than API churn.
- Durable Ecto records/events remain workflow truth. Telemetry, doctor output, and source scans are
  verification/observability surfaces, not substitutes for DB-backed behavior proof.
- Test strategy should prefer focused headless/source-scan tests where possible, then DB-backed
  integration/example proof for actual Postgres object placement.

### Integration Points

- Configuration enters through `config :cairnloop, :schema_prefix` and should be visible in install,
  example, test, and doctor surfaces.
- Host-support migrations and dependency migrations must agree on the same support-domain prefix.
- Raw SQL hot spots include migration backfills/triggers/functions, retrieval health, retrieval
  full-text fragments, and any direct `Ecto.Adapters.SQL.query/4` usage.
- Oban checks and migrations are deliberately separate from Cairnloop support-domain migration work.

</code_context>

<specifics>
## Specific Ideas

- Update installer guidance so adopters do not think `mix ecto.migrate --prefix cairnloop` alone is
  the solution. The safer story is source-qualified migrations plus explicit config.
- Add DB-backed tests that create both `public.cairnloop_*` and `cairnloop.cairnloop_*` fixtures and
  prove the configured prefix wins.
- Audit every `schema "cairnloop_*"`, `Repo.*`, `Ecto.Adapters.SQL.query/4`, `fragment`, migration
  `table/index/references`, and example/test-host migration path before calling the phase complete.
- Correct rollback posture for `vector` in both library and example migration surfaces.
- Keep Phase 60 docs broadening out of scope except for minimal installer/example/upgrading text
  needed to make this DB contract honest.

</specifics>

<deferred>
## Deferred Ideas

- Multi-tenant or per-customer Cairnloop schema prefixes remain future scope.
- Hosted SaaS/demo, advanced routing, local AI, and mobile SDK work remain out of this milestone.
- Broad README, ExDoc, SECURITY, screenshots/assets, and package metadata cleanup belongs to
  Phase 60 after the DB contract is real.
- CI/runtime posture changes belong to Phase 61 unless a Phase 59 test lane requires a narrow
  command update.

</deferred>

---

*Phase: 59-Dedicated Postgres Schema Contract*
*Context gathered: 2026-06-30*
