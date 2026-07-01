defmodule Cairnloop.Repo.Migrations.AddConversationIdToToolProposals do
  use Ecto.Migration

  def change do
    prefix = Cairnloop.SchemaPrefix.configured()

    alter table(:cairnloop_tool_proposals, prefix: prefix) do
      add(
        :conversation_id,
        references(:cairnloop_conversations, prefix: prefix, on_delete: :nilify_all), null: true)
    end

    # Composite index for efficient conversation-scoped timeline queries (D-06)
    create(index(:cairnloop_tool_proposals, [:conversation_id, :inserted_at], prefix: prefix))
  end
end
