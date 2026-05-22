---
phase: M008-S01
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mix.exs
  - config/config.exs
  - lib/cairnloop/postgrex_types.ex
  - priv/repo/migrations/*_create_knowledge_base.exs
  - lib/cairnloop/knowledge_base/article.ex
  - lib/cairnloop/knowledge_base/revision.ex
  - lib/cairnloop/knowledge_base/chunk.ex
  - lib/cairnloop/knowledge_base.ex
  - test/cairnloop/knowledge_base_test.exs
  - test/cairnloop/knowledge_base/revision_test.exs
autonomous: true
requirements:
  - M008-REQ-01
must_haves:
  truths:
    - "System contains Article, Revision, and Chunk data structures"
    - "Published Revisions cannot be modified"
    - "System can query the latest active revision for an article"
    - "Vector embedding type is supported by PostgreSQL and Ecto"
  artifacts:
    - path: "lib/cairnloop/knowledge_base/article.ex"
      provides: "Article schema"
    - path: "lib/cairnloop/knowledge_base/revision.ex"
      provides: "Revision schema with immutability"
    - path: "lib/cairnloop/knowledge_base/chunk.ex"
      provides: "Chunk schema with vector field"
    - path: "lib/cairnloop/knowledge_base.ex"
      provides: "Knowledge Base Context module"
  key_links:
    - from: "lib/cairnloop/knowledge_base/revision.ex"
      to: "Ecto Changeset"
      via: "validation logic checking state == :published"
---

<objective>
Establish the core relational models for a revision-based Knowledge Base to prevent orphaned vector embeddings.

Purpose: We need to store Articles and their content Revisions in an immutable way. Once a revision is published, it cannot be modified so its vectorized chunks remain perfectly aligned with the exact text.
Output: pgvector integration, Ecto migrations, Schemas (Article, Revision, Chunk), Context module, and unit tests.
</objective>

<execution_context>
@$HOME/.gemini/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/milestones/M008-phases/M008-S01-CONTEXT.md
@.planning/milestones/M008-phases/M008-S01/M008-S01-RESEARCH.md
@.planning/milestones/M008-phases/M008-S01/M008-S01-PATTERNS.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add pgvector and Postgrex Types</name>
  <files>mix.exs, lib/cairnloop/postgrex_types.ex, config/config.exs</files>
  <action>
    - Add `{:pgvector, "~> 0.3.1"}` to the dependencies in `mix.exs`.
    - Create `lib/cairnloop/postgrex_types.ex` module that defines types via `Postgrex.Types.define(Cairnloop.PostgrexTypes, Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(), [])`.
    - Update `config/config.exs` to set `types: Cairnloop.PostgrexTypes` on the `Cairnloop.Repo` configuration.
    - Run `mix deps.get`.
  </action>
  <verify>
    <automated>mix deps.get && mix compile</automated>
  </verify>
  <done>pgvector dependency is installed and Ecto is configured to handle vector types natively.</done>
</task>

<task type="auto">
  <name>Task 2: Knowledge Base Migrations and Schemas</name>
  <files>priv/repo/migrations/*_create_knowledge_base.exs, lib/cairnloop/knowledge_base/article.ex, lib/cairnloop/knowledge_base/revision.ex, lib/cairnloop/knowledge_base/chunk.ex</files>
  <action>
    - Generate a new migration file `priv/repo/migrations/*_create_knowledge_base.exs`. 
    - In the migration's `up` function, first execute `CREATE EXTENSION IF NOT EXISTS vector`. Then create tables: `cairnloop_articles` (title, status), `cairnloop_revisions` (article_id, content, version, state: default "draft"), and `cairnloop_chunks` (revision_id, content, embedding: vector(1536)). Add appropriate indexes (like `article_id` on revisions, `revision_id` on chunks).
    - Create `Article` schema with `has_many :revisions`. Field `status` (Enum: :draft, :published, :archived).
    - Create `Revision` schema with `belongs_to :article` and `has_many :chunks`. Field `state` (Enum: :draft, :published, :archived). Add changeset logic to enforce immutability: if the revision state in DB is already `:published`, reject any changes to `content`.
    - Create `Chunk` schema with `belongs_to :revision` and `field :embedding, Pgvector.Ecto.Vector`.
  </action>
  <verify>
    <automated>mix ecto.migrate</automated>
  </verify>
  <done>Database contains the knowledge base tables with vector support, and Ecto schemas are fully modeled with associations and immutability rules.</done>
</task>

<task type="auto">
  <name>Task 3: Knowledge Base Context and Tests</name>
  <files>lib/cairnloop/knowledge_base.ex, test/cairnloop/knowledge_base_test.exs, test/cairnloop/knowledge_base/revision_test.exs</files>
  <action>
    - Create Context module `Cairnloop.KnowledgeBase` with dynamic repo load pattern (`Application.fetch_env!(:cairnloop, :repo)`).
    - Implement `get_latest_active_revision(article_id)` querying `Revision` where `state == :published` ordered by version desc, limit 1.
    - Write unit tests in `test/cairnloop/knowledge_base_test.exs` ensuring context functions correctly return latest active revision.
    - Write unit tests in `test/cairnloop/knowledge_base/revision_test.exs` ensuring that modifying a published revision's content correctly returns an Ecto.Changeset error enforcing immutability.
  </action>
  <verify>
    <automated>mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/revision_test.exs</automated>
  </verify>
  <done>Context provides APIs for Knowledge Base operations and all immutability/query logic is thoroughly tested.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Internal -> Database | Knowledge base content and embeddings persisted to storage. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-M008-01 | Tampering | `Revision` Schema | mitigate | Enforce immutability via `Ecto.Changeset` validations to prevent background jobs or manual API calls from modifying published content and detaching vectors. |
| T-M008-02 | Tampering | `Chunk` Schema | mitigate | Vector column sizes strictly typed at Ecto boundary to prevent malicious injection of oversized array data. |
</threat_model>

<verification>
- pgvector dependency resolves and compiles
- Migration applies cleanly including the PostgreSQL vector extension
- Schemas correctly model the relational graph
- Ecto Changeset rejects updates to published revision content
- Unit tests verify querying for the active revision
</verification>

<success_criteria>
1. Database contains `Article`, `Revision`, and `Chunk` schemas with proper foreign keys and indexes.
2. Ecto models enforce immutability for published revisions, ensuring historical accuracy and preventing "Orphaned Vectors".
3. System can query the latest active revision for any given article.
</success_criteria>

<output>
After completion, create `.planning/milestones/M008-phases/M008-S01-SUMMARY.md`
</output>
