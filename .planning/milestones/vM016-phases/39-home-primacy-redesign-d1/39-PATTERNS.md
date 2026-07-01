# Phase 39: Home Primacy Redesign (D1) - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 7 (3 source modules modified, 1 CSS possibly +1 rule, 3 test files extended)
**Analogs found:** 7 / 7 (all in-repo; every modification has an exact same-file or sibling precedent)

> This phase RESTRUCTURES existing files; it is not greenfield. Every "new" function
> (`Chat.list_conversations/1`, `count_conversations/1`, `scope_status/2`,
> `InboxLive.handle_params/3`, `normalize_status/1`, `safe_count/1`, the throttle pair)
> has a same-file or sibling-file analog whose idiom it must match. Excerpts below are the
> exact text the planner hands the executor to copy/adapt — line numbers are current as of
> this mapping pass.

---

## File Classification

| Modified/New File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/home_live.ex` | LiveView module | event-driven (PubSub) + request-response (render) | same file (current `assign_counts/1` + render + `handle_info`) + `inbox_live.ex` PubSub handler | exact (in-file restructure) |
| `lib/cairnloop/chat.ex` | read facade (Governance posture) | CRUD (read/aggregate) | same file `list_conversations/0` (chat.ex:10) | exact (additive sibling clause) |
| `lib/cairnloop/web/inbox_live.ex` | LiveView module | request-response (`handle_params`) + event-driven (PubSub) | same file `mount/3` (81), `handle_info` (293), `prune_selected_ids/2` (579), `status_variant/1` (537) | exact (in-file) |
| `lib/cairnloop/web/components.ex` | component library | render (read-only this phase) | `cl_hero` (167), `cl_stat` (137), `cl_chip` (76), `cl_empty` (113) — **call-site reference only, no edit** | exact |
| `priv/static/cairnloop.css` | design-system CSS | n/a (static) | `.cl-stat` (410), `.cl-row` (430), `.cl-home-grid` (425), `.cl-hero*` (708) | exact (compose from existing) |
| `test/cairnloop/web/home_live_test.exs` | test (headless render) | request-response | same file `assigns/1` helper + `rendered_to_string` (11-86) | exact |
| `test/cairnloop/web/inbox_live_test.exs` | test (mock-Repo + bare socket) | event-driven + CRUD | same file `build_socket/0` (970), `base_socket/1` (974), `EmptyRepo` (36) | exact |
| `test/cairnloop/chat_test.exs` | test (mock-Repo facade) | CRUD | same file `MockRepo` (6), `setup` put_env (106) | exact |

---

## Pattern Assignments

### `lib/cairnloop/chat.ex` (read facade, CRUD) — additive scoped queries (D-02, D-09)

**Analog:** the sealed 0-arity `list_conversations/0` in the same file. Match its query-pipe idiom exactly; do NOT touch the 0-arity clause (sealed contract / acceptance grep — RESEARCH A3).

**Module setup + the verbatim sealed query** (chat.ex:1-14):
```elixir
defmodule Cairnloop.Chat do
  import Ecto.Query
  alias Cairnloop.{Conversation, Message}
  # ...
  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def list_conversations do                 # PRESERVE VERBATIM — do not collapse into /1
    Conversation
    |> order_by(desc: :updated_at)
    |> repo().all()
  end
```

**`where`-on-status precedent already used in this file** (chat.ex:118-122 inside `reply_to_conversation`) — same `from ... where ... == ^...` shape `scope_status/2` should mirror:
```elixir
repo().one(
  from(s in SLA,
    where: s.conversation_id == ^conversation.id and s.status == :active
  )
)
```

**Pattern to add** (sibling clauses + private scope; from RESEARCH Pattern 2, idiom-matched to the above):
```elixir
def list_conversations(opts) when is_list(opts) do
  Conversation
  |> order_by(desc: :updated_at)
  |> scope_status(Keyword.get(opts, :status))
  |> repo().all()
end

def count_conversations(opts \\ []) do
  Conversation
  |> scope_status(Keyword.get(opts, :status))
  |> repo().aggregate(:count, :id)
end

defp scope_status(query, nil), do: query
defp scope_status(query, status) when status in [:open, :resolved, :archived],
  do: where(query, [c], c.status == ^status)
