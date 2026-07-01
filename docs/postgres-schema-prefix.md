# Postgres Schema Prefix Plan

**Decision:** New Cairnloop installs should place Cairnloop support-domain tables in the
Postgres schema prefix `cairnloop`. Existing public-schema installs remain supported only when
they choose explicit compatibility config. Oban remains host-owned and must not be moved by
Cairnloop's prefix work.

This document is the implementation contract for vM019 DB isolation work. It is not an upgrade
notice for end users yet.

Current worktree status as of 2026-06-29: a first prefix pass is present on disk with a
`Cairnloop.SchemaPrefix` helper, default config, generated-installer migration support, schema
attributes, raw health-query qualification, raw migration SQL qualification for the known
backfill/trigger migrations, public-compatibility test config, dependency-migration docs using
`--prefix cairnloop`, and an `UPGRADING.md` notice. This is evidence of direction, not completion:
the remaining broad work is to make the example/test-host path exercise the dedicated schema end to
end, then run the suite once those migrations create dedicated-schema tables.

## Assumptions

- "Cairnloop support-domain tables" means the `cairnloop_*` tables used by Cairnloop workflows,
  including the host-scaffolded conversation/message/draft/SLA tables. They live in the host
  application's repo, but they are still Cairnloop's support-domain footprint.
- Oban tables are not Cairnloop support-domain tables. They stay wherever the host app configured
  Oban, normally `public.oban_jobs`.
- A single configured Cairnloop prefix is enough for vM019. This is not a multi-tenant or
  per-customer schema-prefix feature.
- Existing installs may already have production data in `public.cairnloop_*`. The implementation
  must fail with actionable guidance or continue in explicit public mode; it must not silently read
  from empty `cairnloop.*` tables.

## Primary-Source Behavior

