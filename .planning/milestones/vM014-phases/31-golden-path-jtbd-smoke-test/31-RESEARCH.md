# Phase 31: Golden-Path JTBD Smoke Test — Research

**Researched:** 2026-05-28
**Domain:** Elixir / Phoenix LiveViewTest + ChannelTest integration testing against real Postgres + pgvector
**Confidence:** HIGH — all findings from direct source-code inspection of the Cairnloop codebase

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** `golden_path_test.exs` uses one long sequential test accumulating state across 9 stages. The golden path IS a state machine.

**D-02:** The 9 sequential stages are: (1) Seed, (2) Inbox sees, (3) ConversationLive + cmd+k search + citation chip, (4) Approve AI draft, (5) Tool proposal approve, (6) ToolExecutionWorker :success, (7) Resolve, (8) Outbound.trigger/2, (9) Bulk recovery.

**D-03:** Use `send_update/2` to inject `StubRetrieval` into `SearchModalComponent` after mounting ConversationLive.

**D-04:** StubRetrieval stub implements `search/2` returning a fixed list of result structs; returns at least 1 result with a valid `article_id` + `content`.

**D-05:** `widget_channel_test.exs` uses `ConnCase` (not DataCase); imports `Phoenix.ChannelTest` inline.

**D-06:** "Operator-side delivery" proved via PubSub assert + InboxLive mount. Subscribe InboxLive, join WidgetChannel, push "new_message", call ProcessMessage.perform/1 inline, assert {:conversations_changed} or InboxLive re-render.

**D-07:** `async: false` for both test files. DataCase.setup_sandbox sets `shared: true` when `async: false` — all spawned processes (LiveView PIDs, channel PIDs) share sandbox automatically.

**D-08:** Both tests live in `test/integration/` and receive `@moduletag :integration` automatically via `ConnCase`. Both run under `mix test.integration`.

**D-09:** All Oban workers called directly via `Worker.perform(%Oban.Job{args: ...})`. Never `Oban.drain_queue`.

**D-10:** Inline defmodule stubs (`StubRetrieval`, `StubContextProvider`, inline tool definitions) live inside the test file.

**D-11:** Phase 30's EditorHandoff gates NOT exercised in the golden path test.

**D-12:** `SeedRun.run/0` NOT called in golden path setup. Use inline minimal fixtures.

### Claude's Discretion
(none explicit — all implementation details auto-decided in D-01..D-12)

### Deferred Ideas (OUT OF SCOPE)
- Channel topic re-join from "widget:lobby" to "widget:{conversation_id}"
- Wallaby / Selenium browser-driven smoke tests
- PhoenixTest as a new test dependency

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| E2E-01 | `test/integration/golden_path_test.exs` covers full JTBD round trip: seed → inbox → cmd+k search → approve AI draft → tool propose/approve → ToolExecutionWorker :success → resolve → Outbound.trigger/2 → bulk recovery → BulkEnvelope + OutboundWorker jobs | All source files verified; exact APIs, event names, and arg shapes documented below |
| E2E-02 | `test/integration/widget_channel_test.exs` covers customer-ingress: join → push "new_message" → PubSub broadcast → operator-side delivery | WidgetChannel.join/3 and ProcessMessage arg shapes confirmed; InboxLive PubSub topic confirmed |
| E2E-03 | Both tests in `mix test.integration` lane, green in CI, no Wallaby, no PhoenixTest dep | mix.exs aliases confirmed; existing integration harness confirmed as the established lane |

</phase_requirements>

---

## Summary

Phase 31 creates two new integration test files against the verified source code of Phases 27–30. The entire golden-path lifecycle can be driven with the existing `ConnCase` + `Phoenix.LiveViewTest` + `Phoenix.ChannelTest` primitives that already back 9 passing integration tests. No new dependencies are needed. No library source code changes are needed — only new test files.

The critical implementation details below are drawn entirely from source inspection of the actual Cairnloop library code. They supersede any training-data assumptions about function signatures, event names, and return shapes.

**Primary recommendation:** Write both test files in a single wave; use the `tool_execution_outcome_live_test.exs` + `bulk_recovery_live_test.exs` patterns as the structural template. The golden path "resolve" stage calls `Chat.resolve_conversation/2` directly (no LiveView event named "resolve" exists in `ConversationLive`), and the outbound sidebar trigger is `phx-click="trigger_recovery_follow_up"` (only available when `conversation.status == :resolved`).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Widget message ingress | API/Channel (WidgetChannel) | Worker (ProcessMessage) | Channel owns connection; worker owns DB write |
| Operator inbox refresh | Frontend Server (InboxLive) | PubSub | InboxLive subscribes to "conversations" topic; Chat facade broadcasts |
| Search modal | Frontend Server (SearchModalComponent) | Retrieval module | LiveComponent owns UI; retrieval module is injectable |
| Approval state machine | API/Backend (Governance) | Workers (ApprovalResumeWorker, ToolExecutionWorker) | Governance facade owns state transitions; workers own execution |
| Outbound recovery trigger | API/Backend (Outbound facade) | Frontend Server (ConversationLive) | Outbound owns persistence; LiveView is the trigger surface |
| Bulk recovery | Frontend Server (InboxLive) | API/Backend (Outbound.bulk_trigger/2) | InboxLive owns cockpit; Outbound facade owns envelope + fan-out |

