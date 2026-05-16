# Project State

## Project Reference
**Core Value:** Provide an embedded Elixir-native customer support engine with high extensibility, strict AI governance, and zero external infrastructure dependencies.
**Current Focus:** Milestone M008 - The Knowledge Base Engine (RAG Substrate). Building an immutable, revision-based Knowledge Base with LiveView Markdown authoring and Oban-powered semantic chunking with pgvector.

## Current Position
**Phase:** 2
**Plan:** 01
**Status:** Completed Phase 2 Plan 01

## Progress
[░░░░░░░░░░] 0% Complete (M008)

## Performance Metrics
- **Test Coverage:** Ensure core Ecto immutability is thoroughly tested.
- **System Constraints:** Maintain idiomatic Elixir. Use Oban for async chunking. Rely on `pgvector` inside PostgreSQL. Avoid WYSIWYG editors.
- **Completed:** 2-01-PLAN.md (Tasks: 3, Files Modified: 2, Duration: 2min)

## Accumulated Context
- **Decisions:** 
  - Using an immutable Revision-Based architecture (`Article`, `Revision`, `Chunk`) inside Ecto to avoid orphaned vectors.
  - Employing Markdown natively with side-by-side LiveView preview for maximum RAG parsing fidelity.
  - Offloading semantic chunking (H2/H3) and embedding generation to background Oban workers using `pgvector`.
  - Relied on the existing implementation for `Cairnloop.Notifier` and `CheckSLA`, verifying everything matches the planned specification exactly and appending test files to solidify correctness.
- **Todos:** 
  - Initialize plans for M008 phases.
- **Blockers:** 
  - None

## Session Continuity
Stopped At: Completed 2-01-PLAN.md
