# Phase 59: Dedicated Postgres Schema Contract - Research

**Researched:** 2026-06-30
**Domain:** Elixir/Ecto/PostgreSQL schema-prefix contract
**Confidence:** HIGH for codebase findings; MEDIUM for external docs fetched through WebSearch official pages because Context7 was unavailable.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Prefix Contract

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

#### Ecto Schema and Runtime Access

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

#### Migration and Raw SQL Contract

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

#### Installer, Example, and Tests

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

### the agent's Discretion

- No owner-level question was escalated. `CLAUDE.md` directs GSD discuss-phase to auto-decide
  routine trust-sensitive implementation calls and surface only genuinely very-impactful choices.
  The dedicated-schema direction, public compatibility path, no-`--prefix` shortcut, and Oban
  boundary are already locked by vM019 project state and `docs/postgres-schema-prefix.md`.

### Deferred Ideas (OUT OF SCOPE)

- Multi-tenant or per-customer Cairnloop schema prefixes remain future scope.
- Hosted SaaS/demo, advanced routing, local AI, and mobile SDK work remain out of this milestone.
- Broad README, ExDoc, SECURITY, screenshots/assets, and package metadata cleanup belongs to
  Phase 60 after the DB contract is real.
- CI/runtime posture changes belong to Phase 61 unless a Phase 59 test lane requires a narrow
  command update.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DB-01 | New installs default Cairnloop support-domain tables to a dedicated Postgres schema prefix named `cairnloop`. [VERIFIED: .planning/REQUIREMENTS.md] | Use `config :cairnloop, :schema_prefix, "cairnloop"` as default and make test/example host migrations create support tables under that prefix. [VERIFIED: config/config.exs; VERIFIED: examples/cairnloop_example/config/config.exs] |
| DB-02 | Existing public-schema installs remain supported through explicit compatibility config and documented migration/upgrade path. [VERIFIED: .planning/REQUIREMENTS.md] | Keep legacy `nil`, add `"public"` proof where supported, and add public-mode DB tests before Phase 60 docs broaden the story. [VERIFIED: 59-CONTEXT.md; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html] |
| DB-03 | Library migrations qualify Cairnloop-owned objects, references, indexes, functions, triggers, and raw SQL safely without relying on `mix ecto.migrate --prefix`. [VERIFIED: .planning/REQUIREMENTS.md] | Convert all `priv/repo/migrations/*.exs` DDL helpers to `prefix: prefix`; raw SQL already has partial `SchemaPrefix.quoted_table/1` usage but DDL remains mostly unqualified. [VERIFIED: priv/repo/migrations/20260516000000_create_knowledge_base.exs; VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] |
| DB-04 | Library migrations do not drop shared host extensions such as `vector` on rollback. [VERIFIED: .planning/REQUIREMENTS.md] | Library migration no longer drops `vector`, but the example app still does and must be corrected. [VERIFIED: priv/repo/migrations/20260516000000_create_knowledge_base.exs; VERIFIED: examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs; CITED: https://www.postgresql.org/docs/current/sql-dropextension.html] |
| DB-05 | Runtime Ecto reads/writes, preload paths, fragments, and structural health checks honor the configured Cairnloop prefix without redirecting arbitrary host-app schemas or Oban tables. [VERIFIED: .planning/REQUIREMENTS.md] | Expand helper use across `Chat`, `KnowledgeBase`, `Retrieval`, `Governance`, `Outbound`, `MCP`, workers, preloads, `insert_all`, and doctor checks; keep `oban_jobs` public/host-owned. [VERIFIED: lib/cairnloop/chat.ex; VERIFIED: lib/cairnloop/retrieval.ex; VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex] |
| DB-06 | Tests prove both dedicated-schema new installs and explicit public-schema compatibility. [VERIFIED: .planning/REQUIREMENTS.md] | Add DB-backed integration tests for object placement, public compatibility, collision isolation, raw SQL, trigger/function placement, FKs, Oban boundary, and source-scan drift. [VERIFIED: test/support/data_case.ex; VERIFIED: test/cairnloop/migrations_test.exs] |
| DB-07 | The example app uses the new dedicated schema default and documents how to switch to public only when a host intentionally chooses that compatibility mode. [VERIFIED: .planning/REQUIREMENTS.md] | Set example Cairnloop config and migration aliases/migrations to dedicated prefix, retain Oban migration host-owned, and add example setup proof. [VERIFIED: examples/cairnloop_example/config/config.exs; VERIFIED: examples/cairnloop_example/mix.exs] |
</phase_requirements>

## Summary

Phase 59 should be planned as a contract-hardening phase, not a feature expansion: the single canonical path is a configured Cairnloop support prefix, defaulting to `"cairnloop"`, with explicit public compatibility for existing installs and no per-tenant or hot prefix switching. [VERIFIED: 59-CONTEXT.md] The key technical risk is that Ecto has multiple prefix surfaces with different precedence rules: query `Repo` prefixes do not override schema or `from`/`join` prefixes, while schema write operations document `opts[:prefix]` as an override. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Repo.html]

The codebase already contains a first-pass `Cairnloop.SchemaPrefix` helper and compile-time schema prefixes, but the integration host and example app still create public `cairnloop_*` tables and the local `cairnloop_test` and `cairnloop_example_test` databases currently contain only public Cairnloop tables plus `public.oban_jobs`. [VERIFIED: lib/cairnloop/schema_prefix.ex; VERIFIED: config/test.exs; VERIFIED: psql inventory 2026-06-30] The planner should split work by responsibility: helper semantics first, migration DDL/raw SQL second, runtime facades/workers third, installer/example/test host fourth, then DB-backed proof and source-scan gates. [VERIFIED: codebase]

