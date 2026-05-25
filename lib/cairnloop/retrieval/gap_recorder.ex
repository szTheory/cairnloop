defmodule Cairnloop.Retrieval.GapRecorder do
  import Ecto.Query

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Retrieval.{GapEvent, GapEventSnapshot}
  alias Cairnloop.Retrieval.Workers.PruneGapEvents

  @assistive_search_dedupe_window_seconds 24 * 60 * 60
  @max_excerpt_length 160
  @max_snapshot_excerpt_length 240
  @max_snapshot_title_length 160
  @max_snapshots 5

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def record(attrs, opts \\ []) do
    normalized_attrs = normalize_attrs(attrs, opts)

    case find_recent_duplicate(normalized_attrs, opts) do
      %GapEvent{} = gap_event ->
        {:ok, gap_event}

      nil ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:gap_event, GapEvent.changeset(%GapEvent{}, normalized_attrs))
        |> repo().transaction()
        |> case do
          {:ok, %{gap_event: gap_event}} ->
            _ = maybe_schedule_prune(opts)
            _ = maybe_schedule_gap_candidate_refresh(gap_event, opts)
            {:ok, gap_event}

          {:error, :gap_event, changeset, _changes} ->
            {:error, changeset}

          other ->
            other
        end
    end
  end

  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    GapEvent
    |> order_by([gap_event], desc: gap_event.occurred_at, desc: gap_event.inserted_at)
    |> limit(^limit)
    |> repo().all()
  end

  defp maybe_schedule_prune(opts) do
    schedule_prune_fn = Keyword.get(opts, :schedule_prune_fn, &schedule_prune_job/0)
    schedule_prune_fn.()
  rescue
    _ -> :ok
  end

  defp maybe_schedule_gap_candidate_refresh(%GapEvent{} = gap_event, opts) do
    schedule_refresh_fn =
      Keyword.get(
        opts,
        :schedule_gap_candidate_refresh_fn,
        &KnowledgeAutomation.schedule_gap_candidate_refresh/1
      )

    schedule_refresh_fn.(%{
      "source_type" => "retrieval_gap_event",
      "source_id" => gap_event.id
    })
  rescue
    _ -> :ok
  end

  defp schedule_prune_job do
    Oban.insert(PruneGapEvents.new_job(%{}, schedule_in: 60))
  end

  defp normalize_attrs(attrs, opts) do
    attrs = Enum.into(attrs, %{})
    query = Map.get(attrs, :query) || Map.get(attrs, "query") || ""

    %{
      occurred_at:
        attrs
        |> get_value(:occurred_at, "occurred_at")
        |> normalize_occurred_at(Keyword.get(opts, :now_fn, &DateTime.utc_now/0)),
      surface: get_value(attrs, :surface, "surface") || :unspecified,
      outcome_class: get_value(attrs, :outcome_class, "outcome_class"),
      reason: get_value(attrs, :reason, "reason"),
      host_user_id: attrs |> get_value(:host_user_id, "host_user_id") |> normalize_string_value(),
      tenant_scope: normalize_tenant_scope(attrs),
      ui_surface: normalize_ui_surface(attrs),
      query_fingerprint: query_fingerprint(query),
      sanitized_query_excerpt: sanitized_query_excerpt(query),
      canonical_hit_count:
        attrs |> get_value(:canonical_hit_count, "canonical_hit_count") |> normalize_count(),
      assistive_hit_count:
        attrs |> get_value(:assistive_hit_count, "assistive_hit_count") |> normalize_count(),
      clarification_attempts:
        attrs |> get_value(:clarification_attempts, "clarification_attempts") |> normalize_count(),
      attempted_evidence_snapshots: normalize_snapshots(attrs)
    }
  end

  defp normalize_occurred_at(%DateTime{} = occurred_at, _now_fn),
    do: DateTime.truncate(occurred_at, :microsecond)

  defp normalize_occurred_at(_, now_fn), do: now_fn.() |> DateTime.truncate(:microsecond)

  defp normalize_string_value(nil), do: nil
  defp normalize_string_value(""), do: nil
  defp normalize_string_value(value), do: to_string(value)

  defp normalize_tenant_scope(attrs) do
    attrs
    |> get_value(:tenant_scope, "tenant_scope")
    |> case do
      value when value in [:host_user_scoped, "host_user_scoped"] -> :host_user_scoped
      value when value in [:public_only, "public_only"] -> :public_only
      value when value in [:system_unscoped, "system_unscoped"] -> :system_unscoped
      _ -> infer_tenant_scope(attrs)
    end
  end

  defp infer_tenant_scope(attrs) do
    if normalize_string_value(get_value(attrs, :host_user_id, "host_user_id")) do
      :host_user_scoped
    else
      :system_unscoped
    end
  end

  defp normalize_ui_surface(attrs) do
    attrs
    |> get_value(:ui_surface, "ui_surface")
    |> case do
      nil -> attrs |> get_value(:host_surface, "host_surface") |> normalize_ui_surface_value()
      value -> normalize_ui_surface_value(value)
    end
  end

  defp normalize_ui_surface_value(value) when value in [:conversation, "conversation"],
    do: :conversation

  defp normalize_ui_surface_value(value) when value in [:inbox, "inbox"], do: :inbox
  defp normalize_ui_surface_value(value) when value in [:settings, "settings"], do: :settings
  defp normalize_ui_surface_value(_), do: :unspecified

  defp normalize_count(value) when is_integer(value) and value >= 0, do: value

  defp normalize_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} when parsed >= 0 -> parsed
      _ -> 0
    end
  end

  defp normalize_count(_), do: 0

  defp normalize_snapshots(attrs) do
    attrs
    |> get_value(:attempted_evidence_snapshots, "attempted_evidence_snapshots")
    |> case do
      nil -> get_value(attrs, :attempted_evidence, "attempted_evidence") || []
      snapshots -> snapshots
    end
    |> List.wrap()
    |> Enum.map(&normalize_snapshot/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&snapshot_dedupe_key/1)
    |> Enum.take(@max_snapshots)
  end

  defp normalize_snapshot(%GapEventSnapshot{} = snapshot), do: snapshot

  defp normalize_snapshot(%{} = snapshot) do
    %{
      source_type: snapshot |> get_value(:source_type, "source_type") |> normalize_source_type(),
      trust_level: snapshot |> get_value(:trust_level, "trust_level") |> normalize_trust_level(),
      title:
        snapshot
        |> get_value(:title, "title")
        |> sanitize_text(@max_snapshot_title_length),
      content_excerpt:
        snapshot
        |> get_value(:content_excerpt, "content_excerpt")
        |> case do
          nil -> get_value(snapshot, :content, "content")
          value -> value
        end
        |> sanitize_text(@max_snapshot_excerpt_length),
      citation_target:
        snapshot
        |> get_value(:citation_target, "citation_target")
        |> normalize_citation_target(),
      match_reasons:
        snapshot
        |> get_value(:match_reasons, "match_reasons")
        |> List.wrap()
        |> Enum.map(&to_string/1)
        |> Enum.uniq()
        |> Enum.take(5),
      score:
        snapshot
        |> get_value(:score, "score")
        |> normalize_score()
    }
  end

  defp normalize_snapshot(_), do: nil

  defp normalize_source_type(value) when value in [:knowledge_base, :resolved_case], do: value
  defp normalize_source_type("knowledge_base"), do: :knowledge_base
  defp normalize_source_type("resolved_case"), do: :resolved_case
  defp normalize_source_type(_), do: :unknown

  defp normalize_trust_level(value) when value in [:canonical, :assistive], do: value
  defp normalize_trust_level("canonical"), do: :canonical
  defp normalize_trust_level("assistive"), do: :assistive
  defp normalize_trust_level(_), do: :unknown

  defp normalize_citation_target(%{} = citation_target) do
    citation_target
    |> Enum.take(5)
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_citation_target(_), do: %{}

  defp normalize_score(value) when is_float(value), do: value
  defp normalize_score(value) when is_integer(value), do: value / 1
  defp normalize_score(_), do: nil

  defp snapshot_dedupe_key(snapshot) do
    {
      snapshot[:source_type],
      snapshot[:trust_level],
      snapshot[:title],
      snapshot[:content_excerpt],
      snapshot[:citation_target]
    }
  end

  defp query_fingerprint(query) do
    :sha256
    |> :crypto.hash(to_string(query))
    |> Base.encode16(case: :lower)
  end

  defp sanitized_query_excerpt(query) do
    query
    |> sanitize_text(@max_excerpt_length)
    |> case do
      "" -> "[redacted query]"
      excerpt -> excerpt
    end
  end

  defp sanitize_text(nil, _max_length), do: ""

  defp sanitize_text(text, max_length) do
    text
    |> to_string()
    |> String.replace(~r/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/iu, "[redacted-email]")
    |> String.replace(~r/\b\d{5,}\b/u, "[redacted-number]")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.slice(0, max_length)
  end

  defp get_value(map, atom_key, string_key) do
    Map.get(map, atom_key) || Map.get(map, string_key)
  end

  defp find_recent_duplicate(attrs, opts) do
    dedupe_lookup_fn = Keyword.get(opts, :dedupe_lookup_fn, &find_recent_assistive_search_gap/1)

    if assistive_only_search_gap?(attrs) do
      dedupe_lookup_fn.(attrs)
    end
  end

  defp assistive_only_search_gap?(attrs) do
    attrs.surface == :search_modal and attrs.outcome_class == :weak_grounding and
      attrs.reason == :assistive_only_results
  end

  defp find_recent_assistive_search_gap(attrs) do
    window_start =
      DateTime.add(attrs.occurred_at, -@assistive_search_dedupe_window_seconds, :second)

    GapEvent
    |> where([gap_event], gap_event.occurred_at >= ^window_start)
    |> where([gap_event], gap_event.query_fingerprint == ^attrs.query_fingerprint)
    |> where([gap_event], gap_event.tenant_scope == ^attrs.tenant_scope)
    |> where([gap_event], gap_event.host_user_id == ^attrs.host_user_id)
    |> where([gap_event], gap_event.ui_surface == ^attrs.ui_surface)
    |> where([gap_event], gap_event.surface == ^attrs.surface)
    |> where([gap_event], gap_event.outcome_class == ^attrs.outcome_class)
    |> where([gap_event], gap_event.reason == ^attrs.reason)
    |> order_by([gap_event], desc: gap_event.occurred_at, desc: gap_event.inserted_at)
    |> limit(1)
    |> repo().one()
  end
end