---

## Standard Stack

No new dependencies. This phase uses only existing libraries.

| Library | Version | Purpose |
|---------|---------|---------|
| Phoenix.LiveViewTest | existing | Drive LiveView events in-process |
| Phoenix.ChannelTest | existing (part of phoenix_live_view) | subscribe_and_join/3, push/3, assert_reply/3 |
| Ecto.Adapters.SQL.Sandbox | existing | shared: true sandbox for async: false |
| Oban.Job | existing | Direct worker perform/1 calls |

---

## Package Legitimacy Audit

No new packages installed in this phase. N/A.

---

## Architecture Patterns

### Recommended Project Structure

Two new files only:
```
test/integration/
├── golden_path_test.exs         # new — E2E-01 (full JTBD state machine)
└── widget_channel_test.exs      # new — E2E-02 (channel ingress + inbox delivery)
```

No new files in `test/support/`.

### Pattern 1: Sequential single-test state machine (golden_path_test.exs)

**What:** One `test "full JTBD round trip"` block that accumulates DB state across 9 inline stages, each separated by a `# Stage N: ...` comment.

**When to use:** When each stage's DB artifacts are the only valid inputs to the next stage. Per D-01, forced per-stage independence would recreate the full fixture chain for every stage.

**Template:**
```elixir
defmodule Cairnloop.Integration.GoldenPathTest do
  @moduledoc """
  E2E-01: Full JTBD round trip.
  # REPO-UNAVAILABLE — only runs under mix test.integration
  """
  use Cairnloop.ConnCase, async: false

  import Cairnloop.Fixtures
  import Ecto.Query

  alias Cairnloop.{Chat, Governance, Outbound}
  alias Cairnloop.Outbound.BulkEnvelope
  alias Cairnloop.Message
  alias Cairnloop.Workers.{ApprovalResumeWorker, ToolExecutionWorker}

  # ---- Inline stubs (D-10) ----
  defmodule StubContextProvider do
    def get_context(_host_user_id, _opts), do: {:ok, %{}}
  end

  defmodule InlineTestTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Golden Path Tool",
      description: "No scope required."

    embedded_schema do
      field(:conversation_id, :string)
      field(:note, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs),
      do: Ecto.Changeset.cast(struct, attrs, [:conversation_id, :note])

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{done: true}}
  end

  defmodule StubRetrieval do
    def search(_query, _opts) do
      [
        %Cairnloop.Retrieval.Result{
          id: 1,
          article_id: 1,
          title: "Test Article",
          content: "Stub content for golden path",
          source_type: :knowledge_base,
          trust_level: :canonical,
          score: 0.9
        }
      ]
    end
  end

  setup do
    Application.put_env(:cairnloop, :tools, [InlineTestTool])
    Application.put_env(:cairnloop, :context_provider, StubContextProvider)
    Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")

    on_exit(fn ->
      Application.delete_env(:cairnloop, :tools)
      Application.delete_env(:cairnloop, :context_provider)
      Application.delete_env(:cairnloop, :outbound_recovery_template_id)
    end)

    conn = Plug.Test.init_test_session(@conn, %{"host_user_id" => "golden_operator"})
    %{conn: conn}
  end

  test "full JTBD round trip", %{conn: conn} do
    # Stage 1: Seed ...
    # Stage 2: Inbox sees ...
    # Stage 3: ConversationLive + cmd+k search ...
    # etc.
  end
end
```

### Pattern 2: Channel test with ConnCase (widget_channel_test.exs)

**What:** ConnCase test that imports `Phoenix.ChannelTest` inline and uses `subscribe_and_join/3` to join WidgetChannel. LiveView mount via `live/2` on the same conn.

**Template:**
```elixir
defmodule Cairnloop.Integration.WidgetChannelTest do
  @moduledoc """
  E2E-02: Widget channel ingress + operator-side delivery.
  # REPO-UNAVAILABLE — only runs under mix test.integration
  """
  use Cairnloop.ConnCase, async: false

  import Phoenix.ChannelTest
  import Cairnloop.Fixtures

  alias Cairnloop.Workers.ProcessMessage

  @endpoint Cairnloop.Web.Endpoint

  setup do
    conn = Plug.Test.init_test_session(@conn, %{"host_user_id" => "widget_operator"})
    %{conn: conn}
  end

  test "customer message joins → processes → operator inbox refreshes", %{conn: conn} do
    # subscribe_and_join pattern ...
    # ProcessMessage.perform/1 inline ...
    # PubSub / InboxLive assert ...
  end
end
```

### Anti-Patterns to Avoid

