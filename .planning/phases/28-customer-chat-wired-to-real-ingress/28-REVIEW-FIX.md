---
phase: 28-customer-chat-wired-to-real-ingress
fixed_at: 2026-05-27T18:32:30Z
review_path: .planning/phases/28-customer-chat-wired-to-real-ingress/28-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

**Fixed at:** 2026-05-27T18:32:30Z
**Source review:** .planning/phases/28-customer-chat-wired-to-real-ingress/28-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: `String.to_existing_atom/1` raises unhandled `ArgumentError` in `ChatLive`

**Files modified:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`
**Commit:** e503a4c
**Applied fix:** Replaced `String.to_existing_atom(status)` with a closed `case` over `"connecting"`, `"connected"`, `"disconnected"`. Unknown strings fall through to `_ -> socket.assigns.channel_status` (preserve current state) instead of crashing. Also updated the stale JS comment in the same file that referenced `String.to_existing_atom/1`.

---

### CR-02: Deferred `submit_csat` clause crashes on `widget:lobby`

**Files modified:** `lib/cairnloop/channels/widget_channel.ex`, `test/cairnloop/channels/widget_channel_test.exs`
**Commit:** 6baae9b (channel fix), 8ba90cb (test update)
**Applied fix:** Replaced the crash-path `handle_in("submit_csat", %{"rating" => rating}, socket)` clause (which destructured `socket.topic` and called `Chat.submit_csat("lobby", rating)` → `Ecto.Query.CastError`) with a single catch-all clause that returns `{:reply, {:error, %{reason: "csat_not_available"}}, socket}`. Two existing tests that expected the old CSAT behavior were updated to assert the new `csat_not_available` error reply (both lobby and conversation-scoped topics).

---

### WR-01: `Oban.insert/1` result silently discarded in `WidgetChannel.handle_in/3`

**Files modified:** `lib/cairnloop/channels/widget_channel.ex`
**Commit:** 2f94e59
**Applied fix:** Replaced the fire-and-forget `Oban.insert()` call followed by unconditional `{:reply, :ok, socket}` with a `case` that matches on `{:ok, _job}` (returns `:ok` reply) and `{:error, _changeset}` (returns `{:error, %{reason: "could_not_queue_message"}}` reply). Failures are now surfaced to the client instead of silently dropped.

---

### WR-02: `ProcessMessage` returns `:error` (retryable) for permanent changeset failures

**Files modified:** `lib/cairnloop/workers/process_message.ex`
**Commit:** 8666422
**Applied fix:** Changed the `{:error, _changeset} -> :error` arm to `{:error, changeset} -> {:cancel, "changeset error: #{inspect(changeset.errors)}"}`. Ecto changeset failures are deterministic and will not succeed on retry; `{:cancel, reason}` marks the Oban job as permanently cancelled without exhausting the 20-retry budget.

---

### WR-03: Optimistic customer message not removed from `@messages` on `send_error`

**Files modified:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`
**Commit:** cf71ab9
**Applied fix:** Expanded `handle_event("send_error", ...)` to drop the last element from `socket.assigns.messages` (the failed optimistic entry), assign `:pending` back to `false`, and set `:send_error` to `true`. Previously only `send_error: true` was set, leaving the ghost message and pending indicator stuck in the UI.

---

### WR-04: `connection_label/1` and `connection_dot_color/1` lack a catch-all clause

**Files modified:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`
**Commit:** 8c242cd
**Applied fix:** Added `defp connection_label(_), do: "Unknown"` and `defp connection_dot_color(_), do: "var(--cl-text-muted, #677066)"` catch-all clauses after the three existing clauses. Prevents `FunctionClauseError` if `@channel_status` ever holds an unexpected atom.

---

## Compile and Test Results

**`mix compile --warnings-as-errors`:** Clean (exit 0, no new warnings introduced).

**`mix test`:** 697 tests, 1 failure (47 excluded). The single failure is the pre-existing `Cairnloop.Automation.DraftTest` baseline failure (M005 schema drift, documented in project CLAUDE.md and user memory as a known pre-existing regression — not caused by these fixes).

---

_Fixed: 2026-05-27T18:32:30Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
