# Phase 42: Cross-Screen Threading - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire navigational threads between the cockpit's currently-isolated leaf screens so the
operator can follow a piece of work across surfaces instead of dead-ending. Four threads
(THREAD-01..03):

1. **Next-in-queue** — from a *resolved* conversation, advance to the next open conversation
   without bouncing through the inbox.
2. **Audit-row → subject** — every Audit Log row links to its subject (conversation and/or the
   governed action), so the audit log stops being a dead end.
3. **Governed-action → audit** — a governed-action card in the conversation rail links to its
   corresponding audit-log entries.
4. **Article → originating conversation** — a KB article detail view links back to the
   conversation where the gap was first surfaced (bi-directional causal threading).

**This phase adds links/affordances and the facade reads that back them. It does NOT add new
workflow capabilities.** In particular: no new "mark resolved/handled" action, no audit-table
schema migration, no new ordering/queue field, no new signed-token return-path machinery.

**Not in scope (own phases):** responsive normalization (P43), motion (P44), seed/screenshots
(P45). New capabilities (saved searches, queue prioritization, multi-select threading) are
deferred.

</domain>

<decisions>
## Implementation Decisions

> Per project decision policy (shift-left) + `opinionated`/`minimal_decisive` profile: gray
> areas were researched against the codebase and **decided**, not bounced back. None cleared
> the VERY-impactful escalation bar (no migration, additive facade reads are the *ratified*
> architecture, queue order is a reversible sort key). The two notable product calls are
> flagged **[veto-cheap]** so the owner can override before planning.

### A — Data linkage strategy (no schema migration)
- **D-01: Resolve audit-row→conversation via the existing FK chain at read time — do NOT add
  `conversation_id` to `ToolActionEvent`.** The chain `ToolActionEvent → tool_proposal →
  conversation` is stable (`tool_action_event.ex` `belongs_to(:tool_proposal)`;
  `tool_proposal.ex:55` `belongs_to(:conversation)`). A navigation FK is not a trust fact
  subject to drift, so a facade read/join is correct and avoids churning the append-only audit
  table (which is explicitly insert-only: `updated_at: false`, no update/delete API). This
  respects "seal completed phases / additive over invasive."
- **D-02: Snapshot-at-decision invariant is not violated by D-01.** That invariant governs
  *trust facts* (risk tier, policy outcome, confidence). The conversation a proposal belongs to
  is an immutable structural FK, not a re-read of live config, so resolving it at render time
  for a *link target* is fine. (Interpretive-display carve-out, P14 D-15 family.)

