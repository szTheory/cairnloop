# Phase 39: Home Primacy Redesign (D1) - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView render restructure + additive `Chat` facade scoped queries + query-param filter (Elixir/Phoenix/Ecto)
**Confidence:** HIGH (all claims code-grounded against the actual repo; no external library research needed)

> Scope note: This phase is locked by 10 CONTEXT decisions (D-01..D-10) and an APPROVED UI-SPEC.
> This research does NOT re-litigate any decision. It pins down the **exact code shapes** an
> executor needs and the **Validation Architecture** the Nyquist gate consumes. Everything below
> is `[VERIFIED: codebase grep/Read]` unless tagged otherwise.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01 … D-10 — authoritative, do not re-decide)
- **D-01:** Resolved filter = query param on existing route `/inbox?status=resolved`, handled by a NEW `handle_params/3` in `InboxLive`. No new route. Home CTA = plain `href="/inbox?status=resolved"`.
- **D-02:** Push filter into the `Chat` facade as a scoped Ecto `where` (NOT `Enum.filter`). Add `Chat.list_conversations/1` (opts; `:status` atom) + `Chat.count_conversations/1`, both delegating to one private `scope_status/2`. Preserve `list_conversations/0` verbatim.
- **D-03:** Fail-closed param handling via explicit `normalize_status/1` whitelist; unknown/garbage → `nil` → unfiltered "all" view. Never `String.to_existing_atom` on raw input.
- **D-04:** PubSub stays filter-aware — `@status` is a durable socket assign; the `{:conversations_changed}` handler re-queries `Chat.list_conversations(status: @status)`. Route `prune_selected_ids/2` through BOTH `handle_params/3` and the PubSub handler.
- **D-05:** Applied-filter UX: when filter active, render a quiet applied-filter line (`cl_chip variant="success" label="Resolved"` + plain `<.link patch={~p"/inbox"}>Show all</.link>`); absent when no filter. Filtered-empty state uses `cl_empty`. Copper NOT spent on filter.
- **D-06:** `cl_hero`/`cl_stat` are `count :integer`. `safe/2` fails closed to `0` for the number, but a SEPARATE `unavailable?` signal drives a quiet neutral "Count unavailable" sub-line so error ≠ calm-zero. Applies to hero AND band tiles.
- **D-07:** Zero state — hero region swaps to a calm `cl_empty` success block; the "Tend the trail" band PERSISTS below. No confetti, no whole-page celebration.
- **D-08:** Health cell uses the secondary-tile shape but renders a `cl_chip` (success "Healthy" / warning "Degraded") where the number would go. Never occupies a numeric count slot. Color + icon + text (brand §7.5).
- **D-09:** Replace Home's full-list `Enum.count` with scoped `Chat.count_conversations(status: …)`. Throttle PubSub recount by coalescing `{:conversations_changed}` bursts into ≤1 recount per window (~500ms–1s) via `Process.send_after` self-message + a "pending" flag. Preserve `safe/2`.
- **D-10:** Fix the duplicate-`href` bug on the "Recover resolved" tile so the resolved CTA resolves deterministically to `/inbox?status=resolved`.

### Claude's Discretion (decided in this research)
- Exact throttle interval/mechanism (D-09) → **PINNED below: 500ms trailing-edge coalesce + `pending_recount?` flag.**
- Exact `cl_empty` icon, sub-line microcopy, and the single `.cl-applied-filter` flex class (composed from existing `.cl-` utilities; no new component primitive). UI-SPEC already fixes the copy; researcher confirms class composition below.

### Deferred Ideas (OUT OF SCOPE — do not build)
- Standing inbox filter chrome (tab bar / segmented control / status dropdown / saved views / per-status counts).
- Filtering by statuses other than the resolved deep-link.
- Phoenix streams refactor of the inbox list.
- "Next in queue" threading; Audit-row → subject linking.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOME-01 | Full-width "Work the queue" hero (~2–3× weight), single copper count, primary `cl_button` CTA into inbox | `cl_hero/1` (components.ex:167) already provides `:cta_slot` + copper `cl-hero__count`. Render shape pinned in §Architecture Patterns. |
| HOME-02 | Recover-resolved folds into hero as a quiet sub-line linking to `/inbox` with resolved filter applied (fix broken CTA), omitted when zero | `:detail` slot on `cl_hero`; deep-link `/inbox?status=resolved` backed by `Chat.list_conversations/1` + `InboxLive.handle_params/3`. Duplicate-href fix §5. |
| HOME-03 | Calmer secondary band (Tend / Audit / System health), neutral counts, health as `cl_chip`, never a numeric count slot | `cl_stat/1` for two numeric tiles; health uses the `.cl-stat` shell with a `cl_chip` in place of the count (UI-SPEC layout). `status_variant/1`-style mapping reused. |
| HOME-04 | Dead 6th cell removed; all-caught-up = calm icon+text, never confetti | Exactly 3 secondary tiles → fills the 3-up grid (no phantom cell). `cl_empty/1` hero swap when `@open_count == 0` (D-07). |
| HOME-05 | Scoped count queries (not full per-tick re-query), throttled, `safe/2` preserved | `Chat.count_conversations/1` (cheap `SELECT count(*)`); 500ms coalesce throttle; `safe/2` extended additively (§4). |
</phase_requirements>

## Summary

Phase 39 is a render restructure plus a small, additive facade/filter change. **No new libraries,
no new routes, no new component primitives.** All five components the layout needs (`cl_hero`,
`cl_stat`, `cl_chip`, `cl_empty`, `cl_button`) already ship in `components.ex`, and all CSS
tokens/classes exist in `priv/static/cairnloop.css`. The real implementation risk is concentrated in
six narrow HOWs: (1) the PubSub throttle coalescing pattern, (2) the additive `Chat` scoped-query
shape, (3) `InboxLive.handle_params/3` filter wiring without clobbering existing mount assigns,
(4) threading a fail-closed `unavailable?` signal separate from the integer count, (5) the
duplicate-`href` fix, and (6) keeping the restructure brand-token-clean.

