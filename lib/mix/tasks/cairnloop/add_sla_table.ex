defmodule Mix.Tasks.Cairnloop.AddSlaTable do
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
          "No Ecto repo found. Please create a migration manually for cairnloop_conversation_slas table."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
          igniter,
          repo,
          "create_cairnloop_conversation_slas",
          body: """
            def change do
              create table(:cairnloop_conversation_slas) do
                add :target_type, :string, null: false
                add :status, :string, null: false
                add :target_at, :utc_datetime_usec, null: false
                add :completed_at, :utc_datetime_usec
                add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all), null: false

                timestamps()
              end

              create index(:cairnloop_conversation_slas, [:conversation_id])
            end
          """,
          on_exists: :skip
        )
    end
  end
end
