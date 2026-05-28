defmodule Cairnloop.Web.ReviewTaskPresenterTest do
  @moduledoc """
  Pure presenter tests for ReviewTaskPresenter.action_label/2 KB-04 copy variants.

  No Repo required — all fixtures use struct construction directly.
  """

  use ExUnit.Case, async: true

  alias Cairnloop.Web.ReviewTaskPresenter
  alias Cairnloop.KnowledgeAutomation.ReviewTask
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion

  # ---------------------------------------------------------------------------
  # Inline fixture helpers
  # ---------------------------------------------------------------------------

  # Default revision/ready suggestion — should return "Open for manual edit"
  defp revision_ready_suggestion do
    %ArticleSuggestion{
      id: 1,
      suggestion_type: :revision,
      status: :ready,
      grounding_metadata: %{}
    }
  end

  # Failed suggestion — should return "Review and draft manually"
  defp failed_suggestion do
    %ArticleSuggestion{
      id: 2,
      suggestion_type: :revision,
      status: :failed,
      grounding_metadata: %{}
    }
  end

  # New article (:article type) suggestion — should return "Create manual draft"
  defp article_type_suggestion do
    %ArticleSuggestion{
      id: 3,
      suggestion_type: :article,
      status: :ready,
      grounding_metadata: %{}
    }
  end

  # blocked_manual_required suggestion (quick_fix_outcome_label == "Manual draft required")
  defp blocked_manual_suggestion do
    %ArticleSuggestion{
      id: 4,
      suggestion_type: :revision,
      status: :ready,
      grounding_metadata: %{"quick_fix_outcome" => "blocked_manual_required"}
    }
  end

  defp task_with(suggestion) do
    %ReviewTask{
      id: 1,
      status: :pending_review,
      article_suggestion: suggestion
    }
  end

  # ---------------------------------------------------------------------------
  # describe: action_label/1 — 1-arity default
  # ---------------------------------------------------------------------------

  describe "action_label/1 — 1-arity defaults" do
    test "returns 'Open for manual edit' for :open_for_edit (default copy)" do
      assert ReviewTaskPresenter.action_label(:open_for_edit) == "Open for manual edit"
    end

    test "returns 'Approve' for :approve" do
      assert ReviewTaskPresenter.action_label(:approve) == "Approve"
    end

    test "returns 'Reject' for :reject" do
      assert ReviewTaskPresenter.action_label(:reject) == "Reject"
    end

    test "returns 'Defer' for :defer" do
      assert ReviewTaskPresenter.action_label(:defer) == "Defer"
    end

    test "returns 'Publish' for :publish" do
      assert ReviewTaskPresenter.action_label(:publish) == "Publish"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: action_label/2 — KB-04 3-variant copy contract
  # ---------------------------------------------------------------------------

  describe "action_label/2 — default :revision/:ready suggestion" do
    test "returns 'Open for manual edit' for an ordinary :revision/:ready suggestion" do
      task = task_with(revision_ready_suggestion())
      label = ReviewTaskPresenter.action_label(:open_for_edit, task)
      assert label == "Open for manual edit"
    end

    test "does not return the old 'Open for edit' copy" do
      task = task_with(revision_ready_suggestion())
      label = ReviewTaskPresenter.action_label(:open_for_edit, task)
      refute label == "Open for edit", "Old 'Open for edit' copy must be replaced"
    end
  end

  describe "action_label/2 — :failed suggestion" do
    test "returns 'Review and draft manually' for a :failed suggestion" do
      task = task_with(failed_suggestion())
      label = ReviewTaskPresenter.action_label(:open_for_edit, task)
      assert label == "Review and draft manually"
    end
  end

  describe "action_label/2 — :article type suggestion (maps to 'Create manual draft')" do
    test "returns 'Create manual draft' for suggestion_type :article" do
      task = task_with(article_type_suggestion())
      label = ReviewTaskPresenter.action_label(:open_for_edit, task)
      assert label == "Create manual draft"
    end
  end

  describe "action_label/2 — blocked_manual_required (quick_fix_outcome_label path)" do
    test "returns 'Create manual draft' when quick_fix_outcome_label == 'Manual draft required'" do
      task = task_with(blocked_manual_suggestion())
      label = ReviewTaskPresenter.action_label(:open_for_edit, task)
      assert label == "Create manual draft"
    end
  end

  describe "action_label/2 — non-:open_for_edit actions delegate to 1-arity" do
    test ":approve delegates to action_label(:approve) -> 'Approve'" do
      task = task_with(revision_ready_suggestion())
      assert ReviewTaskPresenter.action_label(:approve, task) == "Approve"
    end

    test ":reject delegates to action_label(:reject) -> 'Reject'" do
      task = task_with(revision_ready_suggestion())
      assert ReviewTaskPresenter.action_label(:reject, task) == "Reject"
    end
  end

  describe "action_label/2 — no raw atom leakage" do
    test "no returned label starts with a colon (no raw atom leakage)" do
      tasks = [
        task_with(revision_ready_suggestion()),
        task_with(failed_suggestion()),
        task_with(article_type_suggestion()),
        task_with(blocked_manual_suggestion())
      ]

      for task <- tasks do
        label = ReviewTaskPresenter.action_label(:open_for_edit, task)
        assert is_binary(label), "Expected string, got: #{inspect(label)}"
        refute String.starts_with?(label, ":"),
               "Label must not be a raw atom, got: #{inspect(label)}"
      end
    end
  end
end