Two **schema facts** shape the work and are easy to get wrong: the `Conversation.status` enum is
`[:open, :resolved, :archived]` (default `:open`) — **there is no `:awaiting_customer` or `:new`**
despite `InboxLive.status_label/1` handling those phantom values. So `normalize_status/1` and
`scope_status/2` must whitelist only `:resolved` (and optionally `:open`/`:archived`); anything else
→ `nil` → unfiltered. Second: the existing test harness swaps a mock Repo via
`Application.put_env(:cairnloop, :repo, MockRepo)` and runs `mount/3`/`handle_*` directly on a bare
`%Phoenix.LiveView.Socket{}` (disconnected). That bare socket makes `connected?/1` return `false`,
which is exactly what protects the throttle from scheduling on dead render — and it makes
`handle_params/3` + the throttle **headlessly testable here without a live Repo**.

**Primary recommendation:** Implement the throttle as a 500ms trailing-edge coalesce
(`Process.send_after(self(), :recount, 500)` guarded by a `pending_recount?` boolean assign, only
when `connected?(socket)`); add `Chat.count_conversations/1` as a `SELECT count(*) … WHERE`
delegating to `scope_status/2`; thread `@open_count_unavailable?` alongside `@open_count`; and gate
the whole render through the existing brand-token ExUnit test + a headless `render/1` test per
HOME-0x.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Scoped conversation counts / lists | `Chat` facade (data) | — | D-02/Governance posture: web layer never runs direct Ecto; all reads go through the facade. |
| Resolved-filter routing/state | `InboxLive` (LiveView) | URL (query param) | D-01: query param is the source of truth; `handle_params/3` reads it into `@status`. |
| Filter-aware PubSub re-query | `InboxLive` (LiveView) | `Chat` facade | D-04: handler re-queries the facade with `@status` so open can't leak into resolved. |
| Count throttle / coalescing | `HomeLive` (LiveView process) | — | Per-process timer + flag; pure process-mailbox concern, no DB/UI tier. |
| Fail-closed count→display semantics | `HomeLive` presenter helpers | Components (`cl_hero`/`cl_stat`) | `safe/2` + `unavailable?` decided in the LiveView; components stay dumb integer renderers. |
| Visual layout / tokens | Components + `cairnloop.css` | — | All primitives + tokens pre-exist; phase only wires them. |

## Standard Stack

No external packages are added or installed in this phase. The "stack" is the in-repo facade,
components, and CSS that already ship.

### Core (in-repo, pre-existing)
| Module / Component | Location | Purpose | Why Standard |
|--------------------|----------|---------|--------------|
| `Cairnloop.Chat` | `lib/cairnloop/chat.ex` | Read facade — extend with `/1` + `count_conversations/1` + `scope_status/2` | Governance/facade read posture (PROJECT invariant) [VERIFIED: Read] |
| `cl_hero/1` | `components.ex:167` | Primary hero; copper `cl-hero__count`, `:detail` + `:cta_slot` slots | De-polymorphized `count :integer` in P37 [VERIFIED] |
| `cl_stat/1` | `components.ex:137` | Two numeric secondary tiles; `count :integer`, `calm?`, `:href`, `:cta`, `:icon` | Renders `<.link navigate={@href}>` tile [VERIFIED] |
| `cl_chip/1` | `components.ex:76` | Health chip + resolved applied-filter chip; `variant` + icon + label | Icon auto-resolved from variant via `status_icon/1` [VERIFIED] |
| `cl_empty/1` | `components.ex:113` | Zero-state hero swap + filtered-empty inbox; `icon` (default `"compass"`) + `title` + body | `:icon` attr, `title` required [VERIFIED] |
| `cl_button/1` | `components.ex` | Hero CTA primary button inside `:cta_slot` | Pre-existing [VERIFIED] |

### Package Legitimacy Audit
**Not applicable** — Phase 39 installs zero external packages (custom BEM CSS, no npm/hex additions). No registry surface to audit.

## Architecture Patterns

### System Data Flow

```
                          ┌─────────────────────────────────────────────┐
   PubSub "conversations" │  {:conversations_changed} broadcast          │
   (Chat.create_*/ingest_*)└──────────────┬──────────────────────────────┘
                                          │ (burst-prone)
            ┌─────────────────────────────┴──────────────────────────────┐
            ▼                                                              ▼
   ┌──────────────────────┐                                   ┌──────────────────────┐
   │ HomeLive             │                                   │ InboxLive            │
   │ handle_info(:changed)│                                   │ handle_info(:changed)│
   │   set pending flag,  │                                   │   re-query with      │
   │   send_after :recount│  ── 500ms coalesce ──▶ :recount   │   @status, prune sel │
   │ handle_info(:recount)│                                   └──────────┬───────────┘
   │   Chat.count_conv(*) │◀──── scope_status/2 ────┐                    │
   └──────────┬───────────┘                         │         handle_params(?status=)
              │                                      │            normalize_status/1
              ▼                          ┌───────────┴───────────┐  load list+prune
   open_count/resolved_count  ──────────▶│ Cairnloop.Chat facade │◀────────────────┘
   + *_unavailable? signal               │ list_conversations/0|1│
              │                          │ count_conversations/1 │
              ▼                          │ scope_status/2 (priv) │── Ecto where status==^s ─▶ Repo
   cl_hero / cl_stat (integer) +         └───────────────────────┘
   cl_empty (zero) / "Count unavailable"
```

