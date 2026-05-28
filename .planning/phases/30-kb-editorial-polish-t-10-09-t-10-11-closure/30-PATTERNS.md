# Phase 30: KB Editorial Polish + T-10-09 / T-10-11 Closure - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 12 (10 modified, 2 created) + 4 test files
**Analogs found:** 12 / 12 (all in-tree; the one new module has a per-pattern composite analog)

> Every Phase 30 capability is additive composition of existing in-tree primitives — no new deps,
> no migrations, no new schema fields (`manual_edit_opened_at` and `entrypoint_type`/`entrypoint_id`
> already exist). All excerpts below were read and line-verified this session.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/knowledge_automation/editor_handoff.ex` (MOD: +`decode/1`, extend `normalize/1`) | domain (token primitive) | transform (sign/verify) | self — `verify/2` (11-21), `normalize/1` (23-33) | exact (same module) |
| `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex` (MOD: `sign/5` opts, `verify!/2` 3-step) | web wrapper (security gate) | request-response (assert) | self — `sign/4` (8-15), `verify!/2` (17-29) | exact (same module) |
| `lib/cairnloop/knowledge_base.ex` (MOD: +`list_articles/1`) | domain facade | CRUD (list read) | `KnowledgeAutomation.list_gap_candidates/1` (knowledge_automation.ex:40-50) | role-match (cross-context list) |
| `lib/cairnloop/knowledge_automation.ex` (MOD: +`record_editor_handoff/2`, +`get_gap_candidate/2`) | domain facade | CRUD (write + read) | `dismiss_article_suggestion/2` write shape (load-bang → wrapper changeset → `repo().update()`); `get_gap_candidate!/2` (52-62) for read | role-match (write); exact-sibling (read) |
| `lib/cairnloop/web/knowledge_base_live/nav_component.ex` (NEW) | component (function component) | request-response (pure render) | RESEARCH Pattern 1 (no in-tree KB function-component-with-attr precedent) | partial — see No Analog Found |
| `lib/cairnloop/web/knowledge_base_live/index.ex` (MOD: kb_nav, new_article, list_articles) | LiveView (controller) | CRUD + event-driven | self — `handle_event("suggest_revision", ...)` (index.ex:15-40), `mount/3` (10-13) | exact (same module) |
| `lib/cairnloop/web/knowledge_base_live/editor.ex` (MOD: gap_candidate assign, mount rescue, derivation) | LiveView (controller) | request-response (load + render) | self — `mount/3` (12-32), `load_suggestion/3` (94-102) | exact (same module) |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` (MOD: record_editor_handoff + sign opts) | LiveView (controller) | event-driven | self — `handle_event("open_for_manual_edit", ...)` (138-174) | exact (same module) |
| `lib/cairnloop/web/knowledge_base_live/gaps.ex` (MOD: kb_nav only) | LiveView (controller) | request-response | self — `render/1` (59-136), `mount/3` (6-15) | exact (same module) |
| `lib/cairnloop/web/review_task_presenter.ex` (MOD: extend `action_label/2`) | presenter (utility) | transform (atom→copy) | self — `action_label/1` (194-198) + `action_label/2` (200-208) | exact (same module) |
| `test/.../nav_component_test.exs` (NEW) | test (pure render) | request-response | RESEARCH Wave-0 (no nav test precedent) | partial — pure render assertions |
| `test/.../review_task_presenter_test.exs` (NEW) | test (pure) | transform | `test/cairnloop/web/tool_proposal_presenter_test.exs` (presenter-pure idiom) | role-match |
| `test/.../editor_handoff_test.exs` (NEW) | test (pure) | transform | does not exist yet; pure ExUnit on token round-trip | partial |
| `test/cairnloop/web/knowledge_base_live_test.exs` (EXTEND) | test (integration, Mock) | event-driven | self — `MockRepo` (7-57), `MockKnowledgeAutomation` (59-) | exact (same file) |

## Pattern Assignments

### `lib/cairnloop/knowledge_automation/editor_handoff.ex` — domain `decode/1` + extend `normalize/1` (D-02, D-04)

