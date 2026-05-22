defmodule Cairnloop.KnowledgeAutomation.ArticleSuggestion do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.KnowledgeAutomation.ArticleSuggestionEvidence

  @status_values [:pending_generation, :ready, :failed, :dismissed]
  @suggestion_type_values [:article, :revision]
  @entrypoint_type_values [:gap_candidate, :article_revision, :conversation_quick_fix]
  @tenant_scope_values [:host_user_scoped, :public_only, :system_unscoped]

  schema "cairnloop_article_suggestions" do
    field(:stable_key, :string)
    field(:suggestion_type, Ecto.Enum, values: @suggestion_type_values)
    field(:status, Ecto.Enum, values: @status_values, default: :pending_generation)
    field(:tenant_scope, Ecto.Enum, values: @tenant_scope_values)
    field(:host_user_id, :string)
    field(:entrypoint_type, Ecto.Enum, values: @entrypoint_type_values)
    field(:entrypoint_id, :integer)
    field(:article_id, :integer)
    field(:base_revision_id, :integer)
    field(:title, :string)
    field(:change_summary, :string)
    field(:operator_summary, :string)
    field(:proposed_markdown, :string)
    field(:grounding_metadata, :map, default: %{})
    field(:evidence_digest, :string)
    field(:generated_at, :utc_datetime_usec)
    field(:dismissed_at, :utc_datetime_usec)
    field(:manual_edit_opened_at, :utc_datetime_usec)

    embeds_many(:evidence_snapshot, ArticleSuggestionEvidence, on_replace: :delete)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(article_suggestion, attrs) do
    article_suggestion
    |> cast(attrs, [
      :stable_key,
      :suggestion_type,
      :status,
      :tenant_scope,
      :host_user_id,
      :entrypoint_type,
      :entrypoint_id,
      :article_id,
      :base_revision_id,
      :title,
      :change_summary,
      :operator_summary,
      :proposed_markdown,
      :grounding_metadata,
      :evidence_digest,
      :generated_at,
      :dismissed_at,
      :manual_edit_opened_at
    ])
    |> cast_embed(:evidence_snapshot, with: &ArticleSuggestionEvidence.changeset/2)
    |> validate_required([
      :stable_key,
      :suggestion_type,
      :status,
      :tenant_scope,
      :entrypoint_type,
      :entrypoint_id,
      :proposed_markdown,
      :grounding_metadata
    ])
    |> validate_length(:stable_key, min: 8, max: 160)
    |> validate_length(:proposed_markdown, min: 1)
    |> validate_grounding_metadata()
    |> validate_host_scope()
    |> validate_anchor_rules()
  end

  def dismiss_changeset(article_suggestion, dismissed_at) do
    changeset(article_suggestion, %{
      status: :dismissed,
      dismissed_at: dismissed_at
    })
  end

  def regenerate_changeset(article_suggestion) do
    changeset(article_suggestion, %{
      status: :pending_generation,
      dismissed_at: nil,
      generated_at: nil
    })
  end

  defp validate_host_scope(changeset) do
    case {get_field(changeset, :tenant_scope), get_field(changeset, :host_user_id)} do
      {:host_user_scoped, value} when value in [nil, ""] ->
        add_error(changeset, :host_user_id, "must be present for host_user_scoped suggestions")

      _ ->
        changeset
    end
  end

  defp validate_grounding_metadata(changeset) do
    grounding_metadata = get_field(changeset, :grounding_metadata)

    cond do
      grounding_metadata == nil ->
        add_error(changeset, :grounding_metadata, "can't be blank")

      not is_map(grounding_metadata) ->
        add_error(changeset, :grounding_metadata, "must be a map")

      map_size(grounding_metadata) == 0 ->
        add_error(changeset, :grounding_metadata, "can't be blank")

      true ->
        changeset
    end
  end

  defp validate_anchor_rules(changeset) do
    suggestion_type = get_field(changeset, :suggestion_type)
    entrypoint_type = get_field(changeset, :entrypoint_type)
    article_id = get_field(changeset, :article_id)
    base_revision_id = get_field(changeset, :base_revision_id)

    case {suggestion_type, entrypoint_type} do
      {:revision, :article_revision} ->
        changeset
        |> require_anchor(:article_id, article_id)
        |> require_anchor(:base_revision_id, base_revision_id)

      {:article, entrypoint_type} when entrypoint_type in [:gap_candidate, :conversation_quick_fix] ->
        changeset
        |> reject_anchor(:article_id, article_id)
        |> reject_anchor(:base_revision_id, base_revision_id)

      _ ->
        changeset
    end
  end

  defp require_anchor(changeset, field, value) when value in [nil, ""],
    do: add_error(changeset, field, "must be present for revision suggestions")

  defp require_anchor(changeset, _field, _value), do: changeset

  defp reject_anchor(changeset, field, value) when value not in [nil, ""],
    do: add_error(changeset, field, "must be blank for gap-driven article suggestions")

  defp reject_anchor(changeset, _field, _value), do: changeset
end
