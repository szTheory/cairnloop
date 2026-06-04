---
phase: 39-home-primacy-redesign-d1
reviewed: 2026-06-04T07:39:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - lib/cairnloop/chat.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/web/home_live.ex
  - priv/static/cairnloop.css
  - test/cairnloop/chat_test.exs
  - test/cairnloop/web/inbox_live_test.exs
  - test/cairnloop/web/home_live_test.exs
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 39: Code Review Report

**Reviewed:** 2026-06-04T07:39:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 39 restructured the operator Home into a two-tier primacy model and added a
status-scoped `Chat` read facade (`list_conversations/1`, `count_conversations/1`,
`scope_status/2`) plus an Inbox resolved-filter (`handle_params/3`,
`normalize_status/1`). The fail-closed `normalize_status/1` whitelist, the
filter-aware PubSub re-query, the bulk-selection `prune_selected_ids/2`
reconciliation, and the 500ms trailing-edge recount throttle are all implemented
correctly and well-tested.

However, the secondary-band count plumbing on the Cockpit Home contains a
**contract-mismatch BLOCKER**: the two band counts (`gaps_count`, `audit_count`)
pipe the bare-value `safe/2` helper into `split/1`, which only matches the
`{:ok, n}` tuple shape produced by `safe_count/1`. As written, both band counts
are **permanently `0` with `unavailable? = true`** on the live mount path —
including when real gaps/audit events exist. This directly inverts the
fail-closed-but-honest invariant (error ≠ calm-zero; and conversely
"available data must not be reported as unavailable"). It is untested because the
HomeLive suite only exercises `render/1` with pre-built assigns and never calls
`assign_counts/1`.

Secondary findings cover a missing `handle_info/2` catch-all in `InboxLive` (crash
risk on any non-`{:conversations_changed}` mailbox message), a redundant
double `connected?/1` evaluation, redundant inline `style` attributes that
duplicate class-provided styling (added only to satisfy literal-token grep
assertions), and a status-whitelist asymmetry between `normalize_status/1` and
`scope_status/2`.

## Critical Issues

### CR-01: Home band counts (`gaps`, `audit`) are always 0 + "Count unavailable" — `safe/2` bare value piped into `split/1` tuple-matcher

**File:** `lib/cairnloop/web/home_live.ex:79-85` (with `split/1` at `224-225`, `safe/2` at `228-234`)

**Issue:**
`assign_counts/1` computes the two band counts like this:

```elixir
{gaps_count, gaps_unavailable?} =
  safe(fn -> KnowledgeAutomation.list_gap_candidates() |> length() end, nil)
  |> split()

{audit_count, audit_unavailable?} =
  safe(fn -> Governance.list_action_events(limit: 100) |> length() end, nil)
  |> split()
```

But `safe/2` returns the **raw value** on success (e.g. the integer `3`) and the
bare `fallback` (`nil`) on error — it does NOT wrap in `{:ok, _}`:

```elixir
defp safe(fun, fallback) do
  fun.()            # returns 3, not {:ok, 3}
rescue
  _ -> fallback     # returns nil, not :error
...
```

`split/1`, however, only unwraps the `{:ok, integer}` shape emitted by
`safe_count/1`:

```elixir
def split({:ok, n}) when is_integer(n), do: {n, false}
def split(_), do: {0, true}   # <-- everything else, including a bare integer
```

So on the happy path `split(3)` falls through to `def split(_)` and returns
`{0, true}`. Result: **`gaps_count` and `audit_count` are always `0`, and
`gaps_unavailable?`/`audit_unavailable?` are always `true`**, regardless of the
actual gap/audit-event counts. The "Tend knowledge" and "Audit trail" tiles will
permanently render `0` with the "Count unavailable" meta line
(`gaps_meta(0, true) -> "Count unavailable"`, `audit_meta(true) -> "Count
unavailable"`), and `calm?` is forced false (`0 == 0 and not true -> false`), so
the calm "No open knowledge gaps" copy never appears either.

This is a regression introduced this phase: the pre-39 code (`fd5c558`) assigned
`gaps_count = safe(...)` directly, without `split/1`. Phase 39 added `split/1` for
the new D-06 unavailable signal but wired the bare-value `safe/2` source into the
tuple-only `split/1`. The open/resolved counts are correct because they use
`safe_count/1` (which DOES return `{:ok, n}`).

