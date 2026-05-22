defmodule Cairnloop.Web.ReviewTaskPresenter do
  alias Cairnloop.KnowledgeAutomation.{ReviewTask, ReviewTaskEvent}

  @queue_filters [
    {"all", "All work"},
    {"pending_review", "Pending review"},
    {"approved_ready_to_publish", "Approved-ready-to-publish"},
    {"rejected", "Rejected"},
    {"deferred", "Deferred"},
    {"review_needed", "Review needed"},
    {"published", "Published"}
  ]

  def queue_filters, do: @queue_filters

  def status_label(%ReviewTask{status: status}), do: status_label(status)
  def status_label(:pending_review), do: "Pending review"
  def status_label(:approved_ready_to_publish), do: "Approved-ready-to-publish"
  def status_label(:rejected), do: "Rejected"
  def status_label(:deferred), do: "Deferred"
  def status_label(:review_needed), do: "Review needed"
  def status_label(:published), do: "Published"

  def queue_filter_status("all"), do: nil
  def queue_filter_status(value) when is_binary(value), do: String.to_existing_atom(value)
  def queue_filter_status(value), do: value

  def queue_filter_label(status) when is_atom(status), do: status |> Atom.to_string() |> queue_filter_label()

  def queue_filter_label(value) do
    @queue_filters
    |> Enum.find_value("All work", fn {filter, label} -> if filter == value, do: label end)
  end

  def next_step_copy(%ReviewTask{status: :pending_review}), do: "Review evidence and decide what happens next."
  def next_step_copy(%ReviewTask{status: :approved_ready_to_publish}), do: "Ready to publish when you are."
  def next_step_copy(%ReviewTask{status: :rejected}), do: "Rejected with a durable reason. Regenerate only after the evidence changes."
  def next_step_copy(%ReviewTask{status: :deferred}), do: "Deferred until a manual authoring pass or operator follow-up happens."
  def next_step_copy(%ReviewTask{status: :review_needed}), do: "Review again before this can move forward."
  def next_step_copy(%ReviewTask{status: :published}), do: "Published and queued for reindex follow-through."

  def publish_outcome(%ReviewTask{status: :published, published_revision_id: revision_id, reindex_status: :completed}) do
    "Published revision ##{revision_id}. Reindex completed."
  end

  def publish_outcome(%ReviewTask{status: :published, published_revision_id: revision_id}) do
    "Published revision ##{revision_id}. Reindex queued."
  end

  def publish_outcome(_task), do: "Not published yet"

  def decision_summary(%ReviewTask{last_decision: nil}), do: "Waiting for first decision."

  def decision_summary(%ReviewTask{} = task) do
    actor = task.last_actor_id || "system"
    decision = task.last_decision |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    reason = reason_label(task.last_reason)

    [decision <> " by " <> actor, reason && "Reason: #{reason}", task.notes]
    |> Enum.filter(&present?/1)
    |> Enum.join(" · ")
  end

  def history_line(%ReviewTaskEvent{event_type: :task_created, actor_id: actor_id}) do
    "Task created by #{actor_id}"
  end

  def history_line(%ReviewTaskEvent{event_type: :decision_recorded, decision: decision, actor_id: actor_id, notes: notes}) do
    action = decision |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

    [action <> " by " <> actor_id, notes]
    |> Enum.filter(&present?/1)
    |> Enum.join(" · ")
  end

  def history_line(%ReviewTaskEvent{event_type: :publish_recorded, actor_id: actor_id, metadata: metadata}) do
    revision_id = metadata_value(metadata, :published_revision_id)
    publish_status = metadata_value(metadata, :publish_status)

    [
      "Published by #{actor_id}",
      revision_id && "Revision ##{revision_id}",
      publish_status && "Status: #{publish_status}"
    ]
    |> Enum.filter(&present?/1)
    |> Enum.join(" · ")
  end

  def history_line(%ReviewTaskEvent{event_type: :reindex_recorded, metadata: metadata}) do
    "Reindex follow-through: #{metadata_value(metadata, :reindex_status) || "updated"}"
  end

  def history_line(%ReviewTaskEvent{}), do: "Workflow updated"

  def reason_label(nil), do: nil

  def reason_label(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  def available_actions(%ReviewTask{status: :pending_review}), do: [:approve, :reject, :defer, :open_for_edit]
  def available_actions(%ReviewTask{status: :review_needed}), do: [:approve, :reject, :defer, :open_for_edit]
  def available_actions(%ReviewTask{status: :approved_ready_to_publish}), do: [:publish, :open_for_edit, :reject, :defer]
  def available_actions(%ReviewTask{status: :deferred}), do: [:approve, :reject, :open_for_edit]
  def available_actions(%ReviewTask{status: :rejected}), do: [:open_for_edit]
  def available_actions(%ReviewTask{status: :published}), do: []

  def action_label(:approve), do: "Approve"
  def action_label(:reject), do: "Reject"
  def action_label(:defer), do: "Defer"
  def action_label(:publish), do: "Publish"
  def action_label(:open_for_edit), do: "Open for edit"

  defp metadata_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp metadata_value(_, _), do: nil
  defp present?(value), do: value not in [nil, ""]
end
