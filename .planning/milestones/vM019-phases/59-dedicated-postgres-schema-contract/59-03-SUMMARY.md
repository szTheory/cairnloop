---
phase: 59-dedicated-postgres-schema-contract
plan: "03"
subsystem: runtime-facades
tags: [postgres, ecto, schema-prefix, runtime, integration-tests]
requires:
  - phase: 59-01
    provides: SchemaPrefix helper and red DB runtime contracts
  - phase: 59-02
    provides: Prefix-aware KB/retrieval migration family
provides:
  - Prefix-aware Chat facade reads, writes, preloads, and SLA lookups
  - Prefix-aware KnowledgeBase article, revision, draft, publish, and chunk query paths
  - Prefix-aware MCP token insert, read, list, update, and revoke paths
  - Runtime collision contracts for KB and MCP public-table masking
affects: [phase-59, db-prefix, chat, knowledge-base, mcp]
tech-stack:
  added: []
  patterns:
    - Runtime facades use local `prefixed/1` query helpers and `SchemaPrefix.repo_opts/0` write opts
    - Oban job inserts remain host-owned/public while Cairnloop support-domain rows are prefixed
key-files:
  modified:
    - lib/cairnloop/chat.ex
    - lib/cairnloop/knowledge_base.ex
    - lib/cairnloop/mcp.ex
    - test/cairnloop/chat_test.exs
    - test/cairnloop/knowledge_base_test.exs
    - test/cairnloop/mcp_test.exs
    - test/cairnloop/channels/widget_channel_test.exs
    - test/cairnloop/chat_telemetry_test.exs
    - test/cairnloop/knowledge_automation/article_suggestion_test.exs
    - test/cairnloop/knowledge_automation/gap_candidate_test.exs
    - test/cairnloop/web/conversation_live_test.exs
    - test/cairnloop/web/mcp/auth_plug_test.exs
    - test/cairnloop/workers/ingest_scrypath_test.exs
    - test/cairnloop/workers/outbound_worker_test.exs
    - test/cairnloop/workers/process_message_test.exs
    - test/integration/schema_prefix_runtime_test.exs
key-decisions:
  - "Kept sealed public function signatures unchanged; prefixing is internal to repo/query construction."
  - "Used explicit query prefixes for reads/preloads and repo `:prefix` opts for writes because schema compile prefixes alone do not prove public compatibility."
  - "Kept Oban job inserts unprefixed so host-owned Oban remains outside the Cairnloop support schema contract."
patterns-established:
  - "Facade-local `prefixed/1` helpers apply the configured support prefix before Ecto query composition."
requirements-completed: []
requirements-advanced: [DB-05, DB-06]
duration: 15 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 03: Core Runtime Prefixing Summary

**Chat, KnowledgeBase, and MCP now route core support-domain reads and writes through the configured Cairnloop schema prefix without public API churn.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-06-30T15:21:00Z
- **Completed:** 2026-06-30T15:34:50Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- Added prefix-aware query/write helpers to `Chat`, `KnowledgeBase`, and `MCP`.
- Updated Chat conversation/message/SLA reads, writes, preloads, resolution, CSAT, and queue lookups to use the configured support prefix.
- Updated KnowledgeBase article/revision/draft/publish/chunk paths, including a prefix-aware article status update inside `publish_revision/1`.
- Updated MCP token issue/validate/list/update/revoke paths to use prefixed persistence.
- Extended unit tests and runtime integration contracts so public collision tables cannot silently satisfy dedicated-schema behavior.
- Aligned older mock repos and migration source-shape assertions with the explicit prefix opts surfaced by the fast CI gate.

## Task Commits

1. **Task 1: Prefix Chat, KnowledgeBase, and MCP public APIs without signature churn** - `f4e7910` (fix)
2. **Task 2: Align broader fast-CI tests with prefix-aware facade calls** - `0e01630` (test)

**Plan metadata:** this summary commit.

