defmodule Cairnloop.DoctorTest do
  @moduledoc """
  Exercises the `Cairnloop.Doctor` engine behind `mix cairnloop.doctor` with fabricated host
  routers + injected config — DB-free, no live app. Proves the doctor catches the
  "compiles but isn't wired" problems (unmounted dashboard / operations, no-op auditor,
  missing repo) and degrades gracefully when the router can't be found.
  """
  use ExUnit.Case, async: true

  alias Cairnloop.Doctor

  defmodule FullRouter do
    use Phoenix.Router
    require Cairnloop.Router

    scope "/" do
      Cairnloop.Router.cairnloop_dashboard("/support")
    end

    scope "/" do
      Cairnloop.Router.cairnloop_operations()
    end
  end

  defmodule BareRouter do
    use Phoenix.Router
  end

  defp levels(findings), do: Enum.map(findings, &elem(&1, 0))
  defp text(findings), do: findings |> Enum.map(&elem(&1, 1)) |> Enum.join("\n")

  describe "a fully wired host" do
    test "reports no blocking issues and confirms the mounted surfaces" do
      findings =
        Doctor.checks(FullRouter,
          repo: MyApp.Repo,
          auditor: Cairnloop.Auditor.Governance,
          tools: []
        )

      assert Doctor.tally(findings).error == 0
      assert text(findings) =~ "Operator dashboard is mounted"
      assert text(findings) =~ "Audit-log timeline is mounted"
      assert text(findings) =~ "`/health` is mounted"
    end
  end

  describe "a missing repo" do
    test "is a blocking error" do
      findings = Doctor.checks(FullRouter, repo: nil, auditor: Cairnloop.Auditor.Governance)

      assert :error in levels(findings)
      assert text(findings) =~ "`:cairnloop, :repo`"
    end
  end

  describe "an unresolvable router" do
    test "warns once and skips the route-dependent checks" do
      findings = Doctor.checks(nil, repo: MyApp.Repo, auditor: Cairnloop.Auditor.Governance)

      assert text(findings) =~ "Could not locate your Phoenix router"
      # Route-dependent checks are skipped rather than guessing.
      refute text(findings) =~ "dashboard is not mounted"
      refute text(findings) =~ "are not mounted"
    end
  end

  describe "a degraded auditor" do
    test "warns when the dashboard is mounted but the auditor is the no-op default" do
      findings = Doctor.checks(FullRouter, repo: MyApp.Repo, auditor: Cairnloop.Auditor.NoOp)

      assert :warn in levels(findings)
      assert text(findings) =~ "audit log is mounted but"
    end
  end

  describe "an empty router" do
    test "warns that the dashboard and operations endpoints are unmounted" do
      findings =
        Doctor.checks(BareRouter, repo: MyApp.Repo, auditor: Cairnloop.Auditor.Governance)

      msg = text(findings)
      assert msg =~ "operator dashboard is not mounted"
      assert msg =~ "`/health` and `/metrics` are not mounted"
    end
  end
end
