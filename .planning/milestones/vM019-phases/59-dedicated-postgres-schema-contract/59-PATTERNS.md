# Phase 59: Dedicated Postgres Schema Contract - Pattern Map

**Mapped:** 2026-06-30
**Files analyzed:** 18 module families
**Analogs found:** 18 / 18

## File Classification

| New/Modified File Or Family | Role | Data Flow | Closest Analog | Match Quality |
|-----------------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/schema_prefix.ex` | utility | transform | `lib/cairnloop/schema_prefix.ex` | exact |
| `test/cairnloop/schema_prefix_test.exs` | test | transform + source scan | `test/cairnloop/schema_prefix_test.exs` | exact |
| `config/config.exs`, `config/test.exs` | config | transform | same files | exact |
| `lib/cairnloop/**/*` schema modules with `schema "cairnloop_*"` | model | CRUD | `lib/cairnloop/conversation.ex` | exact |
| `priv/repo/migrations/*.exs` | migration | file-I/O + DDL | `lib/mix/tasks/cairnloop/install.ex`, `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` | role-match |
| `priv/test_host/migrations/*.exs` | migration | file-I/O + DDL | `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs`, `priv/test_host/migrations/20260101000001_add_oban_jobs.exs` | exact |
| `examples/cairnloop_example/config/config.exs`, example migrations | config + migration | file-I/O + DDL | `examples/cairnloop_example/config/config.exs`, `examples/.../20260525201622_create_cairnloop_tables.exs` | exact |
| `mix.exs`, `examples/cairnloop_example/mix.exs` aliases | config | batch | same files | exact |
| `lib/mix/tasks/cairnloop/install.ex` | utility/task | file-I/O + generated migration | same file | exact |
| `test/cairnloop/tasks/install_test.exs` | test | source scan | same file | exact |
| `test/cairnloop/migrations_test.exs` | test | source scan | same file | exact |
| `lib/cairnloop/chat.ex`, `knowledge_base.ex`, `mcp.ex` | service/facade | CRUD + request-response | same files | exact |
| `lib/cairnloop/retrieval.ex`, `retrieval/providers/*.ex` | service/facade | raw SQL + transform | same files | exact |
| `lib/cairnloop/**/*workers/*.ex` bulk/indexing workers | worker | event-driven + batch | `ChunkRevision`, `IndexResolvedConversation` | exact |
| `lib/cairnloop/governance.ex`, `lib/cairnloop/outbound.ex` | service/facade | CRUD + event-driven | same files | exact |
| `lib/cairnloop/doctor.ex`, `lib/mix/tasks/cairnloop.doctor.ex` | utility/task | health check + request-response | same files | exact |
| `test/integration/schema_prefix_contract_test.exs`, `public_schema_compatibility_test.exs`, `schema_prefix_runtime_test.exs` | test | DB-backed CRUD + catalog proof | `test/support/data_case.ex`, `test/integration/outbound_bulk_envelopes_migration_test.exs`, `partial_unique_index_test.exs` | role-match |
| example app setup tests | test | DB-backed setup proof | `examples/cairnloop_example/test/support/data_case.ex`, `examples/.../seeds_test.exs` | role-match |

## Pattern Assignments

### `lib/cairnloop/schema_prefix.ex` (utility, transform)

**Analog:** `lib/cairnloop/schema_prefix.ex`

**Imports pattern:** none. Keep this helper dependency-light and usable from migrations.

**Config normalization and repo opts pattern** (lines 17-29):
```elixir
def configured(opts \\ []) do
  opts
  |> Keyword.get(:schema_prefix, Application.get_env(:cairnloop, :schema_prefix, @default))
  |> normalize!()
end

def repo_opts(opts \\ []) do
  case configured(opts) do
    nil -> opts
    prefix -> Keyword.put_new(opts, :prefix, prefix)
  end
end
```

**Raw SQL identifier pattern** (lines 32-49):
```elixir
def quoted_table(table, opts \\ []) when is_binary(table) do
  table = quote_identifier!(table)

  case configured(opts) do
    nil -> table
    prefix -> quote_identifier!(prefix) <> "." <> table
  end
end

def quote_identifier!(identifier) when is_binary(identifier) do
  if Regex.match?(@identifier, identifier) do
    ~s("#{identifier}")
  else
    raise ArgumentError,
          "invalid Cairnloop schema/table identifier #{inspect(identifier)}; " <>
            "expected a single SQL identifier"
  end
end
```

**Validation pattern** (lines 52-70):
```elixir
def normalize!(nil), do: nil
def normalize!(""), do: nil

def normalize!(prefix) when is_binary(prefix) do
  if Regex.match?(@identifier, prefix) do
    prefix
  else
    raise ArgumentError,
          "invalid :cairnloop, :schema_prefix #{inspect(prefix)}; " <>
            "expected nil or a single SQL identifier"
  end
end
```

Planner note: extend this module rather than adding facade-local prefix helpers. Add `"public"` compatibility semantics here if the implementation chooses to treat `"public"` as explicit public mode.

---

### `test/cairnloop/schema_prefix_test.exs` (test, transform + source scan)

**Analog:** `test/cairnloop/schema_prefix_test.exs`

**Env restore pattern** (lines 6-13, 60-62):
```elixir
setup do
  original = Application.get_env(:cairnloop, :schema_prefix)

  on_exit(fn ->
    restore_env(:schema_prefix, original)
  end)

  :ok
end

defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
```

**Default/public helper assertions** (lines 16-32):
```elixir
test "new installs default to the cairnloop schema prefix" do
  Application.delete_env(:cairnloop, :schema_prefix)

  assert Cairnloop.SchemaPrefix.default() == "cairnloop"
  assert Cairnloop.SchemaPrefix.configured() == "cairnloop"
  assert Cairnloop.SchemaPrefix.repo_opts() == [prefix: "cairnloop"]

  assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks") ==
           ~s("cairnloop"."cairnloop_chunks")
end

test "public compatibility can be explicit" do
  Application.put_env(:cairnloop, :schema_prefix, nil)

  assert Cairnloop.SchemaPrefix.configured() == nil
  assert Cairnloop.SchemaPrefix.repo_opts(timeout: 1_000) == [timeout: 1_000]
  assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks") == ~s("cairnloop_chunks")
end
```

**Schema source-scan pattern** (lines 43-57):
```elixir
test "every Cairnloop Ecto schema declares the configured schema prefix" do
  schema_files =
    @schema_files
    |> Enum.filter(fn path -> File.read!(path) =~ ~s(schema "cairnloop_) end)

  assert schema_files != []

  for path <- schema_files do
    source = File.read!(path)

    expected =
      ~s|@schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")|

    assert source =~ expected, "expected #{path} to declare Cairnloop schema prefix"
  end
end
```

Planner note: copy the setup/restore style for tests that mutate `:schema_prefix`, `:repo`, or prefix-related config.

---

### Config Defaults (config, transform)

**Analogs:** `config/config.exs`, `config/test.exs`, `examples/cairnloop_example/config/config.exs`

**Library default pattern** (`config/config.exs` lines 5-7):
```elixir
# New installs keep Cairnloop's support-domain tables out of the host app's public schema.
# Existing public-schema installs can explicitly set this to nil while following UPGRADING.md.
config :cairnloop, :schema_prefix, "cairnloop"
```

**Current test compatibility pattern to replace/prove** (`config/test.exs` lines 35-37):
```elixir
# Current integration-test migrations still create public tables. Keep public compatibility explicit
# until the Phase 59 migration conversion moves the test host to the dedicated schema default.
config :cairnloop, :schema_prefix, nil
```

**Example app config insertion point** (`examples/cairnloop_example/config/config.exs` lines 63-75):
```elixir
config :cairnloop,
  repo: CairnloopExample.Repo,
  tools: [
    Cairnloop.Tools.InternalNote,
    CairnloopExample.Tools.HighRiskDemoAction
  ],
  context_provider: CairnloopExample.DemoContextProvider,
  auditor: Cairnloop.Auditor.Governance
```

Planner note: add `schema_prefix: "cairnloop"` to the example Cairnloop config near the repo config, and make test config dedicated by default after migration conversion. Keep public compatibility explicit in separate test setup.

---

### Ecto Schema Modules (model, CRUD)

**Analog:** `lib/cairnloop/conversation.ex`

**Schema prefix declaration** (lines 1-7):
```elixir
defmodule Cairnloop.Conversation do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  schema "cairnloop_conversations" do
```

**Association pattern** (lines 16-18):
```elixir
has_many(:messages, Cairnloop.Message)
has_many(:drafts, Cairnloop.Automation.Draft)
has_many(:tool_proposals, Cairnloop.Governance.ToolProposal)
```

Files following this pattern today: 20 schema modules under `lib/cairnloop` matched the compile-time attribute. Do not remove this as part of Phase 59. Public compatibility needs DB proof under the real compile/config mode because query prefix opts do not override `@schema_prefix` in every query shape.

---

### Library Migrations (migration, file-I/O + DDL)

**Analogs:** `lib/mix/tasks/cairnloop/install.ex`, `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs`, `priv/repo/migrations/20260516000000_create_knowledge_base.exs`

**Prefix-aware migration body to copy** (`lib/mix/tasks/cairnloop/install.ex` lines 48-79):
```elixir
def change do
  prefix = Cairnloop.SchemaPrefix.configured()

  if prefix do
    execute(
      "CREATE SCHEMA IF NOT EXISTS #{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
      "SELECT 1"
    )
  end

  create table(:cairnloop_conversations, prefix: prefix) do
    add :status, :string, null: false
    add :subject, :string
    add :host_user_id, :string
    add :customer_ref, :string
    add :resolved_at, :utc_datetime_usec
    add :csat_rating, :string

    timestamps()
  end

  create table(:cairnloop_messages, prefix: prefix) do
    add :content, :text, null: false
    add :role, :string, null: false
    add :metadata, :map
    add :conversation_id, references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all), null: false

    timestamps()
  end

  create index(:cairnloop_messages, [:conversation_id], prefix: prefix)
end
```

**Raw SQL already using helper** (`priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` lines 4-15, 21-45):
```elixir
def up do
  chunks_table = Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks")

  chunks_search_vector_function =
    Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks_search_vector_update")

  resolved_chunks_table = Cairnloop.SchemaPrefix.quoted_table("cairnloop_resolved_case_chunks")

  resolved_chunks_search_vector_function =
    Cairnloop.SchemaPrefix.quoted_table("cairnloop_resolved_case_chunks_search_vector_update")

  alter table(:cairnloop_chunks) do
    add(:chunk_index, :integer, null: false, default: 0)
    add(:heading, :text)
    add(:search_vector, :tsvector)
  end

  execute("""
  UPDATE #{chunks_table}
  SET search_vector =
    to_tsvector('english', coalesce(heading, '') || ' ' || coalesce(content, ''))
  """)

  execute("""
  CREATE FUNCTION #{chunks_search_vector_function}()
  RETURNS trigger AS $$
```

**Current DDL gaps to convert** (`priv/repo/migrations/20260516000000_create_knowledge_base.exs` lines 4-31):
```elixir
def up do
  execute("CREATE EXTENSION IF NOT EXISTS vector")

  create table(:cairnloop_articles) do
    add(:title, :string, null: false)
    add(:status, :string, null: false, default: "draft")
    timestamps()
  end

  create table(:cairnloop_revisions) do
    add(:article_id, references(:cairnloop_articles, on_delete: :delete_all), null: false)
    add(:content, :text, null: false)
    add(:version, :integer, null: false, default: 1)
    add(:state, :string, null: false, default: "draft")
    timestamps()
  end

  create(index(:cairnloop_revisions, [:article_id]))
  create(index(:cairnloop_revisions, [:state]))

  create table(:cairnloop_chunks) do
    add(:revision_id, references(:cairnloop_revisions, on_delete: :delete_all), null: false)
    add(:content, :text, null: false)
    add(:embedding, :vector, size: 1536)
    timestamps()
  end

  create(index(:cairnloop_chunks, [:revision_id]))
end
```

**Rollback pattern: do not drop vector** (`priv/repo/migrations/20260516000000_create_knowledge_base.exs` lines 34-38):
```elixir
def down do
  drop(table(:cairnloop_chunks))
  drop(table(:cairnloop_revisions))
  drop(table(:cairnloop_articles))
end
```

Planner note: every `table/2`, `alter table/2`, `drop(table(...))`, `index/3`, `unique_index/3`, and `references/2` in `priv/repo/migrations/*.exs` should carry `prefix: prefix` for Cairnloop support-domain objects. Raw SQL should keep using `SchemaPrefix.quoted_table/1` or a new helper from that module. Oban objects are excluded.

---

### Test-Host And Example Migrations (migration, file-I/O + DDL)

**Analogs:** `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs`, `priv/test_host/migrations/20260101000001_add_oban_jobs.exs`, `examples/.../20260525201622_create_cairnloop_tables.exs`

**Host-owned support table shape to prefix** (`priv/test_host/migrations/20260101000000_create_host_owned_tables.exs` lines 11-32):
```elixir
def change do
  create table(:cairnloop_conversations) do
    add(:status, :string, null: false, default: "open")
    add(:subject, :string)
    add(:host_user_id, :string)
    add(:customer_ref, :string)
    add(:resolved_at, :utc_datetime_usec)
    add(:csat_rating, :string)

    timestamps()
  end

  create table(:cairnloop_messages) do
    add(:content, :text)
    add(:role, :string, null: false, default: "user")
    add(:metadata, :map, default: %{})
    add(:conversation_id, references(:cairnloop_conversations, on_delete: :delete_all))

    timestamps()
  end

  create(index(:cairnloop_messages, [:conversation_id]))
```

**Oban remains host-owned** (`priv/test_host/migrations/20260101000001_add_oban_jobs.exs` lines 1-24):
```elixir
defmodule Cairnloop.TestHost.Migrations.AddObanJobs do
  @moduledoc """
  Creates the `oban_jobs` table (and Oban's supporting types) for the integration
  test host so DB-backed integration tests can exercise code paths that insert
  Oban jobs (e.g. `Cairnloop.Outbound.bulk_trigger/2`'s per-recipient
  `Multi.insert(OutboundWorker.new(...))` step).

  ## Why this lives in the TEST host, not the library

  Cairnloop ships no Oban migration (the host owns `oban_jobs` -- see
  `test/integration/approval_flow_test.exs:9`).
  """
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end
```

**Example current public-style shape to convert** (`examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs` lines 4-28):
```elixir
def change do
  create table(:cairnloop_conversations) do
    add :status, :string, null: false
    add :subject, :string
    add :host_user_id, :string
    add :customer_ref, :string
    add :resolved_at, :utc_datetime_usec
    add :csat_rating, :string

    timestamps()
  end

  create table(:cairnloop_messages) do
    add :content, :text, null: false
    add :role, :string, null: false
    add :metadata, :map

    add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all),
      null: false

    timestamps()
  end

  create index(:cairnloop_messages, [:conversation_id])
end
```

**Example vector rollback anti-pattern** (`examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs` lines 4-10):
```elixir
def up do
  execute("CREATE EXTENSION IF NOT EXISTS vector;")
end

def down do
  execute("DROP EXTENSION IF EXISTS vector;")
end
```

Planner note: example and test-host support tables should copy the installer migration prefix pattern. Keep `AddObanJobs` and example Oban migration host-owned; do not add Cairnloop schema prefix to Oban.

---

### Mix Aliases (config, batch)

**Analogs:** `mix.exs`, `examples/cairnloop_example/mix.exs`

**Integration host migration order** (`mix.exs` lines 108-124):
```elixir
# DB bootstrap for the integration suite (Cairnloop.Repo + Chimeway.Repo boot DB).
# Host-owned tables (conversations/messages/drafts) are created FIRST via the
# test-host migration path -- the library's own migrations reference but do not
# create them (the host owns them). Then the library migrations run.
"test.setup": [
  "ecto.create --quiet -r Cairnloop.Repo -r Chimeway.Repo",
  "ecto.migrate --quiet --migrations-path priv/test_host/migrations --migrations-path priv/repo/migrations"
],
"test.integration": ["test.setup", "test --include integration test/integration"],
```

**CI lanes** (`mix.exs` lines 127-133):
```elixir
"ci.fast": [
  "deps.get --check-locked",
  "format --check-formatted",
  "compile --warnings-as-errors",
  "test --exclude integration --warnings-as-errors"
],
"ci.integration": ["test.integration"],
```

**Example app ordered migration phases** (`examples/cairnloop_example/mix.exs` lines 98-113):
```elixir
# Migrations run as TWO ordered phases: the example's own host tables first (conversations,
# messages, drafts), then Cairnloop's library tables -- several of which reference the
# host-owned conversations table, so they must come after it.
reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end

[
  setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
  "ecto.setup": [
    "ecto.create",
    "ecto.migrate",
    reenable_migrate,
    "ecto.migrate --migrations-path #{cairnloop_migrations}",
    "run priv/repo/seeds.exs"
  ],
```

Planner note: preserve host-first then dependency migration order. Do not make `--prefix cairnloop` the correctness mechanism; make source migrations qualified.

---

### Installer And Installer Tests (task + tests, file-I/O/source scan)

**Analogs:** `lib/mix/tasks/cairnloop/install.ex`, `test/cairnloop/tasks/install_test.exs`

**Generated migration source** (`lib/mix/tasks/cairnloop/install.ex` lines 34-83): use the migration excerpt above.

**Notice config/copy pattern** (`lib/mix/tasks/cairnloop/install.ex` lines 111-140):
```elixir
2. Configure Cairnloop to use your Ecto repo:

     config :cairnloop, :repo, MyApp.Repo

   New installs default Cairnloop support tables to the `cairnloop` Postgres schema:

     config :cairnloop, :schema_prefix, "cairnloop"

   Existing public-schema installs can explicitly keep public compatibility while migrating:

     config :cairnloop, :schema_prefix, nil

4. Run the host migration generated in your app, then the Cairnloop dependency migrations:

     mix ecto.migrate
     mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop

   If you are intentionally staying in public-schema compatibility mode, omit `--prefix cairnloop`.
```

**Installer test source-scan pattern** (`test/cairnloop/tasks/install_test.exs` lines 17-40):
```elixir
test "installer notice includes required repo config and dependency migrations" do
  source = File.read!(@source_path)

  assert source =~ "config :cairnloop, :repo, MyApp.Repo"
  assert source =~ ~s(config :cairnloop, :schema_prefix, "cairnloop")
  assert source =~ "config :cairnloop, :schema_prefix, nil"

  assert source =~
           "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop"

  assert source =~ "omit `--prefix cairnloop`"
  assert source =~ "mix cairnloop.doctor"
end

test "installer-generated migration is schema-prefix aware" do
  source = File.read!(@source_path)

  assert source =~ "prefix = Cairnloop.SchemaPrefix.configured()"
  assert source =~ "CREATE SCHEMA IF NOT EXISTS"
  assert source =~ "create table(:cairnloop_conversations, prefix: prefix)"
```

Planner note: update copy/tests so `--prefix` is not described as sufficient. Tests should assert source-qualified migrations plus explicit public compatibility wording.

---

### Migration Source Scans (test, source scan)

**Analog:** `test/cairnloop/migrations_test.exs`

**Extension rollback scan** (lines 4-13):
```elixir
test "library migrations do not drop shared pgvector extension" do
  migration_sources =
    migration_sources()

  assert migration_sources != []

  for {path, source} <- migration_sources do
    refute source =~ ~r/DROP\s+EXTENSION\s+(?:IF\s+EXISTS\s+)?vector/i,
           "expected #{path} not to drop the shared vector extension"
  end
end
```

**Raw SQL drift scan** (lines 16-33):
```elixir
test "raw SQL in library migrations does not hardcode public-style Cairnloop table names" do
  for {path, source} <- migration_sources() do
    refute source =~ ~r/\bUPDATE\s+cairnloop_/i,
           "expected #{path} raw UPDATE statements to use Cairnloop.SchemaPrefix.quoted_table/1"

    refute source =~ ~r/\bON\s+cairnloop_/i,
           "expected #{path} raw trigger/table references to use Cairnloop.SchemaPrefix.quoted_table/1"

    refute source =~ ~r/\bFUNCTION\s+cairnloop_/i,
           "expected #{path} raw function references to use Cairnloop.SchemaPrefix.quoted_table/1"
  end
end

defp migration_sources do
  "priv/repo/migrations/*.exs"
  |> Path.wildcard()
  |> Enum.map(&{&1, File.read!(&1)})
end
```

Planner note: broaden `migration_sources/0` or add helpers to include `priv/test_host/migrations/*.exs` and `examples/cairnloop_example/priv/repo/migrations/*.exs`. Add scans for unprefixed `table(:cairnloop_`, `alter table(:cairnloop_`, `index(:cairnloop_`, `unique_index(:cairnloop_`, `references(:cairnloop_`, and `drop(table(:cairnloop_`.

---

### Runtime Facades: Chat, KnowledgeBase, MCP (service, CRUD + request-response)

**Analogs:** `lib/cairnloop/chat.ex`, `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/mcp.ex`

**Repo indirection pattern** (`lib/cairnloop/chat.ex` lines 6-13):
```elixir
defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end

def list_conversations do
  Conversation
  |> order_by(desc: :updated_at)
  |> repo().all()
end
```

**Preload pattern** (`lib/cairnloop/chat.ex` lines 53-59):
```elixir
def get_conversation!(id) do
  Conversation
  |> repo().get!(id)
  |> repo().preload(
    messages: from(m in Message, order_by: [asc: m.inserted_at]),
    drafts: from(d in Cairnloop.Automation.Draft, order_by: [asc: d.inserted_at])
  )
end
```

**Ecto.Multi pattern** (`lib/cairnloop/chat.ex` lines 133-145, 238):
```elixir
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(
    :message,
    Message.changeset(%Message{}, %{
      conversation_id: conversation.id,
      content: content,
      role: role
    })
  )
  |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :open}))
  |> auditor.audit(:reply_to_conversation, actor, %{conversation_id: conversation.id})

result = repo().transaction(multi)
```

**KnowledgeBase query and fragment pattern** (`lib/cairnloop/knowledge_base.ex` lines 93-114):
```elixir
def publish_revision(revision) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
  |> Ecto.Multi.update(:article, fn %{revision: rev} ->
    Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
  end)
  |> Ecto.Multi.insert(
    :chunk_job,
    Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id})
  )
  |> repo().transaction()
end

def search_chunks(embedding_vector, limit \\ 5) do
  Cairnloop.KnowledgeBase.Chunk
  |> order_by([c], fragment("? <-> ?", c.embedding, ^Pgvector.new(embedding_vector)))
  |> limit(^limit)
  |> repo().all()
end
```

**MCP token query/write pattern** (`lib/cairnloop/mcp.ex` lines 22-45):
```elixir
%Token{}
|> Token.changeset(attrs)
|> repo().insert()

query =
  from(t in Token,
    where: t.token_hash == ^token_hash,
    where: is_nil(t.revoked_at),
    where: is_nil(t.expires_at) or t.expires_at > ^DateTime.utc_now()
  )

case repo().one(query) do
  nil -> {:error, :unauthorized}
  token -> {:ok, token}
end
```

Planner note: preserve the `repo()` indirection. Add `Cairnloop.SchemaPrefix.repo_opts()` to Repo calls or query sources only where DB proof shows schema attributes are insufficient, especially for public compatibility.

---

### Retrieval Health, Raw SQL, Fragments, And Oban Boundary (service, raw SQL + transform)

**Analogs:** `lib/cairnloop/retrieval.ex`, `lib/cairnloop/retrieval/providers/knowledge_base.ex`, `lib/cairnloop/retrieval/providers/resolved_cases.ex`

**Raw SQL health check and Oban boundary** (`lib/cairnloop/retrieval.ex` lines 12-42):
```elixir
def system_health do
  try do
    # 1. Check pgvector extension
    ext_query = "SELECT 1 FROM pg_extension WHERE extname = 'vector'"
    {:ok, ext_res} = Ecto.Adapters.SQL.query(repo(), ext_query, [])
    ext_ok? = ext_res.num_rows > 0

    # 2. Check vector index health (can we query the chunk tables?)
    idx_query =
      "SELECT id FROM #{Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks")} LIMIT 1"

    {:ok, _} = Ecto.Adapters.SQL.query(repo(), idx_query, [])
    index_ok? = true

    # 3. Check Oban queue for failed indexing attempts
    oban_query =
      "SELECT 1 FROM oban_jobs WHERE state IN ('retryable', 'discarded') AND worker LIKE '%Retrieval%' LIMIT 1"

    {:ok, oban_res} = Ecto.Adapters.SQL.query(repo(), oban_query, [])
```

**Oban query remains host-owned** (`lib/cairnloop/retrieval.ex` lines 191-210):
```elixir
failed_jobs_query =
  from(job in Oban.Job,
    where: job.state in ["retryable", "discarded"],
    where: job.queue == ^queue
  )

failed_jobs_query =
  if worker do
    where(failed_jobs_query, [job], job.worker == ^worker)
  else
    failed_jobs_query
  end

failed_jobs_query
|> repo().all()
```

**Full-text fragment pattern** (`lib/cairnloop/retrieval/providers/knowledge_base.ex` lines 23-31):
```elixir
Chunk
|> join(:inner, [chunk], revision in Revision, on: revision.id == chunk.revision_id)
|> join(:inner, [_chunk, revision], article in Article, on: article.id == revision.article_id)
|> where([_chunk, revision], revision.state == :published)
|> where(
  [chunk, _revision, _article],
  fragment("? @@ websearch_to_tsquery('english', ?)", field(chunk, :search_vector), ^query)
)
```

**Vector fragment pattern** (`lib/cairnloop/retrieval/providers/resolved_cases.ex` lines 87-98):
```elixir
ResolvedCaseChunk
|> join(:inner, [chunk], evidence in ResolvedCaseEvidence,
  on: evidence.id == chunk.resolved_case_evidence_id
)
|> maybe_filter_host_user(host_user_id)
|> order_by(
  [chunk, _evidence],
  fragment("? <-> ?", chunk.embedding, ^Pgvector.new(embedding_vector))
)
```

Planner note: raw table/function names must use `SchemaPrefix`. Fragments that reference schema fields can stay query-based if DB tests prove prefix correctness. Do not apply Cairnloop prefix to `oban_jobs` or `Oban.Job`.

---

### Bulk Workers And `insert_all` (worker, event-driven + batch)

**Analogs:** `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`, `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`, their tests

**Chunk refresh bulk pattern** (`lib/cairnloop/knowledge_base/workers/chunk_revision.ex` lines 45-51):
```elixir
Ecto.Multi.new()
|> Ecto.Multi.delete_all(
  :delete_old_chunks,
  from(c in Chunk, where: c.revision_id == ^revision_id)
)
|> Ecto.Multi.insert_all(:insert_chunks, Chunk, chunk_records)
|> repo().transaction()
```

**Resolved-case preload + nested transaction/bulk pattern** (`lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` lines 18-24, 39-70):
```elixir
case repo().get(Conversation, conversation_id) do
  nil ->
    {:error, :conversation_not_found}

  conversation ->
    conversation = repo().preload(conversation, :messages)
```

```elixir
repo().transaction(fn ->
  evidence =
    repo().one(from(e in ResolvedCaseEvidence, where: e.conversation_id == ^conversation.id))

  evidence_changeset =
    (evidence || %ResolvedCaseEvidence{})
    |> ResolvedCaseEvidence.changeset(evidence_attrs)

  with {:ok, evidence_record} <- repo().insert_or_update(evidence_changeset) do
    chunk_records =
      Enum.zip(chunk_sections, embeddings)
      |> Enum.map(fn {section, embedding} ->
        %{
          resolved_case_evidence_id: evidence_record.id,
          chunk_index: section.chunk_index,
          content: section.content,
          embedding: Pgvector.new(embedding),
          inserted_at: now,
          updated_at: now
        }
      end)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :delete_old_chunks,
      from(c in ResolvedCaseChunk, where: c.resolved_case_evidence_id == ^evidence_record.id)
    )
    |> Ecto.Multi.insert_all(:insert_chunks, ResolvedCaseChunk, chunk_records)
    |> repo().transaction()
```

**Unit test pattern for Multi operations** (`test/cairnloop/knowledge_base/workers/chunk_revision_test.exs` lines 16-31):
```elixir
def transaction(multi) do
  operations = Ecto.Multi.to_list(multi)

  results =
    Enum.reduce(operations, %{}, fn
      {name, {:delete_all, _query, _opts}}, acc ->
        Map.put(acc, name, {1, nil})

      {name, {:insert_all, _schema, records, _opts}}, acc ->
        send(self(), {:inserted_chunk_records, records})
        Map.put(acc, name, {length(records), nil})
```

Planner note: add/verify prefix opts for `Ecto.Multi.delete_all/4` and `Ecto.Multi.insert_all/5` paths. Existing tests already inspect `_opts`; extend them to assert `prefix` where required.

---

### Governance And Outbound Facades (service, CRUD + event-driven)

**Analogs:** `lib/cairnloop/governance.ex`, `lib/cairnloop/outbound.ex`, `test/cairnloop/governance_test.exs`

**Governance sequential co-commit pattern** (`lib/cairnloop/governance.ex` lines 377-391):
```elixir
with {:ok, proposal} <-
       %ToolProposal{}
       |> ToolProposal.changeset(proposal_attrs)
       |> repo().insert(),
     {:ok, _event} <-
       %ToolActionEvent{}
       |> ToolActionEvent.changeset(%{
         tool_proposal_id: proposal.id,
         event_type: :proposal_created,
         from_status: nil,
         to_status: :proposed,
         actor_id: actor_id,
         metadata: %{}
       })
       |> repo().insert() do
```

**Governance approval post-commit enqueue pattern** (`lib/cairnloop/governance.ex` lines 674-690):
```elixir
# Sequential `with` co-commit (never the multi alternative -- Pitfall 1).
with {:ok, approval} <- repo().insert(insert_cs),
     {:ok, _updated} <-
       update_approval_with_event(
         approval,
         Ecto.Changeset.change(approval, %{}),
         event_attrs
       ) do
  # Pattern 4: schedule expiry worker AFTER transaction commits, NOT inside the with.
  enqueue_fn.(
    ApprovalExpiryWorker.new(%{"approval_id" => approval.id}, scheduled_at: expires_at)
  )
```

**No-Multi invariant test** (`test/cairnloop/governance_test.exs` lines 1443-1448):
```elixir
test "source: no Ecto.Multi used (sequential with, Pitfall 1)" do
  source = File.read!("lib/cairnloop/governance.ex")

  refute source =~ "Ecto.Multi",
         "governance.ex must not use Ecto.Multi -- only sequential with co-commits (Pitfall 1)"
end
```

**Outbound shared Multi builder** (`lib/cairnloop/outbound.ex` lines 178-208):
```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(
  message_key,
  Message.changeset(%Message{}, %{
    conversation_id: conversation_id,
    content: content,
    role: :system_outbound,
    metadata: %{
      "template_id" => template_id,
      "status" => "pending",
      "bulk_envelope_id" => bulk_envelope_id
    }
  })
)
|> Ecto.Multi.merge(fn changes ->
  message = Map.fetch!(changes, message_key)
  job_opts = if schedule_in, do: [schedule_in: schedule_in], else: []

  job_args = %{
    "message_id" => message.id,
    "conversation_id" => conversation_id,
    "template_id" => template_id,
    "bulk_envelope_id" => bulk_envelope_id
  }

  Ecto.Multi.insert(
    Ecto.Multi.new(),
    job_key,
    Cairnloop.Workers.OutboundWorker.new(job_args, job_opts)
  )
end)
```

**Outbound bulk transaction pattern** (`lib/cairnloop/outbound.ex` lines 407-426):
```elixir
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:envelope, BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs))
  |> Ecto.Multi.merge(fn %{envelope: env} ->
    Enum.reduce(conversation_ids, Ecto.Multi.new(), fn cid, acc ->
      recipient_opts =
        per_recipient_opts
        |> Keyword.put(:bulk_envelope_id, env.id)
        |> Keyword.put(:multi_key_prefix, cid)

      Ecto.Multi.append(acc, build_trigger_multi(cid, recipient_opts))
    end)
  end)
  |> auditor.audit(:bulk_outbound_trigger, actor, %{
    bulk_envelope_id: envelope_id,
    count: count,
    template_id: template_id
  })

result = repo().transaction(multi)
```

Planner note: do not "standardize" Governance onto `Ecto.Multi`; there is an explicit source guard against it. Prefix work should preserve each facade's established transaction style.

---

### Doctor And Health Checks (utility/task, health check)

**Analogs:** `lib/cairnloop/doctor.ex`, `lib/mix/tasks/cairnloop.doctor.ex`, `test/cairnloop/doctor_test.exs`

**Doctor check aggregation** (`lib/cairnloop/doctor.ex` lines 40-68):
```elixir
def checks(router, opts \\ []) do
  routes = safe_routes(router)
  handlers = route_handlers(routes)
  dashboard_mounted? = Enum.any?(@dashboard_live_views, &(&1 in handlers))
  metrics_mounted? = Cairnloop.Web.MetricsPlug in handlers

  repo = config(opts, :repo)

  [
    check_repo(repo),
    check_router(router),
    check_dashboard(router, dashboard_mounted?),
    check_audit_log(router, dashboard_mounted?, Cairnloop.Web.AuditLogLive in handlers),
    check_operations(router, Cairnloop.Web.HealthPlug in handlers, metrics_mounted?),
    check_metrics_dep(metrics_mounted?),
    check_auditor(config(opts, :auditor), dashboard_mounted?),
    check_tools(config(opts, :tools, [])),
    check_widget_verifier(config(opts, :widget_token_verifier)),
    check_email_webhook_auth(
      config(opts, :email_webhook_verifier),
      config(opts, :email_webhook_token)
    ),
    check_mcp_auth(repo),
    check_optional(config(opts, :context_provider), "context provider", :context_provider),
    check_notifier(config(opts, :notifier)),
    check_oban(),
    check_retrieval(),
    check_scrypath(opts)
  ]
  |> List.flatten()
end
```

**Current honest-not-queried posture** (`lib/cairnloop/doctor.ex` lines 278-295):
```elixir
defp check_oban do
  if Code.ensure_loaded?(Oban) do
    {:ok,
     "Ready: Oban is available. Not checked here: doctor did not inspect a running Oban supervisor or queue state."}
  else
    {:warn,
     "Blocked: Oban is not available to Cairnloop. Add and start Oban in the host app before relying on background jobs."}
  end
end

defp check_retrieval do
  if Code.ensure_loaded?(Pgvector) do
    {:ok,
     "Ready: pgvector library is available. Not checked here: doctor did not query the database, Oban queues, or pgvector indexes."}
  else
```

**Task output pattern** (`lib/mix/tasks/cairnloop.doctor.ex` lines 37-63):
```elixir
def run(args) do
  {opts, rest, _} = OptionParser.parse(args, strict: [strict: :boolean])
  strict? = Keyword.get(opts, :strict, false)

  # Load config (populates Application env) without starting the supervision tree.
  Mix.Task.run("app.config")

  router = resolve_router(rest)
  findings = Doctor.checks(router)

  Mix.shell().info("\nCairnloop doctor\n")
  Enum.each(findings, &print_finding/1)

  counts = Doctor.tally(findings)
  Mix.shell().info("\n" <> summary(counts))
```

**Doctor tests** (`test/cairnloop/doctor_test.exs` lines 114-130):
```elixir
describe "Phase 58 trust diagnostics" do
  test "reports ready widget, email, MCP, notifier, Oban, retrieval, and Scrypath posture" do
    findings = Doctor.checks(FullRouter, ready_opts())
    msg = text(findings)

    assert msg =~ "Ready: Widget ingress has a host verifier configured"
    assert msg =~ "Ready: Email webhook request authentication is configured"
    assert msg =~ "Ready: MCP token-required methods enforce Bearer authentication"
    assert msg =~ "Ready: Notifier callbacks are configured"
    assert msg =~ "Ready: Oban is available"
    assert msg =~ "Ready: pgvector library is available"

    assert msg =~
             "Not checked here: doctor did not query the database, Oban queues, or pgvector indexes"
  end
end
```

Planner note: prefix/readiness truth belongs in doctor, but `/health` stays liveness. Copy the "Not checked here" style unless a check actually queries the DB.

---

### DB-Backed Integration Tests (test, DB-backed CRUD + catalog proof)

**Analogs:** `test/support/data_case.ex`, `test/integration/outbound_bulk_envelopes_migration_test.exs`, `test/integration/partial_unique_index_test.exs`, `test/integration/jsonb_roundtrip_test.exs`

**DataCase pattern** (`test/support/data_case.ex` lines 12-38):
```elixir
using do
  quote do
    @moduletag :integration

    alias Cairnloop.Repo

    import Ecto
    import Ecto.Changeset
    import Ecto.Query
    import Cairnloop.DataCase
  end
end

setup tags do
  Cairnloop.DataCase.setup_sandbox(tags)
  :ok
end

def setup_sandbox(tags) do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Cairnloop.Repo, shared: not tags[:async])
  Application.put_env(:cairnloop, :repo, Cairnloop.Repo)
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
end
```

**Catalog assertion pattern** (`test/integration/outbound_bulk_envelopes_migration_test.exs` lines 20-29, 49-59):
```elixir
%{rows: rows} =
  Repo.query!(
    """
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = 'cairnloop_outbound_bulk_envelopes'
    ORDER BY ordinal_position
    """,
    []
  )
```

```elixir
%{rows: rows} =
  Repo.query!(
    """
    SELECT indexname
    FROM pg_indexes
    WHERE tablename = 'cairnloop_outbound_bulk_envelopes'
    ORDER BY indexname
    """,
    []
  )
```

**Real constraint behavior pattern** (`test/integration/partial_unique_index_test.exs` lines 15-35):
```elixir
test "rejects a second :pending approval for the same proposal" do
  proposal = proposal_fixture()

  assert {:ok, _first} =
           %ToolApproval{}
           |> ToolApproval.changeset(%{tool_proposal_id: proposal.id, status: :pending})
           |> Repo.insert()

  assert {:error, changeset} =
           %ToolApproval{}
           |> ToolApproval.changeset(%{tool_proposal_id: proposal.id, status: :pending})
           |> Repo.insert()

  assert errors_on(changeset)[:tool_proposal_id]

  pending_count =
    ToolApproval
    |> where([a], a.tool_proposal_id == ^proposal.id and a.status == :pending)
    |> Repo.aggregate(:count)

  assert pending_count == 1
end
```

**Runtime env setup pattern** (`test/integration/jsonb_roundtrip_test.exs` lines 40-44):
```elixir
setup do
  Application.put_env(:cairnloop, :tools, [PassTool])
  on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
  :ok
end
```

Planner note: new integration tests should use `DataCase`, catalog queries with `table_schema`/`schemaname`, and real facade calls. Add a collision test that creates misleading `public.cairnloop_*` rows while configured prefix is `"cairnloop"`; no exact existing collision analog was found, so combine DataCase + catalog assertion patterns.

---

### Example App Setup Tests (test, DB-backed setup proof)

**Analogs:** `examples/cairnloop_example/test/support/data_case.ex`, `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs`

**Example DataCase pattern** (`examples/cairnloop_example/test/support/data_case.ex` lines 19-40):
```elixir
using do
  quote do
    alias CairnloopExample.Repo

    import Ecto
    import Ecto.Changeset
    import Ecto.Query
    import CairnloopExample.DataCase
  end
end

setup tags do
  CairnloopExample.DataCase.setup_sandbox(tags)
  :ok
end

def setup_sandbox(tags) do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(CairnloopExample.Repo, shared: not tags[:async])
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
end
```

**Postgres-dependent example test tag** (`examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` lines 7-11):
```elixir
# Tag this entire suite as :requires_postgres. Developers and CI lanes without
# Postgres on localhost:5433 can safely skip with:
#   mix test --exclude requires_postgres
@moduletag :requires_postgres
```

**Seed execution inside sandbox** (`examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` lines 31-49):
```elixir
# The eval'd script runs in the current process, so it inherits the sandbox
# connection checked out by DataCase.setup_sandbox/1. No Sandbox.allow/3 call
# is needed. Oban.drain_queue/1 also runs in-process and sees the same connection.
defp run_seed!() do
  seed_path = Path.expand("../../priv/repo/seeds.exs", __DIR__)
  assert File.exists?(seed_path), "seed file not found at resolved path: #{seed_path}"
  Code.eval_file(seed_path)
  :ok
end
```

Planner note: add an example setup/schema test that queries `CairnloopExample.Repo` catalogs for `cairnloop.cairnloop_*` support tables and `public.oban_jobs`, then runs a lightweight facade read/write if feasible.

## Shared Patterns

### Authentication

No Phase 59 source changes should add auth surfaces. Existing dashboard/web auth stays host-owned and out of scope.

### Error Handling

**Source:** `lib/cairnloop/retrieval.ex` lines 38-42 and `lib/cairnloop/doctor.ex` lines 5-17.

Apply to health/doctor prefix checks: fail closed, report calm copy, and avoid raw exceptions in operator-facing output.

```elixir
rescue
  _ -> {:error, "Unreachable / Degraded"}
catch
  :exit, _ -> {:error, "Unreachable / Degraded"}
end
```

### Prefix Helper

**Source:** `lib/cairnloop/schema_prefix.ex`

Apply to all raw SQL, migration SQL strings, generated migrations, doctor structural checks, and any Repo options added for prefix behavior.

### Migration Qualification

**Source:** `lib/mix/tasks/cairnloop/install.ex` lines 48-79.

Apply to all Cairnloop support-domain migrations in:

- `priv/repo/migrations/*.exs`
- `priv/test_host/migrations/*.exs`
- `examples/cairnloop_example/priv/repo/migrations/*.exs`

Every support-domain `table`, `alter`, `drop`, `index`, `unique_index`, and `references` call should carry `prefix: prefix`; raw SQL should use quoted helper output.

### Oban Boundary

**Sources:** `priv/test_host/migrations/20260101000001_add_oban_jobs.exs` lines 1-24, `lib/cairnloop/retrieval.ex` lines 26-30 and 191-210.

Apply to all Oban checks/enqueues: keep Oban host-owned. Do not schema-qualify `oban_jobs` with `Cairnloop.SchemaPrefix`.

### Repo Indirection

**Sources:** `lib/cairnloop/chat.ex` lines 6-8, `lib/cairnloop/mcp.ex` lines 83-85.

All runtime facades/workers call `Application.fetch_env!(:cairnloop, :repo)` through a local `repo/0`; tests inject mock repos. Add prefix opts without replacing repo injection.

### Source-Scan Tests

**Sources:** `test/cairnloop/schema_prefix_test.exs`, `test/cairnloop/migrations_test.exs`, `test/cairnloop/tasks/install_test.exs`.

Use source scans for drift guards, but pair them with DB-backed tests for object placement, functions, triggers, FKs, `vector`, public compatibility, and collision isolation.

### DB-Backed Tests

**Sources:** `test/support/data_case.ex`, `test/integration/outbound_bulk_envelopes_migration_test.exs`, `test/integration/partial_unique_index_test.exs`.

Use `Cairnloop.DataCase` for integration tests and query `information_schema`/`pg_catalog` directly for physical placement. Include `table_schema` or `schemaname` in every Phase 59 catalog query.

## No Analog Found

| File Or Subpattern | Role | Data Flow | Reason |
|--------------------|------|-----------|--------|
| Public/dedicated same-name collision branch inside `test/integration/schema_prefix_contract_test.exs` | test | DB-backed collision proof | Existing integration tests assert table/index shape and real constraints, but no current test creates misleading `public.cairnloop_*` rows while asserting configured `cairnloop` prefix wins. Compose `DataCase` plus catalog-query patterns. |

## Metadata

**Analog search scope:** `lib/cairnloop`, `test`, `priv`, `examples/cairnloop_example`
**Files scanned:** 345
**Migration files scanned:** 25 real migration files, excluding `.formatter.exs`
**Schema modules with prefix attribute:** 20
**Pattern extraction date:** 2026-06-30
