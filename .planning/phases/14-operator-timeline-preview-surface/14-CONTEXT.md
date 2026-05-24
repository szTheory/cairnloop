# Phase 14: Operator Timeline & Preview Surface - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Render durable governed-action proposals and their outcomes **inside the existing conversation
workflow** as a per-conversation timeline of human-readable preview cards. This is a **read /
display surface** over the durable `ToolProposal` + `ToolActionEvent` records created in Phase 13.

This phase covers **FLOW-01** (operator can inspect governed-action proposals and outcomes inside
the conversation workflow as a durable timeline) and **FLOW-02** (human-readable preview card per
risky action: risk label, actor scope, target, consequence summary, evidence links).

It does **not** build: reject/defer-with-reason actions (FLOW-03 → Phase 15), the approval state
machine + Oban resume (Phase 15), any real execution / results (Phase 16), or the MCP seam
(Phase 17). Nothing executes in Phase 14. The card is **read-only** — no approve/reject/defer
affordances — but its structure must leave room for Phase 15 affordances to drop in without
restructuring.

One small, correctly-placed data change is in scope: a `conversation_id` linkage on
`ToolProposal` (it does not exist yet) so the timeline can be conversation-scoped. See D-06..D-09.

The decisions below were produced by four parallel deep-research passes (idiomatic
Phoenix/LiveView/Ecto + cross-ecosystem lessons from GitHub Actions/Environments, Stripe
dashboard/idempotency, Terraform saved plans, AWS change sets, Argo CD, ServiceNow/ITIL,
event-sourcing read-models, audit-log UX) reconciled into one coherent set. Exact names, copy
wording, and markup are the planner's discretion unless flagged; the **shapes and trust
boundaries are locked**.

</domain>

<decisions>
## Implementation Decisions

### Placement, rendering mechanism & affordances (FLOW-01)

- **D-01:** Render proposals as a **dedicated "Governed actions" section in the right evidence
  rail** — a sibling to the existing `quick_fix_card/1` and `draft_audit_card/1`. **Not** inline in
  the message thread; **not** both. The center `.message-timeline` is *customer dialogue* (the
  `role`/`content` list); governed actions are *operator-grade evidence* and belong in the rail
  (brand §10.2: right panel = context / draft / sources / policy / actions). Each card carries its
  own `ToolActionEvent` mini-timeline, so we get activity-feed value **without** interleaving
  heterogeneous record types into the message list.