It is masked from the test suite: `home_live_test.exs` exercises only `render/1`
with hand-built assigns and never invokes `assign_counts/1`, so no test catches
the mis-wiring. This violates CLAUDE.md's fail-closed contract in the worse
direction — reporting *available* data as *unavailable*.

**Fix:** Make the band counts use the same `{:ok, _}` contract `split/1` expects.
Either route them through `safe_count/1`:

```elixir
{gaps_count, gaps_unavailable?} =
  safe_count(fn -> KnowledgeAutomation.list_gap_candidates() |> length() end)
  |> split()

{audit_count, audit_unavailable?} =
  safe_count(fn -> Governance.list_action_events(limit: 100) |> length() end)
  |> split()
```

(note `safe_count/1` ignores its non-existent fallback arg — drop the `nil`), or
add a `split/1` clause that accepts a bare integer:

```elixir
def split({:ok, n}) when is_integer(n), do: {n, false}
def split(n) when is_integer(n), do: {n, false}
def split(_), do: {0, true}
```

The first option is preferred (single contract). **Add a direct
`assign_counts/1` test** (or a connected-mount integration test) asserting that a
non-zero gaps/audit source yields `{n, false}`, not `{0, true}` — the current
suite cannot detect this class of regression.

## Warnings

### WR-01: `InboxLive` has no catch-all `handle_info/2` — any non-`{:conversations_changed}` mailbox message crashes the LiveView

**File:** `lib/cairnloop/web/inbox_live.ex:355-359`

**Issue:** `InboxLive.mount/3` subscribes the process to the `"conversations"`
PubSub topic, but the module defines exactly one `handle_info/2` clause
(`{:conversations_changed}`). There is no `def handle_info(_msg, socket), do:
{:noreply, socket}` fallback. Any other message delivered to the LiveView process
mailbox — a future/peer broadcast on `"conversations"`, a stray `:DOWN`/monitor
message, a late reply, or anything a library sends to `self()` — will raise
`FunctionClauseError` and crash (and reconnect-loop) the operator's inbox.
`HomeLive` correctly guards against exactly this with its catch-all at
`home_live.ex:66`; `InboxLive` is asymmetric and unprotected. Today the
`"conversations"` topic only carries `{:conversations_changed}`, so it may not fire
in practice, but it is a latent robustness defect that the matching `HomeLive`
code already treats as required.

**Fix:** Add a trailing catch-all clause mirroring `HomeLive`:

```elixir
def handle_info(_msg, socket), do: {:noreply, socket}
```

### WR-02: `connected?/1` evaluated twice per `{:conversations_changed}` in `HomeLive`

**File:** `lib/cairnloop/web/home_live.ex:55-58`

**Issue:** The non-coalesced branch calls `connected?(socket)` twice — once to
decide whether to arm the timer (line 55) and again to set the
`pending_recount?` flag (line 58). Beyond the redundant call, it is a subtle
correctness coupling: the flag is intentionally tied to "did we actually arm a
timer," but expressing that as two independent `connected?/1` calls invites drift
if one side is later edited. Capture once so the armed-timer decision and the flag
can never disagree.

**Fix:**

```elixir
else
  armed? = connected?(socket)
  if armed?, do: Process.send_after(self(), :recount, @recount_ms)
  {:noreply, assign(socket, :pending_recount?, armed?)}
end
```

### WR-03: Redundant inline `style` attributes duplicate class-provided styling (test-driven markup)

**File:** `lib/cairnloop/web/inbox_live.ex:236` and `:267`

**Issue:** Two render sites carry inline `style` attributes that re-state styling
already provided by their component classes:

- Line 236: `<.cl_button variant="primary" ... style="background: var(--cl-primary);">`
  — `.cl-button--primary` already sets `background: var(--cl-primary)`
  (`cairnloop.css:312-314`).
- Line 267: `<.cl_banner variant="danger" ... style="border-color: var(--cl-danger);">`
  — `.cl-banner--danger` already sets `border-color: var(--cl-danger-border)`
  (`cairnloop.css:369`).