**Primary recommendation:** Use and expand `Cairnloop.SchemaPrefix` as the only prefix abstraction, qualify all Cairnloop support-domain DDL/raw SQL/runtime access explicitly, keep Oban outside the helper path, and prove both `"cairnloop"` and explicit public modes against real Postgres before docs are broadened. [VERIFIED: 59-CONTEXT.md; CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Prefix normalization and SQL identifier quoting | API / Backend | Database / Storage | `Cairnloop.SchemaPrefix` owns host config normalization and safe string construction before Ecto or raw SQL reaches Postgres. [VERIFIED: lib/cairnloop/schema_prefix.ex] |
| Ecto schema/query/write prefix behavior | API / Backend | Database / Storage | Cairnloop facades/workers construct queries and changesets; Postgres object placement is the persistence result. [VERIFIED: lib/cairnloop/chat.ex; VERIFIED: lib/cairnloop/knowledge_base.ex] |
| Migration object placement | Database / Storage | API / Backend | Ecto migrations create/alter/drop database objects; migration modules must pass the configured prefix explicitly. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html] |
| Raw SQL and trigger/function qualification | Database / Storage | API / Backend | Direct SQL bypasses Ecto source qualification and must use validated schema-qualified identifiers. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html] |
| Installer-generated substrate | API / Backend | Database / Storage | `mix cairnloop.install` emits host migration source and setup guidance that shape adopter DB state. [VERIFIED: lib/mix/tasks/cairnloop/install.ex] |
| Example/test-host compatibility proof | Database / Storage | API / Backend | The example app and integration host run real migrations and queries, proving object placement and public compatibility. [VERIFIED: examples/cairnloop_example/mix.exs; VERIFIED: test/support/data_case.ex] |
| Oban boundary | Database / Storage | API / Backend | Oban tables are host-owned and must not inherit the Cairnloop schema prefix. [VERIFIED: 59-CONTEXT.md; VERIFIED: priv/test_host/migrations/20260101000001_add_oban_jobs.exs] |

## Project Constraints (from AGENTS.md)

- Read `CLAUDE.md` first for all work in this repo. [VERIFIED: AGENTS.md]
- For UI work, also read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`. [VERIFIED: AGENTS.md]
- The shipped dashboard uses Cairnloop's tokenized `.cl-*` / BEM CSS system, not Tailwind. [VERIFIED: AGENTS.md]
- Keep adopter-facing UI changes inside the component system so spacing, motion, color, and accessibility improve globally instead of drifting screen by screen. [VERIFIED: AGENTS.md]
- Warnings-clean builds are mandatory; code must pass `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- Run `mix ci.fast` before declaring headless work done; for DB-backed changes also run `mix ci.integration`. [VERIFIED: CLAUDE.md]
- Known caveat: `Cairnloop.Repo` may be unavailable in this workspace, so DB tests can be written with a `# REPO-UNAVAILABLE` note only where a real round trip cannot run here. [VERIFIED: CLAUDE.md]
- Public function signatures from shipped phases are sealed; Phase 59 should use additive helpers/config/tests rather than public API churn. [VERIFIED: CLAUDE.md; VERIFIED: .planning/PROJECT.md]
- New web-layer reads continue through narrow facades, especially `Cairnloop.Governance`; do not add direct schema queries from LiveViews. [VERIFIED: CLAUDE.md; VERIFIED: .planning/PROJECT.md]

## Current Codebase Findings