- **`Oban.drain_queue/1`**: Never use in these tests. All Oban workers are called directly via `Worker.perform(%Oban.Job{args: ...})`. Established pattern across all existing integration tests (D-09).
- **`SeedRun.run/0`**: Do not call in setup. Use `Cairnloop.Fixtures` helper functions directly (D-12).
- **Asserting flash text**: `TestLayouts` renders only `@inner_content`, not `@flash`. Assert load-bearing side effects (BulkEnvelope row, Message rows, DB status) instead. See `bulk_recovery_live_test.exs` lines 189–199 for the documented pattern.
- **`async: true`**: Both files must use `async: false` so the sandbox `shared: true` mode automatically allows LiveView PIDs + channel PIDs to borrow the sandbox connection (D-07).
- **`ConversationLive` route confusion**: The test router mounts ConversationLive at `/governance/:id`, not `/:id`. Use `live(conn, "/governance/#{conversation.id}")` in tests.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fake Oban execution | Custom job runner | `Worker.perform(%Oban.Job{args: ...})` | Established pattern across all 9 integration tests; no Oban runtime needed |
| DB-free retrieval | Actual pgvector search | `StubRetrieval` via `send_update/2` | Embedding pipeline is already locked by `seeds_test.exs`; stub decouples smoke test from pgvector timing |
| Auth setup | Custom session handling | `Plug.Test.init_test_session/2` | Already used in `bulk_recovery_live_test.exs`; `ConnCase` returns a bare conn |
| Sandbox allow calls | `Ecto.Adapters.SQL.Sandbox.allow/3` | `async: false` + `shared: true` (auto via DataCase.setup_sandbox) | When `async: false`, `setup_sandbox` passes `shared: not tags[:async]` = `shared: true` — all spawned processes share automatically |

---

## Verified API Reference

This section contains source-verified function signatures and behaviors for every API the test files will call.

### SearchModalComponent (VERIFIED from source)

**File:** `lib/cairnloop/web/search_modal_component.ex`

- Line 21-22: `:retrieval_module` IS an overridable assign in `update/2`. Default: `Cairnloop.Retrieval`.
- Line 337: `assign_defaults/1` sets `retrieval_module: Cairnloop.Retrieval`.
- Line 478: `run_search/3` dispatches via `retrieval_module.search(query, opts)`.
- The component ID in `ConversationLive.render/1` is `id="search-modal"` (line 412 of conversation_live.ex).

**Inject pattern:**
```elixir
send_update(Cairnloop.Web.SearchModalComponent,
  id: "search-modal",
  retrieval_module: StubRetrieval
)
```

**Citation chip events:** There is NO `"cite"` or `"open_result"` event fired back to the parent LiveView. The search modal handles results internally:
- `"activate_result"` — sets active result (mouse hover / keyboard nav)
- `"open_active_result"` — navigates to the result's `open_path`
- `"open_result"` — activates + opens by `dom_id`
- `"search"` — fires search query

For the golden path test, stage 3 should: trigger `"toggle_search"` to open the palette (or assert it opens on cmd+k keydown), fire `"search"` with a query string, assert the rendered HTML contains the stub result title, then fire `"activate_result"` + `"open_active_result"` to simulate citation chip click. The modal does not push an event to the parent for "cite" — it fires `push_navigate` internally.

**StubRetrieval return shape** (from `Cairnloop.Retrieval.Result` struct):
```elixir
%Cairnloop.Retrieval.Result{
  id: 1,
  article_id: 1,
  title: "Test Article",
  content: "Stub content",
  source_type: :knowledge_base,  # :knowledge_base or :resolved_case
  trust_level: :canonical,        # :canonical or :assistive
  score: 0.9
}
```
The `run_search/3` non-default clause (line 478) accepts `results when is_list(results)` — return a plain list of Result structs, no `{:ok, results}` wrapper needed from the stub.

### WidgetChannel (VERIFIED from source)

**File:** `lib/cairnloop/channels/widget_channel.ex`

**`join("widget:lobby", payload, socket)`:**
- Reads `token` from `socket.assigns[:user_token]` (set during `WidgetSocket.connect/3`).
- Calls `Cairnloop.Chat.create_customer_conversation(%{host_user_id: token})`.
- On success: returns `{:ok, %{conversation_id: conversation.id}, updated_socket}`.
- `socket.assigns.conversation_id` is set on success.

**`handle_in("new_message", %{"content" => content}, socket)`:**
- Reads `conversation_id = socket.assigns[:conversation_id]`.
- Enqueues `ProcessMessage.new(%{channel: "widget", conversation_id: conversation_id, content: content})`.
- Returns `{:reply, :ok, socket}` on success.

**WidgetSocket.connect/3** (file: `lib/cairnloop/channels/widget_socket.ex`):
- Accepts `params = %{"token" => token}` where `token` is any binary.
- In demo/test mode, any binary token passes: `{:ok, assign(socket, :user_token, token)}`.
- Use token `"demo_customer"` per CONTEXT.md §Specifics.