**Analog:** self — existing `verify/2`; `decode/1` extracts its integrity-check half.

**Existing integrity primitive** (editor_handoff.ex:11-21):
```elixir
def verify(token, attrs) when is_map(attrs) do
  expected = normalize(attrs)

  with {:ok, payload} <- Plug.Crypto.verify(secret_key_base(), @salt, token, max_age: @max_age),
       true <- payload == expected do
    :ok
  else
    {:error, reason} -> {:error, reason}
    false -> {:error, :mismatch}
  end
end
```
**New `decode/1` (D-02)** — additive; same `Plug.Crypto.verify` call, returns the raw payload:
```elixir
def decode(token) do
  Plug.Crypto.verify(secret_key_base(), @salt, token, max_age: @max_age)
  # {:ok, payload_map} | {:error, reason}
end
```
**Existing `normalize/1`** (editor_handoff.ex:23-33) — extend by adding ONE key, keeping the
`Map.get(attrs, :key) || Map.get(attrs, "key")` dual-access idiom (nil-default → backward-compat):
```elixir
defp normalize(attrs) do
  %{
    "article_id" =>
      normalize_integer(Map.get(attrs, :article_id) || Map.get(attrs, "article_id")),
    "review_task_id" =>
      normalize_integer(Map.get(attrs, :review_task_id) || Map.get(attrs, "review_task_id")),
    "return_to" => Map.get(attrs, :return_to) || Map.get(attrs, "return_to"),
    "suggestion_id" =>
      normalize_integer(Map.get(attrs, :suggestion_id) || Map.get(attrs, "suggestion_id"))
    # ADD: "manual_edit_opened_at" =>
    #        Map.get(attrs, :manual_edit_opened_at) || Map.get(attrs, "manual_edit_opened_at")
  }
end
```
**Reuse:** `@salt "knowledge-base-editor-handoff"` (line 4), `@max_age 1800` (line 5),
`secret_key_base/0` (47-65). Do NOT touch `sign/1` (7-9) or `verify/2` (sealed; additive only).

---

### `lib/cairnloop/web/knowledge_base_live/editor_handoff.ex` — `sign/5` opts + `verify!/2` 3-step pipeline (D-03, D-04)

**Analog:** self — existing `sign/4` (8-15) and `verify!/2` (17-29).

**Existing `sign/4`** (editor_handoff.ex:8-15) — extend to `sign/5` with `opts \\ []`; only
`SuggestionReview` passes the marker opt:
```elixir
def sign(suggestion_id, article_id, review_task_id, return_to) do
  Token.sign(%{
    suggestion_id: suggestion_id,
    article_id: article_id,
    review_task_id: review_task_id,
    return_to: return_to
  })
end
# EXTEND → sign(suggestion_id, article_id, review_task_id, return_to, opts \\ [])
#   add to map: manual_edit_opened_at: Keyword.get(opts, :manual_edit_opened_at)
```
**Existing `verify!/2`** (editor_handoff.ex:17-29) — the CONTRACT to preserve: build `attrs`, on
any failure `raise Ecto.NoResultsError, queryable: Article`:
```elixir
def verify!(params, article_id) do
  attrs = %{
    suggestion_id: Map.get(params, "suggestion_id"),
    article_id: article_id,
    review_task_id: Map.get(params, "review_task_id"),
    return_to: Map.get(params, "return_to")
  }

  case Token.verify(Map.get(params, "handoff"), attrs) do
    :ok -> :ok
    _ -> raise Ecto.NoResultsError, queryable: Article   # PRESERVE byte-for-byte
  end
end
```
**Rewrite (D-03, RESEARCH Pattern 2)** — single `Token.decode/1`, then two assertions against the
**already-decoded** payload (NO second `Token.verify`/`Plug.Crypto.verify`):
```elixir
def verify!(params, article_id) do
  expected = normalized_attrs(params, article_id)  # same shape the domain normalize/1 produces

  with {:ok, payload} <- Token.decode(Map.get(params, "handoff")),
       :ok <- assert_handoff_marker(payload),
       true <- payload == expected do
    :ok
  else
    _ -> raise Ecto.NoResultsError, queryable: Article
  end
end

defp assert_handoff_marker(%{"manual_edit_opened_at" => v}) when is_binary(v) and v != "", do: :ok
defp assert_handoff_marker(_), do: {:error, :missing_handoff_marker}
```
`alias ... Article` already imported (line 6). Leave `ensure_review_task_match!/2` (31-44) untouched.
**Pitfall 1 (RESEARCH):** the new payload key invalidates pre-deploy tokens — acceptable
(`@max_age` = 30 min, minted at click time). Grep all `EditorHandoff.sign` call sites/test fixtures
before the rewrite; any signing without the marker now hits the gate.

