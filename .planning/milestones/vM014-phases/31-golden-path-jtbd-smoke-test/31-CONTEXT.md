# Phase 31: Golden-Path JTBD Smoke Test - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Lock the full JTBD lifecycle and the Phase 28 widget channel ingress into the `mix test.integration` lane using `Phoenix.LiveViewTest` + `Phoenix.ChannelTest` — no new test deps, no browser driver. Two test files are the output: `test/integration/golden_path_test.exs` (full JTBD state machine) and `test/integration/widget_channel_test.exs` (channel ingress + operator inbox re-render). All 9 existing integration tests pass unmodified; both new tests run green against real Postgres + pgvector in CI.

</domain>

<decisions>
## Implementation Decisions

### Test structure (E2E-01)

- **D-01:** `golden_path_test.exs` uses **one long sequential `test "full JTBD round trip"`** that accumulates state across all stages. The golden path IS a state machine — each stage's DB artifacts are the only valid inputs to the next. Forced per-stage independent setup would recreate the full fixture chain for every stage, producing brittle fiction. This matches the `approval_flow_test.exs` pattern for sequential chains. CI signal = "the whole path is green."

- **D-02:** The 8+ sequential stages within the single test are:
  1. **Seed** — create a `Conversation` row + seed a customer `Message` via `Chat.ingest_widget_message/2` (or equivalent fixture)
  2. **Inbox sees** — mount `InboxLive` via `live(conn, "/inbox")`; assert the conversation row appears in the rendered inbox
  3. **ConversationLive + cmd+k search + citation chip** — mount `ConversationLive` via `live(conn, "/#{conversation.id}")`; inject stub retrieval module via `send_update/2` (see D-03); fire `phx-keydown` for `"Escape"` toggle (or `toggle_search` event); type a search query; assert results appear; click a citation chip result
  4. **Approve AI draft** — seed a draft (via `Governance.propose/3` with a stub DraftTool, or via DB fixture); assert draft approval affordance renders in ConversationLive; fire the `approve_draft` event; assert draft approved
  5. **Tool proposal approve** — propose a governed tool via `Governance.propose/3`; mount ConversationLive; fire the `approve` event on the approval footer; assert `:approved` state
  6. **ToolExecutionWorker :success** — call `ApprovalResumeWorker.perform/1` (inline struct); then `ToolExecutionWorker.perform/1`; assert `:executed` state in DB + `done_group` chip in ConversationLive
  7. **Resolve** — fire the `resolve` event on ConversationLive; assert conversation status flips to `:resolved`
  8. **Outbound.trigger/2** — fire the outbound sidebar trigger event (or call `Outbound.trigger/2` directly); assert `Message` row with `:system_outbound` role created
  9. **Bulk recovery** — mount `InboxLive`; select the resolved conversation checkbox; open confirm modal; fire `confirm_bulk_recovery`; assert `BulkEnvelope` row created + `OutboundWorker` jobs enqueued

### cmd+k search approach (E2E-01, step 3)

- **D-03:** Use a **stub retrieval module injected via `Phoenix.LiveViewTest.send_update/2`**. After mounting `ConversationLive`, call:
  ```elixir
  send_update(Cairnloop.Web.SearchModalComponent,
    id: "search-modal",
    retrieval_module: StubRetrieval
  )
  ```
  Define `StubRetrieval` as a module-level inline defmodule in the test that implements `search/2` returning a fixed list of result structs. No code changes to `ConversationLive` needed — the `SearchModalComponent` already accepts `:retrieval_module` as an overridable assign (lines 21-22 of `search_modal_component.ex`). This decouples the smoke test from pgvector availability and embedding pipeline timing (the embedding pipeline is already locked by `seeds_test.exs`).

- **D-04:** The stub should return at least 1 result with a valid `article_id` + `content` so the citation chip fires correctly. The citation chip event (likely `"cite"` or `"open_result"`) should advance the test toward the draft approve step.

### Widget channel test (E2E-02)

