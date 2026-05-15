defmodule Mix.Tasks.Cairnloop.Install.SlaPolicies do
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
    schema_name = Igniter.Project.Module.module_name(igniter, "SLA.Policy")
    provider_name = Igniter.Project.Module.module_name(igniter, "SLA.PolicyProvider")

    igniter
    |> Igniter.Project.Module.create_module(schema_name, """
      use Ecto.Schema
      import Ecto.Changeset

      schema "cairnloop_sla_policies" do
        field :priority, Ecto.Enum, values: [:low, :normal, :high, :urgent]
        field :target_first_response_minutes, :integer
        field :target_resolution_minutes, :integer

        timestamps(updated_at: false)
      end

      @doc false
      def changeset(policy, attrs) do
        policy
        |> cast(attrs, [:priority, :target_first_response_minutes, :target_resolution_minutes])
        |> validate_required([:priority, :target_first_response_minutes, :target_resolution_minutes])
      end
    """)
    |> Igniter.Project.Module.create_module(provider_name, """
      @behaviour Cairnloop.SLAPolicyProvider

      import Ecto.Query

      @impl true
      def get_active_policies do
        {:ok, []}
      end

      @impl true
      def set_policy(_priority, _attrs) do
        {:ok, %{}}
      end
    """)
    |> Igniter.Libs.Ecto.select_repo()
    |> case do
      {igniter, nil} ->
        Igniter.add_issue(
          igniter,
          "No Ecto repo found. Please create a migration manually for cairnloop_sla_policies table."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
          igniter,
          repo,
          "create_cairnloop_sla_policies",
          body: """
            def change do
              create table(:cairnloop_sla_policies) do
                add :priority, :string, null: false
                add :target_first_response_minutes, :integer
                add :target_resolution_minutes, :integer

                timestamps(updated_at: false)
              end

              create index(:cairnloop_sla_policies, [:priority, :inserted_at])
            end
          """,
          on_exists: :skip
        )
    end
    |> Igniter.Project.Config.configure(
      "config.exs",
      :cairnloop,
      [:sla_policy_provider],
      provider_name
    )
  end
end