**subscribe_and_join pattern for widget_channel_test.exs:**
```elixir
{:ok, _reply, socket} =
  socket(Cairnloop.Channels.WidgetSocket, "widget_socket:demo_customer", %{user_token: "demo_customer"})
  |> subscribe_and_join(Cairnloop.Channels.WidgetChannel, "widget:lobby", %{})
```
The join reply is `%{conversation_id: id}`.

**Important:** The test endpoint (`test/support/endpoint.ex`) does NOT mount `WidgetSocket`. It only mounts `/live` for LiveView. The `socket/3` helper in `Phoenix.ChannelTest` builds the socket directly without going through the endpoint's socket mount — so `socket(Cairnloop.Channels.WidgetSocket, ...)` works directly.

### Chat facade (VERIFIED from source)

**File:** `lib/cairnloop/chat.ex`

**`create_customer_conversation/1`** (line 34):
```elixir
Chat.create_customer_conversation(%{host_user_id: "demo_customer"})
# Returns: {:ok, %Cairnloop.Conversation{}} | {:error, changeset}
# Side effect: broadcasts {:conversations_changed} on "conversations" PubSub topic
```

**`ingest_widget_message/2`** (line 60):
```elixir
Chat.ingest_widget_message(conversation_id, "hello from customer")
# Returns: {:ok, %Cairnloop.Message{}} | {:error, changeset}
# Side effects:
#   1. broadcasts {:message_created, message.id} on "conversation:#{conversation_id}"
#   2. broadcasts {:conversations_changed} on "conversations"
```

### Fixtures (VERIFIED from source)

**File:** `test/support/fixtures.ex`

All four fixtures exist and accept optional attrs maps:

```elixir
conversation_fixture(%{status: :open, subject: "...", host_user_id: "..."})
# Returns: %Cairnloop.Conversation{}
# Default: status: :open, subject: "Integration conversation", host_user_id: "test_operator"

message_fixture(%{conversation_id: id, content: "...", role: :user})
# Returns: %Cairnloop.Message{}
# Default: role: :internal_note, content: "Test internal note"

proposal_fixture(%{tool_ref: "...", input_snapshot: %{...}})
# Returns: %Cairnloop.Governance.ToolProposal{}
# Default: status: :proposed, risk_tier: :low_write, approval_mode: :requires_approval

approval_fixture(proposal, %{status: :pending})
# Returns: %Cairnloop.Governance.ToolApproval{}
# Default: status: :pending
```

There is NO `user_fixture/1` or `operator_fixture/1`. Authentication for the test conn uses `Plug.Test.init_test_session/2` (as in `bulk_recovery_live_test.exs` line 64).

### ConnCase (VERIFIED from source)

**File:** `test/support/conn_case.ex`

- Imports `Phoenix.LiveViewTest` (line 20). No `log_in_operator/2` helper exists.
- Sets up a raw `Phoenix.ConnTest.build_conn()` — auth is established via `Plug.Test.init_test_session/2`.
- The `@endpoint` module attribute is set to `Cairnloop.Web.Endpoint` (line 14).
- For widget_channel_test.exs: `import Phoenix.ChannelTest` must be added inline in the test module.

### ProcessMessage worker (VERIFIED from source)

**File:** `lib/cairnloop/workers/process_message.ex`

```elixir
# Widget branch — the one the golden path test uses:
ProcessMessage.perform(%Oban.Job{args: %{
  "channel" => "widget",
  "conversation_id" => conversation_id,   # integer ID
  "content" => "message text"
}})
# Returns: :ok on success, {:cancel, "changeset error: ..."} on permanent failure
```

Note: `conversation_id` in the args is the **integer** ID from `socket.assigns.conversation_id` (set during join). The Oban job enqueued by WidgetChannel stores it as-is.

### InboxLive PubSub (VERIFIED from source)

**File:** `lib/cairnloop/web/inbox_live.ex`

- **Topic:** `"conversations"` on `Cairnloop.PubSub`.
- **Subscription:** `Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")` inside `connected?` block at line 87.
- **Handler:** `handle_info({:conversations_changed}, socket)` at line 320 — reloads `Chat.list_conversations()` and re-assigns `conversations`.

The widget_channel_test.exs assertion should be:
```elixir
# Assert InboxLive re-renders with the new conversation:
html = render(inbox_view)
assert html =~ some_identifier_of_the_conversation
```
Or alternatively: subscribe to the PubSub topic before pushing the message and assert `assert_receive {:conversations_changed}`.

### ApprovalResumeWorker (VERIFIED from source)

**File:** `lib/cairnloop/workers/approval_resume_worker.ex`

```elixir
ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})
# Returns: :ok (transitions :approved → :execution_pending, enqueues ToolExecutionWorker)
```

### ToolExecutionWorker (VERIFIED from source)

**File:** `lib/cairnloop/workers/tool_execution_worker.ex`

```elixir
ToolExecutionWorker.perform(%Oban.Job{
  attempt: 1,
  max_attempts: 3,
  args: %{"approval_id" => approval.id}
})
# Returns: :ok on success (:executed state, ToolActionEvent :execution_succeeded appended)
# Returns: {:cancel, reason} on terminal failure
```

