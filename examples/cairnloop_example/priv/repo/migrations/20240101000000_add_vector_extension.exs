defmodule CairnloopExample.Repo.Migrations.AddVectorExtension do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS vector;")
  end

  def down do
    # `vector` is shared database infrastructure, not owned by this demo migration.
    :ok
  end
end
