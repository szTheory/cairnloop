defmodule Cairnloop.Retrieval.GapEventSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @source_types [:knowledge_base, :resolved_case, :unknown]
  @trust_levels [:canonical, :assistive, :unknown]
  @max_excerpt_length 240
  @max_title_length 160

  embedded_schema do
    field(:source_type, Ecto.Enum, values: @source_types, default: :unknown)
    field(:trust_level, Ecto.Enum, values: @trust_levels, default: :unknown)
    field(:title, :string)
    field(:content_excerpt, :string)
    field(:citation_target, :map, default: %{})
    field(:match_reasons, {:array, :string}, default: [])
    field(:score, :float)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :source_type,
      :trust_level,
      :title,
      :content_excerpt,
      :citation_target,
      :match_reasons,
      :score
    ])
    |> validate_length(:title, max: @max_title_length)
    |> validate_length(:content_excerpt, max: @max_excerpt_length)
    |> validate_change(:citation_target, fn :citation_target, citation_target ->
      if map_size(citation_target || %{}) <= 5 do
        []
      else
        [citation_target: "must contain at most 5 keys"]
      end
    end)
  end
end
