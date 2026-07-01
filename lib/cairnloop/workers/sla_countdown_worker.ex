defmodule Cairnloop.Workers.SlaCountdownWorker do
  use Oban.Worker, queue: :default

  alias Cairnloop.Conversations.SLA

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  def perform(%Oban.Job{args: %{"sla_id" => sla_id}}) do
    case repo().get(SLA, sla_id, repo_opts()) do
      nil ->
        :ok

      %SLA{status: :active} = sla ->
        sla
        |> Ecto.Changeset.change(%{status: :breached, completed_at: DateTime.utc_now()})
        |> repo().update!(repo_opts())

        :ok

      _ ->
        :ok
    end
  end
end
