# Phase 14: Operator Timeline & Preview Surface - Research

**Researched:** 2026-05-24
**Domain:** Phoenix LiveView display surface over Ecto-backed governed-action records
**Confidence:** HIGH — all seams confirmed against live source files

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
D-01 through D-27 as documented in 14-CONTEXT.md. Summarised here for planner use; the full
text is authoritative.

- **D-01** Rail placement — governed-action timeline is a new right-rail section, sibling to
  `quick_fix_card/1` and `draft_audit_card/1`. Not inline in the message thread.
- **D-02** Plain-assign list-comprehension rendering. No `Phoenix.LiveView.stream/3`.
- **D-03** Function components, not LiveComponents.
- **D-04** Rename Execute → Propose in `tool_renderer/1`; replace hardcoded `#2563eb` with brand
  token.
- **D-05** Phase 14 card is read-only. Footer action slot reserved for Phase 15.
- **D-06** Migration: nullable `conversation_id` FK on `cairnloop_tool_proposals`
  (`references(:cairnloop_conversations, on_delete: :nilify_all)`); index on
  `[conversation_id, inserted_at]`.
- **D-07** Thread `conversation_id` into `handle_event("execute_tool")` → `Governance.propose/3`
  writes it on both valid and blocked paths.
- **D-08** `conversation_id` MUST be excluded from the idempotency-key canonical map in
  `derive_idempotency_key/4`.
- **D-09** Add `Governance.list_proposals_for_conversation/1`; load in
  `reload_conversation_with_context/2`; `assign(governed_actions: ...)`.
- **D-10** Four operator state groups: Awaiting / Blocked / Active / Done. Active and Done are
  empty in Phase 14 but declared now.
- **D-11** Status chip labels: `:proposed` → "Proposed" (Awaiting), `:needs_input` → "Needs
  input" (Awaiting), `:scope_invalid` → "Not available here" (Blocked), `:policy_denied` →
  "Blocked by policy" (Blocked).
- **D-12** `:proposed` label is "Proposed" not "Pending approval". Approval gate surfaced as
  future-tense sub-line from `approval_mode`. Phase 15 moves to `pending_approval`.
- **D-13** Status, `risk_tier`, `approval_mode` are separate display axes. Never fuse into one
  badge.
- **D-14** Replace `inspect(reason)` in `failure_reason_message/1` with `reason_label/1` mapping
  + humanize fallback.
- **D-15** Hybrid preview: trust fields from snapshot; prose live-best-effort from `preview/1`
  and live `Spec.title`. TRUST-SENSITIVE — user may veto before planning.
- **D-16** Phase 15/16 promotion path: snapshot consequence string + title additively (no
  schema change needed in Phase 14).
- **D-17** Structured-summary fallback is the COMMON path (no tool implements `preview/1` yet).
- **D-18** One total `Preview.render(proposal)` function — hides all footgun branching.
- **D-19** Rehydration footguns: JSONB atom→string key round-trip; guard atom conversion;
  `struct/2` silent-drop; unregistered tool; `Code.ensure_loaded?` + `function_exported?` guard;
  `try/rescue` wrapper.
- **D-20** Evidence = provenance, not retrieval grounding. Do not reuse `SearchResultPresenter`
  source-card list.
- **D-21** Card surfaces: headline, input snapshot (humanized), event audit trail, scope
  snapshot, policy snapshot, trace metadata.
- **D-22** Inline = humanized. Raw JSON only behind expander. `input_rows/1` is the masking
  choke point.
- **D-23** Telemetry is never a UI source. Timeline reads `list_events/1` only.
- **D-24** Add `history_line/1` catch-all clause now for forward-compat.
- **D-25** `ToolProposalPresenter` mirrors `ReviewTaskPresenter` exactly.
- **D-26** Cairnloop-owned, narrow facade, calm fail-closed copy.
- **D-27** Ordinary implementation choices deferred to planning/execution.

### Claude's Discretion
Exact module/function/CSS names, label/copy wording, card markup, expander mechanism,
ordering tie-breaks, empty-state copy, Phase-15 footer action slot placement — planner
discretion as long as D-01..D-26 shapes and trust boundaries hold.

### Deferred Ideas (OUT OF SCOPE)
- FLOW-03 (reject/defer with persisted reason) — Phase 15
- Approval state machine, Oban resume — Phase 15
- Snapshotting consequence string at propose time — Phase 15/16
- Execution + results rendering — Phase 16
- `Phoenix.LiveView.stream/3` for timeline — Phase 16
- OBS-02 policy-version attribution — Phase 16/17
- Scoria/OpenInference evidence-hook / MCP seam — Phase 17
- Standalone cross-conversation audit-log page — out of scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FLOW-01 | Operator can inspect governed action proposals and outcomes inside the existing conversation workflow as a durable timeline. | Confirmed: `list_proposals_for_conversation/1` (new) → `reload_conversation_with_context` → `governed_action_card/1` in rail (D-09/D-01). All four Phase-13 statuses are durable Ecto rows. |
| FLOW-02 | Operator sees a human-readable preview card for each risky action, including risk label, actor scope, target, consequence summary, and evidence links. | Confirmed: snapshot fields exist on `ToolProposal` (risk_tier, approval_mode, input_snapshot, scope_snapshot, policy_snapshot); `preview/1` is an optional callback in `Cairnloop.Tool`; `ToolProposalPresenter` pattern mirrors `ReviewTaskPresenter`; structured-summary fallback is the common path (D-17). |
</phase_requirements>

---

## Summary

Phase 14 adds a read-only display surface over the durable `ToolProposal` +
`ToolActionEvent` records created in Phase 13. The surface is a new section in the
right-rail of `ConversationLive`, rendered by a plain-assign list-comprehension fed by a
new `Governance.list_proposals_for_conversation/1` facade helper. Each card is a function
component matching the idiom of the existing `quick_fix_card/1` and `draft_audit_card/1`
rail cards.

One small data change is required: a nullable `conversation_id` FK on
`cairnloop_tool_proposals`, following the exact `Draft`/`Conversation` precedent already
in the repo. A new presenter module (`ToolProposalPresenter`) mirrors `ReviewTaskPresenter`
exactly and serves as the single humanization + masking point for all operator-facing copy.
A total `Preview.render/1` function hides the live-vs-fallback branching so the LiveView
never branches on footgun internals.

The structured-summary fallback (built entirely from the propose-time snapshot) is the
COMMON path in Phase 14 because no tool implements the optional `preview/1` callback yet.
Tests must be designed around this reality. The JSONB atom→string key round-trip footgun
(D-19) only surfaces with a real Postgres round-trip; all presenter-level and
`Preview.render/1` tests can run headless against MockRepo-style struct fixtures.

