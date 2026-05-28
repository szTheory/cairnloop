---
phase: 30-kb-editorial-polish-t-10-09-t-10-11-closure
reviewed: 2026-05-28T00:00:00Z
depth: standard
files_reviewed: 20
files_reviewed_list:
  - lib/cairnloop/knowledge_automation.ex
  - lib/cairnloop/knowledge_automation/article_suggestion.ex
  - lib/cairnloop/knowledge_automation/editor_handoff.ex
  - lib/cairnloop/knowledge_base.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/knowledge_base_live/editor.ex
  - lib/cairnloop/web/knowledge_base_live/editor_handoff.ex
  - lib/cairnloop/web/knowledge_base_live/gaps.ex
  - lib/cairnloop/web/knowledge_base_live/index.ex
  - lib/cairnloop/web/knowledge_base_live/nav_component.ex
  - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
  - lib/cairnloop/web/review_task_presenter.ex
  - test/cairnloop/knowledge_automation_test.exs
  - test/cairnloop/knowledge_base_test.exs
  - test/cairnloop/web/conversation_live_test.exs
  - test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs
  - test/cairnloop/web/knowledge_base_live/nav_component_test.exs
  - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
  - test/cairnloop/web/knowledge_base_live_test.exs
  - test/cairnloop/web/review_task_presenter_test.exs
findings:
  critical: 4
  warning: 5
  info: 3
  total: 12
status: issues_found
---

# Phase 30: Code Review Report

**Reviewed:** 2026-05-28
**Depth:** standard
**Files Reviewed:** 20
**Status:** issues\_found

## Summary

Phase 30 delivers the KB editorial nav shell, "New article" affordance, gap evidence sidebar,
`EditorHandoff` token-and-DB gate (T-10-09/T-10-11 closure), and `KnowledgeBase.list_articles/1`.
The overall structure follows established project patterns and the dual-layer handoff gate is
correctly wired. However, four distinct defects are present that require attention before the
phase can be considered shippable.

---

## Critical Issues

### CR-01: Ephemeral in-process secret invalidates all handoff tokens on node restart / new deploy

**File:** `lib/cairnloop/knowledge_automation/editor_handoff.ex:59-67`

**Issue:** When no `secret_key_base` is configured, the module falls back to generating a
random 48-byte secret and storing it via `:persistent_term`. `:persistent_term` is process-local
to the BEAM node and is lost on every restart (including rolling deploys). Any in-flight handoff
token that was signed before the restart will fail `Token.decode/1` after the restart, sending
editors to the flash-error redirect path instead of opening the article. In a clustered
deployment, nodes will each have different secrets and tokens signed by node A will be rejected
by node B. This was intended as a safe fallback for tests, but it silently degrades security
guarantees in staging/production when the config key is not set.

**Fix:** Require the `secret_key_base` config key to be explicitly set in non-test environments,
and raise a clear startup error when it is absent. Remove the `:persistent_term` fallback, or
restrict it explicitly to `:test` environment only with a compile-time guard:

```elixir
defp secret_key_base do
  case Application.get_env(:cairnloop, __MODULE__, [])[:secret_key_base] do
    value when is_binary(value) and byte_size(value) > 0 ->
      value

    _ ->
      if Mix.env() == :test do
        # test-only: stable per-process random key
        key = {__MODULE__, :secret_key_base}
        case :persistent_term.get(key, nil) do
          nil ->
            value = Base.url_encode64(:crypto.strong_rand_bytes(48), padding: false)
            :persistent_term.put(key, value)
            value
          value -> value
        end
      else
        raise """
        Cairnloop.KnowledgeAutomation.EditorHandoff requires a stable secret_key_base.
        Configure it in config/runtime.exs:
          config :cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff,
            secret_key_base: System.fetch_env!("CAIRNLOOP_HANDOFF_SECRET_KEY_BASE")
        """
      end
  end
end
```

---

### CR-02: `open_for_manual_edit` bare-match crash on DB/scope error

**File:** `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:141` and `157`

**Issue:** Two consecutive bare pattern matches (`= load_task_selection/2` and
`= knowledge_automation().record_editor_handoff/2`) use `{:ok, ...} = ...` without error
handling. If either the `get_review_task!/2` bang function raises (e.g., stale ID after a race
condition or scope mismatch), or if `record_editor_handoff/2` returns `{:error, _}` (e.g., a
DB write failure), the LiveView process will crash with a `MatchError` rather than displaying a
user-facing flash message and staying on the page.

