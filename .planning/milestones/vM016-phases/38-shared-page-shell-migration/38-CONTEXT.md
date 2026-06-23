# Phase 38: Shared Page-Shell Migration - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

> **Discussion mode:** Advisor / `minimal_decisive` tier + repo shift-left policy. Requirements
> SHELL-01/SHELL-02 are locked and the vM016 directions are ratified in
> `.planning/vM016-UI-ITERATION-BRIEF.md`; this phase only refines HOW. All gray areas below were
> **auto-decided with rationale** (per `USER-PROFILE.md` decision-handling + `CLAUDE.md` decision
> policy) **except D-01 (deep-path breadcrumb behavior)**, which was surfaced for a cheap veto and
> the owner chose the broader option (editor **and** suggestion_review). A grounding correction to
> that choice is recorded in D-01 — intent honored, mechanism corrected to match the real codebase.

<domain>
## Phase Boundary

Migrate every operator-facing **index/list/detail** screen to render its inner frame through the
locked `cl_page` primitive (built in P37, D-08), replacing each screen's hand-rolled `<h1>` + width
chrome so the cockpit stops feeling like different apps — and wire `cl_breadcrumb` on the deep
KB-editor-from-conversation path so it is no longer defined-but-orphaned.

**In scope:**
- `home_live.ex`, `inbox_live.ex`, `audit_log_live.ex`, `settings_live.ex`, and all KB sub-screens
  (`knowledge_base_live/index.ex`, `editor.ex`, `gaps.ex`, `suggestion_review.ex`) — wrap each
  screen's body in `<.cl_page title="…">` **inside** the existing `<.cl_shell>`, moving the current
  `<h1>` text into the `title` attr and mapping bespoke chrome onto `cl_page` slots.
- Origin-aware `cl_breadcrumb` on the KB **editor** (already renders a static breadcrumb today) and a
  **new** breadcrumb on **suggestion_review** (which has none today) — see D-01.
- Keep `mix compile --warnings-as-errors` clean and `mix test` green (no regressions).

**Out of scope (own later phases):**
- `conversation_live.ex` shell migration — it is the `:reading` rail owned by **P41**; not in the
  SHELL-01 list. P38 touches conversation ONLY indirectly (it is the origin the editor breadcrumb
  points *back* to via the existing handoff `return_to`). Do not restyle/reframe conversation here.
- **Home redesign** (hero/secondary band/zero-state) — P39. P38 only puts Home *inside* `cl_page`
  with its current content; it does not redesign Home's body.
- **Audit-row → conversation linking** — P42 (Cross-Screen Threading). It does **not** exist today
  (audit_log_live has zero row links), so the *full* "Audit Log → conversation → editor" chain in
  SHELL-02's success-criterion phrasing is not fully clickable until P42. The path P38 *delivers and
  can test* is **conversation → KB editor**, with the breadcrumb deriving its back crumb from the
  verified `return_to`.
- hex→token drift remediation (P40), gate hardening (P40), rail disclosure (P41), responsive
  normalization (P43), motion (P44), seeds/screenshots (P45).

</domain>

<decisions>
## Implementation Decisions

### Breadcrumb / deep-path (SHELL-02)