**Primary recommendation:** Implement exactly as locked in D-01..D-26. The riskiest
implementation step is `Preview.render/1`'s live-leg guard stack (D-19); build and test
that in isolation before wiring it into the LiveView.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Conversation-scoped proposal query | Database / Ecto | Governance facade | `list_proposals_for_conversation/1` is a read query; facade owns the API |
| Conversation-scoping FK + migration | Database / Ecto | — | `conversation_id` on `cairnloop_tool_proposals` |
| PubSub → reload → assign | Frontend Server (LiveView process) | — | Existing thin-notification→full-reload pattern |
| governed_action_card rendering | Frontend Server (LiveView render) | — | Function component in `ConversationLive`, stateless render of assigns |
| Preview live leg (Spec.title + preview/1) | API / Governance | Frontend Server (consumer) | `Preview.render/1` lives in `Cairnloop.Governance.Preview` or presenter; LiveView consumes result |
| Humanization / masking | Presenter layer | — | `ToolProposalPresenter` pure module; tone atoms returned, LiveView maps to brand colors |
| Execute → Propose rename + brand token | Frontend Server (LiveView render) | — | `tool_renderer/1` function component inline change |
| failure_reason_message replacement | Frontend Server (LiveView helpers) | Presenter | `reason_label/1` mapping lives in presenter; LiveView delegates |

---

## Code Seam Verification

All seams named in CONTEXT.md were verified against the live source files. Findings follow.

### `lib/cairnloop/web/conversation_live.ex`

**`handle_event("execute_tool", ...)`** — confirmed at L173. Current shape:

```elixir
def handle_event("execute_tool", %{"tool" => tool_ref} = params, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  context = socket.assigns.host_context
  context = Map.put(context, :tool_params, params["tool_params"] || %{})

  case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
    {:ok, proposal} ->
      {:noreply, put_flash(socket, :info, "Proposed — pending review. (##{proposal.id})")}
    {:blocked, outcome, reason} ->
      {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}
  end
end
```

**D-07 insertion point confirmed:** `conversation_id` is NOT yet threaded in. The implementation must add:
```elixir
context = Map.put(context, :conversation_id, socket.assigns.conversation.id)
```
before calling `propose/3`. The conversation id is available as
`socket.assigns.conversation.id`.

**`failure_reason_message/1`** — confirmed at L188-198. Four clauses exist:
- `:unsupported, _` → "Unknown tool — proposal rejected."
- `:needs_input, _cs` → "Invalid tool parameters."
- `:scope_invalid, reason` → `"Tool not available in this context: #{inspect(reason)}."` ← **uses `inspect`** (D-14 violation to fix)
- `:policy_denied, reason` → `"Tool call not permitted: #{inspect(reason)}."` ← **uses `inspect`** (D-14 violation to fix)
- catch-all → `"Tool proposal blocked (#{outcome}): #{inspect(reason)}."` ← **uses `inspect`**

All three `inspect(reason)` usages must be replaced with `ToolProposalPresenter.reason_label(reason)` or equivalent.

**`reload_conversation_with_context/2`** — confirmed at L200. Currently assigns: `conversation`, `host_context`, `context_error`, `quick_fix_card`. `governed_actions` is NOT yet assigned. The implementation must extend this function to call `Governance.list_proposals_for_conversation/1` and add `governed_actions:` to the assign call.

**`context_pane/1`** — confirmed at L415. Contains the "Actions" subsection with `tool_renderer/1`. Correct location for the Execute→Propose rename.

**`tool_renderer/1`** — confirmed at L503. The hardcoded `#2563eb` button color is at L540:
```elixir
<button type="submit" style="padding: 6px 12px; background: #2563eb; color: white; ...">Execute</button>
```
Two changes required: `#2563eb` → brand token (the brand primary is `var(--cl-primary, #A94F30)` as visible in `search_modal_component.ex` L196), and button text `"Execute"` → `"Propose"`. The zero-field case at L521 also renders a button with `phx-click="execute_tool"` and no hardcoded color, but its button text is the tool name via `humanize_context_label`, not "Execute" — no text change needed there.

**`quick_fix_card/1`** — confirmed at L457. Is the idiom to mirror: `rail-card` CSS class, eyebrow, h3 heading, summary paragraph, layers/status-rail, action buttons.

**`draft_audit_card/1`** — confirmed at L582. Has action buttons (approve/edit/discard) — the governed action card must NOT have these in Phase 14 (D-05).

**Message-timeline list-comprehension** — confirmed at L381:
```elixir
<%= for msg <- @conversation.messages do %>
```

**Drafts list-comprehension** — confirmed at L401-408:
```elixir
<%= if Ecto.assoc_loaded?(@conversation.drafts) and length(@conversation.drafts) > 0 do %>
  <%= for draft <- @conversation.drafts do %>
    <.draft_audit_card ... />
  <% end %>
<% end %>
```
The `governed_action_card` rail section uses the same pattern.

**Humanize helpers confirmed:**
- `context_section/1` — L552
- `context_field/1` — L569 (accepts `hide_label` assign, defaults to `false`)
- `humanize_context_label/1` — L670 (splits on `_`, capitalizes each word)
- `normalize_context_value/1` — L679-691 (binary/number/boolean/flat-list passthrough; "Unsupported value" fallback for tuples, PIDs, nested maps, functions)

**JSONB round-trip pattern in this file (in-repo precedent for D-19):** L747-753:
```elixir
defp to_result(%{} = evidence) do
  evidence
  |> Enum.into(%{}, fn
    {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
    pair -> pair
  end)
  |> then(&struct(Result, &1))
rescue
  ArgumentError -> struct(Result, %{})
end
```
This is EXACTLY the pattern D-19 mandates for `Preview.render/1`'s rehydration leg.

### `lib/cairnloop/governance.ex`

**`propose/3`** — confirmed at L177. Does NOT currently write `conversation_id`. `insert_new_proposal/5` at L214 and `insert_blocked_proposal/10` at L303 must both receive and persist `conversation_id`.

**`insert_new_proposal/5`** — the `proposal_attrs` map at L215-227 does NOT include `conversation_id`. Must be added.

**`insert_blocked_proposal/10`** — the `proposal_attrs` map at L309-319 does NOT include `conversation_id`. Must be added.

**`derive_idempotency_key/4`** — confirmed at L105. Current canonical map includes `tool_ref`, `actor_id`, `account_id`, `input`, `dedupe_token`. Does NOT include `conversation_id`. D-08 is already satisfied by the current implementation — confirm that when `conversation_id` is added to `propose_valid/4` and `propose_blocked/5` call sites, it is NOT added to `derive_idempotency_key/4`'s canonical map.

**`get_proposal/1`** — confirmed at L370.

**`list_events/1`** — confirmed at L375. Returns events ordered `asc: inserted_at`. The new `list_proposals_for_conversation/1` must order `desc: inserted_at` (newest first in the rail) and preload events `asc: inserted_at`.

### `lib/cairnloop/governance/tool_proposal.ex`