- **D-05:** `widget_channel_test.exs` uses **`ConnCase`** (not `DataCase`) since it needs both `Phoenix.ChannelTest` + `Phoenix.LiveViewTest` in the same test. Import both in the test file. The Endpoint + PubSub are already started under the integration supervisor when `integration? = true` (see `test_helper.exs`).

- **D-06:** **"Operator-side delivery" = PubSub assert + InboxLive mount.** The test proves E2E-02's "operator-side delivery" claim definitively:
  1. Mount `InboxLive` via `live(conn, "/inbox")` (connected?, so it subscribes to `"conversations"` PubSub topic)
  2. `subscribe_and_join` WidgetChannel on `"widget:lobby"` with token; assert join reply includes `conversation_id`
  3. Push `"new_message"` via the channel; call `ProcessMessage.perform/1` inline (the Oban worker — established pattern from existing tests); assert `Chat.ingest_widget_message/2` ran
  4. Assert `assert_receive {:conversations_changed}` on `Cairnloop.PubSub` OR assert InboxLive re-renders showing the new conversation subject/row
  5. Final assertion: `assert html =~ some_indicator_of_new_conversation` in InboxLive

- **D-07:** `async: false` for both test files. The `DataCase.setup_sandbox` call sets `shared: true` when `async: false`, meaning all spawned processes (LiveView PIDs, channel PIDs) share the sandbox connection automatically — no explicit `Ecto.Adapters.SQL.Sandbox.allow/3` calls needed.

### Auto-decided (no discussion needed)

- **D-08:** Both tests live in `test/integration/` and receive `@moduletag :integration` automatically via `ConnCase`. Both run under `mix test.integration` with zero additional configuration.

- **D-09:** All Oban workers are called directly via `Worker.perform(%Oban.Job{args: ...})` — established pattern across every existing integration test. Do NOT use `Oban.Testing.perform_jobs` or `Oban.drain_queue` in either new test.

- **D-10:** Inline `defmodule` stubs (`StubRetrieval`, `StubContextProvider`, inline tool definitions) live inside the test file, exactly as `NoteWriteTool`, `StubContextProvider`, and `FailingAuditor` do in the existing integration tests.

- **D-11:** Phase 30's `EditorHandoff` gates (T-10-09 / T-10-11) are NOT exercised in the golden path test — those are covered by the Phase 30 test suite (`suggestion_review_test.exs` / `knowledge_base_live_test.exs`). The golden path traverses: inbox → conversation approval → tool execution → outbound/bulk. KB editorial is a separate surface.

- **D-12:** `SeedRun.run/0` is NOT called in the golden path test setup. Inline minimal fixtures (conversation row + messages via `Cairnloop.Fixtures` helpers or direct `Repo.insert/1`) are sufficient and faster. `seeds_test.exs` already pins the full seed pipeline.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements + Roadmap
- `.planning/REQUIREMENTS.md` §E2E — E2E-01, E2E-02, E2E-03 with full acceptance criteria. Read before writing the test assertions.
- `.planning/ROADMAP.md` §Phase 31 — Goal, success criteria (3 items), depends-on chain (Phases 27–30).

### Existing integration test patterns (read before writing new tests)
- `test/integration/approval_flow_test.exs` — Single sequential test pattern for a multi-step state machine chain. Inline tool defmodule. `ApprovalResumeWorker.perform/1` direct call pattern.
- `test/integration/tool_execution_outcome_live_test.exs` — `ConnCase` + LiveViewTest + inline tool + `ToolExecutionWorker.perform/1` direct call. The OBS-02 attribution assertion pattern.
- `test/integration/bulk_recovery_live_test.exs` — `ConnCase` bulk-action flow; multi-step LiveViewTest event sequence; `Outbound.bulk_trigger/2` call; `BulkEnvelope` row assertion. Direct analog for the golden path's outbound/bulk stage.
- `test/integration/bulk_trigger_atomicity_test.exs` — `DataCase` + direct `Outbound.bulk_trigger/2` call. Shows how to assert `BulkEnvelope` row count + per-recipient `Message` rows.