The `regenerate` and `dismiss` handlers correctly use `with ... else _ -> put_flash(...)`.
`open_for_manual_edit` does not.

**Fix:**

```elixir
def handle_event("open_for_manual_edit", %{"id" => task_id}, socket) do
  with {:ok, task, suggestion} <- load_task_selection(task_id, socket),
       {:ok, _suggestion} <-
         knowledge_automation().record_editor_handoff(
           suggestion.id,
           socket.assigns.scope_filters
         ) do
    target_article_id = resolve_target_article_id(suggestion, socket)
    # ... sign token and push_navigate as before
  else
    _ ->
      {:noreply,
       put_flash(socket, :error, "Unable to open the editor right now. Try again.")}
  end
end
```

Similarly, the inner `{:ok, article_id} = create_or_reuse_authoring_article_for_suggestion/2`
bare match at line 147-154 will crash if that call returns `{:error, _}`. Wrap in the same
`with` chain.

---

### CR-03: `return_to` URL parameter accepted without validation — open redirect risk

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:150` and `lib/cairnloop/web/knowledge_base_live/editor.ex:269`

**Issue:** The `return_to` parameter is read directly from URL params and placed into a
`<.link navigate={@review_context.return_to}>` LiveView navigation link without any validation
that it is a relative path. An attacker who crafts a URL of the form
`/knowledge-base/42/edit?suggestion_id=...&handoff=...&return_to=https://evil.example.com`
can make the "Return to review task" link navigate the operator to an external site after
completing an edit. While `<.link navigate=...>` uses Phoenix's internal router and LiveView
navigation (which requires a matching route), a sufficiently crafted JavaScript URL or
`//evil.example.com` path-relative form could still redirect outside the expected domain.

The handoff token does include `return_to` in the signed payload and `verify!/2` checks that it
matches — but the `return_to` value in the token was itself sourced from
`URI.encode_www_form(return_path)` of a server-computed path (in `SuggestionReview`), so the
signing path is safe. However, the `Editor.load_review_context/4` at line 150 reads `return_to`
directly from `params` without consulting the token:

```elixir
return_to: Map.get(params, "return_to", "/knowledge-base/suggestions?task=#{task.id}"),
```

This means a `return_to` param that was NOT in the signed token (i.e., a URL-level injection
bypassing the token check for the return_to field) can still end up rendered in the link.

**Fix:** After `verify!/2` succeeds, read `return_to` from the decoded token payload rather than
from raw URL params. The token already carries the server-authorised `return_to` value:

```elixir
# After Token.decode succeeds, extract return_to from payload:
return_to: verified_return_to_from_token(params) ||
             "/knowledge-base/suggestions?task=#{task.id}"

defp verified_return_to_from_token(%{"handoff" => token}) do
  case Cairnloop.KnowledgeAutomation.EditorHandoff.decode(token) do
    {:ok, %{"return_to" => rt}} when is_binary(rt) -> rt
    _ -> nil
  end
end
defp verified_return_to_from_token(_), do: nil
```

At minimum, enforce that `return_to` starts with `"/"` before rendering the link.

---

### CR-04: `queue_filter_status/1` in `ReviewTaskPresenter` calls `String.to_existing_atom` on user-controlled URL query param

**File:** `lib/cairnloop/web/review_task_presenter.ex:26`

**Issue:** `String.to_existing_atom/1` raises `ArgumentError` if the string does not correspond
to an already-loaded atom. The `"queue"` URL parameter value in
`SuggestionReview.handle_params/3` (line 28) is attacker-controlled. Any string sent as the
`queue=` query param that is not already a loaded atom (e.g., `queue=aaaaaaaaaaaaaaaaaaaaaa`)
will crash the `handle_params` callback with an `ArgumentError`, which Phoenix will surface as
a 500 error. Atom tables are also finite and while `to_existing_atom` does not create new atoms,
the crash path is still a denial-of-service vector (intentional or accidental).

**Fix:** Validate against the known bounded set before converting:

```elixir
@valid_queue_values Enum.map(@queue_filters, &elem(&1, 0))

def queue_filter_status("all"), do: nil

def queue_filter_status(value) when is_binary(value) do
  if value in @valid_queue_values do
    String.to_existing_atom(value)
  else
    nil  # Unknown queue filter treated as "all"
  end
end

def queue_filter_status(value), do: value
```

---

## Warnings

