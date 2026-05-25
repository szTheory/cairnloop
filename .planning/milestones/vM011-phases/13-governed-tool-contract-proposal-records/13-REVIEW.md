---
phase: 13-governed-tool-contract-proposal-records
reviewed: 2026-05-23T21:20:11Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/cairnloop/application.ex
  - lib/cairnloop/governance.ex
  - lib/cairnloop/governance/policy.ex
  - lib/cairnloop/governance/telemetry.ex
  - lib/cairnloop/governance/tool_action_event.ex
  - lib/cairnloop/governance/tool_proposal.ex
  - lib/cairnloop/tool.ex
  - lib/cairnloop/tool/spec.ex
  - lib/cairnloop/tool_registry.ex
  - lib/cairnloop/web/conversation_live.ex
  - priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs
  - test/cairnloop/governance/tool_action_event_test.exs
  - test/cairnloop/governance/tool_proposal_test.exs
  - test/cairnloop/governance_test.exs
  - test/cairnloop/tool_registry_test.exs
  - test/cairnloop/tool_test.exs
  - test/cairnloop/web/conversation_live_test.exs
findings:
  critical: 2
  warning: 6
  info: 4
  total: 12
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-05-23T21:20:11Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

This phase implements the governed-tool proposal system: a `Cairnloop.Tool` behaviour/macro, a fail-closed `Governance.validate/3` pipeline, a synchronous `propose/3` persistence wrapper with idempotency, append-only `ToolActionEvent` records, and the `execute_tool` LiveView handler (propose-only, no inline execution).

The core invariants hold up well under inspection: gate ordering in `validate/3` is encoded as `with` clause order (D-17), `resolve_tool/1` correctly delegates to `ToolRegistry.find_tool_module/1` with no `String.to_existing_atom/1`, `ToolActionEvent` is append-only (no update/delete, `updated_at: false`), deny-by-default `authorize/2` is enforced, and `ConversationLive.execute_tool` is genuinely propose-only (no `run/3`, no `try/rescue`).

However, there is a confirmed crash bug in the LiveView error path that no test exercises, a silent-swallow defect in the blocked-persistence path, and several consistency/robustness problems. Two BLOCKER-class findings must be fixed before this ships.

## Critical Issues

### CR-01: `failure_reason_message/2` crashes the LiveView on scope_invalid (and non-stringable policy reasons)

**File:** `lib/cairnloop/web/conversation_live.ex:191-195`
**Issue:** When `Governance.propose/3` returns `{:blocked, :scope_invalid, reason}`, the `reason` is the tuple `{:missing_scopes, missing}` produced by `check_scope/2` (`lib/cairnloop/governance.ex:80`). `failure_reason_message(:scope_invalid, reason)` interpolates it directly:

```elixir
defp failure_reason_message(:scope_invalid, reason),
  do: "Tool not available in this context: #{reason}."
```

A tuple does not implement `String.Chars`, so `"#{reason}"` raises `Protocol.UndefinedError` and crashes the LiveView process. The same applies to `:policy_denied` whenever `authorize/2` returns a non-stringable reason (any tuple/list/map). I confirmed the crash with a standalone interpolation test. No LiveView test covers the `:scope_invalid` or `:policy_denied` flash paths — only `:unsupported` and `:needs_input` are tested (`test/cairnloop/web/conversation_live_test.exs:875-918`), so this is invisible to the suite.

**Fix:** Use `inspect/1` (which never raises) for any reason that may not be a plain string:

```elixir
defp failure_reason_message(:scope_invalid, reason),
  do: "Tool not available in this context: #{inspect(reason)}."

defp failure_reason_message(:policy_denied, reason),
  do: "Tool call not permitted: #{inspect(reason)}."
```

Add LiveView tests asserting the `:scope_invalid` and `:policy_denied` flash messages so this path is covered.

### CR-02: Blocked-proposal persistence silently swallows insert failures (no `else`, return value discarded)

**File:** `lib/cairnloop/governance.ex:175-178, 286-311`
**Issue:** `propose_blocked/5` runs a `with` pipeline that inserts the proposal and the `:proposal_blocked` event, but it has **no `else` clause**. If either insert returns `{:error, changeset}` (the most likely real case: a second blocked submission with the same derived `idempotency_key` violates the unique index at `migration:30`), the `with` returns `{:error, changeset}` — and that return value is **discarded** by the caller:

```elixir
{:blocked, outcome, reason} = blocked ->
  propose_blocked(tool_ref, actor_id, context, outcome, reason)  # return ignored
  blocked
```

