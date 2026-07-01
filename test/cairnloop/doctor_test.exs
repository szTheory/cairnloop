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

  defmodule WidgetVerifier do
    def verify(_token_or_params, _opts), do: {:ok, %{customer_ref: "customer_123"}}
  end

  defmodule EmailVerifier do
    def verify(_conn), do: {:ok, :verified}
  end

  defmodule ReadyNotifier do
    def on_conversation_resolved(_conversation, _metadata), do: :ok
    def on_sla_breach(_conversation, _sla, _metadata), do: :ok
    def on_outbound_triggered(_message, _conversation), do: :ok
  end

  defp levels(findings), do: Enum.map(findings, &elem(&1, 0))
  defp text(findings), do: findings |> Enum.map(&elem(&1, 1)) |> Enum.join("\n")

  defp ready_opts(overrides \\ []) do
    Keyword.merge(
      [
        repo: MyApp.Repo,
        auditor: Cairnloop.Auditor.Governance,
        tools: [],
        widget_token_verifier: WidgetVerifier,
        email_webhook_verifier: EmailVerifier,
        notifier: ReadyNotifier,
        scrypath_automation_enabled: true,
        scrypath_api_url: "https://scrypath.example.test/v1/index",
        scrypath_api_key: "scrypath_live_key"
      ],
      overrides
    )
  end

  describe "a fully wired host" do
    test "reports no blocking issues and confirms the mounted surfaces" do
      findings = Doctor.checks(FullRouter, ready_opts())

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

  describe "Phase 58 trust diagnostics" do
    test "reports ready widget, email, MCP, notifier, Oban, retrieval, and Scrypath posture" do
      findings = Doctor.checks(FullRouter, ready_opts())
      msg = text(findings)

      assert msg =~ "Ready: Widget ingress has a host verifier configured"
      assert msg =~ "Ready: Email webhook request authentication is configured"
      assert msg =~ "Ready: MCP token-required methods enforce Bearer authentication"
      assert msg =~ "Ready: Notifier callbacks are configured"
      assert msg =~ "Ready: Oban is available"
      assert msg =~ "Ready: pgvector library is available"
      assert msg =~ "Ready: Scrypath automation is enabled with non-placeholder config"

      assert msg =~ "Not checked here: doctor did not query stored MCP token rows"

      assert msg =~
               "Not checked here: doctor did not query the database, Oban queues, or pgvector indexes"
    end

    test "reports missing auth seams and disabled side effects without hard failure" do
      findings =
        Doctor.checks(
          FullRouter,
          ready_opts(
            widget_token_verifier: nil,
            email_webhook_verifier: nil,
            email_webhook_token: nil,
            notifier: nil,
            scrypath_automation_enabled: false
          )
        )

      tally = Doctor.tally(findings)
      msg = text(findings)

      assert tally.error == 0
      assert tally.warn >= 2
      assert msg =~ "Blocked: Widget ingress is blocked because no host verifier is configured"

      assert msg =~
               "Blocked: Email webhook ingress is blocked until the host configures request authentication"

      assert msg =~
               "Scrypath automation is disabled. Resolved conversations will stay inside Cairnloop unless the host opts in."

      assert msg =~ "No custom notifier configured"
    end

    test "reports unsafe Scrypath config as blocked without printing URL or key values" do
      findings =
        Doctor.checks(
          FullRouter,
          ready_opts(
            scrypath_api_url: "https://api.scrypath.local/v1/index",
            scrypath_api_key: "dummy"
          )
        )

      msg = text(findings)

      assert :warn in levels(findings)
      assert msg =~ "Blocked: Scrypath automation is enabled but not ready"
      assert msg =~ "API URL"
      assert msg =~ "API key"
      refute msg =~ "https://api.scrypath.local/v1/index"
      refute msg =~ "dummy"
    end

    test "doctor copy avoids raw host values and credential-bearing output" do
      findings =
        Doctor.checks(
          FullRouter,
          ready_opts(
            email_webhook_token: "super-secret-token",
            scrypath_api_url: "https://user:pass@scrypath.example.test/v1/index",
            scrypath_api_key: "scrypath_live_key"
          )
        )

      msg = text(findings)

      refute msg =~ "super-secret-token"
      refute msg =~ "user:pass"
      refute msg =~ "scrypath_live_key"
      refute msg =~ "%{"
      refute msg =~ "{:"
      refute msg =~ "#"
    end
  end

  describe "Phase 59 schema-prefix diagnostics" do
    test "reports the configured dedicated Cairnloop support prefix without claiming DB proof" do
      findings = Doctor.checks(FullRouter, ready_opts(schema_prefix: "cairnloop"))
      msg = text(findings)

      assert msg =~
               "Ready: Cairnloop support tables are configured for Postgres schema `cairnloop`"

      assert msg =~
               "Not checked here: doctor did not query information_schema or Cairnloop tables"
    end

    test "reports explicit public-schema compatibility mode" do
      findings = Doctor.checks(FullRouter, ready_opts(schema_prefix: "public"))
      msg = text(findings)

      assert msg =~ "public-schema compatibility"
      assert msg =~ "explicitly configured"

      assert msg =~
               "Not checked here: doctor did not query information_schema or Cairnloop tables"
    end

    test "reports nil legacy public-schema compatibility mode" do
      findings = Doctor.checks(FullRouter, ready_opts(schema_prefix: nil))
      msg = text(findings)

      assert msg =~ "legacy public-schema compatibility"

      assert msg =~
               "Not checked here: doctor did not query information_schema or Cairnloop tables"
    end

    test "reports invalid schema prefixes calmly without raw stack traces or raw config output" do
      findings = Doctor.checks(FullRouter, ready_opts(schema_prefix: "bad-prefix!"))
      msg = text(findings)

      assert :error in levels(findings)
      assert msg =~ "Blocked: Cairnloop schema prefix is invalid"
      assert msg =~ "expected nil, `public`, or a single SQL identifier"
      refute msg =~ "bad-prefix!"
      refute msg =~ "** (ArgumentError)"
      refute msg =~ "stacktrace"
    end
  end
end