### WR-01: `normalize_id/1` in `Editor` accepts partial integer parses (e.g. "42abc" → 42)

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:199-204`

**Issue:** The `normalize_id` helper uses `{id, _}` — the wildcard remainder — when parsing
the `suggestion_id` and `review_task_id` URL params. This means `"42abc"` parses to integer 42.
The web `EditorHandoff` module's `normalize_integer/1` correctly uses `{id, ""}` (strict match
on empty remainder). The inconsistency means a URL parameter like `suggestion_id=15injected`
would silently be treated as suggestion 15 instead of being rejected, potentially passing the
handoff gate with an unexpected value if the token was signed for ID 15.

**Fix:** Use `{id, ""}` to require the entire string to be a valid integer:

```elixir
defp normalize_id(value) when is_binary(value) do
  case Integer.parse(value) do
    {id, ""} -> id
    _ -> value
  end
end
```

---

### WR-02: Timestamp skew between DB write and handoff token `manual_edit_opened_at`

**File:** `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:157-173` and
`lib/cairnloop/web/conversation_live.ex:174-191`

**Issue:** Both `open_for_manual_edit` (SuggestionReview) and `open_manual_draft`
(ConversationLive) call `record_editor_handoff/2` (which writes its own `DateTime.utc_now()`
timestamp to the DB) and then separately call `DateTime.utc_now() |> DateTime.to_iso8601()` to
populate the `manual_edit_opened_at` field in the signed token. Two `DateTime.utc_now()` calls
are made — one for the DB row and one for the token. The token's timestamp is therefore
systematically a few microseconds later than the DB row's timestamp. This causes the two
"manual_edit_opened_at" values — the one audited to the DB (T-10-09) and the one asserted in
the token (T-10-11) — to diverge slightly.

While `verify!/2` only checks that the token field is a non-empty binary (not an exact match
against the DB value), any future audit tooling that tries to correlate the two values will find
a mismatch. More importantly, the double-call pattern is a latent correctness risk: if the order
of operations is ever changed to sign the token first and write DB second, the token timestamp
could predate the DB row, which is semantically wrong.

**Fix:** Have `record_editor_handoff/2` return the exact timestamp it wrote to DB, and use that
value when building the token:

```elixir
# In KnowledgeAutomation.record_editor_handoff/2:
def record_editor_handoff(suggestion_id, opts \\ []) do
  now = now_fn(opts).()
  suggestion = get_article_suggestion!(suggestion_id, opts)
  case suggestion |> ArticleSuggestion.manual_edit_changeset(now) |> repo().update() do
    {:ok, updated} -> {:ok, updated, DateTime.to_iso8601(now)}
    error -> error
  end
end

# In SuggestionReview.open_for_manual_edit handler:
{:ok, _suggestion, opened_at_iso} =
  knowledge_automation().record_editor_handoff(suggestion.id, socket.assigns.scope_filters)

handoff_token = EditorHandoff.sign(..., manual_edit_opened_at: opened_at_iso)
```

---

### WR-03: `Editor.mount/3` calls `repo()` directly for article load — architecture invariant violation

**File:** `lib/cairnloop/web/knowledge_base_live/editor.ex:10-11` and `:18`

**Issue:** `Editor` defines `defp repo` and calls `repo().get!(Article, id)` at mount time.
The project architecture invariant (`CLAUDE.md`: "New reads go through the narrow `Cairnloop.Governance` facade, not direct schema queries from the web layer") and the Phase 30 context (D-09/D-10) explicitly require web LiveViews to use facade functions, not direct repo calls. `KnowledgeBase.get_article/1` already exists as the facade equivalent and would satisfy this requirement.

This also breaks test injection consistency: tests must inject both `:knowledge_automation` and `:repo` separately when testing the editor, whereas using the facade would require only `:knowledge_automation` and `:knowledge_base`.

**Fix:**

```elixir
# Remove defp repo/0 from editor.ex
# Replace:
article = repo().get!(Article, id)
# With:
article = KnowledgeBase.get_article!(id)
# (or add a bang variant to KnowledgeBase if get_article!/1 is missing)
```

---

### WR-04: `SuggestionReview.load_review_tasks/2` issues N+1 queries

**File:** `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:318-323`

**Issue:** `load_review_tasks/2` first calls `list_review_tasks/1` to get a list of tasks
(one query), then maps over every task and calls `get_review_task!/2` for each one individually.
`get_review_task!/2` in `KnowledgeAutomation` preloads `:article_suggestion` and `:events`
(line 128), making this an N+1 query pattern: 1 list query + N individual queries with
preloads. For a review queue with 50 tasks, this issues 51 database round-trips on every
mount/handle_params/reload cycle.

This is an architectural defect: `list_review_tasks/1` already knows all the IDs; the preloads
could be applied in a single `Repo.preload/2` call on the result list.

**Fix:** Either extend `list_review_tasks/1` to accept a `preload:` option and perform the
preloads in one pass, or use `Repo.preload/2` on the returned list:

```elixir
defp load_review_tasks(scope_filters, queue_filter) do
  scope_filters
  |> queue_filter_opts(queue_filter)
  |> knowledge_automation().list_review_tasks()
  # Use a single preload call instead of N individual get_review_task! calls
  |> repo().preload([:article_suggestion, :events])
