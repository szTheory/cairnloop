---
phase: 14-operator-timeline-preview-surface
reviewed: 2026-05-24T14:32:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/cairnloop/conversation.ex
  - lib/cairnloop/governance.ex
  - lib/cairnloop/governance/preview.ex
  - lib/cairnloop/governance/tool_proposal.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/tool_proposal_presenter.ex
  - priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs
  - test/cairnloop/governance/preview_test.exs
  - test/cairnloop/governance_test.exs
  - test/cairnloop/web/conversation_live_test.exs
  - test/cairnloop/web/tool_proposal_presenter_test.exs
findings:
  critical: 1
  warning: 6
  info: 4
  total: 11
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-05-24T14:32:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 14 builds the read-only operator timeline + preview surface over durable Phase-13
`ToolProposal` + `ToolActionEvent` records. The presenter layer (`ToolProposalPresenter`),
the total `Preview.render/1` fallback stack, and the masking/humanization choke points are
well-designed and match the stated D-decisions. The D-19 atom-safety guard
(`String.to_existing_atom` + rescue, never `String.to_atom`), the D-22 masking posture, and the
D-14 no-raw-terms humanization are correctly implemented and tested. The build is
warnings-clean for `lib/` and all 114 reviewed tests pass.

The review nonetheless surfaces one BLOCKER: a fail-closed gap in the LiveView `execute_tool`
handler that crashes the LiveView on a `{:error, changeset}` return — a path that
`Governance.propose/3` can genuinely produce and that the CR-02 hardening explicitly threads
through. Several WARNINGs concern an unintended `:needs_input` persistence path that stores a
fully-inspected `Ecto.Changeset` into a durable snapshot column, a few total-function edge cases,
and project-rule warnings emitted while compiling the test suite (which violates the mandatory
warnings-clean build rule for the test files in scope).

Interpretive-prose-live-read via `Preview.render/1` is by-design per D-15 and was NOT flagged.

## Critical Issues

### CR-01: `execute_tool` handler has no clause for `{:error, changeset}` — crashes LiveView on insert failure

**File:** `lib/cairnloop/web/conversation_live.ex:183-189`
**Issue:**
`Cairnloop.Governance.propose/3` can return `{:error, %Ecto.Changeset{}}`. This is not
hypothetical — it is the explicit non-unique-constraint else branch in `insert_new_proposal/6`
(`lib/cairnloop/governance.ex:265-266`, `{:error, cs} -> {:error, cs}`) and the threaded result
from `propose_blocked/5` (`lib/cairnloop/governance.ex:193-196`, `{:error, _cs} = err -> err`).
The CR-02 hardening comment in `propose/3` says insert failures must "not be silently swallowed"
— but the only consumer, the LiveView, has no clause to receive them:

```elixir
case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
  {:ok, proposal} -> ...
  {:blocked, outcome, reason} -> ...
  # no {:error, _} clause
end
```

Any insert failure that is NOT a unique-constraint violation (FK violation on a stale
`conversation_id`, a DB connection drop mid-insert, an unexpected validation error, the
`:proposal_created` event insert failing after the proposal insert succeeded) returns
`{:error, cs}` and raises `CaseClauseError`, crashing the LiveView process. This directly
violates the project's fail-closed posture ("Operator copy is calm, fail-closed... never raw
Elixir terms"). The operator gets a crash/disconnect instead of a calm flash.

**Fix:**
```elixir
case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
  {:ok, proposal} ->
    {:noreply, put_flash(socket, :info, "Proposed — pending review. (##{proposal.id})")}

  {:blocked, outcome, reason} ->
    {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}

  {:error, _changeset} ->
    # Fail closed: never surface a raw changeset to the operator
    {:noreply, put_flash(socket, :error, "This action could not be recorded right now. Please try again.")}
end
```
Add a regression test asserting the `{:error, _}` branch produces a calm error flash (the
existing test MockRepo can be made to return `{:error, changeset}` from `insert/1`).

## Warnings

### WR-01: `:needs_input` outcome persists a fully-inspected `Ecto.Changeset` into the durable `policy_snapshot`