- **D-02:** Rendering mechanism = **plain-assign list-comprehension** (the current idiom for
  `messages`/`drafts`), fed by the existing PubSub → `reload_conversation_with_context` reload path.
  **Do NOT introduce `Phoenix.LiveView.stream/3`** here: this is a bounded, per-conversation, rarely-
  updated list (Phase 14 has no live status churn — approval/execution don't exist yet); streams
  would break the established thin-notification→full-reload PubSub pattern, add
  `phx-update="stream"`/DOM-id ceremony, and put items outside `socket.assigns`. Re-evaluate streams
  at **Phase 16** when real execution events start flowing (or if an org-wide governed-action feed
  ever appears) — document that as the trigger.
- **D-03:** New cards are **function components** (`governed_action_card/1` alongside the existing
  rail cards), **not LiveComponents** — they are stateless renders of immutable snapshot data; the
  parent LiveView owns all events.
- **D-04:** **Reframe the launcher, keep it, add the timeline.** Rename today's `tool_renderer`
  button text **"Execute" → "Propose"** (it already calls `Governance.propose/3` and flashes
  "Proposed — pending review" — "Execute" is now a lie; nothing executes until Phase 16, per P13
  D-05/D-27). Keep the launcher in the `context_pane` "Actions" section (the *initiate* surface);
  add the read-only timeline as a sibling rail section (the *observe* surface). Initiate-vs-observe
  stay distinct (GitHub "Run workflow" vs run history; Stripe "Send request" vs events log). While
  renaming, **replace the hardcoded `#2563eb` SaaS-blue** button color with a brand token (brand
  §2.2/§7 violation).
- **D-05:** The Phase 14 card is **READ-ONLY**. No approve / reject / defer buttons (those are
  Phase 15). Leave a **footer action slot** in the card structure so Phase 15 affordances drop in
  without restructuring. (Contrast: `draft_audit_card` *does* have action buttons — the
  governed-action card must not, yet.)

### Conversation scoping (data linkage — Phase 14 owns it)

- **D-06:** Phase 14 owns a migration adding a **nullable `conversation_id`** to
  `cairnloop_tool_proposals`:
  `add(:conversation_id, references(:cairnloop_conversations, on_delete: :nilify_all), null: true)`
  plus `belongs_to(:conversation)` on `ToolProposal`, `has_many(:tool_proposals)` on `Conversation`,
  and index `[conversation_id, inserted_at]` (exactly the rail's scoped-newest-first access
  pattern). This is the **literal `Draft`/`Conversation` precedent** already in this repo
  (`belongs_to(:conversation)` + `has_many` + ordered preload). **Nullable** because Phase 13 rows
  and any non-LiveView callers of `propose/3` have no conversation home; **`nilify_all`** because a
  governed-action audit record should *outlive* a deleted conversation (only its rail linkage is
  severed). **No data backfill** — pre-Phase-14 proposals have no conversation to attribute; the
  rail query naturally excludes NULL rows.
- **D-07:** Thread `conversation_id` into the propose context in
  `ConversationLive.handle_event("execute_tool", ...)` — symmetric to the existing `:tool_params`
  merge. `Governance.propose/3` writes it on **both** the valid (`insert_new_proposal`) and blocked
  (`insert_blocked_proposal`) paths, so **blocked proposals also appear in the rail** (the
  Support-Truth Gate the brand most wants visible).
- **D-08:** `conversation_id` **MUST be excluded from the idempotency-key canonical map**
  (`derive_idempotency_key/4`). It is routing/identity metadata, not action identity (P13 D-25);
  including it would silently change dedupe semantics and could resurrect duplicate proposals across
  re-renders.
- **D-09:** Add a **narrow facade read helper** `Governance.list_proposals_for_conversation/1`
  (`where conversation_id == ^id`, `order_by desc: inserted_at`, `preload events: asc inserted_at`).
  The LiveView **never** queries `ToolProposal` directly (P13 D-30 narrow paved road, consistent with
  `get_proposal/1`/`list_events/1`). Load it in `reload_conversation_with_context` alongside
  `quick_fix_card` → `assign(socket, governed_actions: ...)`.

### Operator state vocabulary & copy (FLOW-01)

- **D-10:** Operator-facing state grouping = **four stable groups: Awaiting / Blocked / Active /
  Done.** "Active" and "Done" are empty in Phase 14 but **declared now for stability** so Phase
  15/16 states slot in with **zero relabeling of today's four** (same posture as declaring
  `:destructive` early in P13 D-09). Resist proliferating groups (the ITIL footgun) — four is the
  ceiling for at-a-glance legibility.
- **D-11:** Status chip labels + group (keep distinct states distinct — never collapse into a
  generic "done"/"complete", P13 D-23 / P12 D-17; `:unsupported` never appears — telemetry-only,
  never persisted):
  - `:proposed` → **"Proposed"** (Awaiting) — passed every gate and recorded; nothing has run.
  - `:needs_input` → **"Needs input"** (Awaiting) — a required parameter is missing/invalid.
  - `:scope_invalid` → **"Not available here"** (Blocked) — tool can't run in this context / missing
    scope.
  - `:policy_denied` → **"Blocked by policy"** (Blocked) — policy refused; the recorded reason
    explains why.
- **D-12:** The `:proposed` + `:requires_approval` honesty case: label the chip **"Proposed"**, NOT
  "Pending approval" (no approver and no Approve button exist until Phase 15 — naming a non-existent
  action is the documented status-label footgun; mirrors Stripe `requires_action`/GitHub "Waiting"
  refusing to name a state before the action surface exists). Convey the gate via a **future-tense,
  non-actionable sub-line** driven by `approval_mode`, e.g. *"Will require approval before it can
  run."* When Phase 15 lands, status moves to `pending_approval` and the label legitimately becomes
  "Pending approval" with a real action — the copy was forward-compatible because it never claimed a
  flow that didn't exist.
- **D-13:** Keep **status, `risk_tier`, and `approval_mode` (and Phase 16 `result_state`) as
  separate display axes** — never fuse into one badge (risk ⊥ gate per P13 D-08; status ⊥ result per
  Argo CD Sync ⊥ Health). The status chip carries the lifecycle; risk_tier + approval_mode render as
  their own meta line.