---

### `lib/cairnloop/knowledge_base.ex` — `list_articles(opts \\ [])` (D-09, D-10)

**Analog:** `KnowledgeAutomation.list_gap_candidates/1` (knowledge_automation.ex:40-50) — the
canonical opts-list-read. It uses the shared `apply_scope/2` + `maybe_filter_status/2` helpers
(knowledge_automation.ex:1940 / 1946):
```elixir
def list_gap_candidates(opts \\ []) do
  GapCandidate
  |> apply_scope(opts)
  |> maybe_filter_status(opts)
  |> order_by([candidate], desc: candidate.score, desc: candidate.last_seen_at, desc: candidate.id)
  |> repo().all()
end
```
**Apply to `list_articles/1`** — `KnowledgeBase` already has `import Ecto.Query` (knowledge_base.ex:2)
and `repo/0` (5-7). Article has NO tenant fields yet, so substitute `apply_scope` with a status-only
`maybe_filter_article_status/2` (scope opts accepted/ignored), keep `order_by(...) |> repo().all()`
(RESEARCH Pattern 3):
```elixir
def list_articles(opts \\ []) do
  Article
  |> maybe_filter_article_status(opts)
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
**Then rewire `Index.mount/3`** (index.ex:10-13) from `repo().all(Article)` to
`KnowledgeBase.list_articles(scope_filters(session))` (arch invariant #5).

---

### `lib/cairnloop/knowledge_automation.ex` — `record_editor_handoff/2` (write, D-05) + `get_gap_candidate/2` (read, D-07)

**Analog (write):** the established suggestion-write shape — `now_fn(opts).()` →
`get_article_suggestion!(suggestion_id, opts)` (bang load, knowledge_automation.ex:72-78) → schema
changeset → `repo().update()`. The thin field-scoped wrappers `ArticleSuggestion.dismiss_changeset/2`
/ `regenerate_changeset/1` (article_suggestion.ex:89-102) are the precedent for the new changeset:
```elixir
# article_suggestion.ex:89-94 — the wrapper-changeset precedent to mirror
def dismiss_changeset(article_suggestion, dismissed_at) do
  changeset(article_suggestion, %{status: :dismissed, dismissed_at: dismissed_at})
end
```
**CAUTION (verified):** do NOT model on `mark_review_task_material_edit/2` (knowledge_automation.ex:338-395)
— it is a heavyweight status transition (`load_review_task_with_suggestion` + status gating +
`update_task_with_event` + `ReviewTask.decision_changeset`), NOT a simple timestamp write. There is
no narrow `material_edit_changeset` on `ReviewTask`.

**Apply to `record_editor_handoff/2`**:
```elixir
def record_editor_handoff(suggestion_id, opts \\ []) do
  now = now_fn(opts).()
  suggestion = get_article_suggestion!(suggestion_id, opts)

  suggestion
  |> ArticleSuggestion.manual_edit_changeset(now)   # ADD wrapper-changeset (additive, see below)
  |> repo().update()
