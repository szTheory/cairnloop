defmodule Cairnloop.Web.BreadcrumbPresenter do
  @moduledoc """
  Pure, total presenter building `cl_breadcrumb` items lists for the KB editor and
  suggestion_review screens (SHELL-02).

  Mirrors `AuditLogPresenter`/`ToolProposalPresenter`/`ReviewTaskPresenter`:
  - Total functions with safe fallbacks — never crashes on unexpected input.
  - Returns data only — never markup, never raw Elixir terms, no database calls.

  The `return_to` path is already verified upstream (decoded from a signed `handoff` token
  at `editor.ex:147,207-214`) before it ever reaches this presenter. This module renders
  only a DERIVED label from the path shape — never the raw path as a crumb label — honoring
  the operator copy rule ("never raw paths/terms to operators") and ASVS V5 output encoding
  (T-38-05).

  Each `items` list satisfies the `cl_breadcrumb` contract:
  - All non-last items carry the `:href` key.
  - The last item OMITS the `:href` key entirely (not `href: nil` — key absent).

  Cross-references: `Cairnloop.Web.Components.cl_breadcrumb/1` (items contract),
  `audit_log_presenter.ex` (presenter idiom).
  """

  # ---------------------------------------------------------------------------
  # editor_items/3 — origin-conversation crumb variant (Phase 42 THREAD-03b)
  # ---------------------------------------------------------------------------

  @doc """
  Builds the `cl_breadcrumb` items list for the KB editor when an originating
  conversation id is available (Phase 42 cross-screen threading).

  When `origin_conversation_id` is a non-nil integer (article originated from a
  `:conversation_quick_fix`), prepends a `%{label: "From conversation", href: "/\#{id}"}`
  crumb as the first item, followed by the standard `editor_items/2` crumbs for
  the given `return_to` and `title`.

  When `origin_conversation_id` is nil (gap/revision-originated article — honest
  absence, D-12), returns exactly the `editor_items/2` output — no extra crumb.

  The origin crumb href is scope-root-relative (`/\#{id}`) — never mount-prefixed
  (Pitfall 3, T-42-15). The raw conversation id appears only in the href, not as a label.

  WR-06: when `return_to` is itself a bare conversation path pointing at the SAME origin
  (`"/\#{origin_conversation_id}"`), the delegated `editor_items/2` would emit a second
  "Conversation" crumb targeting the same id — a redundant double-crumb. In that case the
  origin crumb is collapsed into the delegated trail (no duplicate). In production the
  quick-fix `return_to` is always a `/knowledge-base/suggestions?...` path, so this is a
  defensive de-duplication rather than a hot path.
  """
  def editor_items(origin_conversation_id, return_to, title)
      when not is_nil(origin_conversation_id) do
    if return_to == "/#{origin_conversation_id}" do
      # return_to already points at the origin conversation — don't duplicate the crumb.
      editor_items(return_to, title)
    else
      [
        %{label: "From conversation", href: "/#{origin_conversation_id}"}
        | editor_items(return_to, title)
      ]
    end
  end

  def editor_items(nil, return_to, title) do
    editor_items(return_to, title)
  end

  # ---------------------------------------------------------------------------
  # editor_items/2 — origin-aware breadcrumb for the KB editor
  # ---------------------------------------------------------------------------

  @doc """
  Builds the `cl_breadcrumb` items list for the KB editor (`editor.ex`).

  When `return_to` is a binary path (signed-token-derived, already verified upstream):
  - Derives the origin label from the path shape:
    - `"/knowledge-base/…"` → `"Suggestions"`
    - any other path (e.g. `"/42"`) → `"Conversation"`
  - Returns a 3-item list:
    `[%{label: origin, href: return_to}, %{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: <title>"}]`

  When `return_to` is `nil` or any non-binary (no verified origin available):
  - Returns the 2-item static fallback:
    `[%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Editing: <title>"}]`

  The last item always omits `:href` (current crumb per `cl_breadcrumb` contract).
  The raw `return_to` path is NEVER used as a label.
  """
  def editor_items(return_to, title) when is_binary(return_to) do
    origin =
      if String.starts_with?(return_to, "/knowledge-base"),
        do: "Suggestions",
        else: "Conversation"

    [
      %{label: origin, href: return_to},
      %{label: "Knowledge", href: "/knowledge-base"},
      %{label: "Editing: #{title}"}
    ]
  end

  def editor_items(_return_to, title) do
    [
      %{label: "Knowledge", href: "/knowledge-base"},
      %{label: "Editing: #{title}"}
    ]
  end

  # ---------------------------------------------------------------------------
  # suggestions_items/1 — static lane breadcrumb for suggestion_review
  # ---------------------------------------------------------------------------

  @doc """
  Builds the `cl_breadcrumb` items list for the KB suggestion_review screen.

  When `task_title` is `nil` or a blank string (no task selected or no title available):
  - Returns the 2-item static lane crumbs:
    `[%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Suggestions"}]`

  When `task_title` is a non-blank binary (a review-task title is available):
  - Returns a 3-item list making "Suggestions" a back link:
    `[%{label: "Knowledge", href: "/knowledge-base"}, %{label: "Suggestions", href: "/knowledge-base/suggestions"}, %{label: task_title}]`

  The last item always omits `:href` (current crumb per `cl_breadcrumb` contract).

  Note: `suggestion_review.ex` does NOT receive a conversation `return_to` — it is a
  review-lane index, not a receiver of a `handoff` token. This presenter does NOT invent
  a conversation→suggestion_review handoff (that cross-screen threading lands in Phase 42).
  """
  def suggestions_items(task_title) when is_binary(task_title) and task_title != "" do
    [
      %{label: "Knowledge", href: "/knowledge-base"},
      %{label: "Suggestions", href: "/knowledge-base/suggestions"},
      %{label: task_title}
    ]
  end

  def suggestions_items(_task_title) do
    [
      %{label: "Knowledge", href: "/knowledge-base"},
      %{label: "Suggestions"}
    ]
  end
end
