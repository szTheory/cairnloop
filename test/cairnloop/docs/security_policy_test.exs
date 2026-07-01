defmodule Cairnloop.Docs.SecurityPolicyTest do
  @moduledoc """
  DB-free source scan for SECURITY.md as a public OSS vulnerability-reporting policy.

  The test reads Markdown only. It never starts Repo, Phoenix, browser tooling, Docker, or
  external network clients.
  """

  use ExUnit.Case, async: true

  @security_path "SECURITY.md"
  @security File.read!(@security_path)

  test "policy includes public OSS support and private reporting sections" do
    for expected <- [
          "# Security Policy",
          "## Supported Versions",
          "latest released version",
          "`main`",
          "## Reporting a Vulnerability",
          "privately through GitHub Security Advisories",
          "working exploit",
          "public issue",
          "## Scope",
          "## Response Posture"
        ] do
      assert_contains(@security, expected)
    end
  end

  test "reporters are asked for impacted version, config, and data-impact details" do
    reporting = section(@security, "## Reporting a Vulnerability")

    for expected <- [
          "affected version or commit",
          "impact and attacker capability",
          "reproduction steps",
          "relevant configuration",
          "route/auth exposure",
          "Phoenix/Ecto/Oban setup",
          "sensitive customer/support data"
        ] do
      assert_contains(reporting, expected)
    end
  end

  test "scope names host responsibilities and Cairnloop-sensitive areas" do
    scope = section(@security, "## Scope")

    for expected <- [
          "operator identity",
          "host-auth integration",
          "email/webhook ingress",
          "governed tool approvals",
          "outbound side effects",
          "MCP tokens",
          "telemetry/logging",
          "database migrations",
          "schema-prefix behavior",
          "route",
          "authentication",
          "authorization policy",
          "secret storage",
          "backup/restore",
          "production monitoring"
        ] do
      assert_contains(scope, expected)
    end
  end

  test "policy avoids internal planning, compliance, SLA, and public exploit ceremony" do
    forbidden_patterns = [
      {"internal phase", ~r/internal phase/i},
      {".planning", ~r/\.planning/},
      {"SLA", ~r/\bSLA\b/},
      {"enterprise support", ~r/enterprise support/i},
      {"SOC 2", ~r/SOC\s*2/i},
      {"HIPAA", ~r/HIPAA/i},
      {"PCI", ~r/\bPCI\b/i},
      {"publish exploit details in public issues", ~r/publish.*exploit.*public issue/i},
      {"post exploit details in public issues", ~r/post.*exploit.*public issue/i},
      {"open a public issue with exploit details", ~r/open.*public issue.*exploit/i}
    ]

    for {label, pattern} <- forbidden_patterns do
      refute Regex.match?(pattern, @security), "Expected SECURITY.md not to contain #{label}"
    end
  end

  defp section(markdown, heading) do
    [_before, rest] = String.split(markdown, heading, parts: 2)

    rest
    |> String.split(~r/\n## /, parts: 2)
    |> hd()
  end

  defp assert_contains(source, expected) do
    assert source =~ expected, "Expected #{@security_path} to include #{inspect(expected)}"
  end
end
