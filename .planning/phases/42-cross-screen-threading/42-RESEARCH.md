# Phase 42: Cross-Screen Threading - Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView cross-view navigation; Ecto facade reads over an existing FK chain (no schema migration); Elixir host-owned library
**Confidence:** HIGH (every code citation verified against the live tree this session)

## Summary

Phase 42 wires four navigational threads between four currently-isolated LiveViews. The
`42-CONTEXT.md` is already a strong, decision-complete spine (D-01..D-14) with file:line
citations. This research **verified those citations against the live source tree**, found a
small number of drifted line numbers, and — more importantly — surfaced **three architectural
facts CONTEXT.md's decisions imply but do not spell out**, each of which changes the shape of a
task:

1. **The audit log does NOT read `Governance.list_action_events/1` directly.** It reads through
   a configurable `Cairnloop.Auditor` behaviour (`audit_log_live.ex:45` calls
   `auditor.list_events(limit:)`), and the default impl `Cairnloop.Auditor.Governance`
   **flattens each event to a plain map** `%{inserted_at:, actor_id:, action:, reason:, metadata:}`
   that deliberately **drops the `tool_proposal` association and all ids**. D-09's "carry
   `conversation_id` (+ proposal id) per event" therefore requires extending the **auditor
   normalization map**, not only `list_action_events/1`. (See Pitfall 1.)

2. **The KB editor only has a `suggestion` in scope on the editor-handoff path.** `load_suggestion/3`
   (`editor.ex:107-115`) returns `nil` unless the URL carries `"suggestion_id"`. A direct visit
   to `/knowledge-base/:id/edit` has no suggestion, and `Article` has **no `belongs_to(:suggestion)`**.
   So D-12's "resolve the originating conversation from the article's suggestion entrypoint"
   needs a **new article→suggestion lookup** (`ArticleSuggestion where article_id == ^id`), not
   reuse of the in-scope `suggestion`. (See Pitfall 2.)

3. **All existing cross-LiveView links use scope-root-relative absolute paths** (`/inbox`,
   `/#{conv.id}`, `/knowledge-base/...`) — never mount-prefixed, even though the library is
   mounted under `/support` in the example app. Threading links MUST mirror this exact idiom or
   they break under the host mount. (See Pitfall 3.)