- **D-14:** **Replace operator-facing `inspect(reason)`** (current `failure_reason_message/1`) with a
  `reason_label/1` mapping + humanize fallback (mirror `GapCandidatePresenter`). Raw Elixir terms
  must never reach an operator (brand §5.6).

### Preview fidelity — snapshot vs live (FLOW-02) — TRUST-SENSITIVE, see escalation note

- **D-15 (TRUST CALL — flagged for ratification):** **Hybrid.** Render the **durable trust fields
  strictly from the propose-time snapshot** — `risk_tier`, `approval_mode`, actor scope
  (`scope_snapshot`), input (`input_snapshot`), `policy_snapshot`, `status` — never re-read live (P13
  D-14/D-24). Render the **interpretive prose** — consequence text via the tool's `preview/1`
  callback, tool title/description from the registry `Spec` — **best-effort LIVE**, explicitly framed
  as a *"current description"* (not "what was decided"), behind a total fallback. Rationale: in
  Phase 14 the proposal is **inert** (nothing approved/executed), so prose drift is benign (a copy
  fix to `preview/1` simply shows better wording for an old candidate), the **governance claim never
  drifts** because the trust fields are pinned to the snapshot, and this avoids reopening the sealed
  Phase 13 `propose/3`/idempotency/co-commit path for zero Phase-14 benefit.
- **D-16:** **Promotion path (forward-compat, additive):** the moment a human *relies* on the prose
  — the Phase 15 approval surface and Phase 16 execution history — the consequence string + title
  **must be snapshotted** (add `rendered_consequence`/`title` columns, populate in `propose/3` going
  forward, have the approval/execution surfaces read the column). This is the strongest alternative
  (Option B) winning later; Hybrid is deliberately structured so the change is purely additive
  (Terraform saved-plan / Stripe store-and-replay / event-sourcing pin-on-decision pattern). **Do
  not** let live re-derivation become load-bearing on any approval/execution screen.
- **D-17:** **Structured-summary fallback is the COMMON path in Phase 14**, not an edge case — **no
  tool implements the optional `preview/1` callback yet**, so design it first-class (also required by
  the REQUIREMENTS Support-Truth Gate: "If action cannot render preview, fall back to a structured
  summary card"). When the live consequence leg misses (`preview/1` not exported, raises, returns a
  non-string, tool unresolved, or rehydration fails), render a human-readable card built **entirely
  from the snapshot**: allowlisted + humanized input rows (reuse `humanize_context_label`/
  `context_field`), risk/approval/scope meta, and a **title fallback chain** (live `Spec.title` →
  snapshotted title once Phase 15 adds it → humanized `tool_ref`; never raw
  `"Elixir.Cairnloop.Tools.X"`). **Never a raw map/JSON dump.**
- **D-18:** Encapsulate the live-vs-fallback choice behind **one total function** (e.g.
  `Cairnloop.Governance.Preview.render(proposal) :: {:preview, string} | {:structured, assigns}`, or a
  presenter helper) so the LiveView never branches on footgun internals and the logic is testable
  headless.
- **D-19:** **Rehydration footguns** when calling host `preview/1` from a stored snapshot (the live
  leg must be wrapped so these degrade one card, never the LiveView):
  - **JSONB round-trip turns atom keys → STRING keys.** `input_snapshot` is atom-keyed in memory at
    propose time (`apply_changes |> Map.from_struct`) but **string-keyed after insert + reload** —
    the central trap, invisible to tests that don't round-trip through Postgres.
  - Guard atom conversion with **`String.to_existing_atom/1` + rescue `ArgumentError`** (never
    `String.to_atom/1` — unbounded-atom DoS; consistent with P13 D-19).
  - `struct/2` **silently drops** unknown/renamed keys (silent-wrong is worse than a crash on a trust
    surface — validate).
  - The **tool module may be unregistered/removed** for a previously-valid proposal → fall back,
    don't crash the timeline.
  - Guard the call with `Code.ensure_loaded?/1` **then** `function_exported?(mod, :preview, 1)`.
  - Wrap the host `preview/1` call in `try/rescue` (host code can raise / loop / return non-string).
  - Prefer `struct(mod, atomized_snapshot)` over re-running `changeset/2` (re-running host changeset
    re-introduces live drift through the back door).

