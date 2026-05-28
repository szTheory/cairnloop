# Phase 30: KB Editorial Polish + T-10-09 / T-10-11 Closure - Research

**Researched:** 2026-05-28
**Domain:** Phoenix LiveView UI cohesion + signed-token/DB editor-handoff security gate (Elixir/Phoenix/Ecto)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**HandoffToken gate (T-10-09 + T-10-11 closure — SEC-01, SEC-02)**

- **D-01:** Use the **double-layer gate**: (1) DB write — `SuggestionReview.open_for_manual_edit` calls `knowledge_automation().record_editor_handoff(suggestion_id, scope_filters)` to write `suggestion.manual_edit_opened_at = DateTime.utc_now()` to the DB (auditable timestamp — closes T-10-09); (2) signed-token assertion — `manual_edit_opened_at` as ISO8601 string is included in the signed `EditorHandoff` token payload; `verify!/2` rejects tokens that lack it (closes T-10-11).
- **D-02:** Add `Token.decode(token) :: {:ok, payload} | {:error, reason}` to the domain `Cairnloop.KnowledgeAutomation.EditorHandoff` module. Purely additive — existing `verify/2` is **unchanged** and backward-compat. `Token.decode/1` calls `Plug.Crypto.verify` and returns the decoded payload map on success.
- **D-03:** Web `EditorHandoff.verify!/2` is extended to a three-step pipeline: (1) `Token.decode(token)` → `{:ok, payload}`; (2) `assert_handoff_marker(payload)` — checks `payload["manual_edit_opened_at"]` is a non-nil, non-empty binary string → `:ok | {:error, :missing_handoff_marker}`; (3) assert attrs match against the **already-decoded payload** (no second `Plug.Crypto.verify` — avoid double-decode). Raises `Ecto.NoResultsError, queryable: Article` on any failure (existing contract unchanged).
- **D-04:** `EditorHandoff.sign` in the web module gets **keyword opts**: `sign(suggestion_id, article_id, review_task_id, return_to, opts \\ [])`. Only `SuggestionReview.open_for_manual_edit` passes `[manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()]`. Existing call sites without opts continue to work unchanged.
- **D-05:** Domain function name for writing the DB timestamp: `KnowledgeAutomation.record_editor_handoff(suggestion_id, scope_filters)`. Distinct from `mark_review_task_material_edit/2` (fires on draft save, not on editor open).
- **D-06:** Gate failure in `Editor.mount/3`: rescue the `Ecto.NoResultsError` raised by `verify!/2` (or any error from `load_suggestion/3`) → `put_flash(:error, <exact UI-SPEC copy>)` + `push_navigate(socket, to: "/knowledge-base/suggestions")`. Never a 500 page. Never raw Elixir terms. **Exact flash copy:** "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."

**Gap sidebar data source (KB-03)**

- **D-07:** Derive `gap_candidate` from the suggestion record in `Editor.mount/3` — **no token or URL changes** for `gap_candidate_id`. After `load_suggestion/3` succeeds, call `load_gap_candidate_from_suggestion(suggestion, scope_filters)` matching on `{suggestion.entrypoint_type, suggestion.entrypoint_id}` → `{:gap_candidate, id}` when `is_integer(id)` → `knowledge_automation().get_gap_candidate(id, scope_filters)` (non-bang). **This overrides the UI-SPEC's mention of `EditorHandoff.sign/4` gaining a `gap_candidate_id` field** — the `ArticleSuggestion` schema already encodes this relationship.
- **D-08:** `Editor.mount/3` gains `assign(socket, :gap_candidate, gap_candidate)`. Template condition: `<%= if @gap_candidate do %>`. The sidebar is read-only; no event handlers.

**Index architecture fix (KB-01, KB-02)**

- **D-09:** Add `KnowledgeBase.list_articles(opts \\ [])` to the `KnowledgeBase` facade. Article schema has no tenant fields today, so scope_filters opts are accepted but currently ignored (reserved). Include `:status` filter support.
- **D-10:** `KnowledgeBase.Index.mount/3` changes from `repo().all(Article)` to `KnowledgeBase.list_articles(scope_filters)`.

**Auto-decided (recorded for downstream agents)**

- **D-11:** Nav shell lives in a dedicated module `Cairnloop.Web.KnowledgeBaseLive.NavComponent` with `def kb_nav/1`. Each KB LiveView calls `<.kb_nav current={:index} />` (or `:editor`, `:suggestions`, `:gaps`).
- **D-12:** "New article" button: single `"new_article"` event on `KnowledgeBase.Index` → `KnowledgeBase.create_article(%{title: "Untitled article", status: :draft})` → `push_navigate(socket, to: "/knowledge-base/#{article.id}/edit")`. Error: `put_flash(:error, "Unable to create the article right now. Try again.")`.
- **D-13:** "Open for manual edit" copy variants live in **`ReviewTaskPresenter.action_label/2`** — keep the presenter-first pattern. Update the presenter to return the 3-variant copy from UI-SPEC §KB-04.
- **D-14:** T-10-10 / T-10-12 / T-10-13 remain **deferred to vM015** (domain layer, `knowledge_automation.ex`).

### Claude's Discretion

(No explicit "Claude's Discretion" section in CONTEXT.md — all 14 decisions were pre-ratified. Remaining discretion areas: test-file layout, exact private-helper naming, render-markup ordering within HEEx, and which existing mock pattern to reuse. These are addressed in the research below.)

### Deferred Ideas (OUT OF SCOPE)

- T-10-10 / T-10-12 / T-10-13 — domain-layer threats in `knowledge_automation.ex`. Deferred to vM015.
- `Article` tenant isolation (adding `host_user_id` / `tenant_scope` fields) — reserved for future milestone; `list_articles/1` opts are already wired for it.
- Centralize duplicated fail-closed search guards — carried from vM009; out of scope for Phase 30.
- Adding `gap_candidate_id` to the token payload (UI-SPEC §KB-03 original wording) — overridden by D-07.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| KB-01 | Shared editorial nav shell across all 4 KB routes (`Index`, `Editor`, `SuggestionReview`, `Gaps`) | New `NavComponent.kb_nav/1` function component (D-11); all 4 LiveViews are library modules in `lib/cairnloop/web/knowledge_base_live/`, rendered by the example app router. Pattern: Phoenix function component with `attr :current`. See Architecture Patterns Pattern 1. |
| KB-02 | `KnowledgeBase.Index` shows explicit "New article" affordance (button + route) | `KnowledgeBase.create_article/1` already exists ([knowledge_base.ex:65](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex)). New `"new_article"` event → create → `push_navigate` to existing `/knowledge-base/:id/edit` route (D-12). No new route needed. |
| KB-03 | `Editor` shows "View source gap" sidebar when opened from a `GapCandidate` handoff | `ArticleSuggestion.entrypoint_type`/`entrypoint_id` already encode the relationship ([article_suggestion.ex:29-30](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex)). Need new non-bang `get_gap_candidate/2` facade fn (D-07). `get_gap_candidate!/2` exists at [knowledge_automation.ex:52](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex) as the model. |
| KB-04 | `SuggestionReview` "Open for manual edit" calm, reason-forward copy; never leaks raw Elixir terms | Copy lives in `ReviewTaskPresenter.action_label/2` ([review_task_presenter.ex:200-208](/Users/jon/projects/cairnloop/lib/cairnloop/web/review_task_presenter.ex)). Already presenter-driven; extend the 1-variant current logic to the 3 UI-SPEC variants (D-13). |
| SEC-01 | `EditorHandoff.verify!/2` requires `manual_edit_opened_at` marker before Editor preload of `proposed_markdown` | Double-layer gate (D-01..D-04). `manual_edit_opened_at` DB field already exists on `ArticleSuggestion` ([article_suggestion.ex:41](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex)). Token currently has NO such field — must be added to `sign` opts + `decode` + `verify!` pipeline. |
| SEC-02 | Editor preload requires the SEC-01 marker, not a bare URL `suggestion_id` | Same gate as SEC-01. Editor's `load_suggestion/3` already calls `EditorHandoff.verify!/2` before preloading ([editor.ex:94-100](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex)); Phase 30 strengthens that gate so a bare `suggestion_id` without a marker-bearing token fails closed. |
</phase_requirements>

