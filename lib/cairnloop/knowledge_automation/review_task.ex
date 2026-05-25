defmodule Cairnloop.KnowledgeAutomation.ReviewTask do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, ReviewTaskEvent}
  alias Cairnloop.KnowledgeBase.{Article, Revision}

  @status_values [
    :pending_review,
    :review_needed,
    :approved_ready_to_publish,
    :deferred,
    :rejected,
    :published
  ]
  @tenant_scope_values [:host_user_scoped, :public_only, :system_unscoped]
  @decision_values [:approved, :rejected, :deferred, :review_needed]
  @reason_values [
    :ready_to_publish,
    :insufficient_evidence,
    :policy_rejected,
    :needs_manual_edit,
    :freshness_invalidated,
    :operator_deferred,
    :draft_conflict
  ]
  @publish_status_values [:not_started, :queued, :published, :failed]
  @reindex_status_values [:not_started, :queued, :running, :completed, :failed]
  @decision_required_statuses [
    :review_needed,
    :approved_ready_to_publish,
    :deferred,
    :rejected,
    :published
  ]

  schema "cairnloop_review_tasks" do
    field(:status, Ecto.Enum, values: @status_values, default: :pending_review)
    field(:tenant_scope, Ecto.Enum, values: @tenant_scope_values)
    field(:host_user_id, :string)
    field(:last_decision, Ecto.Enum, values: @decision_values)
    field(:last_reason, Ecto.Enum, values: @reason_values)
    field(:last_actor_id, :string)
    field(:last_decided_at, :utc_datetime_usec)
    field(:notes, :string)
    field(:publish_status, Ecto.Enum, values: @publish_status_values, default: :not_started)
    field(:reindex_status, Ecto.Enum, values: @reindex_status_values, default: :not_started)
    field(:needs_re_review, :boolean, default: false)
    field(:published_at, :utc_datetime_usec)

    belongs_to(:article_suggestion, ArticleSuggestion)
    belongs_to(:staged_article, Article)
    belongs_to(:staged_revision, Revision)
    belongs_to(:published_revision, Revision)

    has_many(:events, ReviewTaskEvent)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(review_task, attrs) do
    review_task
    |> cast(attrs, [
      :article_suggestion_id,
      :status,
      :tenant_scope,
      :host_user_id,
      :last_decision,
      :last_reason,
      :last_actor_id,
      :last_decided_at,
      :notes,
      :staged_article_id,
      :staged_revision_id,
      :published_revision_id,
      :published_at,
      :publish_status,
      :reindex_status,
      :needs_re_review
    ])
    |> validate_required([:article_suggestion_id, :status, :tenant_scope])
    |> validate_host_scope()
    |> validate_decision_metadata()
    |> validate_publish_fields()
    |> unique_constraint(:article_suggestion_id,
      name: :cairnloop_review_tasks_one_active_task_per_suggestion_index
    )
  end

  def status_values, do: @status_values
  def decision_values, do: @decision_values
  def reason_values, do: @reason_values

  def active_status_values,
    do: [:pending_review, :review_needed, :approved_ready_to_publish, :deferred]

  def active_status?(status), do: status in active_status_values()

  def decision_changeset(
        review_task,
        status,
        decision,
        reason,
        actor_id,
        decided_at,
        attrs \\ %{}
      ) do
    attrs =
      attrs
      |> Map.new()
      |> Map.merge(%{
        status: status,
        last_decision: decision,
        last_reason: reason,
        last_actor_id: actor_id,
        last_decided_at: decided_at
      })

    review_task
    |> changeset(attrs)
    |> validate_decision_reason(decision, reason)
  end

  def valid_reason_for_decision?(:approved, reason), do: reason in [:ready_to_publish]

  def valid_reason_for_decision?(:rejected, reason),
    do: reason in [:insufficient_evidence, :policy_rejected]

  def valid_reason_for_decision?(:deferred, reason),
    do: reason in [:needs_manual_edit, :operator_deferred]

  def valid_reason_for_decision?(:review_needed, reason),
    do: reason in [:needs_manual_edit, :freshness_invalidated, :draft_conflict]

  def valid_reason_for_decision?(_, _reason), do: false

  defp validate_host_scope(changeset) do
    case {get_field(changeset, :tenant_scope), get_field(changeset, :host_user_id)} do
      {:host_user_scoped, value} when value in [nil, ""] ->
        add_error(changeset, :host_user_id, "must be present for host_user_scoped review tasks")

      _ ->
        changeset
    end
  end

  defp validate_decision_metadata(changeset) do
    if get_field(changeset, :status) in @decision_required_statuses do
      changeset
      |> validate_required([:last_decision, :last_reason, :last_actor_id, :last_decided_at])
    else
      changeset
    end
  end

  defp validate_publish_fields(changeset) do
    if get_field(changeset, :status) == :published do
      validate_required(changeset, [:published_revision_id, :published_at])
    else
      changeset
    end
  end

  defp validate_decision_reason(changeset, decision, reason) do
    if valid_reason_for_decision?(decision, reason) do
      changeset
    else
      add_error(changeset, :last_reason, "is not allowed for this decision")
    end
  end
end