defp scope_status(query, _other), do: query
```

**Schema fact (VERIFIED — confirms RESEARCH phantom-status flag):** `conversation.ex:6`:
```elixir
field(:status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open)
```
There is **no `:awaiting_customer` / `:new`** in the real enum. Whitelist only `[:open, :resolved, :archived]` in `scope_status/2` and only `"resolved"` in `normalize_status/1`. The phantom values in `inbox_live.ex:539-546` are dead defensive code — do not be misled into whitelisting them.

---

### `lib/cairnloop/web/home_live.ex` (LiveView, event-driven + render) — restructure

**Analog:** the same file's current `assign_counts/1`, `render/1`, `handle_info`, and `safe/2`.

**Imports / aliases / mount pattern to preserve** (home_live.ex:18-38):
```elixir
use Phoenix.LiveView
import Cairnloop.Web.Components
alias Cairnloop.Chat
alias Cairnloop.Governance
alias Cairnloop.KnowledgeAutomation

def mount(_params, session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
  socket =
    socket
    |> assign(:host_user_id, Map.get(session, "host_user_id"))
    |> assign(:page_title, "Cockpit")
    |> assign_counts()
  {:ok, socket}
end
```
> Add `|> assign(:pending_recount?, false)` to this pipe (before `assign_counts/1`) for the throttle (D-09).

**Current count-assign — REPLACE the full-list `Enum.count` with scoped queries** (home_live.ex:44-60). This is exactly what HOME-05/D-09 targets:
```elixir
defp assign_counts(socket) do
  conversations = safe(fn -> Chat.list_conversations() end, [])           # ← remove full load
  open_count = Enum.count(conversations, &(&1.status == :open))           # ← replace w/ count_conversations(status: :open)
  resolved_count = Enum.count(conversations, &(&1.status == :resolved))   # ← replace w/ count_conversations(status: :resolved)
  gaps_count = safe(fn -> length(KnowledgeAutomation.list_gap_candidates()) end, nil)
  audit_count = safe(fn -> length(Governance.list_action_events(limit: 100)) end, nil)
  {health_ok?, health_label} = system_health()

  assign(socket,
    open_count: open_count, resolved_count: resolved_count,
    gaps_count: gaps_count, audit_count: audit_count,
    health_ok?: health_ok?, health_label: health_label
  )
end
```

**Current PubSub handler — REPLACE with the coalescing throttle pair** (home_live.ex:40-42):
```elixir
def handle_info({:conversations_changed}, socket), do: {:noreply, assign_counts(socket)}
def handle_info(_msg, socket), do: {:noreply, socket}
```
New shape (RESEARCH Pattern 1, 500ms trailing-edge, `connected?/1`-guarded). Add `@recount_ms 500` module attr:
```elixir
def handle_info({:conversations_changed}, socket) do
  if socket.assigns.pending_recount? do
    {:noreply, socket}
  else
    if connected?(socket), do: Process.send_after(self(), :recount, @recount_ms)
    {:noreply, assign(socket, :pending_recount?, connected?(socket))}
  end
end

def handle_info(:recount, socket) do
  {:noreply, socket |> assign(:pending_recount?, false) |> assign_counts()}
end

def handle_info(_msg, socket), do: {:noreply, socket}
```

**Fail-closed helper — PRESERVE `safe/2` verbatim, ADD `safe_count/1` alongside** (home_live.ex:168-174 is the exact rescue/catch shape `safe_count/1` mirrors; `safe/2` has other callers at 45, 48, 49, 150 so do NOT change it):
```elixir
defp safe(fun, fallback) do
  fun.()
rescue
  _ -> fallback
catch
  _, _ -> fallback
end
```
Add (RESEARCH "Fail-closed count signal threading", D-06):
```elixir
defp safe_count(fun) do
  {:ok, fun.()}
rescue
  _ -> :error
catch
  _, _ -> :error
end

defp split({:ok, n}) when is_integer(n), do: {n, false}
defp split(_), do: {0, true}   # fail closed to 0 + unavailable flag
```

**Render — RESTRUCTURE from flat 5-cell grid to hero + 3-up band.** Current render (home_live.ex:63-121) is the flat grid with the **duplicate-destination bug (D-10):** the "Work the queue" tile (line 74) and "Recover resolved" tile (line 84) both `href="/inbox"`. Current band cells use the old polymorphic `count={count_or_dash(...)}` returning `"—"` — this no longer type-checks against `cl_stat`'s `count :integer` (P37). Target render shape is pinned in RESEARCH "Recommended Render Structure" and UI-SPEC "Layout Architecture". Key call-site facts below (see components section). Old `count_or_dash/1` (home_live.ex:125-126) is removed; the `"—"` path is replaced by the `unavailable?` "Count unavailable" sub-line.

> **Health variant mapping (D-08):** map `health_ok?` → `"success"`/`"warning"` at assign time (mirror `InboxLive.status_variant/1`), pass `@health_variant` to `cl_chip`. Do NOT pass the boolean to the component.

---

### `lib/cairnloop/web/inbox_live.ex` (LiveView, request-response + event-driven) — handle_params filter

**Analog:** same file `mount/3` (81), `handle_info` (293), `prune_selected_ids/2` (579), `status_variant/1` (537).

**Current `mount/3` — MOVE the list load OUT into `handle_params/3`** (inbox_live.ex:81-106). Mount currently does `conversations = Chat.list_conversations()` at line 92. Seed `conversations: []` + `status: nil` instead (avoids double-query — RESEARCH Pitfall 2; keeps the existing mount test at inbox_live_test.exs:54 green since it already asserts `conversations == []` with EmptyRepo):
```elixir
def mount(_params, session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
  end

  conversations = Chat.list_conversations()        # ← REMOVE; seed [] + status: nil instead

  {:ok,
   assign(socket,
     conversations: conversations,
     host_user_id: Map.get(session, "host_user_id"),
     selected_ids: MapSet.new(),
     bulk_modal_open: false,
     bulk_preview: nil,
     bulk_refusal: nil
   )}
end
```
> ADD `status: nil` to this assign; change `conversations: conversations` → `conversations: []`. Do NOT touch `selected_ids/bulk_modal_open/bulk_preview/bulk_refusal/host_user_id`.

**Current PubSub handler — make filter-aware** (inbox_live.ex:293-297). This is the exact pattern; only the `list_conversations` call gains `status:`:
```elixir
def handle_info({:conversations_changed}, socket) do
  conversations = Chat.list_conversations()                                   # ← add status: socket.assigns.status
  selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)
  {:noreply, assign(socket, conversations: conversations, selected_ids: selected_ids)}
end
```

**`prune_selected_ids/2` — REUSE AS-IS** (inbox_live.ex:579-582; already returns the MapSet intersection, route it through both `handle_params/3` and the PubSub handler per D-04):
```elixir
def prune_selected_ids(selected_ids, conversations) when is_list(conversations) do
  visible_ids = conversations |> Enum.map(& &1.id) |> MapSet.new()
  MapSet.intersection(selected_ids, visible_ids)
end
```

**`status_variant/1` — REUSE the `:resolved → "success"` mapping** for the applied-filter chip (inbox_live.ex:537-541):
```elixir
defp status_variant(:resolved), do: "success"
defp status_variant(:open), do: "info"
defp status_variant(_), do: "neutral"
# (NB: :awaiting_customer/:new clauses here are dead phantom code — do not whitelist them)
```

**Pattern to ADD** (RESEARCH Pattern 3 — `handle_params/3` + `normalize_status/1`):
```elixir
def handle_params(params, _uri, socket) do
  status = normalize_status(params["status"])
  conversations = Chat.list_conversations(status: status)
  selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)
  {:noreply, assign(socket, status: status, conversations: conversations, selected_ids: selected_ids)}
