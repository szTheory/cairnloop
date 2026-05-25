defmodule Cairnloop.TestHost.Migrations.AddRunKeyToMessages do
  @moduledoc """
  Adds `run_key :string` to `cairnloop_messages` with a partial unique index for
  O(1) idempotency existence checks by `Cairnloop.Tools.InternalNote` (and any
  future governed-write tool that follows the run-level idempotency pattern, D16-05).

  The partial unique index (`WHERE run_key IS NOT NULL`) ensures:
  - A nil run_key row (no idempotency key) is allowed multiple times.
  - A non-nil run_key is unique — duplicate governed-write attempts return the existing row.

  Lives in `priv/test_host/migrations/` — NOT in `priv/repo/migrations/`.
  This migration stands in for host-owned schema additions that a real host app would ship.
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