end
```
`now_fn/1` (knowledge_automation.ex:1663): `defp now_fn(opts), do: Keyword.get(opts, :now_fn, &DateTime.utc_now/0)`.
**Changeset choice (verified):** `ArticleSuggestion.changeset/2` (article_suggestion.ex:48-87) casts
`:manual_edit_opened_at` (line 68) but re-runs heavy `validate_required([:stable_key, :suggestion_type,
:status, :tenant_scope, :entrypoint_type, :entrypoint_id, :proposed_markdown, :grounding_metadata])`
(71-80) plus `validate_anchor_rules`/`validate_quick_fix_metadata` (83-86). A persisted suggestion
satisfies these, so the full `changeset/2` works — but per RESEARCH Pitfall 2 and the
`dismiss_changeset` wrapper pattern, add a dedicated `manual_edit_changeset(suggestion, at)` (additive,
casts only `:manual_edit_opened_at`, no incidental re-validation). **Idempotency (RESEARCH Open Q2):**
overwrite on each open (refresh to latest) — simplest, satisfies the auditable-marker intent.

**Analog (read):** `get_gap_candidate!/2` (knowledge_automation.ex:52-62) is the bang sibling — note
the `apply_scope` + `enforce_scope!` + `preload(:memberships)` + `hydrate_memberships` chain:
```elixir
def get_gap_candidate!(id, opts \\ []) do
  candidate =
    GapCandidate
    |> apply_scope(opts)
    |> where([candidate], candidate.id == ^id)
    |> preload(:memberships)
    |> repo().one!()
    |> enforce_scope!(opts, GapCandidate)

  hydrate_memberships(candidate)
end
```
**Apply to non-bang `get_gap_candidate/2` (D-07)** — wrap the bang sibling (RESEARCH Pattern 3):
```elixir
def get_gap_candidate(id, opts \\ []) do
  get_gap_candidate!(id, opts)
rescue
  Ecto.NoResultsError -> nil
end
```

---

### `lib/cairnloop/web/knowledge_base_live/index.ex` — kb_nav + `new_article` event + `list_articles` (D-10, D-11, D-12)

**Analog:** self — `handle_event("suggest_revision", ...)` is the facade-call → navigate/flash template.

**Existing event pattern** (index.ex:15-40, abridged):
```elixir
def handle_event("suggest_revision", %{"article_id" => article_id}, socket) do
  ...
  case knowledge_automation().suggest_revision(attrs) do
    {:ok, suggestion} -> ... push_navigate(socket, to: "/knowledge-base/suggestions?task=#{task.id}") ...
    {:error, _reason} -> {:noreply, put_flash(socket, :error, "Unable to create the revision suggestion right now.")}
  end
end
```
**Apply to `new_article` (D-12)** — `KnowledgeBase.create_article/1` already exists
(knowledge_base.ex:65-69, `%Article{} |> Article.changeset(attrs) |> repo().insert()`):
```elixir
def handle_event("new_article", _params, socket) do
  case KnowledgeBase.create_article(%{title: "Untitled article", status: :draft}) do
    {:ok, article} -> {:noreply, push_navigate(socket, to: "/knowledge-base/#{article.id}/edit")}
    {:error, _changeset} -> {:noreply, put_flash(socket, :error, "Unable to create the article right now. Try again.")}
  end
end
```
**`mount/3`** (index.ex:10-13): swap `repo().all(Article)` → `KnowledgeBase.list_articles(scope_filters(session))`;
add `alias Cairnloop.KnowledgeBase`. **Render** (42-62): add `<.kb_nav current={:index} />` and the
"New article" button (`phx-click="new_article"`, label `"New article"`, brand-token styles per
UI-SPEC §2 — bare `var(--cl-primary)` / `var(--cl-primary-text)`, `min-height: 44px`,
`phx-click-loading` disabled state).

---

### `lib/cairnloop/web/knowledge_base_live/editor.ex` — gap sidebar + mount rescue (D-06, D-07, D-08, D-11)

**Analog:** self — existing `mount/3` (12-32) and `load_suggestion/3` (94-102).

**Existing `mount/3`** (editor.ex:12-32) — wrap the body in `try/rescue` (D-06). Both
`repo().get!(Article, id)` (line 15) and `load_suggestion/3` (17) already raise `Ecto.NoResultsError`;
the rescue catches gate failures. Preserve the existing assign-chain (22-31) and extend with
`gap_candidate`:
```elixir
def mount(params, session, socket) do
  id = (is_map(params) && params["id"]) || session["id"]
  scope_filters = scope_filters(session)
  article = repo().get!(Article, id)
  latest_revision = KnowledgeBase.get_latest_revision(id)
  suggestion = load_suggestion(params, scope_filters, article.id)
  ...
  {:ok, socket}   # existing assign-chain