Consequences: (1) the audit trail the phase design promises for blocked-but-registered tools ("Support-Truth Gate", D-18) is silently lost on the failing path; (2) no telemetry is emitted (the `Telemetry.emit(:proposal_blocked, ...)` lives inside the `with` body and is skipped); (3) the user still sees the normal blocked flash, masking the persistence failure. This is a data-loss / audit-integrity defect, not a cosmetic one. Note `propose_valid/4` correctly handles the duplicate constraint (lines 238-247) — `propose_blocked/5` does not, an asymmetry that proves the gap.

**Fix:** Mirror the duplicate/idempotency handling from `propose_valid` in the blocked path — check `get_by` first and/or add an `else` clause that handles the unique-constraint error (return the existing blocked proposal) and surfaces any other insert error rather than dropping it:

```elixir
with {:ok, proposal} <- ...insert...,
     {:ok, _event} <- ...insert... do
  Telemetry.emit(:proposal_blocked, ...)
  :ok
else
  {:error, %Ecto.Changeset{} = cs} ->
    if unique_constraint_error?(cs, :idempotency_key) do
      Telemetry.emit(:proposal_duplicate, %{count: 1}, %{outcome: :duplicate})
      :ok
    else
      {:error, cs}
    end
end
```

## Warnings

### WR-01: Blocked vs. valid idempotency keys are derived from different inputs — `:needs_input` retries never dedupe and never reconcile

**File:** `lib/cairnloop/governance.ex:183, 254-255`
**Issue:** `propose_valid/4` derives the key from `validated.input_snapshot`, which is `Map.from_struct(apply_changes(changeset))` (atom keys, only cast fields). `propose_blocked/5` derives the key from the **raw** `Map.get(context, :tool_params, %{})` (string-or-atom keys, exactly as posted from the form). For the same logical call, the two code paths therefore produce **different** idempotency keys. A tool blocked with `:needs_input`, then resubmitted with corrected input that validates, will not collide with — nor supersede — the earlier blocked row, and two blocked submissions of the same params may themselves diverge if the form sends keys in a different shape. The determinism invariant (D-25) only holds within a single path.

**Fix:** Normalize the input used for key derivation identically in both paths (e.g. always run the tool changeset and use `apply_changes` even on the blocked path, or always canonicalize the raw params with consistent key/type coercion before hashing). Document explicitly whether a blocked attempt and a later successful attempt are intended to share a key.

### WR-02: `derive_idempotency_key/4` does not deeply canonicalize nested input — only top-level keys are sorted

**File:** `lib/cairnloop/governance.ex:105-120`
**Issue:** The canonicalization sorts only the **top level** of `input_snapshot`:

```elixir
input: input_snapshot |> Map.to_list() |> Enum.sort() |> Map.new()
```

`Jason.encode!/1` does not guarantee key order for nested maps, and `Map` iteration order is not part of the contract. A tool whose input contains a nested map (entirely plausible for embedded-schema inputs) can hash to two different keys for semantically identical input, breaking idempotency. Additionally, `Map.to_list() |> Enum.sort()` sorts by `{key, value}` pairs; if two keys ever compared equal with differing value term-ordering it would be fragile, though atom keys make that unlikely.

**Fix:** Canonicalize recursively (deep-sort all nested maps) before encoding, or use a JSON encoder configured to sort keys at every level. Add a test with nested input proving stable key derivation.

### WR-03: `propose_blocked/5` re-resolves the tool module inline, duplicating `ToolRegistry.find_tool_module/1`

**File:** `lib/cairnloop/governance.ex:258-269`
**Issue:** `resolve_tool/1` (line 51-56) is documented as the single source of truth — "no duplicate Atom.to_string logic here." But `propose_blocked/5` re-implements exactly that resolution inline:

```elixir
tool_module =
  (Application.get_env(:cairnloop, :tools, []) || [])
  |> Enum.find(fn mod -> Atom.to_string(mod) == tool_ref end)
```