### Recommended Render Structure (Home — from UI-SPEC §Layout, code-grounded)

```elixir
<.cl_shell current={:home} destinations={Cairnloop.Web.Nav.destinations()}>
  <.cl_page title="Welcome back" subtitle="What needs you today?" width="wide">
    <%!-- Tier 1: hero OR zero-state swap (D-07) --%>
    <%= if @open_count == 0 and not @open_count_unavailable? do %>
      <.cl_empty icon="check-circle" title="All caught up">
        Nothing is waiting on you right now.
      </.cl_empty>
    <% else %>
      <.cl_hero job="Work the queue" count={@open_count}>
        <:detail>
          <%= if @open_count_unavailable? do %>
            <span class="cl-text-small cl-text-muted">Count unavailable</span>
          <% end %>
          <%= if @resolved_count > 0 and not @resolved_count_unavailable? do %>
            <a href="/inbox?status=resolved" class="cl-text-small cl-text-muted">
              <%= @resolved_count %> resolved — eligible for recovery
            </a>
          <% end %>
        </:detail>
        <:cta_slot>
          <%!-- A1 RESOLVED: cl_button is a plain <button> (no navigate/href/patch) — wrap in <.link>. --%>
          <.link navigate="/inbox"><.cl_button variant="primary" size="lg">Open inbox</.cl_button></.link>
        </:cta_slot>
      </.cl_hero>
    <% end %>

    <%!-- Tier 2: exactly 3 tiles → fills 3-up grid, no phantom 6th cell (HOME-04) --%>
    <div class="cl-home-grid cl-mt-5">
      <.cl_stat job="Tend knowledge" icon="book" count={@gaps_count}
                calm?={@gaps_count == 0} meta={gaps_meta(@gaps_count, @gaps_unavailable?)}
                href="/knowledge-base/gaps" cta="Review gaps" />
      <.cl_stat job="Audit trail" icon="dot" count={@audit_count}
                calm?={true} meta={audit_meta(@audit_unavailable?)}
                href="/audit-log" cta="View audit log" />
      <%!-- Health cell: .cl-stat shell (div, not link), chip replaces the count slot (D-08) --%>
      <div class="cl-stat">
        <span class="cl-stat__job"><.cl_icon name="shield" class="cl-chip__icon" /> System health</span>
        <.cl_chip variant={@health_variant} label={@health_label} />
        <span class="cl-stat__meta"><%= @health_meta %></span>
      </div>
    </div>
  </.cl_page>
</.cl_shell>
```

> **Pin (D-08):** `@health_variant` is `"success"`/`"warning"` (NOT the boolean `health_ok?` directly).
> Map at assign time: `health_variant = if health_ok?, do: "success", else: "warning"`. This mirrors
> `InboxLive.status_variant/1`'s shape and keeps color+icon+text together.

