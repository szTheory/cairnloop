defmodule CairnloopExample.Repo.Migrations.CreateCairnloopTables do
  use Ecto.Migration

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

      add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:cairnloop_messages, [:conversation_id])
  end
end