**Schema name:** `"cairnloop_tool_proposals"` — confirmed at L26. The migration must use this exact table name for the FK reference.

**`conversation_id` field:** NOT present. Must be added via migration + `belongs_to(:conversation, Cairnloop.Conversation)` + `has_many(:tool_proposals)` on `Cairnloop.Conversation`.

**Status enum values:** `[:proposed, :needs_input, :scope_invalid, :policy_denied]` — confirmed at L21. `@status_values` is exported via `status_values/0`. These four values map to D-11's chip labels.

**Snapshot fields confirmed:** `:input_snapshot` (`:map`, default `%{}`), `:scope_snapshot` (`:map`, default `%{}`), `:policy_snapshot` (`:map`, default `%{}`).

**Phase 16 reserved columns confirmed** (unused in Phase 14): `attempt`, `oban_job_id`, `result_state`, `result_summary`.

**`has_many(:events, ToolActionEvent)`** — confirmed at L47. The preload in `list_proposals_for_conversation/1` can use this association name directly.

### `lib/cairnloop/governance/tool_action_event.ex`

**Confirmed append-only:** `timestamps(type: :utc_datetime_usec, updated_at: false)` at L36.

**Event types:** `[:proposal_created, :proposal_blocked]` — confirmed at L23. Must add a catch-all `history_line/1` clause in `ToolProposalPresenter` that returns `"Workflow updated"` for any unrecognised event type (D-24), exactly as `ReviewTaskPresenter.history_line/1` does at L130.

**Fields confirmed for card display:** `event_type`, `from_status`, `to_status`, `actor_id`, `reason`, `metadata`, `inserted_at`.

### `lib/cairnloop/governance/policy.ex`

**`policy_snapshot` shape** (written by `propose_blocked/5` at L318-319):
```elixir
%{outcome: outcome, reason: reason_str}
```
where `reason_str = inspect(reason)` — **this is raw `inspect` output stored in the snapshot**. The card's policy explanation sentence must humanize this: the `policy_snapshot` has `outcome` (an atom key after Ecto reload — but see D-19 JSONB footgun below) and `reason` (a string).

For the valid path (written by `build_validated_attrs/4` at L86-100):
```elixir
%{
  resolution_source: :phase_13_policy_resolve,
  declared_approval_mode: spec.approval_mode,
  resolved_approval_mode: approval_mode
}
```
These are atom-keyed in memory; string-keyed after JSONB round-trip.

**D-19 JSONB footgun applies to `policy_snapshot`:** After a Postgres round-trip, `policy_snapshot["outcome"]` (string key) not `:outcome` (atom key). The card must handle both, using the `Map.get(map, key) || Map.get(map, Atom.to_string(key))` idiom already present in `ReviewTaskPresenter.metadata_value/2` at L162-165.

### `lib/cairnloop/tool.ex`

**`preview/1` optional callback** — confirmed at L72-73:
```elixir
@callback preview(tool :: struct()) :: String.t()
@optional_callbacks [preview: 1, custom_ui: 0]
```
No default implementation is injected by the `__using__` macro. Confirmed: no tool in the codebase implements `preview/1` yet (D-17 — structured summary is the common path).

**`__tool_spec__/0`** — confirmed at L112. Returns `@__tool_spec__` which is a `%Cairnloop.Tool.Spec{}` with `:title` and `:description` fields (may be nil if not declared). The live title fallback chain in D-17 is: `spec.title` (non-nil) → humanized `tool_ref` (never "Elixir.Cairnloop.Tools.X" — use the `humanize_context_label(last_module_part(tool_module))` idiom from `tool_renderer/1` at L521-523).

### `lib/cairnloop/tool_registry.ex`

**`find_tool_module/1`** — confirmed at L58. Returns `{:ok, module}` or `{:error, :unknown_tool}`. Uses `Atom.to_string/1` (not `String.to_existing_atom/1`) — safe. The `Preview.render/1` rehydration leg calls this; on `{:error, :unknown_tool}` it must fall back to the structured summary (D-19).

**`get_available_tools/2`** — confirmed at L42. Advisory filter used in `context_pane/1`. Already present.

### Presenter modules

**`ReviewTaskPresenter`** — confirmed. Key patterns to mirror in `ToolProposalPresenter`:
- `status_label/1` — pattern-match on atom, return human string
- `history_line/1` — pattern-match on event struct, catch-all returns `"Workflow updated"` (L130)
- `reason_label/1` — `Atom.to_string |> String.replace("_", " ")` (L133-138)
- `metadata_value/2` — dual-key lookup: `Map.get(map, key) || Map.get(map, Atom.to_string(key))` (L162-165) — the JSONB round-trip defence

**`SearchResultPresenter`** — confirmed. `recency_label/1` and `relative_time/1` are the timestamp humanization helpers. The `relative_time/1` private function at L184 handles `NaiveDateTime`, `DateTime`, and `nil`. `ToolProposalPresenter.event_timestamp_label/1` should replicate or delegate to this logic.

**`GapCandidatePresenter`** — confirmed. `@reason_labels` map + `humanize_atom/1` fallback at L75-79:
```elixir
defp humanize_atom(value) when is_atom(value) do
  value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
end
```
`reason_label/1` for `ToolProposalPresenter` uses the same pattern.

**`SearchModalComponent`** badge/chip idiom — confirmed at L131-136. `source_badge_style/1` and `trust_badge_style/1` are private functions returning inline style strings. The governed-action card's risk and status chips should use the same design language. Key: chips pair a badge span with a text label — never color-alone (D-13/brand §7.5).

The actual badge style functions (confirmed in the file, ~L300+ area) return inline `style=` strings with background, border-radius, padding, font-weight. The `--cl-primary` CSS variable (`#A94F30`) is the brand primary used for canonical/active states; amber tones for warning; danger red for errors.

### Migration

**Phase 13 governance migration:** `20260524000000_add_tool_proposals_and_action_events.exs`.

**Migration style confirmed:**
- Uses `:string` type (not PostgreSQL `ENUM` type) for status/risk_tier/approval_mode — compatible with Ecto.Enum
- FK declared as `references(:table, on_delete: :delete_all)` for events
- Indexes with `create(index(...))` and `create(unique_index(...))`
- Timestamps `type: :utc_datetime_usec`
- Events table uses `timestamps(updated_at: false)` for append-only invariant

**D-06 migration exact form:**
```elixir
alter table(:cairnloop_tool_proposals) do
  add(:conversation_id,
    references(:cairnloop_conversations, on_delete: :nilify_all),
    null: true)
end

create(index(:cairnloop_tool_proposals, [:conversation_id, :inserted_at]))
```

**`references(:cairnloop_conversations, ...)` confirmed correct:** `Cairnloop.Conversation` schema uses table `"cairnloop_conversations"` (L5 of conversation.ex).