## Summary

Phase 30 is a **brownfield Elixir/Phoenix-LiveView phase with zero new dependencies**. Every capability lands by adding new functions or optional opts to existing modules — no packages to install, no migrations, no new schema fields (the `manual_edit_opened_at` column and the `entrypoint_type`/`entrypoint_id` relationship already exist). The two security threats close via a "double-layer" handoff gate: a durable DB timestamp (auditable — closes T-10-09) plus a signed-token field assertion (deliberate handoff state — closes T-10-11). The four UI requirements are presentational cohesion: a shared nav function component, a create-article button, a read-only gap-evidence sidebar, and calm presenter-driven button copy.

The codebase is unusually well-factored for this work. The exact patterns Phase 30 must follow already exist in-tree: `EditorHandoff.verify/2` is the integrity-check primitive to wrap; `KnowledgeAutomation.list_gap_candidates(opts \\ [])` + `get_gap_candidate!/2` are the templates for the new `list_articles/1` and non-bang `get_gap_candidate/2`; `ReviewTaskPresenter.action_label/2` already does single-variant copy switching that just needs expanding; and the LiveView test suite uses an established Mock-injection pattern (`Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)`) that lets every behavior be tested **without a live Repo** — critical given the CLAUDE.md `Cairnloop.Repo`-unavailable caveat.

The single highest-risk area is the `verify!/2` rewrite (D-03): it must avoid a double `Plug.Crypto.verify` call, must keep raising `Ecto.NoResultsError` so the existing fail-closed contract is byte-compatible, and must thread a new `manual_edit_opened_at` field through `sign` → `normalize` → `decode` → `verify`. Because the token payload shape is changing (a new key), **any handoff tokens signed before deploy become invalid** — acceptable here because tokens are short-lived (`@max_age 1800` = 30 min) and only minted at "open for manual edit" click time.

