# Phase 38: Shared Page-Shell Migration - Research

**Researched:** 2026-06-03
**Domain:** Phoenix LiveView HEEx render-layer migration (component adoption + breadcrumb origin plumbing)
**Confidence:** HIGH (all claims verified against live code; no external dependencies)

## Summary

This is a **pure-adoption, render-layer-only** phase. The three primitives it consumes —
`cl_page/1`, `cl_breadcrumb/1`, `cl_shell/1` — already exist, are locked (P37), and are verified at
`lib/cairnloop/web/components.ex:329`, `:391`, `:358` respectively, with their CSS present in
`priv/static/cairnloop.css` (`.cl-page` :686, `.cl-page--wide` :689, `.cl-breadcrumb` :459). No new
primitives, no schema/governance/event-path changes. Every change lands inside a LiveView's
`render/1` HEEx and one small shared breadcrumb-items helper.

Nine screens migrate (D-02/D-03/D-04): each currently renders a hand-rolled `<h1>` (sometimes inside
a `<header>` or a `<div class="cl-row cl-row--between">`) directly under `<.cl_shell>`. The
mechanical lift is: nest `<.cl_page title="…" width="wide">` immediately inside `<.cl_shell>`, move
the `<h1>` text into `title=`, map `kb_nav`→`:subnav`, a single primary action→`:actions`, and leave
substantial filter/search bars in the body. All nine are headless-render-testable today via the
established `Module.render(assigns) |> rendered_to_string()` pattern (no Repo).

The riskiest piece (SHELL-02) is the **breadcrumb origin label**. The editor's `return_to` is
already a *verified, signed-token-derived* navigable path — but it is **always present** when a
review task exists (it falls back to `/knowledge-base/suggestions?task=N` even with no conversation
origin), and it carries **no explicit origin-kind marker**. So a human-readable crumb label must be
derived from the **path shape**, not from a token field. suggestion_review has no conversation origin
at all — its crumb is a static lane crumb (`Knowledge / Suggestions / {task}`).

**Primary recommendation:** Add one private helper `breadcrumb_items/1` (a presenter-style pure
function, co-located or in a small presenter) that builds `cl_breadcrumb`'s `items` list from
`{return_to, current_title}`, deriving a human label from the path shape (conversation vs review
lane), with the last crumb current/no-href. Migrate all nine screens to `cl_page width="wide"`
verbatim-title, slot-mapped per D-04. Prove everything with headless render assertions; do not break
the screenshot pipeline (full visual sweep is P45).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (from 38-CONTEXT.md `## Implementation Decisions`)

