defmodule Cairnloop.Repo.Migrations.AddToolProposalsAndActionEvents do
  use Ecto.Migration

  def change do
    create table(:cairnloop_tool_proposals) do
      add(:tool_ref, :string, null: false)
      add(:tool_version, :string)
      add(:idempotency_key, :string, null: false)
      add(:status, :string, null: false, default: "proposed")
      add(:risk_tier, :string, null: false)
      add(:approval_mode, :string, null: false)
      add(:actor_id, :string, null: false)
      add(:account_id, :string)

      # Three discrete snapshot maps — one trust category per field (D-24)
      add(:input_snapshot, :map, null: false, default: %{})
      add(:scope_snapshot, :map, null: false, default: %{})
      add(:policy_snapshot, :map, null: false, default: %{})

      # Phase 16 reserved columns (D-22)
      add(:attempt, :integer, null: false, default: 0)
      add(:oban_job_id, :integer)
      add(:result_state, :string, null: false, default: "not_executed")
      add(:result_summary, :string)

      timestamps(type: :utc_datetime_usec)
    end

    # Idempotency unique index — not a partial index (D-25)
    create(unique_index(:cairnloop_tool_proposals, [:idempotency_key]))

    # Query indexes
    create(index(:cairnloop_tool_proposals, [:status, :inserted_at]))
    create(index(:cairnloop_tool_proposals, [:actor_id, :status]))
    create(index(:cairnloop_tool_proposals, [:tool_ref, :inserted_at]))

    create table(:cairnloop_tool_action_events) do
      add(
        :tool_proposal_id,
        references(:cairnloop_tool_proposals, on_delete: :delete_all),
        null: false
      )

      add(:event_type, :string, null: false)
      add(:from_status, :string)
      add(:to_status, :string, null: false)
      add(:actor_id, :string, null: false)
      add(:reason, :string)
      add(:metadata, :map, null: false, default: %{})

      # append-only: no updated_at (D-21)
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:cairnloop_tool_action_events, [:tool_proposal_id, :inserted_at]))
    create(index(:cairnloop_tool_action_events, [:event_type, :inserted_at]))
  end
end