**Precedent for `nilify_all`:** Confirmed in `20260522093000_add_review_tasks_and_events.exs` at L18-20: `references(:cairnloop_articles, on_delete: :nilify_all)` for optional FK columns. The `:delete_all` variant is used for required parent-child FKs (events→proposals). `nilify_all` is correct for the conversation→proposal link (proposal outlives conversation per D-06).

### `lib/cairnloop/automation/draft.ex` and `lib/cairnloop/conversation.ex`

**`belongs_to(:conversation, Cairnloop.Conversation)`** — confirmed in `Draft` at L24. This is the exact association to clone on `ToolProposal`.

**`has_many(:drafts, Cairnloop.Automation.Draft)`** — confirmed in `Conversation` at L15. The parallel `has_many(:tool_proposals, Cairnloop.Governance.ToolProposal)` belongs on `Conversation`.

**`validate_required(:conversation_id)`** in Draft's changeset at L43 — this is the required FK pattern. `ToolProposal`'s `conversation_id` is nullable (not required), so no `validate_required` addition is needed for it.

**Chat.get_conversation!/1` preload** — confirmed at L17-22. Drafts are preloaded here. `tool_proposals` should NOT be preloaded here (preload would be unbounded across all conversations); instead `list_proposals_for_conversation/1` is called in `reload_conversation_with_context/2` separately.

---

## Standard Stack

This phase introduces no new dependencies. All libraries are already present.

### Core (existing)
| Library | Purpose | Used By |
|---------|---------|---------|
| Phoenix LiveView | Function components, assign, render | `ConversationLive` |
| Ecto | Schema extension, migration, query | `ToolProposal`, `Governance` |
| ExUnit | Test framework | All tests |

### New modules introduced by Phase 14
| Module | Purpose |
|--------|---------|
| `Cairnloop.Web.ToolProposalPresenter` | Pure humanization, no markup, total functions |
| `Cairnloop.Governance.Preview` (or nested in presenter) | Total `render/1` hiding live-vs-fallback logic |
| New migration `~_add_conversation_id_to_tool_proposals.exs` | `conversation_id` nullable FK + index |

**Installation:** No new packages required.

---

## Package Legitimacy Audit

> Not applicable — Phase 14 installs no external packages.

---

## Architecture Patterns

### System Architecture Diagram

```
ConversationLive.mount / handle_info
         |
         v
reload_conversation_with_context/2
   |                        |
   v                        v
Chat.get_conversation!    Governance.list_proposals_for_conversation/1
   (messages, drafts)       (proposals + preloaded events, desc inserted_at)
         |
         v
  assign(socket, governed_actions: [...])
         |
         v
  render/1
    |         |         |
    v         v         v
context_pane  quick_fix  for proposal <- @governed_actions
"Actions"     _card/1       governed_action_card/1
tool_renderer/1               |
"Propose" btn       ToolProposalPresenter.*
                    Preview.render(proposal)
                        |              |
                     {:preview, str}  {:structured, assigns}
                     (live leg —      (common path in Phase 14)
                      rare; no tool   built from snapshot only
                      has preview/1)
```

### Recommended Project Structure
```
lib/cairnloop/
├── governance.ex                              (extend: list_proposals_for_conversation/1)
├── governance/
│   ├── tool_proposal.ex                       (extend: add conversation_id + belongs_to)
│   ├── tool_action_event.ex                   (no change)
│   └── preview.ex  (new)                      (or fold into presenter)
├── conversation.ex                            (extend: add has_many :tool_proposals)
└── web/
    ├── conversation_live.ex                   (extend: 4 touch points — see below)
    └── tool_proposal_presenter.ex  (new)

priv/repo/migrations/
└── YYYYMMDDHHMMSS_add_conversation_id_to_tool_proposals.exs  (new)

test/
├── cairnloop/governance/
│   └── preview_test.exs  (new)
├── cairnloop/web/
│   ├── tool_proposal_presenter_test.exs  (new)
│   └── conversation_live_test.exs  (extend)
```

### Pattern 1: Presenter module (mirror ReviewTaskPresenter exactly)

```elixir
# Source: lib/cairnloop/web/review_task_presenter.ex (confirmed)
defmodule Cairnloop.Web.ToolProposalPresenter do
  alias Cairnloop.Governance.{ToolProposal, ToolActionEvent}

  # Total functions — pattern-match on struct, return string/atom, never markup
  def status_label(%ToolProposal{status: status}), do: status_label(status)
  def status_label(:proposed), do: "Proposed"
  def status_label(:needs_input), do: "Needs input"
  def status_label(:scope_invalid), do: "Not available here"
  def status_label(:policy_denied), do: "Blocked by policy"

  def status_group(:proposed), do: :awaiting
  def status_group(:needs_input), do: :awaiting
  def status_group(:scope_invalid), do: :blocked
  def status_group(:policy_denied), do: :blocked

  # history_line/1 with forward-compat catch-all (D-24)
  def history_line(%ToolActionEvent{event_type: :proposal_created, actor_id: actor_id}) do
    "Proposed by #{actor_id}"
  end
  def history_line(%ToolActionEvent{event_type: :proposal_blocked, actor_id: actor_id, reason: reason}) do
    ["Blocked", actor_id && "by #{actor_id}", reason && "(#{reason})"]
    |> Enum.filter(&present?/1)
    |> Enum.join(" ")
  end
  def history_line(%ToolActionEvent{}), do: "Workflow updated"  # catch-all (D-24)

  # reason_label/1 — replaces inspect(reason) in failure_reason_message/1
  @reason_labels %{
    no_policy_defined: "No policy defined for this tool",
    denied: "Access denied by policy"
    # extend as real reason atoms appear
  }
  def reason_label(reason) when is_atom(reason) do
    Map.get(@reason_labels, reason, humanize_atom(reason))
  end
  def reason_label(reason) when is_binary(reason), do: reason
  def reason_label({:missing_scopes, scopes}), do: "Missing scopes: #{Enum.join(scopes, ", ")}"
  def reason_label(reason), do: inspect(reason)  # last-resort — should not reach operator

  # ... (input_rows/1, approval_outlook/1, risk_tier_label/1, etc.)
