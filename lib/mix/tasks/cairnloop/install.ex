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

  @cairnloop_version Mix.Project.config()[:version]

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
    |> Igniter.Project.Deps.add_dep({:cairnloop, "~> #{@cairnloop_version}"})
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
              prefix = Cairnloop.SchemaPrefix.configured()

              if prefix do
                execute(
                  "CREATE SCHEMA IF NOT EXISTS \#{Cairnloop.SchemaPrefix.quote_identifier!(prefix)}",
                  "SELECT 1"
                )
              end

              create table(:cairnloop_conversations, prefix: prefix) do
                add :status, :string, null: false
                add :subject, :string
                add :host_user_id, :string
                add :customer_ref, :string
                add :resolved_at, :utc_datetime_usec
                add :csat_rating, :string

                timestamps()
              end

              create table(:cairnloop_messages, prefix: prefix) do
                add :content, :text, null: false
                add :role, :string, null: false
                add :metadata, :map
                add :conversation_id, references(:cairnloop_conversations, prefix: prefix, on_delete: :delete_all), null: false

                timestamps()
              end

              create index(:cairnloop_messages, [:conversation_id], prefix: prefix)
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
             # Inject the SIGNED-IN operator per request via an MFA tuple. `host_user_id`
             # is the audit actor + search scope — a static map freezes it at compile time
             # so every operator shares one id. Define cairnloop_session/1 to read the
             # authenticated user off the conn (see the Auth & Operator Identity guide):
             #   def cairnloop_session(conn), do: %{"host_user_id" => to_string(conn.assigns.current_user.id)}
             Cairnloop.Router.cairnloop_dashboard "/",
               session: {MyAppWeb.UserAuth, :cairnloop_session, []}
           end

      2. Configure Cairnloop to use your Ecto repo:

           config :cairnloop, :repo, MyApp.Repo

         New installs default Cairnloop support tables to the `cairnloop` Postgres schema:

           config :cairnloop, :schema_prefix, "cairnloop"

         Existing public-schema installs can explicitly keep public compatibility while migrating:

           config :cairnloop, :schema_prefix, "public"

         The legacy `nil` value is also accepted for existing public-schema installs, but new
         compatibility configuration should prefer `"public"` because it is explicit.

         Existing installs should add a nullable `customer_ref` column to their Cairnloop
         conversations table before enabling the Phase 58 widget verifier path. Keep
         `host_user_id` for signed-in operator/governance identity.

      3. Surface governed-action events in the audit log:

           config :cairnloop, :auditor, Cairnloop.Auditor.Governance

         (Optional) scaffold a Notifier:  mix cairnloop.gen.notifier

      4. Run the host migration generated in your app, then the Cairnloop dependency migrations:

           mix ecto.migrate
           mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations

         Cairnloop migrations read `:schema_prefix` and qualify their own tables in source.
         Do not use `mix ecto.migrate --prefix cairnloop` as a shortcut; that can move
         migrator bookkeeping and still would not fix raw SQL, triggers, or generated host DDL.

      5. Verify the wiring:  mix cairnloop.doctor
    """
  end
end
