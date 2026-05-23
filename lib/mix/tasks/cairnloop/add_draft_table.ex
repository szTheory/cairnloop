defmodule Mix.Tasks.Cairnloop.AddDraftTable do
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
          "No Ecto repo found. Please create a migration manually for cairnloop_drafts table."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
          igniter,
          repo,
          "create_cairnloop_drafts",
          body: """
            def change do
              create table(:cairnloop_drafts) do
                add :content, :text, null: false
                add :proposal_type, :string, null: false, default: "reply"
                add :operator_summary, :text
                add :customer_reply, :text
                add :evidence_snapshot, :map, null: false, default: %{}
                add :grounding_metadata, :map, null: false, default: %{}
                add :clarification_attempts, :integer, null: false, default: 0
                add :status, :string, null: false, default: "pending"
                add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all), null: false

                timestamps()
              end

              create index(:cairnloop_drafts, [:conversation_id])
            end
          """,
          on_exists: :skip
        )
    end
  end
end