Note: `%Oban.Job{attempt: 1, max_attempts: 3}` is required because the worker reads `attempt` and `max_attempts` fields to decide whether to retry or cancel. This matches the exact pattern in `tool_execution_outcome_live_test.exs` lines 155-160.

### ConversationLive event names (VERIFIED from source)

**File:** `lib/cairnloop/web/conversation_live.ex`

All `handle_event` clauses (exhaustive):
- `"reply"` — sends a reply
- `"change"` — form change
- `"approve_draft"` — params: `%{"draft-id" => id}`
- `"edit_draft"` — params: `%{"draft-id" => id}`
- `"discard_draft"` / `"cancel_discard_draft"` / `"confirm_discard_draft"`
- `"start_quick_fix"` / `"open_review_task"` / `"open_manual_draft"`
- `"trigger_recovery_follow_up"` — fires `Outbound.trigger/2` for resolved conversations
- `"execute_tool"` — params: `%{"tool" => tool_ref, "tool_params" => %{}}`
- `"approve_action"` — params: `%{"approval-id" => id}`
- `"reject_action"` / `"defer_action"`

**CRITICAL:** There is NO `"resolve"` event handler in `ConversationLive`. The golden path "resolve" stage (D-02 stage 7) must call `Chat.resolve_conversation/2` directly:
```elixir
Chat.resolve_conversation(conversation.id, resolved_by: "golden_operator")
```

**CRITICAL:** The outbound sidebar trigger button (`phx-click="trigger_recovery_follow_up"`) only renders when `@conversation.status == :resolved` (line 856 of conversation_live.ex). The resolve step (stage 7) must precede the outbound trigger step (stage 8). The ConversationLive view must be reloaded after calling `Chat.resolve_conversation/2` directly, since it does not broadcast a PubSub event that ConversationLive handles. Use `render(view)` after reload or remount.

### ConversationLive route in test router (VERIFIED from source)

**File:** `test/support/router.ex`

```elixir
live("/governance/:id", Cairnloop.Web.ConversationLive, :show)
```

The test URL is `/governance/#{conversation.id}`, NOT `/:id`. CONTEXT.md's reference to `live(conn, "/#{conversation.id}")` is incorrect — the test router mounts it at `/governance/:id`.

### Outbound.trigger/2 (VERIFIED from source)

**File:** `lib/cairnloop/outbound.ex`

```elixir
Outbound.trigger(conversation.id,
  template_id: "recovery_v1",
  actor: conversation.host_user_id
)
# Returns: {:ok, results} | {:error, step, reason, changes}
# Side effect: inserts a :system_outbound Message row with metadata["bulk_envelope_id"] = nil
```

However, in the golden path's stage 8, the test fires the LiveView event `"trigger_recovery_follow_up"` (more realistic and tests the UI path). The `trigger_recovery_follow_up` event is only available when `conversation.status == :resolved` AND `:outbound_recovery_template_id` is configured. The test setup must set:
```elixir
Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")
```

### Outbound.bulk_trigger/2 (VERIFIED from source)

**File:** `lib/cairnloop/outbound.ex` line 249

```elixir
bulk_trigger(conversation_ids, [
  template_id: "recovery_v1",
  rendered_body: "Outbound message using template: recovery_v1",
  actor: "golden_operator"
])
# Returns: {:ok, %BulkEnvelope{}} | {:error, :batch_too_large}
```

In the golden path test, stage 9 drives the bulk recovery through the `InboxLive` LiveView events (more realistic), exactly as in `bulk_recovery_live_test.exs`. For `OutboundWorker` jobs assertion: the bulk submit path calls `Outbound.trigger/2` per recipient inside an Ecto.Multi transaction — it creates `system_outbound` Message rows. Actual Oban `OutboundWorker` jobs are NOT enqueued by `bulk_trigger/2` itself; instead per-recipient `trigger/2` calls create `system_outbound` Message rows. The assertion from `bulk_recovery_live_test.exs` is:
```elixir
assert Repo.aggregate(BulkEnvelope, :count, :id) == before_count + 1
envelope = BulkEnvelope |> order_by([e], desc: e.inserted_at) |> limit(1) |> Repo.one!()
assert envelope.status == :submitted
messages = Message |> where([m], m.conversation_id in ^ids and m.role == :system_outbound) |> Repo.all()
assert length(messages) == N
```

### mix.exs integration lane (VERIFIED from source)

**File:** `mix.exs` lines 70, 52-71

```elixir
"test.integration": ["test.setup", "test --include integration test/integration"]
```

- Both new test files in `test/integration/` will be automatically picked up.
- `@moduletag :integration` comes from `ConnCase.using/0` block (line 7 of conn_case.ex).
- No additional configuration needed for E2E-03.

---

## Common Pitfalls

