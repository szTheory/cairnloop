defmodule Cairnloop.KnowledgeAutomation.CandidateBuilder do
  import Ecto.Query

  alias Cairnloop.KnowledgeAutomation.{GapCandidate, GapCandidateMembership, ManualHandlingSignal}
  alias Cairnloop.KnowledgeAutomation.Telemetry
  alias Cairnloop.Retrieval.GapEvent

  @retention_days 90

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  defp prefixed(queryable) do
    query = Ecto.Queryable.to_query(queryable)
    put_query_prefix(query, Cairnloop.SchemaPrefix.configured())
  end

  def build(gap_events, manual_signals, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    buckets =
      Enum.reduce(gap_events, %{}, fn event, acc ->
        case bucketed_gap_event(event) do
          nil ->
            acc

          bucket ->
            Map.update(acc, bucket.bucket_key, [bucket], &[bucket | &1])
        end
      end)

    buckets =
      Enum.reduce(manual_signals, buckets, fn signal, acc ->
        bucket_key =
          build_bucket_key(
            signal.tenant_scope,
            Map.get(signal, :host_user_id),
            signal.topic_seed
          )

        bucket = %{kind: :manual_signal, data: signal, bucket_key: bucket_key}
        Map.update(acc, bucket_key, [bucket], &[bucket | &1])
      end)

    buckets
    |> Enum.map(fn {_bucket_key, entries} -> build_candidate(entries, now) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn candidate ->
      {
        -(candidate.candidate.score || 0.0),
        DateTime.to_unix(candidate.candidate.last_seen_at, :microsecond) * -1,
        candidate.candidate.stable_key
      }
    end)
  end

  def refresh(opts \\ []) do
    gap_events = Keyword.get_lazy(opts, :gap_events, &recent_gap_events/0)

    manual_signals =
      Keyword.get_lazy(opts, :manual_signals, fn -> ManualHandlingSignal.list_recent(opts) end)

    candidates =
      build(gap_events, manual_signals, now: Keyword.get(opts, :now, DateTime.utc_now()))

    persist_fn = Keyword.get(opts, :persist_fn, &persist_candidates/1)
    persist_fn.(candidates)
  end

  defp recent_gap_events do
    cutoff = DateTime.add(DateTime.utc_now(), -@retention_days * 86_400, :second)

    GapEvent
    |> prefixed()
    |> where([event], event.occurred_at >= ^cutoff)
    |> order_by([event], desc: event.occurred_at, desc: event.id)
    |> repo().all(repo_opts())
  end

  defp bucketed_gap_event(%GapEvent{} = event) do
    topic_seed = ManualHandlingSignal.normalize_topic_seed(event.sanitized_query_excerpt)

    if topic_seed == "" do
      nil
    else
      %{
        kind: :gap_event,
        data: event,
        bucket_key: build_bucket_key(event.tenant_scope, event.host_user_id, topic_seed),
        topic_seed: topic_seed
      }
    end
  end

  defp build_bucket_key(tenant_scope, host_user_id, topic_seed) do
    host_user_id = host_user_id || "all"

    [tenant_scope, host_user_id, topic_seed]
    |> Enum.join("|")
  end

  defp build_candidate(entries, now) do
    gap_events =
      entries
      |> Enum.filter(&(&1.kind == :gap_event))
      |> Enum.map(& &1.data)

    manual_signals =
      entries
      |> Enum.filter(&(&1.kind == :manual_signal))
      |> Enum.map(& &1.data)

    if gap_events == [] and length(manual_signals) < 2 do
      nil
    else
      seed_text =
        gap_events
        |> Enum.map(& &1.sanitized_query_excerpt)
        |> Kernel.++(Enum.map(manual_signals, &(&1.issue_summary || &1.subject || "")))
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.min_by(&String.length/1, fn -> "" end)

      tenant_scope = dominant_value(gap_events, manual_signals, :tenant_scope, :system_unscoped)
      host_user_id = dominant_value(gap_events, manual_signals, :host_user_id, nil)
      ui_surface = dominant_value(gap_events, manual_signals, :ui_surface, :unspecified)

      stable_key =
        [:sha256, tenant_scope || "system_unscoped", host_user_id || "all", seed_text]
        |> Enum.map(&to_string/1)
        |> Enum.join("|")
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      first_seen_at = earliest_seen_at(gap_events, manual_signals)
      last_seen_at = latest_seen_at(gap_events, manual_signals, now)
      manual_case_count = length(manual_signals)
      weak_grounding_count = Enum.count(gap_events, &(candidate_reason(&1) == :weak_grounding))
      no_hit_count = Enum.count(gap_events, &(candidate_reason(&1) == :no_hit))
      evidence_count = length(gap_events) + manual_case_count

      candidate_type =
        cond do
          manual_case_count > 0 and (weak_grounding_count > 0 or no_hit_count > 0) -> :mixed
          manual_case_count > 0 -> :manual_handling
          weak_grounding_count > 0 and no_hit_count > 0 -> :mixed
          weak_grounding_count > 0 -> :weak_grounding
          true -> :no_hit
        end

      score_components =
        score_components(
          evidence_count,
          manual_case_count,
          weak_grounding_count,
          no_hit_count,
          last_seen_at,
          now
        )

      %{
        candidate: %{
          stable_key: stable_key,
          status: :open,
          candidate_type: candidate_type,
          title: title_for(seed_text),
          seed_excerpt: seed_text,
          tenant_scope: tenant_scope,
          host_user_id: host_user_id,
          ui_surface: ui_surface,
          first_seen_at: first_seen_at,
          last_seen_at: last_seen_at,
          evidence_count: evidence_count,
          manual_case_count: manual_case_count,
          weak_grounding_count: weak_grounding_count,
          no_hit_count: no_hit_count,
          score_components: score_components,
          score: Map.fetch!(score_components, "total")
        },
        memberships:
          Enum.map(gap_events, fn event ->
            %{source_type: :retrieval_gap_event, source_id: event.id}
          end) ++
            Enum.map(manual_signals, fn signal ->
              %{source_type: :manual_handling_case, source_id: signal.source_id}
            end),
        retrieval_gap_events: gap_events,
        manual_handling_evidence: manual_signals
      }
    end
  end

  def persist_candidates(candidates) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    stable_keys = Enum.map(candidates, & &1.candidate.stable_key)

    repo().transaction(
      fn ->
        Enum.each(candidates, fn %{candidate: attrs, memberships: memberships} ->
          existing =
            GapCandidate
            |> prefixed()
            |> where([candidate], candidate.stable_key == ^attrs.stable_key)
            |> repo().one(repo_opts())

          candidate =
            (existing || %GapCandidate{})
            |> GapCandidate.changeset(attrs)
            |> repo().insert_or_update!(repo_opts())

          Telemetry.emit(:gap_candidate, %{count: 1}, %{
            surface: candidate.ui_surface,
            entrypoint_type: :gap_candidate,
            outcome: :created,
            reason: candidate_reason_for_telemetry(candidate.candidate_type),
            canonical_evidence_count: candidate.evidence_count,
            assistive_evidence_count: candidate.manual_case_count
          })

          GapCandidateMembership
          |> prefixed()
          |> where([membership], membership.gap_candidate_id == ^candidate.id)
          |> repo().delete_all(repo_opts())

          Enum.each(memberships, fn membership ->
            membership
            |> Map.put(:gap_candidate_id, candidate.id)
            |> Map.put(:inserted_at, now)
            |> GapCandidateMembership.changeset(%GapCandidateMembership{})
            |> repo().insert!(repo_opts())
          end)
        end)

        GapCandidate
        |> prefixed()
        |> where(
          [candidate],
          candidate.status == :open and candidate.stable_key not in ^stable_keys
        )
        |> repo().delete_all(repo_opts())

        :ok
      end,
      repo_opts()
    )
  end

  defp earliest_seen_at(gap_events, manual_signals) do
    gap_events
    |> Enum.map(& &1.occurred_at)
    |> Kernel.++(Enum.map(manual_signals, & &1.occurred_at))
    |> Enum.min(DateTime)
  end

  defp latest_seen_at(gap_events, manual_signals, fallback) do
    gap_events
    |> Enum.map(& &1.occurred_at)
    |> Kernel.++(Enum.map(manual_signals, & &1.occurred_at))
    |> Enum.max_by(&DateTime.to_unix(&1, :microsecond), fn -> fallback end)
  end

  defp score_components(
         evidence_count,
         manual_case_count,
         weak_grounding_count,
         no_hit_count,
         last_seen_at,
         now
       ) do
    age_days = max(DateTime.diff(now, last_seen_at, :day), 0)
    volume = Float.round(:math.log(evidence_count + 1) * 1.6, 3)
    manual = Float.round(manual_case_count * 2.5, 3)
    weak_grounding = Float.round(weak_grounding_count * 1.4, 3)
    no_hit = Float.round(no_hit_count * 1.0, 3)
    recency = Float.round(max(0.0, 3.0 - age_days / 15), 3)
    total = Float.round(volume + manual + weak_grounding + no_hit + recency, 3)

    %{
      "evidence_volume" => volume,
      "manual_handling" => manual,
      "weak_grounding" => weak_grounding,
      "no_hit" => no_hit,
      "recency" => recency,
      "total" => total
    }
  end

  defp candidate_reason(%GapEvent{outcome_class: :empty_recall}), do: :no_hit

  defp candidate_reason(%GapEvent{outcome_class: :weak_grounding}), do: :weak_grounding

  defp candidate_reason(%GapEvent{reason: :no_canonical_results}), do: :no_hit

  defp candidate_reason(%GapEvent{reason: :assistive_only_results}), do: :weak_grounding

  defp candidate_reason(%GapEvent{reason: :canonical_insufficient_detail}), do: :weak_grounding

  defp candidate_reason(_event), do: :no_hit

  defp candidate_reason_for_telemetry(:manual_handling), do: :manual_handling
  defp candidate_reason_for_telemetry(:weak_grounding), do: :weak_grounding_gap
  defp candidate_reason_for_telemetry(:mixed), do: :mixed
  defp candidate_reason_for_telemetry(_type), do: :no_hit

  defp dominant_value(gap_events, manual_signals, key, default) do
    gap_events
    |> Enum.map(&Map.get(&1, key))
    |> Kernel.++(Enum.map(manual_signals, &Map.get(&1, key)))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] ->
        default

      values ->
        values
        |> Enum.frequencies()
        |> Enum.max_by(fn {_value, count} -> count end)
        |> elem(0)
    end
  end

  defp title_for(""), do: "Untitled gap candidate"

  defp title_for(seed_text) do
    seed_text
    |> String.split(" ", trim: true)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
