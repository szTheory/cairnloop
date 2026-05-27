---
phase: 25-bulk-selection-fan-out
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/cairnloop/governance.ex
  - lib/cairnloop/outbound.ex
  - lib/cairnloop/outbound/bulk_envelope.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/workers/outbound_worker.ex
  - priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs
  - test/cairnloop/governance_test.exs
  - test/cairnloop/outbound/bulk_envelope_test.exs
  - test/cairnloop/outbound_test.exs
  - test/cairnloop/web/inbox_live_test.exs
  - test/cairnloop/workers/outbound_worker_test.exs
findings:
  critical: 2
  warning: 6
  info: 4
  total: 12
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-05-27
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 25 lands the BulkEnvelope schema, `Outbound.bulk_trigger/2`, Oban dedup on
`OutboundWorker`, a narrow Governance cohort read, and an InboxLive cockpit. The
overall structural posture is sound — facade reads go through `Cairnloop.Governance`,
the envelope schema snapshots `rendered_body` at confirmation time, telemetry labels
are enum-only, and the sealed `trigger/2` public signature is preserved.

However, two correctness defects warrant blocking before ship:

1. `InboxLive.do_confirm_bulk_send/1` cannot pattern-match the `Ecto.Multi` failure
   4-tuple returned by `repo().transaction(multi)`. Any per-recipient changeset error
   on the happy path will crash the LiveView with a `FunctionClauseError` instead of
   producing the calm operator copy the plan promises.
2. `Outbound.bulk_trigger_refused/6` silently discards `repo().insert/1` failures on
   the audit envelope. A Postgres outage or changeset error will cause the operator
   to receive `{:error, :batch_too_large}` with no audit row recorded — defeating the
   OBS-02 "refused attempts persist" invariant the docstring promises.

Beyond those, a handful of warnings flag (a) a sealed-path behavior change in
`OutboundWorker` job-args shape that Phase 24 callers will observe, (b) inline
styles that bypass the brand-token discipline encoded in CLAUDE.md, (c) telemetry
metadata that contains caller PII for the `:outbound, :triggered` event (carried
over from Phase 22 but worth flagging now that bulk fan-out amplifies the labels),
and (d) several test-only structural fragilities.

## Critical Issues

### CR-01: InboxLive crashes on Ecto.Multi per-recipient changeset failure (unmatched 4-tuple)

**File:** `lib/cairnloop/web/inbox_live.ex:387-421`
**Issue:** `do_confirm_bulk_send/1` matches `outbound_module().bulk_trigger(ids, opts)`
on exactly three return shapes: `{:ok, _results}`, `{:error, :batch_too_large}`, and
`{:error, _other}` (a 2-tuple). But `Outbound.bulk_trigger/2` happy-path returns
`repo().transaction(multi)` directly from inside the telemetry span
(`lib/cairnloop/outbound.ex:272-274`). On `Ecto.Multi` failure, `Repo.transaction/1`
returns a 4-tuple `{:error, failed_operation, failed_value, changes_so_far}` — NOT a
2-tuple. None of the three clauses match a 4-tuple, so the LiveView process will
crash with a `FunctionClauseError` and the operator will see the generic Phoenix
error overlay instead of the planned calm "could not be queued right now" copy.

This is reachable in production: a single bad `Message` changeset (e.g., a
conversation_id that violates the FK once a real Postgres is wired up, or a metadata
size limit), and 25 selected conversations crash the inbox for the operator.

**Fix:**

```elixir
case outbound_module().bulk_trigger(ids, opts) do
  {:ok, _results} ->
    # ...success branch...

  {:error, :batch_too_large} ->
    # ...calm refusal copy...

  # Match the Ecto.Multi failure shape BEFORE the catch-all so we don't
  # crash on a per-recipient changeset error.
  {:error, _failed_op, _failed_value, _changes} ->
    {:noreply,
     socket
     |> put_flash(:error, "Recovery follow-up could not be queued right now. Please try again.")
     |> assign(:bulk_modal_open, false)
     |> assign(:bulk_preview, nil)
     |> assign(:bulk_refusal, nil)}

  {:error, _other} ->
    # existing fallback
end
```

