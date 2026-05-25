defmodule Cairnloop.KnowledgeAutomation.Workers.GenerateArticleSuggestion do
  use Oban.Worker,
    queue: :default,
    unique: [
      period: 60,
      fields: [:worker, :args],
      keys: [:entrypoint_type, :entrypoint_id, :base_revision_id, :evidence_digest]
    ]

  def new_job(args \\ %{}, opts \\ []) do
    args
    |> Enum.into(%{})
    |> stringify_keys()
    |> new(opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"suggestion_id" => suggestion_id} = args}) do
    suggestion = knowledge_automation().get_article_suggestion!(suggestion_id)
    prepared = knowledge_automation().prepare_generation_bundle_from_suggestion(suggestion)

    if prepared.valid? do
      case scoria_engine().generate_article_suggestion(suggestion, prepared) do
        {:ok, proposal} ->
          case knowledge_automation().mark_article_suggestion_ready(suggestion, proposal) do
            {:ok, _updated} -> :ok
            {:error, _changeset} = error -> error
          end

        {:error, reason} ->
          fail_suggestion(suggestion, reason)

        _ ->
          fail_suggestion(suggestion, :generation_failed)
      end
    else
      fail_suggestion(
        suggestion,
        prepared.failure_reason || args["failure_reason"] || :generation_failed
      )
    end
  end

  defp fail_suggestion(suggestion, reason) do
    case knowledge_automation().mark_article_suggestion_failed(suggestion, reason) do
      {:ok, _updated} -> :ok
      {:error, _changeset} = error -> error
    end
  end

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, Cairnloop.KnowledgeAutomation)
  end

  defp scoria_engine do
    Application.get_env(:cairnloop, :scoria_engine, Cairnloop.Automation.ScoriaEngine)
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