- **D-01 — Origin-aware breadcrumb on BOTH the KB editor and suggestion_review (owner-chosen,
  grounded).** The owner vetoed the narrower "editor only" option in favor of consistency across the
  two KB detail screens. Grounding correction (the codebase does not flow origins identically):
  - **Editor (`editor.ex:263`):** already renders a *static* `<.cl_breadcrumb>` (`Knowledge /
    Editing: {title}`). It already carries a **verified** origin via `review_context.return_to`
    (`editor.ex:147`, decoded from a signed `handoff` token; `conversation_live.ex:180-206` is the
    producer when an operator opens the editor from a conversation). Make the trail **origin-aware**:
    when `return_to` is present, **prepend a back crumb to the origin** (≥2 crumbs + a working back
    link, satisfying success-criterion 2), e.g. `← {origin} / Knowledge / Editing: {title}`; when
    absent, fall back to today's static `Knowledge / Editing` trail.
  - **Suggestion review (`suggestion_review.ex:192`):** has **NO breadcrumb today** and is normally
    reached from the **review lane** via `task=`/`queue=` params — it is itself a *producer* of
    editor handoffs (`:145-168`), not a receiver of a conversation `return_to`. So "extend to
    suggestion_review" lands as: **add** a `cl_breadcrumb` it currently lacks, origin-derived from
    its review-lane context (e.g. `Knowledge / Suggestions / {task}` with a back link to the
    suggestions lane), using the **same prepend mechanism** if a verified `return_to` is ever passed.
    Do **not** invent a conversation→suggestion_review handoff (none exists; that would be scope
    creep toward P42).
  - **Shared mechanism:** prefer a small presenter/helper that builds the `items` list for
    `cl_breadcrumb` from `{origin return_to?, lane params, current title}` so both screens stay
    consistent and the orphaned primitive is genuinely exercised. The back link must be a real
    `navigate=` href (the last crumb stays current/no-href, per `cl_breadcrumb`'s contract).
  - **Research must verify:** (a) the `return_to` decoded from the handoff token is safe to render as
    a navigable crumb (it already is verified for navigation at `editor.ex:147`); (b) a human-readable
    label for the origin crumb (the raw `return_to` is a path — derive a label like "Conversation"
    rather than dumping the URL, honoring the "never raw terms to operators" copy rule).

### Page-shell migration (SHELL-01)

- **D-02 — Wrap inside `cl_shell`, not replace it.** `cl_page` is the **inner** frame (D-08); each
  screen keeps `<.cl_shell current={…} destinations={…}>` as the outer chrome and nests
  `<.cl_page title="…">` as the immediate child, with the existing body moving into
  `cl_page`'s `inner_block`. The current per-screen `<h1>` becomes the `title` attr (verbatim text):
  "Welcome back"→Home (note: P39 will replace this; P38 keeps current text), "Inbox", "Audit Log",
  "Settings", "Knowledge Base", "Editing: {title}", "Knowledge gaps", "Suggestion review".
- **D-03 — Width = `wide` for ALL migrated screens.** The `:reading` (≈352px rail) variant is for the
  conversation/detail rail and lands in **P41**; the KB editor's 2-column markdown/preview grid
  needs full width. Uniform `wide` directly satisfies success-criterion 1 (consistent inner content
  width). No screen in this phase uses `:reading`.
- **D-04 — Slot mapping (consistency rule).** Map existing bespoke chrome onto `cl_page` slots
  uniformly: `kb_nav` tabs (`<.kb_nav current={…}/>` on KB screens) → **`:subnav`**; a single primary
  page action/button → **`:actions`** (right-aligned in the header); **substantial filter bars stay
  in the body** (`inner_block`) — do not cram large filter UIs into `:actions`. Breadcrumb → the
  **`:breadcrumb`** slot (move the editor's existing `<.cl_breadcrumb>` call into that slot rather
  than leaving it free-floating above the header).
- **D-05 — Title text is carried verbatim from each current `<h1>`; no copy rewrites in P38.** Home's
  "Welcome back" stays as-is here; the Home hero/copy redesign is P39's job. This keeps the migration
  a pure structural lift with a clean, reviewable diff.

### Verification posture

- **D-06 — Screenshot-pipeline + render tests, headless where possible.** Success-criterion 1 is
  "visually verifiable against the screenshot pipeline" — the planner should plan for screenshot
  regen confirmation (full visual sweep is P45, but P38 should at least not break it). Add/adjust
  headless `render_component`/LiveView render assertions where they don't need Repo; mark any
  genuinely Repo-dependent assertion with `# REPO-UNAVAILABLE`. The breadcrumb back-link presence
  (≥2 crumbs + href) is assertable in a render test.

### Claude's Discretion
- Exact crumb labels and the origin-label derivation ("Conversation" vs "Review task" etc.), and
  whether the shared breadcrumb-items builder lives in a presenter vs an inline private helper.
- Per-screen slot details where a screen has no `kb_nav`/no primary action (those slots simply go
  unused).
- Plan/wave decomposition (e.g. one plan per screen vs grouped) — linear, low-risk; planner's call.
- Whether to add the `.cl-page` migration to `gaps.ex` as a 5th KB screen explicitly (it has an
  `<h1>Knowledge gaps</h1>` at `:68`) — include it for consistency; it's in the KB sub-screen set.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### vM016 iteration direction & requirements
- `.planning/vM016-UI-ITERATION-BRIEF.md` — ratified vM016 directions; the cockpit-consistency
  rationale behind the shell migration.
- `.planning/REQUIREMENTS.md` §SHELL-01, §SHELL-02 — locked requirements for this phase.
- `.planning/ROADMAP.md` §"Phase 38" — goal + the three success criteria.

### Locked component contracts (built in P37)
- `.planning/phases/37-component-primitives/37-CONTEXT.md` — D-08 (`cl_page` shell), D-09 (layout
  tokens `--cl-content-max`/`--cl-rail-width`/`--cl-page-gutter`); the `cl_page` API this phase
  *adopts*.
- `lib/cairnloop/web/components.ex:329` — `cl_page/1` def (attrs `title`/`subtitle`/`width`; slots
  `:actions`/`:breadcrumb`/`:subnav`/`inner_block`).
- `lib/cairnloop/web/components.ex:391` — `cl_breadcrumb/1` def (`items` = `[%{label, href}]`, last
  item current/no-href).
- `priv/static/cairnloop.css` — `.cl-page`, `.cl-page--wide`/`--reading`, `.cl-breadcrumb` classes.

### Screens to migrate (current header/shell patterns)
- `lib/cairnloop/web/home_live.ex:63-122` (`<h1>Welcome back</h1>`)
- `lib/cairnloop/web/inbox_live.ex:112-279` (`<h1>Inbox</h1>` + filter bar)
- `lib/cairnloop/web/audit_log_live.ex:87-165` (`<h1>Audit Log</h1>`)
- `lib/cairnloop/web/settings_live.ex:154-280` (`<h1>Settings</h1>`)
- `lib/cairnloop/web/knowledge_base_live/index.ex:51-109`, `editor.ex:260-342`,
  `gaps.ex:62-156`, `suggestion_review.ex:186-355` (KB sub-screens; `editor` already breadcrumbs)

### Deep-path origin plumbing (SHELL-02)
- `lib/cairnloop/web/conversation_live.ex:180-206` — editor handoff producer (`return_to` +
  signed `handoff` token → `/knowledge-base/{id}/edit?...`).
- `lib/cairnloop/web/knowledge_base_live/editor.ex:128-214` — `load_review_context/4`,
  `verified_return_to_from_token/1`; where the verified origin already lands.
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:145-168` — its own handoff producer
  (it hands off to the editor; it does **not** receive a conversation `return_to`).

### Brand / copy guardrails
- `prompts/cairnloop_brand_book.md` §7.5 (never state-by-color-alone) and copy register
  (humanize — no raw paths/terms to operators; the origin crumb label must be human-readable).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cl_page/1`, `cl_breadcrumb/1`, `cl_shell/1` (`components.ex`) — all built/locked in P37; this
  phase is pure adoption, no new primitives.
- `editor.ex` already imports and renders `cl_breadcrumb` — the wiring pattern is established; P38
  makes it origin-aware and replicates onto `suggestion_review`.
- `review_context.return_to` (verified, signed-token-derived) — the existing, safe origin signal
  for the editor's back crumb; no new token plumbing needed.

### Established Patterns
- Every screen is `<.cl_shell current={KEY} destinations={Cairnloop.Web.Nav.destinations()}>` then a
  hand-rolled `<h1>` + body. Migration is a uniform structural lift, screen-by-screen.
- `kb_nav` (`knowledge_base_live/nav_component.ex`) is a sub-navigation tab strip → maps to
  `cl_page`'s `:subnav` slot.
- Presenters (`audit_log_presenter.ex`, etc.) already centralize display logic — the breadcrumb-items
  builder should follow that pattern (presenter/helper, not inline LiveView logic).

### Integration Points
- New code connects only at the *render* layer (HEEx templates) of each LiveView + a small
  breadcrumb-items helper. No schema, governance-facade, or event-path changes — sealed phases stay
  untouched (`propose/3`, idempotency, co-commit unaffected).
- The brand-token gate (`test/cairnloop/web/brand_token_gate_test.exs`) must stay green: the
  migration must not introduce hardcoded hex (the `editor.ex` body has one inline grid `style=` at
  `:294` using tokens — moving it under `cl_page` should keep tokens; gate *hardening* against inline
  style is P40, but don't regress).

</code_context>

<specifics>
## Specific Ideas

- Owner explicitly wanted the deep-path breadcrumb consistency to span **both** KB detail screens
  (editor + suggestion_review), not just the editor — even though only the editor has the
  conversation-origin signal today. Honor the consistency intent; ground each screen to its real
  available origin (verified `return_to` for editor; review-lane params for suggestion_review).
- The cockpit-feels-like-different-apps problem is the *why* — the visible win is uniform header
  height + inner width across all five screens, checkable against the screenshot pipeline.

</specifics>

<deferred>
## Deferred Ideas

- **Audit-row → conversation linking** — the click target that would make SHELL-02's full
  "Audit Log → conversation → editor" chain end-to-end clickable. Belongs to **Phase 42**
  (Cross-Screen Threading). P38 delivers the breadcrumb on the conversation→editor hop only.
- **conversation_live `cl_page`/`:reading`-rail migration** — **Phase 41** (Conversation Rail
  Progressive Disclosure). Not migrated in P38.
- **Home body redesign** (hero, secondary band, health-as-chip, zero-state) — **Phase 39**. P38
  keeps Home's current "Welcome back" content, only re-framed by `cl_page`.

None of these were scope creep introduced in discussion — they are the natural adjacent phases the
roadmap already assigns.

</deferred>

---

*Phase: 38-shared-page-shell-migration*
*Context gathered: 2026-06-03*