Alternatively, normalize the return shape in `Outbound.bulk_trigger/2` so callers
only ever see `{:ok, results}` or `{:error, reason}`. Either fix is acceptable; the
LiveView clause-add is the smaller surgical change.

**Test gap:** Add a test in `inbox_live_test.exs` that pins the 4-tuple branch
(`Process.put(:stub_outbound_response, {:error, :step, %Ecto.Changeset{}, %{}})`)
and asserts the LiveView returns `{:noreply, _}` rather than raising.

---

### CR-02: Refused-envelope insert errors are silently swallowed, breaking OBS-02 audit guarantee

**File:** `lib/cairnloop/outbound.ex:213-215`
**Issue:** `bulk_trigger_refused/6` writes the audit envelope with:

```elixir
_ = repo().insert(BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs))
```

The leading `_ =` explicitly throws away the `{:ok, _} | {:error, changeset}` return.
If the insert fails (Postgres outage, changeset invalid, unique-constraint collision,
etc.), the operator still receives `{:error, :batch_too_large}` and the bulk telemetry
event still fires with `outcome: :refused_cap_exceeded` — but no row lands. The audit
trail OBS-02 (Phase 26) is supposed to read disappears.

The module docstring at `lib/cairnloop/outbound.ex:165-170` and the schema's own
`@moduledoc` at `lib/cairnloop/outbound/bulk_envelope.ex:5-7` BOTH advertise that
"refused attempts persist" as a guarantee. Silently dropping the error directly
breaks that contract.

This is also a direct departure from the cited analog: `Governance.propose_blocked/5`
threads its insert result back to the caller (`lib/cairnloop/governance.ex:288-291`
explicitly returns `{:error, cs}` on failure rather than swallowing it).

**Fix:**

```elixir
defp bulk_trigger_refused(conversation_ids, template_id, rendered_body, actor, count, cap) do
  envelope_id = Ecto.UUID.generate()
  envelope_attrs = %{...}

  case repo().insert(BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs)) do
    {:ok, _envelope} ->
      Cairnloop.Telemetry.execute(
        [:outbound, :bulk, :triggered],
        %{count: count},
        %{outcome: :refused_cap_exceeded, count: count}
      )
      {:error, :batch_too_large}

    {:error, changeset} ->
      # Log so operators see the audit-write failure; still return :batch_too_large
      # so the LiveView's calm refusal copy fires.
      require Logger
      Logger.error("BulkEnvelope refusal insert failed: #{inspect(changeset.errors)}")
      Cairnloop.Telemetry.execute(
        [:outbound, :bulk, :triggered],
        %{count: count},
        %{outcome: :refused_cap_exceeded_audit_failed, count: count}
      )
      {:error, :batch_too_large}
  end
end
```

(`inspect/1` on a changeset's `.errors` keyword list is acceptable in a Logger line —
T-15-13 forbids it for durable operator-visible columns; this is a structured-log
diagnostic for ops, not an operator-facing string.)

**Test gap:** Add a test in `outbound_test.exs` `describe "bulk_trigger/2"` that
seeds `MockRepo.insert/1` to return `{:error, %Ecto.Changeset{}}` for the
`BulkEnvelope` changeset and asserts the function still returns
`{:error, :batch_too_large}` AND that some observable signal (telemetry outcome
or log line) records the failure.

## Warnings

### WR-01: Sealed `OutboundWorker` job-args shape changed observably for Phase 24 callers

**File:** `lib/cairnloop/outbound.ex:126-131`
**Issue:** Pre-Phase-25 `trigger/2` enqueued jobs with `args: %{"message_id" => id}`.
Phase 25 changes this to always include `"conversation_id"`, `"template_id"`, and
`"bulk_envelope_id"` — even for Phase 24 single-recipient callers. The plan
documents this as "additively required for D-11", and existing tests at
`test/cairnloop/outbound_test.exs:113-119` pin the new shape.

