# Phase 25: Bulk Selection & Fan-out - Research

**Researched:** 2026-05-27
**Domain:** Phoenix LiveView 1.0 multi-select UX over Ecto-backed conversations; Oban fan-out behind a sealed `Outbound.trigger/2` primitive.
**Confidence:** HIGH (all anchors verified against in-repo code; Phoenix LiveView 1.0 patterns verified against hexdocs and Phoenix Files; brand tokens verified against `prompts/cairnloop_brand_book.md`).

## Summary

Phase 25 grafts a bulk outbound flow onto an already-shipped per-conversation recovery affordance (Phase 24). All the destination semantics (sealed `Outbound.trigger/2`, `system_outbound` timeline lane, recovery template via `Application.get_env(:cairnloop, :outbound_recovery_template_id)`) exist in `lib/cairnloop/outbound.ex` and `lib/cairnloop/web/conversation_live.ex` and **must not** be redesigned. The phase's freedom is concentrated on the new envelope (`Outbound.bulk_trigger/2`), the LiveView UX (selection MapSet, sticky bar, modal), and a new `BulkEnvelope` durable record that snapshots template + recipients at confirmation time.

The cleanest mental model: `InboxLive` becomes a checkbox-driven multi-select surface whose **only outbound side effect** is calling `Outbound.bulk_trigger/2`. That envelope writes ONE `BulkEnvelope` row (the audit truth — OBS-02 shape), then calls the sealed `trigger/2` N times inside a single `Ecto.Multi`, threading `bulk_envelope_id` so per-recipient `Message` rows (and the `OutboundWorker` jobs they enqueue) carry a stable correlation key. Per-recipient idempotency is enforced at the Oban-job level (`unique: keys: [:bulk_envelope_id, :conversation_id, :template_id]`) — the codebase already uses this exact pattern for `ApprovalResumeWorker` and `ToolExecutionWorker`.

