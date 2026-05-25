defmodule Cairnloop.Repo.Migrations.RelaxActionEventToStatusNull do
  @moduledoc """
  Phase 15 approval events (`:approval_requested`, `:approved`, `:rejected`, `:deferred`,
  `:expired`, `:invalidated`, `:resume_scheduled`, `:revalidation_passed`,
  `:revalidation_failed`) carry their transition in `event_type` + `metadata` and leave both
  `from_status` and `to_status` NULL (D15-03). The original
  `20260524000000_add_tool_proposals_and_action_events` migration created `to_status` as
  NOT NULL (correct for Phase 13 proposal events). This relaxes it so approval events can be
  co-committed against a real Postgres — without it every approval transition fails with a
  not-null violation (the headless MockRepo suite could not surface this).
  """
  use Ecto.Migration

  def change do
    alter table(:cairnloop_tool_action_events) do
      modify(:to_status, :string, null: true, from: {:string, null: false})
    end
  end
end