CLAUDE.md's seal posture says "Don't churn sealed code paths (e.g. `propose/3`,
idempotency, co-commit) for downstream display concerns; prefer additive changes."
Adding keys to a job arg map IS additive in the strict superset sense, but any
downstream Oban consumer (e.g., custom retry policy, args-introspection in
a `Oban.Telemetry` handler, or a host that pattern-matches `args` strictly) WILL
observe the shape change. A Phase 24 host with a strict
`%{"message_id" => id} = args` clause in their notifier will crash.

This is on the borderline of the sealed-path rule. The Phase 25 plan locked OQ2
("Phase 24 callers DO participate in the new dedup; nil is a valid key value"), so
the decision is durable — but a defensive callout is in order.

**Fix:** Either (a) update the Phase 22/23/24 changelog / sealed-paths inventory in
`.planning/STATE.md` "Carried decisions" to record that Phase 25 expands
`OutboundWorker` job args additively, OR (b) document the new args shape in
`OutboundWorker.@moduledoc` so a host who pattern-matches strictly knows what
keys are now present (the worker docstring already mentions the keys but does
NOT explicitly say Phase 24 calls now also carry them).

### WR-02: InboxLive `mount/3` returns `{:ok, socket}` without `:layout`/`:temporary_assigns` and quietly drops a connected? branch

**File:** `lib/cairnloop/web/inbox_live.ex:61-80`
**Issue:** `mount/3` has a `connected?(socket)` block whose body is a comment placeholder:

```elixir
if connected?(socket) do
  # In a real app we would subscribe to a pubsub here
end
```

Two concerns:

1. The `if` evaluates its branch to `nil` and the result is discarded — dead control
   flow. The block compiles fine but produces no value and serves only as a TODO.
   At minimum, mark with `# TODO(phase XX):` so it doesn't read as an oversight.