Postgres schemas are namespaces. In a new database, unqualified objects are created in `public` by
default, and the default search path is `"$user", public`. Unqualified reads and writes follow
`search_path`; PostgreSQL warns that adding writable schemas to the search path can change query
behavior accidentally or maliciously. A dedicated Cairnloop schema should therefore use explicit
qualification, not a process-wide `SET search_path` contract. Source:
[PostgreSQL Schemas](https://www.postgresql.org/docs/current/ddl-schemas.html).

Ecto has several separate prefix surfaces:

- `@schema_prefix` on an Ecto schema defaults to `nil`. If set, Ecto uses it for structs and for
  queries when the schema appears in `from` or `join`. Source:
  [Ecto.Schema](https://hexdocs.pm/ecto/Ecto.Schema.html).
- Query prefixes can be set on `from`/`join`, with `Ecto.Query.put_query_prefix/2`, or by passing
  `prefix:` to `Repo` query calls. For query operations, precedence is `from`/`join` prefix, then
  `@schema_prefix`, then query/Repo prefix. Source:
  [Ecto.Query Query Prefix](https://hexdocs.pm/ecto/Ecto.Query.html).
- Schema operations such as `insert`, `update`, and `delete` accept `prefix:` and Ecto documents
  that this can override a schema prefix for those operations. Query operations do not have that
  same precedence if `@schema_prefix` is already set. Source:
  [Ecto.Repo](https://hexdocs.pm/ecto/Ecto.Repo.html).
- Migrations support `prefix:` on tables, indexes, constraints, and the migrator default prefix.
  `references/2` defaults to the prefix of the surrounding `table/2` block unless explicitly
  overridden. This default is useful when all referenced support-domain tables share the same
  prefix, and dangerous when a Cairnloop table references a table that must stay outside that
  prefix. Source: [Ecto.Migration Prefixes](https://hexdocs.pm/ecto_sql/Ecto.Migration.html).
- `mix ecto.migrate --prefix` exists, but it is only one migrator option. It cannot make raw SQL,
  runtime queries, trigger/function bodies, fragments, or Oban references correct by itself.
  Source: [mix ecto.migrate](https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html).
- Ecto fragments and `Ecto.Adapters.SQL.query/4` are escape hatches that bypass Ecto's source
  qualification. Any raw table/function/index name inside those strings must be separately quoted
  and qualified. Source: [Ecto.Query fragments](https://hexdocs.pm/ecto/Ecto.Query.html).
- `CREATE EXTENSION` records extension member objects so they can be dropped by `DROP EXTENSION`;
  `DROP EXTENSION` removes the extension and dependent member objects. Cairnloop migrations must
  not drop shared extensions such as `vector` on rollback. Sources:
  [CREATE EXTENSION](https://www.postgresql.org/docs/current/sql-createextension.html) and
  [DROP EXTENSION](https://www.postgresql.org/docs/current/sql-dropextension.html).

## Baseline Repo Evidence

This was the pre-vM019 baseline that justified the plan. Some items are now partially addressed by
the first implementation pass, but this list remains useful as the checklist for remaining prefix
work.

- Schemas use unprefixed `schema "cairnloop_*"` declarations and no `@schema_prefix`. Evidence:
  `lib/cairnloop/conversation.ex`, `lib/cairnloop/message.ex`,
  `lib/cairnloop/automation/draft.ex`, `lib/cairnloop/conversations/sla.ex`,
  `lib/cairnloop/knowledge_base/article.ex`, `lib/cairnloop/knowledge_base/revision.ex`,
  `lib/cairnloop/knowledge_base/chunk.ex`, `lib/cairnloop/retrieval/resolved_case_evidence.ex`,
  `lib/cairnloop/retrieval/resolved_case_chunk.ex`, `lib/cairnloop/retrieval/gap_event.ex`,
  `lib/cairnloop/governance/tool_proposal.ex`,
  `lib/cairnloop/governance/tool_action_event.ex`,
  `lib/cairnloop/governance/tool_approval.ex`, `lib/cairnloop/mcp/token.ex`,
  `lib/cairnloop/outbound/bulk_envelope.ex`, and
  `lib/cairnloop/knowledge_automation/*.ex`.
- Library migrations create, alter, index, and drop unqualified tables. Evidence:
  `priv/repo/migrations/20260516000000_create_knowledge_base.exs`,
  `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs`,
  `priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs`,
  `priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs`,
  `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs`,
  `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs`, and
  `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`.
- Library migrations contain FKs to host-scaffolded support tables. Evidence:
  `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` references
  `cairnloop_conversations`, and
  `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs` adds
  `conversation_id` referencing `cairnloop_conversations`.
- The first KB migration creates and drops `vector`. Evidence:
  `priv/repo/migrations/20260516000000_create_knowledge_base.exs`. The example app also creates
  and drops the extension in
  `examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs`.
- Raw SQL assumes public-style names. Evidence:
  `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` uses
  `UPDATE cairnloop_chunks`, trigger DDL `ON cairnloop_chunks`, and unqualified function names;
  `priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs` uses
  `UPDATE cairnloop_retrieval_gap_events`.
- Runtime raw SQL and fragments assume public-style names. Evidence: `lib/cairnloop/retrieval.ex`
  checks `SELECT id FROM cairnloop_chunks LIMIT 1` and `SELECT 1 FROM oban_jobs ...`;
  `lib/cairnloop/retrieval/providers/knowledge_base.ex` references
  `cairnloop_chunks.search_vector`; `lib/cairnloop/retrieval/providers/resolved_cases.ex`
  references `cairnloop_resolved_case_chunks.search_vector`.
- Runtime Repo calls pass no `prefix:` option. Evidence: `lib/cairnloop/chat.ex`,
  `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/governance.ex`,
  `lib/cairnloop/outbound.ex`, `lib/cairnloop/automation.ex`,
  `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`,
  `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`,
  `lib/cairnloop/workers/outbound_worker.ex`, and `lib/cairnloop/web/settings_live.ex`.
- The test host and example app assume public-style support tables. Evidence:
  `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs`,
  `priv/test_host/migrations/20260101000001_add_oban_jobs.exs`,
  `examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs`,
  `examples/cairnloop_example/config/config.exs`, and
  `examples/cairnloop_example/mix.exs`.
- User-facing docs currently teach public-style migrations. Evidence: `README.md`,
  `guides/01-quickstart.md`, `guides/03-host-integration.md`, and
  `guides/04-troubleshooting.md`.

## Tradeoffs

Defaulting to `cairnloop` is the right adoption boundary because it keeps Cairnloop's support
domain inspectable and removable without polluting host `public`. It also aligns with Postgres'
recommendation to put shared applications in separate schemas.

The cost is implementation breadth. Prefixing only migrations is not enough. Prefixing only schemas
is not enough. Prefixing only `mix ecto.migrate --prefix` is not enough. The repo has Ecto queries,
inserts, preloads, raw fragments, direct SQL, trigger functions, full-text vectors, test-host
migrations, generated installer migrations, and docs that all need the same contract.

Static `@schema_prefix "cairnloop"` is attractive as a default, but it has a compatibility trap:
for query operations, Ecto gives `@schema_prefix` higher precedence than the Repo/query prefix. If
the implementation sets static schema prefixes, explicit public compatibility must set `prefix:` on
every `from` and `join` source, not merely on `Repo.all(query, prefix: "public")`. A central helper
with tests is safer than scattered schema attributes. `@schema_prefix` can still be revisited after
public-mode tests prove every query source is explicitly overridden.

Keeping `public` as an explicit compatibility option is less clean than forcing all installs to
migrate, but it is necessary because the current released shape has public-schema assumptions. A
default change that silently returns empty results from `cairnloop.*` would be worse than retaining
public compatibility.

## Recommended Implementation Plan

1. Add one internal prefix module.

   The contract should be a small internal helper, for example `Cairnloop.DBPrefix`, that:

   - reads `config :cairnloop, :schema_prefix`, defaulting to `"cairnloop"` for new installs;
   - accepts explicit compatibility values `"public"` or `nil` only with documented intent;
   - validates that the prefix is a single identifier, not arbitrary SQL;
   - provides `repo_opts(opts)`, `query(queryable)`, `table(name)`, and `quote_table(name)` helpers;
   - provides a separate Oban table helper only if needed, defaulting to the host-owned Oban prefix
     rather than Cairnloop's prefix.

2. Convert runtime Repo access through the helper.

   All Cairnloop facade and worker reads/writes should use helper-supplied prefix options or
   helper-built queries. This includes `repo().get`, `repo().one`, `repo().all`, `insert`,
   `insert_all`, `update`, `delete`, `delete_all`, `update_all`, `preload`, and `Ecto.Multi`
   operations in `lib/cairnloop/chat.ex`, `lib/cairnloop/knowledge_base.ex`,
   `lib/cairnloop/governance.ex`, `lib/cairnloop/outbound.ex`, retrieval workers, automation
   workers, and `lib/cairnloop/web/settings_live.ex`.

3. Make migrations prefix-aware in source, not only in Mix CLI flags.

   Cairnloop-owned/support-domain migration operations should call `table(..., prefix: prefix)`,
   `index(..., prefix: prefix)`, `constraint(..., prefix: prefix)`, and
   `references(..., prefix: prefix)` deliberately. Migration modules should create the schema with
   `CREATE SCHEMA IF NOT EXISTS cairnloop` for the dedicated default path. For public
   compatibility, the same code should resolve prefix to `nil` or `"public"` consistently.

4. Treat FK prefixes as explicit design choices.

   FKs between support-domain tables should use the Cairnloop support prefix. FKs to Oban or
   arbitrary host app tables should not inherit the Cairnloop prefix. Because `references/2`
   defaults to the surrounding table prefix, any non-support-domain reference must specify its
   target prefix explicitly.

5. Rewrite raw SQL and fragments with qualified identifiers.

   Migration SQL must qualify tables, functions, triggers, and indexes. Runtime fragments must stop
   embedding bare strings like `cairnloop_chunks.search_vector`; use either Ecto fields where
   possible or a small, validated identifier-quoting helper for schema-qualified table references.
   Prefix values must never be interpolated from unvalidated host input.

6. Keep extensions host-safe.

   `CREATE EXTENSION IF NOT EXISTS vector` can remain as a convenience or become a doctor/installer
   check, but Cairnloop rollback should not issue `DROP EXTENSION IF EXISTS vector`. The extension
   is database-level shared infrastructure from an adopter's point of view.

7. Add installer and docs substrate.

   `lib/mix/tasks/cairnloop/install.ex` should generate host-support migrations that use the
   Cairnloop support prefix by default, print the compatibility switch for existing installs, and
   keep Oban instructions separate. The generated migration commands should not tell adopters that
   `mix ecto.migrate --prefix cairnloop` alone is sufficient.

8. Add doctor/readiness checks without bloating `/health`.

   `lib/cairnloop/doctor.ex` and structural checks should verify that the configured prefix exists,
   that expected support-domain tables are present in that prefix, that public tables are not being
   silently ignored, that `vector` is installed when retrieval is enabled, and that Oban is checked
   using the host-owned Oban prefix.

## Migration and Upgrade Strategy

New install path:

```elixir
config :cairnloop,
  repo: MyApp.Repo,
  schema_prefix: "cairnloop"
```

New generated migrations should:

- create `cairnloop` if it does not exist;
- create host-scaffolded support tables such as `cairnloop_conversations`,
  `cairnloop_messages`, `cairnloop_drafts`, and `cairnloop_conversation_slas` in the configured
  Cairnloop support prefix;
- run Cairnloop library migrations with prefix-aware table/index/reference/raw SQL code;
- run Oban migrations separately under the host's Oban configuration.

Existing public-schema compatibility path:

```elixir
config :cairnloop,
  repo: MyApp.Repo,
  schema_prefix: "public"
```

This mode should be explicit in docs and config. It should continue reading and writing
`public.cairnloop_*` tables. If the config is absent and the app has `public.cairnloop_*` tables but
no `cairnloop` schema, Cairnloop should emit an actionable upgrade error or doctor failure rather
than silently switching to empty dedicated-schema tables.

Dedicated-schema move path for existing installs:

1. Back up the database.
2. Stop app writes or enter a maintenance window.
3. Create the `cairnloop` schema.
4. Move support-domain tables with `ALTER TABLE public.cairnloop_* SET SCHEMA cairnloop`, excluding
   Oban tables and excluding unrelated host tables.
5. Move or recreate Cairnloop-owned functions, triggers, and indexes that were created by library
   migrations. Triggers follow their table, but trigger functions have their own schema placement
   and must be audited explicitly.
6. Leave `schema_migrations` in the host's normal migration location unless a deliberate migration
   history strategy says otherwise. Do not make migration history movement part of the default
   prefix change.
7. Deploy with `schema_prefix: "cairnloop"`.
8. Run structural checks that prove reads, writes, retrieval SQL, and Oban checks hit the intended
   schemas.

Rollback:

- Public compatibility is the low-risk rollback for runtime behavior: set `schema_prefix: "public"`
  if the data still lives in public.
- If tables were physically moved to `cairnloop`, rollback requires a planned reverse `ALTER TABLE`
  move and function/trigger audit.
- Rollback must not drop `vector` or Oban tables.

## Test Strategy

Coverage should prove both supported modes, not only compile-time migration generation.

- Migration tests should run the same library migration set into a dedicated `cairnloop` schema and
  into explicit public compatibility, then assert table, index, trigger, function, and FK placement.
- Runtime integration tests should create data in the configured prefix and assert facades and
  workers read/write there: `Chat`, `KnowledgeBase`, `Retrieval`, `Governance`, `Outbound`, MCP
  token handling, dashboard settings, and all relevant workers.
- Negative tests should create misleading same-name tables in `public` while using
  `schema_prefix: "cairnloop"` and prove Cairnloop does not read them.
- Public compatibility tests should create data only in `public` and prove the explicit setting
  preserves existing behavior.
- Raw SQL tests should cover `Retrieval.system_health/0`, full-text search providers, trigger
  updates, gap event alignment, and any `Ecto.Adapters.SQL.query/4` call.
- Oban tests should prove Cairnloop prefix config does not redirect `oban_jobs`.
- Installer source-scan tests should assert generated migrations include prefix-aware
  table/index/FK code, default dependency migrations use `--prefix cairnloop`, and public
  compatibility says to omit that flag.
- Docs tests should keep `README.md`, `guides/01-quickstart.md`,
  `guides/03-host-integration.md`, `guides/04-troubleshooting.md`, and the example app aligned
  with the new config and migration commands.

## Example App Changes

The example app should become the proof path for new installs:

- `examples/cairnloop_example/config/config.exs` should set `schema_prefix: "cairnloop"`.
- `examples/cairnloop_example/priv/repo/migrations/*` should create support-domain tables in the
  configured Cairnloop prefix while keeping `Oban.Migration.up()` host-owned.
- `examples/cairnloop_example/mix.exs` aliases should continue ordering host-support migrations
  before library migrations, but the library migrations themselves should qualify their objects.
- Example docs should show explicit public compatibility for adopters upgrading from the current
  public-schema layout.
- The example vector extension migration should stop dropping the extension on rollback, or the
  example should move extension creation into an explicit host-owned prerequisite.

## What Not To Overbuild

- Do not implement arbitrary per-tenant schema prefixes.
- Do not support multiple simultaneous Cairnloop prefixes in one host repo.
- Do not rely on `SET search_path` as the primary correctness mechanism.
- Do not present `mix ecto.migrate --prefix` as sufficient by itself.
- Do not move or rename Oban tables.
- Do not move arbitrary host app tables into the Cairnloop schema.
- Do not create a custom Repo or adapter layer unless the small prefix helper proves insufficient.
- Do not drop shared database extensions on rollback.
- Do not refactor unrelated UI, governance, or retrieval behavior while doing the prefix work.

## Acceptance Criteria

- A fresh install can run with `schema_prefix: "cairnloop"` and all Cairnloop support-domain tables,
  indexes, functions, triggers, raw SQL, and runtime queries use that schema.
- An existing install can run with explicit `schema_prefix: "public"` without moving data.
- FKs to support-domain tables resolve in the configured Cairnloop support prefix.
- Oban remains host-owned and unaffected by Cairnloop's prefix config.
- Retrieval health, full-text search fragments, and migration SQL contain no unqualified
  Cairnloop-owned table/function assumptions.
- Rollbacks do not drop `vector`.
- Installer output and docs explain both the new default and public compatibility without claiming
  a CLI prefix flag is enough.
