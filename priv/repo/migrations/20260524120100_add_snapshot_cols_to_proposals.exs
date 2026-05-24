defmodule Cairnloop.Repo.Migrations.AddSnapshotColsToProposals do
  use Ecto.Migration

  def change do
    alter table(:cairnloop_tool_proposals) do
      # Nullable prose-snapshot columns (D15-14):
      # Pre-Phase-15 rows stay NULL; propose/3 populates from Phase 15 forward.
      # Approval surfaces read these snapshotted columns — NEVER call live Preview.render/1.
      add(:rendered_consequence, :text)
      add(:title, :string)
    end
  end
end
