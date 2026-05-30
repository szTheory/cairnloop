defmodule Mix.Tasks.Cairnloop.Install do
  @shortdoc "Installs Cairnloop: adds the dep, generates the base migration, and prints next steps"

  @moduledoc """
  Igniter installer for Cairnloop.

  Adds the dependency, generates the base `cairnloop_*` tables migration against your repo, and
  prints the remaining host-owned wiring steps (router mount, auditor config) plus a pointer to
  `mix cairnloop.doctor` to verify. Cairnloop is host-owned, so the router mount and auth stay
  yours — the installer guides them rather than silently injecting routes.
  """

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
    |> Igniter.Project.Deps.add_dep({:cairnloop, "~> 0.3"})
    |> add_base_migration()
    |> Igniter.add_notice(next_steps_notice())
  end

  defp add_base_migration(igniter) do
    case Igniter.Libs.Ecto.select_repo(igniter) do
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

  defp next_steps_notice do
    """
    Cairnloop is host-owned. To finish wiring it up:

      1. Mount the operator surfaces in your router (lib/my_app_web/router.ex):

           require Cairnloop.Router

           # Liveness/metrics probes — outside auth so infra can reach them.
           scope "/" do
             Cairnloop.Router.cairnloop_operations()
           end

           # Operator dashboard — wrap in your own auth pipeline.
           scope "/support" do
             pipe_through [:browser]   # add your :require_admin pipeline here
             Cairnloop.Router.cairnloop_dashboard "/",
               session: %{"host_user_id" => "the_current_operator_id"}
           end

      2. Surface governed-action events in the audit log:

           config :cairnloop, :auditor, Cairnloop.Auditor.Governance

         (Optional) scaffold a Notifier:  mix cairnloop.gen.notifier

      3. Run the migration:  mix ecto.migrate

      4. Verify the wiring:  mix cairnloop.doctor
    """
  end
end