This is the duplicate logic the comment forbids, and it diverges from the registry (it bypasses `find_tool_module/1`'s contract). If resolution rules ever change in the registry, this path silently goes stale.

**Fix:** Call `Cairnloop.ToolRegistry.find_tool_module(tool_ref)` and pattern-match `{:ok, mod}`. Since gate 0 already guaranteed the tool resolves before `propose_blocked/5` is reached, the `{:error, ...}` branch is unreachable and can be a hard failure.

### WR-04: Dead `{:unknown, :always_block}` branch can produce an enum value the schema rejects

**File:** `lib/cairnloop/governance.ex:262-269`
**Issue:** The `else` branch of the tool-module lookup sets `risk_tier: :unknown`. But `ToolProposal`'s `@risk_tier_values` (`tool_proposal.ex:22`) is `[:read_only, :low_write, :high_write, :destructive]` — `:unknown` is **not** a valid enum value. If this branch ever executed, `ToolProposal.blocked_changeset/2` would be invalid and the insert would fail — which, per CR-02, is then silently swallowed. The branch is currently dead (gate 0 guarantees the module exists by the time `propose_blocked` runs), but it is a latent landmine: it pairs an impossible-to-persist value with a path that hides insert errors.

**Fix:** Remove the dead branch (fold into WR-03's `{:ok, mod}` match), or if defensive code is wanted, raise loudly rather than fabricate an invalid enum value.

### WR-05: `Application.handle_conversation_resolved/4` swallows all Oban errors with a bare rescue

**File:** `lib/cairnloop/application.ex:45-49`
**Issue:**

```elixir
try do
  Oban.insert(job)
rescue
  _ -> :ok
end
```

A catch-all `rescue _` that returns `:ok` hides every failure mode (misconfiguration, DB down, serialization error) of the scrypath ingest enqueue. A dropped job here is invisible — no log, no telemetry. This is outside the Phase 13 proposal core but is in a reviewed file and is a genuine robustness defect.

**Fix:** Narrow the rescue to the specific expected exception (or handle the `{:error, _}` return of `Oban.insert/1` instead of rescuing), and at minimum `Logger.warning/1` the dropped job so it is observable.

### WR-06: Blocked path is missing duplicate pre-check, so the first blocked write can race a second into a constraint error

**File:** `lib/cairnloop/governance.ex:250-311`
**Issue:** `propose_valid/4` deliberately does a `get_by` pre-check before insert (lines 189-196) "to avoid the on_conflict footgun." `propose_blocked/5` has neither the pre-check nor the constraint-error recovery. Combined with CR-02, a repeated blocked submission (same actor, same params, same dedupe token) hits the unique index and the error vanishes. Even after CR-02 is fixed, the blocked path should match the valid path's defense-in-depth so the behavior is symmetric and testable.

**Fix:** Add the same `get_by(ToolProposal, idempotency_key: key)` pre-check used in `propose_valid/4`, returning the existing blocked proposal (and emitting `:proposal_duplicate`) on a hit.

## Info

### IN-01: No test coverage for `:scope_invalid` / `:policy_denied` LiveView flash messages

**File:** `test/cairnloop/web/conversation_live_test.exs:875-918`
**Issue:** The `execute_tool` tests cover happy path, `:unsupported`, and `:needs_input`, but not `:scope_invalid` or `:policy_denied`. This is precisely why CR-01 went undetected. Adding these two tests would both regression-guard CR-01 and document the operator-facing copy.
**Fix:** Add LiveView `handle_event("execute_tool", ...)` tests for a scope-failing tool and a policy-denying tool, asserting the flash string.

### IN-02: `propose/3` discards `propose_blocked/5`'s return value, returning stale `blocked` regardless of outcome

**File:** `lib/cairnloop/governance.ex:175-178`
**Issue:** Even independent of CR-02, returning the pre-computed `blocked` tuple instead of threading `propose_blocked`'s result means the caller can never learn whether persistence actually happened. This is a design smell that directly enables CR-02's silent swallow.
**Fix:** Decide on a contract: either `propose_blocked/5` always returns `:ok`/`{:error, _}` and `propose/3` reflects it, or keep returning `blocked` but only after confirming persistence succeeded.

### IN-03: `validate/3` catch-all `{:error, reason}` could misclassify a tool that returns `{:error, :unknown_tool}` from `authorize/2`

**File:** `lib/cairnloop/governance.ex:145-150`
**Issue:** The `else` block's final clause `{:error, reason} -> {:blocked, :policy_denied, reason}` is a catch-all. It correctly captures `authorize/2`'s 2-tuple today, but it would also catch any other 2-tuple `{:error, X}` and relabel it as `:policy_denied`. If a future `authorize/2` returns `{:error, :unknown_tool}` or similar, the outcome would be mislabeled. Low risk now, but the implicit coupling between clause shape (2-tuple vs 3-tuple) and intent is fragile.
**Fix:** Match `authorize`'s result explicitly (e.g. tag it before the `with`, or pattern-match the known authorize reasons) so the precedence mapping is not arity-dependent.

### IN-04: `tool_renderer/1` builds an empty form (`""` values) on every render — operator input is silently reset

**File:** `lib/cairnloop/web/conversation_live.ex:526-527`
**Issue:** `params = Enum.into(schema_fields, %{}, fn f -> {to_string(f), ""} end)` initializes every field to `""` each render. Because `execute_tool` for a needs_input block re-renders the pane via the normal flow, in-progress operator input in a tool form is not preserved across a failed submit (unlike the reply form, which is preserved deliberately). Not a correctness bug for Phase 13's propose-only scope, but worth noting for the Phase 14 UX seam.
**Fix:** When re-rendering after a `:needs_input` block, seed the form with the submitted `tool_params` so the operator does not lose their entry.

---

_Reviewed: 2026-05-23T21:20:11Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
