# Phase 42: Cross-Screen Threading - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 9 (3 facade modules, 3 LiveViews, 1 presenter, 2+ test files)
**Analogs found:** 9 / 9 (all in-repo; this is a "mirror existing patterns" phase)

This phase adds **read functions + declarative links** — no new workflow state, no migration. Every
new behavior has a close in-repo analog. The planner should lean on the excerpts below; each carries a
file:line provenance so plan actions can say "mirror `chat.ex:20-25`" rather than describing in prose.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/chat.ex` (add `next_open_conversation/1`) | facade (read) | scoped cheap-read | `chat.ex` `count_conversations/1` (`:29-33`) + `list_conversations/1` (`:20-25`) | exact (same module) |
| `lib/cairnloop/auditor/governance.ex` (`Cairnloop.Auditor.Governance.list_events/1` enrich map) | facade-impl (normalizer) | transform | `auditor.ex:66-78` (the existing `Enum.map` flatten) | exact (same fn) |
| `lib/cairnloop/governance.ex` (add `proposal_id:` opt to `list_action_events/1`) | facade (read) | scoped read | `list_action_events/1` (`:998-1008`) + `list_events/1` (`:978-983`) | exact (same fn) |
| `lib/cairnloop/knowledge_automation.ex` (add `originating_conversation_id/2`) | facade (read) | scoped cheap-read | `list_article_suggestions/1` (`:64-70`) + `apply_scope/2` (`:1965-1969`) | exact (same module) |
| `lib/cairnloop/web/audit_log_live.ex` (add `handle_params/2` + per-row link) | LiveView | request-response (param filter) | (none in this LV) — see "No Analog" + Pattern 3 | role-match |
| `lib/cairnloop/web/audit_log_presenter.ex` (subject-link helper) | presenter | transform | existing total fns `action_label/1` etc. (`:22-48`) | exact (same module) |
| `lib/cairnloop/web/conversation_live.ex` (Next-in-queue in resolved region) | LiveView | render + nav | `outbound_recovery_card/1` (`:531-545`); back-link (`:438`); inbox row link (`inbox_live.ex:215`) | exact |
| `lib/cairnloop/web/conversation_live.ex` (audit deep-link in Tier-3 trace group) | LiveView | render + nav | governed-action card Tier-3 group (`:1082-1091`) | exact |
| `lib/cairnloop/web/knowledge_base_live/editor.ex` (article→conv breadcrumb crumb) | LiveView | render + nav | breadcrumb slot (`:265-266`) + `BreadcrumbPresenter.editor_items/2` (`:45-63`) | exact |
| Test files (chat/auditor/knowledge_automation + headless render extends) | test | — | `audit_log_live_test.exs:1-63` (headless `render/1`+`base_assigns/0`) | exact |

## Pattern Assignments

### `lib/cairnloop/chat.ex` — `next_open_conversation/1` (facade, scoped cheap-read)

**Analog:** `chat.ex:20-33` (the P39 D-09 cheap-read pair). Mirror the `repo()` indirection (`:6-8`),
the `order_by(desc: :updated_at)` ordering, and `scope_status/2`'s parameterized `^` pin idiom.

**`repo()` indirection + ordering** (`chat.ex:6-25`):
```elixir
defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end

def list_conversations(opts) when is_list(opts) do
  Conversation
  |> order_by(desc: :updated_at)
  |> scope_status(Keyword.get(opts, :status))
  |> repo().all()
end
```

**Cheap-read pattern (never full-list + Enum)** (`chat.ex:29-33`):
```elixir
def count_conversations(opts \\ []) do
  Conversation
  |> scope_status(Keyword.get(opts, :status))
  |> repo().aggregate(:count, :id)