### B — Facade ownership of the new reads (criterion-4 reconciliation)
- **D-03: Honor the *spirit* of success-criterion-4 ("no direct `Cairnloop.Repo` queries in
  LiveViews — reads route through a facade"), with domain-correct facade ownership:**
  - Governed-action / audit reads → **`Cairnloop.Governance`** (extend `list_action_events/1`
    to carry subject refs; reuse `list_events/1`, `get_proposal/1`).
  - Conversation/queue reads (next-in-queue) → **`Cairnloop.Chat`** (its existing facade owns
    conversation listing; add `next_open_conversation/1`).
  - Article→conversation resolution → the KB/knowledge-automation read path (entrypoint lives
    on `ArticleSuggestion`), surfaced through a facade fn, not raw `Repo` in the LiveView.
  The criterion literally names `Governance`; the intent is "facade, not raw `Repo`." Recorded
  so the verifier reads criterion-4 against intent, not the literal module name.

### C — Next-in-queue semantics (THREAD-01)
- **D-04 [veto-cheap]: "Next" mirrors the inbox's *existing* canonical order — do NOT invent a
  new ordering.** Inbox/Chat already orders `desc: :updated_at`, status-scoped (`chat.ex:12,22`).
  Next-in-queue = the first **open** conversation in that same order, excluding the current id.
  This guarantees "next" never diverges from the list the operator already sees, and needs no
  new column. (Alternative FIFO-oldest-first was rejected: it would contradict the visible
  inbox order and surprise the operator.)
- **D-05: The affordance attaches to the existing `status == :resolved` state — no new "mark
  handled" action.** `conversation_live.ex` has no manual resolve event; conversations reach
  `:resolved` elsewhere, and the resolved state already gates the recovery-follow-up block
  (`:225`, `:533`). The "Next in queue" affordance renders in that resolved-state region,
  keyed off `@conversation.status == :resolved`. Adding a resolve button is out of scope.
- **D-06: End-of-queue is honest and calm.** When `next_open_conversation/1` returns `nil`,
  render a calm "Queue clear — no more open conversations" state linking to `/inbox` (which
  shows its own empty state). Never render a dead/disabled "Next" or navigate to a stale id.
- **D-07: `next_open_conversation/1` is a cheap scoped read.** Follow the P39 D-09 pattern
  (scoped query, no full-list `Enum`); return the next open conversation id (or `nil`) — do not
  load the full conversation. Deterministic tiebreak by `id` when `updated_at` ties.

### D — Audit-row link target (THREAD-02)
- **D-08: Each audit row links to its subject conversation; when the row's governed action is
  on the current path, also expose the governed-action context.** Success-criterion-2 says
  "conversation *or* governed action." Primary link = conversation (the human-meaningful
  subject). Rows whose proposal has no conversation (should be rare) degrade gracefully to a
  non-linked row rather than a broken link (fail-closed honesty).
- **D-09: Extend the audit read, not the schema — `load_events/0` in `AuditLogLive` consumes a
  facade result that carries `conversation_id` (+ proposal id) per event** via the D-01 join.
  Keep the existing `events`/`visible_events` assign shape; enrich each row presenter with the
  resolved subject ref.

### E — Governed-action → audit deep-link (THREAD-03)
- **D-10 [veto-cheap]: Link to the audit log *filtered to that governed action*, via a
  `?proposal=<id>` query param — not to a single opaque event row.** A proposal emits multiple
  append-only events (proposed/approved/executed); the meaningful target is "this action's audit
  trail," not one event. `AuditLogLive.handle_params/2` reads `proposal` and applies it as a
  filter through the facade (`Governance.list_events/1` or `list_action_events(proposal_id:)`).
  No schema change; deep-linkable/shareable URL.
- **D-11: No new signed-token return path for this link.** The KB editor's signed `return_to`
  token (`editor_handoff.ex`) is specific to the editor handoff. Audit↔conversation↔card links
  use plain declarative nav; orientation comes from the existing breadcrumb shell (P38) and the
  existing "← Back to Inbox" affordance. Keep it simple — don't generalize the token machinery.

### F — Article → originating-conversation (THREAD-03)
- **D-12: Resolve the originating conversation from the article's suggestion entrypoint;
  render the back-link ONLY when one exists.** `ArticleSuggestion` carries `entrypoint_type` +
  `entrypoint_id`; when `entrypoint_type == :conversation_quick_fix`, `entrypoint_id` is the
  conversation id. For `:gap_candidate` / `:article_revision` there is no originating
  conversation → **omit the link entirely** (no dead/placeholder link — honest absence).
- **D-13: Surface the link in the KB article detail / editor header (breadcrumb or header
  link), reusing the existing `cl_breadcrumb` + `BreadcrumbPresenter` infrastructure** rather
  than inventing a new affordance. (`components.ex:395`, `breadcrumb_presenter.ex`.)

### G — Navigation mechanism (all four threads)
- **D-14: Use declarative `<.link navigate={…}>` for all threading links** (matches the
  existing inbox-row link `inbox_live.ex:215` and back-to-inbox `conversation_live.ex:438`).
  Reserve `push_navigate` for links that must be triggered from a server `handle_event`. No
  `push_patch` — these are cross-LiveView transitions, not same-view param tweaks.

### Claude's Discretion
- Exact facade function names/signatures (`next_open_conversation/1` arg shape;
  whether audit subject refs ride on the existing struct vs a thin presenter map).
- The exact query-param name for the audit deep-link (`proposal` vs `proposal_id`) and whether
  to also accept a `trace`/idempotency-key form.
- Copy for the "Next in queue" affordance and the end-of-queue "Queue clear" state (calm,
  reason-forward, brand §7.5 — text + tone, never color alone).
- Whether the audit row links the whole row vs an explicit "View conversation" link element
  (a11y: ensure the link has an accessible name, not row-as-link ambiguity).
- Placement of the governed-action→audit link within the card (likely the Tier-3 "Identifiers
  & trace" group added in P41 D-02, since it is trace-level navigation).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements & roadmap
- `.planning/ROADMAP.md` §"Phase 42: Cross-Screen Threading" — goal + 4 success criteria
  (next-in-queue affordance after resolve; audit rows link to subject; gov-action→audit +
  article→conversation links; `mix test` green with no direct `Repo` reads in LiveViews).
- `.planning/REQUIREMENTS.md` — THREAD-01 (next-in-queue), THREAD-02 (audit rows link to
  subject), THREAD-03 (gov-action→audit + article→conversation bi-directional threading).
- `.planning/PROJECT.md` "## Architectural Invariants" — Governance-facade reads from web layer;
  snapshot-at-decision; seal-completed-phases / additive posture.

### Facade (the read seam — extend, don't bypass)
- `lib/cairnloop/governance.ex` — public read facade. Reuse/extend: `list_action_events/1`
  (`:998`), `list_events/1` (`:978`, per-proposal events), `get_proposal/1` (`:579`),
  `list_proposals_for_conversation/2` (`:1018`).
- `lib/cairnloop/chat.ex` — `list_conversations/0,1` (`:10,:20`), `scope_status/2` (`:41`),
  ordering `desc: :updated_at`. Add `next_open_conversation/1` here (conversation domain).

### Schemas (FK chain — confirm, do not migrate)
- `lib/cairnloop/governance/tool_action_event.ex` — append-only audit event;
  `belongs_to(:tool_proposal)`; `updated_at: false` (insert-only invariant — DO NOT add columns).
- `lib/cairnloop/governance/tool_proposal.ex:55` — `belongs_to(:conversation)` (the hop to
  resolve audit-row→conversation).
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` (~`:29-31`) — `entrypoint_type` +
  `entrypoint_id` (originating-conversation resolution; `:conversation_quick_fix` → conv id).

### LiveViews & router (link sites)
- `lib/cairnloop/router.ex:119-134` — routes: conversation `/:id` (`:cairnloop_conversation`),
  audit `/audit-log` (`:cairnloop_audit_log`), inbox `/inbox`, KB editor `/knowledge-base/:id/edit`.
- `lib/cairnloop/web/audit_log_live.ex` — `mount/3` (`:22`), `load_events/0` (`:40-49`),
  `visible_events` assign (`:65`); add `handle_params/2` proposal filter (D-10) + per-row
  subject link (D-08/D-09).
- `lib/cairnloop/web/conversation_live.ex` — resolved-state region (`:533`, recovery follow-up
  gate `:225`) for the Next-in-queue affordance (D-05); governed-action card
  (`:957-1112`, trace group per P41 D-02) for the audit deep-link (D-10).
- `lib/cairnloop/web/inbox_live.ex:215` — canonical row→conversation link pattern to mirror.
- `lib/cairnloop/web/knowledge_base_live/editor.ex:195-196` — breadcrumb slot for the
  article→conversation link (D-13).

### Components & orientation layer (P38)
- `lib/cairnloop/web/components.ex:395-405` — `cl_breadcrumb/1`.
- `lib/cairnloop/web/breadcrumb_presenter.ex` — `editor_items/2` (path-shape origin derivation).
- `.planning/phases/41-conversation-rail-progressive-disclosure-d2/41-CONTEXT.md` D-02 —
  the Tier-3 "Identifiers & trace" group where the gov-action→audit link likely belongs.

### Brand
- `prompts/cairnloop_brand_book.md` §7.5 — never state-by-color-alone; calm, reason-forward
  operator copy; mono only for ids/traces.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Cairnloop.Governance` facade** already exposes the audit/proposal reads needed — threading
  reads extend this seam (no raw `Repo` in LiveViews).
- **`Cairnloop.Chat.list_conversations/1` + `scope_status/2`** — the `status: :open` scoped,
  `updated_at desc`-ordered read that `next_open_conversation/1` builds on (P39 D-09 cheap-read
  pattern: scoped query, no full-list `Enum`).
- **`cl_breadcrumb/1` + `BreadcrumbPresenter`** (P38) — orientation layer for deep links; reuse
  for article→conversation, don't build new return-path UI.
- **`<.link navigate=>` row pattern** (`inbox_live.ex:215`) and **"← Back to Inbox"**
  (`conversation_live.ex:438`) — the established nav idiom to mirror.

### Established Patterns
- All cross-LiveView nav is client-side `navigate=` / `push_navigate` — no `patch` between these
  screens. Threading links follow suit (D-14).
- Audit table is append-only (insert-only invariant) — threading must read it, never extend its
  schema (D-01).
- Fail-closed display: missing/absent links degrade to honest absence, never dead links
  (D-06, D-08, D-12).

### Integration Points
- `AuditLogLive`: add `handle_params/2` proposal filter (D-10) + per-row subject resolution from
  the enriched facade read (D-09); keep `events`/`visible_events` assign shape.
- `ConversationLive`: resolved-state region gains the Next-in-queue affordance (D-05); the
  governed-action card's trace group gains the audit deep-link (D-10).
- KB editor: breadcrumb/header gains the conditional originating-conversation link (D-12/D-13).

</code_context>

<specifics>
## Specific Ideas

- "Next" must equal the next item in the inbox's *visible* order (`updated_at desc`, open) — the
  operator should never feel "next" disagrees with the list they just left (D-04).
- The governed-action→audit link should land on that action's *trail* (filtered audit view),
  reflecting that one proposal emits many append-only events (D-10).
- Article→conversation link appears only for conversation-originated articles; gap/revision
  articles legitimately have no originating conversation and show no link (D-12).

</specifics>

<deferred>
## Deferred Ideas

- **Manual "mark resolved/handled" action** in the conversation view — the Next-in-queue
  affordance keys off the *existing* resolved state; adding a resolve control is a separate
  capability (not in THREAD scope).
- **Queue prioritization / risk-weighted ordering** — D-04 mirrors the existing `updated_at`
  order; any smarter queue ordering is its own product decision/phase.
- **Persisted/shareable "return to where I came from" stacks** beyond the existing breadcrumb
  shell — generalizing the KB editor's signed `return_to` token to all threads is deferred
  (D-11 keeps links plain).
- **Adding `conversation_id` (or denormalized subject) to `ToolActionEvent`** — explicitly
  rejected for this phase (D-01). Revisit only if a future phase needs audit reads independent
  of the proposal join at scale.

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 42-cross-screen-threading*
*Context gathered: 2026-06-04*