### Test infrastructure
- `test/support/data_case.ex` — `DataCase` template; `setup_sandbox` sets `shared: true` for `async: false`, so spawned processes (LiveView PIDs, channel PIDs) share the sandbox automatically.
- `test/support/conn_case.ex` — `ConnCase` template; imports `Phoenix.LiveViewTest`, `Phoenix.ConnTest`; builds conn pointed at `Cairnloop.Web.Endpoint`. Add `import Phoenix.ChannelTest` in `widget_channel_test.exs`.
- `test/support/fixtures.ex` — `Cairnloop.Fixtures`; `conversation_fixture/1`, `proposal_fixture/1`, `approval_fixture/2`, `message_fixture/1`. Use these for inline fixture setup.
- `test/test_helper.exs` — Integration supervisor starts `Cairnloop.Repo`, `Phoenix.PubSub`, `Cairnloop.Web.Endpoint` when `integration? = true`. Channel test needs the Endpoint running (already handled).

### SearchModalComponent injection point
- `lib/cairnloop/web/search_modal_component.ex` lines 21–22, 337 — `:retrieval_module` overridable assign (default: `Cairnloop.Retrieval`); `update/2` callback accepts it from parent. Line 478: `run_search(retrieval_module, query, opts)`. Inject via `Phoenix.LiveViewTest.send_update/2` after mounting ConversationLive.

### Key source files the golden path test traverses
- `lib/cairnloop/web/inbox_live.ex` — InboxLive; `handle_info({:conversations_changed}, socket)` at ~line 562; PubSub subscribe at mount inside `connected?` block.
- `lib/cairnloop/web/conversation_live.ex` — ConversationLive; approval footer, tool execution, resolve event, outbound sidebar trigger.
- `lib/cairnloop/channels/widget_channel.ex` — `join("widget:lobby", ...)` creates conversation via `Chat.create_customer_conversation/1`; `handle_in("new_message", ...)` enqueues ProcessMessage.
- `lib/cairnloop/workers/process_message.ex` — ProcessMessage Oban worker; calls `Chat.ingest_widget_message/2`.
- `lib/cairnloop/workers/approval_resume_worker.ex` — `perform/1` direct call pattern.
- `lib/cairnloop/workers/tool_execution_worker.ex` — `perform/1` direct call pattern.
- `lib/cairnloop/chat.ex` — `create_customer_conversation/1`, `ingest_widget_message/2` (Phase 28 additions).
- `lib/cairnloop/governance.ex` — `propose/3` used for seeding tool proposals in the test.
- `lib/cairnloop/outbound.ex` — `trigger/2` and `bulk_trigger/2`; `BulkEnvelope` row creation.

### Architecture posture
- `CLAUDE.md` — Build/test conventions (warnings-clean, mix test gate), arch invariants (sealed primitives, Governance facade, brand tokens). Tests must compile with `--warnings-as-errors`.
- `.planning/STATE.md` §Accumulated Context — "vM014 test harness decision: Phoenix.LiveViewTest + Phoenix.ChannelTest. NOT Wallaby. NOT PhoenixTest dep." Confirms D-07/D-09.

