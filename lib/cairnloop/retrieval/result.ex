defmodule Cairnloop.Retrieval.Result do
  @moduledoc """
  Normalized retrieval evidence shared across search, grounding, and telemetry summaries.
  """

  defstruct [
    :id,
    :title,
    :content,
    :source_type,
    :trust_level,
    :visibility,
    :citation_target,
    :article_id,
    :revision_id,
    :conversation_id,
    :chunk_index,
    :updated_at,
    :resolved_at,
    :issue_summary,
    :resolution_note,
    :actions_taken,
    :outcome,
    :score,
    :can_ground_reply?,
    metadata: %{},
    match_reasons: [],
    keyword_rank: nil,
    semantic_rank: nil
  ]
end