end
```

**New fn shape (per RESEARCH Pattern 1 — D-07; `select`-only, deterministic id tiebreak):**
```elixir
# Additive sibling to list_conversations/1. select(:id) only — do NOT load the full row.
def next_open_conversation(current_id) do
  Conversation
  |> where([c], c.status == :open and c.id != ^current_id)
  |> order_by([c], desc: c.updated_at, desc: c.id)   # tiebreak by id (D-07 determinism)
  |> limit(1)
  |> select([c], c.id)
  |> repo().one()
end
```
Status enum confirmed `[:open, :resolved, :archived]` (`conversation.ex:5-6`). Note `chat.ex` uses
`alias Cairnloop.{Conversation, Message}` so reference `Conversation`, not the fully-qualified name.

---

### `lib/cairnloop/auditor/governance.ex` — enrich `list_events/1` map (facade-impl, transform)

**Analog + extension point:** `auditor.ex:66-78` — THE D-09 extension point (RESEARCH correction #1).
`AuditLogLive` consumes `auditor.list_events(...)` (`audit_log_live.ex:45-46`), NOT `Governance` directly.
The current flatten **drops** the proposal/ids — add them here, not only in `list_action_events/1`.

**Current flatten map (extend this exact `Enum.map`)** (`auditor.ex:66-78`):
```elixir
@impl true
def list_events(opts) do
  opts
  |> Governance.list_action_events()      # already preloads :tool_proposal (governance.ex:1006)
  |> Enum.map(fn event ->
    %{
      inserted_at: event.inserted_at,
      actor_id: event.actor_id,
      action: event.event_type,
      reason: event.reason,
      metadata: event.metadata || %{}
      # ADD (D-09): navigational subject refs — structural FK, not a trust fact.
      # conversation_id: event.tool_proposal && event.tool_proposal.conversation_id,
      # proposal_id: event.tool_proposal_id
    }
  end)
end
```
`list_action_events/1` already `preload(:tool_proposal)` (`governance.ex:1006`), so no extra query.
Guard `tool_proposal` may be nil → `conversation_id` resolves to nil → fail-closed non-link row (D-08).

---

### `lib/cairnloop/governance.ex` — `proposal_id:` opt on `list_action_events/1` (facade, read)

**Analog:** `list_action_events/1` (`:998-1008`) for the opts/limit/offset idiom; `list_events/1`
(`:978-983`) for the `where([e], e.tool_proposal_id == ^proposal_id)` filter shape to lift in.

**Existing reads** (`governance.ex:978-1008`):
```elixir
def list_events(proposal_id) do
  ToolActionEvent
  |> where([e], e.tool_proposal_id == ^proposal_id)
  |> order_by([e], asc: e.inserted_at)
  |> repo().all()
end

def list_action_events(opts \\ []) do
  limit = Keyword.get(opts, :limit, 100)
  offset = Keyword.get(opts, :offset, 0)

  ToolActionEvent
  |> order_by([e], desc: e.inserted_at, desc: e.id)
  |> limit(^limit)
  |> offset(^offset)
  |> preload(:tool_proposal)
  |> repo().all()
end
```
**Add (D-10, RESEARCH Open Q1 recommendation):** an optional `proposal_id:` opt that conditionally
adds `where(e.tool_proposal_id == ^id)` so the auditor's single normalization path serves both
filtered and unfiltered reads. Mirror the `Keyword.get` + conditional-`where` idiom from `apply_scope/2`
(`knowledge_automation.ex:1965-1969`, shown below) — a `maybe_where_equal`-style helper, never an
unscoped raw query (V4 access control; do not bypass operator scope).

---

### `lib/cairnloop/knowledge_automation.ex` — `originating_conversation_id/2` (facade, cheap-read)

**Analog:** `list_article_suggestions/1` (`:64-70`) + `apply_scope/2` (`:1965-1969`). RESEARCH
correction #2: this is a NEW read keyed on `ArticleSuggestion.article_id` — the editor's in-scope
`suggestion` is nil on a direct visit (`editor.ex:107-115`), and `Article` has no `belongs_to(:suggestion)`.

**Scoped list read + scope helper** (`knowledge_automation.ex:36-70, 1965-1969`):
```elixir
defp repo, do: Application.fetch_env!(:cairnloop, :repo)

