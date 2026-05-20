---
phase: M009-S04
plan: "02"
subsystem: retrieval
tags: [retrieval, ecto, oban, retention, gap-events]
requires:
  - phase: M009-S04
    provides: bounded retrieval telemetry metadata and structured diagnostic reasons
provides:
  - append-only retrieval gap-event storage with typed envelope fields
  - synchronous gap recorder writes with sanitized query evidence and snapshot dedupe
  - explicit 90-day Oban-backed pruning for durable gap-event retention
affects: [retrieval, drafting, search, observability, future-clustering]
tech-stack:
  added: []
  patterns: [append-only retrieval gap events, synchronous Ecto.Multi persistence, explicit Oban retention maintenance]
key-files:
  created:
    [
      lib/cairnloop/retrieval/gap_event.ex,
      lib/cairnloop/retrieval/gap_event_snapshot.ex,
      lib/cairnloop/retrieval/gap_recorder.ex,
      lib/cairnloop/retrieval/workers/prune_gap_events.ex,
      priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs,
      test/cairnloop/retrieval/gap_recorder_test.exs,
      test/cairnloop/retrieval/workers/prune_gap_events_test.exs
    ]
  modified: []
key-decisions:
  - "Used one append-only `cairnloop_retrieval_gap_events` table with `Ecto.Enum` envelope fields plus embedded evidence snapshots instead of a normalized lineage model."
  - "Kept the primary gap-event write synchronous through `Ecto.Multi` and treated prune scheduling as best-effort follow-up so product semantics do not depend on Oban state."
  - "Applied sanitization and dedupe in the recorder by hashing raw queries for fingerprints, storing redacted excerpts, and collapsing duplicate attempted-evidence snapshots."
patterns-established:
  - "Retrieval gap persistence writes one durable row immediately and leaves maintenance work to a separate explicit worker."
  - "Gap-event snapshots preserve canonical-vs-assistive semantics with bounded embedded payloads."
requirements-completed: [M009-REQ-09]
duration: 19min
completed: 2026-05-20
---

# Phase M009-S04 Plan 02: Retrieval Gap Event Store Summary

**Append-only retrieval gap events with synchronous recorder inserts, sanitized evidence snapshots, and explicit 90-day pruning**

## Performance

- **Duration:** 19 min
- **Started:** 2026-05-20T20:00:00Z
- **Completed:** 2026-05-20T20:18:57Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added a dedicated retrieval gap-event schema, embedded snapshot contract, and migration with indexes over occurrence time, scope, and diagnostic fields.
- Implemented `Cairnloop.Retrieval.GapRecorder` as a synchronous `Ecto.Multi` seam that sanitizes query excerpts, fingerprints raw queries, and deduplicates attempted evidence snapshots.
- Added `Cairnloop.Retrieval.Workers.PruneGapEvents` for explicit 90-day retention and covered both recorder and retention behavior with focused unit tests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the append-only retrieval gap-event schema and synchronous recorder seam** - `6246092` (feat)
2. **Task 2: Add the explicit 90-day retention worker and maintenance contract** - `7676f03` (feat)

## Files Created/Modified
- `lib/cairnloop/retrieval/gap_event.ex` - typed append-only gap-event schema with embedded attempted-evidence snapshots
- `lib/cairnloop/retrieval/gap_event_snapshot.ex` - bounded embedded snapshot payload preserving source and trust semantics
- `lib/cairnloop/retrieval/gap_recorder.ex` - synchronous recorder API with sanitization, fingerprinting, dedupe, and secondary prune scheduling
- `lib/cairnloop/retrieval/workers/prune_gap_events.ex` - explicit 90-day Oban pruning worker and retention cutoff helpers
- `priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs` - durable retrieval gap-events table and indexes
- `test/cairnloop/retrieval/gap_recorder_test.exs` - immediate-availability, sanitization, and secondary-scheduling coverage
- `test/cairnloop/retrieval/workers/prune_gap_events_test.exs` - retention-window and prune-worker lifecycle coverage

## Verification
- `mix test test/cairnloop/retrieval/gap_recorder_test.exs` ✅
- `mix test test/cairnloop/retrieval/workers/prune_gap_events_test.exs` ✅
- `mix test test/cairnloop/retrieval/gap_recorder_test.exs test/cairnloop/retrieval/workers/prune_gap_events_test.exs` ✅
- `rg -n 'field\(:surface, Ecto.Enum|field\(:outcome_class, Ecto.Enum|field\(:reason, Ecto.Enum|query_fingerprint|sanitized_query_excerpt|canonical_hit_count|assistive_hit_count|90|prune|retention' lib/cairnloop test/cairnloop priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs` ✅

## Decisions Made
- Kept durable gap evidence in one focused relational table and used embeds for attempted evidence snapshots to stay aligned with the phase’s “boring and explicit” storage posture.
- Stored only redacted excerpts plus SHA-256 fingerprints of raw queries so future clustering can correlate events without hoarding raw customer text.
- Scheduled prune follow-up after a successful insert and tolerated enqueue failure so retention maintenance remains secondary to the boundary-owned row write.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Targeted test runs emit existing repo-level Postgrex warnings for `Chimeway.Repo` missing database configuration. The owned retrieval tests still pass and the warning was left untouched because it is outside this plan’s scope.

## User Setup Required

None - no external service configuration required.

## Known Stubs
None.

## Threat Flags
None.

## Self-Check: PASSED
- Summary file exists at `.planning/milestones/M009-phases/M009-S04/M009-S04-02-SUMMARY.md`.
- Task commits `6246092` and `7676f03` exist in git history.

## Next Phase Readiness
- Search and drafting boundaries can now persist no-hit, retrieval-error, and weak-grounding evidence synchronously through `GapRecorder`.
- The follow-on integration plan can wire concrete boundary calls into search and draft flows without revisiting storage or retention semantics.

---
*Phase: M009-S04*
*Completed: 2026-05-20*