| Area | Finding | Planning Impact |
|------|---------|-----------------|
| Default config | `config/config.exs` sets `config :cairnloop, :schema_prefix, "cairnloop"`. [VERIFIED: config/config.exs] | Keep as new-install default and make tests/example agree. |
| Test config | `config/test.exs` explicitly sets `schema_prefix` to `nil` because current integration migrations still create public tables. [VERIFIED: config/test.exs] | Move main integration proof to dedicated default; keep public-mode proof deliberate. |
| Helper | `Cairnloop.SchemaPrefix` has `default/0`, `configured/1`, `repo_opts/1`, `quoted_table/2`, `quote_identifier!/1`, and `normalize!/1`; it accepts `nil`/empty string as public compatibility and validates single identifiers. [VERIFIED: lib/cairnloop/schema_prefix.ex] | Expand this helper, do not create parallel prefix modules. |
| Schema modules | Cairnloop schema modules declare `@schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")`. [VERIFIED: lib/cairnloop/conversation.ex; VERIFIED: lib/cairnloop/message.ex; VERIFIED: test/cairnloop/schema_prefix_test.exs] | Public compatibility must be tested with the actual compile mode or explicit from/join prefixes where needed. |
| Library migration DDL | Most `priv/repo/migrations/*.exs` table/index/reference/alter calls omit `prefix: prefix`, while raw SQL in two migrations partly uses `SchemaPrefix.quoted_table/1`. [VERIFIED: priv/repo/migrations/20260516000000_create_knowledge_base.exs; VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] | Plan a dedicated migration conversion pass for all DDL helpers, not just raw SQL strings. |
| Vector rollback | Library KB migration creates `vector` and no longer drops it; example app vector migration still drops `vector` in `down/0`. [VERIFIED: priv/repo/migrations/20260516000000_create_knowledge_base.exs; VERIFIED: examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs] | Fix example rollback and keep source-scan tests covering example and library migrations. |
| Runtime raw SQL | `Retrieval.system_health/0` qualifies `cairnloop_chunks` through `SchemaPrefix.quoted_table/1` but still checks `oban_jobs` directly. [VERIFIED: lib/cairnloop/retrieval.ex] | Keep Oban direct/host-owned; improve health/doctor to report configured prefix honestly. |
| Runtime writes | `Chat`, `KnowledgeBase`, `Governance`, `Outbound`, `MCP`, settings, and workers use `repo().insert/update/get/all/transaction/preload` without central prefix opts. [VERIFIED: lib/cairnloop/chat.ex; VERIFIED: lib/cairnloop/governance.ex; VERIFIED: lib/cairnloop/outbound.ex; VERIFIED: lib/cairnloop/mcp.ex] | Audit and wrap operations where schema prefixes are not enough, especially public mode and bulk operations. |
| Bulk operations | `ChunkRevision` and `IndexResolvedConversation` use `Ecto.Multi.insert_all` and `delete_all` for chunk refreshes. [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex; VERIFIED: lib/cairnloop/retrieval/workers/index_resolved_conversation.ex] | Add explicit `SchemaPrefix.repo_opts()` to `Multi.insert_all/delete_all` or prove schema-module prefix suffices in both modes. |
| Installer | `mix cairnloop.install` generates prefix-aware conversation/message host migrations but still tells adopters to run dependency migrations with `--prefix cairnloop`. [VERIFIED: lib/mix/tasks/cairnloop/install.ex] | Update wording so the CLI flag is a helper, not the contract, and generated host migration covers full support-domain set as needed. |
| Example app | Example config currently does not set `:schema_prefix`, and example support migrations create public `cairnloop_*` tables. [VERIFIED: examples/cairnloop_example/config/config.exs; VERIFIED: examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs] | Make example the dedicated-schema proof path. |
| Test host | `priv/test_host/migrations` creates public support tables and host-owned `public.oban_jobs`. [VERIFIED: priv/test_host/migrations/20260101000000_create_host_owned_tables.exs; VERIFIED: priv/test_host/migrations/20260101000001_add_oban_jobs.exs] | Convert support tables to prefix-aware while keeping Oban public. |
| Live local DB | `cairnloop_test` and `cairnloop_example_test` currently have public Cairnloop tables and public Oban tables; neither has a `cairnloop` schema. [VERIFIED: psql inventory 2026-06-30] | Planner should include DB reset or setup-proof tasks; stale public DB state can mask bugs. |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 local | Build, compile, and test runtime. [VERIFIED: `elixir --version`; VERIFIED: `mix --version`] | Project requires Elixir `~> 1.19` in `mix.exs`. [VERIFIED: mix.exs] |
| Ecto | 3.13.6 locked | Schema/query/prefix behavior. [VERIFIED: `mix deps`; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html] | Existing project dependency via `ecto_sql`; no replacement needed. [VERIFIED: mix.exs] |
| Ecto SQL | 3.13.5 locked | Migrations, SQL adapter integration, `mix ecto.migrate`. [VERIFIED: `mix deps`; CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html] | Provides native prefix options for tables, indexes, references, and migrator prefix. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html] |
| Postgrex | 0.22.2 locked | PostgreSQL adapter and query execution. [VERIFIED: `mix deps`] | Existing Ecto Postgres adapter path. [VERIFIED: test/support/repo.ex] |
| PostgreSQL / pgvector image | Local psql 14.17; CI uses `pgvector/pgvector:pg16` | DB-backed migration/runtime proof. [VERIFIED: `psql --version`; VERIFIED: .github/workflows/ci.yml; VERIFIED: docker-compose.yml] | Required for real schema/object placement tests. [VERIFIED: test/support/data_case.ex] |
| pgvector Elixir package | 0.3.1 locked | Ecto vector type and embedding distance queries. [VERIFIED: `mix deps`] | Existing KB/retrieval migrations and queries use `:vector` and `Pgvector.new/1`. [VERIFIED: priv/repo/migrations/20260516000000_create_knowledge_base.exs; VERIFIED: lib/cairnloop/knowledge_base.ex] |
| Oban | 2.22.1 locked | Host-owned background job substrate. [VERIFIED: `mix deps`] | Must remain outside Cairnloop prefix while worker inserts continue to work. [VERIFIED: 59-CONTEXT.md; VERIFIED: priv/test_host/migrations/20260101000001_add_oban_jobs.exs] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Igniter | 0.8.0 locked | Installer source generation. [VERIFIED: `mix deps`; VERIFIED: lib/mix/tasks/cairnloop/install.ex] | Extend installer output and generated host migration source. |
| ExUnit + Ecto SQL Sandbox | Built into Elixir/Ecto | DB-backed integration isolation. [VERIFIED: test/support/data_case.ex] | Use for dedicated/public schema proof and collision tests. |
| Phoenix/LiveView example app | Phoenix 1.8.7, LiveView 1.1.30 locked | Adoption proof host. [VERIFIED: `mix deps`; VERIFIED: examples/cairnloop_example/mix.exs] | Use for example setup/schema default proof; no UI redesign needed. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit Ecto migration/runtime prefixes | `SET search_path` | Rejected by locked decision and Postgres docs because unqualified object resolution follows search_path and can be ambiguous or unsafe. [VERIFIED: 59-CONTEXT.md; CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| `Cairnloop.SchemaPrefix` | New per-facade helpers | Rejected by D-02; central helper keeps validation and quoting in one place. [VERIFIED: 59-CONTEXT.md] |
| Source scans only | DB-backed proof | Rejected by D-16 because functions, triggers, FKs, `vector`, and raw SQL object placement require Postgres proof. [VERIFIED: 59-CONTEXT.md] |

**Installation:**

No new package install is recommended for Phase 59. [VERIFIED: mix.exs; VERIFIED: 59-CONTEXT.md]

## Package Legitimacy Audit

No new external package is recommended or required for this phase, so the Package Legitimacy Gate is not applicable. [VERIFIED: mix.exs; VERIFIED: codebase]

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```text
Host config
  config :cairnloop, :schema_prefix, "cairnloop" | "public" | nil
        |
        v
Cairnloop.SchemaPrefix
  normalize -> repo opts -> Ecto query/write opts
  normalize -> quoted identifiers -> raw SQL/table/function refs
        |
        +--> Ecto schemas/facades/workers
        |      Chat / KnowledgeBase / Retrieval / Governance / MCP / Outbound
        |      queries, preloads, Ecto.Multi, insert_all/delete_all
        |
        +--> Migrations and installer-generated host migrations
        |      create/alter/drop table, index, references, constraints, functions, triggers
        |
        +--> Doctor/structural checks
               configured prefix exists, Cairnloop tables exist there,
               public collisions detected, vector present, Oban checked separately

PostgreSQL
  cairnloop.cairnloop_*       <- Cairnloop support domain by default
  public.cairnloop_*          <- explicit compatibility only
  public.oban_jobs or host cfg <- host-owned Oban, not redirected
  pg_extension.vector         <- shared database extension, never dropped by rollback
```

### Recommended Project Structure

```text
lib/cairnloop/
  schema_prefix.ex                 # canonical prefix helper
  chat.ex                          # facade write/read conversion
  knowledge_base.ex                # KB facade conversion
  retrieval.ex                     # health and Oban boundary
  retrieval/providers/*.ex         # query-source prefix proof
  retrieval/workers/*.ex           # insert_all/delete_all prefix proof
  governance.ex                    # proposal/approval/event prefix proof
  outbound.ex                      # envelope/message multi prefix proof
  doctor.ex                        # prefix/readiness truth

priv/repo/migrations/
  *.exs                            # library support-domain DDL and raw SQL qualification

priv/test_host/migrations/
  *.exs                            # integration host support tables in configured prefix; Oban public

examples/cairnloop_example/
  config/*.exs                     # example prefix default
  priv/repo/migrations/*.exs       # example host support tables in configured prefix
  test/*                           # example setup/schema proof

test/
  cairnloop/*_test.exs             # source scans and helper tests
  integration/*_test.exs           # DB-backed dedicated/public schema proof
```

### Pattern 1: Central Prefix Helper

**What:** Expand `Cairnloop.SchemaPrefix` to supply all prefix-sensitive primitives: normalization, public compatibility handling, repo opts, query/source helpers if needed, quoted identifiers, and migration/raw SQL table/function names. [VERIFIED: lib/cairnloop/schema_prefix.ex]

**When to use:** Every time code constructs a Cairnloop support-domain SQL object reference or decides Repo options. [VERIFIED: 59-CONTEXT.md]

**Example:**

```elixir
# Source: lib/cairnloop/schema_prefix.ex and Ecto Repo prefix docs
prefix = Cairnloop.SchemaPrefix.configured()
opts = Cairnloop.SchemaPrefix.repo_opts(timeout: 15_000)
table = Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks")

repo().all(query, opts)
Ecto.Adapters.SQL.query!(repo(), "SELECT id FROM #{table} LIMIT 1", [])
```

### Pattern 2: Migration Prefix Variable Per Module

**What:** Define `prefix = Cairnloop.SchemaPrefix.configured()` at the start of each migration direction and pass it to `table/2`, `index/3`, `unique_index/3`, `references/2`, and raw SQL helpers. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html]