### Pitfall 1: ConversationLive route is `/governance/:id` not `/:id`
**What goes wrong:** Test fails with a 404 or wrong LiveView mount.
**Why it happens:** CONTEXT.md's stage descriptions say `live(conn, "/#{conversation.id}")`, but the test router mounts ConversationLive at `/governance/:id`.
**How to avoid:** Always use `live(conn, "/governance/#{conversation.id}")` in tests.
**Warning signs:** `{:error, {:redirect, ...}}` or missing assigns in the mounted view.

### Pitfall 2: No "resolve" event in ConversationLive
**What goes wrong:** Test fires `render_click(view, "resolve")` → `FunctionClauseError` from `handle_event`.
**Why it happens:** `ConversationLive` has no `handle_event("resolve", ...)` clause. The resolve functionality does not surface as a LiveView button/event in the current implementation.
**How to avoid:** Stage 7 calls `Chat.resolve_conversation(conversation.id, resolved_by: "golden_operator")` directly. Then either reload ConversationLive or remount it to verify `:resolved` status in the rendered HTML.

### Pitfall 3: trigger_recovery_follow_up only renders for :resolved conversations
**What goes wrong:** Stage 8's `render_click(view, element("button[phx-click='trigger_recovery_follow_up']"))` fails because the button is absent from the rendered HTML.
**Why it happens:** The `outbound_recovery_card/1` component (line 854) is wrapped in `<%= if @conversation.status == :resolved do %>`. If stage 7 happens correctly, status is `:resolved` and the button appears.
**How to avoid:** Ensure stage 7 (resolve) fully commits before attempting stage 8. Since ConversationLive subscribes to `"conversation:#{id}"` topic and `Chat.resolve_conversation/2` does NOT broadcast on that topic, the view will not auto-refresh. Remount ConversationLive after calling `Chat.resolve_conversation/2` directly.

### Pitfall 4: StubRetrieval return shape must match Retrieval.Result struct
**What goes wrong:** `SearchModalComponent` crashes with a `KeyError` or `FunctionClauseError` when iterating results.
**Why it happens:** `build_sections/1` calls `&1.source_type` and `SearchResultPresenter.dom_id/1` on each result. If stub returns plain maps, these field accesses fail.
**How to avoid:** Return `%Cairnloop.Retrieval.Result{...}` structs, not plain maps. At minimum set `:source_type`, `:trust_level`, `:id`, `:title`, `:content`.

### Pitfall 5: ToolExecutionWorker requires %Oban.Job{attempt:, max_attempts:} fields
**What goes wrong:** `FunctionClauseError` or `KeyError` when calling `ToolExecutionWorker.perform/1` without both fields.
**Why it happens:** The worker's `perform/1` clause pattern-matches on all three: `attempt`, `max_attempts`, and `args`.
**How to avoid:** Always pass `%Oban.Job{attempt: 1, max_attempts: 3, args: %{"approval_id" => id}}`.

### Pitfall 6: Widget channel test socket requires @endpoint module attribute
**What goes wrong:** `Phoenix.ChannelTest.socket/3` fails with a missing endpoint error.
**Why it happens:** `Phoenix.ChannelTest` macros use `@endpoint` module attribute.
**How to avoid:** `ConnCase` already sets `@endpoint Cairnloop.Web.Endpoint` (line 14 of conn_case.ex). But `import Phoenix.ChannelTest` must be added explicitly to widget_channel_test.exs since ConnCase does not include it.

### Pitfall 7: The TestEndpoint does not mount WidgetSocket
**What goes wrong:** Attempting to connect via HTTP websocket to the test endpoint.
**Why it happens:** `test/support/endpoint.ex` only mounts `/live` for LiveView; there is no `socket "/widget", Cairnloop.Channels.WidgetSocket` mount.
**How to avoid:** Use `socket(Cairnloop.Channels.WidgetSocket, "widget_socket:demo_customer", %{user_token: "demo_customer"})` directly — the `Phoenix.ChannelTest.socket/3` helper bypasses the endpoint socket mount and builds the socket struct directly.

### Pitfall 8: Governance.approve/3 requires an enqueue_fn in tests
**What goes wrong:** `Governance.approve/3` tries to call `Oban.insert/1` which may fail without a running Oban instance.
**Why it happens:** `approve/3` enqueues the `ApprovalResumeWorker` after recording the decision.
**How to avoid:** Use the `enqueue_fn:` capture pattern from `approval_flow_test.exs` (lines 52-56):
```elixir
test_pid = self()
capture = fn job -> send(test_pid, {:enqueued, job}); {:ok, job} end
Governance.approve(approval.id, "golden_operator", enqueue_fn: capture)
assert_received {:enqueued, _resume_job}
```
Then call `ApprovalResumeWorker.perform/1` directly. Same pattern applies to `Governance.request_approval/2`.

---

## Code Examples

### Stage 2: Inbox sees new conversation
```elixir
# Source: bulk_recovery_live_test.exs lines 75-78 + inbox_live.ex line 150
conn = Plug.Test.init_test_session(conn, %{"host_user_id" => "golden_operator"})
{:ok, inbox_view, html} = live(conn, "/inbox")
assert html =~ conversation.subject
```

