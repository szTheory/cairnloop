defmodule Cairnloop.Retrieval.GapRecorderTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Retrieval.{GapEvent, GapRecorder}

  defmodule MockRepo do
    def one(_query), do: nil

    def transaction(multi) do
      results =
        Enum.reduce(Ecto.Multi.to_list(multi), %{}, fn
          {:gap_event, {:insert, changeset, _opts}}, acc ->
            gap_event =
              changeset
              |> Ecto.Changeset.apply_action!(:insert)
              |> Map.put(:id, System.unique_integer([:positive]))
              |> Map.put(:inserted_at, DateTime.utc_now())

            Process.put(:gap_events, [gap_event | Process.get(:gap_events, [])])
            Map.put(acc, :gap_event, gap_event)
        end)

      {:ok, results}
    end

    def all(%Ecto.Query{}), do: Process.get(:gap_events, []) |> Enum.reverse()
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.put(:gap_events, [])

    on_exit(fn ->
      Process.delete(:gap_events)

      if original_repo do
        Application.put_env(:cairnloop, :repo, original_repo)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)

    :ok
  end

  test "records a sanitized append-only gap event synchronously and makes it immediately queryable" do
    now = DateTime.from_naive!(~N[2026-05-20 20:30:00.123456], "Etc/UTC")

    assert {:ok, %GapEvent{} = gap_event} =
             GapRecorder.record(
               %{
                 query: "Customer jane@example.com cannot export invoice 1234567890 from billing",
                 surface: :search_modal,
                 outcome_class: :empty_recall,
                 reason: :no_canonical_results,
                 host_user_id: 42,
                 ui_surface: :conversation,
                 canonical_hit_count: 0,
                 assistive_hit_count: 1,
                 clarification_attempts: 1,
                 attempted_evidence: [
                   %{
                     source_type: :resolved_case,
                     trust_level: :assistive,
                     title: "Billing export workaround",
                     content: "Resolved case tied to jane@example.com and invoice 1234567890",
                     citation_target: %{conversation_id: 55},
                     match_reasons: [:semantic_match]
                   },
                   %{
                     source_type: :resolved_case,
                     trust_level: :assistive,
                     title: "Billing export workaround",
                     content: "Resolved case tied to jane@example.com and invoice 1234567890",
                     citation_target: %{conversation_id: 55},
                     match_reasons: [:semantic_match]
                   }
                 ]
               },
               now_fn: fn -> now end,
               schedule_prune_fn: fn -> :ok end
             )

    assert gap_event.occurred_at == now

    assert gap_event.query_fingerprint ==
             :crypto.hash(
               :sha256,
               "Customer jane@example.com cannot export invoice 1234567890 from billing"
             )
             |> Base.encode16(case: :lower)

    assert gap_event.sanitized_query_excerpt ==
             "Customer [redacted-email] cannot export invoice [redacted-number] from billing"

    assert gap_event.host_user_id == "42"
    assert gap_event.tenant_scope == :host_user_scoped
    assert gap_event.ui_surface == :conversation
    assert gap_event.canonical_hit_count == 0
    assert gap_event.assistive_hit_count == 1
    assert length(gap_event.attempted_evidence_snapshots) == 1

    [stored_event] = GapRecorder.list_recent(limit: 5)
    assert stored_event.id == gap_event.id
    assert stored_event.reason == :no_canonical_results
    assert hd(stored_event.attempted_evidence_snapshots).content_excerpt =~ "[redacted-email]"
  end

  test "keeps prune scheduling secondary to the primary insert path" do
    assert {:ok, %GapEvent{} = gap_event} =
             GapRecorder.record(
               %{
                 query: "billing export timeout",
                 surface: :api,
                 outcome_class: :retrieval_error,
                 reason: :provider_timeout
               },
               schedule_prune_fn: fn -> {:error, :oban_down} end
             )

    assert gap_event.reason == :provider_timeout
    assert gap_event.tenant_scope == :system_unscoped
    assert gap_event.ui_surface == :unspecified
    assert length(GapRecorder.list_recent(limit: 5)) == 1
  end

  test "dedupes assistive-only search gaps within the 24-hour window by scope context" do
    now = DateTime.from_naive!(~N[2026-05-21 12:00:00], "Etc/UTC")

    assert {:ok, %GapEvent{} = first_gap_event} =
             GapRecorder.record(
               %{
                 query: "billing export",
                 surface: :search_modal,
                 outcome_class: :weak_grounding,
                 reason: :assistive_only_results,
                 host_user_id: "user_42",
                 tenant_scope: :host_user_scoped,
                 ui_surface: :conversation
               },
               now_fn: fn -> now end,
               schedule_prune_fn: fn -> :ok end
             )

    dedupe_lookup_fn = fn attrs ->
      Process.get(:gap_events, [])
      |> Enum.find(fn gap_event ->
        gap_event.query_fingerprint == attrs.query_fingerprint and
          gap_event.tenant_scope == attrs.tenant_scope and
          gap_event.host_user_id == attrs.host_user_id and
          gap_event.ui_surface == attrs.ui_surface and
          gap_event.surface == attrs.surface and
          gap_event.outcome_class == attrs.outcome_class and
          gap_event.reason == attrs.reason and
          DateTime.compare(
            gap_event.occurred_at,
            DateTime.add(attrs.occurred_at, -(24 * 60 * 60), :second)
          ) != :lt
      end)
    end

    assert {:ok, %GapEvent{} = second_gap_event} =
             GapRecorder.record(
               %{
                 query: "billing export",
                 surface: :search_modal,
                 outcome_class: :weak_grounding,
                 reason: :assistive_only_results,
                 host_user_id: "user_42",
                 tenant_scope: :host_user_scoped,
                 ui_surface: :conversation
               },
               now_fn: fn -> DateTime.add(now, 60, :second) end,
               schedule_prune_fn: fn -> :ok end,
               dedupe_lookup_fn: dedupe_lookup_fn
             )

    assert second_gap_event.id == first_gap_event.id
    assert length(GapRecorder.list_recent(limit: 5)) == 1
  end
end
