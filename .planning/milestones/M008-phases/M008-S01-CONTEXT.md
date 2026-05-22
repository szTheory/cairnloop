# M008-S01 Context: Immutable Knowledge Base Foundation (Ecto)

## Goal
Establish the core relational models for a revision-based Knowledge Base to prevent orphaned vector embeddings.

## Requirements
- M008-REQ-01: System implements an immutable Revision-Based architecture in Ecto, utilizing `Article`, `Revision`, and `Chunk` schemas.

## Success Criteria
1. Database contains `Article`, `Revision`, and `Chunk` schemas with proper foreign keys and indexes.
2. Ecto models enforce immutability for published revisions, ensuring historical accuracy and preventing "Orphaned Vectors".
3. System can query the latest active revision for any given article.
