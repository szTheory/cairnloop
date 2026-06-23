# Phase 38: Shared Page-Shell Migration - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 9 modified screens + 1 new presenter/helper
**Analogs found:** 10 / 10 (every change has a verified in-repo analog — pure-adoption phase)

> This is a PURE-ADOPTION migration. The primitives (`cl_page/1`, `cl_breadcrumb/1`,
> `cl_shell/1`) already exist and are LOCKED (P37). All 9 screen files are MODIFIED in place,
> not created. The only genuinely new code is one small breadcrumb-items presenter/helper.
> Every excerpt below is the concrete shape the planner should make screens replicate.

## File Classification

| Modified/New File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/home_live.ex` (MOD) | LiveView render | request-response | `cl_page` def + `gaps.ex` (subtitle, no actions/subnav) | exact (migration target is the primitive itself) |
| `lib/cairnloop/web/inbox_live.ex` (MOD) | LiveView render | request-response | `cl_page` def; sibling-modal handling per Pitfall 4 | exact |
| `lib/cairnloop/web/audit_log_live.ex` (MOD) | LiveView render | request-response | `cl_page` def + subtitle pattern; filter bar stays in body | exact |
| `lib/cairnloop/web/settings_live.ex` (MOD) | LiveView render | request-response | `cl_page` def; `:actions` = Toggle dark mode (textbook actions case) | exact |
| `lib/cairnloop/web/knowledge_base_live/index.ex` (MOD) | LiveView render | request-response | `cl_page` def; `:subnav`=kb_nav, `:actions`=New article | exact |
| `lib/cairnloop/web/knowledge_base_live/editor.ex` (MOD) | LiveView render | request-response | **its own current `cl_breadcrumb` call (`:263`) is the best exemplar** | exact + best exemplar |
| `lib/cairnloop/web/knowledge_base_live/gaps.ex` (MOD) | LiveView render | request-response | `cl_page` minimal pattern (subtitle + subnav, no actions) | exact |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` (MOD) | LiveView render | request-response | `editor.ex` breadcrumb call (replicate) + `gaps.ex` page shape | exact |
| `Cairnloop.Web.BreadcrumbPresenter` (NEW) | presenter | transform (pure fn) | `lib/cairnloop/web/audit_log_presenter.ex` | role-match (presenter idiom) |

---

## Migration Target Shape (the primitive every screen wraps into)

**Source:** `lib/cairnloop/web/components.ex:321-346` (`cl_page/1`)

**Exact API (attrs + slots) the planner must replicate:**
```elixir
attr(:title, :string, required: true)
attr(:subtitle, :string, default: nil)
attr(:width, :string, values: ~w(wide reading), default: "wide")
slot(:actions)      # right-aligned in header's cl-row--between
slot(:breadcrumb)   # rendered ABOVE the title row (header top); only emits if non-empty
slot(:subnav)       # rendered BETWEEN header and body (cl-page__subnav)
slot(:inner_block, required: true)  # the whole former body, minus <h1>/wrapper
```

**Rendered DOM (what render-tests assert against)** — `components.ex:329-345`:
```elixir
<div class={["cl-page", "cl-page--#{@width}"]}>      # => "cl-page cl-page--wide"
  <header class="cl-page__header">
    <div :if={@breadcrumb != []}>{render_slot(@breadcrumb)}</div>
    <div class="cl-row cl-row--between">
      <div>
        <h1 class="cl-page__title">{@title}</h1>
        <p :if={@subtitle} class="cl-page__subtitle">{@subtitle}</p>
      </div>
      <div :if={@actions != []}>{render_slot(@actions)}</div>
    </div>
  </header>
  <div :if={@subnav != []} class="cl-page__subnav">{render_slot(@subnav)}</div>
  <div class="cl-page__body">{render_slot(@inner_block)}</div>
</div>
```
**Test markers (headless, no Repo):** `class="cl-page cl-page--wide"`, `class="cl-page__title"`,
`class="cl-page__subtitle"`, `class="cl-page__subnav"`.