**File:** `lib/cairnloop/governance.ex:190-196, 313, 326` (and `propose_blocked/5` chain)
**Issue:**
The third clause of `propose/3` (`{:blocked, outcome, reason}`) catches `outcome = :needs_input`
in addition to `:scope_invalid` / `:policy_denied`, because `validate/3` returns
`{:blocked, :needs_input, changeset}` (`lib/cairnloop/governance.ex:162`). `:needs_input` is a
valid `ToolProposal` status (`tool_proposal.ex:22`), so the proposal IS persisted. But for this
path the `reason` is an `Ecto.Changeset`, and `insert_blocked_proposal/10` does
`reason_str = inspect(reason)` (`governance.ex:313`) then stores it in
`policy_snapshot: %{outcome: :needs_input, reason: reason_str}` (`governance.ex:326`) and in the
`ToolActionEvent.reason` column (`governance.ex:344`). The result is a giant
`#Ecto.Changeset<...>` string written into a durable trust-category snapshot column. This
contradicts the moduledoc/comments ("Registered tool blocked by scope/policy: proposal persisted")
which only describe scope/policy, and it pollutes the audit record with raw Elixir internals.
The `governed_action_card` "Raw policy snapshot" expander then renders this inspected changeset
back to the operator (behind an expander, so not itself a leak — but the durable data is wrong).

The LiveView never reaches this path today because `validate/3` is called first inside
`propose/3` and the LiveView surfaces "Invalid tool parameters" via the
`{:blocked, :needs_input, _}` flash branch — i.e. the proposal is silently persisted as a side
effect while the operator is told it was rejected. Whether `:needs_input` should persist at all
is a design question; if it should, it must not store an inspected changeset.

**Fix:**
Either (a) handle `:needs_input` like `:unsupported` (telemetry only, no row) if it should not be
durable, or (b) if it must persist, extract a humanized reason from the changeset rather than
`inspect/1`, e.g.:
```elixir
reason_str =
  case reason do
    %Ecto.Changeset{} = cs ->
      cs
      |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
      |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)

    other ->
      ToolProposalPresenter.reason_label(other) || "Action was blocked"
  end
```
Add a test for `propose/3` with an `InvalidInputTool` asserting the persisted `policy_snapshot`
contains no `#Ecto.Changeset<` substring.

### WR-02: Test-suite compilation emits `@impl` warnings — violates mandatory warnings-clean build

**File:** `test/cairnloop/governance_test.exs:117-184` (ValidTool, ScopeFailingTool, PolicyDenyingTool, InvalidInputTool)
**Issue:**
Compiling the in-scope test files emits multiple
`warning: module attribute @impl was not set for function run/3 callback (specified in
Cairnloop.Tool)` and equivalent `scope/0` warnings for the four test tool modules. CLAUDE.md
states "Warnings-clean builds are mandatory." The neighboring `conversation_live_test.exs` tool
fixtures correctly annotate every callback with `@impl Cairnloop.Tool`; the `governance_test.exs`
fixtures do not, so they regress the warnings-clean rule whenever the test suite is compiled.

**Fix:**
Add `@impl Cairnloop.Tool` before each `def run/3`, `def scope/0` (and any other behaviour
callbacks) in the `governance_test.exs` tool fixtures, mirroring the
`conversation_live_test.exs` fixtures.

### WR-03: Unused default argument warning on `tool_proposal_fixture/1`

**File:** `test/cairnloop/web/conversation_live_test.exs:1348`
**Issue:**
`defp tool_proposal_fixture(overrides \\ %{})` emits
`warning: default values for the optional arguments in the private function
tool_proposal_fixture/1 are never used` because every caller passes an explicit map. Same
warnings-clean rule as WR-02.

**Fix:**
Drop the unused default: `defp tool_proposal_fixture(overrides) do`. (Callers already pass an
argument; alternatively add a zero-arg caller if one is intended.)

### WR-04: `event.metadata` truthiness always opens the per-event "Details" expander

**File:** `lib/cairnloop/web/conversation_live.ex:976-988`
**Issue:**
The event mini-timeline guards the Details expander with `if event.reason || event.metadata`.
`ToolActionEvent.metadata` defaults to `%{}` (`tool_action_event.ex:31`) and the card maps
`metadata: ev.metadata` (`conversation_live.ex:864`) with no normalization. An empty map `%{}` is
truthy in Elixir, so the "Details" expander renders for every event even when there is no reason
and the metadata is empty — and the inner `<%= if event.metadata do %>` then renders
`inspect(%{}, pretty: true)` → `"%{}"`. The operator sees an empty "Details / %{}" disclosure on
every `:proposal_created` event. Low-severity correctness/quality issue, not a crash.

**Fix:**
Guard on emptiness, not truthiness:
```elixir
<%= if event.reason || (is_map(event.metadata) and map_size(event.metadata) > 0) do %>
```
and likewise for the inner metadata `<pre>` block.