end
```

(The web layer would need the `:repo` injection for this to remain testable — or the facade
could expose a `list_review_tasks_with_details/1` variant.)

---

### WR-05: Brand convention violation — `var(--cl-text-muted, rgba(...))` hex fallback in new render code

**File:** `lib/cairnloop/web/conversation_live.ex:802`

**Issue:** Phase 29 established a BRAND-04 gate: new render code must use bare `var(--cl-<token>)` — no inline hex/rgba fallbacks. Line 802 of `conversation_live.ex` was added or modified in Phase 30 and contains:

```
style="...; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));"
```

This violates the Phase 29 D-09 negative-grep gate which is enforced on `lib/cairnloop/web/`. The fallback `rgba(47, 36, 29, 0.62)` should be removed.

**Fix:**

```elixir
style="margin: 6px 0 0; font-size: 14px; line-height: 1.4; color: var(--cl-text-muted);"
```

---

## Info

### IN-01: `scope_filters(session)` called twice in `Index.mount/3`

**File:** `lib/cairnloop/web/knowledge_base_live/index.ex:8-9`

**Issue:** `scope_filters(session)` is called twice on consecutive lines — once to pass to
`list_articles/1` and once to store in the socket assign. The function parses session keys each
time. While not a correctness bug, it is an unnecessary double computation.

**Fix:**

```elixir
def mount(_params, session, socket) do
  scope_filters = scope_filters(session)
  articles = KnowledgeBase.list_articles(scope_filters)
  {:ok, assign(socket, articles: articles, scope_filters: scope_filters)}
end
```

---

### IN-02: `MockKnowledgeAutomation.mark_review_task_material_edit/3` in test has wrong arity

**File:** `test/cairnloop/web/knowledge_base_live_test.exs:126-129`

**Issue:** The mock defines `mark_review_task_material_edit(review_task_id, attrs, _opts \\ [])` with 3 positional args plus a default, but `Editor.maybe_mark_review_task_material_edit/2` calls `knowledge_automation().mark_review_task_material_edit(review_task.id, attrs)` with 2 args. The real facade `KnowledgeAutomation.mark_review_task_material_edit/2` has signature `(id, opts \\ [])` — the web layer passes `attrs` as `opts`, not as a separate argument. The mock's 3-arg form does not match the real signature. This means the test would pass with the wrong mock regardless of the real function's behaviour under certain edge cases. The `assert_received {:material_edit, 27, attrs}` assertion at line 568 checks what was sent, not what was called.

**Fix:** Align the mock signature with the real module:

```elixir
def mark_review_task_material_edit(review_task_id, opts) do
  send(self(), {:material_edit, review_task_id, opts})
  {:ok, Process.get(:mock_review_task)}
end
```

---

### IN-03: `record_editor_handoff/2` DB-write test does not cover scope isolation path

**File:** `test/cairnloop/knowledge_automation_test.exs:66-88`

**Issue:** The `record_editor_handoff/2` test uses a `MockRepo.one!/1` that returns whatever is
in the process dictionary, bypassing the `apply_scope/2` → `where` → `enforce_scope!` pipeline.
A tenant-scoped call `record_editor_handoff(15, tenant_scope: :host_user_scoped, host_user_id: "user_X")` is not verified to enforce scope. The test is marked `# REPO-UNAVAILABLE` which is the correct posture, but no in-process assertion validates that `apply_scope` / `enforce_scope!` would be applied correctly to the suggestion fetch within `record_editor_handoff`.

**Fix:** Add a test that verifies when `MockRepo.one!/1` returns a fixture with a mismatched `host_user_id`, `record_editor_handoff` raises `Ecto.NoResultsError` (via `enforce_scope!`). This does not require a live DB.

---

_Reviewed: 2026-05-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