The inline styles exist only because tests/integration assert the literal
`var(--cl-primary)` / `var(--cl-danger)` token string appears in the rendered
HTML (see the inline comments at 234-235 and 265-266). This couples markup to a
brittle "token appears as a literal in the DOM" assertion and partially defeats
the "components carry semantic classes; visual truth lives in cairnloop.css"
posture stated in `components.ex:16-23`. It is gate-clean (the BRAND-04 gate only
flags `var(--cl-token, #hex)` hex fallbacks, not bare tokens), so it is not a
BLOCKER — but it is drift that future component edits to `.cl-button--primary` /
`.cl-banner--danger` will silently fail to reflect.

**Fix:** Drop the inline `style` attributes and re-target the assertions at the
semantic classes the component already renders, e.g. assert
`html =~ "cl-button--primary"` and `html =~ "cl-banner--danger"` instead of the
raw token strings. If a token must be asserted at the DOM level, prefer a single
shared test against `cairnloop.css` rather than per-call-site inline styles.

### WR-04: `normalize_status/1` (web) and `scope_status/2` (facade) whitelists are inconsistent — `:open`/`:archived` are dead paths

**File:** `lib/cairnloop/web/inbox_live.ex:141-142` vs `lib/cairnloop/chat.ex:43-46`

**Issue:** `scope_status/2` accepts `:open`, `:resolved`, and `:archived` as
scopable statuses, and `count_conversations/1` is called with `status: :open` from
`HomeLive.assign_counts/1`. But the Inbox URL normalizer `normalize_status/1`
whitelists **only** `"resolved"` → `:resolved`; `"open"` and any other value map
to `nil` (unfiltered). The result is that the `:open` and `:archived` branches of
`scope_status/2` are reachable only from `HomeLive`'s hard-coded
`status: :open` count call — never from any operator-navigable Inbox URL. This is
intentional for the current UI-SPEC (Inbox only filters resolved), and the
fail-closed direction is correct (unknown → unfiltered, never crash), so it is not
a bug. But the divergence is undocumented at the call boundary and a future
"Open" filter chip would silently no-op because the normalizer drops it. Flagging
so the asymmetry is a deliberate, recorded decision rather than a latent trap.

**Fix:** Add an inline note at `normalize_status/1` that the web whitelist is
intentionally narrower than the facade whitelist (UI exposes resolved-only), and
either add `def normalize_status("open"), do: :open` when the Open filter ships or
keep a test asserting `"open" -> nil` is intentional (the latter exists at
`inbox_live_test.exs:1018`, so primarily this is a documentation fix).

## Info

### IN-01: `cl_banner` already emits `role="status"`; nesting it inside `role="dialog"` adds a redundant live-region

**File:** `lib/cairnloop/web/inbox_live.ex:267` (banner) inside `:244-251` (dialog)

**Issue:** The refusal banner uses `<.cl_banner variant="danger">`, and `cl_banner`
hard-codes `role="status"` (`components.ex:100`). It renders inside the
`role="dialog" aria-modal="true"` container. A polite `status` live-region inside a
modal dialog is harmless but redundant; the dialog's own labelling
(`aria-labelledby="bulk-confirm-title"`) already announces the refusal heading.
Not a defect, just minor ARIA noise.

**Fix:** Optional — consider a non-live container for in-dialog refusal copy, or
leave as-is.

### IN-02: `bulk_refusal` carries an unused `:count` field

**File:** `lib/cairnloop/web/inbox_live.ex:413`

**Issue:** `open_bulk_confirm` builds `bulk_refusal: %{count: count, max: cap}`, but
the render path only reads `@bulk_refusal.max` (line 277). The `:count` field is
never displayed. Dead data — harmless but suggests the refusal copy once showed
the attempted count.

**Fix:** Drop `:count` from the map, or surface it in the refusal copy
(e.g. "You selected N; the safe limit is M.") if that was the intent.

### IN-03: `count_conversations/1` default-arg vs `list_conversations/1` arity asymmetry

**File:** `lib/cairnloop/chat.ex:20-33`

**Issue:** `list_conversations/1` is a separate arity guarded by
`when is_list(opts)` (preserving the sealed 0-arity clause), while
`count_conversations/1` uses a default arg `opts \\ []`. Both are correct, but the
inconsistent style for two sibling status-scoped readers is a minor readability
snag — a reader expecting symmetry may wonder whether `count_conversations/0`
behaves differently. The test at `chat_test.exs:436` confirms `/0` works.

**Fix:** Optional — none required; cosmetic consistency only.

---

_Reviewed: 2026-06-04T07:39:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
