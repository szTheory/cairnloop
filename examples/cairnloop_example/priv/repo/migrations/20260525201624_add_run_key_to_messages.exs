defmodule CairnloopExample.Repo.Migrations.AddRunKeyToMessages do
  @moduledoc """
  Adds `run_key :string` to `cairnloop_messages` with a partial unique index for O(1)
  idempotency existence checks by governed-write tools (`Cairnloop.Tools.InternalNote`
  and any tool following the run-level idempotency pattern, D16-05).

  Cairnloop's `Cairnloop.Message` schema declares `run_key`, but the column is HOST-OWNED:
  a real adopter must add it via their own migration before mounting a governed-write tool.
  This example app mounts `InternalNote`, so it ships the column here — without it, executing
  any governed write fails with `column run_key does not exist`. This mirrors the library's
  own `priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs`.
  """
  use Ecto.Migration

  def change do
    alter table(:cairnloop_messages) do
      add(:run_key, :string)
    end

    create(
      unique_index(:cairnloop_messages, [:run_key],
        name: :cairnloop_messages_run_key_unique_index,
        where: "run_key IS NOT NULL"
      )
    )
  end
end
