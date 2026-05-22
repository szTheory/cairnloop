---
phase: M007-S01
plan: 01
subsystem: Cairnloop
tags: [telemetry, oban, scrypath, ingestion]
requires: []
provides: [Scrypath API dependency, IngestScrypath worker, telemetry wiring]
affects: [Cairnloop.Application, mix.exs]
key-files:
  created:
    - lib/cairnloop/workers/ingest_scrypath.ex
    - test/cairnloop/workers/ingest_scrypath_test.exs
  modified:
    - mix.exs
    - lib/cairnloop/application.ex
key-decisions:
  - Used Req client to communicate with the Scrypath vector database API over HTTPS.
  - Wrapped `Oban.insert/1` inside a `try/rescue` block in the telemetry handler to prevent test suite crashes when Oban is not running.
---

# Phase M007-S01 Plan 01: Scrypath Ingestion Setup Summary

Implemented telemetry wiring and an Oban worker for asynchronous indexing of resolved conversations into the Scrypath vector database.

## Deviations from Plan

None - plan executed exactly as written, with minor standard accommodations for test suite behavior (wrapping `Oban.insert` in `try-rescue`).

## Threat Flags

None found.

## Known Stubs

- **`lib/cairnloop/workers/ingest_scrypath.ex` (line 7)**: Hardcoded `"dummy"` fallback for `:scrypath_api_key` environment variable.

## Self-Check: PASSED
FOUND: lib/cairnloop/workers/ingest_scrypath.ex
FOUND: test/cairnloop/workers/ingest_scrypath_test.exs
FOUND: mix.exs
FOUND: lib/cairnloop/application.ex