> **Pin (cl_hero href no-op):** `cl_hero`'s `href`/`cta` attrs only drive the FALLBACK link that
> renders when `:cta_slot` is empty (components.ex:174). Since we supply `:cta_slot`, do NOT pass
> `href`/`cta` to `cl_hero` — put the navigation on the `cl_button` inside the slot. Passing both is
> dead config and risks two CTAs. (UI-SPEC's `href="/inbox"` on `cl_hero` is illustrative only.)

### Pattern 1: Throttled PubSub recount (D-09 / HOME-05) — PINNED

**Decision:** 500ms **trailing-edge** coalesce with a `pending_recount?` boolean assign.

- **Interval = 500ms.** Rationale: bursts come from `create_customer_conversation/1` +
  `ingest_widget_message/2` (each broadcasts `{:conversations_changed}` — see chat.ex:44, 71). A
  single inbound widget message can emit 2 broadcasts back-to-back; an operator action triggers more.
  500ms is below human-perceptible "stale dashboard" threshold yet collapses a multi-broadcast burst
  into one pair of `SELECT count(*)` queries. 250ms is twitchy; 1s feels laggy for a live count badge.
  500ms is the documented UI-SPEC value (UI-SPEC:229) — keep it.
- **Trailing-edge, not leading.** Initial counts are loaded synchronously in `mount/3` via
  `assign_counts/1`, so the operator never waits for a first tick. After mount, the first
  `{:conversations_changed}` schedules a recount 500ms later — the user does not need sub-500ms
  freshness on a passive dashboard. Trailing-edge is strictly simpler (one flag, no "last fired at"
  timestamp bookkeeping) and cannot double-fire.
- **`connected?/1` guard.** Schedule ONLY when `connected?(socket)`. On dead render (and in headless
  tests using a bare `%Phoenix.LiveView.Socket{}`), `connected?/1` is `false`, so no timer is armed —
  no orphaned messages, no test flakiness.

**Recommended shape (function names + assign keys the planner hands to the executor):**

```elixir
# mount/3 — add the flag; keep the synchronous initial load.
socket =
  socket
  |> assign(:pending_recount?, false)
  |> assign_counts()            # synchronous initial counts (scoped queries now)

# Burst arrives: set the flag + arm a single timer. Coalesce: if a timer is already
# pending, do nothing (the in-flight :recount will pick up the latest DB state).
@impl true
def handle_info({:conversations_changed}, socket) do
  if socket.assigns.pending_recount? do
    {:noreply, socket}                                   # already scheduled — coalesce
  else
    if connected?(socket), do: Process.send_after(self(), :recount, @recount_ms)
    {:noreply, assign(socket, :pending_recount?, connected?(socket))}
  end
end

# Trailing edge fires once per window: clear the flag, do the scoped recount.
def handle_info(:recount, socket) do
  {:noreply, socket |> assign(:pending_recount?, false) |> assign_counts()}
end

def handle_info(_msg, socket), do: {:noreply, socket}

@recount_ms 500
```

> **Why the flag is set to `connected?(socket)` (not bare `true`):** in a disconnected/test socket no
> timer is armed, so the flag must stay `false` or a `:recount` would never arrive to clear it and all
> later `{:conversations_changed}` would be swallowed forever. Setting it to `connected?(socket)`
> keeps the connected path coalescing and the dead/test path doing an immediate recompute-on-message
> (or, in tests, you inject `:recount` directly — see Validation Architecture).

### Pattern 2: Additive scoped `Chat` queries (D-02 / D-09) — PINNED

`Conversation.status` is `Ecto.Enum, values: [:open, :resolved, :archived], default: :open`
(conversation.ex:6) [VERIFIED]. `scope_status/2` must match this reality.

```elixir
# PRESERVE verbatim (sealed-contract invariant) — do NOT touch the 0-arity clause.
def list_conversations do
  Conversation
  |> order_by(desc: :updated_at)
  |> repo().all()
end

# ADD — opts-driven, delegates to scope_status/2.
def list_conversations(opts) when is_list(opts) do
  Conversation
  |> order_by(desc: :updated_at)
  |> scope_status(Keyword.get(opts, :status))
  |> repo().all()
end

# ADD — cheap SELECT count(*) … WHERE; NOT load + Enum.count.
def count_conversations(opts \\ []) do
  Conversation
  |> scope_status(Keyword.get(opts, :status))
  |> repo().aggregate(:count, :id)
end

# ADD (private) — single source of truth for the where; nil/unknown → unfiltered.
defp scope_status(query, nil), do: query
defp scope_status(query, status) when status in [:open, :resolved, :archived],
  do: where(query, [c], c.status == ^status)
defp scope_status(query, _other), do: query   # defense-in-depth: ignore unknown atoms
```

> **Why `repo().aggregate(:count, :id)` not `repo().one(from c in q, select: count(c.id))`:** both
> emit `SELECT count(...)`; `aggregate/3` is the idiomatic Ecto.Repo call, composes cleanly with the
> scoped query, and reads at a glance. Either is acceptable; aggregate is the recommendation.
> [VERIFIED: composes with the same `scope_status/2` as the list query → CTA badge count and landed
> filtered list can never disagree, per D-09.]

> **Sealed-contract note:** keep `list_conversations/0` and `list_conversations/1` as two distinct
> head clauses (do NOT collapse into one `\\ []` default), because the 0-arity is the sealed contract
> and an existing acceptance grep may assert its exact form. Two clauses = purely additive.

### Pattern 3: `InboxLive.handle_params/3` filter wiring (D-01/D-03/D-04) — PINNED

`InboxLive.mount/3` currently loads `Chat.list_conversations()` and assigns
`selected_ids/bulk_modal_open/bulk_preview/bulk_refusal/host_user_id` (inbox_live.ex:92-105). To
avoid a double query (mount load + handle_params load), **move the list load out of mount into
`handle_params/3`** and have mount assign only the non-list state + a default `@status`.

```elixir
# mount/3: drop the Chat.list_conversations() call; seed @status nil; keep all other assigns.
def mount(_params, session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
  {:ok,
   assign(socket,
     conversations: [],                # populated by handle_params (avoid double-query)
     status: nil,                       # durable filter assign (D-04)
     host_user_id: Map.get(session, "host_user_id"),
     selected_ids: MapSet.new(),
     bulk_modal_open: false,
     bulk_preview: nil,
     bulk_refusal: nil
   )}
end

# NEW handle_params/3 — load filtered list here (runs after mount on first render AND on patch).
def handle_params(params, _uri, socket) do
  status = normalize_status(params["status"])
  conversations = Chat.list_conversations(status: status)
  selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)
  {:noreply, assign(socket, status: status, conversations: conversations, selected_ids: selected_ids)}
end

# D-03 fail-closed whitelist — NEVER String.to_existing_atom on raw input.
defp normalize_status("resolved"), do: :resolved
defp normalize_status(_), do: nil       # unknown/garbage/nil → unfiltered "all"
```

```elixir
# D-04 — PubSub handler becomes filter-aware (re-query with @status) and prunes.
def handle_info({:conversations_changed}, socket) do
  conversations = Chat.list_conversations(status: socket.assigns.status)
  selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)
  {:noreply, assign(socket, conversations: conversations, selected_ids: selected_ids)}
end
```

**Pins / footguns:**
- `prune_selected_ids/2` already exists (inbox_live.ex:579) and returns the MapSet intersection. Route
  it through BOTH `handle_params/3` and the PubSub handler (D-04) so a now-hidden resolved row can't
  silently inflate the bulk-bar count.
- **mount-assign clobber check:** `handle_params/3` must NOT overwrite `selected_ids` with a fresh
  MapSet — it must *prune* the existing one (above). It also must not touch
  `bulk_modal_open/bulk_preview/bulk_refusal/host_user_id`. The shape above only assigns
  `status/conversations/selected_ids`. [VERIFIED: those four assigns originate in mount and are
  managed by the bulk-event handlers; handle_params leaves them untouched.]
- Existing `InboxLive` mount test (inbox_live_test.exs:43-62) asserts `socket.assigns.conversations == []`
  after `mount/3` with an EmptyRepo. **Moving the load to handle_params means mount now returns
  `conversations: []` unconditionally** — this test KEEPS PASSING (mount no longer queries), and a new
  test should exercise `handle_params/3` with a mock repo for the filtered load. Good: the change is
  test-compatible, not test-breaking, for that assertion.

### Pattern 4: Applied-filter row + filtered-empty (D-05)

```elixir
<%= if @status == :resolved do %>
  <div class="cl-applied-filter cl-row cl-text-small">
    <.cl_chip variant="success" label="Resolved" />
    <span>Showing resolved conversations ·</span>
    <.link patch={~p"/inbox"}>Show all</.link>
  </div>
<% end %>
```

- `.cl-applied-filter` is the single small flex class allowed by CONTEXT (composed atop existing
  `.cl-row` + `.cl-text-small`). If it needs any rule at all, add ONE class to `cairnloop.css`
  (e.g. background `var(--cl-surface)`, padding `var(--cl-space-3)`); do NOT introduce a component.
  `.cl-row`, `.cl-text-small`, `--cl-surface`, `--cl-space-3` all exist [VERIFIED: cairnloop.css:430, 251, 67].
- Filtered-empty (resolved list empty): render `cl_empty title="No resolved conversations to recover"`
  with body "Nothing is waiting for a recovery follow-up right now." + a `<.link navigate={~p"/inbox"}>Show all conversations</.link>`.
- **Mind the existing empty branch (inbox_live.ex:125):** `@conversations == []` currently renders
  "No conversations yet." Split this: empty + `@status == :resolved` → filtered-empty copy; empty +
  no filter → existing "No conversations yet." Don't show the resolved copy on a genuinely empty inbox.

### Anti-Patterns to Avoid
- **Do NOT** add `status=resolved` handling as a `live_action` route (rejected by D-01 — bloats host routing).
- **Do NOT** filter via `Enum.filter` on a full list load (rejected by D-02 — defeats the scoped count).
- **Do NOT** call `String.to_existing_atom/1` (or `String.to_atom/1`) on `params["status"]` (D-03 — DoS/atom-table risk).
- **Do NOT** schedule `Process.send_after` on a disconnected socket (orphan timers, test flakiness).
- **Do NOT** pass `href`/`cta` to `cl_hero` while also supplying `:cta_slot` (dead config, double-CTA risk).
- **Do NOT** render `0` as the calm "all caught up" state when the count is *unavailable* (D-06 — dishonest).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Status chip color/icon | Custom `<span>` + hex | `cl_chip variant=…` | Auto icon via `status_icon/1`; brand §7.5 color+icon+text guaranteed |
| Empty / zero state | Bespoke div | `cl_empty` | Calm icon+title+body shape already shipped |
| Selection reconciliation on filter change | New MapSet diff | `prune_selected_ids/2` (inbox_live.ex:579) | Already written, doc-tested; just wire it in |
| Count query | Load list + `Enum.count` | `Chat.count_conversations/1` | Cheap `SELECT count(*)`; can't disagree with the list (shared `scope_status/2`) |
| Debounce/throttle | External lib | `Process.send_after` + flag | Idiomatic LiveView coalescing; no dep needed |

**Key insight:** every visual + reconciliation primitive this phase needs already exists in-repo and
is sealed-tested. The phase's only genuinely new code is ~3 facade functions, 1 `handle_params/3`,
1 `normalize_status/1`, and the throttle pair — all small, pure-ish, and headlessly testable.

## Fail-closed count signal threading (D-06) — PINNED

`safe/2` (home_live.ex:168) currently returns `fun.()` or a fallback on rescue/catch. It is reused
unchanged for the numeric value, but we need a **separate** error signal so `0` (genuine) ≠ `0`
(unavailable). Recommended helper that returns a tagged result, then split in `assign_counts/1`:

```elixir
# Add: a count helper that distinguishes success from failure (keeps safe/2 intact for other callers).
defp safe_count(fun) do
  {:ok, fun.()}
rescue
  _ -> :error
catch
  _, _ -> :error
end

defp assign_counts(socket) do
  {open_count, open_unavailable?}       = split(safe_count(fn -> Chat.count_conversations(status: :open) end))
  {resolved_count, resolved_unavail?}   = split(safe_count(fn -> Chat.count_conversations(status: :resolved) end))
  # gaps/audit: same split via safe_count; health unchanged.
  assign(socket,
    open_count: open_count, open_count_unavailable?: open_unavailable?,
    resolved_count: resolved_count, resolved_count_unavailable?: resolved_unavail?,
    # … gaps_count/gaps_unavailable?, audit_count/audit_unavailable?, health_variant/label/meta
  )
end

defp split({:ok, n}) when is_integer(n), do: {n, false}
defp split(_),                          do: {0, true}   # fail closed to 0 + unavailable flag
```

- `cl_hero`/`cl_stat` still receive a plain `integer` `count` (de-polymorphized P37 — VERIFIED at
  components.ex:128, 159). The `*_unavailable?` flag drives a quiet neutral "Count unavailable"
  sub-line, NOT the integer.
- **`safe/2` additive-extension note:** leave `safe/2` exactly as-is (it has other callers:
  `system_health/0` uses it at home_live.ex:150). Add `safe_count/1` alongside — purely additive,
  zero risk to existing callers. [VERIFIED: `safe/2` called at lines 45, 48, 49, 150.]
- The zero-state hero swap condition is `@open_count == 0 and not @open_count_unavailable?` so an
  unavailable open count shows the hero with a "Count unavailable" sub-line, never the celebratory
  "All caught up" block.

## Duplicate-href bug (D-10) — diagnosed

`home_live.ex:78-86` (the "Recover resolved" `cl_stat`) passes `href="/inbox"` **once** (line 84) —
re-reading the current file, the *duplicate* CONTEXT refers to is that BOTH the "Work the queue" tile
(line 74) and the "Recover resolved" tile (line 84) point at the **same bare `/inbox`**, so the
resolved CTA does not carry its filter and lands on the unfiltered inbox (the "broken-on-click" CTA).
There is not literally a repeated `href=` attribute on one element in the current source; the bug is
**two tiles → one undifferentiated destination**, and the resolved one should deep-link.

**Deterministic fix:** In the restructure, the "Recover resolved" concept moves into the hero
`:detail` sub-line as a plain `<a href="/inbox?status=resolved">` (HOME-02). The "Work the queue"
CTA stays `/inbox` (open is the default unfiltered view). Result: two distinct, deterministic
destinations — `/inbox` (open work) and `/inbox?status=resolved` (recovery). No `href` collision
survives the restructure.

> If a literal duplicate `href` attribute on a single element is found at edit time (Phoenix/HEEx
> would actually warn/raise on duplicate attrs at compile under `--warnings-as-errors`), the rule is:
> the **last** attribute wins in HEEx, but the warnings-as-errors build (CLAUDE.md) would reject it —
> so the fix is to delete the stale one and keep the single intended `href`. Either way the resolved
> sub-line's href is `/inbox?status=resolved`.

## Brand-token gate compatibility — VERIFIED

The BRAND-04 gate (`test/cairnloop/web/brand_token_gate_test.exs`) runs under `mix test` (CI truth)
and fails the build on any `var(--cl-<token>, #hex)` **hex-fallback** string in `lib/cairnloop/web/`
or the example app's live dir. [VERIFIED: Read test file.]

- **What the gate catches:** `var(--cl-primary, #A94F30)`-style hex fallbacks in `.ex` render files.
- **What the gate does NOT catch:** bare hardcoded `#hex`, inline `rgba()`/`hsl()`, or
  `var(--cl-x, rgba(...))` (regex requires `#` after the comma). **So a naive executor could slip a
  raw `#A94F30` or `style="color:#677066"` past this gate.** Reviewers/plan verification must grep for
  raw hex independently. Recommended belt-and-suspenders: the phase render test asserts the rendered
  Home/Inbox markup contains NO `#[0-9A-Fa-f]{6}` substring (cheap, deterministic).
- **Every new bit is already token-backed** (UI-SPEC Color table → CSS tokens, all verified present):
  hero copper = `cl-hero__count` (`--cl-primary`); calm/zero = `cl-hero__count--calm` / `cl-stat__count--calm` (`--cl-success`); health chip = `cl-chip--success`/`cl-chip--warning`; applied-filter = `cl-chip--success` + `--cl-surface`/`--cl-neutral-surface`; "Count unavailable" = `cl-text-muted`/`--cl-neutral-text`. The executor must reach for these CLASSES, never a literal color.
- Note: `cairnloop.css` itself contains hex (e.g. `--cl-text, #18211F` at line 362) — that file is
  **out of gate scope** (gate scans only `.ex` files), and editing the CSS file is not part of this
  phase beyond at most one `.cl-applied-filter` rule.

## Runtime State Inventory

> Rename/refactor inventory — this phase is a render/feature change, not a rename, but it touches
> stored status semantics and PubSub, so each category is answered explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `Conversation.status` enum `[:open, :resolved, :archived]` (conversation.ex:6). Filter reads only existing values; **no migration, no new status**. | None — read-only filter. |
| Live service config | None. PubSub topic `"conversations"` already subscribed by both LiveViews; no new topic/broadcast. | None. |
| OS-registered state | None. | None — verified: no schedulers/tasks touched. |
| Secrets/env vars | None new. Existing knobs (`:repo`, `:outbound_module`, etc.) unchanged. | None. |
| Build artifacts | None. No package rename; `priv/static/cairnloop.css` may gain one `.cl-applied-filter` rule (shipped static asset, no build step). | None beyond the optional CSS rule. |

**Phantom-status caveat (not stored state, but a code-reality mismatch):** `InboxLive.status_label/1`
and `status_variant/1` handle `:awaiting_customer` and `:new`, which **do not exist** in the schema
enum. This is dead-but-harmless defensive code. `normalize_status/1` and `scope_status/2` must
whitelist only the REAL enum values (`:resolved` for this phase) — do not be misled into whitelisting
the phantom statuses. [VERIFIED: conversation.ex:6 vs inbox_live.ex:539-546.]

## Common Pitfalls

### Pitfall 1: Throttle flag never clears → counts freeze
**What goes wrong:** Setting `pending_recount? = true` unconditionally in the handler, but on a
disconnected socket no `:recount` ever arrives to clear it, so all later `{:conversations_changed}`
are coalesced into nothing forever.
**How to avoid:** Set the flag to `connected?(socket)` (the pinned shape), and only arm the timer when
connected. Verify with the deterministic message-injection test (Validation Architecture).

### Pitfall 2: Double DB query on inbox first render
**What goes wrong:** Loading `Chat.list_conversations()` in BOTH `mount/3` and `handle_params/3`.
**How to avoid:** Load ONLY in `handle_params/3`; mount seeds `conversations: []`. (Matches the pinned shape; keeps the existing mount test green.)

### Pitfall 3: Open conversation leaks into the resolved view
**What goes wrong:** PubSub handler re-queries `Chat.list_conversations()` (unfiltered) while
`@status == :resolved`, so a new `:open` conversation appears in the resolved list.
**How to avoid:** Re-query `Chat.list_conversations(status: socket.assigns.status)` (D-04). Covered by a `# REPO-UNAVAILABLE` round-trip test.

### Pitfall 4: Stale bulk selection inflates the count after filtering
**What goes wrong:** A resolved row selected, then it leaves the filtered list; `@selected_ids` still
holds its id → bulk bar shows a phantom count.
**How to avoid:** `prune_selected_ids/2` through both `handle_params/3` and the PubSub handler (D-04).

### Pitfall 5: Raw hex sneaks past the BRAND-04 gate
**What goes wrong:** Executor writes `style="color:#A94F30"` — the gate regex only catches the
`var(--cl-…, #…)` form, so the build stays green with a brand violation.
**How to avoid:** Use CSS classes/tokens only; add the suggested no-raw-hex assertion to the phase render test.

## Validation Architecture

> Nyquist gate keys off this exact heading. Test framework: **ExUnit** (`mix test`), `async: true`
> where Repo-free. **`mix test` excludes `:integration`** (MEMORY: integration gate runs only in CI /
> via `mix test.integration`) — so the brand-token gate and all headless render/presenter tests run
> in the default lane and are the local pre-merge truth. **`Cairnloop.Repo` may be unavailable here**
> (CLAUDE.md): prefer headless tests; DB-round-trip tests are written but marked `# REPO-UNAVAILABLE`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 pinned for format/CI) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/cairnloop/web/home_live_test.exs test/cairnloop/web/inbox_live_test.exs test/cairnloop/chat_test.exs` |
| Brand gate command | `mix test test/cairnloop/web/brand_token_gate_test.exs` |
| Full suite command | `mix test` (excludes `:integration`); CI adds `mix test.integration` |

### Established harness patterns (reuse — both are Repo-free)
1. **Headless `render/1`** (home_live_test.exs): build an assigns map, call
   `Cairnloop.Web.HomeLive.render(assigns(...))`, `rendered_to_string/1`, assert on substrings.
   No Repo, `async: true`. Use this for ALL Home render assertions (HOME-01..04).
2. **Mock-Repo + bare socket** (inbox_live_test.exs:43): `Application.put_env(:cairnloop, :repo, MockRepo)`
   then call `mount/3`/`handle_params/3`/`handle_info/2` directly on `%Phoenix.LiveView.Socket{}`.
   `connected?/1` is `false` on this socket → throttle-safe. Use for query/filter/throttle logic.

### Phase Requirements → Test Map
| Req ID | Behavior (observable signal) | Test Type | Automated Command | File Exists? |
|--------|------------------------------|-----------|-------------------|--------------|
| HOME-01 | Rendered Home contains `cl-hero` section with `cl-hero__count` and a primary `cl_button` "Open inbox"; `cl-hero` present only when `open_count > 0` | headless render | `mix test test/cairnloop/web/home_live_test.exs` | ✅ (extend) |
| HOME-02a | Resolved sub-line `<a href="/inbox?status=resolved">` present when `resolved_count > 0`, ABSENT when `0` | headless render | same | ✅ (extend) |
| HOME-02b | `normalize_status("resolved") == :resolved`; `normalize_status("garbage"|nil|"open;DROP") == nil` (fail-closed whitelist) | pure unit | `mix test test/cairnloop/web/inbox_live_test.exs` | ❌ Wave 0 (new describe) |
| HOME-02c | `scope_status/2` builds `where status == ^:resolved` (assert via `Ecto.Query` inspect, no Repo) | query-builder unit | `mix test test/cairnloop/chat_test.exs` | ✅ (extend) |
| HOME-02d | `handle_params(%{"status"=>"resolved"},…)` sets `@status=:resolved` + loads filtered list (mock repo); `handle_info(:changed)` re-queries with `@status` so open can't leak | DB-round-trip | `mix test.integration` | ❌ Wave 0 `# REPO-UNAVAILABLE` |
| HOME-03 | Rendered band has exactly 3 tiles; health renders `cl-chip--success`/`--warning` + label, NOT in a `cl-stat__count`; counts are neutral (no `cl-hero__count`/copper class on band) | headless render | home_live_test.exs | ✅ (extend) |
| HOME-04a | `open_count == 0 and not unavailable?` → `cl-empty` + "All caught up"; band still rendered below | headless render | home_live_test.exs | ✅ (extend) |
| HOME-04b | No phantom 6th cell: rendered `.cl-home-grid` contains exactly 3 `.cl-stat` children | headless render | home_live_test.exs | ❌ Wave 0 assertion |
| HOME-05a | `Chat.count_conversations(status: :resolved)` issues a single `count` aggregate over the scoped query (assert query/no full load) | DB-round-trip + query-builder | chat_test.exs (`# REPO-UNAVAILABLE` for the count value) | ✅ (extend) |
| HOME-05b (throttle) | A burst of N `{:conversations_changed}` arms at MOST one `:recount`; a `:recount` clears `pending_recount?` and recomputes | deterministic message-injection | home_live_test.exs | ❌ Wave 0 (new describe) |
| D-06 | `unavailable?` (count helper returns `:error`) → integer renders `0` AND a "Count unavailable" sub-line; genuine `0` renders "All caught up", NOT "Count unavailable" | headless render + pure unit (`split/1`) | home_live_test.exs | ❌ Wave 0 |
| Brand | Rendered Home/Inbox markup contains no `var(--cl-…, #…)` (existing gate) AND (recommended) no raw `#[0-9A-Fa-f]{6}` | ExUnit gate | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ |

