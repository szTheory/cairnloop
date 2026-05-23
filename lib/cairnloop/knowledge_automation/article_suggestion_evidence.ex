defmodule Cairnloop.KnowledgeAutomation.ArticleSuggestionEvidence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @source_types [:knowledge_base, :resolved_case, :unknown]
  @trust_levels [:canonical, :assistive, :unknown]
  @max_excerpt_length 500
  @max_title_length 200

  embedded_schema do
    field(:source_type, Ecto.Enum, values: @source_types, default: :unknown)
    field(:trust_level, Ecto.Enum, values: @trust_levels, default: :unknown)
    field(:title, :string)
    field(:excerpt, :string)
    field(:citation_target, :map, default: %{})
    field(:metadata, :map, default: %{})
    field(:match_reasons, {:array, :string}, default: [])
  end

  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [
      :source_type,
      :trust_level,
      :title,
      :excerpt,
      :citation_target,
      :metadata,
      :match_reasons
    ])
    |> validate_required([
      :source_type,
      :trust_level,
      :title,
      :excerpt,
      :citation_target,
      :metadata
    ])
    |> validate_length(:title, max: @max_title_length)
    |> validate_length(:excerpt, max: @max_excerpt_length)
    |> validate_citation_target()
    |> validate_metadata_destination()
  end

  defp validate_citation_target(changeset) do
    validate_change(changeset, :citation_target, fn :citation_target, citation_target ->
      cond do
        not is_map(citation_target) ->
          [citation_target: "must be a map"]

        map_size(citation_target) > 5 ->
          [citation_target: "must contain at most 5 keys"]

        missing_citation_keys?(citation_target) ->
          [citation_target: "must include article_id, revision_id, and chunk_index"]

        true ->
          []
      end
    end)
  end

  defp validate_metadata_destination(changeset) do
    validate_change(changeset, :metadata, fn :metadata, metadata ->
      destination = metadata_destination(metadata)

      cond do
        not is_map(metadata) ->
          [metadata: "must be a map"]

        not is_map(destination) ->
          [metadata: "must include metadata.destination"]

        map_size(destination) > 4 ->
          [metadata: "must contain at most 4 keys"]

        true ->
          []
      end
    end)
  end

  defp missing_citation_keys?(citation_target) do
    Enum.any?(
      [:article_id, :revision_id, :chunk_index],
      &(map_lookup(citation_target, &1) in [nil, ""])
    )
  end

  defp metadata_destination(metadata) do
    map_lookup(metadata, :destination)
  end

  defp map_lookup(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
