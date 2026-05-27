defmodule CairnloopExample.DemoContextProvider do
  @moduledoc """
  Demo implementation of `Cairnloop.ContextProvider` for the example application.

  Returns plausible, hard-coded context for the 16 seeded demo conversations
  (five distinct customer identities across the Trailmark SaaS demo dataset).
  Each known actor yields a structured map of categorized sections — for
  example, "User Details", "Active Plan", and a persona-specific third section —
  matching the documented context shape the operator inbox renders.

  For any actor id that is not one of the five demo identities, the provider
  returns `{:ok, %{}}`, allowing the operator inbox to degrade gracefully
  rather than surface an error (fail-open contract from `Cairnloop.ContextProvider`).

  No database queries, external calls, or atom creation from input are performed.
  All branching is pattern-matched against string literals, satisfying the
  ASVS V5 atom-table exhaustion requirement.
  """

  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context("demo_user_acme_billing", _opts) do
    {:ok,
     %{
       "User Details" => %{
         name: "Riya Chen",
         email: "riya@acme.example",
         joined: "2025-08-14"
       },
       "Active Plan" => %{
         tier: "Team",
         seats: 8,
         status: "past due"
       },
       "Recent Charges" => %{
         last_charge_at: "2026-05-12",
         last_amount: "$48.00",
         currency: "USD"
       }
     }}
  end

  @impl true
  def get_context("demo_user_globex_seats", _opts) do
    {:ok,
     %{
       "User Details" => %{
         name: "Mateo Alvarez",
         email: "mateo@globex.example",
         joined: "2025-11-02"
       },
       "Active Plan" => %{
         tier: "Team",
         seats: 4,
         status: "active"
       },
       "Seats" => %{
         seats_used: 4,
         seats_total: 4,
         pending_invites: 1
       }
     }}
  end

  @impl true
  def get_context("demo_user_initech_billing", _opts) do
    {:ok,
     %{
       "User Details" => %{
         name: "Sora Lin",
         email: "sora@initech.example",
         joined: "2024-09-30"
       },
       "Active Plan" => %{
         tier: "Starter",
         seats: 2,
         status: "active"
       },
       "Billing" => %{
         billing_email: "accounts@initech.example",
         payment_method: "card ending 4242"
       }
     }}
  end

  @impl true
  def get_context("demo_user_umbrella_ci", _opts) do
    {:ok,
     %{
       "User Details" => %{
         name: "Priya Sharma",
         email: "priya@umbrella.example",
         joined: "2026-01-15"
       },
       "Active Plan" => %{
         tier: "Pro",
         seats: 12,
         status: "active"
       },
       "Recent CI Runs" => %{
         last_run_at: "2026-05-25T18:22:00Z",
         last_run_status: "skipped",
         consecutive_skips: 3
       }
     }}
  end

  @impl true
  def get_context("demo_user_hooli_tokens", _opts) do
    {:ok,
     %{
       "User Details" => %{
         name: "Jonas Weber",
         email: "jonas@hooli.example",
         joined: "2025-04-08"
       },
       "Active Plan" => %{
         tier: "Team",
         seats: 6,
         status: "active"
       },
       "API Keys" => %{
         active_keys: 2,
         last_rotated_at: "2026-02-10",
         expiring_within_30_days: 1
       }
     }}
  end

  @impl true
  def get_context(_actor_id, _opts) do
    {:ok, %{}}
  end
end