end

defp normalize_status("resolved"), do: :resolved
defp normalize_status(_), do: nil        # NEVER String.to_existing_atom on raw input (D-03)
```

**Current empty branch — SPLIT it** (inbox_live.ex:125-130). Today `@conversations == []` renders "No conversations yet." Split: empty + `@status == :resolved` → `cl_empty` filtered-empty copy; empty + no filter → existing "No conversations yet." (RESEARCH Pattern 4):
```elixir
<%= if @conversations == [] do %>
  <p class="inbox-empty-state cl-text-muted cl-text-small mt-4">
    No conversations yet.
  </p>
<% end %>
```

**Applied-filter row to ADD above the list** (RESEARCH Pattern 4 / UI-SPEC). Composes from existing `.cl-row` + `.cl-text-small`; chip reuses `cl_chip variant="success"`:
```elixir
<%= if @status == :resolved do %>
  <div class="cl-applied-filter cl-row cl-text-small">
    <.cl_chip variant="success" label="Resolved" />
    <span>Showing resolved conversations ·</span>
    <.link patch={~p"/inbox"}>Show all</.link>
  </div>
<% end %>
```

---

### `lib/cairnloop/web/components.ex` (component library) — CALL-SITE REFERENCE ONLY (read-only)

These components are consumed, not edited. Exact attrs/slots so the planner's call-sites are correct:

**`cl_hero/1`** (components.ex:159-179) — `count :integer` (required), `job` (required), `href`/`cta` (default nil), `calm?` (default false), slots `:detail` + `:cta_slot`:
```elixir
attr(:count, :integer, required: true)
attr(:job, :string, required: true)
attr(:href, :string, default: nil)
attr(:cta, :string, default: nil)
attr(:calm?, :boolean, default: false)
slot(:detail)
slot(:cta_slot)
# Render: <:cta_slot> WINS over @cta/@href. The href/cta fallback link renders ONLY when cta_slot == [].
```
> **CRITICAL (RESEARCH pin):** when supplying `:cta_slot`, do NOT also pass `href`/`cta` to `cl_hero` — they only drive the fallback link (line 174) and become dead config / double-CTA risk. UI-SPEC's `href="/inbox"` on `cl_hero` is illustrative only.

**`cl_stat/1`** (components.ex:127-149) — renders a `<.link navigate={@href}>` tile; `count :integer` (required, numeric-only post-P37):
```elixir
attr(:job, :string, required: true)
attr(:count, :integer, required: true)
attr(:meta, :string, default: nil)
attr(:href, :string, default: nil)
attr(:cta, :string, default: nil)
attr(:icon, :string, default: nil)
attr(:calm?, :boolean, default: false)
# Render: <.link navigate={@href} class="cl-stat cl-focusable">
#   <span class="cl-stat__job"><.cl_icon .../> {@job}</span>
#   <span class={["cl-stat__count", @calm? && "cl-stat__count--calm"]}>{@count}</span> ...
```
> The health cell is NOT a `cl_stat` — it is a hand-built `<div class="cl-stat">` (div, not link) with a `cl_chip` where the count span would be (D-08; shape in RESEARCH render structure / UI-SPEC line 148).

**`cl_chip/1`** (components.ex:65-86) — `variant` + `label` + optional `icon` (auto-resolved from variant via `status_icon/1`); used for health chip AND resolved applied-filter chip:
```elixir
attr(:variant, :string, default: "neutral", values: ~w(success info warning danger ai neutral))
attr(:label, :string, default: nil)
attr(:icon, :string, default: nil)
# Render: <span class="cl-chip cl-chip--#{@variant}"><.cl_icon .../> <span>{@label}</span></span>
```

**`cl_empty/1`** (components.ex:107-121) — zero-state hero swap AND filtered-empty inbox; `title` required, `icon` default `"compass"`, body via inner block:
```elixir
attr(:title, :string, required: true)
attr(:icon, :string, default: "compass")
slot(:inner_block)
# Render: <div class="cl-empty"> <.cl_icon name={@icon} size="28" .../> <p class="cl-empty__title">{@title}</p> ... </div>
```

**`cl_button/1`** (components.ex:29-47) — **A1 RESOLVED: `cl_button` renders a plain `<button>`, NOT a link.** Its `:rest` global includes only `disabled form name value phx-click phx-value-id phx-disable-with data-confirm` — **no `navigate`/`href`/`patch`.** So the hero CTA cannot navigate via `cl_button` alone. Wrap it: `<.link navigate="/inbox"><.cl_button variant="primary" size="lg">Open inbox</.cl_button></.link>`, OR use the `cl_hero` `:cta`/`href` fallback path instead of `:cta_slot`. The planner must pick one — do not pass `navigate=` to `cl_button` (it will be dropped):
```elixir
attr(:variant, :string, default: "default", values: ~w(default primary danger ghost))
attr(:size, :string, default: "md", values: ~w(sm md lg))
attr(:type, :string, default: "button")
attr(:rest, :global, include: ~w(disabled form name value phx-click phx-value-id phx-disable-with data-confirm))
# Render: <button type={@type} class={["cl-button", ...]} {@rest}>{render_slot(@inner_block)}</button>
```

---

### `priv/static/cairnloop.css` (design-system CSS) — compose from existing, ≤1 new rule

**Analog / existing classes to compose** (all VERIFIED present):
```css
.cl-home-grid { display: grid; grid-template-columns: 1fr; gap: var(--cl-space-5, 16px); }   /* 425 — mobile-first 1→2→3 */
@media (min-width: 640px)  { .cl-home-grid { grid-template-columns: repeat(2, 1fr); } }       /* 426 */
@media (min-width: 1024px) { .cl-home-grid { grid-template-columns: repeat(3, 1fr); } }       /* 427 */
.cl-row { display: flex; align-items: center; gap: var(--cl-space-3, 8px); }                  /* 430 */
.cl-text-small { font-size: var(--cl-font-small, 13px); line-height: var(--cl-leading-small, 20px); }  /* 251 */
.cl-text-muted { color: var(--cl-text-muted, #677066); }                                     /* 250 */
.cl-mt-5 { margin-top: var(--cl-space-5, 16px); }                                             /* 440 */
.cl-stat { /* surface card shell reused for the health cell div */ }                          /* 410 */
.cl-hero / .cl-hero__job / .cl-hero__count / .cl-hero__detail / .cl-hero__cta                 /* 708-727 */
```
Tokens available: `--cl-surface` (38), `--cl-neutral-surface` (67), `--cl-space-3` (90).

**At most ONE new rule** (`.cl-applied-filter`, CONTEXT/Claude's discretion) — composed atop `.cl-row` + `.cl-text-small`; only add if a background/padding is genuinely needed, e.g.:
```css
.cl-applied-filter { background: var(--cl-surface); padding: var(--cl-space-3) 0; }
```
> No new component primitive. **Brand gate note (BRAND-04):** the gate (`brand_token_gate_test.exs`) only catches `var(--cl-x, #hex)` fallbacks in `.ex` files — it does NOT scan CSS and does NOT catch bare `#hex` or `rgba()`. Reach for CLASSES/tokens in the `.ex` renders, never a literal color; add the recommended "no raw `#[0-9A-Fa-f]{6}`" assertion to the Home render test.

---

### Test files — reuse existing headless + mock-Repo harnesses

**`test/cairnloop/web/home_live_test.exs`** (headless `render/1`, `async: true`, no Repo) — reuse the `assigns/1` merge helper; EXTEND its defaults with the new keys (`open_count_unavailable?`, `resolved_count_unavailable?`, `gaps_unavailable?`, `audit_unavailable?`, `health_variant`). Existing tests at lines 26-61 WILL break (job "Recover resolved" removed, "—" dash → "Count unavailable", 5-card → 3 tiles + hero) — update them as part of the work:
```elixir
use ExUnit.Case, async: true
import Phoenix.LiveViewTest

defp assigns(overrides) do
  Map.merge(
    %{open_count: 0, resolved_count: 0, gaps_count: 0, audit_count: 0,
      health_ok?: true, health_label: "Healthy", __changed__: nil},
    Map.new(overrides))
end

test "..." do
  html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 7})))
  assert html =~ "7"
end
```
> Throttle test (HOME-05b, deterministic, NO sleep): build a socket with `pending_recount?: false`, call `handle_info({:conversations_changed}, socket)` and assert the flag flips (when connected) / no timer armed (disconnected bare socket); then call `handle_info(:recount, socket)` directly and assert the flag clears + counts recompute. Use the `base_socket`-style bare `%Phoenix.LiveView.Socket{}` so `connected?/1` is false.

**`test/cairnloop/web/inbox_live_test.exs`** (`async: false`; mock-Repo + bare socket) — reuse `build_socket/0`, `base_socket/1`, the `EmptyRepo` stub, and `render_html/1`. Add a `describe "normalize_status/1"` (pure whitelist) + `handle_params/3` mock-repo tests:
```elixir
defp build_socket, do: %Phoenix.LiveView.Socket{}           # disconnected → connected?/1 false → throttle-safe

defmodule EmptyRepo do                                       # swap via Application.put_env(:cairnloop, :repo, EmptyRepo)
  def all(_query), do: []
end
# usage:
Application.put_env(:cairnloop, :repo, EmptyRepo)
{:ok, socket} = InboxLive.mount(%{}, %{"host_user_id" => "u1"}, build_socket())
```
> For the `:resolved` leak test (open conversation must not enter the resolved view via PubSub re-query) — needs a real Repo round-trip; write it but mark `# REPO-UNAVAILABLE` (CLAUDE.md) and run in `mix test.integration` / CI.

**`test/cairnloop/chat_test.exs`** (`async: false`; `MockRepo` + `setup` put_env) — reuse the `MockRepo` module + `setup` that swaps `:repo`. Add `scope_status/2` query-shape assertions (inspect the `Ecto.Query` — no Repo needed) and `# REPO-UNAVAILABLE` count round-trip tests. `MockRepo` will need an `aggregate/3` clause and an `all/1` that honors the scoped where for the count/list tests:
```elixir
defmodule MockRepo do
  def all(_query), do: []      # extend to return scoped fixtures for list_conversations/1
  # add: def aggregate(_query, :count, :id), do: <fixture count>   (for count_conversations/1)
  def insert(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)}
  # ...
end

setup do
  Application.put_env(:cairnloop, :repo, MockRepo)
  on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
  :ok
end
```

---

## Shared Patterns

### Fail-closed defensive read (rescue/catch wrapper)
**Source:** `home_live.ex:168-174` (`safe/2`).
**Apply to:** all Home count assigns. Preserve `safe/2` (other callers at 45/48/49/150); add `safe_count/1` (returns `{:ok, n} | :error`) + `split/1` so a genuine `0` is distinguishable from an unavailable count (D-06). The integer stays `0` (fail-closed) while a separate `*_unavailable?` boolean drives the "Count unavailable" sub-line.

### Connected-only PubSub subscribe + guard
**Source:** `home_live.ex:29` and `inbox_live.ex:88-90` — both `if connected?(socket), do: Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")`.
**Apply to:** the throttle (`Process.send_after` only when `connected?(socket)`) so dead render / bare-socket tests never arm a timer (RESEARCH Pitfall 1).

### Status → chip variant mapping (color + icon + text, never color alone)
**Source:** `inbox_live.ex:537-541` (`status_variant/1`) + `cl_chip/1` (components.ex:76, auto-icon via `status_icon/1`).
**Apply to:** Home health cell (`@health_variant = if health_ok?, do: "success", else: "warning"`) and the InboxLive resolved applied-filter chip. Brand §7.5.

### Scoped Ecto read through the facade (Governance posture)
**Source:** `chat.ex:118-122` (`from ... where ... == ^...`).
**Apply to:** `scope_status/2`; the web layer never runs direct Ecto — Home and Inbox both call `Chat.*` only.

### `prune_selected_ids/2` reconciliation on every list change
**Source:** `inbox_live.ex:579-582` (already doc-tested; used by the PubSub handler at 295).
**Apply to:** BOTH the new `handle_params/3` and the (now filter-aware) PubSub handler so a now-hidden resolved row can't silently inflate the bulk-bar count (D-04, RESEARCH Pitfall 4).

### Headless render / mock-Repo bare-socket test harnesses
**Source:** `home_live_test.exs:11-27` (assigns map + `rendered_to_string`); `inbox_live_test.exs:36-41,970` (`EmptyRepo` + `build_socket`); `chat_test.exs:6,106` (`MockRepo` + `setup` put_env).
**Apply to:** all new tests. Prefer headless/pure; mark Repo-round-trip tests `# REPO-UNAVAILABLE`.

---

## No Analog Found

None. Every modification has an exact same-file or sibling-file precedent. The only genuinely
"new" construct is the `Process.send_after` + `pending_recount?` throttle coalescing, but its
two-clause `handle_info` shape and `connected?/1` guard mirror the existing PubSub-handler +
connected-subscribe idioms already in `home_live.ex` / `inbox_live.ex`. No RESEARCH-only
(external) pattern is needed.

---

## Metadata

**Analog search scope:** `lib/cairnloop/web/` (LiveViews + components), `lib/cairnloop/` (facade + schema), `priv/static/cairnloop.css`, `test/cairnloop/web/` + `test/cairnloop/`.
**Files scanned:** 9 (3 source modules, 1 schema, 1 CSS, 3 test files, 1 component lib).
**Pattern extraction date:** 2026-06-04
**Open question resolved this pass:** A1 (`cl_button` is a `<button>`, not a link — hero CTA must wrap in `<.link>` or use the `cl_hero` fallback path).
