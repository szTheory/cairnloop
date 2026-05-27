defmodule Cairnloop.TestHost.Migrations.AddObanJobs do
  @moduledoc """
  Creates the `oban_jobs` table (and Oban's supporting types) for the integration
  test host so DB-backed integration tests can exercise code paths that insert
  Oban jobs (e.g. `Cairnloop.Outbound.bulk_trigger/2`'s per-recipient
  `Multi.insert(OutboundWorker.new(...))` step).

  ## Why this lives in the TEST host, not the library

  Cairnloop ships no Oban migration (the host owns `oban_jobs` — see
  `test/integration/approval_flow_test.exs:9`). The test_host directory exists
  precisely to simulate a real Cairnloop-consuming host: it already creates
  host-owned tables (`cairnloop_conversations`, `cairnloop_messages`) and now
  also creates the Oban substrate that a production host would. The library
  itself remains zero-children and ships no Oban migration.

  This is additive — pre-existing integration tests that bypass Oban via a
  capture `enqueue_fn` (approval_flow_test, tool_execution_worker_test) still
  pass; this migration only ENABLES tests that need a real Oban insert to land.
  """
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end