2. The selection MapSet lives entirely in process memory. The docstring at line 72-74
   says "selection state is LiveView-local. No persistence across reloads" — that's
   fine. But if pubsub is added later (the comment hints at it), and a peer LiveView
   pushes a `:conversation_resolved` event mid-selection, the InboxLive will need to
   reconcile `@selected_ids` against the new `:conversations` list (since a no-longer-
   visible conversation could remain in `@selected_ids` and inflate the "Send recovery
   follow-up to N" button copy). Currently `@selected_ids` never gets pruned when
   conversations disappear.

**Fix:** Either remove the dead `if connected?(socket)` block entirely, or annotate
it with a phase-tracking TODO. For (2), add an `update_conversations/2` helper that
prunes `@selected_ids` against the new list when conversations change.

### WR-03: InboxLive inline-styles bypass brand token discipline; many hardcoded fallbacks

**File:** `lib/cairnloop/web/inbox_live.ex:92-263` (multiple lines)
**Issue:** Every styled element uses `style="..."` with inline declarations like:

```html
style="background: var(--cl-surface-raised, #FFFFFF); border-top: 1px solid var(--cl-border, #D8D0BF); ..."
```

CLAUDE.md says "Brand tokens over hardcoded hex (primary `var(--cl-primary, #A94F30)`)."
The CSS-variable form is correctly used, but the inline `style=""` attribute discipline
has two problems:

1. Inline styles are stylesheet duplication: the same `min-height: 44px; padding: 10px 16px;`
   declaration block is repeated five times across buttons. The brand book's button
   shape should live in `priv/static/css/cairnloop.css` (or equivalent) where the
   token cascade can override it consistently. A future brand revision (e.g., 48px
   touch targets) requires editing five string literals in one file.
2. Hardcoded fallback hex values (`#FFFFFF`, `#FBF7EE`, `#2f241d`, `#fffdf8`,
   `#D8D0BF`, `#A94F30`, `#B54C36`) are scattered throughout. While they ARE wrapped
   in `var(--cl-..., #...)` fallback form, the brand book is the canonical source
   of truth — a hex drift here will be silently inconsistent with the rest of the
   app's stylesheet.

**Fix:** Extract to named CSS classes:

```html
<button type="button" phx-click="clear_selection" class="cl-btn cl-btn--secondary">
  Clear selection
</button>
```

…and define `.cl-btn`, `.cl-btn--primary`, `.cl-btn--secondary`, `.cl-bulk-bar`,
`.cl-modal-dialog`, etc. once in the stylesheet. This is the same discipline
used in `conversation_live.ex` (per grep — that file uses class names, not inline
style strings for its rail).

### WR-04: `Outbound.trigger/2` telemetry metadata leaks `actor` PII into labels

**File:** `lib/cairnloop/outbound.ex:64-69, 71-82`
**Issue:** The telemetry `meta` map for `[:cairnloop, :outbound, :triggered]` contains
`conversation_id`, `template_id`, `schedule_in`, AND `actor`. The new `bulk_trigger/2`
event correctly emits enum-only labels (`outcome` + `count`), and `test/cairnloop/outbound_test.exs:388-393`
explicitly asserts no high-cardinality leak. But the OLD `trigger/2` event still
emits all four fields — and Phase 25's plan calls out telemetry-label hygiene as
load-bearing (research Pitfall 5; D-B enum-only invariant).

This is pre-existing (Phase 22), but Phase 25 amplifies the consequence: bulk
fan-out routes through `trigger/2`'s per-recipient lane, so a 25-recipient bulk
now emits 25 telemetry events each carrying `conversation_id` + `actor` as
metadata labels. Cardinality explosion + PII leakage to any attached Prometheus /
StatsD / Datadog handler.

**Fix:** Even if the carrying decision is to leave `trigger/2`'s labels alone for
backwards compatibility with existing telemetry consumers, document the asymmetry
in the moduledoc, OR (preferred) move `actor` and `conversation_id` to the
auditor metadata (durable row) and out of the `:telemetry` labels. If a host
truly needs per-recipient telemetry by actor, they can attach to the
`:bulk_outbound_trigger` auditor event instead.

### WR-05: `bulk_trigger_submit/6` cap is captured at submit-time but not enforced in the audit envelope's record

**File:** `lib/cairnloop/outbound.ex:229-275`
**Issue:** The cap value (`max_batch_size()`) is read fresh at line 187 (`cap = max_batch_size()`)
and only persisted into `refused_reason` on the refused path. The submit-path envelope
row records `count` and `recipient_conversation_ids` but does NOT record the cap that
was in effect at decision time. If ops tune `:cairnloop, :max_batch_size` between
two bulk attempts, an OBS-02 reader looking at two envelopes both with
`count: 20` cannot tell whether each was below or above the cap at the time.

**Fix:** Add an `:effective_cap` integer column to the BulkEnvelope schema +
migration, populated on BOTH refused AND submitted paths. This is a forward-compat
hardening; not blocking if the OBS-02 reader is scoped to "what happened" rather
than "what was the policy at the time".

### WR-06: `confirm_bulk_send` re-reads selection IDs and ignores the snapshot's eligibility filter

**File:** `lib/cairnloop/web/inbox_live.ex:376-385`
**Issue:** `do_confirm_bulk_send/1` does:

```elixir
ids = socket.assigns.selected_ids |> MapSet.to_list() |> Enum.sort()
```

…and passes those `ids` directly to `bulk_trigger/2`. But `open_bulk_confirm` at
line 319 calls `governance_module().preview_bulk_recovery_cohort(ids)` to FILTER
the cohort to `:resolved` conversations only (D-01 invariant). Between modal-open
and modal-confirm, two things can shift the cohort:

1. The user could (in a multi-tab scenario) resolve / unresolve a conversation
   in another tab; the LiveView in this tab still has the old `@conversations`
   assign and the now-ineligible id will be sent.
2. The preview's `eligible_ids` (which honors D-01) is captured into
   `bulk_preview.count` but NEVER fed back as the ground-truth `ids` to send.

The confirm path uses `MapSet.to_list(selected_ids)` — the raw selection — rather
than the snapshotted `preview.eligible_ids`. So the count displayed in the modal
(`preview.count`) can disagree with the count actually sent
(`length(MapSet.to_list(selected_ids))`).

The audit envelope will record the raw selection, which is technically what the
operator asked for, but the operator was shown a different filtered count.

**Fix:** Persist `eligible_ids` from the preview into `bulk_preview` and have
`do_confirm_bulk_send/1` use them:

```elixir
bulk_preview = %{
  count: count,
  eligible_ids: preview.eligible_ids,  # ADD
  sample: preview.sample,
  more: preview.more,
  rendered_body: rendered_body,
  template_id: template_id
}

# in do_confirm_bulk_send:
ids = preview.eligible_ids
```

This makes the snapshot guarantee explicit: what was shown is what was sent
(CLAUDE.md "snapshot trust facts at decision time").

## Info

### IN-01: `Outbound.bulk_trigger_refused/6` and `bulk_trigger_submit/6` duplicate envelope_attrs construction

**File:** `lib/cairnloop/outbound.ex:201-211, 233-242`
**Issue:** Both branches build a nearly identical map (id, template_id, rendered_body,
recipient_conversation_ids, count, requested_by, requested_at). DRY this into a
private `base_envelope_attrs/5` helper to make future column additions
(see WR-05 :effective_cap) a single edit instead of two.

### IN-02: `BulkEnvelope.changeset/2` allows status reset to nil via cast

**File:** `lib/cairnloop/outbound/bulk_envelope.ex:63-100`
**Issue:** `@castable` includes `:status`, but `:status` is not in `@required`.
A caller passing `%{status: nil}` will cast successfully and the schema default
(`:submitted`) will NOT re-apply (Ecto only applies field defaults on INSERT before
cast; cast overrides). The migration `null: false, default: "submitted"` is the
backstop, so the DB rejects it — but the error surfaces as a generic DB error
rather than a clean changeset validation message.

**Fix:** Add `validate_required(:status)` OR remove `:status` from `@castable` when
the caller intends to use the default. Low priority since the DB will catch it.

### IN-03: Test file `outbound_test.exs` MockRepo synthesizes IDs as `999` for all messages

**File:** `test/cairnloop/outbound_test.exs:54-58`
**Issue:** The MockRepo's `execute_multi` clause does
`Map.put(applied, :id, 999)` when `:id` is nil. In a multi-recipient bulk_trigger
test, every per-recipient Message will get `id: 999`, which means the assertion at
line 116 (`assert job.args["message_id"] == 999`) only happens to pass because
there's only one message. In the bulk-trigger tests at lines 252-264, message
identity is asserted via the `conversation_id` field and the `:"message_#{cid}"`
key, so it doesn't matter there. But if a future test wants to assert distinct
message IDs, the mock will lie.

**Fix:** Generate a unique id per insert (e.g., `System.unique_integer([:positive])`).

### IN-04: Migration's `cairnloop_outbound_bulk_envelopes` lacks index on `:status`

**File:** `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs:40-41`
**Issue:** Indexes exist on `:requested_at` and `:template_id`. OBS-02's most
likely scan ("show me all refused envelopes in the last 24h") is well-served by
the `:requested_at` index, but a "give me all refusals ever" or "what's the
refuse rate by template?" scan benefits from a composite or status-only index.

**Fix:** Optional follow-up. Add `create(index(:cairnloop_outbound_bulk_envelopes, [:status]))`
when OBS-02 lands its first reader and the actual query pattern is known.

---

_Reviewed: 2026-05-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