The cap (D-09, `max_batch_size = 25`) lives in two places (defense-in-depth, per the codebase's existing posture): LiveView refuses on submit with brand-aligned calm copy (D-10), and `bulk_trigger/2` raises `{:error, :batch_too_large}` at the envelope boundary for any non-UI caller.

**Primary recommendation:** Land a new `Cairnloop.Outbound.BulkEnvelope` schema with snapshotted recipient + rendered template body. Add `bulk_trigger/2` (uses one `Ecto.Multi` to insert envelope + N `Outbound.trigger/2` calls). Add `Cairnloop.Governance.list_eligible_conversation_ids_for_bulk_recovery/1` for the cohort-eligibility read. Add `bulk_envelope_id` and idempotency-key threading through `Outbound.trigger/2` opts (additive — preserves D-12 seal because callers without the opt see identical behavior). Wire `InboxLive` with a `selected_ids :: MapSet.t/0` assign, sticky bar at bottom, and a `<.focus_wrap>`-based confirmation modal that follows the existing `SearchModalComponent` styling vocabulary.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Checkbox state, sticky bar, modal | Frontend (Phoenix LiveView) | — | Pure UX state, lives in socket assigns per D-04 |
| Cohort eligibility read ("which conversation IDs are resolved-and-visible") | API / Backend (`Cairnloop.Governance` facade) | Database (`cairnloop_conversations` index on status) | D-14 forbids direct Ecto from web layer |
| Bulk envelope persistence (audit truth) | Database (`cairnloop_outbound_bulk_envelopes` table) | API / Backend (`Outbound.bulk_trigger/2`) | D-13 requires one durable row per bulk action |
| Template + recipient snapshot | API / Backend (`Outbound.bulk_trigger/2`) | Database (`BulkEnvelope` columns) | CLAUDE.md "snapshot at decision time; never re-read at render" |
| Per-recipient delivery | API / Backend (`Outbound.trigger/2` SEALED) | Worker (`OutboundWorker`) + Database (`Message` row + Oban job) | D-12 forbids modifying `trigger/2` shape |
| Idempotency (at-most-once per recipient) | Worker layer (`OutboundWorker` Oban job uniqueness) | Database (Oban's `oban_jobs` unique constraint) | Matches existing `ApprovalResumeWorker` pattern |
| Cap enforcement (D-09 hard fail-closed) | Frontend (early refusal w/ calm copy) AND API (`bulk_trigger/2` envelope guard) | — | Defense-in-depth per existing facade posture |
| Refusal copy (D-10 calm, icon+text) | Frontend (`InboxLive` template) | — | Brand book §5.6, §7.5 — never color-alone |
| Telemetry (`:bulk`, enum labels only) | API / Backend (`Outbound.bulk_trigger/2`) | — | D-B enum-only labels; D-C telemetry not for UI |

## Standard Stack

All tooling is **already in the repo**. Phase 25 adds zero new dependencies.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | `~> 1.0` (mix.exs:89) | LiveView surface for selection, modal | Already installed; 1.0 ships `<.focus_wrap>` + `Phoenix.Component.attr/slot` [VERIFIED: mix.exs] |
| `ecto_sql` | `~> 3.10` (mix.exs:85) | `Ecto.Multi` for atomic envelope + fan-out | Pattern used in `Outbound.trigger/2` and `Governance.propose/3` [VERIFIED: lib/cairnloop/outbound.ex] |
| `oban` | `~> 2.17` (mix.exs:91) | Per-recipient worker enqueue + idempotency | `unique: [keys: …]` pattern already used in `ApprovalResumeWorker` and `ToolExecutionWorker` [VERIFIED: lib/cairnloop/workers/approval_resume_worker.ex:36] |
| `jason` | `~> 1.2` (mix.exs:90) | JSONB snapshot serialization | Used in `Governance.derive_idempotency_key` [VERIFIED: lib/cairnloop/governance.ex:212] |
| `:telemetry` | std lib via `Cairnloop.Telemetry` | Bounded enum-label events | `Cairnloop.Telemetry.execute/3` already exists [VERIFIED: lib/cairnloop/telemetry.ex] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Phoenix.LiveView.JS` | bundled with `phoenix_live_view` | `JS.push_focus()` / `JS.pop_focus()` / `JS.focus()` for modal accessibility | Required for D-07 modal (focus into modal on open; restore on cancel) [CITED: hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| `Phoenix.Component` | bundled | `attr/3` + `slot/3` + `focus_wrap/1` | Modal markup [VERIFIED: lib/cairnloop/web/conversation_live.ex:823 `attr(:conversation, :map, required: true)`] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit `MapSet` in assigns (D-04) | `Phoenix.LiveView.stream` + per-row checked state | Streams hide the cohort from server (per Phoenix Files article, "the LiveView process does not know which breweries are on the page"). Rejected by D-04 — selection MUST live in assigns to support cohort preview & cap check. |
| New `BulkEnvelope` schema | Threading `bulk_envelope_id` as a UUID on each `Message` metadata field | Rejected. Per D-13 a single audit row per bulk action is required ("records a single audit envelope row"). A metadata-only approach has no canonical row to query for "how many bulk actions happened?" (OBS-02). |
| `phoenix_multi_select` library | (third-party, hexdocs) | Rejected. The library is designed for typeahead/tag picker UX — not table-row bulk-action selection. The 44-line InboxLive baseline doesn't justify a dep, and the brand book prefers operator-cockpit shape over generic widgets. |
| Long-poll / JS hook for "select all visible" | Pure `phx-click` + `MapSet` math in `handle_event` | D-04 says state lives in assigns; D-02 restricts to visible rows. Since the visible cohort IS the server's `@conversations`, no JS hook is needed — the LiveView already knows which IDs are visible. |

**Installation:** No new packages. Verified against `mix.exs` lines 85–96.

**Version verification (already on disk):**
```bash
# In repo
grep -A1 "phoenix_live_view" mix.exs   # ~> 1.0
grep -A1 "oban" mix.exs                # ~> 2.17
```

## Package Legitimacy Audit

Phase 25 adds **zero new packages**. All dependencies (`phoenix_live_view ~> 1.0`, `ecto_sql ~> 3.10`, `oban ~> 2.17`, `jason ~> 1.2`) are already locked in `mix.exs` and were vetted in earlier milestones (vM009–vM012). No `slopcheck` run needed.

| Package | Registry | Age | Disposition |
|---------|----------|-----|-------------|
| (none added in Phase 25) | — | — | — |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
Operator (browser)
   │
   │  click checkbox on conversation row
   ▼
InboxLive.handle_event("toggle_select", %{"id" => id})
   │     │ MapSet.put/MapSet.delete on @selected_ids
   │     │ if @selected_ids empty → hide sticky bar; else show
   │     │
   │     └─→ assign(:selected_ids, …) → re-render row + sticky bar
   │
   │  click "Send recovery follow-up to N"
   ▼
InboxLive.handle_event("open_bulk_confirm", _)
   │
   │  fetch cohort preview (recipient labels, count) via the narrow facade
   ▼
Cairnloop.Governance.preview_bulk_recovery_cohort(selected_ids)  ── narrow read (D-14)
   │
   │   if MapSet.size > @max_batch_size  → assign(:bulk_refusal, calm copy)  [D-10]
   │   else                              → assign(:bulk_preview, %{count, sample_5, body, +N more})
   ▼
Modal renders (Phoenix.Component + <.focus_wrap>)
   │
   │  operator clicks "Confirm send"
   ▼
InboxLive.handle_event("confirm_bulk_send", _)
   │
   │   call envelope (NOT trigger/2 directly)
   ▼
Cairnloop.Outbound.bulk_trigger(conversation_ids, opts)         ── NEW (D-13)
   │
   │  cap re-check {:error, :batch_too_large} on > max_batch_size
   │
   │  Ecto.Multi:
   │   1) insert %BulkEnvelope{id: uuid, template_id, recipient_ids_snapshot,
   │                            rendered_body, requested_by, requested_at, count}
   │   2) for each conv_id: Outbound.trigger(conv_id,
   │                          template_id: ..., actor: ...,
   │                          bulk_envelope_id: env.id)        ── SEALED, additive opt
   │
   ▼
For each Outbound.trigger/2 call (existing sealed path):
   │  Ecto.Multi.insert(message)         (system_outbound, metadata.bulk_envelope_id)
   │  Ecto.Multi.insert(OutboundWorker.new(..., unique: [keys: [:bulk_envelope_id,
   │                                                            :conversation_id,
   │                                                            :template_id]]))
   ▼
Oban runs each OutboundWorker job  → Chimeway delivery  → updates Message.metadata.status
                                                          (no change to D-A — still
                                                           one system_outbound card per recipient)
```

The diagram intentionally collapses to ONE arrow at the `Outbound.trigger/2` boundary — that surface is **sealed** by D-12 and Phase 23/24 carry; the envelope must call it without modifying its shape (the new `bulk_envelope_id` is an additive opt with a `nil` default — see "Sealed-Primitive Additive Opt" pattern below).

### Recommended Project Structure
```
lib/cairnloop/
├── outbound.ex                                 # add bulk_trigger/2 (sealed trigger/2 unchanged)
├── outbound/
│   └── bulk_envelope.ex                        # NEW Ecto schema (D-13)
├── governance.ex                               # extend facade with cohort preview read (D-14)
├── workers/
│   └── outbound_worker.ex                      # add unique: opts; honor bulk_envelope_id (D-11)
└── web/
    ├── inbox_live.ex                           # selection state, sticky bar, handlers
    └── inbox_live/
        └── bulk_confirm_component.ex           # LiveComponent for modal (matches SearchModalComponent shape)

priv/repo/migrations/
└── 20260527000000_add_outbound_bulk_envelopes.exs   # NEW migration

test/cairnloop/
├── outbound_test.exs                           # extend: bulk_trigger/2 happy path, cap, snapshot
├── outbound/
│   └── bulk_envelope_test.exs                  # NEW headless schema test
├── governance_test.exs                         # extend: cohort preview read
├── workers/
│   └── outbound_worker_test.exs                # extend: uniqueness key
└── web/
    └── inbox_live_test.exs                     # extend: selection MapSet, modal, refusal copy
```

### Pattern 1: Sealed-Primitive Additive Opt (D-12 preservation)
**What:** Add an optional keyword to `Outbound.trigger/2` (`:bulk_envelope_id`) with a `nil` default, propagated into `Message.metadata` and the Oban job args. Existing callers (e.g., `ConversationLive.handle_event("trigger_recovery_follow_up", …)` at lib/cairnloop/web/conversation_live.ex:210) pass nothing and observe identical behavior.
**When to use:** When a downstream feature needs a correlation key on the same primitive surface that's been declared sealed.
**Example:**
```elixir
# lib/cairnloop/outbound.ex — additive change
def trigger(conversation_id, opts) do
  template_id = Keyword.fetch!(opts, :template_id)
  bulk_envelope_id = Keyword.get(opts, :bulk_envelope_id)  # NEW additive opt
  # ... rest unchanged. bulk_envelope_id flows into:
  #   1) Message.metadata["bulk_envelope_id"]
  #   2) OutboundWorker.new(%{"message_id" => id, "bulk_envelope_id" => bulk_envelope_id}, …)
end
```
This is the same shape used by `Governance.request_approval/2` for the injectable `enqueue_fn` opt — additive, defaulted, no test regressions for existing callers. [VERIFIED: lib/cairnloop/governance.ex:634]

### Pattern 2: One `Ecto.Multi` for Envelope + Fan-out
**What:** `bulk_trigger/2` builds a single `Ecto.Multi` that inserts the `BulkEnvelope` first, then merges N `Outbound.trigger/2` calls' multis via `Ecto.Multi.merge/2` (the codebase's existing fan-out idiom — see `Chat.reply_to_conversation` and `Outbound.trigger/2` itself).
**When to use:** When a single atomic boundary must own "envelope + N child writes."
**Example:**
```elixir
# lib/cairnloop/outbound.ex — NEW
def bulk_trigger(conversation_ids, opts) do
  if length(conversation_ids) > max_batch_size() do
    {:error, :batch_too_large}
  else
    template_id = Keyword.fetch!(opts, :template_id)
    actor = Keyword.get(opts, :actor)
    rendered_body = render_template_body(template_id, opts)

    envelope_attrs = %{
      id: Ecto.UUID.generate(),
      template_id: template_id,
      recipient_conversation_ids: conversation_ids,
      rendered_body: rendered_body,
      requested_by: actor,
      requested_at: DateTime.utc_now(),
      count: length(conversation_ids)
    }

    Cairnloop.Telemetry.span([:outbound, :bulk, :triggered],
      %{count: length(conversation_ids), template_id: template_id}, fn ->
        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:envelope,
              BulkEnvelope.changeset(%BulkEnvelope{}, envelope_attrs))
          |> Ecto.Multi.merge(fn %{envelope: env} ->
            Enum.reduce(conversation_ids, Ecto.Multi.new(), fn cid, acc ->
              # Merge each trigger/2's own multi — keeps trigger/2 sealed.
              Ecto.Multi.merge(acc, fn _ ->
                {:ok, results} = call_trigger_isolated(cid, opts ++ [bulk_envelope_id: env.id])
                # …or build the per-recipient multi here directly; see "Open Question 1"
              end)
            end)
          end)
          |> auditor().audit(:bulk_outbound_trigger, actor,
                             %{bulk_envelope_id: envelope_attrs.id, count: envelope_attrs.count})

        {repo().transaction(multi), meta}
    end)
  end
end
```

> **Note for planner:** the `Ecto.Multi.merge` shape here is a sketch. The cleanest implementation is to refactor a small private `build_trigger_multi/2` inside `Outbound` so both `trigger/2` and `bulk_trigger/2` reuse the same per-recipient multi-builder — see Open Question 1. This is additive (no behavior change to `trigger/2`).

### Pattern 3: Per-recipient Oban uniqueness via `unique: keys:` (D-11)
**What:** Idempotency key `(conversation_id, template_id, bulk_envelope_id)` is enforced by Oban itself via `unique: [period: :infinity, fields: [:worker, :args], keys: [:conversation_id, :template_id, :bulk_envelope_id]]`. No new DB constraint needed.
**When to use:** Whenever at-most-once semantics for a job class are required and the dedup key is composable from `args`.
**Example:**
```elixir
# lib/cairnloop/workers/outbound_worker.ex
use Oban.Worker,
  queue: :default,
  unique: [period: :infinity, fields: [:worker, :args],
           keys: [:conversation_id, :template_id, :bulk_envelope_id]]

# args shape must include all three keys at insert time:
OutboundWorker.new(%{
  "message_id" => message.id,
  "conversation_id" => conversation_id,
  "template_id" => template_id,
  "bulk_envelope_id" => bulk_envelope_id   # nil for single-conversation triggers — Oban treats nil as a valid key value
}, [])
```
[VERIFIED: lib/cairnloop/workers/approval_resume_worker.ex:36 uses the same `unique:` shape; CITED: hexdocs.pm/oban/unique_jobs.html]

**Important:** For single-conversation (Phase 24) callers `bulk_envelope_id` is `nil`. Oban will still uniquify against `(conversation_id, template_id, nil)`. If two single-conversation recoveries with the same template arrive back-to-back, the **second one is correctly deduped** — which matches Phase 24's intended behavior. If the planner wants single-conversation triggers to bypass this guard, they must change the keys to include a discriminator (e.g., `message_id`). See Open Question 2.

### Pattern 4: `<.focus_wrap>` + `JS.push_focus`/`JS.pop_focus` Modal (D-07 / D-08)
**What:** Phoenix LiveView 1.0's `Phoenix.Component.focus_wrap/1` keeps tab focus inside the modal; `JS.push_focus()` on open captures the trigger element; `JS.pop_focus()` on cancel restores it.
**When to use:** Any modal that gates a destructive or important action.
**Example:**
```elixir
# lib/cairnloop/web/inbox_live/bulk_confirm_component.ex (or inline in InboxLive)
def render(assigns) do
  ~H"""
  <%= if @open do %>
    <div role="dialog" aria-modal="true" aria-labelledby="bulk-confirm-title"
         class="bulk-confirm-backdrop"
         phx-window-keydown="cancel_bulk_confirm" phx-key="Escape">
      <.focus_wrap id="bulk-confirm-wrap">
        <div class="bulk-confirm-dialog">
          <h2 id="bulk-confirm-title">Send recovery follow-up</h2>

          <p>You're about to send to <strong><%= @count %></strong> conversation(s).</p>

          <ul class="recipient-sample" aria-label="First 5 recipients">
            <li :for={label <- @sample}><%= label %></li>
          </ul>
          <%= if @more > 0 do %>
            <p class="recipient-more">+ <%= @more %> more</p>
          <% end %>

          <section aria-label="Message body">
            <h3>Message</h3>
            <p class="rendered-body"><%= @rendered_body %></p>
          </section>

          <div class="bulk-confirm-actions">
            <button type="button" phx-click="cancel_bulk_confirm">Cancel</button>
            <button type="button" phx-click="confirm_bulk_send"
                    style="background: var(--cl-primary, #A94F30); color: #fffdf8;">
              Confirm send
            </button>
          </div>
        </div>
      </.focus_wrap>
    </div>
  <% end %>
  """
end
```
The trigger (the sticky-bar "Send recovery follow-up to N" button) uses:
```elixir
phx-click={JS.push_focus() |> JS.push("open_bulk_confirm")}
```
And on cancel, `cancel_bulk_confirm` returns `{:noreply, … |> push_event("pop-focus", %{}) }` — or, simpler, the button itself runs `phx-click={JS.pop_focus() |> JS.push("cancel_bulk_confirm")}`.
[CITED: fly.io/phoenix-files/liveview-accessible-focus/ and hexdocs.pm/phoenix_live_view/Phoenix.Component.html — VERIFIED: phoenix_live_view ~> 1.0 in mix.exs:89]

### Anti-Patterns to Avoid
- **Storing selection state in LocalStorage / phx-hook.** D-04 forbids persistence; assigns-only is the contract.
- **Computing the cohort at worker time.** The cohort MUST be snapshotted at confirmation (D-13 + CLAUDE.md "snapshot at decision time"). Workers read from the `BulkEnvelope` row, never re-resolve eligibility.
- **Calling `Outbound.trigger/2` from outside `bulk_trigger/2` for bulk fan-out.** Defeats audit single-source-of-truth (D-13 "records a single audit envelope row").
- **State-by-color-alone refusal banner.** Brand book §7.5 + D-10: refusal MUST carry icon + text + (optional) color. Use `var(--cl-danger, #B54C36)` for color but never make color the only signal.
- **`Phoenix.LiveView.stream` for the conversation list.** Streams remove the cohort from server memory, breaking "select all visible" math and cap check. Per Phoenix Files article: "when using LiveView streams, the LiveView process does not know which breweries are on the page." D-04 implicitly forbids streams by mandating `MapSet` in assigns.
- **Direct `repo()` query in `InboxLive` for eligibility.** D-14 violation. Always go through `Cairnloop.Governance`.
- **Bumping `Outbound.trigger/2`'s signature.** Even adding a required positional arg breaks D-12. Only ADD optional keys with `nil` defaults.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-job dedup for at-most-once delivery | A custom Postgres `UNIQUE` constraint on `(conversation_id, template_id, bulk_envelope_id)` over `messages` or a new table | Oban's `unique: [period: :infinity, keys: [...]]` | Oban already provides this. The codebase uses it for `ApprovalResumeWorker` and `ToolExecutionWorker`. Custom constraints risk drift; Oban centralizes the policy. [VERIFIED: lib/cairnloop/workers/approval_resume_worker.ex:36] |
| Modal focus management | Custom JS hook with `tabindex` math | `Phoenix.Component.focus_wrap/1` + `JS.push_focus/pop_focus` | LiveView 1.0 ships these; hand-rolled focus traps are a well-known accessibility footgun. [CITED: hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| UUID generation | `:crypto.strong_rand_bytes` + base64 munging | `Ecto.UUID.generate/0` | The Cairnloop codebase uses `:crypto.hash` for deterministic hashes (idempotency keys) but **`Ecto.UUID.generate/0` for opaque IDs** is the conventional choice. [VERIFIED: lib/cairnloop/governance.ex:214 hashes; envelope IDs should use Ecto.UUID] |
| "Select all visible" tristate logic | A JS hook (per Phoenix Files article) | A `MapSet` comparison in `handle_event`: `MapSet.equal?(MapSet.new(visible_ids), @selected_ids) → "all"; MapSet.size(@selected_ids) > 0 → "some"; else → "none"` | Because the server knows the visible cohort (`@conversations`), a JS hook is unnecessary and creates an extra round-trip. D-04 keeps state in assigns. |
| Atomic envelope + N message inserts | Custom `Repo.transaction` with manual rollback | `Ecto.Multi.new() |> insert(:envelope, ...) |> merge(fn _ → fan_out_multi end)` | The repo's standard idiom (see `Chat.reply_to_conversation`, `Outbound.trigger/2`). Lets the auditor inject its own multi step (Cairnloop.Auditor behaviour). [VERIFIED: lib/cairnloop/auditor.ex] |
| Cohort eligibility read | Inline `Conversation |> where(status: :resolved) |> repo().all()` in `InboxLive` | New function on `Cairnloop.Governance` facade (e.g., `Governance.list_eligible_conversation_ids_for_bulk_recovery/1`) | D-14. The facade is the narrow read contract. |
| Telemetry event filtering by `conversation_id` / `actor_id` | Custom telemetry handler that drops high-cardinality labels | Allow-list enum normalizer on emit (see `Cairnloop.Governance.Telemetry.normalize_outcome/1`) | D-B enum-only labels. The pattern already exists. [VERIFIED: lib/cairnloop/governance/telemetry.ex] |

**Key insight:** Phase 25 is overwhelmingly **composition** of existing patterns: sealed primitive + new envelope, `MapSet` in assigns, `Ecto.Multi.merge`, Oban `unique: keys:`, `Cairnloop.Telemetry.span`, `Cairnloop.Auditor` injection, `Phoenix.Component` + `focus_wrap`. The only genuinely new artifact is the `BulkEnvelope` schema. Everything else is a re-application of an in-repo pattern.

## Runtime State Inventory

Phase 25 is mostly greenfield code addition, but it does have one rename-adjacent consideration: the **idempotency key shape** of `OutboundWorker` is changing (D-11 adds `bulk_envelope_id` to the key tuple). For any in-flight Oban jobs or pending sends from Phase 24, this is a code-only change — there is no migration of existing rows because (a) the Cairnloop repo does not have production data in this workspace (REPO-UNAVAILABLE), and (b) Phase 24 jobs are short-lived (queue: :default).

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `Cairnloop.Message` rows with `role: :system_outbound` exist from Phase 24 — they have `metadata: %{"template_id", "status"}` but no `bulk_envelope_id`. **No backfill required** — single-conversation Phase 24 sends keep `bulk_envelope_id: nil`. | None (additive). |
| Live service config | Oban worker config in host application | Code-only: add `unique:` clause to `OutboundWorker`. Oban will start enforcing uniqueness for new jobs. No external service config touched. |
| OS-registered state | None — Cairnloop is a library, no daemons of its own. | None. |
| Secrets/env vars | New: `:max_batch_size` (D-09) under the `:cairnloop` app env. Default 25. | Document in `mix help cairn_loop.doctor`-style guidance if such a path exists; otherwise just document in `Outbound` module docstring. |
| Build artifacts | None — pure Elixir compilation. | `mix compile --warnings-as-errors` must pass (D-15). |

**The canonical question — runtime state surviving a rename — does NOT apply** because Phase 25 is additive, not a rename. The only "thing that becomes nil instead of absent" is `Message.metadata["bulk_envelope_id"]`, which is `nil` for pre-Phase-25 rows and unproblematic because no read path requires it.

## Common Pitfalls

### Pitfall 1: Forgetting that Oban `unique: keys:` uses *nil-equality*, not "exclude when nil"
**What goes wrong:** Two single-conversation recoveries (Phase 24 callers, `bulk_envelope_id: nil`) for the same `(conversation_id, template_id)` are silently deduped after the first one is enqueued.
**Why it happens:** Oban's `unique` key matches `nil` as a value, not as a wildcard.
**How to avoid:** Confirm via test that two Phase 24 recoveries with the same template ID, dispatched in quick succession, BOTH enqueue (or BOTH are deduped — whichever the team decides is correct). If "both should enqueue," the simplest fix is to **always pass a value** for the key — e.g., use `Ecto.UUID.generate()` for a "single-conversation envelope" stub. See Open Question 2.
**Warning signs:** A retest of Phase 24 behavior in `outbound_worker_test.exs` shows only one Oban job inserted when two were attempted.

### Pitfall 2: Snapshotting the *template_id* instead of the *rendered body*
**What goes wrong:** A template change between confirmation and Oban-job execution causes the wrong copy to be sent — silently. The operator confirmed message X; recipients receive message Y.
**Why it happens:** "Snapshot the template" is ambiguous — `template_id` is a reference, not the content. Per CLAUDE.md: "Snapshot trust facts at decision time; never re-read live config at render time."
**How to avoid:** `BulkEnvelope.rendered_body` is a `:string` (or `:text`) column populated AT CONFIRMATION TIME. `OutboundWorker.perform/1` MUST read `rendered_body` from `Message.metadata["bulk_envelope_id"] |> BulkEnvelope` (or from `Message.content` if the body was inlined per Pattern 2). Worker never reloads the template from `Application.get_env`.
**Warning signs:** A test that mutates `Application.put_env(:cairnloop, :outbound_recovery_template_id, "v2")` between confirmation and worker run shows v2 copy in the delivered message.

### Pitfall 3: "Select all visible" not respecting filter changes (D-04 clearing)
**What goes wrong:** Operator filters inbox by "Refunds" → selects 8 → switches filter to "Billing" → 8 selections still active (now invisible). Cap check could let through 25 invisible recipients.
**Why it happens:** Filter `handle_event` forgets to `assign(:selected_ids, MapSet.new())`.
**How to avoid:** Centralize "clear selection" into a helper, call it from EVERY filter/navigate handler. Headless test: dispatch a fake filter event and assert `assigns.selected_ids == MapSet.new()`.
**Warning signs:** Modal preview shows recipient labels not present in the currently rendered list.

### Pitfall 4: Cap check only on the LiveView side
**What goes wrong:** A future MCP write-tool caller (vM012 surface, see CLAUDE.md "MCP write surfaces… are available for use in outbound triggers if needed") sends 200 conversation IDs straight to `bulk_trigger/2`, bypassing the LiveView refusal.
**Why it happens:** Single-point-of-truth on the UI is the most common defense-in-depth failure mode.
**How to avoid:** `bulk_trigger/2` MUST validate `length(conversation_ids) <= max_batch_size()` and return `{:error, :batch_too_large}` regardless of caller. The LiveView's calm refusal is for UX; the envelope's hard guard is for safety.
**Warning signs:** A test that calls `Outbound.bulk_trigger(List.duplicate(1, 100), …)` succeeds.

### Pitfall 5: Telemetry label leak — `template_id` is high-cardinality
**What goes wrong:** Emitting `[:cairnloop, :outbound, :bulk, :triggered]` with `template_id: "recovery_v1"` as a label is fine NOW (one template), but D-B is a project-wide invariant. Operator may add many templates later.
**Why it happens:** "template_id" looks like a tiny enum but isn't formally bounded.
**How to avoid:** Either (a) treat `template_id` as a bounded enum normalized against `Application.get_env(:cairnloop, :outbound_templates, [])` (mirrors the `tool_ref` normalizer in `Cairnloop.Governance.Telemetry`), or (b) drop it from telemetry labels entirely and keep only `outcome` (`:sent`, `:refused_cap_exceeded`, `:partial_persist_failure`). Option (b) is simpler and discharges the rule trivially.
[VERIFIED: lib/cairnloop/governance/telemetry.ex:109-117 — pattern to mirror.]

### Pitfall 6: Modal cancel losing selection (D-08 violation)
**What goes wrong:** Cancelling the modal also clears `@selected_ids`, forcing the operator to start over.
**Why it happens:** A copy-paste from "Clear selection" handler.
**How to avoid:** `cancel_bulk_confirm` resets ONLY the modal-related assigns (`@bulk_preview`, `@bulk_modal_open`), never `@selected_ids`.
**Warning signs:** A headless test that selects 3 conversations, opens the modal, cancels, and expects `MapSet.size(assigns.selected_ids) == 3` — fails.

### Pitfall 7: Test data poisoning across `async: false` test files
**What goes wrong:** Phase 25 introduces `Application.put_env(:cairnloop, :max_batch_size, 3)` in a test. A later test in the same file expects default cap 25 and times out / passes by accident.
**Why it happens:** `async: false` shares Application env across describes.
**How to avoid:** Always use `setup` + `on_exit(fn -> Application.delete_env(:cairnloop, :max_batch_size) end)` — matches the `OutboundTest` and `OutboundWorkerTest` existing patterns. [VERIFIED: test/cairnloop/outbound_test.exs:42-49]

## Code Examples

### Selection toggle in `InboxLive`
```elixir
# lib/cairnloop/web/inbox_live.ex (additive)
def handle_event("toggle_select", %{"id" => id_str}, socket) do
  id = String.to_integer(id_str)
  selected = socket.assigns.selected_ids

  new_selected =
    if MapSet.member?(selected, id) do
      MapSet.delete(selected, id)
    else
      MapSet.put(selected, id)
    end

  {:noreply, assign(socket, :selected_ids, new_selected)}
end

def handle_event("toggle_select_all_visible", _params, socket) do
  visible_eligible = visible_eligible_ids(socket.assigns.conversations)
  selected = socket.assigns.selected_ids

  new_selected =
    if Enum.all?(visible_eligible, &MapSet.member?(selected, &1)) do
      # All visible are selected → un-select them
      Enum.reduce(visible_eligible, selected, &MapSet.delete(&2, &1))
    else
      # Some/none visible selected → select all
      Enum.reduce(visible_eligible, selected, &MapSet.put(&2, &1))
    end

  {:noreply, assign(socket, :selected_ids, new_selected)}
end

defp visible_eligible_ids(conversations) do
  conversations
  |> Enum.filter(&(&1.status == :resolved))
  |> Enum.map(& &1.id)
end
```

### Render checkbox + sticky bar
```elixir
<%= for conv <- @conversations do %>
  <li>
    <%= if conv.status == :resolved do %>
      <input type="checkbox"
             phx-click="toggle_select"
             phx-value-id={conv.id}
             checked={MapSet.member?(@selected_ids, conv.id)}
             aria-label={"Select conversation: #{conv.subject || "No subject"}"} />
    <% end %>
    <.link navigate={"/#{conv.id}"}>
      <strong><%= conv.subject || "No Subject" %></strong> — <%= conv.status %>
    </.link>
  </li>
<% end %>

<%= if MapSet.size(@selected_ids) > 0 do %>
  <div role="region" aria-label="Bulk actions" class="bulk-action-bar"
       style="position: sticky; bottom: 0; background: var(--cl-surface-raised, #FFFFFF);
              border-top: 1px solid var(--cl-border, #D8D0BF); padding: 12px 16px;
              display: flex; gap: 12px; align-items: center;">
    <span><strong><%= MapSet.size(@selected_ids) %></strong> selected</span>
    <button type="button" phx-click="clear_selection">Clear selection</button>
    <button type="button"
            phx-click={JS.push_focus() |> JS.push("open_bulk_confirm")}
            style="background: var(--cl-primary, #A94F30); color: #fffdf8;
                   border-radius: 8px; min-height: 44px; padding: 10px 16px;">
      Send recovery follow-up to <%= MapSet.size(@selected_ids) %>
    </button>
  </div>
<% end %>
```

### Calm refusal banner (D-10)
```elixir
<%= if @bulk_refusal do %>
  <div role="alert" class="bulk-refusal"
       style="background: rgba(181, 76, 54, 0.08);
              border: 1px solid var(--cl-danger, #B54C36);
              padding: 12px; display: flex; gap: 12px; align-items: flex-start;">
    <%# icon + text — never color alone (brand §7.5, D-10) %>
    <svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" fill="none">
      <circle cx="10" cy="10" r="9" stroke="currentColor" stroke-width="1.5"/>
      <path d="M10 6v5M10 13.5v.5" stroke="currentColor" stroke-width="1.5"/>
    </svg>
    <div>
      <strong>Batch too large.</strong>
      <p style="margin: 4px 0 0; color: var(--cl-text, #18211F);">
        This batch exceeds the safe send limit of <%= @max_batch_size %>.
        Narrow your selection and try again.
      </p>
    </div>
  </div>
<% end %>
```

### `BulkEnvelope` schema
```elixir
# lib/cairnloop/outbound/bulk_envelope.ex
defmodule Cairnloop.Outbound.BulkEnvelope do
  @moduledoc """
  Durable audit envelope for a bulk outbound action (D-13, OBS-02-shaped).
  Snapshots template_id, rendered_body, and recipient cohort at confirmation time.
  Per-recipient delivery flows through Outbound.trigger/2 (sealed) carrying the envelope id.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "cairnloop_outbound_bulk_envelopes" do
    field :template_id, :string
    # Snapshotted at confirmation time — never re-read at worker run time (CLAUDE.md).
    field :rendered_body, :string
    field :recipient_conversation_ids, {:array, :integer}
    field :count, :integer
    field :requested_by, :string
    field :requested_at, :utc_datetime_usec
    # Status: :submitted (fan-out enqueued); per-recipient delivery status lives on Message rows.
    field :status, Ecto.Enum, values: [:submitted, :refused_cap_exceeded], default: :submitted
    field :refused_reason, :string

    timestamps()
  end

  def changeset(envelope, attrs) do
    envelope
    |> cast(attrs, [:id, :template_id, :rendered_body, :recipient_conversation_ids,
                    :count, :requested_by, :requested_at, :status, :refused_reason])
    |> validate_required([:id, :template_id, :rendered_body, :recipient_conversation_ids,
                          :count, :requested_at])
    |> validate_number(:count, greater_than: 0)
  end
end
```

### Migration
```elixir
# priv/repo/migrations/20260527000000_add_outbound_bulk_envelopes.exs
defmodule Cairnloop.Repo.Migrations.AddOutboundBulkEnvelopes do
  use Ecto.Migration

  def change do
    create table(:cairnloop_outbound_bulk_envelopes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_id, :string, null: false
      add :rendered_body, :text, null: false
      add :recipient_conversation_ids, {:array, :bigint}, null: false
      add :count, :integer, null: false
      add :requested_by, :string
      add :requested_at, :utc_datetime_usec, null: false
      add :status, :string, null: false, default: "submitted"
      add :refused_reason, :string

      timestamps()
    end

    create index(:cairnloop_outbound_bulk_envelopes, [:requested_at])
    create index(:cairnloop_outbound_bulk_envelopes, [:template_id])
  end
end
```

### Governance facade extension
```elixir
# lib/cairnloop/governance.ex (additive)
@doc """
Returns the list of conversation ids that are currently eligible to be targets of a
bulk recovery follow-up. v1 eligibility: `status == :resolved`. Restricted to the
caller-supplied candidate id set (the LiveView's currently visible filtered cohort
per D-02).
"""
def list_eligible_conversation_ids_for_bulk_recovery(candidate_ids)
    when is_list(candidate_ids) do
  alias Cairnloop.Conversation

  Conversation
  |> where([c], c.id in ^candidate_ids and c.status == :resolved)
  |> select([c], c.id)
  |> repo().all()
end

@doc """
Returns a cohort preview map for the bulk confirmation modal. Pulled through the
narrow facade per D-14. Returns:

    %{
      eligible_ids: [123, 124, ...],
      sample: ["Refund request (#123)", ...],   # first 5 labels
      more: 12,                                  # count beyond sample
      total: 17
    }
"""
def preview_bulk_recovery_cohort(candidate_ids) when is_list(candidate_ids) do
  alias Cairnloop.Conversation

  rows =
    Conversation
    |> where([c], c.id in ^candidate_ids and c.status == :resolved)
    |> order_by([c], desc: c.updated_at)
    |> select([c], %{id: c.id, subject: c.subject, host_user_id: c.host_user_id})
    |> repo().all()

  total = length(rows)
  sample = rows |> Enum.take(5) |> Enum.map(&label_for/1)
  more = max(total - 5, 0)
  %{eligible_ids: Enum.map(rows, & &1.id), sample: sample, more: more, total: total}
end

defp label_for(%{subject: subject, id: id}) when is_binary(subject), do: "#{subject} (##{id})"
defp label_for(%{id: id}), do: "Conversation ##{id}"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LiveView Phoenix.HTML form-based bulk update | `phx-click` per checkbox + assigns-only state | LiveView 0.17.8+ added per-input `phx-change` support; LiveView 1.0 stabilized `Phoenix.Component` API | Lets the cap check, sticky bar, and modal preview all live in `handle_event` flow — no form submission needed. |
| Hand-rolled focus traps | `<.focus_wrap>` + `JS.push_focus/pop_focus` | LiveView 0.18 [CITED: phoenixframework.org/blog/phoenix-liveview-0.18-released] | Phase 25 should not author its own focus-trap JS. Use the built-in components. |
| `unique: [period: N]` on time alone | `unique: [period: :infinity, fields:, keys:]` | Oban 2.10+ stabilized keys-based dedup | Lets `bulk_envelope_id`-keyed dedup work without a time window. The repo already uses this for governance workers. |
| `LiveView.stream` for *everything* | Streams when ephemeral / large; assigns for cohort-aware UX | Streams introduced in 0.20+ | Streams remove server knowledge of visible rows — wrong fit for "select all visible". Stick with assigns (D-04). |

**Deprecated/outdated:**
- Hand-rolled `data-confirm` browser-native confirm dialogs — replaced by LiveView modals with `focus_wrap`. [CITED: dev.to/neophen/beter-data-confirm-modals-in-phoenix-liveview-5al5]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | "Single-conversation Phase 24 sends keep `bulk_envelope_id: nil` and Oban's `unique:` key treats nil as a valid value, so two same-template single-conversation triggers in quick succession are deduped." | Pitfall 1 / Pattern 3 | Phase 24 behavior could subtly change. Mitigation: add a regression test in Phase 25's plan to confirm Phase 24's existing tests still pass after the `unique:` clause lands. [ASSUMED — verified shape against Oban docs but not empirically tested against existing Phase 24 fixtures.] |
| A2 | "`Ecto.UUID.generate/0` is the right ID generator for `BulkEnvelope.id`." | Don't Hand-Roll / Schema | The codebase mixes id strategies (`ToolProposal` uses BIGINT autoincrement; `mcp_tokens` use binary_id). Either is fine; the planner may pick BIGINT for consistency with the rest of `cairnloop_*` tables. [ASSUMED — defaulted to binary_id because UUIDs are conventionally used for correlation keys across services.] |
| A3 | "`rendered_body` should be persisted on `BulkEnvelope` (single rendering) rather than on each `Message` row." | Bulk Envelope Architecture | If the planner decides per-recipient bodies (personalization) come later, the schema may want a `body_template` + per-message rendered. v1 (D-07: "single rendered template body") makes a single column correct, but future-proofing might want a JSONB blob. [ASSUMED — D-07 explicitly says "single rendered template body" so this is consistent with the locked decision, but flagging for the planner to confirm.] |
| A4 | "Telemetry events for bulk: `[:cairnloop, :outbound, :bulk, :triggered]` with measurements `count` and labels `outcome: :submitted \| :refused_cap_exceeded`." | Pitfall 5 / Patterns | Phase 26 (OBS-01) will own the final telemetry shape. Phase 25's emit point is correct; the label vocabulary may shift slightly. [ASSUMED — based on D-B enum-only rule and existing `Cairnloop.Governance.Telemetry` pattern, but final shape is Phase 26's call.] |
| A5 | "`auditor().audit(:bulk_outbound_trigger, …)` is the right action name to register with the host auditor behaviour." | Pattern 2 example | The host's auditor may want a different atom; this is the v1 default. [ASSUMED — modeled on existing `:outbound_trigger` in `lib/cairnloop/outbound.ex:59`.] |
| A6 | "`recipient_conversation_ids` as `{:array, :bigint}` is sufficient; no separate join table needed." | Schema | If future analytics want to JOIN against conversations, an array column is queryable but awkward. For v1's OBS-02 audit purpose ("recording the operator and the cohort of conversations affected") this is fine. [ASSUMED — chose array for simplicity; planner may opt for a `cairnloop_outbound_bulk_envelope_recipients` join.] |

**Risk-weighted summary:** A1 is the only assumption with non-trivial regression risk. A2–A6 are stylistic and easily revised in the planner's review.

## Open Questions

1. **Should `Outbound.bulk_trigger/2` reuse a private `build_trigger_multi/2` helper, or call `Outbound.trigger/2` N times in separate transactions?**
   - What we know: The codebase pattern for fan-out is `Ecto.Multi.merge` inside a single transaction (see `Chat.reply_to_conversation`). `Outbound.trigger/2` itself returns from inside `Cairnloop.Telemetry.span/3` and wraps its own transaction — calling it N times within `bulk_trigger`'s transaction would nest transactions.
   - What's unclear: Whether to (a) extract a private `build_trigger_multi/2` that returns the multi WITHOUT running it (used by both `trigger/2` and `bulk_trigger/2`), or (b) call `trigger/2` N times outside a transaction (loses atomicity), or (c) just inline the per-recipient multi-building in `bulk_trigger/2`.
   - Recommendation: Option (a). Extract a private helper. Keeps `trigger/2`'s PUBLIC signature sealed (D-12), keeps both paths atomic, and avoids transaction nesting. The planner should validate this against `Outbound`'s current `Cairnloop.Telemetry.span` wrapper.

2. **Should Phase 24 single-conversation triggers participate in the new `unique:` keys dedup?**
   - What we know: D-11 explicitly says "at-most-once delivery / idempotency is enforced at the per-recipient level — each fan-out send remains a separate `OutboundWorker` job keyed by `(conversation_id, template_id, bulk_envelope_id)`."
   - What's unclear: For Phase 24 callers, `bulk_envelope_id` is `nil`. Oban treats nil as a valid value, so two Phase 24 recoveries with the same `(conversation_id, template_id)` will be deduped. Is this desired?
   - Recommendation: It IS desired (single-conversation recovery should not double-send), but the planner should confirm Phase 24 has no test that relies on being able to enqueue two back-to-back recoveries for the same conversation. A re-run of the Phase 24 test suite under the new `unique:` clause is mandatory.

3. **Where does `max_batch_size` live?**
   - What we know: D-09 says "configurable via application env" and is the planner's discretion.
   - What's unclear: `Application.get_env(:cairnloop, :max_batch_size, 25)` direct vs a `Cairnloop.Outbound.Config` module.
   - Recommendation: Direct `Application.get_env/3` matches `:outbound_recovery_template_id` and the rest of the codebase. A `Config` module is over-engineering for one knob.

4. **Sticky bar placement: top or bottom?**
   - What we know: D-05 leaves this to the planner.
   - What's unclear: The brand book §10.2 specifies left/center/right rails for the conversation surface but is silent on inbox bottom-rail.
   - Recommendation: **Bottom-anchored** sticky bar. Reasons: (1) it stays out of the way of header chrome, (2) operators read top-to-bottom and act at the bottom, (3) the recovery card in `ConversationLive` (lib/cairnloop/web/conversation_live.ex:825-846) sits below the timeline — the inbox should feel structurally parallel.

5. **Should the `BulkEnvelope` have a `status: :submitted | :refused_cap_exceeded` column, or should refusals not persist at all?**
   - What we know: D-09 is "hard fail-closed" — refused batches should not send.
   - What's unclear: Does the audit story (OBS-02) want refusals visible in the same table as submissions? Phase 26 will read this; if refusals aren't persisted, Phase 26 will need a separate audit lane.
   - Recommendation: Persist refusals. Matches the `Cairnloop.Governance.propose_blocked` pattern (one row per attempt, blocked-with-reason in `policy_snapshot`). [VERIFIED: lib/cairnloop/governance.ex:452-548]

6. **Recipient sample (first 5) — by what ordering?**
   - What we know: D-07 says "first 5 recipient labels" but not which 5.
   - What's unclear: Insertion order, by `updated_at desc`, by id, randomized?
   - Recommendation: By `updated_at desc` (most recently active). Matches the inbox's existing `Chat.list_conversations/0` ordering (lib/cairnloop/chat.ex:11). Consistent and predictable.

## Environment Availability

Phase 25 adds no external runtime dependencies. All needs are met by existing in-repo tooling.

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | All | ✓ | `~> 1.19` (mix.exs:8) | — |
| Phoenix LiveView | InboxLive surface | ✓ | `~> 1.0` (mix.exs:89) | — |
| Ecto + Postgrex | `BulkEnvelope` schema + migration | ✓ | `~> 3.10` / latest (mix.exs:85-86) | Tests headless under REPO-UNAVAILABLE (D-16); migration runs when host repo is available. |
| Oban | `OutboundWorker` uniqueness | ✓ | `~> 2.17` (mix.exs:91) | `unique:` keys feature exists in 2.10+; no version bump needed. |
| `Cairnloop.Repo` | Migration + integration tests | ✗ (REPO-UNAVAILABLE in this workspace per CLAUDE.md) | — | Write headless unit tests for cap/refusal/MapSet/snapshot logic; tag DB-touching tests `# REPO-UNAVAILABLE`. |
| Postgres (test integration path) | `test.integration` alias | ✓ when host runs it | — | Skip in default `mix test`; gate-pass criterion is `mix test` green, not `mix test.integration` per D-16. |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `Cairnloop.Repo` for DB-touching tests — use the existing `MockRepo` pattern from `test/cairnloop/outbound_test.exs:5-40`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) + `Phoenix.LiveViewTest` + `Cairnloop.ConnCase` (for integration) |
| Config file | `mix.exs` aliases (mix.exs:54-71) — `test.setup`, `test.integration`, default `mix test` |
| Quick run command | `mix test` (excludes `:integration` tag — fast inner loop per mix.exs comments) |
| Full suite command | `mix test` + `mix test.integration` (the latter requires `Cairnloop.Repo` which is REPO-UNAVAILABLE here per CLAUDE.md / D-16) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| BULK-01 | `toggle_select` adds/removes id from `@selected_ids` MapSet | headless LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_toggle_select` | ❌ Wave 0 — extend existing file |
| BULK-01 | "Select all visible" toggles all currently-rendered eligible ids | headless LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_select_all_visible` | ❌ Wave 0 |
| BULK-01 | Filter change clears `@selected_ids` (D-04) | headless LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_filter_clears_selection` | ❌ Wave 0 — only after filter affordance lands; for v1 there's no inbox filter, but navigate-away clearing must be tested |
| BULK-01 | Cohort eligibility read goes through `Cairnloop.Governance` (D-14) | headless unit | `mix test test/cairnloop/governance_test.exs:test_list_eligible_conversation_ids` | ❌ Wave 0 |
| BULK-02 | Modal renders count, first-5 sample, "+N more" tail, rendered body | headless component | `mix test test/cairnloop/web/inbox_live_test.exs:test_modal_renders_preview` | ❌ Wave 0 |
| BULK-02 | Cancel modal preserves `@selected_ids` (D-08) | headless LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_cancel_preserves_selection` | ❌ Wave 0 |
| BULK-02 | `bulk_trigger/2` snapshots rendered_body, never re-reads template at worker | headless unit | `mix test test/cairnloop/outbound_test.exs:test_bulk_trigger_snapshots_body` | ❌ Wave 0 |
| BULK-02 | `bulk_trigger/2` writes ONE `BulkEnvelope` row + N `Outbound.trigger/2` (via Multi merge) | DB-touching unit (REPO-UNAVAILABLE — tag and skip locally) | `# REPO-UNAVAILABLE` tag | ❌ Wave 0 |
| BULK-03 | `length(ids) > max_batch_size` → `bulk_trigger/2` returns `{:error, :batch_too_large}` and persists nothing | headless unit | `mix test test/cairnloop/outbound_test.exs:test_bulk_trigger_cap_refusal` | ❌ Wave 0 |
| BULK-03 | LiveView refuses with calm copy + icon (D-10) when oversized | headless LiveView | `mix test test/cairnloop/web/inbox_live_test.exs:test_oversized_refusal_copy` | ❌ Wave 0 |
| BULK-03 | `OutboundWorker.new` job carries `bulk_envelope_id`, `conversation_id`, `template_id` in args | headless unit (assert on Ecto.Multi shape) | `mix test test/cairnloop/outbound_test.exs:test_bulk_trigger_threads_envelope_id` | ❌ Wave 0 |
| BULK-03 | Oban dedup prevents double-enqueue for same `(conversation_id, template_id, bulk_envelope_id)` | DB-touching integration | `# REPO-UNAVAILABLE` tag → `mix test.integration` | ❌ Wave 0 |
| UI-03 | Sticky bar appears when `MapSet.size > 0`, hides when empty | headless component render | `mix test test/cairnloop/web/inbox_live_test.exs:test_sticky_bar_visibility` | ❌ Wave 0 |
| UI-03 | Sticky bar uses `var(--cl-primary, #A94F30)` brand token + icon-not-color-alone | headless render assertion | grep on rendered HTML for token + icon SVG | ❌ Wave 0 |
| UI-03 | Modal traps focus (`<.focus_wrap>` rendered) | headless markup test | assert `has_element?(view, "[id$=-focus-wrap]")` after open | ❌ Wave 0 |

### What each test layer catches

- **Headless presenter/total-function tests** (preferred per CLAUDE.md / D-16): MapSet math, cap-validation function, refusal-copy string, modal sample rendering, JSON shape of telemetry metadata. Catches: pure-logic bugs, off-by-one, copy regressions, telemetry label leakage.
- **Headless LiveView tests** (`Phoenix.LiveViewTest` against `InboxLive` w/ a stub `Outbound`/`Governance`): Selection state, sticky-bar visibility, modal rendering, refusal banner. Catches: assigns drift, focus/keydown wiring, copy regressions, accessibility markup.
- **Headless Outbound unit tests** (against `MockRepo` per the existing `test/cairnloop/outbound_test.exs` pattern): `bulk_trigger/2` envelope shape, cap returns `{:error, :batch_too_large}`, snapshot persistence, telemetry emit. Catches: contract regressions, snapshot drift.
- **DB-touching integration tests** (`test.integration`, requires Postgres — REPO-UNAVAILABLE here; tag and gate): Oban uniqueness constraint actually rejecting a second enqueue; multi atomicity (rollback if envelope insert fails); FK from `Message` to `Conversation`. **These can only be caught at the integration layer** because they depend on Postgres + Oban table behavior; mocks can't faithfully reproduce them.

### Sampling rate (Nyquist)

Avoid Cartesian explosion. Validation does NOT require:
- One test per cap value (the cap is a single integer; one test at `cap` and one at `cap+1` suffices).
- One test per recipient count (test 1, test cap-boundary, test cap+1; skip everything in between).
- One test per visible-rows ordering (sampling: test "all resolved", "mixed resolved/open", "all open" — three cases).

### Wave 0 gaps
- [ ] `test/cairnloop/outbound/bulk_envelope_test.exs` — schema validation, required fields, count > 0 invariant.
- [ ] `test/cairnloop/outbound_test.exs` — extend with `bulk_trigger/2` happy path, cap refusal, snapshot persistence, telemetry emit.
- [ ] `test/cairnloop/governance_test.exs` — verify `list_eligible_conversation_ids_for_bulk_recovery/1` and `preview_bulk_recovery_cohort/1` exist and return the documented shape. (Headless against MockRepo.)
- [ ] `test/cairnloop/workers/outbound_worker_test.exs` — extend to assert the new `unique:` clause and the `bulk_envelope_id` arg threading.
- [ ] `test/cairnloop/web/inbox_live_test.exs` — extend for selection MapSet handlers, sticky-bar render, modal open/cancel, refusal banner, focus_wrap markup.

### Sampling Rate (per-task / per-wave / phase gate)
- **Per task commit:** `mix compile --warnings-as-errors && mix test test/cairnloop/<changed-file>` (focused run on touched file).
- **Per wave merge:** `mix test` (full headless suite — REPO-UNAVAILABLE skips are tagged out).
- **Phase gate:** `mix test` green AND `mix compile --warnings-as-errors` clean. `mix test.integration` is best-effort here (REPO-UNAVAILABLE per D-16) but MUST pass when run in a host with `Cairnloop.Repo` available.

## Security Domain

The phase touches operator-initiated outbound messaging to many recipients in one click. Even though the messages are template-driven (not free-form) and go to already-resolved conversations (no harvesting fresh PII), the **scale × destructive-by-mistake** axis is what makes this a security-relevant phase.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (transitively) | Host owns auth — D-D / CLAUDE.md. `InboxLive.mount/3` reads `host_user_id` from session; Phase 25 must not bypass. |
| V3 Session Management | yes | `actor` for `bulk_trigger/2` comes from session-derived `host_user_id` only; never from request params. (Same pattern as `trigger_recovery_follow_up` in conversation_live.ex:213.) |
| V4 Access Control | yes | A user who can see `InboxLive` is presumed by the host to be allowed to send recovery follow-ups. The phase MUST NOT add any ad-hoc privilege check (Cairnloop is host-owned authz per CLAUDE.md). What the phase MUST do: pass `host_user_id` as `:actor` so the auditor (host-implemented) sees who acted. |
| V5 Input Validation | yes | `conversation_ids` from the LiveView are server-derived (from `@selected_ids`), not from raw form input, but: an MCP-driven `bulk_trigger/2` call MUST validate that each id is an integer and exists. `BulkEnvelope.changeset/2` enforces `validate_required`. |
| V6 Cryptography | no | No new cryptographic surface. `Ecto.UUID.generate/0` for envelope ids is sufficient. |

### Known Threat Patterns for {Phoenix LiveView + Oban + Ecto}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Mass-action click-jacking (operator confirms more than they intended) | Tampering / Repudiation | Mandatory confirmation modal with explicit recipient count + cap refusal (D-07, D-09). [LOCKED by D-07/D-08/D-09.] |
| Replay of bulk send via duplicated Oban job | Repudiation / Tampering | `unique: [period: :infinity, keys: [...]]` Oban-level dedup (D-11). |
| Template substitution after operator confirmation | Tampering | Snapshot `rendered_body` on the `BulkEnvelope` at confirmation time (CLAUDE.md / D-13). |
| Mass-send to non-resolved (wrong cohort) conversations | Tampering / Information Disclosure | Eligibility re-checked at envelope (`bulk_trigger/2` re-resolves via `Governance` facade) — defense-in-depth against a stale assigns set. (Recommendation; planner to confirm.) |
| Audit gap (operator denies bulk action) | Repudiation | Single `BulkEnvelope` row per bulk action with `requested_by` + `requested_at` + `count` (OBS-02 shape). Per-recipient Message rows carry `bulk_envelope_id` for full trace. |
| Telemetry PII leak (recipient host_user_id in metric labels) | Information Disclosure | D-B enum-only labels — strictly enforced via allow-list normalizer (mirrors `Cairnloop.Governance.Telemetry`). |
| Worker queue starvation from a 25-job burst | Denial of Service | Existing `:default` queue + Oban's built-in concurrency limits; 25-job burst is small. Cap (D-09) bounds the worst case. |

### What's explicitly NOT a Phase 25 concern

- Per-recipient PII handling (the recipient is a `host_user_id` already in the host system; no new data fields about them).
- Cross-site request forgery (LiveView's stateful channel handles this).
- SQL injection (Ecto parameterized everywhere; no raw SQL in the proposed change).
- Rate limiting at the SMTP / Chimeway adapter (Phase 23 owns delivery).

## Project Constraints (from CLAUDE.md)

These directives are extracted from `/Users/jon/projects/cairnloop/CLAUDE.md` and have the same authority as locked CONTEXT.md decisions.

- **Shift-left decision policy:** Research deeply, decide, proceed. Escalate only VERY-impactful calls. Phase 25's research has already auto-ratified all four discussion areas (per the CONTEXT.md provenance note); the planner should NOT re-litigate.
- **Warnings-clean build (also D-15):** `mix compile --warnings-as-errors` is mandatory. Any new module — `Cairnloop.Outbound.BulkEnvelope`, the LiveComponent, the migration — must compile clean.
- **REPO-UNAVAILABLE caveat (also D-16):** Prefer headless tests; tag DB-required tests `# REPO-UNAVAILABLE`. Plan accordingly.
- **Durable Ecto records + events are workflow truth; `:telemetry` is observability only — never UI/display source.** The `BulkEnvelope` row is workflow truth. The `[:cairnloop, :outbound, :bulk, …]` events are observability only.
- **New reads go through the narrow `Cairnloop.Governance` facade.** (Also D-14.) No direct `Conversation |> where(...)` in `InboxLive` for eligibility reads.
- **Snapshot trust facts at decision time; never re-read live config at render time.** `BulkEnvelope.rendered_body` is the canonical pattern.
- **Seal completed phases — don't churn sealed code paths.** `Outbound.trigger/2`, `OutboundWorker.perform/1`, `ConversationLive.handle_event("trigger_recovery_follow_up", …)` are all PHASE 23/24-sealed. Phase 25 adds additive opts only.
- **Operator copy is calm, fail-closed, reason-forward, honest — never raw Elixir terms / raw JSON to operators (humanize; raw only behind an explicit expander). Never state-by-color-alone (brand §7.5).** D-10 refusal copy must follow this. The `Governance.insert_blocked_proposal/N` reason-humanization pattern (lib/cairnloop/governance.ex:466-486) is the template.
- **Brand tokens over hardcoded hex (primary `var(--cl-primary, #A94F30)`).** Sticky bar, confirm button, and danger banner all MUST use tokens.

## Sources

### Primary (HIGH confidence — in-repo, verified at file:line)
- `lib/cairnloop/outbound.ex` (1–65) — the sealed `trigger/2` primitive and its `Ecto.Multi` + `Cairnloop.Telemetry.span/3` shape.
- `lib/cairnloop/workers/outbound_worker.ex` (1–39) — current worker behavior; place for `unique:` clause.
- `lib/cairnloop/workers/approval_resume_worker.ex` (34–36) and `lib/cairnloop/workers/tool_execution_worker.ex` (38–41) — `unique: [period: :infinity, fields:, keys: [...]]` template to copy.
- `lib/cairnloop/governance.ex` (entire file, especially 246–289, 452–548, 466–486 reason-humanization) — facade pattern, snapshot pattern, blocked-proposal persistence pattern.
- `lib/cairnloop/governance/telemetry.ex` (entire file) — enum-only normalization template.
- `lib/cairnloop/web/conversation_live.ex` (194–230 handler; 823–847 recovery card; 502–531 CSS; 1739–1745 helpers) — Phase 24 reference impl.
- `lib/cairnloop/web/search_modal_component.ex` (33–80) — existing modal + backdrop styling vocabulary, `JS.focus()` example.
- `lib/cairnloop/web/inbox_live.ex` (entire 44 lines) — current surface to graft selection onto.
- `lib/cairnloop/chat.ex` (10–14, 25–147) — `Chat.list_conversations/0` data source and `Ecto.Multi.merge` pattern.
- `lib/cairnloop/conversation.ex` (entire) — `status: :resolved` enum.
- `lib/cairnloop/message.ex` (entire) — `role: :system_outbound` enum, template_id validation.
- `lib/cairnloop/auditor.ex` (entire) — host-injected audit step pattern.
- `lib/cairnloop/telemetry.ex` (entire) — `Cairnloop.Telemetry.span/3` and `execute/3` helpers.
- `test/cairnloop/outbound_test.exs` (1–116) — MockRepo pattern to copy.
- `test/cairnloop/workers/outbound_worker_test.exs` (1–74) — worker test pattern.
- `test/cairnloop/web/inbox_live_test.exs` (1–27) — InboxLive test template.
- `mix.exs` (83–104) — versions verified (`phoenix_live_view ~> 1.0`, `oban ~> 2.17`, `ecto_sql ~> 3.10`, `jason ~> 1.2`).
- `prompts/cairnloop_brand_book.md` — voice (§5.6 error pattern), color tokens (§7.4 / §7.5), state chips (§10.6), micro-interaction principles (§10.5). NEVER state-by-color-alone (§7.5).
- `CLAUDE.md` — shift-left, warnings-clean, REPO-UNAVAILABLE, snapshot, seal-completed-phases, facade reads, brand tokens.

### Secondary (MEDIUM confidence — verified web docs)
- [Phoenix.Component (hexdocs)](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) — `attr/3`, `slot/3`, `focus_wrap/1` API confirmed.
- [Oban Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html) — `:fields` and `:keys` semantics confirmed.
- [LiveView accessibility focus primitives — fly.io/phoenix-files](https://fly.io/phoenix-files/liveview-accessible-focus/) — `JS.push_focus()`, `JS.pop_focus()`, `<.focus_wrap>` patterns.
- [LiveView 0.18 release blog](https://www.phoenixframework.org/blog/phoenix-liveview-0.18-released) — `focus_wrap` since 0.18; stable in 1.0.
- [Phoenix LiveView Bulk Actions — fullstackphoenix.com](https://fullstackphoenix.com/tutorials/add-bulk-actions-in-phoenix-liveview) — confirms assigns-based selection idiom; also confirms stream-based selection requires JS hooks (which D-04 rules out).

### Tertiary (LOW confidence — single source, not load-bearing)
- [LiveView Multi-Select component — fly.io/phoenix-files](https://fly.io/phoenix-files/liveview-multi-select/) — typeahead-style multi-select, not applicable here but useful context.
- [Better data-confirm modals — dev.to](https://dev.to/neophen/beter-data-confirm-modals-in-phoenix-liveview-5al5) — modern modal patterns; not load-bearing because the codebase already has `SearchModalComponent` as the local style.
- [Beyond data-confirm — ftes.de](https://ftes.de/articles/2025-03-31-beyond-data-confirm) — destructive-action confirmation patterns; corroborates D-07/D-08.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every package verified in mix.exs; zero new deps.
- Architecture: HIGH — every pattern verified against an existing in-repo implementation (`Outbound.trigger/2`, `Governance.propose/3`, `ApprovalResumeWorker`, `SearchModalComponent`, `Cairnloop.Auditor`).
- Pitfalls: HIGH — most pitfalls were extracted from the codebase's own carried decisions (CLAUDE.md, D-A–D-D) and verified against existing test fixtures.
- Open questions: MEDIUM — six items flagged for the planner; A1 is the highest-risk because it could regress Phase 24.

**Research date:** 2026-05-27
**Valid until:** 2026-06-26 (30-day window — the stack is stable; the codebase posture is fully locked; only `phoenix_live_view 1.x` minor bumps would invalidate the focus_wrap recommendation, and 1.0 is unlikely to drop those primitives).

---

*Phase: 25-bulk-selection-fan-out*
*Research authored: 2026-05-27*
