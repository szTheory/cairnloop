defmodule Mix.Tasks.Cairnloop.AddResolvedAtColumn do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :cairnloop,
      schema: [],
      defaults: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> Igniter.Libs.Ecto.select_repo()
    |> case do
      {igniter, nil} ->
        Igniter.add_issue(
          igniter,
          "No Ecto repo found. Please create a migration manually for cairnloop tables."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
          igniter,
          repo,
          "add_resolved_at_to_conversations",
          body: """
            def change do
              alter table(:cairnloop_conversations) do
                add :resolved_at, :utc_datetime_usec
              end
            end
          """,
          on_exists: :skip
        )
    end
  end
end
