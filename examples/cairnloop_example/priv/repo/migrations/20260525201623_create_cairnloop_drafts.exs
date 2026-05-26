defmodule CairnloopExample.Repo.Migrations.CreateCairnloopDrafts do
  use Ecto.Migration

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

      add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:cairnloop_drafts, [:conversation_id])
  end
end