def list_article_suggestions(opts \\ []) do
  ArticleSuggestion
  |> apply_scope(opts)
  |> maybe_filter_article_suggestion_status(opts)
  |> order_by([suggestion], desc: suggestion.inserted_at, desc: suggestion.id)
  |> repo().all()
end

defp apply_scope(query, opts) do
  query
  |> maybe_where_equal(:tenant_scope, Keyword.get(opts, :tenant_scope))
  |> maybe_where_equal(:host_user_id, Keyword.get(opts, :host_user_id))
end
```

**Schema fields confirmed** (`article_suggestion.ex:29-31`): `entrypoint_type` is
`Ecto.Enum [:gap_candidate, :article_revision, :conversation_quick_fix]`; `entrypoint_id` is
`:integer`; `article_id` is `:integer`. **New fn (RESEARCH Pattern 4):**
```elixir
def originating_conversation_id(article_id, opts \\ []) do
  ArticleSuggestion
  |> apply_scope(opts)
  |> where([s], s.article_id == ^article_id and s.entrypoint_type == :conversation_quick_fix)
  |> order_by([s], asc: s.inserted_at)   # earliest origin if multiple (A2)
  |> limit(1)
  |> select([s], s.entrypoint_id)
  |> repo().one()
end
```
Only `:conversation_quick_fix` rows carry a conversation id (D-12); `:gap_candidate`/`:article_revision`
return nil → omit the crumb entirely (honest absence, D-12/Pitfall 4).

---

### `lib/cairnloop/web/audit_log_live.ex` — `handle_params/2` filter + per-row subject link (LiveView)

**No existing `handle_params/2` in this LV** (RESEARCH correction). Mirror the existing
`assign |> load_events` flow from `mount/3` and the `handle_event` clauses.

**Existing mount + load flow to extend** (`audit_log_live.ex:22-51`):
```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(query: "", action_filter: "all", limit: @page_size)
    |> load_events()
  {:ok, socket}
end

defp load_events(socket) do
  auditor = Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.Governance)
  events = auditor.list_events(limit: socket.assigns.limit)
  socket
  |> assign(events: events, maybe_more?: length(events) >= socket.assigns.limit)
  |> recompute()
end
```
**Add (RESEARCH Pattern 3, D-10):** two `handle_params/2` clauses — one matching
`%{"proposal" => raw}` that parses tolerantly (`Integer.parse/1`, fallback nil — V5 input validation,
Pitfall: never interpolate raw param into a query) and assigns a `proposal_filter`, one catch-all that
assigns nil; both pipe into `load_events`. Thread the filter into `auditor.list_events(...)` / the new
`Governance.list_action_events(proposal_id:)` opt. Keep the existing `events`/`visible_events` assign
shape and the `recompute/1` re-derivation untouched (D-09).

**Per-row subject link** — the table body row to extend (`audit_log_live.ex:133-137`):
```elixir
<tr :for={event <- @visible_events}>
  <td>{P.timestamp_label(Map.get(event, :inserted_at))}</td>
  <td>{P.actor_label(Map.get(event, :actor_id))}</td>
  <td>{P.action_label(Map.get(event, :action))}</td>
  ...
```
Use the **scope-relative** `<.link navigate>` idiom (D-14, Pitfall 3): `navigate={"/#{conversation_id}"}`,
NEVER mount-prefixed. When `conversation_id` is nil → render plain text, not a broken link (D-08).
Give the link an explicit accessible name ("View conversation"), mirroring the inbox `aria-label`
pattern (`inbox_live.ex:212,216`) — never row-as-link ambiguity (Pitfall 6, brand §7.5).

---

### `lib/cairnloop/web/audit_log_presenter.ex` — subject-link helper (presenter, transform)

**Analog:** the existing total fns (`:22-75`) — multi-clause head, explicit nil/`_` fallbacks, returns
strings/atoms/data only, never markup. A new `subject_href/1` (or `subject_link/1`) returning a path
string or nil belongs here, branching on the enriched `conversation_id`.

**Total-function idiom to mirror** (`audit_log_presenter.ex:54-74`):
```elixir
def actor_label(nil), do: "System"
def actor_label(""), do: "System"
def actor_label(actor) when is_binary(actor), do: actor
def actor_label(_), do: "System"