- **D-01 — Origin-aware breadcrumb on BOTH the KB editor and suggestion_review (owner-chosen,
  grounded).**
  - **Editor (`editor.ex:263`):** already renders a *static* `<.cl_breadcrumb>` (`Knowledge /
    Editing: {title}`). It carries a **verified** origin via `review_context.return_to`
    (`editor.ex:147`, decoded from a signed `handoff` token; `conversation_live.ex:180-206` is the
    producer when an operator opens the editor from a conversation). Make the trail **origin-aware**:
    when `return_to` is present, **prepend a back crumb to the origin** (≥2 crumbs + working back
    link, satisfying success-criterion 2), e.g. `← {origin} / Knowledge / Editing: {title}`; when
    absent, fall back to today's static `Knowledge / Editing` trail.
  - **Suggestion review (`suggestion_review.ex:192`):** has **NO breadcrumb today** and is normally
    reached from the **review lane** via `task=`/`queue=` params — it is itself a *producer* of
    editor handoffs (`:145-168`), not a receiver of a conversation `return_to`. So "extend to
    suggestion_review" lands as: **add** a `cl_breadcrumb` it currently lacks, origin-derived from
    its review-lane context (e.g. `Knowledge / Suggestions / {task}` with a back link to the
    suggestions lane), using the **same prepend mechanism** if a verified `return_to` is ever passed.
    Do **not** invent a conversation→suggestion_review handoff (none exists; scope creep toward P42).
  - **Shared mechanism:** prefer a small presenter/helper that builds the `items` list for
    `cl_breadcrumb` from `{origin return_to?, lane params, current title}`. The back link must be a
    real `navigate=` href (the last crumb stays current/no-href, per `cl_breadcrumb`'s contract).
  - **Research must verify:** (a) the `return_to` decoded from the handoff token is safe to render as
    a navigable crumb; (b) a human-readable label for the origin crumb (the raw `return_to` is a path
    — derive a label like "Conversation" rather than dumping the URL, honoring "never raw terms to
    operators").

- **D-02 — Wrap inside `cl_shell`, not replace it.** `cl_page` is the **inner** frame; each screen
  keeps `<.cl_shell current={…} destinations={…}>` as outer chrome and nests `<.cl_page title="…">`
  as the immediate child, with the existing body moving into `cl_page`'s `inner_block`. The current
  per-screen `<h1>` becomes the `title` attr (verbatim text).

- **D-03 — Width = `wide` for ALL migrated screens.** `:reading` lands in P41. Uniform `wide`
  directly satisfies success-criterion 1. No screen in this phase uses `:reading`.

- **D-04 — Slot mapping (consistency rule).** `kb_nav` tabs → **`:subnav`**; a single primary page
  action/button → **`:actions`**; **substantial filter bars stay in the body** (`inner_block`).
  Breadcrumb → the **`:breadcrumb`** slot (move the editor's existing `<.cl_breadcrumb>` call into
  that slot rather than leaving it free-floating above the header).

- **D-05 — Title text carried verbatim from each current `<h1>`; no copy rewrites in P38.** Home's
  "Welcome back" stays as-is here (Home redesign is P39). Pure structural lift with a clean diff.

- **D-06 — Screenshot-pipeline + render tests, headless where possible.** Plan for screenshot regen
  confirmation (full visual sweep is P45, but P38 must not break it). Add/adjust headless
  `render_component`/LiveView render assertions where they don't need Repo; mark genuinely
  Repo-dependent assertions `# REPO-UNAVAILABLE`. Breadcrumb back-link presence (≥2 crumbs + href) is
  assertable in a render test.

### Claude's Discretion
- Exact crumb labels and the origin-label derivation ("Conversation" vs "Review task" etc.), and
  whether the shared breadcrumb-items builder lives in a presenter vs an inline private helper.
- Per-screen slot details where a screen has no `kb_nav`/no primary action (those slots go unused).
- Plan/wave decomposition (one plan per screen vs grouped) — linear, low-risk; planner's call.
- Whether to add the `.cl-page` migration to `gaps.ex` as a 5th KB screen explicitly — include it for
  consistency; it's in the KB sub-screen set.

### Deferred Ideas (OUT OF SCOPE)
- **Audit-row → conversation linking** — Phase 42. P38 delivers the breadcrumb on the
  conversation→editor hop only.
- **conversation_live `cl_page`/`:reading`-rail migration** — Phase 41. Not migrated in P38.
- **Home body redesign** (hero, secondary band, health-as-chip, zero-state) — Phase 39. P38 keeps
  Home's current "Welcome back" content, only re-framed by `cl_page`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHELL-01 | Home, Inbox, Audit Log, Settings, and the KB screens render through `cl_page`, so every operator screen shares consistent header, width, and inner framing. | `cl_page/1` API verified (`components.ex:321-346`); per-screen migration shapes mapped below for all nine screens; uniform `width="wide"` (D-03); slot mapping (D-04) verified against each screen's existing chrome. |
| SHELL-02 | `cl_breadcrumb` is wired on the deep KB-from-conversation path (no longer defined-but-orphaned), giving a "you are here" cue on nested routes. | `cl_breadcrumb/1` contract verified (`components.ex:385-401`); editor `return_to` verified as a safe navigable origin (`editor.ex:147-149`, `verified_return_to_from_token/1` :207-214); producer path confirmed (`conversation_live.ex:185-206`); human-readable label derivation strategy documented; suggestion_review's static lane crumb derivation confirmed. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Warnings-clean builds are mandatory** — `mix compile --warnings-as-errors` must pass. Moving HEEx
  into `cl_page` slots is the warning risk (unused assigns, slot-arity). See Pitfall 3.
- **`mix test` must stay green** — report failures honestly. Known baseline noise (OutboundWorkerTest,
  a SettingsLive order-flake) is pre-existing, not a P38 regression.
- **`Cairnloop.Repo` may be unavailable in this workspace** — prefer headless/pure render tests.
  All nine screens already have a headless `render(assigns)` harness (see Validation Architecture).
- **Brand tokens over hardcoded hex; operator copy humanized** — never dump a raw path/URL to
  operators (the breadcrumb origin label must be human-readable, not the `return_to` path).
- **Seal completed phases** — render-layer-only; do NOT touch `propose/3`, idempotency, co-commit,
  governance facade. Additive over rewrite.
- **Decision policy (shift-left)** — auto-decide the discretionary calls (crumb labels, helper
  location) with recorded rationale; escalate nothing here (all low-impact, reversible).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Page header/width framing | Frontend render (HEEx) | — | `cl_page` is a stateless `Phoenix.Component`; purely presentational |
| Breadcrumb trail rendering | Frontend render (HEEx) | — | `cl_breadcrumb` is stateless; consumes a precomputed `items` list |
| Origin-label derivation | Presenter/helper (pure fn) | — | Display logic; follows the established presenter pattern (`audit_log_presenter.ex`); no Repo |
| Origin signal (`return_to`) | Already-loaded LiveView assign | Signed token (verified) | `review_context.return_to` is decoded+verified at mount (`editor.ex:147`); render just reads it |
| Lane context (suggestion_review) | Already-loaded LiveView assign | URL params | `queue_filter`/`selected_task` already assigned; static lane crumb |

**Key boundary:** Nothing in P38 crosses into the data/governance/event tier. The origin signal is
already loaded and verified upstream; P38 only *renders* it. This keeps sealed phases untouched.

## Standard Stack

No new packages. This phase uses only the already-shipped, in-repo primitives.

### Core (already in repo — verified)
| Component | Location | Purpose | Why Standard |
|-----------|----------|---------|--------------|
| `cl_page/1` | `lib/cairnloop/web/components.ex:329` | Inner page frame: title/subtitle header + `:actions`/`:breadcrumb`/`:subnav`/`inner_block` slots | Locked P37 (UIC-01); the consistency primitive |
| `cl_breadcrumb/1` | `lib/cairnloop/web/components.ex:391` | Trail nav; `items = [%{label, href}]`, last item current/no-href | Locked P37; the orphaned primitive this phase exercises |
| `cl_shell/1` | `lib/cairnloop/web/components.ex:358` | Outer nav chrome; stays unchanged (P38 nests `cl_page` inside it) | Locked; already on every screen |
| `kb_nav/1` | `lib/cairnloop/web/knowledge_base_live/nav_component.ex` | KB sub-tab strip → maps to `cl_page` `:subnav` | Already on all 4 KB screens |

### Supporting (presenters — existing pattern to follow)
| Module | Location | Purpose | When to Use |
|--------|----------|---------|-------------|
| `AuditLogPresenter` | `lib/cairnloop/web/audit_log_presenter.ex` | Centralizes display logic (`action_label/1` etc.) | The breadcrumb-items builder should mirror this presenter idiom |
| `ReviewTaskPresenter` | (referenced in suggestion_review) | Lane filters/labels | Source of human lane labels for suggestion_review's crumb |

### `cl_page/1` exact API (VERIFIED — `components.ex:321-346`)

```elixir
attr(:title, :string, required: true)
attr(:subtitle, :string, default: nil)
attr(:width, :string, values: ~w(wide reading), default: "wide")
slot(:actions)      # right-aligned in header row
slot(:breadcrumb)   # rendered ABOVE the title row (header top)
slot(:subnav)       # rendered BETWEEN header and body
slot(:inner_block, required: true)  # body
```

Rendered shape (verified):
```
<div class="cl-page cl-page--wide">
  <header class="cl-page__header">
    <div :if breadcrumb>{breadcrumb}</div>
    <div class="cl-row cl-row--between">
      <div><h1 class="cl-page__title">{title}</h1><p :if subtitle .../></div>
      <div :if actions>{actions}</div>
    </div>
  </header>
  <div :if subnav class="cl-page__subnav">{subnav}</div>
  <div class="cl-page__body">{inner_block}</div>
</div>
```

Valid `width` values: **`wide`** (default, `max-width: var(--cl-content-max)`, centered) and
`reading` (`var(--cl-rail-width)` ≈352px). P38 uses **`wide` for all nine** (D-03).
CSS confirmed present: `.cl-page` (`cairnloop.css:686`), `.cl-page--wide` (:689),
`.cl-page--reading` (:690), `.cl-page__header/__title/__subtitle/__subnav/__body` (:691-705).

### `cl_breadcrumb/1` exact API (VERIFIED — `components.ex:385-401`)

```elixir
attr(:items, :list, required: true)  # [%{label, href}], last item current (no href)
```
Renders `<nav class="cl-breadcrumb" aria-label="Breadcrumb">` with `/` separators; items WITH `href`
become `<.link navigate={href}>`, the item WITHOUT `href` becomes `<span aria-current="page">`.
**Contract:** the back-link crumb must carry `href:`; the current/last crumb must OMIT `href`.
CSS confirmed: `.cl-breadcrumb` (`cairnloop.css:459`), `.cl-breadcrumb__sep` (:460).

**Installation:** none. `npm install` / `mix deps.get` not required — no new dependencies.

## Package Legitimacy Audit

Not applicable — this phase installs **zero** external packages. It adopts in-repo, already-shipped
function components and adds pure-Elixir render/helper code. No registry interaction.

## Per-Screen Migration Shape (SHELL-01)

For each screen: where the `<h1>` is, the bespoke chrome, and the D-04 slot mapping. All line numbers
verified against live code.

| Screen | File:line (h1) | Current header chrome | `:subnav` | `:actions` | Body (`inner_block`) | Maps cleanly? |
|--------|----------------|------------------------|-----------|------------|----------------------|---------------|
| **Home** | `home_live.ex:67` (`<h1>Welcome back</h1>` inside `<header style=…>` with subtitle "What needs you today?") | `<header>` + `<p class="cl-text-muted">` subtitle | — | — | `.cl-home-grid` of 5 `cl_stat` | ✅ — subtitle → `subtitle="What needs you today?"`; the inline `<header style="margin-bottom…">` is replaced by `cl_page`'s header |
| **Inbox** | `inbox_live.ex:124` (`<h1>Inbox</h1>` inside `<div class="cairnloop-inbox">`) | live_component search modal (sibling of h1), bulk-header, list, sticky bulk bar, confirm modal | — | — | everything except h1 (search modal, list, bulk bar, modal all stay in body) | ✅ — substantial UI stays in body per D-04. **Note:** the `<.live_component … search-modal>` (`:115`) is a *sibling* of the body; keep it inside `inner_block` (or as a sibling of `cl_page` inside `cl_shell` — see Pitfall 4) |
| **Audit Log** | `audit_log_live.ex:91` (`<h1>Audit Log</h1>` inside `<header class="cl-mb-7">` + subtitle) | search/filter form lives in the `cl_card` `:header` (`:97-123`) — a *substantial* filter bar | — | — | `cl_card` (with its filter header + table + pagination) stays whole in body | ✅ — subtitle → `subtitle=`; the filter bar is part of the card, stays in body |
| **Settings** | `settings_live.ex:166` (`<h1>Settings</h1>` inside `<div class="cl-row cl-row--between">` with a Toggle-dark-mode button) | search modal live_component; the "Toggle dark mode" button is right-aligned beside h1; flash banners; health/MCP/policy cards | — | **"Toggle dark mode" button** → `:actions` (single primary-ish page action, right-aligned) | search modal + banners + cards | ✅ — the toggle button is the textbook `:actions` case |
| **KB Index** | `index.ex:57` (`<h1>Knowledge Base</h1>` inside `<div class="cl-row cl-row--between">` with a "New article" button) | `<.kb_nav current={:index}/>` (`:54`); "New article" `cl_button`; "Review KB gap candidates" link; articles card | `<.kb_nav current={:index}/>` | **"New article" button** → `:actions` | gap-candidates link + articles card | ✅ — clean: kb_nav→subnav, New article→actions |
| **KB Editor** | `editor.ex:271` (`<h1>Editing: {@article.title}</h1>` inside `cl-row--between`) | `<.cl_breadcrumb>` (`:263`, currently free-floating above kb_nav); `<.kb_nav current={:editor}/>` (`:268`); banners; 2-col markdown/preview grid (`style="display:grid…"` `:294`); source-gap card | `<.kb_nav current={:editor}/>` | — | banners + 2-col grid + gap card | ✅ — **breadcrumb moves into `:breadcrumb` slot** (D-04); the existing static items become origin-aware (SHELL-02) |
| **KB Gaps** | `gaps.ex:68` (`<h1>Knowledge gaps</h1>` inside `<header class="cl-mb-7">` + subtitle) | `<.kb_nav current={:gaps}/>` (`:65`); subtitle; gap-candidates card | `<.kb_nav current={:gaps}/>` | — | subtitle → `subtitle=`; gap card | ✅ |
| **KB Suggestion review** | `suggestion_review.ex:192` (`<h1>Suggestion review</h1>` inside `<header class="cl-mb-7">` + subtitle) | `<.kb_nav current={:suggestions}/>` (`:189`); subtitle; filter card; queue table; detail cards | `<.kb_nav current={:suggestions}/>` | — | filter card + queue + detail cards | ✅ — **plus a NEW breadcrumb** into `:breadcrumb` (SHELL-02, D-01) |

**No screen has chrome that fails to map cleanly.** Two consistency notes for the planner:

1. **Subtitle handling:** Home, Audit Log, Gaps, Suggestion review each carry a
   `<p class="cl-text-muted">` subtitle under the h1. These map to `cl_page`'s `subtitle=` attr (the
   component renders `<p class="cl-page__subtitle">`). This is a CSS-class change (`cl-text-muted` →
   `cl-page__subtitle`); confirm the visual is acceptable (both are muted) — if a test asserts the
   exact subtitle *text* it still passes; if a test asserts `cl-text-muted` on that node it would
   need updating. (No such assertion was found.)

2. **`kb_nav` order vs `cl_page`:** today `kb_nav` renders *above* the h1 on all 4 KB screens. In
   `cl_page` the `:subnav` slot renders *below* the header (between header and body) per
   `components.ex:342`. This is an intentional consistency change (subnav now sits under the title,
   matching the other screens' visual rhythm). Flag for the screenshot diff — it is the one visible
   reordering. It is correct per D-04; just note it so it isn't mistaken for a regression in P45.

## Breadcrumb Origin Plumbing (SHELL-02 — the riskiest part)

### (a) Is `return_to` safe to render as a `navigate=` href? — YES, verified.

`review_context.return_to` is set in `load_review_context/4` (`editor.ex:145-153`):
```elixir
return_to:
  verified_return_to_from_token(params) ||
    "/knowledge-base/suggestions?task=#{task.id}",
```
`verified_return_to_from_token/1` (`editor.ex:207-214`) decodes the signed `handoff` token via
`EditorHandoff.decode/1` and only returns the `return_to` string if decode succeeds. It is **already
rendered as a `navigate=` href today** at `editor.ex:287` (`<.link navigate={@review_context.return_to}>Return to review task</.link>`).
So it is verified-safe to reuse for the back crumb. **No new token plumbing needed.**

### (b) Human-readable origin label — derive from PATH SHAPE (no kind-marker in the token).

**Critical grounding finding:** The handoff token (`editor_handoff.ex:8-16`,
`knowledge_automation/editor_handoff.ex` token map) carries `suggestion_id`, `article_id`,
`review_task_id`, `return_to`, `manual_edit_opened_at` — **there is NO explicit "origin kind" field**
(e.g. no `"origin" => "conversation"`). And `return_to` is **always non-nil** when a review task
exists (it falls back to the suggestions lane). Therefore:

- `review_origin?` (`editor.ex:30`) = `review_task != nil` — this means "opened from the review lane,"
  NOT "opened from a conversation." It is **not** a reliable conversation-origin signal.
- The conversation producer (`conversation_live.ex:185-186`) sets `return_path = "/#{conversation.id}"`
  → `return_to` is a path like `/42` (bare conversation id, the conversation route root).
- The suggestion_review producer (`suggestion_review.ex:149-159`) sets `return_to` to
  `/knowledge-base/suggestions?task=N[&queue=…]`.

**So the label must be derived from the path shape of `return_to`:**

| `return_to` shape | Origin | Human label (Claude's discretion, recommended) |
|-------------------|--------|------------------------------------------------|
| `/knowledge-base/suggestions...` | Review lane | `"Suggestions"` (or fall back to the static `Knowledge` trail) |
| anything else / bare `/{id}` | A conversation | `"Conversation"` |

Recommended derivation (pure, total, no Repo):
```elixir
defp origin_label(return_to) when is_binary(return_to) do
  if String.starts_with?(return_to, "/knowledge-base"), do: "Suggestions", else: "Conversation"
end
defp origin_label(_), do: nil
```
This honors the copy rule (never dump the raw `/42` path to the operator). `[VERIFIED: editor.ex,
conversation_live.ex, editor_handoff.ex live code]`

**Recommended editor crumb logic (D-01):**
- When `return_to` is a conversation path → `[%{label: "Conversation", href: return_to},
  %{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: #{title}"}]` (≥2 crumbs + working
  back link → satisfies success-criterion 2).
- When `return_to` is the suggestions lane → either prepend `%{label: "Suggestions", href: return_to}`
  or fall back to today's static `[%{label: "Knowledge", href: "/knowledge-base"},
  %{label: "Editing: #{title}"}]`. **Decision (auto, shift-left):** prepend `"Suggestions"` so the
  back link is always live and the orphaned-primitive intent (a working deep-path back link) is
  exercised in both cases. Either is acceptable per D-01; prepending is the stronger consistency
  choice.

### (c) suggestion_review — NO conversation origin; static lane crumb. — confirmed.

`suggestion_review.ex` has **no breadcrumb today** (verified: render starts at `:188` with
`<.kb_nav>` then `<header><h1>`; no `cl_breadcrumb`). It is reached via the review lane (`task=`/
`queue=` params; `queue_filter` and `selected_task` are already assigns — `:13-24`, `:29-57`). It is
a **producer** of editor handoffs (`:141-169`), never a receiver of a conversation `return_to`.

So its crumb is **static/lane-derived** (no conversation origin to honor):
```
[%{label: "Knowledge", href: "/knowledge-base"},
 %{label: "Suggestions"}]            # current page, no href
```
Optionally, when a task is selected, a 3rd current crumb (`{task_title}`) with the prior
`Suggestions` crumb becoming a live back link to `/knowledge-base/suggestions`. The available signals
for the crumb: `@queue_filter`, `@selected_task` (and `task_patch/2`/`queue_patch/2` helpers already
in the module). **Do not invent a conversation→suggestion_review handoff** (none exists — that's P42).

### (d) Shared breadcrumb-items builder — recommended shape & location.

A single pure function building the `items` list keeps both screens consistent and exercises the
orphaned primitive once. **Recommended signature:**
```elixir
# items from {return_to, current_title} for the editor; {nil, lane labels} for suggestion_review
breadcrumb_items(return_to, current_title)  # editor
# -> prepends an origin crumb when return_to present, always ends with a no-href current crumb
```
**Location (Claude's discretion — recommended):** a small **presenter** mirroring the established
`audit_log_presenter.ex` idiom — e.g. `Cairnloop.Web.BreadcrumbPresenter` with
`editor_items/2` and `suggestions_items/1` — OR co-located private helpers in each LiveView. Given
the two call sites differ in inputs (editor: verified `return_to`; suggestion_review: lane params)
and the logic is small, a **shared presenter module** is the cleaner choice (testable headless, no
Repo, matches CLAUDE.md "new reads/display logic go through presenters/facade not inline"). The
last crumb must always be current (no `href:` key) per the `cl_breadcrumb` contract.

## Architecture Patterns

### Migration Diagram (data/render flow, per screen)

```
URL/params ──► LiveView.mount/3 (assigns; for editor: load_review_context → verified return_to)
                    │
                    ▼
            LiveView.render/1 (HEEx)
                    │
            <.cl_shell current= destinations=>          ← OUTER chrome (unchanged)
                    │
            <.cl_page title="{old <h1> text}" width="wide">   ← NEW inner frame
                ├─ <:breadcrumb> (editor + suggestion_review only)
                │     items = BreadcrumbPresenter.*(return_to|lane)   ← origin-aware
                ├─ <:subnav> <.kb_nav current=…/> (KB screens only)
                ├─ <:actions> single primary button (Settings/KB-Index only)
                └─ (inner_block) ← the entire former body, minus the <h1> and its wrapper
                    │
                    ▼
            .cl-page--wide  (consistent max-width + gutter)  ← satisfies SHELL-01 success-criterion 1
```

### Pattern 1: Minimal page migration (Home / Gaps — no actions, no subnav)
```elixir
# BEFORE (gaps.ex)
<.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
  <.kb_nav current={:gaps} />
  <header class="cl-mb-7">
    <h1>Knowledge gaps</h1>
    <p class="cl-text-muted">Ranked maintenance signals…</p>
  </header>
  <.cl_card>…</.cl_card>
</.cl_shell>

# AFTER
<.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
  <.cl_page title="Knowledge gaps" subtitle="Ranked maintenance signals…" width="wide">
    <:subnav><.kb_nav current={:gaps} /></:subnav>
    <.cl_card>…</.cl_card>
  </.cl_page>
</.cl_shell>
```

### Pattern 2: Page with a primary action (KB Index / Settings)
```elixir
<.cl_page title="Knowledge Base" width="wide">
  <:subnav><.kb_nav current={:index} /></:subnav>
  <:actions>
    <.cl_button variant="primary" phx-click="new_article" phx-disable-with="Creating...">
      New article
    </.cl_button>
  </:actions>
  <p class="cl-mb-7"><.link navigate="/knowledge-base/gaps">Review KB gap candidates</.link></p>
  <.cl_card>…</.cl_card>
</.cl_page>
```

### Pattern 3: Origin-aware breadcrumb (Editor)
```elixir
<.cl_page title={"Editing: #{@article.title}"} width="wide">
  <:breadcrumb>
    <.cl_breadcrumb items={BreadcrumbPresenter.editor_items(@review_context.return_to, @article.title)} />
  </:breadcrumb>
  <:subnav><.kb_nav current={:editor} /></:subnav>
  <.cl_banner :if={…}>…</.cl_banner>
  <div style="display:grid; grid-template-columns: 1fr 1fr; gap: var(--cl-space-5)">…</div>  # KEEP tokens
</.cl_page>
```

### Anti-Patterns to Avoid
- **Cramming a substantial filter/search bar into `:actions`** — D-04 forbids it. Audit Log's
  search+filter form and inbox's controls stay in the body.
- **Leaving the editor breadcrumb free-floating** above the header — it must move into `:breadcrumb`
  (D-04).
- **Rewriting body markup while migrating** — keep the diff a pure structural lift (D-05). Don't
  retheme, don't touch the 2-col grid's token-based `style=`, don't churn sealed logic.
- **Using `return_to`/`review_origin?` as a conversation-origin boolean** — `review_origin?` is true
  for ANY review-lane open; the conversation signal is the *path shape*, not that flag.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Page header/width chrome | Per-screen `<header>` + width div | `cl_page` slots | The entire point of SHELL-01: one consistent frame |
| Breadcrumb markup | Inline `<nav>` per screen | `cl_breadcrumb items=` | Locked primitive; `aria-current`/sep handled |
| Origin label | Inline `if` in HEEx | `BreadcrumbPresenter.*` pure fn | Presenter idiom; testable; keeps copy-rule logic in one place |
| Origin token decode | New signing/verify | existing `review_context.return_to` | Already verified at mount (`editor.ex:147`) |

**Key insight:** Every capability here already exists as a primitive or a verified assign. The only
*new* code is one small display helper. Anything more is scope creep.

## Runtime State Inventory

This is a **render-layer refactor**, not a rename/data migration — but it touches strings/markup, so
each category is answered explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/collection/key strings change. Verified: no schema, query, or stored-string touch. | none |
| Live service config | None — no external service config references these screens' markup. | none |
| OS-registered state | None — no task/process/unit names involved. | none |
| Secrets/env vars | None — the signed `handoff` token's secret key and structure are **unchanged** (P38 only *reads* `return_to`, never re-signs). | none |
| Build artifacts | None — no package/egg/binary rename; `mix compile` recompiles touched `.ex` normally. | none |

**Test-string coupling (the one real "stale state" risk):** existing test assertions that match the
old header markup. Verified: only `inbox_live_test.exs:625` references `<h1>Inbox</h1>` — and that's
in the *test name string*, asserting `"No conversations yet."` (it will NOT break). The markdown
render test `knowledge_base_live_test.exs:201` (`"<h1>\nHello</h1>"`) asserts *preview content*, not
the page header — safe. No test asserts the page `<h1>` wrapper markup. **Action:** none required,
but the planner should add a grep step before each screen's verification to catch any
header-markup assertion (`<h1>`, `cl-text-muted` on a subtitle node, free-floating breadcrumb).

## Common Pitfalls

### Pitfall 1: `review_origin?` mistaken for a conversation-origin flag
**What goes wrong:** Using `@review_origin?` to decide whether to show the conversation back crumb
shows the back crumb for *every* review-lane open, mislabeling suggestion-lane opens as "Conversation."
**Why it happens:** `review_origin? = review_task != nil` (`editor.ex:30`) reads like "came from
elsewhere," but it just means "a review task is attached." `return_to` is non-nil in both cases.
**How to avoid:** Derive the label from the `return_to` **path shape** (`/knowledge-base...` = lane,
else = conversation), per section (b). Never branch on `review_origin?` for the crumb label.
**Warning signs:** A suggestion-lane editor open shows "Conversation /" in its trail.

### Pitfall 2: Breaking the `cl_breadcrumb` last-item contract
**What goes wrong:** Giving the current/last crumb an `href` makes it a link (wrong; loses
`aria-current="page"`), or omitting `href` on the back crumb makes the back link dead.
**Why it happens:** The contract is positional: last item = no `href`; all prior = `href` present.
**How to avoid:** Builder always appends `%{label: current_title}` (no `href:` key) last; all earlier
crumbs carry `href:`. Assert both in a render test (a `<.link navigate=…>` AND an
`aria-current="page"` span).

### Pitfall 3: Warnings-as-errors when moving HEEx into slots
**What goes wrong:** `mix compile --warnings-as-errors` fails on an unused assign (if an old assign
was only used in removed wrapper markup) or a slot used where the component doesn't declare it.
**Why it happens:** Reshuffling markup can orphan an assign; `cl_page` only declares
`:actions`/`:breadcrumb`/`:subnav`/`inner_block` — any other named slot errors.
**How to avoid:** After each screen migration run `mix compile --warnings-as-errors`. Only use the
four declared slots. If an assign goes unused, it usually wasn't (body moved wholesale), but verify.
**Warning signs:** "variable @x is unused" / "undefined slot" at compile.

### Pitfall 4: Inbox/Settings `live_component` sibling placement
**What goes wrong:** The search-modal `<.live_component>` (inbox `:115`, settings `:157`) is a sibling
of the `<h1>` body today. If it's dropped *outside* both `cl_page` and the body it can lose its DOM
position; if double-nested it can duplicate.
**Why it happens:** `cl_page` introduces a new wrapping div; the modal must land in exactly one place.
**How to avoid (decision):** Keep the search modal as the **first child of `inner_block`** (inside
`cl_page`). It's a fixed-overlay component; its visual position is CSS-driven, so being inside
`cl-page__body` is fine and keeps the LiveView tree stable. Verify with the existing search-modal
render test still passing.

### Pitfall 5: Subnav reorder mistaken for a P45 screenshot regression
**What goes wrong:** `kb_nav` now renders *below* the title (was above). The P45 screenshot diff
flags it as a change.
**How to avoid:** Document the intentional reorder (this RESEARCH + the plan) so P45 acceptance reads
it as expected, not a regression.

## Code Examples

### Headless render assertion for ≥2 crumbs + working back link (success-criterion 2)
```elixir
# Source: established pattern — home_live_test.exs:27, knowledge_base_live_test.exs:716-721
test "editor from a conversation shows a working back crumb (≥2 crumbs)" do
  assigns = build_editor_assigns(return_to: "/42")  # conversation path
  html = render_html(assigns)                         # Editor.render(assigns) |> rendered_to_string

  assert html =~ ~s(class="cl-breadcrumb")
  assert html =~ ~s(navigate="/42") or html =~ ~s(href="/42")   # working back link
  assert html =~ ~s(aria-current="page")                         # current crumb present
  # ≥2 crumbs => at least one separator
  assert html =~ ~s(class="cl-breadcrumb__sep")
end
```

### Headless assertion that a screen now renders inside `.cl-page`
```elixir
test "gaps renders inside the shared page shell" do
  html = rendered_to_string(Cairnloop.Web.KnowledgeBaseLive.Gaps.render(assigns(%{})))
  assert html =~ ~s(class="cl-page cl-page--wide")
  assert html =~ ~s(class="cl-page__title")
  assert html =~ "Knowledge gaps"   # verbatim title carried (D-05)
end
```

### Origin-label derivation (pure, no Repo)
```elixir
# BreadcrumbPresenter (recommended location)
def editor_items(return_to, title) when is_binary(return_to) do
  origin = if String.starts_with?(return_to, "/knowledge-base"), do: "Suggestions", else: "Conversation"
  [%{label: origin, href: return_to},
   %{label: "Knowledge", href: "/knowledge-base"},
   %{label: "Editing: #{title}"}]
end
def editor_items(_return_to, title) do
  [%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: #{title}"}]
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-screen hand-rolled `<h1>` + width div | `cl_page` inner frame | P37 built it, P38 adopts | Consistent header/width across the cockpit |
| Static `Knowledge / Editing` breadcrumb (editor only) | Origin-aware trail with a live back crumb; new crumb on suggestion_review | P38 | Deep-path "you are here" + working back nav |

**Deprecated/outdated:** the free-floating `<.cl_breadcrumb>` above `kb_nav` in `editor.ex:263-266`
(moves into the `:breadcrumb` slot). The per-screen `<header style=…>`/`<header class="cl-mb-7">`
wrappers (replaced by `cl_page`'s `__header`).

## Validation Architecture

> `workflow.nyquist_validation` is not disabled in config — this section is included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + `Phoenix.LiveViewTest` (`render_component/2`, `rendered_to_string/1`) |
| Config file | `mix.exs` / `test/test_helper.exs` (standard) |
| Quick run command | `mix test test/cairnloop/web/<screen>_test.exs` |
| Full suite command | `mix test` (excludes `:integration`); CI adds `mix test.integration` + quality lane |
| Headless pattern | `Module.render(assigns) |> rendered_to_string()` — established on every screen (home_live_test:27, knowledge_base_live_test:716, suggestion_review_test:872, inbox_live_test render_html) |

### Success-Criterion / Requirement → Validation Map
| Criterion / Req | Behavior | Validation Method | Testability |
|-----------------|----------|-------------------|-------------|
| SHELL-01 / SC-1 (consistent inner width) | All 9 screens render `.cl-page--wide` | Render assertion `html =~ "cl-page cl-page--wide"` per screen | **Headless** (no Repo) |
| SHELL-01 (title carried) | Each `cl_page__title` shows the verbatim old h1 text (D-05) | Render assertion on title text + `cl-page__title` | **Headless** |
| SHELL-01 (slot mapping) | kb_nav in `cl-page__subnav`; primary action in header actions | Render assertion: subnav/actions markers present | **Headless** |
| SHELL-02 / SC-2 (≥2 crumbs + back link) | Editor from-conversation trail has a working `navigate=` back crumb + an `aria-current` current crumb | Render assertion (example above) | **Headless** |
| SHELL-02 (suggestion_review crumb exists) | suggestion_review now renders a `cl-breadcrumb` | Render assertion `html =~ "cl-breadcrumb"` | **Headless** |
| SC-1 (visual consistency) | Light+dark screenshots unbroken | Screenshot pipeline regen confirmation (P45 owns the full sweep) | **Visual-only** (confirm pipeline still runs; do not block on full acceptance) |
| Brand gate | No hex fallback re-introduced | `brand_token_gate_test.exs` stays green | **Headless** |
| Build | Warnings-clean | `mix compile --warnings-as-errors` | **Compile check** |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/<that_screen>_test.exs` + `mix compile --warnings-as-errors`.
- **Per wave merge:** `mix test` (full default suite incl. brand gate + components_test).
- **Phase gate:** full suite green + a screenshot-pipeline smoke (pipeline runs without error) before
  `/gsd:verify-work`. The exhaustive visual acceptance is P45 (VERIFY-01).

### Wave 0 Gaps
- [ ] Possibly add a tiny shared test asserting `.cl-page--wide` presence per screen (or extend each
  existing `_test.exs`). Most screens already have a headless render harness — extend, don't create.
- [ ] If `BreadcrumbPresenter` is introduced: add `test/cairnloop/web/breadcrumb_presenter_test.exs`
  (pure, no Repo) covering conversation-path → "Conversation", lane-path → "Suggestions", nil →
  static fallback, and last-crumb-has-no-href.
- [ ] No framework install needed (ExUnit/LiveViewTest already present).

## Security Domain

> `security_enforcement` default-enabled. This is a render-layer phase with a narrow surface.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | unchanged |
| V3 Session Management | no | unchanged |
| V4 Access Control | no | unchanged (scope filters unchanged) |
| V5 Input Validation / Output Encoding | **yes** | `return_to` is rendered as a `navigate=` href; it is already **verified** via the signed `handoff` token (`verified_return_to_from_token/1`). HEEx auto-escapes the label text. Do **not** render the raw path as visible text (copy rule + avoids reflecting an attacker-influenced path) — render a derived human label instead. |
| V6 Cryptography | no | the handoff token is signed/verified upstream; P38 only reads the decoded value, never re-signs |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Open-redirect / unverified back link | Tampering | `return_to` is only honored when it decodes from the signed `handoff` token (already enforced at `editor.ex:147,207-214`); P38 reuses this verified value — never an unverified param |
| Path/URL reflected to operator | Information disclosure / spoofing | Render a derived label ("Conversation"/"Suggestions"), never the raw `return_to` string (honors the copy rule AND avoids reflecting a path) |
| XSS via title/label | Tampering | HEEx auto-escapes `{...}` interpolations; titles/labels are plain strings — no `raw/1` |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The intended human label for a conversation origin is "Conversation" (and lane origin "Suggestions"). Exact wording is explicitly Claude's-discretion per D-01; any humanized noun satisfies the copy rule. | Breadcrumb (b) | Low — label text only; trivially adjustable; no behavior impact |
| A2 | Prepending a "Suggestions" back crumb (vs falling back to the static trail) when `return_to` is the lane path is the better consistency choice. D-01 permits either. | Breadcrumb (b) | Low — both satisfy SHELL-02; reversible |
| A3 | A shared `BreadcrumbPresenter` module is preferable to inline per-LiveView helpers. D-01 leaves this to discretion. | Breadcrumb (d) | Low — pure refactor location; either passes tests |

**No assumptions affect compliance, retention, security posture, or data.** All structural and API
claims are VERIFIED against live code.

## Open Questions (RESOLVED)

1. **Subtitle node class change (`cl-text-muted` → `cl-page__subtitle`).** RESOLVED — see recommendation.
   - What we know: Home/Audit/Gaps/Suggestion-review subtitles map to `cl_page`'s `subtitle=` attr,
     which renders `<p class="cl-page__subtitle">`.
   - What's unclear: whether any screenshot or test depends on the old `cl-text-muted` subtitle class.
   - Recommendation: grep confirmed no test asserts it; proceed. Flag in the P45 screenshot diff as an
     expected, benign class swap.

2. **Does the screenshot pipeline auto-discover the migrated screens, or need a manifest update?**
   - What we know: full visual sweep + seed enrichment is P45 (VERIFY-01/SEED-01).
   - What's unclear: whether P38's structural change requires regenerating baselines now.
   - Recommendation: P38 should run the pipeline as a *smoke* (it executes without error); leave
     baseline acceptance to P45. Planner: add a "screenshot pipeline runs clean" gate, not a
     "baselines updated" gate.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / `mix compile` | warnings-clean build | ✓ (repo standard) | CI-pinned 1.19.5 (memory) | — |
| ExUnit / Phoenix.LiveViewTest | headless render tests | ✓ (in deps) | — | — |
| `Cairnloop.Repo` (Postgres) | NOT required by P38 render tests | may be ✗ in workspace | — | headless `render(assigns)` harness needs no Repo (already used by every screen) |
| Playwright screenshot pipeline | SC-1 visual confirm | (CI) | — | confirm pipeline runs; full acceptance deferred to P45 |

**Missing dependencies with no fallback:** none — P38 is fully testable headlessly.
**Missing dependencies with fallback:** Repo unavailability is fully covered by the headless render
pattern; mark any genuinely Repo-needing assertion `# REPO-UNAVAILABLE` (none expected here).

## Sources

### Primary (HIGH confidence — live code, this session)
- `lib/cairnloop/web/components.ex:321-401` — `cl_page/1`, `cl_shell/1`, `cl_breadcrumb/1` exact API
- `priv/static/cairnloop.css:459-460, 686-705` — `.cl-breadcrumb`, `.cl-page*` CSS
- `lib/cairnloop/web/home_live.ex:63-122`, `inbox_live.ex:112-197`, `audit_log_live.ex:87-167`,
  `settings_live.ex:154-195` — screen header regions
- `lib/cairnloop/web/knowledge_base_live/index.ex:51-111`, `editor.ex:1-44,128-214,260-345`,
  `gaps.ex:62-97`, `suggestion_review.ex:130-357` — KB screen headers + breadcrumb plumbing
- `lib/cairnloop/web/conversation_live.ex:170-219` — editor handoff producer (`return_to` shape)
- `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex` + `knowledge_automation/editor_handoff.ex`
  — token map (no origin-kind field)
- `lib/cairnloop/web/knowledge_base_live/nav_component.ex` — `kb_nav/1`
- `lib/cairnloop/web/audit_log_presenter.ex` — presenter idiom to mirror
- `test/cairnloop/web/{home_live,inbox_live,knowledge_base_live,knowledge_base_live/suggestion_review,brand_token_gate}_test.exs`
  — headless render harness + gate scope
- `.planning/phases/37-component-primitives/37-CONTEXT.md` (D-08/D-09), `38-CONTEXT.md`,
  `REQUIREMENTS.md` (SHELL-01/02)

### Secondary / Tertiary
- None — no external/web sources needed (in-repo adoption phase).

## Metadata

**Confidence breakdown:**
- Standard stack (cl_page/cl_breadcrumb API): **HIGH** — read directly from source + CSS.
- Per-screen migration shapes: **HIGH** — every h1 and chrome element line-verified.
- Breadcrumb origin plumbing: **HIGH** — verified `return_to` is signed-token-derived and already
  rendered as a navigate href; verified no origin-kind field exists (label must derive from path).
- Testing approach: **HIGH** — established headless `render(assigns)` harness confirmed on all screens.
- Pitfalls: **HIGH** — derived from concrete code facts (review_origin? semantics, slot declarations,
  brand-gate regex scope).

**Research date:** 2026-06-03
**Valid until:** ~2026-07-03 (stable; in-repo only — invalidated only by edits to `components.ex`,
the listed screens, or the handoff token shape).