**Primary recommendation:** Implement as ~4 plans: (1) domain+web `EditorHandoff` gate (SEC-01/SEC-02) + `record_editor_handoff/2` + `get_gap_candidate/2` + `list_articles/1` facade additions; (2) `NavComponent.kb_nav/1` + wire into all 4 LiveViews (KB-01); (3) Index new-article button/event + `list_articles` switch (KB-02) and Editor gap sidebar + mount rescue (KB-03, SEC-01/SEC-02 wiring); (4) `ReviewTaskPresenter` copy variants (KB-04). Order matters: the facade/gate plan (1) must land before the LiveView plans that call it. All render code uses bare `var(--cl-<token>)` (no hex fallbacks) per the Phase 29 BRAND-04 gate.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Handoff token sign/verify integrity (`Plug.Crypto`) | Domain (`KnowledgeAutomation.EditorHandoff`) | — | Integrity verification is a domain primitive — policy-agnostic, mirrors Phoenix.Token/Guardian/Joken |
| Handoff semantic assertions (marker present, attrs match) | Web wrapper (`Web.KnowledgeBaseLive.EditorHandoff`) | — | Product assertions belong at the web boundary; domain stays policy-free (D-02) |
| Auditable handoff DB write (`manual_edit_opened_at`) | Domain facade (`KnowledgeAutomation.record_editor_handoff/2`) | Database/Storage | Workflow truth is durable Ecto records (CLAUDE.md); writes go through the facade, never from web layer |
| Gap-candidate read for sidebar | Domain facade (`KnowledgeAutomation.get_gap_candidate/2`) | Web (`Editor` render) | Arch invariant #5: web layer reads through the facade, never direct `Repo` queries |
| Article list read for Index | Domain facade (`KnowledgeBase.list_articles/1`) | Web (`Index` render) | Same arch invariant #5 — replaces the current `repo().all(Article)` violation in `Index.mount/3` |
| New-article creation | Domain facade (`KnowledgeBase.create_article/1`, exists) | Web (`Index` event) | Write through the facade; web only orchestrates event → facade → navigate |
| Nav shell rendering | Web (`NavComponent` function component) | — | Pure presentation; no state, no events, no domain reads |
| Operator-facing copy (button labels, flash) | Web presenters (`ReviewTaskPresenter`) | — | Brand §5.5: never inline raw atoms; presenter layer owns all operator text |
| Markdown → HTML preview | Web (`Editor`, via `Earmark`) | — | Existing; unchanged in Phase 30 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | `~> 1.0` (1.1.x installed) | All 4 KB surfaces are LiveViews; nav shell is a function component | Already the project's web layer [VERIFIED: mix.exs:89] |
| `phoenix` | 1.8.7 (resolved) | Pulls `plug_crypto` transitively; supplies `Phoenix.Component`/`~H` for the nav function component | [VERIFIED: mix.lock] |
| `plug_crypto` | 2.1.1 (resolved) | `Plug.Crypto.sign/4` + `Plug.Crypto.verify/4` back the signed handoff token | Already used by `EditorHandoff` [VERIFIED: mix.lock; editor_handoff.ex:8,14] |
| `ecto_sql` | `~> 3.10` | `ArticleSuggestion` schema + `record_editor_handoff` DB write | [VERIFIED: mix.exs:84] |
| `earmark` | 1.4.48 (resolved) | Markdown → HTML for the editor preview pane (unchanged this phase) | [VERIFIED: mix.lock] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| daisyUI (vendored) | latest (vendored `@plugin "../vendor/daisyui"`) | Component primitives in the example app's Tailwind build | New render markup may use daisyUI classes; brand tokens take precedence (UI-SPEC) [VERIFIED: examples/.../app.css:105] |
| Heroicons (vendored) | vendored `@plugin "../vendor/heroicons"` | `hero-*` icon classes | Only if an icon is added; Phase 30 components are text-labeled (UI-SPEC: no icon-only buttons) [VERIFIED: examples/.../app.css:100] |
| `lazy_html` | `>= 0.1.0` (test only) | `Phoenix.LiveViewTest` HTML parsing for element/form helpers | Already present; use for any new LiveView render assertions [VERIFIED: mix.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Double-layer (DB + token) gate | Token-only OR DB-only | Token-only leaves no audit record (fails T-10-09 intent); DB-only lets a forged URL still preload before the write is checked. D-01 uses both — locked. |
| New `get_gap_candidate/2` non-bang fn | `rescue Ecto.NoResultsError -> nil` around `get_gap_candidate!/2` | D-07 names a dedicated non-bang fn as primary; rescue is the documented fallback. Dedicated fn is clearer and avoids exception-as-control-flow. |
| `NavComponent` dedicated module | `defp kb_nav/1` in a shared helper | D-11 locks the dedicated module. Dedicated module is more discoverable and testable in isolation. |

**Installation:**
```bash
# No new dependencies. Phase 30 adds functions/opts to existing modules only.
```

**Version verification:** All versions above were read from `mix.lock` (resolved) and `mix.exs` (constraints) in this session — no registry lookups required because no packages are being added.

## Package Legitimacy Audit

> **Not applicable.** Phase 30 installs **zero** external packages. All work is additive functions/opts on existing in-tree modules. No `mix deps.get`, no registry fetch, no new entry in `mix.exs`/`mix.lock`.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | N/A — no installs this phase |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Project Constraints (from CLAUDE.md)

These directives carry locked-decision authority. Research must not recommend approaches that contradict them.

1. **Warnings-clean builds are mandatory** — code must pass `mix compile --warnings-as-errors`. New functions with `opts \\ []` defaults: ensure no unused-variable warnings (prefix unused with `_`).
2. **Run `mix test` before declaring done** — report failures honestly.
3. **`Cairnloop.Repo` may be unavailable in this workspace** — prefer headless/pure tests (presenters, total functions, Mock-injected LiveViews). Tests needing a real Postgres round-trip get a `# REPO-UNAVAILABLE` note. Some focused runs emit `*.Repo` boot noise — pre-existing baseline, not a regression.
4. **Durable Ecto records + events are workflow truth; `:telemetry` is observability only** — the `manual_edit_opened_at` DB write is the auditable truth, not a telemetry event.
5. **New reads go through the narrow facade, not direct schema queries from the web layer** — this is the entire reason for D-09/D-10 (`list_articles/1`) and D-07 (`get_gap_candidate/2`). The current `Index.mount/3` `repo().all(Article)` is the violation being fixed.
6. **Snapshot trust facts at decision time; never re-read live config at render time** — the gap sidebar reads the suggestion's already-loaded `entrypoint_id` (decision-time snapshot), not a live re-query of policy.
7. **Seal completed phases — don't churn sealed code paths; prefer additive changes** — `EditorHandoff.verify/2` (domain), `Token.sign/1`, and existing `sign/4` call sites stay backward-compatible. New behavior arrives via `decode/1`, `verify!/2` rewrite (web wrapper only), and `sign/5` opts.
8. **Operator copy is calm, fail-closed, reason-forward, honest — never raw Elixir terms / raw JSON; never state-by-color-alone (brand §7.5).**
9. **Brand tokens over hardcoded hex.** Note: CLAUDE.md still shows the *old* `var(--cl-primary, #A94F30)` form, but Phase 29 BRAND-04 supersedes it — **new render code uses bare `var(--cl-primary)`** with NO hex fallback (see Common Pitfalls Pitfall 4).

## Architecture Patterns

### System Architecture Diagram

```
                     ┌─────────────────────────────────────────────────┐
                     │ Example app router (examples/.../router.ex)       │
                     │ mounts LIBRARY KB LiveView modules at /knowledge- │
                     │ base, /gaps, /suggestions, /:id/edit              │
                     └───────────────┬─────────────────────────────────┘
                                     │ renders
        ┌────────────────────────────┼────────────────────────────┐
        ▼                ▼            ▼              ▼              ▼
   ┌─────────┐    ┌────────────┐ ┌──────────┐ ┌──────────────┐  (shared)
   │ Index   │    │SuggestionRv│ │ Gaps     │ │ Editor       │ ┌──────────────┐
   │(KB-01,02│    │(KB-01, 04, │ │(KB-01)   │ │(KB-01,03,    │ │ NavComponent │
   │ list_   │    │ open_for_  │ │          │ │ SEC-01/02)   │ │ .kb_nav/1    │
   │ articles│    │ manual_edit│ │          │ │              │ │ <.kb_nav     │
   └────┬────┘    └─────┬──────┘ └────┬─────┘ └──────┬───────┘ │  current=…/> │
        │               │             │              │         └──────────────┘
        │ create_article│ sign(...,   │              │ verify!(params, id)
        │ list_articles │  opts: m_e_  │              │   ├─ Token.decode/1 ──┐
        │               │  opened_at)  │              │   ├─ assert_handoff_   │
        │               │ record_      │              │   │   marker(payload)  │
        │               │  editor_     │              │   └─ assert attrs vs   │
        │               │  handoff/2   │              │       decoded payload  │
        ▼               ▼  (DB write)  │              │ load_gap_candidate_    │
   ┌────────────────────────────────────────────────▼──from_suggestion/2     │
   │ FACADES (Governance/arch-invariant #5 boundary)                          │
   │  KnowledgeBase: list_articles/1*, create_article/1, get_article/1        │
   │  KnowledgeAutomation: record_editor_handoff/2*, get_gap_candidate/2*,    │
   │                       get_article_suggestion!/2, get_gap_candidate!/2    │
   │  (* = new in Phase 30)                                                   │
   └───────────────────────────────┬─────────────────────────────────────────┘
                                    │ Ecto
                     ┌──────────────▼──────────────┐
                     │ Postgres: cairnloop_articles,│
                     │ cairnloop_article_suggestions│
                     │ (manual_edit_opened_at col   │
                     │  ALREADY EXISTS),            │
                     │ cairnloop_gap_candidates     │
                     └──────────────────────────────┘

   Domain primitive (policy-free):
   ┌──────────────────────────────────────────────────────────────┐
   │ KnowledgeAutomation.EditorHandoff (domain)                     │
   │  sign(attrs)  → Plug.Crypto.sign  (existing, +marker via map)  │
   │  verify(token, attrs) → Plug.Crypto.verify (existing UNCHANGED)│
   │  decode(token)* → {:ok, payload} | {:error, reason}   (NEW)    │
   │  normalize(attrs) (extend to carry manual_edit_opened_at)      │
   └──────────────────────────────────────────────────────────────┘
```

The "open for manual edit" trace: operator clicks button in `SuggestionReview` → `record_editor_handoff/2` writes the DB timestamp → `EditorHandoff.sign(.., opts: [manual_edit_opened_at: iso8601])` mints a token carrying the marker → `push_navigate` to Editor with `?handoff=<token>` → `Editor.mount/3` → `load_suggestion/3` → `EditorHandoff.verify!/2` decodes once, asserts the marker is present, asserts attrs match → only then preloads `proposed_markdown`. A bare `suggestion_id` URL with no marker-bearing token raises → rescued → calm flash + redirect.

### Recommended Project Structure

```
lib/cairnloop/
├── knowledge_base.ex                       # + list_articles(opts \\ [])  [D-09]
├── knowledge_automation.ex                 # + record_editor_handoff/2 [D-05], get_gap_candidate/2 [D-07]
├── knowledge_automation/
│   ├── editor_handoff.ex                   # + decode/1 [D-02], normalize carries marker [D-04]
│   └── article_suggestion.ex               # UNCHANGED (manual_edit_opened_at already present)
└── web/
    ├── review_task_presenter.ex            # action_label/2 → 3 copy variants [D-13]
    └── knowledge_base_live/
        ├── nav_component.ex                # NEW: kb_nav/1 function component [D-11]
        ├── editor_handoff.ex              # sign/5 opts [D-04], verify!/2 3-step pipeline [D-03]
        ├── index.ex                        # kb_nav, new_article event, list_articles [D-10,11,12]
        ├── editor.ex                       # kb_nav, gap_candidate assign, mount rescue [D-06,07,08,11]
        ├── suggestion_review.ex            # kb_nav, record_editor_handoff + sign opts [D-01,11]
        └── gaps.ex                         # kb_nav only [D-11]

test/cairnloop/
├── web/review_task_presenter_test.exs      # NEW (pure) — 3 copy variants [KB-04]
└── web/knowledge_base_live/
    ├── nav_component_test.exs              # NEW (pure render) — active marker, aria-current [KB-01]
    ├── editor_handoff_test.exs            # exists/extend — decode/1, verify!/2 marker gate [SEC-01/02]
    ├── editor_test.exs / knowledge_base_live_test.exs  # extend — gate failure flash, gap sidebar
    └── suggestion_review_test.exs          # extend — record_editor_handoff called, sign carries marker
```

### Pattern 1: Phoenix function component (the nav shell — KB-01)

**What:** A stateless `~H` function component with a typed `attr`, defined once and called in all 4 LiveViews.
**When to use:** Shared presentational markup with no events/state — exactly the nav shell.
**Example:**
```elixir
# Source: Phoenix.Component (CITED: hexdocs.pm/phoenix_live_view/Phoenix.Component.html)
defmodule Cairnloop.Web.KnowledgeBaseLive.NavComponent do
  use Phoenix.Component

  attr :current, :atom, required: true  # :index | :editor | :suggestions | :gaps

  def kb_nav(assigns) do
    ~H"""
    <nav aria-label="Knowledge base"
         style="background: var(--cl-surface); border-bottom: 1px solid var(--cl-border);
                padding: 0 24px; height: 48px; display: flex; align-items: center; gap: 8px;">
      <.kb_nav_link to="/knowledge-base" label="Knowledge base" active={@current == :index} />
      <.kb_nav_link to="/knowledge-base/suggestions" label="Suggestions" active={@current == :suggestions} />
      <.kb_nav_link to="/knowledge-base/gaps" label="Gaps" active={@current == :gaps} />
    </nav>
    """
  end

  attr :to, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp kb_nav_link(assigns) do
    ~H"""
    <.link navigate={@to}
           aria-current={if @active, do: "page"}
           style={"padding: 12px 16px; font-size: 13px; font-weight: 600; text-decoration: none;
                   border-bottom: 2px solid #{if @active, do: "var(--cl-primary)", else: "transparent"};
                   color: #{if @active, do: "var(--cl-text)", else: "var(--cl-text-muted)"};"}>
      <%= @label %>
    </.link>
    """
  end
end
```
Each LiveView calls it as `<.kb_nav current={:index} />` after `import Cairnloop.Web.KnowledgeBaseLive.NavComponent` (or via `Phoenix.Component` import). Note: `:editor` is not in the nav link set (per UI-SPEC labels: only Knowledge base / Suggestions / Gaps) — `current={:editor}` simply renders no active marker, which is correct since the Editor has no top-level nav entry.

### Pattern 2: Wrap an integrity primitive, assert semantics at the web boundary (SEC-01/SEC-02)

**What:** Domain `decode/1` verifies the signature and returns the raw payload; the web wrapper asserts product rules against the decoded map (single decode, no re-verify).
**When to use:** Any signed-token gate — mirrors Phoenix.Token/Guardian/Joken.
**Example:**
```elixir
# Domain — Cairnloop.KnowledgeAutomation.EditorHandoff  [D-02]
# Source: in-tree existing verify/2 (editor_handoff.ex:11) is the model
def decode(token) do
  Plug.Crypto.verify(secret_key_base(), @salt, token, max_age: @max_age)
  # returns {:ok, payload_map} | {:error, reason}
end

# normalize/1 must also carry the marker so signed tokens include it  [D-04]
defp normalize(attrs) do
  %{
    "article_id" => normalize_integer(get(attrs, :article_id)),
    "review_task_id" => normalize_integer(get(attrs, :review_task_id)),
    "return_to" => get(attrs, :return_to),
    "suggestion_id" => normalize_integer(get(attrs, :suggestion_id)),
    "manual_edit_opened_at" => get(attrs, :manual_edit_opened_at)  # NEW (nil when absent)
  }
end
```
```elixir
# Web wrapper — Cairnloop.Web.KnowledgeBaseLive.EditorHandoff  [D-03, D-04]
def sign(suggestion_id, article_id, review_task_id, return_to, opts \\ []) do
  Token.sign(%{
    suggestion_id: suggestion_id,
    article_id: article_id,
    review_task_id: review_task_id,
    return_to: return_to,
    manual_edit_opened_at: Keyword.get(opts, :manual_edit_opened_at)
  })
end

def verify!(params, article_id) do
  expected = normalized_attrs(params, article_id)  # same shape normalize/1 produces

  with {:ok, payload} <- Token.decode(Map.get(params, "handoff")),
       :ok <- assert_handoff_marker(payload),
       true <- payload == expected do
    :ok
  else
    _ -> raise Ecto.NoResultsError, queryable: Article  # existing contract — UNCHANGED
  end
end

defp assert_handoff_marker(%{"manual_edit_opened_at" => v}) when is_binary(v) and v != "", do: :ok
defp assert_handoff_marker(_), do: {:error, :missing_handoff_marker}
```
**Critical:** step 3 compares against the *already-decoded* `payload` (no second `Token.verify/2`, which would call `Plug.Crypto.verify` a second time — D-03 explicitly forbids the double-decode).

### Pattern 3: Optional `opts \\ []` facade additions mirroring existing list functions (KB-02/KB-03/D-09)

**What:** New facade functions accept `opts \\ []` and pipe through the existing `apply_scope/2` + `maybe_filter_status/2` helpers.
**When to use:** Every new read added to the facade — keeps the arity stable for future tenant fields.
**Example:**
```elixir
# Cairnloop.KnowledgeBase  [D-09] — mirrors KnowledgeAutomation.list_gap_candidates/1 (knowledge_automation.ex:40)
def list_articles(opts \\ []) do
  Article
  |> maybe_filter_article_status(opts)   # :status filter; scope opts accepted but no-op (no tenant fields yet)
  |> order_by([a], desc: a.inserted_at, desc: a.id)
  |> repo().all()
end

defp maybe_filter_article_status(query, opts) do
  case Keyword.get(opts, :status, :all) do
    :all -> query
    nil -> query
    status -> where(query, [a], a.status == ^status)
  end
end
```
```elixir
# Cairnloop.KnowledgeAutomation  [D-07] — non-bang sibling of get_gap_candidate!/2 (knowledge_automation.ex:52)
def get_gap_candidate(id, opts \\ []) do
  get_gap_candidate!(id, opts)
rescue
  Ecto.NoResultsError -> nil
end
```
Note `KnowledgeBase` will need `import Ecto.Query` (already imported at [knowledge_base.ex:2]).

### Pattern 4: DB write through the facade returning a tagged tuple (SEC-01 / D-05)

**What:** `record_editor_handoff/2` loads the suggestion, updates `manual_edit_opened_at`, returns `{:ok, suggestion} | {:error, reason}`.
**When to use:** The auditable DB half of the gate.
**Example:**
```elixir
# Cairnloop.KnowledgeAutomation  [D-05] — model: create_or_reuse_authoring_article_for_suggestion/2 (knowledge_automation.ex:551)
def record_editor_handoff(suggestion_id, opts \\ []) do
  suggestion = get_article_suggestion!(suggestion_id, opts)

  suggestion
  |> ArticleSuggestion.changeset(%{manual_edit_opened_at: now_fn(opts).()})
  |> repo().update()
end
```
`now_fn(opts)` is the existing time-injection helper at [knowledge_automation.ex:1663] — reuse it so tests can pin the timestamp. Caution: `ArticleSuggestion.changeset/2` re-runs `validate_required` over many fields — confirm the loaded suggestion already satisfies them (it will, since it was persisted). If a narrow update changeset is cleaner, add a dedicated `manual_edit_changeset/2` to the schema (additive). **Decision (Claude's discretion):** prefer a dedicated `manual_edit_changeset/2` to avoid re-validating unrelated fields and to keep the write intent explicit — this is the safer additive path.

### Anti-Patterns to Avoid

- **Double-decode in `verify!/2`:** Calling `Token.decode/1` then `Token.verify/2` runs `Plug.Crypto.verify` twice. D-03 forbids it — assert attrs against the already-decoded payload map.
- **Putting `gap_candidate_id` in the token:** Overridden by D-07. The suggestion already carries the relationship; duplicating it blends attestation with data transport.
- **Direct `repo().all(Article)` in the web layer:** The current `Index.mount/3` violation. Must route through `list_articles/1` (arch invariant #5).
- **Inline hex fallback in new render code:** `var(--cl-primary, #A94F30)` is forbidden by the Phase 29 BRAND-04 gate. Use bare `var(--cl-primary)`.
- **Raw atoms/struct repr in operator copy:** e.g. rendering `:needs_manual_edit` or `inspect(suggestion)`. All operator text flows through presenters (brand §5.5).
- **Amending the sealed domain `verify/2`:** The domain `verify/2` and `sign/1` stay backward-compatible. Changes are additive (`decode/1`, extended `normalize/1` carrying a nil-default key).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Signed, expiring handoff token | Custom HMAC + base64 + timestamp parsing | `Plug.Crypto.sign/4` + `Plug.Crypto.verify/4` (already in `EditorHandoff`) | Constant-time compare, key derivation, max-age enforcement handled correctly; SECURITY.md notes the marker is "simpler than HMAC" precisely because the token infra already exists |
| Markdown → HTML for preview | Regex/string munging | `Earmark.as_html!/1` (already used at editor.ex:85) | XSS-safe-ish, CommonMark coverage; unchanged this phase |
| Scope filtering on facade reads | Hand-written `where` per call site | `apply_scope/2` + `maybe_filter_status/2` helpers (knowledge_automation.ex:1940) | Consistent tenant semantics; `list_articles/1` should mirror them even though Article has no tenant fields yet |
| Time injection for tests | `DateTime.utc_now()` inline | `now_fn(opts)` helper (knowledge_automation.ex:1663) | Lets headless tests pin timestamps without a clock |
| LiveView render assertions | Manual string slicing | `Phoenix.LiveViewTest` + `lazy_html` element helpers | Already the project's test idiom across 9+ integration tests |

**Key insight:** Phase 30 is almost entirely *composition of existing primitives*. The only genuinely new logic is the three-step `verify!/2` pipeline and the `assert_handoff_marker/1` predicate — everything else is wiring functions that already exist.

## Runtime State Inventory

> Phase 30 is **additive UI + a security gate, not a rename/refactor/migration**. There are no string renames, no datastore key changes, and no new DB columns (the column exists). This section is included for completeness because SEC-01 introduces a new *token payload shape*, which has a runtime-state implication.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `cairnloop_article_suggestions.manual_edit_opened_at` column **already exists** ([article_suggestion.ex:41]); no schema migration. Existing rows have `manual_edit_opened_at = NULL` until first "open for manual edit" — correct (no prior handoff occurred). | None — column present; `record_editor_handoff/2` populates on first open. |
| Live service config | None — KB surfaces are in-repo LiveViews mounted by the example app router; no external service holds handoff state. | None — verified: routes are static in both `lib/.../router.ex:22-25` and `examples/.../router.ex:22-25`. |
| OS-registered state | None. No OS-level registration touches KB editing. | None — verified by absence. |
| Secrets/env vars | `EditorHandoff` secret key: `Application.get_env(:cairnloop, EditorHandoff)[:secret_key_base]`, falling back to a per-node random in `:persistent_term` ([editor_handoff.ex:47-65]). **Token payload shape change (adding `manual_edit_opened_at`) means tokens minted before deploy fail `verify!/2` after deploy.** | None blocking — tokens are short-lived (`@max_age 1800` = 30 min) and only exist between "open for manual edit" click and Editor mount. Note this in the plan as expected behavior, not a regression. |
| Build artifacts | None — no `*.egg-info`, no compiled artifacts carrying renamed strings. New modules compile into `_build` normally. | None — `mix compile --warnings-as-errors` covers it. |

## Common Pitfalls

### Pitfall 1: Token payload shape change invalidates in-flight tokens
**What goes wrong:** After deploy, a previously-minted handoff URL (or a test fixture token) fails the new marker assertion and the operator hits the gate-failure flash.
**Why it happens:** `normalize/1` now includes `"manual_edit_opened_at"`; `payload == expected` is false if the old token lacks the key, and `assert_handoff_marker/1` rejects nil markers.
**How to avoid:** Accept it — tokens live ≤30 min and are minted at click time. Any existing test that signs a token without the marker must be updated to pass the opt (or assert the gate-failure path). Search tests for `EditorHandoff.sign` before changing the shape.
**Warning signs:** `knowledge_base_live_test.exs` / `editor_handoff_test.exs` failing with `Ecto.NoResultsError` after the `verify!/2` rewrite.

### Pitfall 2: `ArticleSuggestion.changeset/2` re-validates many required fields on a narrow update
**What goes wrong:** `record_editor_handoff/2` using the full `changeset/2` may surface unrelated validation errors or feel surprising.
**Why it happens:** `changeset/2` runs `validate_required` over `stable_key`, `suggestion_type`, `proposed_markdown`, etc. ([article_suggestion.ex:71-80]).
**How to avoid:** Add a dedicated `manual_edit_changeset(suggestion, attrs)` to the schema (additive) that casts only `:manual_edit_opened_at` — cleaner intent, no incidental re-validation. (Claude's-discretion decision, see Pattern 4.)
**Warning signs:** Changeset errors on fields the handoff write never touches.

### Pitfall 3: `manual_edit_opened_at` is `:utc_datetime_usec` in DB but must be ISO8601 string in the token
**What goes wrong:** Signing a `DateTime` struct into the token, then comparing a string in `verify!/2`, fails equality; also `:utc_datetime_usec` structs are not plain-Erlang-term-safe for `Plug.Crypto.sign`.
**Why it happens:** The DB column stores a `DateTime`; the token payload must store the ISO8601 *binary* (`DateTime.to_iso8601/1`) per the established signed-payload pattern (CONTEXT.md code_context).
**How to avoid:** Token side stores `DateTime.utc_now() |> DateTime.to_iso8601()` (per D-04). `assert_handoff_marker/1` checks `is_binary(v) and v != ""`. The DB write stores the raw `DateTime`. Keep the two representations deliberately distinct.
**Warning signs:** `verify!/2` always raising even with a valid handoff; or `Plug.Crypto.sign` raising on a non-serializable term.

### Pitfall 4: Inline hex fallback trips the Phase 29 BRAND-04 negative-grep gate
**What goes wrong:** New nav/sidebar/button markup written as `var(--cl-primary, #A94F30)` fails the gate that scans `lib/cairnloop/web/`.
**Why it happens:** CLAUDE.md still shows the old fallback form; the BRAND-04 gate (Phase 29) supersedes it but is itself still `Pending` (REQUIREMENTS.md). New code must pre-comply.
**How to avoid:** Bare `var(--cl-<token>)` only. All tokens the UI-SPEC references are verified present in `examples/.../app.css`: `--cl-bg`, `--cl-surface`, `--cl-surface-raised`, `--cl-primary`, `--cl-primary-text`, `--cl-danger`, `--cl-ai`, `--cl-success`, `--cl-info`, `--cl-warning`, `--cl-text`, `--cl-text-muted`, `--cl-border`, `--cl-focus`, `--cl-radius-sm/md/lg`.
**Warning signs:** `grep -rE 'var\(--cl-[a-z-]+, #' lib/cairnloop/web/` returns matches.

### Pitfall 5: Repo unavailable in this workspace breaks DB-touching tests
**What goes wrong:** Tests for `record_editor_handoff/2` / `list_articles/1` / `get_gap_candidate/2` fail to boot a Postgres connection.
**Why it happens:** CLAUDE.md caveat — `Cairnloop.Repo` may be unavailable here.
**How to avoid:** Use the established Mock-injection pattern. LiveView tests set `Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)` and `:repo, MockRepo` (see `knowledge_base_live_test.exs` MockRepo at top; `suggestion_review_test.exs` MockKnowledgeAutomation). Presenter/`verify!`/`decode` tests are pure and need no Repo. Mark any genuine Postgres-round-trip test with `# REPO-UNAVAILABLE`.
**Warning signs:** `DBConnection`/`Postgrex` connection-refused in test output (distinguish from the pre-existing `*.Repo` boot noise baseline).

### Pitfall 6: `String.to_existing_atom` in queue filters can raise on unknown input
**What goes wrong:** Not Phase 30's direct concern, but `ReviewTaskPresenter.queue_filter_status/1` uses `String.to_existing_atom` ([review_task_presenter.ex:26]); when extending presenter copy, don't introduce new `String.to_atom` on user input.
**How to avoid:** Keep new copy variants keyed off existing atoms (`:open_for_edit`, suggestion structs), never off raw strings.

## Code Examples

### KB-04: Three-variant `action_label/2` (calm copy)
```elixir
# Source: in-tree review_task_presenter.ex:200-208 (extend existing 1-variant logic)
# UI-SPEC §KB-04 copy table
def action_label(:open_for_edit, %ReviewTask{article_suggestion: suggestion})
    when not is_nil(suggestion) do
  cond do
    suggestion.status == :failed ->
      "Review and draft manually"

    suggestion.suggestion_type == :article or
        ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion) == "Manual draft required" ->
      "Create manual draft"

    true ->
      "Open for manual edit"
  end
end

def action_label(:open_for_edit, _task), do: "Open for manual edit"
```
Note: the UI-SPEC condition mentions `quick_fix_outcome == :blocked_manual_required`; in-tree that surfaces as `quick_fix_outcome_label(suggestion) == "Manual draft required"` ([review_task_presenter.ex:203]). Cross-reference `ArticleSuggestionPresenter` for the exact predicate during planning. Verify the default `:open_for_edit` label is `"Open for manual edit"` (UI-SPEC), replacing the current `"Open for edit"` at [review_task_presenter.ex:198].

### KB-02: New-article event on Index
```elixir
# Source: D-12; create_article/1 exists at knowledge_base.ex:65
def handle_event("new_article", _params, socket) do
  case KnowledgeBase.create_article(%{title: "Untitled article", status: :draft}) do
    {:ok, article} ->
      {:noreply, push_navigate(socket, to: "/knowledge-base/#{article.id}/edit")}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Unable to create the article right now. Try again.")}
  end
end
```
Button markup (UI-SPEC §2): `phx-click="new_article"`, `phx-click-loading` disabled state, `min-height: 44px`, `background: var(--cl-primary); color: var(--cl-primary-text)`, label `"New article"`.

### SEC-01/SEC-02: SuggestionReview wiring (DB write + marker-bearing token)
```elixir
# Source: D-01, D-04; extends suggestion_review.ex:138-174 open_for_manual_edit
def handle_event("open_for_manual_edit", %{"id" => task_id}, socket) do
  {:ok, task, suggestion} = load_task_selection(task_id, socket)
  # ... existing target_article_id resolution unchanged ...

  {:ok, _suggestion} =
    knowledge_automation().record_editor_handoff(suggestion.id, socket.assigns.scope_filters)  # DB write [D-05]

  handoff_token =
    EditorHandoff.sign(
      suggestion.id, target_article_id, task.id, URI.decode_www_form(return_to),
      manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()           # token marker [D-04]
    )
  # ... existing push_navigate with &handoff=... unchanged ...
end
```

### KB-03 / SEC: Editor mount rescue + gap sidebar derivation
```elixir
# Source: D-06, D-07, D-08; editor.ex:12-32 mount, :94-102 load_suggestion
def mount(params, session, socket) do
  scope_filters = scope_filters(session)
  id = (is_map(params) && params["id"]) || session["id"]

  try do
    article = repo().get!(Article, id)
    latest_revision = KnowledgeBase.get_latest_revision(id)
    suggestion = load_suggestion(params, scope_filters, article.id)   # calls verify!/2 internally
    gap_candidate = load_gap_candidate_from_suggestion(suggestion, scope_filters)  # [D-07]
    # ... existing review_context / content / assigns ...
    {:ok, assign(socket, gap_candidate: gap_candidate, article: article, ...)}
  rescue
    Ecto.NoResultsError ->
      {:ok,
       socket
       |> put_flash(:error,
            "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing.")
       |> push_navigate(to: "/knowledge-base/suggestions")}
  end
end

defp load_gap_candidate_from_suggestion(nil, _), do: nil
defp load_gap_candidate_from_suggestion(suggestion, scope_filters) do
  case {suggestion.entrypoint_type, suggestion.entrypoint_id} do
    {:gap_candidate, gid} when is_integer(gid) ->
      knowledge_automation().get_gap_candidate(gid, scope_filters)
    _ -> nil
  end
end
```
**Caution (planner):** the existing `mount/3` calls `repo().get!(Article, id)` *before* any handoff check; an invalid `id` already raises `Ecto.NoResultsError`. Wrapping the whole body in `try/rescue` means a genuinely-missing article ALSO lands on the "open from review queue" flash, which is slightly off-message for that case but acceptable (fail-closed, calm, redirects to a valid surface). If precise messaging is wanted, rescue only around `load_suggestion/3`. **Decision (Claude's discretion):** rescue the whole `mount` body — simpler, fail-closed, and the redirect target is always valid; the message is acceptable for both the missing-article and missing-marker cases since both mean "you didn't arrive here legitimately."

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Editor accepts any matching `suggestion_id` + signed token (integrity only) | Token must additionally carry a `manual_edit_opened_at` marker (deliberate-handoff assertion) + DB audit row | Phase 30 (this) | Closes T-10-09 (audit) + T-10-11 (no bare-URL preload) |
| `Index.mount/3` does `repo().all(Article)` directly | Reads through `KnowledgeBase.list_articles/1` facade | Phase 30 | Restores arch invariant #5 before Phase 31 golden-path traverses Index |
| 4 KB routes with unrelated per-page layout | Shared `kb_nav/1` function component on all 4 | Phase 30 | Operator orientation; no context-switch |
| Brand colors as `var(--cl-token, #hex)` inline fallback | Bare `var(--cl-token)` (tokens defined in app.css `:root`) | Phase 29 (BRAND-02/04) | New Phase 30 render code must pre-comply with the bare form |

**Deprecated/outdated:**
- `var(--cl-primary, #A94F30)` inline-fallback form (still shown in CLAUDE.md): superseded by Phase 29's bare-token form for all `lib/cairnloop/web/` render code.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A dedicated `manual_edit_changeset/2` on `ArticleSuggestion` is cleaner than reusing `changeset/2` for the handoff write. | Pattern 4 / Pitfall 2 | Low — both work; reusing `changeset/2` just re-validates already-valid fields. Planner can choose. |
| A2 | Wrapping the entire `Editor.mount/3` body in `try/rescue` (vs. only `load_suggestion/3`) is acceptable for the missing-article case. | Code Examples (Editor) | Low — fail-closed either way; only the flash precision differs. |
| A3 | The UI-SPEC `quick_fix_outcome == :blocked_manual_required` predicate maps to `ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion) == "Manual draft required"` in-tree; `:new_article` maps to `:article`; the `:failed` variant keys off `suggestion.status == :failed`. | Code Examples (KB-04) | **CONFIRMED (risk retired)** — verified against `article_suggestion_presenter.ex` (lines 8, 39, 78-88) + `article_suggestion.ex` (lines 7-8). See Open Questions (RESOLVED) #1. |
| A4 | Existing tests that call `EditorHandoff.sign` without the marker opt will need updating after the payload-shape change. | Pitfall 1 | Low-Medium — a grep before the rewrite confirms scope; missing one yields a test failure, not a runtime bug. |
| A5 | `:editor` as a `current` value renders no active nav marker (Editor has no top-level nav entry per UI-SPEC labels). | Pattern 1 | Low — UI-SPEC lists only 3 nav labels; this is the intended behavior. |

## Open Questions (RESOLVED)

1. **Exact `ArticleSuggestionPresenter` predicate for the "Create manual draft" / ":failed" branches (KB-04).**
   - What we know: UI-SPEC keys it off `suggestion_type == :new_article` or `quick_fix_outcome == :blocked_manual_required`; in-tree the suggestion_type enum is `[:article, :revision]` (not `:new_article`) and quick-fix outcome surfaces via `quick_fix_outcome_label/1`.
   - What's unclear: the precise mapping of UI-SPEC's `:new_article` to the in-tree `:article` type, and `:blocked_manual_required` to the label string.
   - Recommendation: planner reads `lib/cairnloop/web/article_suggestion_presenter.ex` to confirm `quick_fix_outcome_label/1` return values and the `quick_fix?/1` predicate before finalizing `action_label/2`.
   - **RESOLVED (confirmed against in-tree source this revision):** Read `lib/cairnloop/knowledge_automation/article_suggestion.ex` and `lib/cairnloop/web/article_suggestion_presenter.ex`. Confirmed:
     - `@status_values [:pending_generation, :ready, :failed, :dismissed]` (article_suggestion.ex line 7) — `:failed` IS a real enum atom. `ArticleSuggestionPresenter.status_label/1` maps `:failed` -> "Generation blocked" (line 8) and `action_labels/1` matches `%ArticleSuggestion{status: :failed}` (line 39). The ":failed" KB-04 variant predicate is **`suggestion.status == :failed`** (exact atom). NOT dead code.
     - `@suggestion_type_values [:article, :revision]` (line 8) — there is NO `:new_article` value. UI-SPEC's `:new_article` maps to the in-tree **`:article`** atom. The "Create manual draft" predicate is **`suggestion.suggestion_type == :article`**.
     - `quick_fix_outcome_label/1` (presenter lines 78-88) returns the binary **`"Manual draft required"`** for both `"blocked_manual_required"` and `:blocked_manual_required`. The companion "Create manual draft" predicate is **`ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion) == "Manual draft required"`**.
     - Risk per A3 (Medium) is retired: the predicates are confirmed, not assumed. Plan 02 Task 3 already uses these exact strings/atoms; the `:failed` fixture in its test MUST set `status: :failed` (the exact enum value).

2. **Whether `record_editor_handoff/2` should be idempotent (overwrite an existing `manual_edit_opened_at`).**
   - What we know: D-05 says "write `manual_edit_opened_at = DateTime.utc_now()`" on each open.
   - What's unclear: if an operator re-opens, should the timestamp refresh or keep the first-open time? For audit (T-10-09), "most recent open" is the more useful signal and overwriting is simplest.
   - Recommendation: overwrite on each open (refresh to latest). It satisfies the auditable-marker intent and avoids a conditional write. Flag for cheap veto.
   - **RESOLVED (settled, recorded for executors):** `record_editor_handoff/2` is **overwrite-on-each-open (refresh-to-latest)** — the narrow `ArticleSuggestion.manual_edit_changeset/2` unconditionally casts `:manual_edit_opened_at` to `now_fn(opts).()` and `repo().update/1` persists it, replacing any prior value. No conditional / first-write-wins branch. Rationale: T-10-09's auditable intent is satisfied by "most recent deliberate open," the write is unconditional (simplest, no read-before-write race), and durable records + events remain workflow truth. This is the behavior Plan 01 Task 3 implements and Plan 01 Task 4 asserts (Mock: changeset called with the suggestion id + the pinned `now_fn` timestamp; real Postgres round-trip marked `# REPO-UNAVAILABLE`).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/Mix toolchain | compile + test | ✓ (project builds today) | per `.tool-versions`/asdf | — |
| `phoenix_live_view` | all 4 KB surfaces | ✓ | 1.1.x (resolved) | — |
| `plug_crypto` | token sign/verify/decode | ✓ | 2.1.1 (resolved) | — |
| `earmark` | preview pane (unchanged) | ✓ | 1.4.48 (resolved) | — |
| `Cairnloop.Repo` (live Postgres) | DB-touching tests only | ✗ (per CLAUDE.md, may be unavailable in this workspace) | — | Mock-injection pattern for LiveView tests; `# REPO-UNAVAILABLE` note for genuine round-trips |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `Cairnloop.Repo` — use the established Mock pattern (`MockRepo` + `MockKnowledgeAutomation` via `Application.put_env`) for headless tests; mark Postgres-round-trip tests `# REPO-UNAVAILABLE`.

## Validation Architecture

> `workflow.nyquist_validation` is **absent** in `.planning/config.json` → treated as **enabled**.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + `Phoenix.LiveViewTest` (HTML via `lazy_html`) |
| Config file | `test/test_helper.exs` (standard ExUnit) |
| Quick run command | `mix test test/cairnloop/web/knowledge_base_live/ test/cairnloop/web/review_task_presenter_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| KB-01 | `kb_nav/1` renders 3 links, marks active via `aria-current="page"` + primary border (not color alone) | unit (pure render) | `mix test test/cairnloop/web/knowledge_base_live/nav_component_test.exs` | ❌ Wave 0 |
| KB-01 | All 4 LiveViews render the nav shell | integration (LiveView render) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | ✅ extend |
| KB-02 | `"new_article"` event creates article + navigates; error path flashes calm copy | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | ✅ extend |
| KB-03 | Editor shows sidebar when suggestion `entrypoint_type == :gap_candidate`; hidden otherwise; degrades to nil on deleted gap | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | ✅ extend |
| KB-04 | `action_label(:open_for_edit, task)` returns the 3 correct calm variants; never raw atoms | unit (pure) | `mix test test/cairnloop/web/review_task_presenter_test.exs` | ❌ Wave 0 |
| SEC-01 | `verify!/2` raises when token lacks `manual_edit_opened_at`; `record_editor_handoff/2` writes the DB timestamp | unit (pure for verify!) + Mock (DB write) | `mix test test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs` | ✅/❌ extend or Wave 0 |
| SEC-02 | Editor with bare `suggestion_id` (no marker token) → gate-failure flash + redirect; valid marker token → preloads `proposed_markdown` | integration (Mock) | `mix test test/cairnloop/web/knowledge_base_live_test.exs` | ✅ extend |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors && mix test test/cairnloop/web/knowledge_base_live/ test/cairnloop/web/review_task_presenter_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green (modulo the one known pre-existing `Automation.DraftTest` baseline failure — M005 drift, not a regression) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/cairnloop/web/knowledge_base_live/nav_component_test.exs` — covers KB-01 (pure render: links, active marker, aria-current, no-color-alone)
- [ ] `test/cairnloop/web/review_task_presenter_test.exs` — covers KB-04 (pure: 3 copy variants, no raw atoms)
- [ ] Confirm `test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs` exists; if absent, create for SEC-01 `decode/1` + `verify!/2` marker-gate pure tests
- [ ] Framework install: none — ExUnit + `lazy_html` already present

## Security Domain

> `security_enforcement` is not set to `false` in config → **enabled**. Phase 30's entire SEC-01/SEC-02 scope is a security gate, so this section is load-bearing.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host app owns auth; KB surfaces inherit the host session. No auth logic in scope. |
| V3 Session Management | partial | The handoff token is a short-lived (`@max_age 1800`) signed capability, not a session; `Plug.Crypto` enforces expiry. |
| V4 Access Control | **yes** | The double-layer gate is an access-control check: the Editor must verify a deliberate, server-signed handoff before exposing `proposed_markdown` (SEC-01/SEC-02). Tenant scope enforced via `apply_scope`/`enforce_scope!`. |
| V5 Input Validation | **yes** | `verify!/2` validates the `handoff` param's signature + marker before trusting `suggestion_id`; bare/forged URL params are rejected fail-closed. |
| V6 Cryptography | **yes** | Token integrity via `Plug.Crypto.sign`/`verify` (HMAC under the hood) — never hand-rolled. Secret-key handling already in `EditorHandoff`. |
| V7 Error Handling & Logging | **yes** | Gate failure raises `Ecto.NoResultsError` → rescued → calm flash; never leaks `suggestion_id`, raw params, or Ecto error details to the operator (brand §5.6). |

### Known Threat Patterns for Phoenix LiveView + signed-token handoff

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Bare `suggestion_id` URL preloads reviewed content (T-10-11) | Spoofing / Information disclosure | Require a server-signed token carrying a deliberate-handoff marker before preload (SEC-02) |
| No auditable record that the editor was opened (T-10-09) | Repudiation | Durable `manual_edit_opened_at` DB write via `record_editor_handoff/2` (SEC-01) |
| Forged/tampered handoff token | Tampering | `Plug.Crypto.verify` constant-time HMAC check; reject on `{:error, _}` |
| Replayed expired handoff | Elevation/replay | `@max_age 1800` enforced by `Plug.Crypto.verify` |
| Cross-tenant suggestion/gap read | Information disclosure | `apply_scope/2` + `enforce_scope!/3` on facade reads (already enforced; reused by new fns) |
| Raw Elixir term leakage in error flash | Information disclosure | Presenter-driven, fixed-string flash copy (brand §5.5/§5.6); never `inspect/1` to operators |

**Out of scope (deferred to vM015):** T-10-10 (authoring-target seam), T-10-12 (gap-candidate prep bypass), T-10-13 (stale-gate input injection) — all domain-layer in `knowledge_automation.ex`.

## Sources

### Primary (HIGH confidence)
- In-tree source (read this session): `lib/cairnloop/knowledge_automation/editor_handoff.ex`, `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex`, `.../editor.ex`, `.../index.ex`, `.../suggestion_review.ex`, `.../gaps.ex`, `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/knowledge_automation.ex` (mounts, facades, scope helpers, `create_or_reuse_authoring_article_for_suggestion`, `mark_review_task_material_edit`, `now_fn`, `apply_scope`/`enforce_scope!`), `lib/cairnloop/knowledge_automation/article_suggestion.ex`, `.../gap_candidate.ex`, `lib/cairnloop/knowledge_base/article.ex`, `lib/cairnloop/web/review_task_presenter.ex`
- `SECURITY.md` — T-10-09 / T-10-11 full threat descriptions + file/line citations
- `.planning/REQUIREMENTS.md` §KB Editorial Polish + §Security Threat Closure
- `.planning/STATE.md` — carried decisions, vM014 SECURITY split, baseline test caveats
- `30-CONTEXT.md` (D-01..D-14), `30-UI-SPEC.md` (visual/copy/interaction contract)
- `mix.exs` + `mix.lock` — resolved dependency versions
- `examples/cairnloop_example/assets/css/app.css` — `--cl-*` token inventory
- `prompts/cairnloop_brand_book.md` §5.6 (error pattern), §13.4 (handoff copy), §7.5 (color-alone rule)
- `CLAUDE.md` — architecture posture, build/test conventions, decision policy

### Secondary (MEDIUM confidence)
- `.planning/phases/29-brand-token-css-extraction-d-10-closure/29-0*-SUMMARY.md` / `29-01-PLAN.md` — BRAND-04 negative-grep gate scope (extended to `lib/cairnloop/web/`)
- `test/cairnloop/web/knowledge_base_live_test.exs`, `.../suggestion_review_test.exs`, `.../gaps_test.exs` — Mock-injection test pattern

### Tertiary (LOW confidence)
- (none — all claims grounded in in-tree source or the canonical planning docs)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions read from resolved `mix.lock`; zero new packages.
- Architecture: HIGH — every target module and the exact patterns to mirror were read in-session; the relationship fields/columns the design relies on were verified to already exist.
- Pitfalls: HIGH — derived directly from the in-tree token/changeset/scope code and the CLAUDE.md Repo caveat.
- Security domain: HIGH — SEC-01/SEC-02 map 1:1 to the SECURITY.md T-10-09/T-10-11 mitigations and the locked double-layer design.

**Research date:** 2026-05-28
**Valid until:** 2026-06-27 (stable — brownfield, no fast-moving external deps; re-verify only if `EditorHandoff`/`ArticleSuggestion` schemas change before planning)