def timestamp_label(%DateTime{} = dt), do: ...
def timestamp_label(_), do: "—"
```
Return `nil` href on absent conversation_id; the row template branches on it (fail-closed, D-08).

---

### `lib/cairnloop/web/conversation_live.ex` — Next-in-queue in resolved region (LiveView)

**Analog:** `outbound_recovery_card/1` (`:531-545`) — the existing `@conversation.status == :resolved`
region (D-05). The affordance renders here, keyed off the same status. Mirror the back-link nav idiom
(`:438`) and the inbox row-link idiom (`inbox_live.ex:215`).

**Resolved-state region to attach to** (`conversation_live.ex:529-546`):
```elixir
attr(:conversation, :map, required: true)

def outbound_recovery_card(assigns) do
  ~H"""
  <%= if @conversation.status == :resolved do %>
    <.cl_card class="outbound-action-card" aria-label="Outbound recovery">
      <div class="outbound-action-eyebrow">Outbound recovery</div>
      <h3>Send Recovery Follow-up</h3>
      ...
```

**Scope-relative declarative nav idiom (D-14, Pitfall 3)** — back-link (`:438`) + inbox row (`inbox_live.ex:215`):
```elixir
<.link navigate="/inbox" class="cl-text-muted cl-text-small">&larr; Back to Inbox</.link>
# and
<.link navigate={"/#{conv.id}"} class="cl-grow">...</.link>
```

**Next-in-queue + Queue-clear (RESEARCH Code Examples, D-06)** — compute `@next_open_id` via
`Chat.next_open_conversation/1`; render in the resolved region:
```elixir
<%= case @next_open_id do %>
  <% nil -> %>
    <p class="cl-text-muted">Queue clear — no more open conversations.</p>
    <.link navigate="/inbox" class="cl-text-small">Back to inbox</.link>
  <% id -> %>
    <.link navigate={"/#{id}"} class="cl-button">Next in queue &rarr;</.link>
<% end %>
```
Copy is Claude's discretion (calm, reason-forward, brand §7.5 — text+tone, never color alone). Never a
dead/disabled "Next" or a stale-id navigate (D-06).

---

### `lib/cairnloop/web/conversation_live.ex` — audit deep-link in Tier-3 trace group (LiveView)

**Analog:** the governed-action card Tier-3 "Identifiers & trace" group (`:1082-1091`, P41 D-02). The
`@trace.proposal_id` is already in scope here — this is the placement for the gov-action→audit link (D-10).

**Tier-3 trace group** (`conversation_live.ex:1082-1091`):
```elixir
<%!-- Tier-3 standalone "Identifiers & trace" (D-02) — default-closed; NO data-tier --%>
<.cl_disclosure id={"ga-#{@proposal.id}-trace"}>
  <:summary>Identifiers &amp; trace</:summary>
  <.cl_fact_list facts={[
    %{label: "Proposal", value: "##{@trace.proposal_id}"},
    %{label: "Tool", value: @trace.tool_ref},
    %{label: "Version", value: @trace.tool_version},
    %{label: "Idempotency key", value: @trace.idempotency_key}
  ]} />
```
**Add (D-10):** a `<.link navigate={"/audit-log?proposal=#{@trace.proposal_id}"}>View audit trail</.link>`
in/after this group. Scope-relative (`/audit-log?...`), declarative `navigate` (D-14), explicit link text.

---

### `lib/cairnloop/web/knowledge_base_live/editor.ex` — article→conversation crumb (LiveView)

**Analog:** the breadcrumb slot (`:265-266`, RESEARCH-corrected line) + `BreadcrumbPresenter.editor_items/2`
(`:45-63`). Reuse `cl_breadcrumb` (`components.ex:395-405`) — do NOT build a new affordance (D-13).

**Breadcrumb slot** (`editor.ex:264-267`):
```elixir
<.cl_page title={"Editing: #{@article.title}"} width="wide">
  <:breadcrumb>
    <.cl_breadcrumb items={BreadcrumbPresenter.editor_items(@review_context.return_to, @article.title)} />
  </:breadcrumb>
```

**`cl_breadcrumb/1` items contract** (`components.ex:389-405`): list of `%{label, href}`; last item omits
`:href` (key absent, not nil); renders `<.link :if={item[:href]} navigate={item.href}>`.

**`BreadcrumbPresenter.editor_items/2` total-fn idiom to extend** (`breadcrumb_presenter.ex:45-63`):
```elixir
def editor_items(return_to, title) when is_binary(return_to) do
  origin = if String.starts_with?(return_to, "/knowledge-base"), do: "Suggestions", else: "Conversation"
  [%{label: origin, href: return_to},
   %{label: "Knowledge", href: "/knowledge-base"},
   %{label: "Editing: #{title}"}]
end

def editor_items(_return_to, title) do   # nil/non-binary fallback → 2-item static
  [%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: #{title}"}]
end
```
**Add:** resolve `KnowledgeAutomation.originating_conversation_id(@article.id, scope_filters)` at mount,
pass it through to the presenter (or add an origin crumb only when non-nil). The presenter already
derives a "Conversation" origin label — reuse that derivation. Crumb href must be scope-relative
`"/#{conversation_id}"` (Pitfall 3); omit entirely when nil (D-12, honest absence). The presenter
docstring (`:82-84`) already notes "cross-screen threading lands in Phase 42" — this is that work.

**Editor mount shape to thread the new read into** (`editor.ex:12-34`): `scope_filters(session)` is
already computed; `article.id` is in scope; add the read alongside the other `assign(...)` calls.

---

### Test files (headless render + facade unit) — no-Repo idiom

**Analog:** `audit_log_live_test.exs:1-63` — the dominant Repo-free render idiom (RESEARCH Validation).

**Headless `render/1`-with-built-assigns** (`audit_log_live_test.exs:7-20, 27-32`):
```elixir
use ExUnit.Case, async: true
import Phoenix.LiveViewTest

defp base_assigns do
  %{visible_events: [], query: "", action_filter: "all",
    action_options: [], maybe_more?: false, __changed__: nil}
end

test "..." do
  html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))
  assert html =~ ~s(cl-page cl-page--wide)
end
```
- **Link/render behaviors** (Next-in-queue link & Queue-clear, audit row link/plain-cell, audit
  deep-link in trace group, editor crumb present/omitted): fully headless via `render/1` + built
  assigns — extend `conversation_live_test.exs`, `audit_log_live_test.exs`,
  `audit_log_presenter_test.exs`, `breadcrumb_presenter_test.exs`, `editor_test.exs`.
- **Param tolerance** (`handle_params/2` for bad/absent `?proposal`): headless, no Repo.
- **Facade reads** (`next_open_conversation/1`, enriched auditor map FK join, `originating_conversation_id/2`):
  need a Postgres round-trip — write them, mark `# REPO-UNAVAILABLE`, run in `mix test.integration`.
- **Real route transition** (all 4 threads): add `examples/cairnloop_example/test/e2e/thread_navigation_test.exs`,
  mirror `rail_disclosure_test.exs` (`@moduletag :e2e`, `PhoenixTest.Playwright.Case`, `visit("/support/...")`).

## Shared Patterns

### Facade read indirection (NEVER `Cairnloop.Repo` in a LiveView)
**Source:** `chat.ex:6-8`, `knowledge_automation.ex:36-38`, `governance.ex` (`repo()` indirection, D-30).
**Apply to:** every new read. LiveViews call the facade fn; the facade calls `repo()`.
```elixir
defp repo, do: Application.fetch_env!(:cairnloop, :repo)
```
Criterion-4 intent = "facade, not raw Repo" (D-03). The literal text names `Governance`; honor the
intent with domain-correct ownership: queue→`Chat`, audit→`Governance`/`Auditor`, article→`KnowledgeAutomation`.

### Scope-root-relative declarative nav (RESEARCH correction #3 / Pitfall 3)
**Source:** `inbox_live.ex:181,215` (`/inbox`, `/#{conv.id}`), `conversation_live.ex:438` (`/inbox`).
**Apply to:** all four threads. `<.link navigate={"/#{id}"}>`, `<.link navigate="/inbox">`,
`<.link navigate={"/audit-log?proposal=#{id}"}>`. NEVER `/support/...` or any mount prefix — the host
owns the mount (`/support` in the example app); the library router is scope-relative (`router.ex:111-133`).
Reserve `push_navigate` for server-`handle_event`-triggered nav only; no `push_patch` (D-14).

### Fail-closed display (honest absence, never a dead link)
**Source:** established posture — `inbox_live.ex` empty states; `breadcrumb_presenter.ex` nil fallbacks.
**Apply to:** audit row (nil conversation_id → plain text), editor crumb (nil origin → omit), Next-in-queue
(nil → "Queue clear", never disabled/stale). A `navigate=` containing `nil`/empty segment is the warning sign (Pitfall 4).

### Total presenter functions
**Source:** `audit_log_presenter.ex:22-75`, `breadcrumb_presenter.ex:45-99`.
**Apply to:** any new presenter helper — multi-clause head with explicit nil/`_` fallback, returns
data/strings only (never markup, never raw Elixir terms to operators — brand §5.6/§7.5; mono only for ids).

### Tolerant param parsing (V5 input validation)
**Source:** RESEARCH Pattern 3 / Don't-Hand-Roll.
**Apply to:** `AuditLogLive.handle_params/2` `?proposal=` — `Integer.parse/1` with nil fallback; pin
with `^id` in the Ecto query (never string-interpolate). Total/crash-proof.

## No Analog Found

| File/Behavior | Role | Data Flow | Reason |
|---------------|------|-----------|--------|
| `AuditLogLive.handle_params/2` | LiveView callback | request-response | `AuditLogLive` has no `handle_params/2` today. Pattern is standard Phoenix (RESEARCH Pattern 3); no in-repo same-module analog. Mirror the `mount`→`assign`→`load_events` flow (`audit_log_live.ex:22-51`) for the assign/load half. |

No file is fully without guidance — every behavior has a same-module or sibling-module idiom to mirror;
only the `handle_params/2` callback shell itself is net-new to this LiveView.

## Metadata

**Analog search scope:** `lib/cairnloop/` (chat, auditor, governance, knowledge_automation facades;
web/ LiveViews, components, presenters), `test/cairnloop/web/`.
**Files read this pass:** `chat.ex`, `auditor.ex`, `governance.ex` (`:975-1029`), `knowledge_automation.ex`
(`:1-90, 1965-1994`), `article_suggestion.ex`, `web/audit_log_live.ex`, `web/audit_log_presenter.ex`
(`:1-75`), `web/conversation_live.ex` (`:425-549, 957-1091`), `web/components.ex` (`:385-419`),
`web/breadcrumb_presenter.ex`, `web/inbox_live.ex` (`:175-224`), `web/knowledge_base_live/editor.ex`
(`:1-60, 100-129, 255-279`), `test/cairnloop/web/audit_log_live_test.exs`.
**Pattern extraction date:** 2026-06-04