### Prior phase context
- `.planning/phases/28-customer-chat-wired-to-real-ingress/28-CONTEXT.md` — D-01..D-17 document the full WidgetChannel wiring. D-06: `Chat.ingest_widget_message/2` broadcasts `{:conversations_changed}` on `"conversations"` PubSub topic. D-09: InboxLive subscribes to `"conversations"` in mount. Critical for widget_channel_test design.
- `.planning/phases/30-kb-editorial-polish-t-10-09-t-10-11-closure/30-CONTEXT.md` — D-11 confirms Phase 30 SEC gates are NOT in golden path scope (D-11 in this context maps to this phase's D-11 exclusion).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Cairnloop.Fixtures`** — `conversation_fixture/1` + `message_fixture/1` + `proposal_fixture/1` + `approval_fixture/2` handle all inline setup needed for the golden path stages without calling `SeedRun.run/0`.
- **`ConnCase` + `import Phoenix.ChannelTest`** — Adding the ChannelTest import to `widget_channel_test.exs` gives access to `subscribe_and_join/3`, `push/3`, `assert_reply/3` alongside `live/2`. The Endpoint is already started under the integration supervisor.
- **Inline `defmodule` stub pattern** — `NoteWriteTool` in `tool_execution_outcome_live_test.exs` and `StubContextProvider` in `approval_footer_live_test.exs` show the pattern for `StubRetrieval` and any inline tool needed by the golden path test.
- **`Governance.propose/3`** — Already tested directly in `approval_flow_test.exs` as the seeding mechanism for tool proposals. Use it to seed the draft/tool proposal stages.
- **`Outbound.bulk_trigger/2`** — Already exercised in `bulk_recovery_live_test.exs`. The bulk stage at the end of the golden path can call this directly OR fire the LiveView event — the LiveView event approach is more realistic.

### Established Patterns
- **Direct worker execution:** `Worker.perform(%Oban.Job{args: %{"key" => val}})` — used in `approval_flow_test.exs`, `tool_execution_outcome_live_test.exs`, `tool_execution_worker_test.exs`. Never `Oban.drain_queue` in the golden path test.
- **Application env injection:** `Application.put_env(:cairnloop, :key, Value)` + `on_exit(fn -> Application.delete_env/2 end)` — used for `:context_provider`, `:tools`, `:max_batch_size`. The golden path needs `:context_provider → StubContextProvider` and `:tools → [InlineTestTool]`.
- **LiveViewTest event sequence:** `render_click(view, selector)`, `render_keydown(view, selector, key)`, `render_change(view, form, params)`, `render_submit(view, form, params)` — `bulk_recovery_live_test.exs` has the most complete example of a multi-step LiveViewTest event chain.
- **`send_update/2` inject:** `Phoenix.LiveViewTest.send_update(Module, id: "id", assigns...)` — standard LiveComponent testing idiom; no code changes to the parent LiveView required.
- **`assert html =~` string assertions** — Every existing integration test uses HTML substring assertions, not CSS selector assertions. Keep the same pattern.

### Integration Points
- `test/integration/golden_path_test.exs` — new file; `use Cairnloop.ConnCase, async: false`; the golden path smoke test
- `test/integration/widget_channel_test.exs` — new file; `use Cairnloop.ConnCase, async: false`; the channel ingress + InboxLive delivery test
- No new test support files needed — everything is available in existing `ConnCase`, `DataCase`, and `Fixtures`
- No new mix.exs dependencies — `Phoenix.ChannelTest` is part of the phoenix_live_view package already in dev/test deps

</code_context>

<specifics>
## Specific Ideas

- The `StubRetrieval` module inside the golden path test file should implement `search/2 :: {:ok, [%{id: integer, article_id: integer, content: binary, score: float}]}` (or whatever shape `SearchModalComponent` expects from `Cairnloop.Retrieval.search/2`). Check `lib/cairnloop/retrieval.ex` for the exact return shape before writing the stub.
- For the `widget_channel_test.exs`, the channel join token should be `"demo_customer"` (per Phase 28 CONTEXT.md §Specifics — the example app JS hook uses this token; `WidgetSocket` accepts any binary token in demo mode).
- The golden path test's single test function can be structured with inline `# Stage N: ...` comments to make it readable as a walkthrough document — this mirrors the moduledoc structure in `bulk_recovery_live_test.exs`.
- Both tests should include a `@moduledoc` that references the requirement IDs they close (E2E-01, E2E-02, E2E-03) and the `# REPO-UNAVAILABLE` note per CLAUDE.md convention.

</specifics>

<deferred>
## Deferred Ideas

- Channel topic re-join from `"widget:lobby"` to `"widget:{conversation_id}"` (deferred from Phase 28 CONTEXT.md) — still out of scope for Phase 31. The `widget_channel_test.exs` stays on `"widget:lobby"`.
- Wallaby / Selenium browser-driven smoke tests — explicitly out of scope per STATE.md deferred items.
- PhoenixTest as a new test dependency — explicitly out of scope per STATE.md deferred items.

</deferred>

---

*Phase: 31-golden-path-jtbd-smoke-test*
*Context gathered: 2026-05-28*