**Breadcrumb primitive** — `components.ex:385-401` (`cl_breadcrumb/1`):
```elixir
attr(:items, :list, required: true)  # [%{label, href}], LAST item current (NO :href key)
# Renders <nav class="cl-breadcrumb" aria-label="Breadcrumb">; items WITH href => <.link navigate=>;
# the one WITHOUT href => <span aria-current="page">; separators are <span class="cl-breadcrumb__sep">/</span>
```
**Contract (Pitfall 2):** back crumb carries `href:`; current/last crumb OMITS `href:`.
Test markers: `class="cl-breadcrumb"`, `navigate="…"` (or `href=`), `aria-current="page"`,
`class="cl-breadcrumb__sep"` (≥2 crumbs => ≥1 separator).

**Both primitives are imported via `import Cairnloop.Web.Components`** — already present on every
screen (verified `editor.ex:3`, `suggestion_review.ex:4`). No new imports needed for `cl_page`/`cl_breadcrumb`.

---

## Best Already-Correct Exemplar

**Source:** `lib/cairnloop/web/knowledge_base_live/editor.ex:262-272` — the ONLY screen rendering
`cl_breadcrumb` today (currently free-floating ABOVE `kb_nav`; D-04 moves it into `:breadcrumb`):
```elixir
<.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
  <.cl_breadcrumb items={[
    %{label: "Knowledge", href: "/knowledge-base"},
    %{label: "Editing: #{@article.title}"}     # last item: NO href => current crumb
  ]} />

  <.kb_nav current={:editor} />

  <div class="cl-row cl-row--between cl-mb-7">
    <h1>Editing: {@article.title}</h1>
  </div>
  ...
```
This is the reference `items` shape (label/href maps; current crumb omits href) the
`suggestion_review` crumb and the new presenter must produce. The editor's full body (2-col grid
at `:294` with token-based `style=`, banners, source-gap card) moves wholesale into `inner_block`
UNCHANGED (D-05 / anti-pattern: don't retheme the grid).

**Verified origin signal for editor's origin-aware crumb** — `editor.ex:145-153`:
```elixir
return_to:
  verified_return_to_from_token(params) ||
    "/knowledge-base/suggestions?task=#{task.id}",
```
`verified_return_to_from_token/1` (`editor.ex:207-214`) only returns the string if the signed
`handoff` token decodes — already rendered as a `navigate=` href today at `editor.ex:287`
(`<.link navigate={@review_context.return_to}>Return to review task</.link>`). Safe to reuse for the
back crumb; NO new token plumbing. **Producers of that `return_to` shape:**
- Conversation → `conversation_live.ex:185-186`: `return_path = "/#{conversation.id}"` (bare `/42`).
- Suggestion lane → `suggestion_review.ex:149-159`: `/knowledge-base/suggestions?task=N[&queue=…]`.
- **No origin-kind field in the token** — label MUST derive from path shape (see Shared Patterns / Pitfall 1).

---

## Pattern Assignments (per-screen current header region)

Each block gives the exact CURRENT `<h1>`+chrome (with line numbers) for `read_first`, and the
D-04 slot target. The `<h1>` wrapper (`<header style=…>` / `cl-row--between` / `<header class="cl-mb-7">`)
is REMOVED; its text becomes `title=`; subtitle `<p class="cl-text-muted">` becomes `subtitle=`.

### `home_live.ex` (no actions, no subnav)
**Current header** (`home_live.ex:65-69`):
```elixir
<.cl_shell current={:home} destinations={Cairnloop.Web.Nav.destinations()}>
  <header style="margin-bottom: var(--cl-space-7);">
    <h1>Welcome back</h1>
    <p class="cl-text-muted">What needs you today?</p>
  </header>
  <div class="cl-home-grid">...5× cl_stat...</div>
```
→ `<.cl_page title="Welcome back" subtitle="What needs you today?" width="wide">` ; `.cl-home-grid`
stays in body. **D-05: "Welcome back" verbatim (Home redesign is P39).** No `:actions`/`:subnav`.

### `inbox_live.ex` (no actions, no subnav; sibling-modal — Pitfall 4)
**Current header** (`inbox_live.ex:114-124`):
```elixir
<.cl_shell current={:inbox} destinations={Cairnloop.Web.Nav.destinations()}>
  <.live_component module={Cairnloop.Web.SearchModalComponent} id="search-modal"
    host_surface="inbox" host_user_id={@host_user_id} current_path="/" />
  <div class="cairnloop-inbox">
    <h1>Inbox</h1>
    ...empty-state, bulk-header, list, sticky bulk bar, confirm modal...
```
→ `<.cl_page title="Inbox" width="wide">`. **Search-modal `live_component` (`:115`) becomes FIRST
CHILD of `inner_block`** (Pitfall 4 decision). Everything else (list, bulk bar, modal) stays in body
per D-04. The `<div class="cairnloop-inbox">` wrapper may stay around the body content.
**Test note:** `inbox_live_test.exs:625` references `<h1>Inbox</h1>` only in a test NAME string asserting
`"No conversations yet."` — will NOT break.

### `audit_log_live.ex` (no actions, no subnav; substantial filter bar stays in body)
**Current header** (`audit_log_live.ex:89-95`):
```elixir
<.cl_shell current={:audit} destinations={Cairnloop.Web.Nav.destinations()}>
  <header class="cl-mb-7">
    <h1>Audit Log</h1>
    <p class="cl-text-muted">A timeline of governed actions ... Search or filter to narrow the view.</p>
  </header>
  <.cl_card>
    <:header>...search form + action filter form (cl-row--wrap)...</:header>  # filter bar = card header, :97-123
    ...table + pagination...
```
→ `<.cl_page title="Audit Log" subtitle="A timeline of governed actions ...">`. The filter bar lives
in the `cl_card` `:header` (`:97-123`) — **stays whole in body** (D-04 forbids cramming filters into
`:actions`). No primary action.

### `settings_live.ex` (textbook `:actions` case; sibling-modal — Pitfall 4)
**Current header** (`settings_live.ex:156-174`):
```elixir
<.cl_shell current={:settings} destinations={Cairnloop.Web.Nav.destinations()}>
  <.live_component module={Cairnloop.Web.SearchModalComponent} id="search-modal"
    host_surface="settings" host_user_id={@host_user_id} current_path="/settings" />
  <div class="cl-row cl-row--between cl-mb-7">
    <h1>Settings</h1>
    <button type="button" onclick="...toggle theme..." class="cl-button cl-button--ghost">
      Toggle dark mode
    </button>
  </div>
  ...flash banners, health/MCP/policy cards...
```
→ `<.cl_page title="Settings" width="wide">` with `<:actions>` = the **Toggle dark mode** button
(verbatim, incl. its `onclick`). Search-modal `live_component` → first child of `inner_block`
(Pitfall 4). Banners + cards stay in body.
**Test note (memory baseline):** SettingsLive has a known order-flake — don't count as regression.

### `index.ex` (KB; `:subnav`=kb_nav, `:actions`=New article)
**Current header** (`index.ex:53-61`):
```elixir
<.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
  <.kb_nav current={:index} />
  <div class="cl-row cl-row--between cl-mb-7">
    <h1>Knowledge Base</h1>
    <.cl_button variant="primary" phx-click="new_article" phx-disable-with="Creating...">
      New article
    </.cl_button>
  </div>
  <p class="cl-mb-7"><.link navigate="/knowledge-base/gaps">Review KB gap candidates</.link></p>
  <.cl_card>...articles table...</.cl_card>
```
→ `<.cl_page title="Knowledge Base" width="wide">` ; `<:subnav><.kb_nav current={:index} /></:subnav>` ;
`<:actions>` = the **New article** `cl_button`. The gap-candidates `<p>` link + articles card stay in body.

### `editor.ex` (KB; `:subnav`=kb_nav, `:breadcrumb`=origin-aware — SHELL-02)
**Current header** (`editor.ex:262-272`, full exemplar excerpt above):
```elixir
<.cl_breadcrumb items={[...]} />          # :263 — MOVE into <:breadcrumb> slot (D-04)
<.kb_nav current={:editor} />             # :268 — MOVE into <:subnav>
<div class="cl-row cl-row--between cl-mb-7"><h1>Editing: {@article.title}</h1></div>  # :270-272
```
→ `<.cl_page title={"Editing: #{@article.title}"} width="wide">` with:
- `<:breadcrumb><.cl_breadcrumb items={BreadcrumbPresenter.editor_items(@review_context.return_to, @article.title)} /></:breadcrumb>`
- `<:subnav><.kb_nav current={:editor} /></:subnav>`
- body = banners (`:274-292`) + 2-col grid (`:294`, KEEP token `style=`) + source-gap card (`:328`) UNCHANGED.
**No `:actions`.** Origin-aware items satisfy SHELL-02 / SC-2 (≥2 crumbs + working back link).

### `gaps.ex` (KB; minimal — `:subnav`=kb_nav, subtitle, no actions)
**Current header** (`gaps.ex:64-72`):
```elixir
<.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
  <.kb_nav current={:gaps} />
  <header class="cl-mb-7">
    <h1>Knowledge gaps</h1>
    <p class="cl-text-muted">Ranked maintenance signals from retrieval misses, weak grounding,
      and repeated manual handling.</p>
  </header>
  <.cl_card>...gap candidates...</.cl_card>
```
→ `<.cl_page title="Knowledge gaps" subtitle="Ranked maintenance signals ...">` ;
`<:subnav><.kb_nav current={:gaps} /></:subnav>` ; gap cards in body. (Per CONTEXT discretion: include
gaps as the explicit 5th KB screen.) **No breadcrumb** (gaps is a lane index, not a detail screen).

### `suggestion_review.ex` (KB; `:subnav`=kb_nav, NEW `:breadcrumb` — SHELL-02 D-01)
**Current header** (`suggestion_review.ex:188-196`):
```elixir
<.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations()}>
  <.kb_nav current={:suggestions} />
  <header class="cl-mb-7">
    <h1>Suggestion review</h1>
    <p class="cl-text-muted">Inspect grounded KB proposals before any manual editing
      or later publish workflow begins.</p>
  </header>
  <.cl_card>...suggestion filters...</.cl_card>  # filter card stays in body
  ...queue table + detail cards...
```
→ `<.cl_page title="Suggestion review" subtitle="Inspect grounded KB proposals ...">` with:
- `<:subnav><.kb_nav current={:suggestions} /></:subnav>`
- `<:breadcrumb>` = **NEW** static/lane crumb (has none today):
  `[%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Suggestions"}]` (current crumb no href).
  Available lane signals: `@queue_filter`, `@selected_task`; helpers `task_patch/2` (`:461`),
  `queue_patch/2` (`:466`) already in module. **Do NOT invent a conversation→suggestion_review handoff
  (none exists — that's P42).**
- filter card + queue + detail cards stay in body.

---

## Shared Patterns

### Breadcrumb-items builder (NEW — the only new code)
**Analog (structural):** `lib/cairnloop/web/audit_log_presenter.ex:1-48` — a pure, total presenter
module: docstring states "Total functions with safe fallbacks ... Returns strings and atoms only —
never markup, never raw Elixir terms." Header-comment cross-references sibling presenters
(`ToolProposalPresenter`/`ReviewTaskPresenter`). The new `Cairnloop.Web.BreadcrumbPresenter` should
mirror this module shape: moduledoc, pattern-matched total functions, no Repo, returns data (the
`items` list), never markup.

**Apply to:** `editor.ex` `:breadcrumb` slot, `suggestion_review.ex` `:breadcrumb` slot.

**Recommended pure functions (research §(d), §Code Examples — Claude's discretion on labels):**
```elixir
def editor_items(return_to, title) when is_binary(return_to) do
  origin = if String.starts_with?(return_to, "/knowledge-base"), do: "Suggestions", else: "Conversation"
  [%{label: origin, href: return_to},
   %{label: "Knowledge", href: "/knowledge-base"},
   %{label: "Editing: #{title}"}]          # last: NO :href => current crumb
end
def editor_items(_return_to, title) do      # nil return_to => static fallback (≥2 crumbs still)
  [%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: #{title}"}]
end
```
**Contract enforced (Pitfall 2):** every non-last crumb has `href:`; the last map OMITS `href:`.

### Origin-label derivation (copy rule + security V5)
**Apply to:** `BreadcrumbPresenter.editor_items/2`. Derive the human label from `return_to` PATH SHAPE,
NEVER from `@review_origin?` (Pitfall 1: `review_origin? = review_task != nil` at `editor.ex:30` is
true for ANY review-lane open, not a conversation signal). NEVER render the raw `/42` path as visible
text (brand copy rule "never raw terms/paths to operators"; avoids reflecting an attacker-influenced
path — V5). `/knowledge-base...` ⇒ "Suggestions"; anything else ⇒ "Conversation".

### Slot-mapping consistency (D-04) — applies to ALL screens
- `<.kb_nav current={…}/>` ⇒ `:subnav` (KB screens only). **Note:** kb_nav currently renders ABOVE
  the h1; in `cl_page` `:subnav` renders BELOW the header (`components.ex:342`). This reorder is
  INTENTIONAL (Pitfall 5) — document for the P45 screenshot diff so it isn't read as a regression.
- single primary button ⇒ `:actions` (Settings toggle, KB-Index "New article" only).
- substantial filter/search bars ⇒ STAY in body (Audit Log card-header filter, Inbox controls,
  Suggestion-review filter card). Do NOT cram into `:actions`.
- breadcrumb ⇒ `:breadcrumb` slot (editor: move existing; suggestion_review: new).

### Verbatim-title / pure-structural-lift (D-05) — applies to ALL screens
Title text carried verbatim from each current `<h1>`; subtitle `<p class="cl-text-muted">` ⇒
`subtitle=` (renders `cl-page__subtitle`). Move the body wholesale into `inner_block`; do NOT
retheme/rewrite body markup (keep the editor 2-col grid's token-based `style=` at `:294` as-is).

### Build/test gates (CLAUDE.md) — applies to ALL screens
After EACH screen: `mix compile --warnings-as-errors` (Pitfall 3: watch orphaned assigns / only the
4 declared slots) + `mix test test/cairnloop/web/<screen>_test.exs`. Headless render harness
(`Module.render(assigns) |> rendered_to_string()`) already exists on every screen — extend, don't
create. Brand-token gate (`test/cairnloop/web/brand_token_gate_test.exs`) must stay green (no hex
fallback reintroduced). Mark any genuinely Repo-needing assertion `# REPO-UNAVAILABLE` (none expected).

---

## No Analog Found

None. Every change has a verified in-repo analog (the primitive itself for page-shell wraps; the
editor's existing `cl_breadcrumb` call for breadcrumbs; `audit_log_presenter.ex` for the new
presenter). This is a pure-adoption phase — no novel role/data-flow combinations.

## Metadata

**Analog search scope:** `lib/cairnloop/web/` (LiveView screens, `components.ex`, presenters),
`lib/cairnloop/web/knowledge_base_live/` (KB sub-screens, nav_component), the conversation handoff
producer.
**Files scanned:** 10 read in full/targeted ranges + grep verification of imports & patch helpers.
**Pattern extraction date:** 2026-06-03
