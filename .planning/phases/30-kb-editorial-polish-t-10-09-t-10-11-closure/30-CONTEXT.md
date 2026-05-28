# Phase 30: KB Editorial Polish + T-10-09 / T-10-11 Closure - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Tighten the four KB routes into one coherent editorial surface (shared nav shell, "New article" affordance, inline gap evidence sidebar, calm handoff copy) and close two of the five open SECURITY threats — T-10-09 (no auditable handoff marker when editor is opened from review queue) and T-10-11 (proposed_markdown preloaded from bare `suggestion_id` URL without deliberate handoff state) — via an `EditorHandoff` token-and-DB gate. T-10-10 / T-10-12 / T-10-13 remain deferred to vM015 (domain layer, `knowledge_automation.ex`). All changes are additive; sealed render code is not churned.

</domain>

<decisions>
## Implementation Decisions

### HandoffToken gate (T-10-09 + T-10-11 closure — SEC-01, SEC-02)

- **D-01:** Use the **double-layer gate**: (1) DB write — `SuggestionReview.open_for_manual_edit` calls `knowledge_automation().record_editor_handoff(suggestion_id, scope_filters)` to write `suggestion.manual_edit_opened_at = DateTime.utc_now()` to the DB (auditable timestamp — closes T-10-09); (2) signed-token assertion — `manual_edit_opened_at` as ISO8601 string is included in the signed `EditorHandoff` token payload; `verify!/2` rejects tokens that lack it (closes T-10-11, Editor can only preload `proposed_markdown` via a server-signed `open_for_manual_edit` handoff).

- **D-02:** Add `Token.decode(token) :: {:ok, payload} | {:error, reason}` to the domain `Cairnloop.KnowledgeAutomation.EditorHandoff` module. This is purely additive — existing `verify/2` is **unchanged** and backward-compat. `Token.decode/1` calls `Plug.Crypto.verify` and returns the decoded payload map on success. Pattern: canonical Elixir (Phoenix.Token, Guardian, Joken) — integrity verification is the domain primitive; semantic field assertions belong in the web layer.

- **D-03:** Web `EditorHandoff.verify!/2` is extended to a three-step pipeline (single `Plug.Crypto` decode via `Token.decode/1`, then two assertions):
  1. `Token.decode(token)` → `{:ok, payload}`
  2. `assert_handoff_marker(payload)` — checks `payload["manual_edit_opened_at"]` is a non-nil, non-empty binary string → `:ok | {:error, :missing_handoff_marker}`
  3. Assert attrs match against decoded payload (replicate existing `Token.verify/2` logic against the already-decoded map, **not** a second `Plug.Crypto.verify` call — avoid double-decode)
  Raises `Ecto.NoResultsError, queryable: Article` on any failure (existing contract unchanged).

- **D-04:** `EditorHandoff.sign` in the web module gets **keyword opts**: `sign(suggestion_id, article_id, review_task_id, return_to, opts \\ [])`. Only `SuggestionReview.open_for_manual_edit` passes `[manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()]`. Existing call sites that do not pass opts continue to work unchanged (opts defaults to `[]`). The domain `Token.sign/1` receives the full map including any opts-derived fields.

- **D-05:** Domain function name for writing the DB timestamp: `KnowledgeAutomation.record_editor_handoff(suggestion_id, scope_filters)`. Clear intent — the editor handoff was initiated. Distinct from `mark_review_task_material_edit/2` (which fires on draft save, not on editor open).

- **D-06:** Gate failure in `Editor.mount/3`: rescue the `Ecto.NoResultsError` raised by `verify!/2` (or any error from `load_suggestion/3`) → `put_flash(:error, <exact UI-SPEC copy below>)` + `push_navigate(socket, to: "/knowledge-base/suggestions")`. Never a 500 page. Never raw Elixir terms. **Exact flash copy (from UI-SPEC §Handoff Marker Interaction):**
  > "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."

### Gap sidebar data source (KB-03)