end
```
**Existing `load_suggestion/3`** (editor.ex:94-102) — already calls `EditorHandoff.verify!/2` BEFORE
preloading (the SEC-02 enforcement point; strengthened by the verify!/2 rewrite, no change here):
```elixir
defp load_suggestion(%{"suggestion_id" => suggestion_id} = params, scope_filters, article_id) do
  :ok = EditorHandoff.verify!(params, article_id)
  suggestion_id |> normalize_id() |> knowledge_automation().get_article_suggestion!(scope_filters)
end

defp load_suggestion(_params, _scope_filters, _article_id), do: nil
```
**Add (D-06 rescue)** — calm flash + redirect (exact UI-SPEC copy):
```elixir
rescue
  Ecto.NoResultsError ->
    {:ok,
     socket
     |> put_flash(:error, "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing.")
     |> push_navigate(to: "/knowledge-base/suggestions")}
end
```
**Add (D-07 derivation)** — VERIFIED schema: `entrypoint_type` is `Ecto.Enum` with values
`[:gap_candidate, :article_revision, :conversation_quick_fix]` (article_suggestion.ex:9, 29),
`entrypoint_id` is `:integer` (line 30). Match `:gap_candidate`:
```elixir
defp load_gap_candidate_from_suggestion(nil, _), do: nil
defp load_gap_candidate_from_suggestion(suggestion, scope_filters) do
  case {suggestion.entrypoint_type, suggestion.entrypoint_id} do
    {:gap_candidate, gid} when is_integer(gid) -> knowledge_automation().get_gap_candidate(gid, scope_filters)
    _ -> nil
  end
end
```
**Add (D-08)** `assign(socket, :gap_candidate, gap_candidate)` + template `<%= if @gap_candidate do %>`
read-only sidebar (UI-SPEC §KB-03; bare brand tokens). Reuse `knowledge_automation/0` (168-170),
`scope_filters/1` (181-189), `normalize_id/1` (172-179). Add `<.kb_nav current={:editor} />` to
`render/1` (225-263).

---

### `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — record_editor_handoff + marker-bearing sign (D-01, D-04, D-11)

**Analog:** self — existing `handle_event("open_for_manual_edit", ...)` (138-174).

**Existing handler** (suggestion_review.ex:138-174) — insert the DB write before `sign`, add the opt:
```elixir
def handle_event("open_for_manual_edit", %{"id" => task_id}, socket) do
  {:ok, task, suggestion} = load_task_selection(task_id, socket)
  target_article_id = if suggestion.suggestion_type == :revision do ... end
  return_to = task.id |> task_patch(socket.assigns.queue_filter) |> URI.encode_www_form()

  handoff_token =
    EditorHandoff.sign(suggestion.id, target_article_id, task.id, URI.decode_www_form(return_to))

  {:noreply, push_navigate(socket, to: "/knowledge-base/#{target_article_id}/edit?suggestion_id=#{suggestion.id}" <>
    "&review_task_id=#{task.id}&return_to=#{return_to}&handoff=#{URI.encode_www_form(handoff_token)}")}
end
```
**Add (D-01 DB write)** before sign — mirrors the existing
`knowledge_automation().<fn>(suggestion.id, socket.assigns.scope_filters)` shape used throughout
this file (e.g. `regenerate` lines 62-65, `dismiss` 76-79):
```elixir
{:ok, _suggestion} =
  knowledge_automation().record_editor_handoff(suggestion.id, socket.assigns.scope_filters)
```
**Modify sign (D-04)** add the marker opt as an ISO8601 STRING (Pitfall 3 — `:utc_datetime_usec`
is not term-safe for signing):
```elixir
EditorHandoff.sign(
  suggestion.id, target_article_id, task.id, URI.decode_www_form(return_to),
  manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
)
```
**Add** `<.kb_nav current={:suggestions} />` to `render/1` (176-306). `knowledge_automation/0`
(410-412), `scope_filters/1` (418-426) already present.

