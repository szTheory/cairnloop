# Phase 1: Immutable Knowledge Base Foundation (Ecto) - Research

**Researched:** 2024
**Domain:** Elixir, Ecto, pgvector, CMS Architecture
**Confidence:** HIGH

## Summary

This phase establishes the foundational Ecto models (`Article`, `Revision`, `Chunk`) for the Knowledge Base Engine. To prevent "Orphaned Vectors" (where an embedding no longer matches the text it represents), the architecture uses immutable revisions. Operators draft content in a mutable `:draft` state. Upon publishing, the state transitions to `:published` and the Ecto model is locked—any further changes require creating a new revision.

The `pgvector` library enables storing vector embeddings natively within PostgreSQL. While Phase 3 will handle the actual generation of embeddings, Phase 1 must implement the schema support by adding the `vector` extension and defining the column types using `Pgvector.Ecto.Vector`.

**Primary recommendation:** Use `pgvector` (0.3.1+) with Ecto, and strictly enforce `Revision` immutability at the Ecto Changeset layer to ensure background processes never encounter orphaned embeddings.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M008-REQ-01 | System implements an immutable Revision-Based architecture in Ecto, utilizing `Article`, `Revision`, and `Chunk` schemas. | Ecto Changeset `enforce_immutability/1` logic, pgvector schema configuration, and specific relational mapping. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| KnowledgeBase Identity | Database / Storage | — | `Article` schema acts as the parent container and stable identifier for a Knowledge Base entry. |
| Content Immutability | API / Backend | Database / Storage | `Revision` schema represents a point-in-time state. The Ecto layer enforces immutability via changesets when state transitions to `:published`. |
| Vector Storage | Database / Storage | — | `Chunk` schema utilizes `pgvector` to store vectorized portions of a specific published revision. |
| Revision Lifecycle | API / Backend | — | The Context module coordinates drafting, publishing (locking the previous revision), and retrieving the "active" revision. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sql` | ~> 3.10 | Relational database mapping | Standard for Phoenix/Elixir apps. |
| `pgvector` | ~> 0.3.1 | Ecto support for PostgreSQL vector type | Official Elixir integration for pgvector, enables storing `Pgvector.Ecto.Vector` types natively. |

**Installation:**
Add to `mix.exs`:
```elixir
{:pgvector, "~> 0.3.1"}
```

## Architecture Patterns

### System Architecture Diagram
```text
[KnowledgeBase Context]
       │
       ▼
  ┌─────────┐
  │ Article │
  └─────────┘
       │ 1:M
       ▼
 ┌──────────┐ (Immutable if state == :published)
 │ Revision │ ◀── queried for "latest active"
 └──────────┘
       │ 1:M
       ▼
   ┌───────┐
   │ Chunk │ (Contains Pgvector.Ecto.Vector)
   └───────┘
```

### Pattern 1: Pgvector Ecto Integration
**What:** Configuring Ecto to understand the PostgreSQL `vector` type.
**When to use:** When adding vector columns to schemas.
**Implementation:**
Requires defining a custom `PostgrexTypes` module:
```elixir
Postgrex.Types.define(Cairnloop.PostgrexTypes, Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(), [])
```
And configuring the Repo in `config.exs`:
```elixir
config :cairnloop, Cairnloop.Repo, types: Cairnloop.PostgrexTypes
```

### Pattern 2: Enforcing Changeset Immutability
**What:** Rejecting changes to a record if it has already been persisted in a locked state.
**When to use:** In the `Revision` schema, once a revision is `:published`, its content must never change to preserve alignment with `Chunk` vectors.
**Example:**
```elixir
defp enforce_immutability(changeset) do
  if changeset.data.state == :published do
    case changeset.changes do
      %{state: :archived} -> changeset # Allow archiving a published revision
      changes when map_size(changes) == 0 -> changeset
      _ -> add_error(changeset, :base, "Cannot modify a published revision.")
    end
  else
    changeset
  end
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vector Storage | JSON arrays in `:text` or `:map` columns | `pgvector` | JSON arrays cannot be natively searched for nearest-neighbor cosine distance without fetching all rows into memory. `pgvector` handles this natively in the DB. |
| Immutability | UI-only disabled states | Ecto Changeset validations | UI validations can be bypassed by console scripts, API calls, or background workers, leading to orphaned vectors. |

## Common Pitfalls

### Pitfall 1: Forgetting the Vector Extension
**What goes wrong:** Migrations fail with "type vector does not exist".
**Why it happens:** The `pgvector` extension must be installed in PostgreSQL before the `vector` type can be used in table definitions.
**How to avoid:** Create a dedicated migration that runs `execute("CREATE EXTENSION IF NOT EXISTS vector")` *before* the Knowledge Base tables are created.

### Pitfall 2: Modifying Published Revisions (Orphaned Vectors)
**What goes wrong:** The underlying text of a published revision is changed, but the AI continues to retrieve the old embeddings which now point to modified or contradictory text.
**Why it happens:** Allowing updates to published revisions breaks the synchronization between the `Revision` content and its `Chunk` embeddings.
**How to avoid:** Always create a *new* `:draft` revision, modify that, and publish it. The old published revision remains untouched.

## Code Examples

### 1. Migrations
```elixir
def up do
  execute("CREATE EXTENSION IF NOT EXISTS vector")

  create table(:cairnloop_articles) do
    add :title, :string, null: false
    timestamps()
  end

  create table(:cairnloop_revisions) do
    add :article_id, references(:cairnloop_articles, on_delete: :delete_all), null: false
    add :content, :text, null: false
    add :version, :integer, null: false
    add :state, :string, null: false, default: "draft"
    timestamps()
  end
  
  create index(:cairnloop_revisions, [:article_id])

  create table(:cairnloop_chunks) do
    add :revision_id, references(:cairnloop_revisions, on_delete: :delete_all), null: false
    add :content, :text, null: false
    add :embedding, :vector, size: 1536 # OpenAI standard
    timestamps()
  end
  
  create index(:cairnloop_chunks, [:revision_id])
end
```

### 2. Querying the Latest Active Revision
```elixir
# lib/cairnloop/knowledge_base.ex
def get_latest_active_revision(article_id) do
  from(r in Revision,
    where: r.article_id == ^article_id and r.state == :published,
    order_by: [desc: r.version],
    limit: 1
  )
  |> Repo.one()
end
```

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | Ecto/pgvector | ✓ | — | — |
| `pgvector` ext | Database Storage | ✓ | — | — |

*(PostgreSQL is already the primary data store, but ensure the local postgres instance has the `pgvector` extension installed at the system level. If using Docker, use the `pgvector/pgvector` image).*

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| M008-REQ-01 | Revisions cannot be modified once published | unit | `mix test test/cairnloop/knowledge_base/revision_test.exs` | ❌ Wave 0 |
| M008-REQ-01 | Latest active revision can be queried | unit | `mix test test/cairnloop/knowledge_base_test.exs` | ❌ Wave 0 |

## Open Questions

1. **Embedding Size**
   - What we know: OpenAI text-embedding-3-small uses 1536 dimensions.
   - What's unclear: If Cairnloop intends to support other models (Cohere, local HuggingFace), fixing the size to 1536 might be too rigid.
   - Recommendation: For Phase 1, use `add :embedding, :vector` (without a hardcoded size parameter) to allow flexibility, or use 1536 if OpenAI is the definitive standard.

## Sources

### Primary (HIGH confidence)
- `pgvector` hex documentation: Verified integration patterns for Ecto.
- `M008-S01-PATTERNS.md`: Analogs from `Conversation` and `Message` models for structural alignment.