end
```

### Pattern 2: Total Preview.render/1 (D-18/D-19)

```elixir
defmodule Cairnloop.Governance.Preview do
  # Source: pattern derived from conversation_live.ex L747-753 (confirmed in-repo precedent)

  def render(%Cairnloop.Governance.ToolProposal{} = proposal) do
    case live_preview(proposal) do
      {:ok, text} when is_binary(text) and text != "" -> {:preview, text}
      _ -> {:structured, structured_summary(proposal)}
    end
  end

  defp live_preview(proposal) do
    with {:ok, tool_module} <- Cairnloop.ToolRegistry.find_tool_module(proposal.tool_ref),
         true <- Code.ensure_loaded?(tool_module),
         true <- function_exported?(tool_module, :preview, 1),
         input_struct <- rehydrate_input(tool_module, proposal.input_snapshot) do
      try do
        result = tool_module.preview(input_struct)
        if is_binary(result), do: {:ok, result}, else: :error
      rescue
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  defp rehydrate_input(tool_module, snapshot) when is_map(snapshot) do
    # D-19: JSONB gives string keys; atomize with String.to_existing_atom + rescue
    atomized =
      Enum.into(snapshot, %{}, fn
        {key, value} when is_binary(key) ->
          try do
            {String.to_existing_atom(key), value}
          rescue
            ArgumentError -> {key, value}  # unknown key — silently drop via struct/2
          end
        pair -> pair
      end)
    # struct/2 silently drops unknown keys — acceptable here (D-19)
    struct(tool_module, atomized)
  end

  defp structured_summary(proposal) do
    # Build entirely from snapshot — the common Phase-14 path (D-17)
    %{
      title: live_title(proposal.tool_ref),
      input_rows: input_rows(proposal.input_snapshot),
      risk_tier: proposal.risk_tier,
      approval_mode: proposal.approval_mode,
      scope: proposal.scope_snapshot
    }
  end

  defp live_title(tool_ref) do
    case Cairnloop.ToolRegistry.find_tool_module(tool_ref) do
      {:ok, mod} ->
        spec = mod.__tool_spec__()
        spec.title || humanize_tool_ref(tool_ref)
      _ ->
        humanize_tool_ref(tool_ref)
    end
  end

  defp humanize_tool_ref(tool_ref) do
    tool_ref |> String.split(".") |> List.last() |> String.replace("_", " ")
  end
end
```

### Pattern 3: `list_proposals_for_conversation/1` (D-09)

```elixir
# Add to lib/cairnloop/governance.ex
def list_proposals_for_conversation(conversation_id) do
  ToolProposal
  |> where([p], p.conversation_id == ^conversation_id)
  |> order_by([p], desc: p.inserted_at)
  |> preload(events: ^from(e in ToolActionEvent, order_by: [asc: e.inserted_at]))
  |> repo().all()
end
```

### Pattern 4: `reload_conversation_with_context/2` extension (D-09)

```elixir
# Extend existing function at L200
defp reload_conversation_with_context(socket, conversation_id) do
  conversation = Chat.get_conversation!(conversation_id)
  {context, context_error} = load_host_context(conversation)
  quick_fix_card = load_quick_fix_card(conversation)
  governed_actions = Cairnloop.Governance.list_proposals_for_conversation(conversation_id)

  assign(socket,
    conversation: conversation,
    host_context: context,
    context_error: context_error,
    quick_fix_card: quick_fix_card,
    governed_actions: governed_actions
  )
end
```

### Pattern 5: `governed_action_card/1` shape (D-03/D-05)

```elixir
attr :proposal, :map, required: true  # %ToolProposal{events: [...]}

def governed_action_card(assigns) do
  # Prepare presenter values before render to keep template clean
  assigns =
    assign(assigns,
      status_label: ToolProposalPresenter.status_label(assigns.proposal),
      risk_tier_label: ToolProposalPresenter.risk_tier_label(assigns.proposal.risk_tier),
      approval_outlook: ToolProposalPresenter.approval_outlook(assigns.proposal),
      preview: Preview.render(assigns.proposal),
      input_rows: ToolProposalPresenter.input_rows(assigns.proposal.input_snapshot),
      history: assigns.proposal.events
    )

  ~H"""
  <section class="rail-card governed-action-card" aria-live="polite">
    <!-- eyebrow -->
    <!-- headline: consequence preview or structured title -->
    <!-- status chip (text + color — never color alone, D-13/brand §7.5) -->
    <!-- risk tier + approval mode meta line -->
    <!-- approval_outlook sub-line (future-tense, D-12) -->
    <!-- input rows (humanized, D-22) -->
    <!-- event mini-timeline (compact; full detail behind <details>) -->
    <!-- scope snapshot (on :scope_invalid, surface missing scopes, D-21) -->
    <!-- policy snapshot sentence (D-21) -->
    <!-- trace metadata (de-emphasized, mono, D-21) -->
    <!-- footer action slot (empty in Phase 14, D-05) -->
  </section>
  """