## Files Modified

- `lib/cairnloop/chat.ex` - Prefix-aware conversation/message reads and writes, preload queries, SLA lookups, resolution, CSAT, and next-open query.
- `lib/cairnloop/knowledge_base.ex` - Prefix-aware KB reads/writes, draft transactions, publish status update, and chunk search query.
- `lib/cairnloop/mcp.ex` - Prefix-aware MCP token issue/validate/list/update/revoke paths.
- `test/cairnloop/chat_test.exs` - Mock-repo assertions for prefixed Chat query/write/Multi paths.
- `test/cairnloop/knowledge_base_test.exs` - Mock-repo assertions for prefixed KB query/write/Multi/chunk paths.
- `test/cairnloop/mcp_test.exs` - Mock-repo assertions for prefixed MCP token persistence.
- `test/integration/schema_prefix_runtime_test.exs` - Added KB and MCP public-collision runtime contract cases.
- Broader facade consumers in channel, worker, telemetry, LiveView, MCP auth, and knowledge-automation tests - Mock arity shims and migration source assertions updated for explicit prefix opts.

## Decisions Made

- Did not change any public function signatures in the core facades.
- Used `Ecto.Multi.run/3` for the dependent article status update in `KnowledgeBase.publish_revision/1` so the article fetch and update both run with explicit prefix opts.
- Left Oban job inserts without `SchemaPrefix.repo_opts/0`; Oban remains host-owned and public by contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Function-form `Ecto.Multi.update/4` hid article update prefix behavior**
- **Found during:** focused KnowledgeBase test run.
- **Issue:** Ecto stored function-form `Ecto.Multi.update/4` as a run operation, so the mock could not assert the article update opts and the production path was less explicit.
- **Fix:** Replaced the dependent article update with `Ecto.Multi.run/3`, then fetched and updated the article through the transaction repo using `SchemaPrefix.repo_opts/0`.
- **Files modified:** `lib/cairnloop/knowledge_base.ex`, `test/cairnloop/knowledge_base_test.exs`
- **Verification:** `mix test test/cairnloop/chat_test.exs test/cairnloop/knowledge_base_test.exs test/cairnloop/mcp_test.exs --warnings-as-errors`
- **Committed in:** `f4e7910`

---

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** The fix made the dependent publish update more directly prefix-aware without changing facade APIs.

## Issues Encountered

- DB-backed runtime integration was not run as a green gate for this plan because the phase still has later migration/test-host owner plans. The integration file was compile-checked with its `:integration` tests excluded.
- First `mix ci.fast` run failed after the core facade commit because older mocks did not implement the explicit `get!/3` / `insert/2` repo calls, and two migration source-shape tests still expected unprefixed DDL strings. Updated those tests in `0e01630`; the rerun passed.

## User Setup Required

None.

## Verification

- PASS: `mix test test/cairnloop/chat_test.exs test/cairnloop/knowledge_base_test.exs test/cairnloop/mcp_test.exs --warnings-as-errors`
- PASS: `mix compile --warnings-as-errors`
- PASS: `mix test --exclude integration test/integration/schema_prefix_runtime_test.exs --warnings-as-errors` compiled the integration contract file with 7 integration tests excluded.
- PASS: `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/outbound_worker_test.exs test/cairnloop/workers/process_message_test.exs test/cairnloop/channels/widget_channel_test.exs test/cairnloop/web/mcp/auth_plug_test.exs test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/gap_candidate_test.exs test/cairnloop/web/conversation_live_test.exs --warnings-as-errors`
- PASS: `mix test test/cairnloop/workers/ingest_scrypath_test.exs --warnings-as-errors`
- PASS: `mix ci.fast` (1151 tests, 0 failures, 78 excluded)

## Next Phase Readiness

Ready for the remaining Wave 2 work. Plan 59-03 has converted the core runtime facades; later plans still own additional migration families, host setup, and the final DB-backed runtime proof.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
