defmodule Mix.Tasks.Cairnloop.Install do
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
    |> Igniter.Project.Deps.add_dep({:cairnloop, "~> 0.1.0"})
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
          "create_cairnloop_tables",
          body: """
            def change do
              create table(:cairnloop_conversations) do
                add :status, :string, null: false
                add :subject, :string
                add :host_user_id, :string
                add :resolved_at, :utc_datetime_usec
                add :csat_rating, :string

                timestamps()
              end

              create table(:cairnloop_messages) do
                add :content, :text, null: false
                add :role, :string, null: false
                add :metadata, :map
                add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all), null: false

                timestamps()
              end

              create index(:cairnloop_messages, [:conversation_id])
            end
          """,
          on_exists: :skip
        )
    end
  end
end