end
```

### Anti-Patterns to Avoid

- **`inspect(reason)` to operator:** All three `failure_reason_message/1` clauses that call `inspect(reason)` must be replaced before Phase 14 ships (D-14). Calling `inspect` on a tuple like `{:missing_scopes, [:admin_scope]}` produces raw Elixir that must never reach the operator UI (brand §5.6).

- **`String.to_atom/1` for JSONB keys:** Only `String.to_existing_atom/1` with a `rescue ArgumentError` fallback is safe. `String.to_atom/1` is an unbounded-atom DoS vector (D-19).

- **Re-running `changeset/2` during rehydration:** `Preview.render/1` must use `struct(tool_module, atomized_snapshot)` not re-run `tool_module.changeset/2` — the latter introduces live drift through the back door (D-19).

- **`has_many(:tool_proposals)` eager-loaded in `Chat.get_conversation!/1`:** Do not add this preload to `Chat.get_conversation!`. Proposals are loaded separately in `reload_conversation_with_context/2` via `list_proposals_for_conversation/1`. Bundling them into `get_conversation!` would make every conversation load in the system pay the join cost.

- **`Phoenix.LiveView.stream/3`:** Not for this phase (D-02). The established thin-notification→full-reload pattern is correct for bounded, rarely-updated lists.

- **Introducing `LiveComponent` for the card:** Function component only (D-03). Cards are stateless renders of snapshot data.

- **Sourcing `governed_actions` from telemetry events:** All display comes from `list_events/1` (durable Ecto) and `list_proposals_for_conversation/1`. `:telemetry` events are observability only (D-23).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSONB atom↔string key coercion | Custom recursive key-normalizer | `String.to_existing_atom/1` + `rescue ArgumentError` + `struct/2` (in-repo precedent L747-753) | Already proven in `to_result/1`; consistent with P13 D-19 |
| Relative timestamp display | Custom duration formatter | Replicate `SearchResultPresenter.relative_time/1` private logic | Already handles NaiveDateTime/DateTime/nil; covers all units |
| Humanize atom to string | Custom inflector | `Atom.to_string |> String.replace("_", " ") |> String.capitalize()` (established in `GapCandidatePresenter.humanize_atom/1` L75-79) | Already the project idiom |
| Status-to-label mapping | `case status` branching in template | `ToolProposalPresenter.status_label/1` (pure function) | Template should never branch on trust-domain atoms |
| Dual-key JSONB map lookup | Separate getter per field | `metadata_value/2` idiom from `ReviewTaskPresenter` L162-165 | Safe against both atom and string keys |

---

## Rehydration Footgun Detail (D-19)

This is the highest-risk implementation area. All five sub-footguns confirmed:

**Footgun 1 — JSONB atom→string key round-trip (THE central trap):**
- `input_snapshot` is atom-keyed in memory at propose time (`Map.from_struct/1` produces atom keys)
- After Postgres INSERT + SELECT (any Ecto reload), the `:map` field returns string-keyed
- The existing in-repo precedent at `conversation_live.ex` L747-753 shows the correct guard
- Tests that don't round-trip through Postgres will NOT catch this — they get atom keys directly from `MockRepo.insert` which calls `apply_changes`
- Only tests that insert to Postgres and reload (or explicitly simulate string keys) prove correctness

**Footgun 2 — `String.to_atom/1`:**
- Never use it. Confirmed: `ToolRegistry.find_tool_module/1` uses `Atom.to_string/1` (not the reverse), which is safe. The key-atomization in `Preview.render/1` must use `String.to_existing_atom/1` + `rescue ArgumentError`.

**Footgun 3 — `struct/2` silent key drop:**
- If the tool's schema changes after a proposal is persisted (field renamed/removed), `struct(tool_module, atomized_snapshot)` silently drops the unknown keys. This is acceptable for the live `preview/1` leg (worst case: less informative preview text). It must NOT be accepted for the structured summary leg — the structured summary is built from raw snapshot maps, not a struct, so it's unaffected.

**Footgun 4 — unregistered tool module:**
- `ToolRegistry.find_tool_module/1` returns `{:error, :unknown_tool}` — the live leg must fall through to structured summary in this case. Confirmed the function signature and return type.

**Footgun 5 — `Code.ensure_loaded?/1` + `function_exported?/3`:**
- Guard order matters: `Code.ensure_loaded?/1` first (ensures the module is loaded in the VM — relevant if the tool module was hot-removed), then `function_exported?(mod, :preview, 1)`. The `__using__` macro does NOT inject a default `preview/1` implementation (confirmed: `@optional_callbacks [preview: 1, custom_ui: 0]` with no injected default). So `function_exported?/3` returns `false` for all current tools.

**`policy_snapshot` JSONB footgun (additional):** The valid-path snapshot stores atom keys (`:resolution_source`, `:declared_approval_mode`, `:resolved_approval_mode`); the blocked-path snapshot stores string keys (built with `%{outcome: outcome, reason: reason_str}`). After JSONB round-trip both become string keys. The card's policy explanation must use the `metadata_value/2` dual-key idiom.

---

## Common Pitfalls

### Pitfall 1: Adding `conversation_id` to the idempotency key
**What goes wrong:** Including `conversation_id` in `derive_idempotency_key/4`'s canonical map silently changes dedupe semantics — two browsers proposing the same action in different conversations would deduplicate when they should not, and the same action re-proposed in the same conversation would get a different key than the original.
**Why it happens:** It seems intuitive to scope idempotency by conversation.
**How to avoid:** D-08 is explicit. Check the `derive_idempotency_key/4` call site when adding `conversation_id` to the propose context — the key must only be written to the proposal record, never passed into the canonical map.
**Warning signs:** Any change to the `canonical =` map inside `derive_idempotency_key/4`.

### Pitfall 2: JSONB string-key invisible in tests
**What goes wrong:** All presenter and Preview tests pass because MockRepo returns atom-keyed structs from `apply_changes`. The bug only surfaces in production when the map is loaded from Postgres.
**Why it happens:** `MockRepo.insert` calls `Ecto.Changeset.apply_changes` which returns atom keys.
**How to avoid:** Test `Preview.render/1` and `input_rows/1` with explicitly string-keyed maps in addition to atom-keyed maps. Include at least one test comment noting the Postgres-only nature of the real footgun.
**Warning signs:** Tests that only use `%{order_id: "123"}` without a `%{"order_id" => "123"}` variant.

### Pitfall 3: `inspect/1` reaching the operator
**What goes wrong:** `failure_reason_message/1` currently calls `inspect(reason)` for scope_invalid and policy_denied. The scope_invalid reason is `{:missing_scopes, [:admin_scope]}` — a tuple. This already reaches the operator as `"{:missing_scopes, [:admin_scope]}"` today.
**Why it happens:** D-14 fix was deferred to Phase 14.
**How to avoid:** Replace all three `inspect` calls in `failure_reason_message/1` before the Phase 14 card is wired up. `ToolProposalPresenter.reason_label/1` must handle the `{:missing_scopes, scopes}` tuple case.
**Warning signs:** Any `inspect(reason)` in code paths that produce operator-visible strings.

### Pitfall 4: `preview/1` crash taking down the LiveView
**What goes wrong:** If `Preview.render/1` is called without a `try/rescue` around the `tool_module.preview/1` invocation, any exception from host code crashes the LiveView process.
**Why it happens:** Host callbacks can raise.
**How to avoid:** The `try/rescue` block is mandatory (D-19). `Preview.render/1` must catch all exceptions and fall through to the structured summary.
**Warning signs:** `Preview.render/1` calling `tool_module.preview(input_struct)` without a `try do ... rescue _ -> :error end` wrapper.

### Pitfall 5: `has_many(:tool_proposals)` in `Chat.get_conversation!/1` preload
**What goes wrong:** Adding `tool_proposals` to the preload in `Chat.get_conversation!` adds a join to every conversation load in the system, not just the LiveView rendering path.
**Why it happens:** The `belongs_to`/`has_many` association exists, and it's natural to preload it where conversations are loaded.
**How to avoid:** Load proposals separately in `reload_conversation_with_context/2` only. The `Chat.get_conversation!` preload must remain exactly as it is (messages + drafts only).

### Pitfall 6: `Ecto.assoc_loaded?` guard omission
**What goes wrong:** `proposal.events` may be `%Ecto.Association.NotLoaded{}` if the preload was skipped or if a proposal is constructed in a test without events. Iterating it directly raises.
**Why it happens:** Preload hygiene.
**How to avoid:** Guard all event list operations with `Ecto.assoc_loaded?(proposal.events)`, rendering a calm "No history yet" if false (D-24 / D-21).

---

## Validation Architecture

**`workflow.nyquist_validation` key is absent from `.planning/config.json`** — treated as enabled. Validation Architecture section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (confirmed via all existing `*.exs` test files) |
| Config file | `test/test_helper.exs` (standard Phoenix; not inspected but confirmed present via test run) |
| Quick run command | `mix test test/cairnloop/governance/preview_test.exs test/cairnloop/web/tool_proposal_presenter_test.exs` |
| Full suite command | `mix test` |
| Compile gate | `mix compile --warnings-as-errors` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FLOW-01 | `list_proposals_for_conversation/1` returns proposals ordered desc by inserted_at with events preloaded | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 — extend governance_test.exs |
| FLOW-01 | `reload_conversation_with_context/2` assigns `governed_actions` | unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 — extend |
| FLOW-01 | `governed_action_card/1` renders all four statuses in the rail without crashing | unit (render_component) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 — extend |
| FLOW-01 | `conversation_id` is excluded from idempotency key (D-08) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 — extend |
| FLOW-01 | `conversation_id` written on valid path AND on blocked path (D-07) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ Wave 0 — extend |
| FLOW-02 | `Preview.render/1` returns `{:structured, assigns}` when no `preview/1` implemented (common path, D-17) | unit (no DB) | `mix test test/cairnloop/governance/preview_test.exs` | ❌ Wave 0 |
| FLOW-02 | `Preview.render/1` falls back to structured summary when `preview/1` raises | unit (no DB) | `mix test test/cairnloop/governance/preview_test.exs` | ❌ Wave 0 |
| FLOW-02 | `Preview.render/1` falls back to structured summary when tool unregistered | unit (no DB) | `mix test test/cairnloop/governance/preview_test.exs` | ❌ Wave 0 |
| FLOW-02 | `Preview.render/1` handles string-keyed snapshot (simulated JSONB round-trip) | unit (no DB) | `mix test test/cairnloop/governance/preview_test.exs` | ❌ Wave 0 |
| FLOW-02 | `ToolProposalPresenter.status_label/1` returns correct copy for all four statuses | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ Wave 0 |
| FLOW-02 | `ToolProposalPresenter.reason_label/1` humanizes `{:missing_scopes, [...]}` without `inspect` | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ Wave 0 |
| FLOW-02 | `ToolProposalPresenter.history_line/1` catch-all returns `"Workflow updated"` for unknown event types | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ Wave 0 |
| FLOW-02 | `input_rows/1` never dumps raw map — returns humanized rows or `"Unsupported value"` | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ❌ Wave 0 |
| FLOW-02 | `failure_reason_message/1` replacement no longer calls `inspect` on scope/policy reason | source assertion (existing pattern at L1019-1044 in conversation_live_test.exs) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 — extend |
| Support-Truth Gate | Blocked proposals (scope_invalid, policy_denied, needs_input) appear in the rail | unit (render_component with MockRepo) | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ Wave 0 — extend |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors && mix test test/cairnloop/governance/preview_test.exs test/cairnloop/web/tool_proposal_presenter_test.exs`
- **Per wave merge:** `mix compile --warnings-as-errors && mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps (test infrastructure that must exist before implementation)

**New test files (Wave 0):**
- [ ] `test/cairnloop/governance/preview_test.exs` — covers `Preview.render/1` headless (no DB required)
- [ ] `test/cairnloop/web/tool_proposal_presenter_test.exs` — covers all presenter functions (pure, no DB)

**Extend existing test files (Wave 0):**
- [ ] `test/cairnloop/governance_test.exs` — add describe blocks for `list_proposals_for_conversation/1`, `conversation_id` exclusion from idempotency key, `conversation_id` written on both valid and blocked paths
- [ ] `test/cairnloop/web/conversation_live_test.exs` — add describe blocks for governed_action_card rendering

**Shared fixture:**
- [ ] A `%ToolProposal{}` struct factory (inline in each test file — existing pattern; no shared factory module in this codebase)
- [ ] `MockRepo` in `conversation_live_test.exs` must be extended to return `governed_actions: []` or a list of proposal structs from `reload_conversation_with_context/2` — the current MockRepo at L8 returns a `Conversation` without proposals (not an issue until Phase 14 wires `governed_actions` into the assign)

**No additional framework install required** — ExUnit and Phoenix.LiveViewTest are already configured.

### DB-round-trip tests (cannot run without Repo)

The JSONB atom→string key footgun (D-19, Footgun 1) is genuinely undetectable without a
real Postgres round-trip. For these tests:

1. The MockRepo-based `Preview.render/1` tests should include a test case with
   **explicitly string-keyed** snapshot maps (e.g. `%{"order_id" => "123"}` instead of
   `%{order_id: "123"}`) to partially simulate the footgun. This does not require a real
   DB but gives meaningful coverage.
2. Full Postgres round-trip coverage is deferred to a future "repo-backed realism lane" per
   STATE.md (the `Cairnloop.Repo` unavailability caveat). Document this gap in test files
   with a `# REPO-UNAVAILABLE: Full JSONB round-trip test requires Postgres` comment.

