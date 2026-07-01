# Upgrading Cairnloop

This file captures upgrade steps that can affect host applications. Read it before bumping
Cairnloop in production.

## Compatibility Matrix

These are source-backed compatibility claims for the current package. Treat them as modest
adoption guidance, not a broad support promise for untested host stacks.

| Surface | Current posture |
|---|---|
| Cairnloop package | Current source version is v0.5.1. Host apps should depend on `{:cairnloop, "~> 0.5.1"}` until a later release note says otherwise. |
| Elixir | `mix.exs` declares `elixir: "~> 1.19"`. The local Phase 60 docs checks run on Elixir 1.19. |
| OTP | Use an OTP release compatible with your Elixir/Phoenix stack; current local verification ran on OTP 28. |
| Phoenix | Cairnloop is an embedded Phoenix LiveView dashboard library, not a standalone service. The example app proves the current integration on Phoenix 1.8.x. |
| Ecto / Postgres | Cairnloop uses Ecto SQL and a host-owned Postgres repo. New installs default Cairnloop support tables to the `cairnloop` schema; existing public installs must choose explicit compatibility while migrating. |
| pgvector / vector | Retrieval uses pgvector and the Postgres `vector` extension. Treat the extension as shared database infrastructure owned by the host database. |
| Oban | Oban remains host-owned. Cairnloop's `:schema_prefix` setting does not move Oban tables or Oban migration history. |

## v0.5.1 and the `cairnloop` Postgres schema default

New installs default Cairnloop support-domain tables to the dedicated Postgres schema prefix
`cairnloop`:

```elixir
config :cairnloop, :schema_prefix, "cairnloop"
```

This keeps Cairnloop's tables out of the host app's default `public` namespace. Oban remains
host-owned and is not moved by this setting.

Existing installs that already have `public.cairnloop_*` tables should not silently switch to an
empty dedicated schema. Pin explicit public compatibility first:

```elixir
config :cairnloop, :schema_prefix, "public"
```

Legacy `nil` is also accepted for existing public-schema installs, but `"public"` is preferred
because it records the compatibility choice explicitly.

Then schedule a deliberate data migration to `cairnloop.*` when you are ready. The high-level
production sequence is:

1. Back up the database.
2. Deploy with `schema_prefix: "public"` and verify the app still reads existing public tables.
3. Schedule a maintenance window and stop writes to Cairnloop support-domain tables.
4. Record row counts for every `public.cairnloop_*` table you plan to move.
5. Create the `cairnloop` schema.
6. Move or copy Cairnloop support tables from `public` to `cairnloop`. Do not move Oban tables or
   unrelated host tables.
7. Verify row counts, indexes, constraints, and foreign keys. Also audit Cairnloop-owned functions
   and triggers; triggers follow tables, but trigger functions have their own schema placement.
8. Deploy with `schema_prefix: "cairnloop"`.
9. Run smoke checks against conversation creation, KB/retrieval reads, governed actions, outbound
   follow-up, MCP token lookup, and `mix cairnloop.doctor`.
10. Keep the public tables until rollback risk is gone, then drop them in a separate change.

No code in the package relocates existing public-schema tables for you. The host owns the
maintenance window, backup, data movement, and verification plan.

For the default dedicated-schema path, configure `schema_prefix: "cairnloop"` and run the generated
host migration before the Cairnloop dependency migrations:

```bash
mix ecto.migrate
mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations
```

Do not treat `mix ecto.migrate --prefix cairnloop` as the setup contract. Cairnloop qualifies raw
SQL and generated host migrations in source so runtime schemas, DDL, triggers, and backfills agree;
the migrator prefix flag alone cannot provide that and may move migrator bookkeeping into the wrong
schema.

## Shared Postgres extensions

Cairnloop uses pgvector for knowledge-base embeddings. Cairnloop migrations may create the
extension when needed, but they must not drop shared database extensions during rollback. Treat
`vector` as host-owned database infrastructure. The shared `vector` infrastructure is not dropped
by Cairnloop rollback.

## Rollback posture

This rollback posture is intentionally conservative.

Rollback posture depends on where the data lives:

- If the data still lives in `public`, pin `schema_prefix: "public"` and redeploy. That is the
  lowest-risk runtime rollback for existing installs.
- If you moved tables into `cairnloop`, rollback needs a second maintenance window and a planned
  reverse table/function/trigger move. Do not improvise this during an incident.
- Oban remains host-owned and should not move as part of either direction.
- Rollback must not drop shared database extensions, including `vector`.

## Local verification

Before releasing an upgrade PR, run:

```bash
mix ci
```

For DB-prefix work, also run:

```bash
mix ci.integration
```

and run the same host-app checks twice, in separate configs:

```elixir
config :cairnloop, :schema_prefix, "cairnloop"
```

```elixir
config :cairnloop, :schema_prefix, "public"
```