### What proves the throttle WITHOUT flakiness (no `sleep`)
Do **not** assert wall-clock timing. Instead:
1. Build a connected-or-mock socket with `pending_recount?: false`.
2. Send `handle_info({:conversations_changed}, socket)` → assert it returns
   `pending_recount?: true` (when connected). Send it again 4× → assert it stays `true` and does NOT
   recompute counts each time (coalesce: only the flag flips, counts unchanged from the burst).
3. Send `handle_info(:recount, socket)` directly → assert `pending_recount?: false` and that
   `assign_counts/1` ran (counts reflect the mock repo's current state). This deterministically proves
   "≤1 recount per burst" without timing.
   (On a disconnected/bare socket, assert that `{:conversations_changed}` does NOT arm a timer and the
   flag stays `false` — proves the `connected?/1` guard.)

### What needs a live Repo (write, mark `# REPO-UNAVAILABLE`)
- `count_conversations/1` actually returning the right row count per status.
- `handle_info({:conversations_changed})` re-query with `@status=:resolved` NOT including a freshly
  inserted `:open` conversation (the leak test).
- `list_conversations(status: :resolved)` row contents.
These are written against a real `Conversation` fixture and run in `mix test.integration` / CI.

### Wave 0 Gaps
- [ ] `test/cairnloop/web/inbox_live_test.exs` — new `describe "normalize_status/1"` (pure whitelist) + `handle_params/3` mock-repo tests.
- [ ] `test/cairnloop/chat_test.exs` — `scope_status/2` query-shape assertions (inspect `Ecto.Query`) + `# REPO-UNAVAILABLE` count tests.
- [ ] `test/cairnloop/web/home_live_test.exs` — extend assigns helper with the new keys (`open_count_unavailable?`, `resolved_count_unavailable?`, `gaps_unavailable?`, `audit_unavailable?`, `health_variant`); add hero/zero-state/3-cell/Count-unavailable/throttle describes. **Existing tests at lines 26-61 will break** (job label "Recover resolved" removed; "—" dash path replaced by "Count unavailable"; 5-card assertion now 3 tiles + hero) — update them as part of the work, do not leave stale.
- [ ] No framework install needed (ExUnit present).

## Environment Availability
| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/mix | build + tests | ✓ | pin 1.19.5 (format/CI) | — |
| `Cairnloop.Repo` (Postgres) | DB-round-trip tests only | ✗ (may be unavailable in workspace) | — | Headless/pure tests run; round-trip tests marked `# REPO-UNAVAILABLE`, run in CI |

**Missing deps with fallback:** live Repo → headless render + mock-repo socket tests cover the logic locally; round-trip behavior validated in CI integration lane.
**Missing deps with no fallback:** none.

## Assumptions Log
| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ~~`cl_button` accepts `navigate=` for the hero CTA~~ **RESOLVED (pattern-mapper + plan-checker):** `cl_button/1` (components.ex:35-43) renders a plain `<button>`; its `:rest` global does NOT forward `navigate`/`href`/`patch`. The hero CTA MUST be wrapped in `<.link navigate="/inbox">` (or use `cl_hero`'s own `href`/`:cta` path). | Render structure | RESOLVED — render snippet above + Plan 03 corrected. |
| A2 | `cl_icon` name `"check-circle"` exists in the inline SVG set for the zero-state | Render structure | LOW — UI-SPEC specifies it; if absent, fall back to `"compass"` (cl_empty default) or `"inbox"`. |
| A3 | An acceptance grep may assert the exact 0-arity `list_conversations/0` form | Pattern 2 | LOW — keeping two distinct clauses satisfies it regardless. |
| A4 | 500ms is acceptable to the owner as the throttle window | Throttle | LOW — matches UI-SPEC:229; documented, owner-reviewed UI-SPEC. |

## Open Questions (RESOLVED)
1. **`cl_button` CTA attribute (`navigate` vs `href`/`patch`) — RESOLVED.**
   - Confirmed against source (`components.ex:35-43`): `cl_button/1` renders a plain `<button>`; its
     `:rest` global forwards only `~w(disabled form name value phx-click phx-value-id phx-disable-with
     data-confirm)` — it does NOT forward `navigate`/`href`/`patch`.
   - Resolution: wrap the hero CTA in `<.link navigate="/inbox"><.cl_button …>Open inbox</.cl_button></.link>`
     (or use `cl_hero`'s own `href`/`:cta` fallback). Reflected in the "Recommended Render Structure"
     snippet above and in 39-03-PLAN.md. A bare `cl_button` with `navigate=` would ship a dead CTA.

## Sources

### Primary (HIGH — code-grounded, this session)
- `lib/cairnloop/web/home_live.ex` — current 5-cell grid, `safe/2` (168), `assign_counts/1`, `count_or_dash/1`, `system_health/0`.
- `lib/cairnloop/chat.ex` — `list_conversations/0` (10), broadcast sites (44, 71), facade shape.
- `lib/cairnloop/web/inbox_live.ex` — `mount/3` (81-106), `handle_info({:conversations_changed})` (293), `prune_selected_ids/2` (579), `status_variant/1` (537).
- `lib/cairnloop/conversation.ex` — `status` enum `[:open, :resolved, :archived]` (6).
- `lib/cairnloop/web/components.ex` — `cl_chip` (76), `cl_empty` (113), `cl_stat` (137, `count :integer`), `cl_hero` (167, `:detail`/`:cta_slot`).
- `test/cairnloop/web/home_live_test.exs` — headless `render/1` harness.
- `test/cairnloop/web/inbox_live_test.exs` — mock-Repo + bare-socket harness (43-62, 970).
- `test/cairnloop/web/brand_token_gate_test.exs` — BRAND-04 gate regex + scope.
- `priv/static/cairnloop.css` — token/class presence (`--cl-neutral-surface` 67, `.cl-row` 430, `.cl-text-small` 251, `.cl-mt-5` 440).
- `.planning/REQUIREMENTS.md` — HOME-01..05 text (27-31).
- `39-CONTEXT.md`, `39-UI-SPEC.md` — locked decisions + design contract.

### Secondary / Tertiary
- None — no external research was needed or performed for this phase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components/tokens verified present in-repo.
- Architecture (throttle, queries, handle_params): HIGH — shapes derived directly from existing code + locked decisions.
- Pitfalls: HIGH — each maps to a verified code reality (schema enum, mount load, gate regex scope).
- `cl_button` CTA attr: MEDIUM — not read this pass (A1/OQ1); trivially resolved at edit time.

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stable in-repo target; no fast-moving external deps)