---

## Brand / UX Confirmations

### Brand token for button color
The hardcoded `#2563eb` (SaaS blue) in `tool_renderer/1` at L540 must be replaced.
Confirmed brand primary: `var(--cl-primary, #A94F30)` — confirmed in
`search_modal_component.ex` at L196 (primary action button). Also visible in the quick-fix
CSS at L346: `background: #a94f30` for `.quick-fix-actions button`.

### Chip/badge idiom
Confirmed in `search_modal_component.ex` L131-136: chips are `<span style={source_badge_style(...)}>` elements inside a flex div. The inline-style functions produce background/border-radius/padding/font-weight combinations. The governed-action card status chip and risk-tier chip should follow this pattern. Brand §7.5 (never state-by-color-alone) is enforced by always pairing the colored chip with a text label inside the same element.

### Humanize helpers
Confirmed in `conversation_live.ex`:
- `humanize_context_label/1` — L670
- `normalize_context_value/1` — L679-691 (returns "Unsupported value" for unsupported types)
- `context_field/1` — L569 (label + value pair; `hide_label` option)
- `context_section/1` — L552 (section header + fields; handles nested map by iterating children)

All four are suitable for reuse in the input-snapshot and scope-snapshot display rows of the governed-action card (D-22).

### "Never state-by-color-alone" enforcement
The `quick_fix_status_chip.current` class at L353 uses `border-color + background` change, but the label text (in `.quick-fix-status-label`) always renders alongside. The governed-action status chip must follow the same pattern — brand color/tone atom returned from presenter, LiveView maps it to CSS, label text always co-present.

### `approval_outlook/1` honesty seam (D-12)
No current code implements this. It is a new presenter function that returns a calm
future-tense string based on `approval_mode` when the proposal is in `:proposed` status:
- `:auto` → `nil` (no sub-line needed — will run without approval)
- `:requires_approval` → `"Will require approval before it can run."`
- `:always_block` → `"This action cannot be approved or run."`

Phase 15 repurposes this seam: when `status == :pending_approval`, the sub-line becomes
the real approval action copy and the chip label changes to "Pending approval".

---

## Runtime State Inventory

> Phase 14 is not a rename/refactor/migration phase in the classical sense, but it includes
> a schema migration and new assigns. Explicit inventory follows.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `cairnloop_tool_proposals` rows exist from Phase 13 testing. None have `conversation_id` (nullable column, NULL is correct for pre-Phase-14 rows). | Migration adds nullable column — no data backfill needed or desired (D-06). |
| Live service config | No n8n workflows or external services reference `ToolProposal`. | None. |
| OS-registered state | None relevant. | None. |
| Secrets/env vars | No new env vars. `APPLICATION.get_env(:cairnloop, :repo)` pattern already established. | None. |
| Build artifacts | `ToolProposal` schema change requires migration in development; `mix ecto.migrate` must be run. Test suite uses MockRepo so no migration required for tests. | Developer runs `mix ecto.migrate` before manual testing. |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | All | Confirmed (existing CI/test suite passes) | — | — |
| ExUnit | Tests | Confirmed | — | — |
| Phoenix.LiveViewTest | ConversationLive tests | Confirmed (existing test at L2) | — | — |
| PostgreSQL | JSONB round-trip tests (real footgun) | Not available in this workspace (STATE.md) | — | String-keyed fixture tests (partial coverage; gap documented) |