### Evidence / inspection links (FLOW-02)

- **D-20:** "Evidence" for a governed action means **provenance, not retrieval grounding**. A
  `ToolProposal` has no `evidence_snapshot` and that absence is **correct**. **Do NOT** reuse
  `SearchResultPresenter`'s "Supporting evidence" source-card list — fabricating retrieved sources on
  an operator/AI-initiated action is a lie. FLOW-02's "evidence links" resolve to durable
  Cairnloop-owned records.
- **D-21:** What each card surfaces (Phase-14 display scope):
  - **Headline (inline):** consequence preview + risk-tier + approval-mode/status chip — the card's
    reason to exist.
  - **Input snapshot (inline, humanized rows).**
  - **Action-event audit trail `list_events/1` (inline compact one-line timeline; full detail behind
    a `<details>` expander)** — who / what / when, + reason on blocks. This is "support that leaves a
    trail."
  - **Scope snapshot (inline);** on `:scope_invalid`, surface the **missing scopes** prominently.
  - **Policy snapshot → one calm "why this gate" sentence** (`resolution_source` + declared→resolved
    approval mode); raw map behind an expander. This is display only — **not** OBS-02 attribution.
  - **Source conversation:** co-located (the card lives in the thread) — essentially free.
  - **Trace metadata (de-emphasized, mono, copyable):** proposal id, `tool_ref`/`tool_version`, short
    idempotency key.
- **D-22:** **Inline = humanized, never raw JSON.** Raw maps only behind an explicit opt-in expander
  (Stripe Inspector pattern). `input_rows/1` is the **masking / minimization choke point** — iterate
  known fields, humanize values, elide/mask unknown/nested/sensitive values (PII guard); reuse
  `normalize_context_value/1`'s defensive "Unsupported value" posture. Never iterate arbitrary maps
  blindly into the DOM.
- **D-23:** **Telemetry is NEVER a UI source** (P13 D-29). The timeline reads `list_events/1`
  (durable Ecto truth) only; `Telemetry.emit` events (`:proposal_duplicate`, etc.) are observability,
  not displayed.
- **D-24:** Add a **`history_line/1` catch-all clause now** so Phase 15/16 event types render a
  generic "Workflow updated" instead of crashing the card (mirror `ReviewTaskPresenter.history_line/1`
  forward-compat). Guard event-association loading (`Ecto.assoc_loaded?`) and render a calm "No
  history yet" on an empty trail.

### Presenter shape (consolidates state + evidence display)

- **D-25:** Introduce a **`Cairnloop.Web.ToolProposalPresenter`** (a.k.a. GovernedProposalPresenter),
  mirroring `ReviewTaskPresenter`/`SearchResultPresenter` exactly: pure module, pattern-match on
  struct/atom, **total functions with safe fallbacks**, return strings/atoms (no markup), **never
  re-read live config** (snapshots are truth, P13 D-14). Recommended surface (names are planner
  discretion): `status_label`, `status_group` (+ `status_group_label`), `status_meaning`,
  `risk_tier_label` (+ `risk_tier_tone` → `:info|:warning|:danger`), `approval_mode_label`,
  `approval_outlook` (the honest future-tense gate sub-line — the **named Phase-14 honesty seam**
  Phase 15 repurposes), `reason_label` (replaces `inspect`), `input_rows` (masking choke point),
  `scope_summary`, `policy_explanation`, `block_reason_copy`, `history_line` (+ catch-all),
  `event_timestamp_label` (reuse the recency idiom), `trace_metadata`. **Tone helpers return atoms;**
  the LiveView maps them to brand state colors and **always pairs color with text/chip** (never
  color-alone — brand §7.5 / accessibility).

### Architecture & posture

- **D-26:** Keep the lane **Cairnloop-owned**: durable Ecto records are workflow truth, `:telemetry`
  is observability only (P13 D-29); new reads go through the **narrow `Cairnloop.Governance` facade**
  (P13 D-30). Calm, fail-closed, **honest** copy — no fake success-green for inert `:proposed`, no
  implied autonomy/execution (brand voice).
