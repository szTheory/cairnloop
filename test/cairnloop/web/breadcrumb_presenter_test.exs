defmodule Cairnloop.Web.BreadcrumbPresenterTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Web.BreadcrumbPresenter, as: P

  # ---------------------------------------------------------------------------
  # Helper: assert the last-crumb contract on any returned items list
  # ---------------------------------------------------------------------------

  defp assert_last_crumb_contract(items) do
    assert length(items) >= 1, "items list must have at least 1 entry"
    # All non-last crumbs carry :href
    assert Enum.all?(Enum.drop(items, -1), &Map.has_key?(&1, :href)),
           "all non-last crumbs must have :href; got: #{inspect(Enum.drop(items, -1))}"
    # The last crumb OMITS :href (not href: nil — key must be absent)
    refute Map.has_key?(List.last(items), :href),
           "last crumb must NOT have :href key; got: #{inspect(List.last(items))}"
  end

  defp assert_no_raw_path_label(items, return_to) when is_binary(return_to) do
    labels = Enum.map(items, & &1.label)
    refute return_to in labels,
           "no crumb label should equal the raw return_to path; labels: #{inspect(labels)}"
  end

  defp assert_no_raw_path_label(_items, _return_to), do: :ok

  # ---------------------------------------------------------------------------
  # editor_items/2 — conversation origin (/42 shape)
  # ---------------------------------------------------------------------------

  describe "editor_items/2 with a conversation return_to (bare /N path)" do
    setup do
      %{return_to: "/42", title: "How to reset"}
    end

    test "returns 3 items", %{return_to: return_to, title: title} do
      items = P.editor_items(return_to, title)
      assert length(items) == 3
    end

    test "first crumb is 'Conversation' with the return_to as href", %{
      return_to: return_to,
      title: title
    } do
      [first | _] = P.editor_items(return_to, title)
      assert first.label == "Conversation"
      assert first.href == "/42"
    end

    test "second crumb is 'Knowledge' back-link to /knowledge-base", %{
      return_to: return_to,
      title: title
    } do
      [_, second | _] = P.editor_items(return_to, title)
      assert second.label == "Knowledge"
      assert second.href == "/knowledge-base"
    end

    test "last crumb is 'Editing: <title>' with NO :href key", %{
      return_to: return_to,
      title: title
    } do
      items = P.editor_items(return_to, title)
      last = List.last(items)
      assert last.label == "Editing: How to reset"
      refute Map.has_key?(last, :href)
    end

    test "satisfies the last-crumb contract", %{return_to: return_to, title: title} do
      assert_last_crumb_contract(P.editor_items(return_to, title))
    end

    test "no crumb label equals the raw return_to path", %{return_to: return_to, title: title} do
      assert_no_raw_path_label(P.editor_items(return_to, title), return_to)
    end
  end

  # ---------------------------------------------------------------------------
  # editor_items/2 — suggestions-lane return_to (/knowledge-base/... shape)
  # ---------------------------------------------------------------------------

  describe "editor_items/2 with a suggestions-lane return_to" do
    setup do
      %{return_to: "/knowledge-base/suggestions?task=7", title: "Refund policy"}
    end

    test "returns 3 items", %{return_to: return_to, title: title} do
      items = P.editor_items(return_to, title)
      assert length(items) == 3
    end

    test "first crumb is 'Suggestions' with the return_to as href", %{
      return_to: return_to,
      title: title
    } do
      [first | _] = P.editor_items(return_to, title)
      assert first.label == "Suggestions"
      assert first.href == "/knowledge-base/suggestions?task=7"
    end

    test "last crumb is 'Editing: <title>' with NO :href key", %{
      return_to: return_to,
      title: title
    } do
      items = P.editor_items(return_to, title)
      last = List.last(items)
      assert last.label == "Editing: Refund policy"
      refute Map.has_key?(last, :href)
    end

    test "satisfies the last-crumb contract", %{return_to: return_to, title: title} do
      assert_last_crumb_contract(P.editor_items(return_to, title))
    end

    test "no crumb label equals the raw return_to path", %{return_to: return_to, title: title} do
      assert_no_raw_path_label(P.editor_items(return_to, title), return_to)
    end
  end

  # ---------------------------------------------------------------------------
  # editor_items/2 — nil / non-binary return_to (static fallback)
  # ---------------------------------------------------------------------------

  describe "editor_items/2 with nil return_to (static fallback)" do
    setup do
      %{title: "Draft article"}
    end

    test "returns exactly 2 items", %{title: title} do
      assert length(P.editor_items(nil, title)) == 2
    end

    test "first crumb is 'Knowledge' linking to /knowledge-base", %{title: title} do
      [first | _] = P.editor_items(nil, title)
      assert first.label == "Knowledge"
      assert first.href == "/knowledge-base"
    end

    test "last crumb is 'Editing: <title>' with NO :href key", %{title: title} do
      last = List.last(P.editor_items(nil, title))
      assert last.label == "Editing: Draft article"
      refute Map.has_key?(last, :href)
    end

    test "satisfies the last-crumb contract", %{title: title} do
      assert_last_crumb_contract(P.editor_items(nil, title))
    end

    test "first crumb is a linked crumb (≥1 linked crumb in fallback)", %{title: title} do
      [first | _] = P.editor_items(nil, title)
      assert Map.has_key?(first, :href), "fallback must still have ≥1 linked crumb"
    end
  end

  describe "editor_items/2 with a non-binary, non-nil return_to" do
    test "falls back to the 2-item static list" do
      items = P.editor_items(42, "Some title")
      assert length(items) == 2
      assert_last_crumb_contract(items)
    end
  end

  # ---------------------------------------------------------------------------
  # suggestions_items/1 — static lane crumbs (no selected task)
  # ---------------------------------------------------------------------------

  describe "suggestions_items/1 with no selected-task title" do
    test "returns 2 items" do
      items = P.suggestions_items(nil)
      assert length(items) == 2
    end

    test "first crumb is 'Knowledge' linking to /knowledge-base" do
      [first | _] = P.suggestions_items(nil)
      assert first.label == "Knowledge"
      assert first.href == "/knowledge-base"
    end

    test "last crumb is 'Suggestions' with NO :href key" do
      last = List.last(P.suggestions_items(nil))
      assert last.label == "Suggestions"
      refute Map.has_key?(last, :href)
    end

    test "satisfies the last-crumb contract" do
      assert_last_crumb_contract(P.suggestions_items(nil))
    end
  end

  # ---------------------------------------------------------------------------
  # suggestions_items/1 — with a selected task title (3-crumb variant)
  # ---------------------------------------------------------------------------

  describe "suggestions_items/1 with a selected-task title" do
    setup do
      %{task_title: "Revamp refund section"}
    end

    test "returns 3 items", %{task_title: task_title} do
      items = P.suggestions_items(task_title)
      assert length(items) == 3
    end

    test "'Suggestions' becomes a linked back crumb to /knowledge-base/suggestions", %{
      task_title: task_title
    } do
      [_, suggestions_crumb | _] = P.suggestions_items(task_title)
      assert suggestions_crumb.label == "Suggestions"
      assert suggestions_crumb.href == "/knowledge-base/suggestions"
    end

    test "last crumb is the task title with NO :href key", %{task_title: task_title} do
      last = List.last(P.suggestions_items(task_title))
      assert last.label == task_title
      refute Map.has_key?(last, :href)
    end

    test "satisfies the last-crumb contract", %{task_title: task_title} do
      assert_last_crumb_contract(P.suggestions_items(task_title))
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-cutting: last-crumb contract on ALL clauses (exhaustive)
  # ---------------------------------------------------------------------------

  describe "last-crumb contract — exhaustive" do
    test "all editor_items/2 clauses end with a no-href crumb" do
      assert_last_crumb_contract(P.editor_items("/42", "T"))
      assert_last_crumb_contract(P.editor_items("/knowledge-base/suggestions?task=1", "T"))
      assert_last_crumb_contract(P.editor_items(nil, "T"))
      assert_last_crumb_contract(P.editor_items(42, "T"))
    end

    test "all suggestions_items/1 clauses end with a no-href crumb" do
      assert_last_crumb_contract(P.suggestions_items(nil))
      assert_last_crumb_contract(P.suggestions_items("A task title"))
      assert_last_crumb_contract(P.suggestions_items(""))
    end
  end

  # ---------------------------------------------------------------------------
  # Negative copy assertion: no raw path ever appears as a label
  # ---------------------------------------------------------------------------

  describe "negative copy assertion — raw return_to never used as label" do
    test "conversation path /42 is never a crumb label" do
      items = P.editor_items("/42", "Some article")
      labels = Enum.map(items, & &1.label)
      refute "/42" in labels
    end

    test "suggestions path is never a crumb label" do
      return_to = "/knowledge-base/suggestions?task=7"
      items = P.editor_items(return_to, "Some article")
      labels = Enum.map(items, & &1.label)
      refute return_to in labels
    end
  end
end