---

### `lib/cairnloop/web/knowledge_base_live/gaps.ex` — kb_nav only (D-11)

**Analog:** self — minimal change. Existing `render/1` `~H` block opens at gaps.ex:60. Add
`<.kb_nav current={:gaps} />` at the top of the block; import the nav component. No event/state
changes (read-only surface). `scope_filters/1` (142-150), `knowledge_automation/0` (138-140) present.

---

### `lib/cairnloop/web/review_task_presenter.ex` — extend `action_label/2` copy variants (D-13, KB-04)

**Analog:** self — existing `action_label/1` (single atom, 194-198) + `action_label/2`
(action + task, 200-208). **IMPORTANT (verified): the 2-arity ALREADY does a quick-fix branch** — so
KB-04 EXTENDS existing 2-variant logic, it does not introduce it from scratch.

**Existing** (review_task_presenter.ex:194-208):
```elixir
def action_label(:approve), do: "Approve"
def action_label(:reject), do: "Reject"
def action_label(:defer), do: "Defer"
def action_label(:publish), do: "Publish"
def action_label(:open_for_edit), do: "Open for edit"

def action_label(action, %ReviewTask{article_suggestion: suggestion})
    when not is_nil(suggestion) do
  case {action, ArticleSuggestionPresenter.quick_fix_outcome_label(suggestion)} do
    {:open_for_edit, "Manual draft required"} -> "Open manual draft"
    _ -> action_label(action)
  end
end

def action_label(action, _task), do: action_label(action)
```
**Call site** (suggestion_review.ex:352-353) passes the full task:
`{"open_for_manual_edit", ReviewTaskPresenter.action_label(:open_for_edit, task)}`.

**Modify (D-13)** — adjust the existing `case` to the UI-SPEC §KB-04 3 variants. Current outputs
differ from UI-SPEC targets:
- default `:open_for_edit` is `"Open for edit"` (line 198) → UI-SPEC wants `"Open for manual edit"`;
- the existing `"Manual draft required"` branch yields `"Open manual draft"` → UI-SPEC wants
  `"Create manual draft"` (and likely a `:failed` → `"Review and draft manually"` variant).
Keep the `action_label/1` clauses (except the `:open_for_edit` default string) and the
`def action_label(action, _task), do: action_label(action)` fallback (line 208) untouched.
**Predicate confirmation (RESEARCH Open Q1 / A3):** the `quick_fix_outcome_label(suggestion) ==
"Manual draft required"` mapping is CONFIRMED in-tree (line 203). Still read
`lib/cairnloop/web/article_suggestion_presenter.ex` to confirm the `:failed`/`suggestion_type`
predicate for the 3rd variant. VERIFIED: `suggestion_type` enum is `[:article, :revision]`
(article_suggestion.ex:8) — there is NO `:new_article`; map UI-SPEC's `:new_article` to `:article`.
Pitfall 6: no `String.to_atom` on user input.

---

### `lib/cairnloop/web/knowledge_base_live/nav_component.ex` (NEW, D-11)

No in-tree KB precedent for a `Phoenix.Component` function component with typed `attr`. Use
RESEARCH Pattern 1 as the template. See "No Analog Found".

---

## Shared Patterns

### Facade-reads-only from the web layer (arch invariant #5)
**Source:** `KnowledgeAutomation.list_gap_candidates/1` (knowledge_automation.ex:40-50) +
`get_gap_candidate!/2` (52-62) — opts-list/get with `apply_scope/2` (line 1940), shared
`maybe_filter_status/2` (1946), and `enforce_scope!/3` (2113).
**Apply to:** `KnowledgeBase.list_articles/1`, `KnowledgeAutomation.get_gap_candidate/2`, and
`Index.mount/3` (replaces `repo().all(Article)` at index.ex:11).
```elixir
GapCandidate |> apply_scope(opts) |> maybe_filter_status(opts) |> order_by(...) |> repo().all()
```