**Missing dependencies with no fallback:**
- None that block Phase 14 execution.

**Missing dependencies with fallback:**
- PostgreSQL for full JSONB round-trip proof → use explicit string-keyed fixtures in unit tests; gap documented with `# REPO-UNAVAILABLE` comments.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Synchronous `execute` in LiveView | `Governance.propose/3` — durable proposal, no execution | Phase 13 | Phase 14 shows proposals, not results |
| Flash message as the only proposal feedback | Flash → being replaced by timeline card in Phase 14 | Phase 14 | Flash remains for immediate feedback; card is the durable record |
| `inspect(reason)` in failure_reason_message | Replace with `reason_label/1` mapping | Phase 14 | D-14 — raw Elixir must never reach the operator |

**Deprecated/outdated in this phase:**
- `failure_reason_message/1` clauses using `inspect(reason)` — D-14 fix is due in Phase 14.
- The hardcoded `#2563eb` blue on the Execute button — D-04 brand-token fix due in Phase 14.
- The "Execute" button text — rename to "Propose" (D-04).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No tool in the codebase currently implements `preview/1` (structured summary is the common path, D-17) | Standard Stack / Seam verification | If a tool does implement it, the live leg exercises sooner; tests must cover that path — no architectural change |
| A2 | `var(--cl-primary, #A94F30)` is the correct brand token to replace `#2563eb` | Brand/UX Confirmations | If the brand token name differs, the button gets the fallback color — visually noticeable but not a trust issue |

**If this table is empty:** Not empty — two low-risk assumptions above.

---

## Open Questions (RESOLVED)

1. **D-15 ratification (trust-sensitive — flagged for user)**
   - What we know: D-15 is marked as a trust call in CONTEXT.md; it is "recommended and justified" but the user may veto in favour of snapshot-now before planning.
   - What's unclear: Whether the user has ratified D-15 or intends to reopen Phase 13's `propose/3` path to snapshot the consequence string now.
   - Recommendation: Planner should confirm with user before writing M011-S02-01/02 tasks that touch `Preview.render/1`. If the user vetoes D-15, the plan for M011-S02-01 must include reopening `propose/3` to snapshot the consequence string (a schema change + call-site change in Phase 13 code).
   - **RESOLVED (2026-05-24):** Ratified **Hybrid** (no veto). The user delegated the call; three parallel deep-research passes (Elixir/Phoenix/Ecto idioms, cross-ecosystem review-then-act systems, project-vision coherence) converged unanimously on Hybrid. Phase 13 `propose/3` is NOT reopened; no prose migration in Phase 14. The Phase-15 forward-compat guardrail (additive `rendered_consequence`/`title` columns when prose first becomes load-bearing) is carried in 14-CONTEXT.md + STATE.md. See the "RATIFIED" note in 14-CONTEXT.md.

2. **`policy_snapshot` reason string is `inspect(reason)` (from Phase 13)**
   - What we know: `insert_blocked_proposal/10` stores `reason_str = inspect(reason)` in `policy_snapshot` at L307. This is raw Elixir term output.
   - What's unclear: Whether the Phase 14 card should display this raw string in the "raw map behind expander" section, or attempt to parse/humanize it.
   - Recommendation: Display the raw string ONLY behind the expander (D-22 — inline = humanized, raw behind expander). The inline policy sentence uses the `outcome` key only (humanized via presenter). This is consistent with D-22 and requires no Phase 13 change.
   - **RESOLVED (2026-05-24):** Adopt the recommendation as-is — inline humanized via the presenter, raw string only behind the `<details>` expander (D-22). No Phase 13 change. Implemented by 14-02 (raw maps behind expander) + 14-01 (`policy_explanation`/`block_reason_copy` in `ToolProposalPresenter`).

---

## Sources

### Primary (HIGH confidence — all verified against live source files)
- `lib/cairnloop/web/conversation_live.ex` — all seams verified (line numbers confirmed)
- `lib/cairnloop/governance.ex` — facade API confirmed
- `lib/cairnloop/governance/tool_proposal.ex` — schema confirmed
- `lib/cairnloop/governance/tool_action_event.ex` — append-only schema confirmed
- `lib/cairnloop/governance/policy.ex` — `policy_snapshot` shape confirmed
- `lib/cairnloop/tool.ex` — `preview/1` optional callback confirmed
- `lib/cairnloop/tool_registry.ex` — `find_tool_module/1` return type confirmed
- `lib/cairnloop/web/review_task_presenter.ex` — presenter idiom confirmed
- `lib/cairnloop/web/search_result_presenter.ex` — recency/relative_time confirmed
- `lib/cairnloop/web/gap_candidate_presenter.ex` — reason_labels + humanize_atom confirmed
- `lib/cairnloop/web/search_modal_component.ex` — badge chip idiom confirmed
- `lib/cairnloop/automation/draft.ex` — belongs_to(:conversation) precedent confirmed
- `lib/cairnloop/conversation.ex` — has_many(:drafts) precedent; table name confirmed
- `lib/cairnloop/chat.ex` — get_conversation! preload shape confirmed
- `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs` — migration style confirmed
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` — nilify_all FK precedent confirmed
- `test/cairnloop/governance_test.exs` — MockRepo pattern + test idiom confirmed
- `test/cairnloop/web/conversation_live_test.exs` — test idiom + source-assertion pattern confirmed
- `.planning/phases/14-operator-timeline-preview-surface/14-CONTEXT.md` — locked decisions
- `.planning/REQUIREMENTS.md` — FLOW-01, FLOW-02, Proof Posture Gate, Support-Truth Gate

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Repo unavailability caveat
- `.planning/config.json` — nyquist_validation key absent (treated as enabled)

---

## Metadata

**Confidence breakdown:**
- Code seam existence: HIGH — all seams directly verified in source files
- Standard stack: HIGH — no new packages; all libraries already in use
- Architecture: HIGH — locked in D-01..D-27; confirmed against idioms already present
- Rehydration footguns: HIGH — all five confirmed against source; in-repo precedent at L747-753
- Migration style: HIGH — two precedent migrations read and style confirmed
- Validation Architecture: HIGH — test infrastructure present; gaps listed precisely
- Brand/UX: HIGH — badge idiom and primary color confirmed in source

**Research date:** 2026-05-24
**Valid until:** 2026-06-24 (stable domain; no fast-moving dependencies)