- **D-07:** Derive `gap_candidate` from the suggestion record in `Editor.mount/3` — **no token or URL changes** for `gap_candidate_id`. After `load_suggestion/3` succeeds, call `load_gap_candidate_from_suggestion(suggestion, scope_filters)`:
  ```elixir
  defp load_gap_candidate_from_suggestion(nil, _), do: nil
  defp load_gap_candidate_from_suggestion(suggestion, scope_filters) do
    case {suggestion.entrypoint_type, suggestion.entrypoint_id} do
      {:gap_candidate, id} when is_integer(id) ->
        knowledge_automation().get_gap_candidate(id, scope_filters)  # non-bang
      _ -> nil
    end
  end
  ```
  `get_gap_candidate/2` (non-bang, returns nil on not-found) to be added to the `KnowledgeAutomation` facade (or fallback: wrap `get_gap_candidate!/2` in a rescue that returns nil). Reason: `ArticleSuggestion.entrypoint_id` when `entrypoint_type == :gap_candidate` IS the `gap_candidate_id` — the domain model is the canonical source of truth. Adding it to the token would duplicate data and blend security attestation with data transport. The UI-SPEC's mention of `EditorHandoff.sign/4` gaining a `gap_candidate_id` field was written before the existing schema relationship was recognized — it is overridden by this decision.

- **D-08:** `Editor.mount/3` gains `assign(socket, :gap_candidate, gap_candidate)`. Template condition: `<%= if @gap_candidate do %>` (exactly per UI-SPEC §KB-03). The sidebar is read-only; no event handlers needed for it.

### Index architecture fix (KB-01, KB-02)

- **D-09:** Add `KnowledgeBase.list_articles(opts \\ [])` to the `KnowledgeBase` facade. Architecture invariant #5 requires no direct `Repo` queries from the web layer. Article schema has no tenant fields today, so scope_filters opts are accepted but currently ignored (reserved for when Article gains `host_user_id`/`tenant_scope`). Consistent with `KnowledgeAutomation.list_gap_candidates(opts \\ [])` and `list_review_tasks(opts \\ [])` — prevents arity-breaking change when tenant support lands. Include `:status` filter support (useful for Index which shows all statuses).

- **D-10:** `KnowledgeBase.Index.mount/3` changes from `repo().all(Article)` to `KnowledgeBase.list_articles(scope_filters)`. Index becomes arch-invariant-compliant before Phase 31 golden-path test traverses it.

### Auto-decided (no discussion needed — recorded for downstream agents)

- **D-11:** Nav shell lives in a dedicated module `Cairnloop.Web.KnowledgeBaseLive.NavComponent` with `def kb_nav/1`. Each KB LiveView calls `<.kb_nav current={:index} />` (or `:editor`, `:suggestions`, `:gaps`). Purely additive — no sealed render code touched. Labels and routes per UI-SPEC §KB-01.