**Primary recommendation:** Implement all four threads as **presenter/total-function reads +
declarative `<.link navigate=>`**, extending the existing facade seams (`Governance`, `Chat`,
`KnowledgeAutomation`) and the **`Auditor.Governance` normalization map**. Test headlessly via
`render/1`-with-built-assigns and presenter unit tests (the repo's dominant, Repo-free pattern);
reserve a thin E2E layer in `examples/cairnloop_example/test/e2e/` for proving the actual route
transition. No migration, no churn of the append-only audit table or sealed `propose/3` paths.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Next-in-queue resolution (THREAD-01) | API/Backend (`Cairnloop.Chat` facade) | LiveView (renders affordance) | Queue order is a domain read; the conversation facade owns conversation listing |
| Audit-row → subject enrichment (THREAD-02) | API/Backend (`Auditor.Governance` + `Governance` facade) | LiveView (renders link) | The FK hop (event→proposal→conversation) is a domain read; web layer only renders |
| Governed-action → audit deep-link (THREAD-03) | LiveView (`handle_params/2` filter) | API/Backend (`Governance.list_action_events(proposal_id:)`) | Deep-link param handling is a view concern; the filtered read is a facade extension |
| Article → originating-conversation (THREAD-03) | API/Backend (`KnowledgeAutomation` article→suggestion lookup) | LiveView/Presenter (breadcrumb) | Entrypoint resolution is a domain read; breadcrumb is presentation |

**Why this matters:** Each thread is a *read + render*, never new workflow state. The link
target (a conversation id, an audit filter, a proposal id) is structural/navigational, not a
trust fact — so resolving it at render time does NOT violate snapshot-at-decision (D-02 verified
against `PROJECT.md` posture; it governs risk tier / policy outcome / confidence, none of which
these reads touch).

## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01..D-14 — verbatim spine)
- **D-01:** Resolve audit-row→conversation via the existing FK chain at read time — do NOT add
  `conversation_id` to `ToolActionEvent`. **[VERIFIED]** `tool_action_event.ex:61` `belongs_to(:tool_proposal)`; `tool_proposal.ex:55` `belongs_to(:conversation)`; `tool_action_event.ex:64` `timestamps(..., updated_at: false)` (insert-only, no update/delete API — `:111`).
- **D-02:** Snapshot-at-decision is not violated by D-01 (link target is structural FK, not a trust-fact re-read). **[VERIFIED against PROJECT.md posture.]**
- **D-03:** Honor the *spirit* of criterion-4 ("no direct `Repo` in LiveViews") with domain-correct facade ownership: governed-action/audit→`Governance`; conversation/queue→`Chat`; article→conversation→KB read path. **[VERIFIED: criterion-4 text at `ROADMAP.md:150`.]**
- **D-04 [veto-cheap]:** "Next" mirrors the inbox's existing canonical order (`desc: :updated_at`, status-scoped); next = first **open** conversation in that order excluding current id. **[VERIFIED]** `chat.ex:11-13` ordering; `chat.ex:41-46` `scope_status/2`.
- **D-05:** Affordance attaches to existing `status == :resolved` state — no new "mark handled" action. **[VERIFIED]** the resolved-state region is `outbound_recovery_card/1` keyed on `@conversation.status == :resolved` (`conversation_live.ex:531-545`); recovery gate `:221-235`.
- **D-06:** End-of-queue is honest/calm — `next_open_conversation/1` returns `nil` → render "Queue clear" linking to `/inbox`; never a dead/disabled Next or stale-id navigate.
- **D-07:** `next_open_conversation/1` is a cheap scoped read (P39 D-09 pattern: scoped query, no full-list `Enum`); return next open conversation **id (or nil)**; deterministic tiebreak by `id`.
- **D-08:** Each audit row links to its subject conversation; rows whose proposal has no conversation degrade to a non-linked row (fail-closed). **[VERIFIED: graceful-absence is the established display posture.]**
- **D-09:** Extend the audit read, not the schema — the audit read carries `conversation_id` (+ proposal id) per event; keep `events`/`visible_events` assign shape. **[VERIFIED + CORRECTED — see Pitfall 1: the extension point is the `Auditor.Governance` normalization map, AND `list_action_events/1` already preloads `:tool_proposal`.]**
- **D-10 [veto-cheap]:** Governed-action→audit links to the audit log *filtered to that action* via `?proposal=<id>`; `AuditLogLive.handle_params/2` reads it and filters through the facade. **[VERIFIED + CORRECTED — `AuditLogLive` has NO `handle_params/2` yet; `list_action_events/1` has NO `proposal_id` filter yet. Both are net-new extensions.]**
- **D-11:** No new signed-token return path; use plain declarative nav + existing breadcrumb shell. **[VERIFIED: `editor_handoff.ex` token is editor-specific.]**
- **D-12:** Resolve originating conversation from the article's suggestion entrypoint; render link ONLY when `entrypoint_type == :conversation_quick_fix`; omit for `:gap_candidate`/`:article_revision`. **[VERIFIED + CORRECTED — see Pitfall 2: needs an article→suggestion lookup; the in-scope `suggestion` is nil on direct visits.]**
- **D-13:** Surface the link in the KB editor breadcrumb/header reusing `cl_breadcrumb` + `BreadcrumbPresenter`. **[VERIFIED, citation corrected: breadcrumb slot is `editor.ex:265-266`, NOT `:195-196`; component `components.ex:395`; presenter `editor_items/2` at `breadcrumb_presenter.ex:45`.]**
- **D-14:** Use declarative `<.link navigate={…}>` for all four threads; reserve `push_navigate` for server-`handle_event`-triggered nav; no `push_patch`. **[VERIFIED]** mirror `inbox_live.ex:215` and `conversation_live.ex:438`.

### Claude's Discretion
- Exact facade fn names/signatures (`next_open_conversation/1` arg shape; subject refs on struct vs thin presenter map).
- Exact deep-link param name (`proposal` vs `proposal_id`); whether to also accept a `trace`/idempotency-key form.
- Copy for "Next in queue" and "Queue clear" (calm, reason-forward, brand §7.5 — text+tone, never color alone).
- Whole-row link vs explicit "View conversation" element (a11y: ensure accessible name; avoid row-as-link ambiguity).
- Placement of gov-action→audit link within the card (likely the Tier-3 "Identifiers & trace" group, P41 D-02).

### Deferred Ideas (OUT OF SCOPE)
- Manual "mark resolved/handled" action.
- Queue prioritization / risk-weighted ordering.
- Persisted/shareable "return to where I came from" stacks beyond the breadcrumb shell.
- Adding `conversation_id` (or denormalized subject) to `ToolActionEvent`.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| THREAD-01 | After resolving a conversation, "next in queue" advances the operator | Next-in-queue = `Chat.next_open_conversation/1` (new): scoped `where status==:open`, `order_by [desc: :updated_at, asc/desc: :id]`, `where id != current`, `limit 1`, `select :id`. Affordance in `outbound_recovery_card/1` (resolved-state region). `nil` → "Queue clear" state. |
| THREAD-02 | Audit rows link to subject (conversation / governed action) | Enrich `Auditor.Governance.list_events/1` map with `conversation_id` (from already-preloaded `event.tool_proposal.conversation_id`) + `proposal_id`; presenter exposes a subject link; row degrades to non-link when conversation_id is nil. |
| THREAD-03 | Gov-action card → audit entry; KB article → originating conversation | (a) Card Tier-3 trace group gains `<.link navigate={"/audit-log?proposal=#{@trace.proposal_id}"}>`; `AuditLogLive.handle_params/2` reads `proposal` and filters. (b) KB editor resolves article→suggestion→`entrypoint_id` (when `:conversation_quick_fix`) and renders a breadcrumb/header link to `/#{conversation_id}`. |

## Standard Stack

No new external packages. This phase is pure in-repo Elixir/Phoenix LiveView/Ecto.

### Core (already present — extend, do not add)
| Module | Purpose | Why used |
|--------|---------|----------|
| `Cairnloop.Governance` (`governance.ex`) | Audit/proposal read facade | `list_action_events/1` (`:998`), `list_events/1` (`:978`), `get_proposal/1` (`:579`), `list_proposals_for_conversation/2` (`:1018`) — the sanctioned read seam (D-30). |
| `Cairnloop.Chat` (`chat.ex`) | Conversation read facade | `list_conversations/0,1` (`:10,:20`), `count_conversations/1` (`:30`), `scope_status/2` (`:41`), ordering `desc: :updated_at`. Add `next_open_conversation/1` here. |
| `Cairnloop.Auditor` behaviour (`auditor.ex`) | Pluggable audit read | `list_events/1` callback; default impl `Cairnloop.Auditor.Governance` normalizes events to flat maps. **D-09's true extension point.** |
| `Cairnloop.KnowledgeAutomation` (`knowledge_automation.ex`) | Suggestion/article read facade | `list_article_suggestions/1` (`:64`), `get_article_suggestion!/2` (`:72`). Add an article→originating-conversation read here. |
| `Cairnloop.Web.BreadcrumbPresenter` (`breadcrumb_presenter.ex`) | Breadcrumb item derivation | `editor_items/2` (`:45`) already handles the bare `/N` conversation path shape — extend for the entrypoint-derived crumb. |
| `cl_breadcrumb/1` (`components.ex:395`) | Breadcrumb render | `items={[%{label, href}]}`, last item omits `:href`. |

**Installation:** none.

## Package Legitimacy Audit

Not applicable — Phase 42 installs no external packages. All work extends in-repo modules.

## Architecture Patterns

### System Data Flow (the four threads)

```
THREAD-01 (next-in-queue)
  resolved ConversationLive (outbound_recovery_card region)
    └─ render-time call → Chat.next_open_conversation(current_id)
         └─ scoped query: where status==:open, id != current, order updated_at desc, limit 1, select :id
              ├─ id  → <.link navigate={"/#{id}"}>Next in queue</.link>
              └─ nil → calm "Queue clear" state → <.link navigate="/inbox">

THREAD-02 (audit-row → subject)
  AuditLogLive.load_events
    └─ auditor.list_events(limit:)            [Cairnloop.Auditor behaviour]
         └─ Auditor.Governance.list_events    → Governance.list_action_events (preloads :tool_proposal)
              └─ MAP each event to %{..., conversation_id: e.tool_proposal.conversation_id, proposal_id: e.tool_proposal_id}
                   └─ AuditLogPresenter exposes subject link
                        ├─ conversation_id present → <.link navigate={"/#{conversation_id}"}>
                        └─ nil → plain text cell (fail-closed, no broken link)

THREAD-03a (gov-action card → audit)
  ConversationLive governed-action card, Tier-3 "Identifiers & trace" group (@trace.proposal_id)
    └─ <.link navigate={"/audit-log?proposal=#{@trace.proposal_id}"}>View audit trail</.link>
         └─ AuditLogLive.handle_params(%{"proposal" => id}) → assign(proposal_filter: id) → load filtered
              └─ Governance.list_action_events(proposal_id: id)   [NEW opt]
                   (or Governance.list_events(proposal_id) + normalize)

THREAD-03b (article → originating conversation)
  KnowledgeBaseLive.Editor.mount
    └─ KnowledgeAutomation.originating_conversation_id(article_id)   [NEW read]
         └─ ArticleSuggestion where article_id==^id, entrypoint_type==:conversation_quick_fix → entrypoint_id
              ├─ id  → breadcrumb/header link <.link navigate={"/#{id}"}>From conversation</.link>
              └─ nil → omit link entirely (honest absence; gap/revision articles legitimately have none)
```

### Pattern 1: Cheap scoped "next" read (THREAD-01, follows P39 D-09)
**What:** Single-row scoped query selecting only the id; never `list_conversations |> Enum.find`.
**When:** Computing the next open conversation at render time in the resolved region.
**Example:**
```elixir
# lib/cairnloop/chat.ex  — additive sibling to list_conversations/1
# Source: mirrors chat.ex:20-24 (ordering) + chat.ex:30-33 (cheap-read pattern, P39 D-09)
@doc """
Returns the id of the next open conversation in the inbox's canonical order
(`updated_at desc`), excluding `current_id`, or `nil` when the queue is clear.
Deterministic tiebreak by id so a tie never yields a nondeterministic "next".
"""
def next_open_conversation(current_id) do
  Cairnloop.Conversation
  |> where([c], c.status == :open and c.id != ^current_id)
  |> order_by([c], desc: c.updated_at, desc: c.id)   # tiebreak by id
  |> limit(1)
  |> select([c], c.id)
  |> repo().one()
end
```
*Tiebreak direction is Claude's discretion (D-07 only mandates determinism); `desc: :id` keeps newest-first consistent with `updated_at desc`.*

### Pattern 2: Enrich the auditor normalization map (THREAD-02 — the real D-09)
**What:** Add ids to the flat event map; `list_action_events/1` already preloads `:tool_proposal`.
**When:** Backing the audit-row subject link.
**Example:**
```elixir
# lib/cairnloop/auditor/governance.ex  — extend the existing Enum.map
# Source: auditor.ex Cairnloop.Auditor.Governance.list_events/1 (verified this session)
def list_events(opts) do
  opts
  |> Governance.list_action_events()          # already preloads :tool_proposal
  |> Enum.map(fn event ->
    proposal = event.tool_proposal            # may be nil only if FK broken (shouldn't happen)
    %{
      inserted_at: event.inserted_at,
      actor_id: event.actor_id,
      action: event.event_type,
      reason: event.reason,
      metadata: event.metadata || %{},
      # NEW (D-09): navigational subject refs — structural FK, not a trust fact
      conversation_id: proposal && proposal.conversation_id,
      proposal_id: event.tool_proposal_id
    }
  end)
end
```
**Why here, not in `list_action_events/1`:** the LiveView consumes the *auditor* result
(`audit_log_live.ex:45`), and the existing map drops these fields. Adding them only to
`list_action_events/1` would never reach the row. (Custom-auditor hosts won't get the link —
acceptable; the link degrades to absence, which is the fail-closed contract.)

### Pattern 3: Deep-link param via `handle_params/2` (THREAD-03a)
**What:** Add `handle_params/2` to `AuditLogLive` (it has none today) to read `?proposal=<id>`.
**When:** Filtering the audit log to one action's trail.
**Example:**
```elixir
# lib/cairnloop/web/audit_log_live.ex — NEW callback
def handle_params(%{"proposal" => raw}, _uri, socket) do
  proposal_id = parse_id(raw)   # tolerant: integer or nil
  {:noreply, socket |> assign(proposal_filter: proposal_id) |> load_events()}
end
def handle_params(_params, _uri, socket) do
  {:noreply, socket |> assign(proposal_filter: nil) |> load_events()}
end
```
Then `load_events/1` passes the filter to the auditor/facade. Add `proposal_id:` support to
`Governance.list_action_events/1` (a `where e.tool_proposal_id == ^id` when present), OR reuse
`Governance.list_events(proposal_id)` (already exists, `:978`) and normalize it the same way.
The facade extension is cleaner because it keeps one normalization path.

### Pattern 4: Article → originating conversation lookup (THREAD-03b)
**What:** New `KnowledgeAutomation` read; resolve via `ArticleSuggestion.article_id`.
**When:** KB editor mount, to conditionally render the breadcrumb back-link.
**Example:**
```elixir
# lib/cairnloop/knowledge_automation.ex — NEW read (Article has no belongs_to(:suggestion))
@doc "Conversation id that originated this article (via its suggestion entrypoint), or nil."
def originating_conversation_id(article_id, opts \\ []) do
  ArticleSuggestion
  |> apply_scope(opts)
  |> where([s], s.article_id == ^article_id and s.entrypoint_type == :conversation_quick_fix)
  |> order_by([s], asc: s.inserted_at)        # earliest origin if multiple
  |> limit(1)
  |> select([s], s.entrypoint_id)
  |> repo().one()
end
```
*Multiple suggestions can target one article (revisions); take the earliest `:conversation_quick_fix`
as the true origin. `entrypoint_id` is `:integer` (`article_suggestion.ex:30`).*

### Anti-Patterns to Avoid
- **Reading `Cairnloop.Repo` directly in any LiveView** — violates criterion-4/D-30; route through a facade.
- **Adding columns to `ToolActionEvent`** — append-only/insert-only invariant (D-01).
- **`<.link navigate="/support/...">` or any mount-prefixed path** — links are scope-root-relative (Pitfall 3).
- **Loading the full next conversation just to get its id** — use a `select`-only scoped read (D-07).
- **Rendering a disabled/placeholder link on absence** — fail-closed = omit or non-link text (D-06/D-08/D-12).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audit-row subject resolution | A new `conversation_id` column + migration | FK chain read via preloaded `event.tool_proposal.conversation_id` | Insert-only audit invariant; FK already exists (D-01) |
| Breadcrumb back-link UI | A bespoke "return to conversation" widget | `cl_breadcrumb/1` + `BreadcrumbPresenter.editor_items/2` | P38 orientation layer already handles the `/N` shape (D-13) |
| Deep-link return path | A new signed `return_to` token | Plain `<.link navigate>` + breadcrumb shell | `editor_handoff.ex` token is editor-specific; don't generalize (D-11) |
| Queue ordering | A new ordering/queue field | Mirror inbox `order_by desc: :updated_at` | "Next" must match the list the operator just left (D-04) |
| Date/id parsing for params | Custom regex | `Integer.parse/1` with tolerant fallback | Total, crash-proof param handling |

**Key insight:** Every thread is a *read over data that already exists*. The temptation is to
denormalize (add a column) or build new return-path machinery; both violate carried invariants.

## Runtime State Inventory

This is an additive code/UI phase — **no rename, no migration, no data backfill**. Each
category checked explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no schema change, no key/collection rename. Reads use existing FKs. | None — verified: no migration in scope (D-01, CONTEXT boundary). |
| Live service config | None — no external service config references threading. | None. |
| OS-registered state | None — no scheduled tasks / process names involved. | None. |
| Secrets/env vars | None — no new secret or env var. `:auditor` is an existing app-env config (`audit_log_live.ex:45`), unchanged. | None. |
| Build artifacts | None — pure source additions; no package rename, no egg-info/build output. | `mix compile --warnings-as-errors` after changes (standard gate). |

**Canonical question — "after every file is updated, what runtime state still has stale data?"**
Answer: **nothing.** The phase adds read functions and links; it writes no new persistent state.

## Common Pitfalls

### Pitfall 1: D-09 extension point is the auditor map, not just `list_action_events/1`
**What goes wrong:** A planner reads D-09 ("extend `list_action_events/1`") literally, adds
`conversation_id` there, and the audit row still can't link — because `AuditLogLive` consumes
`Cairnloop.Auditor.Governance.list_events/1` (`audit_log_live.ex:45`), whose normalization map
**drops** the proposal/ids.
**Why:** The audit log is decoupled from `Governance` by the pluggable `Cairnloop.Auditor`
behaviour (hosts can swap auditors). The default impl flattens events.
**How to avoid:** Add `conversation_id` + `proposal_id` to the **`Auditor.Governance.list_events/1`
map** (Pattern 2). `list_action_events/1` already preloads `:tool_proposal`, so no extra query.
**Warning sign:** An audit-row link test passes against `list_action_events/1` output but fails
against rendered LiveView HTML.

### Pitfall 2: KB editor has no `suggestion` on a direct visit
**What goes wrong:** Using the in-scope `@suggestion` (from `load_suggestion/3`) to resolve the
originating conversation works only when the URL has `"suggestion_id"` (editor-handoff). A direct
visit to `/knowledge-base/:id/edit` has `suggestion == nil` → the back-link silently never renders.
**Why:** `load_suggestion/3` (`editor.ex:107-115`) is param-gated; `Article` has no
`belongs_to(:suggestion)` (`article.ex` has only `title`, `status`, `has_many :revisions`).
**How to avoid:** Resolve via a **new article→suggestion lookup** keyed on
`ArticleSuggestion.article_id` (Pattern 4), independent of the handoff param.
**Warning sign:** Back-link appears from the review-task flow but is absent when an operator opens
the article from the KB index.

### Pitfall 3: Scope-relative paths — never mount-prefix
**What goes wrong:** Writing `<.link navigate="/support/#{id}">` (because E2E visits `/support/...`)
breaks navigation when a host mounts the library under a different scope.
**Why:** Every existing library link is **scope-root-relative**: `inbox_live.ex:215` `/#{conv.id}`,
`:181` `/inbox`, `conversation_live.ex:438` `/inbox`, `:1493` `/knowledge-base/suggestions?...`.
The mount prefix (`/support` in the example) is the host's concern, not the library's.
**How to avoid:** Mirror the idiom exactly — `/#{conv_id}`, `/audit-log?proposal=#{id}`,
`/knowledge-base/#{id}/edit`. The router defines them scope-relative (`router.ex:119-133`).
**Warning sign:** E2E passes at `/support/...` but the link href is `/support/support/...` or 404s.

### Pitfall 4: Broken/dead links on absent subject
**What goes wrong:** Audit row for a proposal with no conversation, or an article with no
`:conversation_quick_fix` suggestion, renders a link to `/` or `/nil`.
**Why:** `proposal.conversation_id` can be nil; gap/revision articles have no originating conv.
**How to avoid:** Fail-closed — render plain text (audit) or omit the crumb (article) when the
id is nil. Presenter returns `nil` href; the row/crumb branches on it (D-06/D-08/D-12).
**Warning sign:** A `navigate=` attribute containing `nil` or an empty segment.

### Pitfall 5: Churning sealed paths / the append-only table
**What goes wrong:** Adding an update API or column to `ToolActionEvent`, or touching `propose/3`.
**Why:** Insert-only invariant (`tool_action_event.ex:10-11,64,111`); seal-completed-phases posture.
**How to avoid:** Read-only over the existing FK; all four threads are additive.

### Pitfall 6: a11y — accessible name on row links
**What goes wrong:** Whole-row-as-link with no discernible accessible name, or a bare `/N`
link that screen readers announce as the path.
**How to avoid:** Give the link explicit text ("View conversation") or an `aria-label`
(mirror `inbox_live.ex:216` `aria-label={"Select conversation: ..."}`). Brand §7.5: never
state-by-color-alone — the link must read as a link by text, not color.

## Code Examples

(See Patterns 1–4 above — each is a verified seam with file:line provenance.)

### Affordance placement in the resolved region (THREAD-01)
```elixir
# lib/cairnloop/web/conversation_live.ex — inside/adjacent to outbound_recovery_card/1
# Source: conversation_live.ex:531-545 (the `@conversation.status == :resolved` region)
<%= if @conversation.status == :resolved do %>
  <%= case @next_open_id do %>
    <% nil -> %>
      <p class="cl-text-muted">Queue clear — no more open conversations.</p>
      <.link navigate="/inbox" class="cl-text-small">Back to inbox</.link>
    <% id -> %>
      <.link navigate={"/#{id}"} class="cl-button">Next in queue &rarr;</.link>
  <% end %>
<% end %>
```
*Compute `@next_open_id` once at mount/assign time via `Chat.next_open_conversation/1` — Claude's
discretion whether it rides an assign vs a presenter; copy is discretion (calm, reason-forward).*

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Each cockpit screen a dead-end leaf | Cross-screen threads via facade reads + declarative nav | Phase 42 | Operator follows work across surfaces |
| (none) | `Cairnloop.Auditor` pluggable behaviour decouples audit read | pre-existing (P35 era) | D-09 must extend the auditor map, not just `Governance` |

**Deprecated/outdated:** none relevant.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Tiebreak `desc: :id` is acceptable for next-in-queue determinism | Pattern 1 | Low — D-07 only mandates determinism; any consistent tiebreak satisfies it |
| A2 | Earliest `:conversation_quick_fix` suggestion is the canonical origin when an article has several | Pattern 4 | Low — picks the genuine first-origin; reversible (it's a sort choice) |
| A3 | Custom-auditor hosts forgoing the subject link is acceptable | Pattern 2 / Pitfall 1 | Low — degrades to fail-closed absence, the established contract |

**No table is empty:** these three are genuine open choices left to the planner; none clear the
VERY-impactful escalation bar.

## Open Questions

1. **`?proposal` filter via new `list_action_events(proposal_id:)` opt vs reuse `list_events/1`?**
   - Known: `list_events/1` (`:978`) already filters by `proposal_id` (positional) but returns
     raw structs; `list_action_events/1` is the auditor-backed timeline path.
   - Unclear: which keeps a single normalization path cleanest.
   - Recommendation: add `proposal_id:` opt to `list_action_events/1` so the auditor's one
     normalization map serves both filtered and unfiltered reads (Claude's discretion per CONTEXT).

2. **Whole-row link vs explicit "View conversation" element (a11y).**
   - Recommendation: explicit link element with visible text — avoids row-as-link ambiguity and
     guarantees an accessible name (CONTEXT lists this as discretion; lean explicit).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/`mix` | build + headless tests | ✓ (repo standard) | pin 1.19.5 (CI parity per memory) | — |
| `Cairnloop.Repo` (Postgres) | integration/E2E only | ✗ in this workspace (known caveat) | — | Headless `render/1` + presenter tests cover all four threads; DB-round-trip tests marked `# REPO-UNAVAILABLE` |
| `phoenix_test_playwright` | example-app E2E | ✓ in `examples/cairnloop_example` (`mix.exs:53`, `~> 0.14`) | — | E2E runs only in the example app via `mix test.e2e` (gated CI lane) |

**Missing with no fallback:** none.
**Missing with fallback:** `Cairnloop.Repo` — use the dominant headless pattern (verified in
`audit_log_live_test.exs:1-20`: `render/1` with built assigns, `async: true`, no Repo).

## Validation Architecture

> nyquist_validation is ENABLED (config has no `workflow.nyquist_validation` key → default on).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in); `Phoenix.LiveViewTest` for render assertions; `phoenix_test_playwright ~> 0.14` for E2E |
| Config file | `mix.exs` aliases (`:test`, `test.integration`, `test.e2e`); example app `examples/cairnloop_example/mix.exs` |
| Quick run command | `mix test` (DB-free; excludes `:integration` — `mix.exs:88-90`) |
| Full suite command | `mix test.integration` (DB-backed) + quality lane; `cd examples/cairnloop_example && mix test.e2e` (browser) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| THREAD-01 | `next_open_conversation/1` returns next-open id / nil; tiebreak by id | unit (DB) | `mix test.integration test/cairnloop/chat_test.exs` | ❌ Wave 0 (add cases) |
| THREAD-01 | Resolved region renders "Next in queue" link / "Queue clear" on nil | headless render | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend |
| THREAD-02 | Audit map carries `conversation_id`/`proposal_id`; nil → no link | unit | `mix test test/cairnloop/auditor_governance_test.exs` (map shape — pure if events pre-built) / DB for FK join | ❌ Wave 0 |
| THREAD-02 | Audit row renders subject link / plain cell on absence | headless render + presenter | `mix test test/cairnloop/web/audit_log_live_test.exs` + `audit_log_presenter_test.exs` | ✅ extend both |
| THREAD-03a | `?proposal=<id>` filters audit; `handle_params/2` total for bad/absent param | headless render | `mix test test/cairnloop/web/audit_log_live_test.exs` | ✅ extend |
| THREAD-03a | Card Tier-3 group renders audit deep-link with `@trace.proposal_id` | headless render | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend |
| THREAD-03b | `originating_conversation_id/2`: `:conversation_quick_fix`→id; others→nil | unit (DB) | `mix test.integration test/cairnloop/knowledge_automation_test.exs` | ❌ Wave 0 |
| THREAD-03b | Editor breadcrumb renders/omits the conversation crumb | headless render + presenter | `mix test test/cairnloop/web/knowledge_base_live/editor_test.exs` + `breadcrumb_presenter_test.exs` | ✅ extend |
| all 4 | Real route transition actually navigates (no JS-blind blind spot) | E2E (browser) | `cd examples/cairnloop_example && mix test.e2e` | ❌ Wave 0 (add `thread_navigation_test.exs`) |
| criterion-4 | No new `Cairnloop.Repo` in LiveViews | static/grep test | extend a grep-based gate or add to brand-token-style gate | ❌ Wave 0 (optional guard) |

**Repo-unavailable handling:** Behaviors needing a Postgres round-trip (the FK join in THREAD-02,
the scoped queries in THREAD-01/03b) are written but marked `# REPO-UNAVAILABLE` where they can't
run in this workspace; they run in the `mix test.integration` lane. The **link-rendering and
param-tolerance** behaviors are fully covered headless via `render/1`-with-built-assigns (no Repo).

### Sampling Rate
- **Per task commit:** `mix test` (headless, fast) + `mix compile --warnings-as-errors`.
- **Per wave merge:** `mix test.integration` (DB-backed reads) + quality lane.
- **Phase gate:** full suite green + `cd examples/cairnloop_example && mix test.e2e` (proves the
  navigation actually transitions in a real browser) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/cairnloop/chat_test.exs` — `next_open_conversation/1` cases (covers THREAD-01 read).
- [ ] `test/cairnloop/auditor_governance_test.exs` — enriched map shape (covers THREAD-02).
- [ ] `test/cairnloop/knowledge_automation_test.exs` — `originating_conversation_id/2` cases (THREAD-03b).
- [ ] `examples/cairnloop_example/test/e2e/thread_navigation_test.exs` — real-browser transition for the 4 threads (mirror `rail_disclosure_test.exs` structure; `@moduletag :e2e`; uses `visit("/support/...")` + fixtures).
- [ ] Extend existing: `conversation_live_test.exs`, `audit_log_live_test.exs`, `audit_log_presenter_test.exs`, `breadcrumb_presenter_test.exs`, `knowledge_base_live/editor_test.exs`.

*Existing headless test infra (e.g. `audit_log_live_test.exs` `base_assigns/0` + `rendered_to_string`)
covers the render-side of all four threads with no new framework.*

## Security Domain

`security_enforcement` is not disabled in config → applies, but this is a low-surface phase.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V4 Access Control | yes | Reads go through scoped facades (`apply_scope/2` in KnowledgeAutomation; tenant scope on conversation/audit reads). Deep-link `?proposal=<id>` must not bypass the operator's existing scope — the facade read already enforces it; do NOT add an unscoped query. |
| V5 Input Validation | yes | `?proposal=<id>` parsed with `Integer.parse/1`, tolerant fallback to nil (no crash, no raw interpolation into queries — Ecto pins parameterize). |
| V6 Cryptography | no | No new tokens (D-11 keeps links plain). |
| V2/V3 Auth/Session | no | No new auth/session surface; host owns the live_session. |

### Known Threat Patterns for Phoenix LiveView + Ecto
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant deep-link (operator opens `?proposal=<id>` for another tenant's action) | Info Disclosure | Filter through the scoped facade read, not a raw `Repo` query — the scope is already enforced in `apply_scope/2`/governance reads (D-30) |
| Param injection via `?proposal` | Tampering | `Integer.parse/1` + Ecto parameterized pin (`^id`) — never string-interpolate into a query |
| Raw atom/term leak to operator HTML | Info Disclosure | Humanize via presenters (existing posture, `audit_log_presenter_test.exs`); never render raw ids except behind the mono trace expander (brand §7.5) |

## Sources

### Primary (HIGH confidence — verified in-tree this session)
- `lib/cairnloop/chat.ex:10-46` — `list_conversations/0,1`, `count_conversations/1`, `scope_status/2`, `order_by desc: :updated_at`.
- `lib/cairnloop/governance.ex:579,978,998,1018` — `get_proposal/1`, `list_events/1`, `list_action_events/1` (preloads `:tool_proposal`), `list_proposals_for_conversation/2`.
- `lib/cairnloop/auditor.ex` — `Cairnloop.Auditor` behaviour + `Auditor.Governance.list_events/1` flat-map normalization (the D-09 extension point).
- `lib/cairnloop/governance/tool_action_event.ex:10-11,61,64,111` — insert-only invariant, `belongs_to(:tool_proposal)`.
- `lib/cairnloop/governance/tool_proposal.ex:55` — `belongs_to(:conversation)`.
- `lib/cairnloop/knowledge_automation/article_suggestion.ex:9,29-30` — entrypoint enum values, `entrypoint_type`/`entrypoint_id` (`:integer`).
- `lib/cairnloop/knowledge_automation.ex:64,72` — `list_article_suggestions/1`, `get_article_suggestion!/2`.
- `lib/cairnloop/knowledge_base/article.ex:5-9` — Article schema (NO `belongs_to(:suggestion)`).
- `lib/cairnloop/web/audit_log_live.ex:22,40-49,53-65,123-159` — mount, `load_events/1` (calls `auditor.list_events`), `recompute/1`, table markup (no `handle_params/2`).
- `lib/cairnloop/web/conversation_live.ex:221-235,434-438,438,531-545,816,1082-1090,1493` — resolved region (`outbound_recovery_card/1`), back-to-inbox link, scope-relative nav, Tier-3 trace group (`@trace.proposal_id`), `review_task_path/1`.
- `lib/cairnloop/web/knowledge_base_live/editor.ex:12-32,107-115,263-266` — mount, `load_suggestion/3` (nil on direct visit), breadcrumb slot (corrected to `:265-266`).
- `lib/cairnloop/web/components.ex:390-405` — `cl_breadcrumb/1`.
- `lib/cairnloop/web/breadcrumb_presenter.ex:45,82-86` — `editor_items/2`; docstring confirming "cross-screen threading lands in Phase 42".
- `lib/cairnloop/web/inbox_live.ex:181,215-216` — canonical row link + a11y aria-label pattern.
- `lib/cairnloop/router.ex:111-133` — scope-relative routes (`/audit-log`, `/:id`, `/knowledge-base/:id/edit`).
- `lib/cairnloop/conversation.ex:5-6` — status enum `[:open, :resolved, :archived]`.
- `mix.exs:88-90` — `mix test` DB-free / excludes `:integration`; `test.integration` alias.
- `test/cairnloop/web/audit_log_live_test.exs:1-20` — headless `render/1`+`base_assigns/0`, `async: true`, no Repo.
- `test/cairnloop/web/audit_log_presenter_test.exs`, `breadcrumb_presenter_test.exs` — pure total-function presenter test pattern.
- `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs:1-40` + `examples/cairnloop_example/mix.exs:53,127-136` — E2E harness (`PhoenixTest.Playwright.Case`, `:e2e` tag, `visit("/support/...")`, `mix test.e2e`).
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex:42` — library mounted at `/support`.

### Secondary
- `.planning/REQUIREMENTS.md:51-53` (THREAD-01..03); `.planning/ROADMAP.md:142-152` (Phase 42 goal + 4 success criteria).
- `./CLAUDE.md` — facade-read / snapshot-at-decision / seal-completed-phases / brand-token / calm-copy invariants.

### Tertiary (LOW)
- None — all claims verified in-tree.

## Project Constraints (from CLAUDE.md)
- Warnings-clean build mandatory: `mix compile --warnings-as-errors`.
- `mix test` before declaring done; report failures honestly. (Default `mix test` is DB-free; validate DB-backed reads with `mix test.integration` + quality lane, and browser nav with `mix test.e2e` per memory.)
- `Cairnloop.Repo` may be unavailable here — prefer headless/pure tests; mark genuine round-trips `# REPO-UNAVAILABLE`.
- Durable Ecto records + events are truth; `:telemetry` is observability only — irrelevant here (reads only).
- New reads go through the narrow facade (`Governance`/`Chat`/`KnowledgeAutomation`), never direct schema queries from the web layer.
- Snapshot trust facts at decision time; never re-read live config at render time. (D-02: link targets are structural FKs, not trust facts — carve-out applies.)
- Seal completed phases / additive over invasive — do NOT churn `propose/3`, idempotency, co-commit, or the append-only audit table.
- Operator copy calm, fail-closed, reason-forward, honest; never raw Elixir terms/JSON; never state-by-color-alone (brand §7.5); mono only for ids/traces.
- Brand tokens over hardcoded hex (`var(--cl-primary, #A94F30)`).

## Metadata

**Confidence breakdown:**
- Standard stack / facade seams: HIGH — every fn + line verified in-tree.
- Architecture (the 3 corrections): HIGH — auditor indirection, editor suggestion-nil, scope-relative paths all confirmed by reading source.
- Pitfalls: HIGH — derived directly from verified code, not training data.
- Validation architecture: HIGH — mirrors existing test files inspected this session.

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stable in-repo code; re-verify line numbers if the cited files change before planning)