### Stage 3: SearchModalComponent injection + search assertion
```elixir
# Source: search_modal_component.ex lines 21-22; CONTEXT.md D-03
{:ok, view, _html} = live(conn, "/governance/#{conversation.id}")

# Inject stub retrieval
send_update(Cairnloop.Web.SearchModalComponent,
  id: "search-modal",
  retrieval_module: StubRetrieval
)

# Open palette via phx-window-keydown toggle (key: "k" with meta)
# Simpler: use render_hook/3 or fire the "toggle_search" event directly
view
|> element("[phx-window-keydown='toggle_search']")
|> render_keydown(%{"key" => "k", "metaKey" => true})

# Fire search
view
|> element("[phx-target]")  # target is @myself (SearchModalComponent)
# Use render_component event via target:
# Alternative: use Phoenix.LiveViewTest.render_click with phx-target
```

Note: Firing events on LiveComponents with `phx-target={@myself}` requires using `element/2` with a selector that includes the component's `phx-target` attribute, or using the view-level `render_keydown`. The `toggle_search` event is on the root `div` with `phx-window-keydown="toggle_search"`, which fires on the component itself. See `render_keydown(view, "toggle_search", %{"key" => "k"})` for the keydown approach targeting the view.

### Stage 6: ToolExecutionWorker direct call
```elixir
# Source: tool_execution_outcome_live_test.exs lines 155-160
assert :ok =
  ToolExecutionWorker.perform(%Oban.Job{
    attempt: 1,
    max_attempts: 3,
    args: %{"approval_id" => approval.id}
  })

approval = Repo.get!(Cairnloop.Governance.ToolApproval, approval.id)
assert approval.status == :executed
```

### Stage 7: Resolve directly via Chat facade
```elixir
# Source: chat.ex line 222; no LiveView event exists
assert {:ok, _} = Chat.resolve_conversation(conversation.id, resolved_by: "golden_operator")
conversation = Chat.get_conversation!(conversation.id)
assert conversation.status == :resolved
```

### Stage 9: Bulk recovery via LiveView events
```elixir
# Source: bulk_recovery_live_test.exs lines 164-231
envelope_count_before = Repo.aggregate(BulkEnvelope, :count, :id)
{:ok, inbox_view, _html} = live(conn, "/inbox")

inbox_view
|> element(~s(input[phx-click="toggle_select"][phx-value-id="#{resolved_conversation.id}"]))
|> render_click()

inbox_view |> element(~s(button[phx-click="open_bulk_confirm"])) |> render_click()
inbox_view |> element(~s(button[phx-click="confirm_bulk_send"])) |> render_click()

assert Repo.aggregate(BulkEnvelope, :count, :id) == envelope_count_before + 1
```

---

## State of the Art

No new APIs introduced in Phase 31. All APIs were established in Phases 14–28.

| Component | Established In | Current State |
|-----------|---------------|---------------|
| `Phoenix.LiveViewTest` integration harness | Phase 15 | 9 passing integration tests |
| `ConnCase` with `async: false` sandbox sharing | Phase 15 | Documented pattern |
| `WidgetChannel` + `ProcessMessage` | Phase 28 | `Chat.ingest_widget_message/2` calls confirmed |
| `Outbound.bulk_trigger/2` | Phase 25 | Covered by `bulk_trigger_atomicity_test.exs` |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `subscribe_and_join/3` works without endpoint WebSocket mount when using `socket/3` helper directly | Pitfall 7 / Widget channel test | Test fails with socket connection error — would require adding WidgetSocket mount to test endpoint |
| A2 | `Chat.resolve_conversation/2` does NOT broadcast any PubSub message that ConversationLive handles | Pitfall 3 | If it does broadcast, stage 7 would auto-refresh ConversationLive and the remount step would be unnecessary |

All other claims in this document are [VERIFIED] via direct source code inspection.

---

## Open Questions

1. **ConversationLive cmd+k toggle event delivery**
   - What we know: `SearchModalComponent` handles `phx-window-keydown="toggle_search"` on its root div. `ConversationLive` does not have a `"toggle_search"` event handler.
   - What's unclear: Whether `render_keydown(view, "toggle_search", ...)` targeting the view-level will route to the LiveComponent's `handle_event`, or if it needs to target the component directly via `element/2`.
   - Recommendation: Use `render_keydown(view, "toggle_search", %{"key" => "k"})` first; if that fails, use `element("[phx-window-keydown='toggle_search']") |> render_keydown(...)` to target the component root.

2. **resolve_conversation broadcast behavior**
   - What we know: `Chat.resolve_conversation/2` does not show any PubSub broadcast call in the Chat module (only inserts Message + updates Conversation via Ecto.Multi).
   - What's unclear: Whether NotifyResolvedWorker or IndexResolvedConversation workers fire secondary broadcasts that ConversationLive listens to.
   - Recommendation: After calling `Chat.resolve_conversation/2` directly, remount `ConversationLive` to get a fresh render that reflects the `:resolved` status.

