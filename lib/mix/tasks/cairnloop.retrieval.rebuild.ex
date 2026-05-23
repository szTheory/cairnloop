defmodule Mix.Tasks.Cairnloop.Retrieval.Rebuild do
  use Mix.Task

  @shortdoc "Enqueue retrieval rebuild jobs for a scoped corpus"

  @moduledoc """
  Rebuild retrieval corpus state through `Cairnloop.Retrieval`.

  Examples:

      mix cairnloop.retrieval.rebuild --corpus knowledge_base --revision-id 42
      mix cairnloop.retrieval.rebuild --corpus resolved_cases --conversation-id 7
  """

  @switches [corpus: :string, revision_id: :keep, conversation_id: :keep]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: @switches)

    corpus =
      opts
      |> Keyword.fetch!(:corpus)
      |> String.to_existing_atom()

    rebuild_opts =
      [corpus: corpus]
      |> maybe_put_ids(:revision_ids, Keyword.get_values(opts, :revision_id))
      |> maybe_put_ids(:conversation_ids, Keyword.get_values(opts, :conversation_id))

    case retrieval_module().rebuild_corpus(rebuild_opts) do
      {:ok, jobs} ->
        Mix.shell().info("Enqueued #{length(jobs)} rebuild job(s) for #{corpus}")

      {:error, reason} ->
        Mix.raise("Retrieval rebuild failed: #{inspect(reason)}")
    end
  end

  defp maybe_put_ids(opts, _key, []), do: opts
  defp maybe_put_ids(opts, key, values), do: Keyword.put(opts, key, Enum.map(values, &String.to_integer/1))

  defp retrieval_module do
    Application.get_env(:cairnloop, :retrieval_module, Cairnloop.Retrieval)
  end
end