### DB write through the facade returning a tagged tuple, via a wrapper changeset
**Source:** the suggestion-write shape `now_fn(opts).()` → `get_article_suggestion!(id, opts)` (bang
load, knowledge_automation.ex:72-78) → schema changeset → `repo().update()`. The
`ArticleSuggestion.dismiss_changeset/2` / `regenerate_changeset/1` wrappers (article_suggestion.ex:89-102)
are the field-scoped-changeset precedent.
**AVOID:** `mark_review_task_material_edit/2` (knowledge_automation.ex:338-395) as the analog — it is a
heavyweight status transition (`load_review_task_with_suggestion` + `update_task_with_event` +
`decision_changeset`), NOT a simple timestamp write.
**Apply to:** `KnowledgeAutomation.record_editor_handoff/2` (auditable T-10-09 write) + a new
`ArticleSuggestion.manual_edit_changeset/2` mirroring `dismiss_changeset/2`. Reuse `now_fn/1`
(knowledge_automation.ex:1663) for test-pinnable timestamps.

### Signed-token integrity primitive (never hand-roll HMAC)
**Source:** `KnowledgeAutomation.EditorHandoff` (editor_handoff.ex:7-21) — `Plug.Crypto.sign/4` +
`verify/4` with `@salt` + `@max_age 1800`.
**Apply to:** new domain `decode/1` (same `Plug.Crypto.verify` call) and the web `verify!/2`
rewrite. DateTime marker = ISO8601 STRING in the token (Pitfall 3); DB column stays a `DateTime`.

### Brand-compliant flash + presenter-first copy
**Source:** brand book §5.5/§5.6; existing flash idiom (e.g. index.ex:33, gaps.ex:50/55,
suggestion_review.ex:69/82). Fixed strings, never raw atoms / `inspect/1`.
**Apply to:** Editor gate flash = exact UI-SPEC copy (D-06); new-article error
"Unable to create the article right now. Try again." (D-12); button labels via `ReviewTaskPresenter`.

### Bare brand tokens in new render code (Phase 29 BRAND-04 gate)
**Source:** Phase 29 BRAND-04 negative-grep gate — `grep -rE 'var\(--cl-[a-z-]+, #' lib/cairnloop/web/`
must return nothing (`test/cairnloop/web/brand_token_gate_test.exs` enforces this).
**Apply to:** all new `style=` in nav_component, editor sidebar, index "New article" button. Bare
`var(--cl-primary)` etc. — NO hex fallback. Verified tokens in `examples/.../app.css`:
`--cl-bg/surface/surface-raised/primary/primary-text/danger/ai/success/info/warning/text/text-muted/border/focus/radius-sm/md/lg`.
Active nav marker via `aria-current="page"` + primary border — never color-alone (brand §7.5).

### Scope-filters threading + Mock-injection test seams (no live Repo needed)
**Source:** identical `scope_filters/1` private helper in all 4 LiveViews (editor.ex:181-189,
index.ex:68-76, suggestion_review.ex:418-426, gaps.ex:142-150) + `knowledge_automation/0` / `repo/0`
seams. Test pattern: `test/cairnloop/web/knowledge_base_live_test.exs` defines `MockRepo` (lines 7-57:
`all(Article)` returns a fixed list, `get!(Article, id)` matches `"42"` or raises
`Ecto.NoResultsError`, `one/1` reads `Process.get(:mock_repo_one_lookup|:mock_repo_one_result)`,
`insert/2` + `update/2` `apply_changes`) and `MockKnowledgeAutomation` (59-) wired via
`Application.put_env` with `on_exit` restore.
**Apply to:** every new facade call threads `scope_filters`. New behaviors test against
`MockRepo`/`MockKnowledgeAutomation`; presenter/`decode`/`verify!` tests are pure (no Repo). Mark
genuine Postgres round-trips `# REPO-UNAVAILABLE`.

