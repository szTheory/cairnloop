defmodule Cairnloop.TestHost.Migrations.AddOutboundToMessages do
  @moduledoc """
  Documents the addition of the `system_outbound` role to the `cairnloop_messages` table.
  In this test host, the `role` column is a string, so no schema change is strictly
  required, but this migration maintains parity with host-app expectations.
  """
  use Ecto.Migration

  def up do
    # No-op in string-based schema, but host apps using native enums would:
    # execute "ALTER TYPE message_role ADD VALUE 'system_outbound'"
    :ok
  end

  def down do
    :ok
  end
end