**When to use:** Every Cairnloop support-domain migration in `priv/repo/migrations`, `priv/test_host/migrations`, and example app migrations. [VERIFIED: codebase]

**Example:**

```elixir
# Source: Ecto.Migration prefixes docs
def change do
  prefix = Cairnloop.SchemaPrefix.configured()

  if prefix do
    execute("CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}")
  end

  create table(:cairnloop_revisions, prefix: prefix) do
    add(:article_id, references(:cairnloop_articles, prefix: prefix, on_delete: :delete_all),
      null: false
    )
  end

  create(index(:cairnloop_revisions, [:article_id], prefix: prefix))
end
```

### Pattern 3: Oban Boundary Is Explicit

**What:** Cairnloop prefix helpers should not be applied to `oban_jobs`; Oban placement remains host-owned. [VERIFIED: 59-CONTEXT.md]

**When to use:** `Retrieval.system_health/0`, `replay_failed/1`, worker enqueue tests, test-host Oban migration, and example `AddOban` migration. [VERIFIED: lib/cairnloop/retrieval.ex; VERIFIED: examples/cairnloop_example/priv/repo/migrations/20260525201621_add_oban.exs]

**Example:**

```elixir
# Source: lib/cairnloop/retrieval.ex and Phase 59 D-07
chunk_sql = "SELECT id FROM #{Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks")} LIMIT 1"
oban_sql = "SELECT 1 FROM oban_jobs WHERE state IN ('retryable', 'discarded') LIMIT 1"
```

### Anti-Patterns to Avoid