## No Analog Found

| File | Role | Data Flow | Reason / Template |
|------|------|-----------|-------------------|
| `lib/cairnloop/web/knowledge_base_live/nav_component.ex` | component (function component) | request-response | No in-tree KB `Phoenix.Component` with typed `attr`. Use RESEARCH Pattern 1: `use Phoenix.Component`, `attr :current, :atom, required: true`, `def kb_nav/1` + private `kb_nav_link/1`; active via `aria-current={if @active, do: "page"}` + primary border (never color-alone, brand §7.5); bare brand tokens. Nav links: Knowledge base / Suggestions / Gaps only — `:editor` renders no active marker (Editor has no top-level nav entry; Assumption A5). |
| `test/.../nav_component_test.exs` | test (pure render) | request-response | Wave-0 new file; no nav-render test precedent. Pure `Phoenix.LiveViewTest`/`lazy_html` assertions: 3 links, active marker, `aria-current`, no-color-alone. |
| `test/.../editor_handoff_test.exs` | test (pure) | transform | Does not exist (confirmed: `test/cairnloop/web/knowledge_base_live/` holds only `gaps_test.exs`, `suggestion_review_test.exs`). Wave-0 new file: pure ExUnit on `decode/1` round-trip + `verify!/2` marker-gate (no Repo). Set `Application.put_env(:cairnloop, EditorHandoff, secret_key_base: "...")` so signing is deterministic. |
| `test/.../review_task_presenter_test.exs` | test (pure) | transform | Wave-0 new file. Closest idiom: `test/cairnloop/web/tool_proposal_presenter_test.exs` (existing presenter-pure test). Assert the 3 calm `action_label(:open_for_edit, task)` variants; never raw atoms. |

## Metadata

**Analog search scope:** `lib/cairnloop/web/knowledge_base_live/`, `lib/cairnloop/knowledge_base.ex`,
`lib/cairnloop/knowledge_automation.ex`, `lib/cairnloop/knowledge_automation/{editor_handoff,article_suggestion}.ex`,
`lib/cairnloop/web/review_task_presenter.ex`, `test/cairnloop/web/`.
**Files scanned:** 11 source + 4 test (read fully or via line-verified targeted ranges).
**Skills:** none found (`.claude/skills/`, `.agents/skills/` absent).
**Verified corrections vs. RESEARCH/CONTEXT citations (planner: prefer these):**
- The gap-candidate facade fns live DIRECTLY in `knowledge_automation.ex` (`list_gap_candidates/1`
  40-50, `get_gap_candidate!/2` 52-62) — there is NO `gap_candidates.ex` submodule.
- `list_gap_candidates/1` uses the shared `maybe_filter_status/2` (line 1946), not an inline
  `where status == :open`; `get_gap_candidate!/2` adds `enforce_scope!` + `preload(:memberships)` +
  `hydrate_memberships`.
- `now_fn/1` (line 1663) = `Keyword.get(opts, :now_fn, &DateTime.utc_now/0)`.
- `mark_review_task_material_edit/2` (line 338) is a heavyweight status-transition, NOT a
  narrow-changeset write — use the `dismiss_changeset` wrapper shape as the write analog; there is no
  `ReviewTask.material_edit_changeset`.
- `entrypoint_type` enum = `[:gap_candidate, :article_revision, :conversation_quick_fix]`
  (article_suggestion.ex:9); `suggestion_type` = `[:article, :revision]` (no `:new_article`).
- `ReviewTaskPresenter.action_label/2` (200-208) ALREADY has a quick-fix branch
  (`"Manual draft required"` → `"Open manual draft"`); KB-04 EXTENDS this rather than introducing it,
  and must change the default `:open_for_edit` copy from `"Open for edit"` to `"Open for manual edit"`.
**Constraints honored:** CLAUDE.md sealed-contract/additive posture, facade-reads-only,
presenter-first copy, bare brand tokens, warnings-clean. No source modified — PATTERNS.md is the
only file written.
**Pattern extraction date:** 2026-05-28