### WR-05: `metadata_value/2` uses `||` and will treat a stored `false` value as missing

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex:320-322`
**Issue:**
`Map.get(map, key) || Map.get(map, Atom.to_string(key))` returns the string-key value whenever
the atom-key value is falsy. For the current `:outcome` / `:reason` usage this is benign (outcomes
are atoms, reasons are non-empty strings). But this is a general-purpose dual-key lookup helper
(documented as mirroring `ReviewTaskPresenter.metadata_value/2`); if any future snapshot key
legitimately stores `false` (e.g. a boolean policy flag), the atom-key `false` is silently
discarded and the string-key (or `nil`) value is returned instead — a latent correctness trap.

**Fix:**
Prefer explicit presence checks:
```elixir
defp metadata_value(map, key) when is_map(map) do
  case Map.fetch(map, key) do
    {:ok, value} -> value
    :error -> Map.get(map, Atom.to_string(key))
  end
end
```

### WR-06: `humanize_label/1` can emit an empty headline/title for a trailing-dot or empty tool_ref segment

**File:** `lib/cairnloop/governance/preview.ex:163-178`
**Issue:**
`humanize_tool_ref/1` does `tool_ref |> String.split(".") |> List.last() |> humanize_label()`.
For a malformed `tool_ref` ending in `"."` (e.g. `"Cairnloop.Tools."`), `List.last/1` returns
`""`; `humanize_label("")` then runs `String.split("", " ") -> [""]`, `Enum.map(..., &capitalize)
-> [""]`, `Enum.join -> ""`. The title fallback (`resolve_title/1`) therefore returns an empty
string instead of the intended `"Unknown tool"` sentinel, and the card headline renders blank.
The `nil` case is handled, but the empty-string case is not. tool_ref is server-derived today so
this is low-likelihood, but the function is documented as a total fallback and should never
produce an empty headline.

**Fix:**
Add an empty-string guard:
```elixir
defp humanize_label(nil), do: "Unknown tool"
defp humanize_label(""), do: "Unknown tool"
defp humanize_label(label) do
  ...
end
```
(Optionally also guard `List.last/1` returning `nil` for a fully-empty split.)

## Info

### IN-01: `propose/3` doc/comments understate the `:needs_input` persistence path

**File:** `lib/cairnloop/governance.ex:168-198`
**Issue:**
The `propose/3` `@doc` and the inline comment at line 191 ("Registered tool blocked by
scope/policy") describe only `:scope_invalid` / `:policy_denied` for the persisting branch, but
the `{:blocked, outcome, reason}` clause also catches `:needs_input` (see WR-01). The
documentation should match the actual matched outcomes so future maintainers don't assume
`:needs_input` is non-persisting.

**Fix:** Update the doc and comment to enumerate `:needs_input` explicitly (or exclude it per
the WR-01 resolution).

### IN-02: `trace_metadata/1` idempotency-key suffix boundary is inconsistent for 8-char keys

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex:290-295`
**Issue:**
The suffix logic uses `byte_size(key) > 8` to prepend the `"…"` ellipsis. A key of exactly 8
chars falls into the second clause and is shown in full with no ellipsis, while a 9-char key shows
`"…" <> last 8`. Real SHA-256 hex keys are 64 chars so this never triggers in production; it is a
cosmetic edge inconsistency only. Not a defect, noted for completeness.

**Fix:** None required; if desired, change `> 8` to `>= 8` for consistency, or document the
boundary.

### IN-03: `governed_action_card/1` calls `Preview.render/1` per proposal at render time (by-design, noted)

**File:** `lib/cairnloop/web/conversation_live.ex:885`
**Issue:**
Each card invokes the live preview leg (`Code.ensure_loaded?`, `function_exported?`, atom
rehydration, `try/rescue` around `mod.preview/1`) on every render. This is the ratified D-15
interpretive-prose-live behavior behind a TOTAL fallback and is explicitly out of scope to flag as
a bug. Noted only so the Phase-15 forward-compat guardrail in `preview.ex` (snapshot
`rendered_consequence`/`title` at propose-time before prose becomes load-bearing) is not lost —
the contract is well documented in the moduledoc.

**Fix:** None for Phase 14. Carry the Phase-15 snapshot contract forward as documented.

### IN-04: Migration has no explicit `down/0` (acceptable — `change/0` is auto-reversible)

**File:** `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs:4-11`
**Issue:**
The migration uses `change/0` with `alter table ... add` + `create index`, both of which Ecto can
auto-reverse, so rollback works. The `on_delete: :nilify_all` and `null: true` choices correctly
preserve pre-Phase-14 NULL rows (D-06/D-07). No action needed — recorded as a positive
confirmation that reversibility was verified.

**Fix:** None.

---

_Reviewed: 2026-05-24T14:32:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