- **D-27:** **Shift ordinary implementation choices left** to planning/execution (exact
  module/function/CSS names, card markup, expander mechanics, ordering tie-breaks, empty-state copy,
  footer-slot placement). Re-escalate only decisions that materially affect trust semantics, the
  no-execution boundary, or scope (P13 D-31). The one trust-sensitive call here is **D-15**
  (preview snapshot-vs-live) — flagged below.

### Claude's Discretion

- Exact names (`ToolProposalPresenter` vs `GovernedProposalPresenter`; the `Preview.render` module;
  individual helper function names), exact label/copy wording within the calm brand voice, exact card
  markup and CSS (using brand tokens), the expander mechanism (`<details>` vs LiveView toggle),
  newest-first ordering tie-breaks, empty-state copy, and where the Phase-15 footer action slot sits
  — all planner/executor discretion **as long as the shapes and trust boundaries in D-01..D-26
  hold**.

### ⚠ Escalation note (one decision flagged back to the user)

Per the user's standing preference, only the single genuinely trust-sensitive call is surfaced:
**D-15 (Hybrid preview: trust fields from snapshot, prose live-best-effort)**. It is recommended
and justified (Phase 14 is inert; reopening Phase 13's sealed propose path buys nothing now; the
Phase 15 promotion to a snapshotted consequence string is additive — D-16). The alternative is to
snapshot the consequence/title **now** by reopening `propose/3` + a migration. Recorded as decided
(Hybrid); the user may veto in favor of snapshot-now before planning.

#### ✅ RATIFIED — Hybrid (Option A), 2026-05-24 (plan-phase)