- **D-12:** "New article" button (KB-02): single `"new_article"` event on `KnowledgeBase.Index` → `KnowledgeBase.create_article(%{title: "Untitled article", status: :draft})` → `push_navigate(socket, to: "/knowledge-base/#{article.id}/edit")`. `KnowledgeBase.create_article/1` already exists. Initial title: `"Untitled article"` (satisfies `Article.changeset/2`'s `validate_required([:title, :status])`). Error: `put_flash(:error, "Unable to create the article right now. Try again.")`.

- **D-13:** "Open for manual edit" copy variants live in **`ReviewTaskPresenter.action_label/2`** — keep the presenter-first pattern (brand book §5.5 mandates it; never inline raw atom values in templates). Update the presenter to return the 3-variant copy from UI-SPEC §KB-04 table.

- **D-14:** T-10-10 / T-10-12 / T-10-13 remain **deferred to vM015** (domain layer, `knowledge_automation.ex` — different file from Phase 30 scope). Pre-decided at vM014 kickoff.

### Folded Todos

- **T-10-09 + T-10-11 closure** (from STATE.md "Root SECURITY.md carries 3 open threats — T-10-09 + T-10-11 close in Phase 30"): folded directly into SEC-01 / SEC-02 scope above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UI design contract (APPROVED — highest priority)
- `.planning/phases/30-kb-editorial-polish-t-10-09-t-10-11-closure/30-UI-SPEC.md` — APPROVED Phase 30 UI design contract. Complete visual spec (spacing, typography, color, component inventory), interaction contracts (all five components), exact copy for every rendered string, accessibility checklist, motion/transition rules. **Supersedes any default styling decisions.** Agents must read this before writing any render code.

### Security threats being closed
- `SECURITY.md` — T-10-09 (row E, "editor handoff") + T-10-11 (row S, "editor preload") full threat descriptions with affected file/line citations. Read before implementing SEC-01/SEC-02. T-10-10/T-10-12/T-10-13 rows are in-scope for vM015 only.

### Requirements + Roadmap
- `.planning/REQUIREMENTS.md` §KB Editorial Polish + §Security Threat Closure — KB-01..KB-04, SEC-01, SEC-02 requirements and acceptance criteria.
- `.planning/ROADMAP.md` §Phase 30 — Goal, phase boundary, success criteria (4 items).

### EditorHandoff modules (primary implementation targets)
- `lib/cairnloop/knowledge_automation/editor_handoff.ex` — domain token module; `sign/1`, `verify/2`, `normalize/1`. Phase 30 adds `decode/1` here.
- `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex` — web wrapper; `sign/4`, `verify!/2`, `ensure_review_task_match!/2`. Phase 30 extends `sign` to keyword opts, rewrites `verify!/2` to three-step pipeline.

### KB LiveViews being modified
- `lib/cairnloop/web/knowledge_base_live/editor.ex` — Editor; gains `gap_candidate` assign, `load_gap_candidate_from_suggestion/2`, mount rescue for gate failure. Phase 30 SEC-01/SEC-02 gate lands here.
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — SuggestionReview; `open_for_manual_edit` event gains `record_editor_handoff` call + updated `EditorHandoff.sign` with `manual_edit_opened_at` opt.
- `lib/cairnloop/web/knowledge_base_live/index.ex` — Index; gains kb_nav, new_article button+event, switches to `KnowledgeBase.list_articles/1`.
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` — Gaps; gains kb_nav only (read-only surface, no other Phase 30 changes).

### Facades being extended
- `lib/cairnloop/knowledge_base.ex` — Add `list_articles(opts \\ [])` with `maybe_filter_status/2`.
- `lib/cairnloop/knowledge_automation.ex` — Add `record_editor_handoff/2` (writes `manual_edit_opened_at`); add `get_gap_candidate/2` (non-bang, returns nil on not-found).

### ArticleSuggestion schema (critical prior-art)
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` (or embedded in `knowledge_automation.ex`) — `manual_edit_opened_at` DB field (`field(:manual_edit_opened_at, :utc_datetime_usec)`) already exists. `entrypoint_type` / `entrypoint_id` already encode the `gap_candidate_id` relationship. Read before implementing D-07.

### Brand + copy register
- `prompts/cairnloop_brand_book.md` — §5 (copy register: calm, reason-forward, fail-closed), §5.2 (error copy shape), §5.5 (never raw atoms/JSON), §7.5 (color-alone rule), §16 (accessibility). Governs all flash messages and button labels.

### Prior phase context
- `.planning/phases/29-brand-token-css-extraction-d-10-closure/29-CONTEXT.md` — Phase 29 D-09 (negative-grep gate extended to `lib/cairnloop/web/` + `examples/.../live/`). New render code in Phase 30 must use bare `var(--cl-<token>)` — no inline hex fallbacks.

### Architecture posture
- `CLAUDE.md` — Sealed-contract + additive-opts, Governance-facade reads, brand tokens, never raw hex to operators. All Phase 30 changes must honor these.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.KnowledgeAutomation.EditorHandoff` — `sign/1` (domain, map-accepting), `verify/2` (existing, unchanged). Add `decode/1` alongside.
- `Cairnloop.Web.KnowledgeBaseLive.EditorHandoff` — `sign/4` (positional → extend to keyword opts), `verify!/2` (rewrite pipeline).
- `KnowledgeBase.create_article/1` — already exists; accepts `%{title: ..., status: ...}`. Used by KB-02 new article button.
- `KnowledgeAutomation.get_gap_candidate!/2` — already exists; needs a non-bang soft variant for KB-03 sidebar (deleted gap gracefully degrades to nil).
- `KnowledgeAutomation.list_gap_candidates/1` with `opts \\ []` — the exact pattern `list_articles/1` should follow.
- `Editor.scope_filters(session)` private helper — already returns `[tenant_scope: ..., host_user_id: ...]`; used by new `load_gap_candidate_from_suggestion/2` and passed through to `list_articles/1`.

### Established Patterns
- **HandoffToken verify pipeline:** Web wrapper calls domain decode, then semantic assertions, then raises on failure — never surfaces raw errors to operators.
- **Signed-token payload:** Plain Elixir map, serialized by `Plug.Crypto.sign/4`. DateTime values must be stored as ISO8601 strings (`:utc_datetime_usec` structs are not plain-Erlang-term-safe for signing).
- **Brand-compliant flash errors:** Follow `put_flash(:error, "<exact UI-SPEC copy>")` — never "Something went wrong", never raw error term.
- **Presenter-first copy:** All operator-visible text comes from `ReviewTaskPresenter` or `ArticleSuggestionPresenter` — never inline atom/struct repr in templates.
- **Test gate:** Phase 29 BRAND-04 negative-grep gate enforces no `var(--cl-*, #hex)` in new render code. All new `style=` attributes use bare `var(--cl-<token>)`.
- **Facade-reads-only from web layer:** Web LiveViews never call `repo()` for list/filter queries. Phase 30 adds `KnowledgeBase.list_articles/1` to honor arch invariant #5.

### Integration Points
- `lib/cairnloop/router.ex` — KB routes already defined; check for any "new article" route that may need to be added (or confirm the Index handles creation inline via event → push_navigate to existing editor route `/knowledge-base/:id/edit`).
- `KnowledgeBase.Index` session → `scope_filters/1` — already present; wire to `list_articles/1` in mount.
- `Editor.mount/3` rescue clause — new rescue wraps `load_suggestion/3` to catch gate failures and produce the brand-compliant flash + redirect.

</code_context>

<specifics>
## Specific Ideas

- The `manual_edit_opened_at` gate uses a **double-layer** approach (token + DB) rather than either alone. This closes both threat descriptions: T-10-09 wants an auditable DB record; T-10-11 wants the editor to require deliberate server-side handoff state beyond bare URL params. Both are satisfied simultaneously.
- `Token.decode/1` is the canonical Elixir/Phoenix pattern (mirrors Phoenix.Token, Guardian, Joken): verify integrity first, return payload, let the caller assert semantics. The domain layer stays policy-agnostic; the web wrapper owns the product assertions.
- `gap_candidate_id` is NOT added to the token payload. The `ArticleSuggestion` already encodes the relationship via `entrypoint_type == :gap_candidate` + `entrypoint_id`. The Editor derives it post-handoff-verification from the loaded suggestion record. This keeps the token's semantic contract clean (attestation, not data ferry).
- `list_articles(opts \\ [])` from day one — consistent with the six KnowledgeAutomation list functions; prevents arity-breaking change when Article gains tenant fields. Opts are accepted but currently ignored for non-status keys.

</specifics>

<deferred>
## Deferred Ideas

- T-10-10 / T-10-12 / T-10-13 — domain-layer threats in `knowledge_automation.ex`. Deferred to vM015 per assessment thread decision at vM014 kickoff.
- `Article` tenant isolation (adding `host_user_id` / `tenant_scope` fields) — reserved for future milestone; `list_articles/1` opts are already wired for it.
- Centralize duplicated fail-closed search guards — carried from vM009; out of scope for Phase 30.

</deferred>

---

*Phase: 30-kb-editorial-polish-t-10-09-t-10-11-closure*
*Context gathered: 2026-05-28*