- **Relying on `mix ecto.migrate --prefix` as the contract:** It is only a migrator option and does not fix raw SQL, fragments, runtime queries, trigger functions, or Oban boundary behavior. [VERIFIED: 59-CONTEXT.md; CITED: https://ecto-sql.hexdocs.pm/3.13.5/Mix.Tasks.Ecto.Migrate.html]
- **Adding `SET search_path` as the primary mechanism:** Postgres resolves unqualified names via search_path and warns about security/ambiguity when writable schemas are in path. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]
- **Assuming `Repo.all(query, prefix: "public")` overrides schema prefixes:** Ecto query prefix precedence gives `from`/`join` prefixes and `@schema_prefix` precedence over query/Repo prefix. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]
- **Dropping `vector` on rollback:** `DROP EXTENSION` removes extension member objects and can cascade to dependent objects, so Cairnloop rollback must not drop shared database extensions. [CITED: https://www.postgresql.org/docs/current/sql-dropextension.html]
- **Moving Oban into Cairnloop prefix:** Oban remains host-owned by locked decision. [VERIFIED: 59-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Query/write prefixing | Custom SQL string rewrites around Ecto queries | Ecto `prefix:` options, `from`/`join` prefix, schema prefixes, and `Cairnloop.SchemaPrefix.repo_opts/1` | Ecto already owns query source qualification and different operations have documented prefix semantics. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Repo.html] |
| Migration object placement | Search-path changes or CLI-only migration flags | Ecto migration `prefix:` on `table`, `index`, `references`, `constraint`, plus explicit raw SQL qualification | Ecto migration docs support native prefixes and references inherit surrounding table prefix by default. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html] |
| Identifier quoting | Interpolating host config into raw SQL | `Cairnloop.SchemaPrefix.quote_identifier!/1` and `quoted_table/2` | Existing helper validates single SQL identifiers before quoting. [VERIFIED: lib/cairnloop/schema_prefix.ex] |
| Extension lifecycle | Extension drop/recreate during app rollback | `CREATE EXTENSION IF NOT EXISTS vector` only, plus doctor/prereq guidance | PostgreSQL tracks extension member objects for drop; dropping shared `vector` can remove infrastructure other app code uses. [CITED: https://www.postgresql.org/docs/current/sql-createextension.html; CITED: https://www.postgresql.org/docs/current/sql-dropextension.html] |
| Test proof | Regex-only source scans | ExUnit + Ecto SQL Sandbox + information_schema/pg_catalog assertions | Source scans cannot prove FK/function/trigger/table placement under real Postgres. [VERIFIED: 59-CONTEXT.md; VERIFIED: test/support/data_case.ex] |

**Key insight:** The hard part is consistency across independent prefix surfaces, not creating the schema; a partial fix can pass compile but silently read from empty dedicated tables or public compatibility tables depending on compile mode and query shape. [VERIFIED: codebase; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Local `cairnloop_test` and `cairnloop_example_test` databases contain `public.cairnloop_*` tables and no `cairnloop` schema; `vector` is installed. [VERIFIED: psql inventory 2026-06-30] | Include reset/setup or migration-proof tasks so old public state does not mask dedicated-schema failures. |
| Live service config | No external live-service UI/database config was found for this prefix contract; repo config files set default `"cairnloop"` in `config/config.exs` and test public compatibility in `config/test.exs`. [VERIFIED: rg config scan] | Update code/config docs and tests; no external service patch identified. |
| OS-registered state | `launchctl` shows Homebrew PostgreSQL service `homebrew.mxcl.postgresql@14`; no Cairnloop-specific launchd state found. [VERIFIED: launchctl scan] | No OS registration change required; use DB reset/migrations, not launchd changes. |
| Secrets/env vars | No current shell `CAIRNLOOP*`, `DATABASE_URL`, or `PG*` env vars were set; config files read `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, and example runtime reads `DATABASE_URL`. [VERIFIED: printenv scan; VERIFIED: rg config scan] | Planner should avoid depending on env-only prefix switches; use explicit app config and test commands. |
| Build artifacts | `_build` and example `_build` contain compiled Cairnloop artifacts, including schemas with compile-time `@schema_prefix`. [VERIFIED: find `_build` scan; VERIFIED: lib/cairnloop/conversation.ex] | Run clean compile or force recompilation after changing `config/test.exs` prefix because `Application.compile_env/3` is captured at compile time. |

**Nothing found in category:** No non-git external service configuration or Cairnloop-specific OS registration was found in this session. [VERIFIED: scan results]

## Common Pitfalls

### Pitfall 1: Repo Prefix Options Do Not Override Query Schema Prefixes

**What goes wrong:** Public compatibility appears configured but query reads still target `cairnloop.*` because `@schema_prefix` wins over Repo query prefix. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]
**Why it happens:** Ecto query prefix precedence is `from`/`join` prefix, then `@schema_prefix`, then query/Repo prefix. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]
**How to avoid:** Public-mode tests must run under the actual compile/config mode or use explicit `from`/`join` prefix helpers for every query source. [VERIFIED: 59-CONTEXT.md]
**Warning signs:** `Repo.all(query, prefix: "public")` is the only public-mode override in a query path. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Repo.html]

### Pitfall 2: DDL Prefix Gaps Survive Raw SQL Fixes

**What goes wrong:** Raw SQL points at `cairnloop.*`, but `create table`, `alter table`, `index`, and FK operations still affect public/default schema. [VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs]
**Why it happens:** Ecto migration helpers need explicit `prefix:` unless a migration default prefix is active. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html]
**How to avoid:** Convert every support-domain migration helper call, not only `execute/1` strings. [VERIFIED: codebase]
**Warning signs:** `table(:cairnloop_...)`, `index(:cairnloop_...)`, `references(:cairnloop_...)`, or `alter table(:cairnloop_...)` without `prefix:`. [VERIFIED: rg migration scan]

### Pitfall 3: Reference Prefix Inheritance Can Misplace Foreign Keys

**What goes wrong:** FKs to support-domain tables work, but a future FK to a host-owned non-Cairnloop table accidentally inherits the Cairnloop prefix. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html]
**Why it happens:** Ecto references inside a prefixed table default to the table block's prefix. [CITED: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html]
**How to avoid:** For support-domain FKs, pass `prefix: prefix`; for non-support-domain targets, pass the target prefix deliberately. [VERIFIED: 59-CONTEXT.md]
**Warning signs:** New `references(:host_table)` inside a Cairnloop-prefixed table block without target-prefix commentary. [VERIFIED: 59-CONTEXT.md]

### Pitfall 4: `insert_all` and `delete_all` Are Easy to Miss

**What goes wrong:** Chunk refresh workers delete/insert rows in the wrong schema or only pass under one compile mode. [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex; VERIFIED: lib/cairnloop/retrieval/workers/index_resolved_conversation.ex]
**Why it happens:** Bulk operations do not flow through ordinary changeset struct insert behavior and must be considered separately. [CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Repo.html; CITED: https://ecto.hexdocs.pm/Ecto.Multi.html]
**How to avoid:** Add helper-backed opts to `Ecto.Multi.insert_all/delete_all` or DB-prove schema module prefix behavior in both modes. [VERIFIED: codebase]
**Warning signs:** `Ecto.Multi.insert_all(..., Chunk, chunk_records)` with no opts. [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex]

### Pitfall 5: Example App Rollback Drops Shared Vector

**What goes wrong:** Rolling back the example app removes `vector` for the whole database. [VERIFIED: examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs]
**Why it happens:** Example migration currently issues `DROP EXTENSION IF EXISTS vector;` in `down/0`. [VERIFIED: examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs]
**How to avoid:** Make `down/0` a no-op for `vector` or move extension creation into explicit host prerequisite/doctor guidance. [CITED: https://www.postgresql.org/docs/current/sql-dropextension.html]
**Warning signs:** Any `DROP EXTENSION ... vector` in library, test-host, or example migrations. [VERIFIED: test/cairnloop/migrations_test.exs]

## Code Examples

Verified patterns from official sources and current code:

### Ecto Query Prefix Precedence

```elixir
# Source: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html
# Precedence: from/join prefix > @schema_prefix > query/Repo prefix.
query =
  from c in Cairnloop.Conversation,
    prefix: Cairnloop.SchemaPrefix.configured(),
    where: c.status == :open

repo().all(query)
```

### Prefix-Aware Migration Helper Pattern

```elixir
# Source: https://ecto-sql.hexdocs.pm/3.13.5/Ecto.Migration.html
def change do
  prefix = Cairnloop.SchemaPrefix.configured()

  if prefix do
    execute("CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}")
  end

  create table(:cairnloop_messages, prefix: prefix) do
    add :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all),
        null: false
  end

  create index(:cairnloop_messages, [:conversation_id], prefix: prefix)
end
```

### Raw SQL Qualification Pattern

```elixir
# Source: lib/cairnloop/retrieval.ex
chunks_table = Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks")
Ecto.Adapters.SQL.query!(repo(), "SELECT id FROM #{chunks_table} LIMIT 1", [])
```

### Public Compatibility Test Shape

```elixir
# Source: test/support/data_case.ex and Phase 59 D-15
setup do
  original = Application.get_env(:cairnloop, :schema_prefix)
  Application.put_env(:cairnloop, :schema_prefix, "public")
  on_exit(fn -> if original, do: Application.put_env(:cairnloop, :schema_prefix, original), else: Application.delete_env(:cairnloop, :schema_prefix) end)
end
```

The exact public-mode test implementation must account for compile-time `@schema_prefix`; a runtime `Application.put_env/3` alone is not sufficient for schema modules compiled with `"cairnloop"`. [VERIFIED: lib/cairnloop/conversation.ex; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Public-schema unqualified `cairnloop_*` tables | Dedicated `cairnloop` support schema by default with explicit public compatibility | vM019 Phase 59 locked decision on 2026-06-30 [VERIFIED: 59-CONTEXT.md] | Avoids polluting host public schema and makes Cairnloop footprint inspectable. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| Raw table/function names in migration SQL | `Cairnloop.SchemaPrefix.quoted_table/1` for raw SQL identifiers | First pass before Phase 59 research [VERIFIED: docs/postgres-schema-prefix.md; VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] | Still incomplete because DDL helpers remain mostly unprefixed. [VERIFIED: rg migration scan] |
| Example/test-host public tables | Example/test-host as dedicated-schema proof path | Required by D-14 [VERIFIED: 59-CONTEXT.md] | Converts adoption proof from docs claim to runnable DB behavior. [VERIFIED: examples/cairnloop_example/mix.exs; VERIFIED: test/support/data_case.ex] |

**Deprecated/outdated:**

- Teaching `mix ecto.migrate --prefix cairnloop` as sufficient is outdated; the flag exists but does not solve raw SQL/runtime prefixing. [VERIFIED: 59-CONTEXT.md; CITED: https://ecto-sql.hexdocs.pm/3.13.5/Mix.Tasks.Ecto.Migrate.html]
- Dropping `vector` in rollback is unsafe for a shared host database. [CITED: https://www.postgresql.org/docs/current/sql-dropextension.html]
- Relying on unqualified names plus search_path is unsafe for this contract. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ASVS category mapping below is interpreted for this database-prefix phase rather than copied from a project-specific ASVS matrix. [ASSUMED] | Security Domain | Planner may add too broad or too narrow a security checklist. |

## Open Questions (RESOLVED)

1. **Public compatibility spelling**
   - Resolution: Support legacy `nil` and explicit `"public"` per D-03. Document and test `"public"` as the preferred explicit public-schema compatibility spelling while preserving `nil` and empty string as accepted legacy compatibility inputs. [VERIFIED: 59-CONTEXT.md; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]

2. **Compile-mode strategy for dual-mode tests**
   - Resolution: Use the default dedicated-schema test compile for normal Phase 59 verification, and add an exact public-mode compile/test lane for public compatibility: `CAIRNLOOP_SCHEMA_PREFIX=public MIX_ENV=test mix do clean, compile --force --warnings-as-errors, test --include integration test/integration/public_schema_compatibility_test.exs --warnings-as-errors`. This proves public mode under the actual compile/config path used by schema modules instead of relying on runtime `Application.put_env/3` against modules compiled with the dedicated default. [VERIFIED: lib/cairnloop/conversation.ex; VERIFIED: 59-CONTEXT.md; CITED: https://ecto.hexdocs.pm/3.13.6/Ecto.Query.html]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Compile/tests | yes | 1.19.5 | None needed. [VERIFIED: `elixir --version`] |
| Mix | Compile/tests/migrations | yes | 1.19.5 | None needed. [VERIFIED: `mix --version`] |
| PostgreSQL server | DB-backed integration proof | yes | Server accepting on local 5432; psql 14.17 client | Docker pgvector service if local service unavailable. [VERIFIED: `pg_isready`; VERIFIED: `psql --version`; VERIFIED: docker-compose.yml] |
| Docker | Optional DB/demo fallback | yes | 29.5.2 | Homebrew PostgreSQL is currently running. [VERIFIED: `docker --version`; VERIFIED: launchctl scan] |
| pgvector extension | Retrieval migrations/tests | yes in `cairnloop_test` | `vector` installed | CI/docker use `pgvector/pgvector:pg16`. [VERIFIED: psql inventory; VERIFIED: .github/workflows/ci.yml] |
| Context7 CLI/MCP | Documentation lookup | no | unavailable | Used official docs through WebSearch and cached digests. [VERIFIED: `ctx7` check; CITED: official docs URLs] |

**Missing dependencies with no fallback:** none found. [VERIFIED: environment probes]

**Missing dependencies with fallback:**

- Context7 unavailable; official HexDocs/PostgreSQL docs were fetched through WebSearch and tagged MEDIUM confidence by the GSD confidence seam. [VERIFIED: gsd classify-confidence; CITED: official docs URLs]

## Recommended Plan Boundaries And Verification Strategy

| Requirement | Plan Boundary | Verification |
|-------------|---------------|--------------|
| DB-01 | Convert default test/example path to `schema_prefix: "cairnloop"` and create schema-qualified support-domain tables. [VERIFIED: config/config.exs; VERIFIED: 59-CONTEXT.md] | DB test asserts `information_schema.tables` has `cairnloop.cairnloop_*` and no accidental public reads. |
| DB-02 | Keep explicit public compatibility with `nil` and `"public"` handling. [VERIFIED: 59-CONTEXT.md] | Public-mode integration test runs public tables only and verifies facade reads/writes. |
| DB-03 | Update every library migration DDL/raw SQL object placement. [VERIFIED: rg migration scan] | Source scan plus DB test for tables, indexes, FKs, triggers, functions, and raw backfills under configured prefix. |
| DB-04 | Remove `DROP EXTENSION vector` from library/example rollback paths. [VERIFIED: examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs] | Source scan across `priv/repo`, `priv/test_host`, and example migrations; rollback test or manual migration-down proof keeps `pg_extension.vector`. |
| DB-05 | Prefix runtime facades/workers/preloads/bulk ops/structural checks; keep Oban host-owned. [VERIFIED: lib/cairnloop/retrieval.ex; VERIFIED: lib/cairnloop/outbound.ex] | Collision test with misleading `public.cairnloop_*`; Oban test asserts `public.oban_jobs` remains target. |
| DB-06 | Add DB-backed tests for both modes and source scans for drift. [VERIFIED: test/support/data_case.ex] | `mix ci.integration` plus targeted integration modules. |
| DB-07 | Update example app config/migrations/aliases and minimal docs. [VERIFIED: examples/cairnloop_example/config/config.exs; VERIFIED: examples/cairnloop_example/mix.exs] | `cd examples/cairnloop_example && MIX_ENV=test mix test`; run `mix test.e2e` only if browser-mounted behavior is touched. [VERIFIED: examples/cairnloop_example/AGENTS.md] |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto SQL Sandbox for integration; example app ExUnit/Phoenix tests. [VERIFIED: test/support/data_case.ex; VERIFIED: examples/cairnloop_example/test/support/data_case.ex] |
| Config file | `config/test.exs`; example `examples/cairnloop_example/config/test.exs`. [VERIFIED: config/test.exs; VERIFIED: examples/cairnloop_example/config/test.exs] |
| Quick run command | `mix test test/cairnloop/schema_prefix_test.exs test/cairnloop/migrations_test.exs test/cairnloop/tasks/install_test.exs --warnings-as-errors` [VERIFIED: existing test files] |
| Full suite command | `mix ci.fast && mix ci.integration && cd examples/cairnloop_example && mix test` [VERIFIED: mix.exs; VERIFIED: examples/cairnloop_example/mix.exs] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| DB-01 | Dedicated `cairnloop` schema contains support tables after setup. [VERIFIED: 59-CONTEXT.md] | integration | `mix test.integration --only integration test/integration/schema_prefix_contract_test.exs` | No - Wave 0 |
| DB-02 | Explicit public compatibility reads/writes public support tables. [VERIFIED: 59-CONTEXT.md] | integration | `mix test.integration --only integration test/integration/public_schema_compatibility_test.exs` | No - Wave 0 |
| DB-03 | Migration DDL/raw SQL objects are prefix-qualified. [VERIFIED: 59-CONTEXT.md] | unit + integration | `mix test test/cairnloop/migrations_test.exs --warnings-as-errors` and integration catalog assertions | Partial - extend |
| DB-04 | Rollback paths do not drop `vector`. [VERIFIED: .planning/REQUIREMENTS.md] | unit + integration/manual migration rollback | `mix test test/cairnloop/migrations_test.exs --warnings-as-errors` | Partial - extend to example |
| DB-05 | Runtime facades/workers/preloads/health checks honor prefix and keep Oban host-owned. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix test.integration --only integration test/integration/schema_prefix_runtime_test.exs` | No - Wave 0 |
| DB-06 | Dedicated and public modes both proven. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix ci.integration` | Partial infrastructure only |
| DB-07 | Example app uses dedicated default and can set up successfully. [VERIFIED: .planning/REQUIREMENTS.md] | example integration/smoke | `cd examples/cairnloop_example && MIX_ENV=test mix test` | Partial - existing tests, missing prefix proof |

### Sampling Rate

- **Per task commit:** Run the targeted file(s) affected by that task plus `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- **Per wave merge:** Run `mix ci.fast` for source-scan/helper waves and `mix ci.integration` for DB-backed waves. [VERIFIED: CLAUDE.md; VERIFIED: mix.exs]
- **Phase gate:** Run `mix ci.fast`, `mix ci.integration`, and example app setup tests; add `cd examples/cairnloop_example && mix test.e2e` if browser-mounted behavior or routes are affected. [VERIFIED: CLAUDE.md; VERIFIED: examples/cairnloop_example/AGENTS.md]

### Wave 0 Gaps

- [ ] `test/integration/schema_prefix_contract_test.exs` - proves dedicated schema object placement for DB-01/DB-03/DB-06. [VERIFIED: missing file scan]
- [ ] `test/integration/public_schema_compatibility_test.exs` - proves DB-02 under explicit public config. [VERIFIED: missing file scan]
- [ ] `test/integration/schema_prefix_runtime_test.exs` - proves facade/worker/preload/bulk/health behavior for DB-05. [VERIFIED: missing file scan]
- [ ] Extend `test/cairnloop/migrations_test.exs` - cover unprefixed DDL helpers, example/test-host migrations, and `DROP EXTENSION vector`. [VERIFIED: test/cairnloop/migrations_test.exs]
- [ ] Extend `test/cairnloop/tasks/install_test.exs` - assert generated migration and notice do not imply CLI `--prefix` alone is sufficient. [VERIFIED: test/cairnloop/tasks/install_test.exs]
- [ ] Example app prefix/setup test - assert example config/migrations use `schema_prefix: "cairnloop"` and support tables land there. [VERIFIED: examples/cairnloop_example/config/config.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase does not change auth flows; keep existing Phase 58 auth tests intact. [ASSUMED] |
| V3 Session Management | no | Phase does not change session/cookie behavior. [ASSUMED] |
| V4 Access Control | limited | Prevent Cairnloop config from redirecting host/Oban tables; use explicit object boundaries and tests. [VERIFIED: 59-CONTEXT.md] |
| V5 Input Validation | yes | Validate schema/table identifiers through `Cairnloop.SchemaPrefix.quote_identifier!/1` and reject multi-token SQL input. [VERIFIED: lib/cairnloop/schema_prefix.ex] |
| V6 Cryptography | no | No new crypto; do not alter MCP token hashing behavior. [VERIFIED: lib/cairnloop/mcp.ex] |
| V8 Data Protection | yes | Dedicated schema prevents namespace collision and makes Cairnloop support-domain data inspectable/removable without moving arbitrary host data. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html; VERIFIED: 59-CONTEXT.md] |
| V14 Configuration | yes | Explicit default `"cairnloop"` and explicit public compatibility config are the main security-relevant controls. [VERIFIED: config/config.exs; VERIFIED: 59-CONTEXT.md] |

### Known Threat Patterns for Ecto/PostgreSQL Prefix Work

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SQL identifier injection through prefix config | Tampering / Elevation of Privilege | Single-identifier validation plus double-quote helper; never interpolate raw config. [VERIFIED: lib/cairnloop/schema_prefix.ex] |
| Search-path hijack or accidental table shadowing | Tampering | Explicit schema-qualified names for raw SQL and Ecto prefix APIs for queries/migrations. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| Silent public/dedicated data split | Information Disclosure / Integrity | Dedicated/public/collision DB tests and doctor prefix checks. [VERIFIED: 59-CONTEXT.md] |
| Dropping shared extension on rollback | Denial of Service | Do not issue `DROP EXTENSION vector`; source-scan and rollback-proof it. [CITED: https://www.postgresql.org/docs/current/sql-dropextension.html] |
| Oban table redirection | Denial of Service / Integrity | Keep Oban migrations/checks separate from `Cairnloop.SchemaPrefix`. [VERIFIED: 59-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `CLAUDE.md` - decision policy, warnings-clean test policy, DB-backed lane requirements, and sealed-contract posture. [VERIFIED: codebase]
- `AGENTS.md` - repo agent constraints. [VERIFIED: codebase]
- `.planning/phases/59-dedicated-postgres-schema-contract/59-CONTEXT.md` - locked Phase 59 decisions and canonical refs. [VERIFIED: codebase]
- `.planning/REQUIREMENTS.md` - DB-01 through DB-07. [VERIFIED: codebase]
- `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` - vM019 project decisions and phase scope. [VERIFIED: codebase]
- `docs/postgres-schema-prefix.md` - existing implementation contract and prior audit evidence. [VERIFIED: codebase]
- `lib/cairnloop/schema_prefix.ex`, `config/*.exs`, `priv/repo/migrations/*.exs`, `priv/test_host/migrations/*.exs`, `examples/cairnloop_example/**` - current implementation surfaces. [VERIFIED: codebase]
- Local probes: `mix deps`, `elixir --version`, `mix --version`, `pg_isready`, `psql` catalog queries, `docker --version`, `launchctl list`. [VERIFIED: tool output]

### Secondary (MEDIUM confidence)

- Ecto 3.13.6 `Ecto.Schema` docs - `@schema_prefix` behavior. https://hexdocs.pm/ecto/3.13.6/Ecto.Schema.html [CITED: hexdocs.pm]
- Ecto 3.13.6 `Ecto.Query` docs - query prefix precedence and fragments/direct SQL caveat. https://hexdocs.pm/ecto/3.13.6/Ecto.Query.html [CITED: hexdocs.pm]
- Ecto 3.13.6 `Ecto.Repo` docs - Repo prefix options for query and write operations. https://hexdocs.pm/ecto/3.13.6/Ecto.Repo.html [CITED: hexdocs.pm]
- Ecto SQL 3.13.5 `Ecto.Migration` docs - migration prefix, references, indexes, and migration default prefix. https://hexdocs.pm/ecto_sql/3.13.5/Ecto.Migration.html [CITED: hexdocs.pm]
- Ecto SQL 3.13.5 `mix ecto.migrate` docs - `--prefix` command option. https://hexdocs.pm/ecto_sql/3.13.5/Mix.Tasks.Ecto.Migrate.html [CITED: hexdocs.pm]
- PostgreSQL 18 schemas docs - schema namespace, public schema, search_path, privileges. https://www.postgresql.org/docs/current/ddl-schemas.html [CITED: postgresql.org]
- PostgreSQL 18 CREATE/DROP EXTENSION docs - extension member object tracking and drop behavior. https://www.postgresql.org/docs/current/sql-createextension.html and https://www.postgresql.org/docs/current/sql-dropextension.html [CITED: postgresql.org]

### Tertiary (LOW confidence)

- ASVS category applicability is mapped by phase judgment, not verified against a project-specific ASVS policy file. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - local `mix deps` and project files verify versions and existing dependency use. [VERIFIED: `mix deps`; VERIFIED: mix.exs]
- Architecture: HIGH - locked decisions and codebase files directly define the boundaries. [VERIFIED: 59-CONTEXT.md; VERIFIED: codebase]
- Pitfalls: MEDIUM - Ecto/Postgres claims are official docs fetched via WebSearch because Context7 was unavailable; local code hazards are HIGH. [CITED: official docs; VERIFIED: codebase]

**Research date:** 2026-06-30
**Valid until:** 2026-07-30 for codebase findings, 2026-07-07 for official-doc currency around Ecto/PostgreSQL behavior. [ASSUMED]