D-15 is **ratified as Hybrid**. The user delegated the call ("decide for me; only escalate VERY
impactful ones") and it was resolved by three parallel deep-research passes — Elixir/Phoenix/Ecto
idioms, cross-ecosystem review-then-act systems, and project-vision coherence — which **converged
unanimously on Hybrid**. Key findings, recorded so this is not re-litigated:

- **"Review must match apply" is an execution-boundary property, not a proposal-creation one.**
  Terraform (`plan -out` → "stale plan" only at *apply*), CloudFormation change sets (OBSOLETE only
  at execute), Atlantis, GitHub Actions (commit pinned at queue; gate holds execution), Argo CD
  (Sync ⊥ Health, diff recomputed live) all pin **structured facts** at decision time and **derive
  prose at display time**. None pre-snapshot prose before a human relies on it. Stripe deliberately
  moved *away* from snapshot-events (they go stale vs schema evolution) toward thin events + live
  fetch. Phase 14 has no apply/approve boundary, so the invariant does not bite.
- **Idiomatic Elixir:** pure presenter + total `Preview.render/1 :: {:preview, str} | {:structured,
  assigns}` is exactly the in-repo `ReviewTaskPresenter` idiom; the JSONB string-key footgun is
  already managed by the `to_result/1` precedent (`conversation_live.ex` L747-753). An `embeds_one`
  typed snapshot would kill the footgun class but is **not worth it** (heterogeneous per-tool input
  shapes; would force reopening Phase 13's schema).
- **Coherence:** D-14/D-24 sealed *trust config* (risk/approval/policy); prose is a different
  category and P13 D-06 made `preview/1` **explicitly optional**, deliberately excluded from the
  snapshot. REQUIREMENTS Support-Truth Gate ("fall back to a structured summary card") linguistically
  presupposes a live leg that can fail — i.e. it was written *for* Hybrid. Option B's failure mode
  (permanently pinning possibly-wrong Day-0 prose, no update path, migration cost per fix) is **worse**
  than Hybrid's (cosmetic display drift while inert).

**Forward-compat guardrail (MUST carry to Phase 15 — the one real risk all three agents flagged):**
the danger is a Phase 15 author reusing the live `Preview.render` leg on the approval screen instead
of D-16's additive snapshot. Phase 15 MUST: (1) add nullable `rendered_consequence` + `title` columns
to `cairnloop_tool_proposals`; (2) populate them in `propose/3` from Phase 15 forward; (3) have the
approval/execution surfaces read the **snapshotted columns**, never call live `Preview.render`; (4) add
a test asserting the approval card shows the snapshotted consequence when it diverges from the live
registry description. Phase 14 should leave a discoverable marker (e.g. a `@moduledoc` note on the
`Preview` module + a `must_haves` truth) so this constraint survives context resets.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary & active requirements
- `.planning/ROADMAP.md` — Phase 14 goal + plans M011-S02-01/02/03; Phases 15-17 (what Phase 14 must
  stay forward-compatible with: approval lifecycle, execution, MCP).
- `.planning/REQUIREMENTS.md` — **FLOW-01, FLOW-02** (the two requirements this phase delivers);
  FLOW-03/APRV-* (Phase 15, must NOT be built); Proof Posture Gate ("Tests for preview rendering and
  action metadata exposure"; "durable blocked/pending/error states instead of optimistic UI");
  Support-Truth Gate ("If action cannot render preview, fall back to structured summary card").
- `.planning/PROJECT.md` — vM011 posture: extend the M009/M010 trust model; host-owned
  governed-action lane; durable records as truth; calm operator-grade surfaces.
- `.planning/STATE.md` — carried decisions (workflow truth in Phoenix/Ecto/Oban; durable records over
  telemetry); environment caveat (`Cairnloop.Repo` may be unavailable in this workspace —
  preview/rehydration tests must tolerate that, and the JSONB string-key footgun (D-19) won't surface
  without a real DB round-trip).

### Prior-phase decisions that constrain Phase 14
- `.planning/phases/13-governed-tool-contract-proposal-records/13-CONTEXT.md` — **the direct
  upstream.** D-14/D-24 (snapshot at propose time; never re-read live config at render time — the
  crux of D-15); D-27 (no inline execution; proposal id returned as the Phase-14 card seam; calm
  flash → real card); D-08 (orthogonal risk ⊥ approval → D-13); D-23 (keep states distinct, never a
  generic "done"); D-18 (`:unsupported` is telemetry-only, never persisted → never a card); D-29
  (durable records are truth, telemetry observability only → D-23); D-30 (narrow facade → D-09);
  D-25 (idempotency-key derivation → D-08 exclusion).
- `.planning/phases/12-in-thread-quick-fix-ops-closure/12-CONTEXT.md` — D-08 (no opaque
  trust-mixing blob → conversation_id is its own column, D-06/D-08), D-17 (don't collapse distinct
  states → D-10/D-11).

### Existing code seams (read before implementing)
- `lib/cairnloop/web/conversation_live.ex` — THE LiveView. `handle_event("execute_tool", ...)`
  (~L173, thread `conversation_id`, D-07); `context_pane/1` "Actions" + `tool_renderer/1` (~L415/503,
  rename Execute→Propose + brand-token color, D-04); `quick_fix_card/1` (~L457) and
  `draft_audit_card/1` (~L582) — the rail-card idiom to clone for `governed_action_card/1`;
  `context_section/1`/`context_field/1`/`humanize_context_label/1`/`normalize_context_value/1`
  (~L552-691) — the **humanize-don't-dump** rendering helpers (D-17/D-22);
  `reload_conversation_with_context/2` (~L200, where to load `governed_actions`, D-09);
  `failure_reason_message/1` (~L188, replace `inspect`, D-14); the message-timeline list-comprehension
  (~L381) and drafts loop (~L402) — the plain-assign render pattern (D-02).
- `lib/cairnloop/governance.ex` — facade: `propose/3` (`insert_new_proposal`/`insert_blocked_proposal`
  write `conversation_id`, D-07; `derive_idempotency_key/4` excludes it, D-08), `get_proposal/1`,
  `list_events/1`; add `list_proposals_for_conversation/1` (D-09).
- `lib/cairnloop/governance/tool_proposal.ex` — schema to extend: add `conversation_id` +
  `belongs_to(:conversation)` (D-06); snapshot maps (`input_snapshot`/`scope_snapshot`/
  `policy_snapshot`), `risk_tier`/`approval_mode`/`status` enums (the render sources, D-15/D-21).
- `lib/cairnloop/governance/tool_action_event.ex` — append-only audit log the per-card timeline
  renders from (`event_type`/`from_status`/`to_status`/`actor_id`/`reason`/`metadata`/`inserted_at`,
  D-21/D-24).
- `lib/cairnloop/governance/policy.ex` — current `policy_snapshot` shape for the "why this gate"
  sentence (D-21).
- `lib/cairnloop/tool.ex` — `Cairnloop.Tool` behaviour: optional `preview/1` (no default — D-17),
  `__tool_spec__/0` → `%Spec{title, description, risk_tier, approval_mode}` (live title source, D-15).
- `lib/cairnloop/tool_registry.ex` — `find_tool_module/1` (`{:error, :unknown_tool}` for
  unregistered tools → rehydration fallback, D-19).
- `lib/cairnloop/web/review_task_presenter.ex` — **the presenter to mirror** for
  `ToolProposalPresenter` (`thread_status_label/1`, `status_label/1`, `history_line/1` + catch-all),
  D-25/D-24.
- `lib/cairnloop/web/search_result_presenter.ex` — recency/label idiom (`recency_label`,
  `relative_time`) to reuse for `event_timestamp_label` (D-25). (Do NOT reuse its source-card list as
  governed-action "evidence" — D-20.)
- `lib/cairnloop/web/gap_candidate_presenter.ex` — `@reason_labels` map + humanize fallback pattern
  for `reason_label/1` (D-14).
- `lib/cairnloop/web/search_modal_component.ex` — brand badge/chip inline-style idiom
  (`source_badge_style`/`trust_badge_style`) for status/risk chips (D-13/D-25).
- `lib/cairnloop/automation/draft.ex` + `lib/cairnloop/conversation.ex` + `lib/cairnloop/chat.ex` —
  the in-repo `belongs_to(:conversation)` + `validate_required` + `has_many` + ordered-preload
  precedent the `conversation_id` change clones (D-06).
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` (and the Phase 13 governance
  migration) — migration style (enum, index) for the `conversation_id` migration (D-06).

### Product & brand posture
- `prompts/cairnloop_brand_book.md` — §10.2 (rail layout → D-01), §13.1 (automation level 4 = "Tool
  proposal" → "Propose" label, D-04), §5.3/§5.6 (name the state; reason-forward error copy; no raw
  terms → D-12/D-14), §7.5 (never state-by-color-alone → D-13/D-25), §13.2 ("Blocked by policy",
  "Approval required" register → D-11/D-12). Calm, "show your sources," "support that leaves a trail."
- `docs/cairnloop-jtbd-and-user-flows.md` — embedded support-cockpit, in-thread workflow this surface
  plugs into.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned Phoenix architecture,
  evidence-vs-telemetry separation.
- `prompts/scoria overview for integration ideas.txt` / `prompts/parapet overview for integration
  ideas.txt` — evidence-vs-telemetry framing; optional evidence lane is **Phase 17** (Phase 14 must
  not depend on it — D-20 deferral).

### External references surfaced during research (orientation, not requirements)
- GitHub Actions/Environments deployment review; Stripe dashboard events log + idempotency
  store-and-replay; Terraform saved plan (`plan -out`, "stale plan" error); AWS CloudFormation change
  sets — "review-then-apply must match what was reviewed" + initiate-vs-observe separation (D-04/D-16).
- Argo CD Sync ⊥ Health two-axis status model — keep status/result/approval as separate axes (D-13).
- ServiceNow/ITIL change states — keep terminal states distinct, resist group proliferation (D-10).
- Event-sourcing read-models / immutable audit-log UX — render history as decided; humanize over raw
  JSON; mask PII before display (D-15/D-22).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `quick_fix_card/1` + `draft_audit_card/1` (`conversation_live.ex`) — rail-card idiom to clone for
  `governed_action_card/1` (eyebrow + status + summary + meta + reason + per-card sub-timeline).
- `context_section/1` / `context_field/1` / `humanize_context_label/1` / `normalize_context_value/1`
  — humanize-don't-dump renderers for input/scope/policy snapshots (D-17/D-22).
- `ReviewTaskPresenter` (incl. `history_line/1` + catch-all) — the exact presenter idiom + forward-
  compat fallback to mirror in `ToolProposalPresenter`.
- `SearchResultPresenter.recency_label/relative_time` — relative-time helper for event timestamps.
- `GapCandidatePresenter` `@reason_labels` + humanize fallback — pattern for `reason_label/1`.
- `Governance` read helpers (`get_proposal/1`, `list_events/1`) — the facade to extend with
  `list_proposals_for_conversation/1`.
- `Draft`/`Conversation` `belongs_to`/`has_many`/ordered-preload — the conversation-linkage precedent.

### Established Patterns
- Plain-assign list-comprehension rendering + thin-notification PubSub → full
  `reload_conversation_with_context` (no streams; no optimistic UI).
- Function components in the LiveView for stateless cards (LiveComponents only for self-stateful
  children).
- Presenter modules (pure, total, struct/atom pattern-match, return strings/atoms) for all
  display-label logic; LiveView maps tone atoms → brand colors, always color + text.
- Snapshot-at-propose-time as the render source of trust facts; telemetry strictly observability.
- Append-only event table + denormalized status column (mirrored by `ToolProposal`/`ToolActionEvent`).
- Calm, fail-closed, reason-forward operator copy with explicit blocked reasons.

### Integration Points
- `cairnloop_tool_proposals.conversation_id` (new, nullable, FK `nilify_all`, indexed
  `[conversation_id, inserted_at]`) + `belongs_to`/`has_many` (D-06).
- `ConversationLive.handle_event("execute_tool")` threads `conversation_id` into the propose context;
  `Governance.propose/3` persists it on valid + blocked paths (D-07); excluded from idempotency key
  (D-08).
- `Governance.list_proposals_for_conversation/1` → `reload_conversation_with_context` →
  `assign(governed_actions:)` → `governed_action_card/1` in a new rail section (D-09/D-01).
- `Cairnloop.Web.ToolProposalPresenter` + a total `Preview.render(proposal)` helper consumed only by
  the card (D-18/D-25).
- `tool_renderer/1` button: "Execute" → "Propose", brand-token color (D-04).

</code_context>

<specifics>
## Specific Ideas

- "Initiate vs observe" split modeled on GitHub ("Run workflow" button separate from run history) and
  Stripe ("Send request" separate from the events log) — launcher in Actions, timeline as a sibling.
- "Render history exactly as it was decided" (immutable audit / event-sourcing) is why trust fields
  are snapshot-pinned; the **one** deliberate exception is inert Phase-14 prose, honestly labelled
  "current description" (D-15).
- The structured-summary fallback should be **more** trustworthy than the thing it replaces (built
  purely from the snapshot), not a degraded "no preview available" message — and it is the *common*
  path because no tool implements `preview/1` yet (D-17).
- `approval_outlook/1` is the named honesty seam: future-tense gate copy now, repurposed to real
  "Pending approval" status when Phase 15 ships (D-12/D-25).
- Card leaves a footer action slot so Phase 15 approve/reject/defer affordances drop in without
  restructuring (D-05).

</specifics>

<deferred>
## Deferred Ideas

- **Reject / defer a proposal with a persisted reason (FLOW-03)** — Phase 15 (the read-only card +
  footer action slot are the seam).
- **Approval state machine, `pending_approval`/`approved`/`rejected`/`deferred`/`expired`, Oban
  resume + re-validation, "Pending approval" label + Approve action** — Phase 15 (the
  Awaiting/Blocked/Active/Done groups + `approval_outlook/1` are forward-compatible).
- **Snapshotting the rendered consequence string + title at propose time** — Phase 15/16, additive
  (D-16), when a human first relies on the prose.
- **Execution + results rendering (`result_state`/`result_summary`/`attempt`/`oban_job_id`),
  bounded execution telemetry alignment** — Phase 16.
- **`Phoenix.LiveView.stream/3` for the timeline** — re-evaluate at Phase 16 when real execution
  events flow or an org-wide governed-action feed appears (D-02).
- **OBS-02 audit/evidence attribution** (full policy-version lineage, which-rule-fired, attributable
  evidence chains) — Phase 16/17; Phase 14 shows only the existing `policy_snapshot` as a plain
  sentence (D-21).
- **Optional Scoria / OpenInference evidence-hook fetching + read-only MCP seam** — Phase 17 (Phase
  14 depends only on Cairnloop-owned Ecto records, D-20).
- **Standalone / cross-conversation governed-action audit-log page** (Stripe Activity / GitHub org
  audit-log style) — out of scope; Phase 14 renders one conversation's cards in-thread.

</deferred>

---

*Phase: 14-operator-timeline-preview-surface*
*Context gathered: 2026-05-24*
</content>
</invoke>