---

## Environment Availability

No new external dependencies. Existing integration harness (Postgres + pgvector + Endpoint + PubSub) is started by `test_helper.exs` when `integration? = true`.

| Dependency | Required By | Available | Fallback |
|------------|------------|-----------|---------|
| Cairnloop.Repo (Postgres + pgvector) | All DB assertions | ✓ (via mix test.integration) | None — tests are tagged :integration and excluded from `mix test` |
| Cairnloop.PubSub | InboxLive subscription, widget channel delivery | ✓ (started in test_helper.exs integration supervisor) | None |
| Cairnloop.Web.Endpoint | LiveView mount | ✓ (started in test_helper.exs integration supervisor) | None |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` |
| Quick run (headless) | `mix test` |
| Integration run | `mix test.integration` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| E2E-01 | Full JTBD round trip in single sequential test | integration | `mix test.integration test/integration/golden_path_test.exs` | ❌ Wave 0 |
| E2E-02 | Widget channel ingress → operator inbox delivery | integration | `mix test.integration test/integration/widget_channel_test.exs` | ❌ Wave 0 |
| E2E-03 | Both tests green under `mix test.integration`, no Wallaby/PhoenixTest | integration | `mix test.integration` | ❌ Wave 0 (implicitly satisfied by E2E-01 + E2E-02) |

### Wave 0 Gaps

- [ ] `test/integration/golden_path_test.exs` — covers E2E-01 (the entire file is the deliverable)
- [ ] `test/integration/widget_channel_test.exs` — covers E2E-02 (the entire file is the deliverable)

No framework install needed — existing test infrastructure covers all phase requirements.

---

## Security Domain

Phase 31 is test-only. No new production code paths. ASVS categories do not apply to test files.

The test files must NOT:
- Use `String.to_atom/1` on user-supplied data (test data is test-controlled; use `String.to_existing_atom/1` if converting JSONB keys, per CLAUDE.md arch posture).
- Hardcode hex color values in assertions (use bare `var(--cl-primary)` form per BRAND-04 gate — note: test files are in `test/` not `lib/`, so the BRAND-04 grep gate does not cover them, but the pattern should be consistent).

---

## Sources

### Primary (HIGH confidence — source code inspection)
- `lib/cairnloop/web/search_modal_component.ex` — `:retrieval_module` assign, `run_search/3`, event names
- `lib/cairnloop/channels/widget_channel.ex` — join/3 signature, `handle_in("new_message", ...)`, conversation_id flow
- `lib/cairnloop/channels/widget_socket.ex` — connect/3, token validation
- `lib/cairnloop/chat.ex` — `create_customer_conversation/1`, `ingest_widget_message/2`, `resolve_conversation/2` signatures and return shapes
- `lib/cairnloop/workers/process_message.ex` — `perform/1` arg shape `%{"channel", "conversation_id", "content"}`
- `lib/cairnloop/workers/approval_resume_worker.ex` — `perform/1` arg shape `%{"approval_id"}`
- `lib/cairnloop/workers/tool_execution_worker.ex` — `perform/1` full Oban.Job struct requirement
- `lib/cairnloop/outbound.ex` — `trigger/2`, `bulk_trigger/2` signatures
- `lib/cairnloop/retrieval/result.ex` — Result struct fields
- `lib/cairnloop/web/inbox_live.ex` — PubSub topic "conversations", `handle_info({:conversations_changed}, socket)`, event names
- `lib/cairnloop/web/conversation_live.ex` — all `handle_event` clauses (exhaustive), route is `/governance/:id`
- `test/support/conn_case.ex` — imports, session setup, `@endpoint`
- `test/support/data_case.ex` — `setup_sandbox` shared: true behavior
- `test/support/fixtures.ex` — all four fixture functions
- `test/support/endpoint.ex` — test endpoint does NOT mount WidgetSocket
- `test/support/router.ex` — ConversationLive at `/governance/:id`, InboxLive at `/inbox`
- `test/test_helper.exs` — integration supervisor, PubSub + Endpoint started when integration? = true
- `mix.exs` — `"test.integration"` alias definition
- `test/integration/approval_flow_test.exs` — enqueue_fn capture pattern, direct worker perform
- `test/integration/bulk_recovery_live_test.exs` — Plug.Test.init_test_session, full multi-step LiveViewTest sequence
- `test/integration/tool_execution_outcome_live_test.exs` — ConnCase + inline defmodule stubs + Oban.Job struct pattern

---

## Metadata

**Confidence breakdown:**
- API signatures: HIGH — verified from source code
- Event names: HIGH — exhaustive grep of handle_event clauses
- Test infrastructure: HIGH — source code inspection of ConnCase, DataCase, test_helper.exs
- StubRetrieval struct shape: HIGH — Retrieval.Result struct fields verified
- ChannelTest socket pattern: MEDIUM — Pitfall 7 assumption about bypassing endpoint mount is from training knowledge, not a running test

**Research date:** 2026-05-28
**Valid until:** Until source files listed in Sources section are modified
