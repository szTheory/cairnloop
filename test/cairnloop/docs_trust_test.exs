defmodule Cairnloop.DocsTrustTest do
  use ExUnit.Case, async: true

  @mcp_guide_path Path.expand("../../guides/05-mcp-clients.md", __DIR__)
  @extending_guide_path Path.expand("../../guides/06-extending.md", __DIR__)
  @auth_guide_path Path.expand("../../guides/07-auth-and-operator-identity.md", __DIR__)
  @readme_path Path.expand("../../README.md", __DIR__)
  @quickstart_path Path.expand("../../guides/01-quickstart.md", __DIR__)
  @example_readme_path Path.expand("../../examples/cairnloop_example/README.md", __DIR__)
  @host_integration_path Path.expand("../../guides/03-host-integration.md", __DIR__)
  @troubleshooting_path Path.expand("../../guides/04-troubleshooting.md", __DIR__)
  @mcp_guide File.read!(@mcp_guide_path)
  @extending_guide File.read!(@extending_guide_path)
  @auth_guide File.read!(@auth_guide_path)
  @readme File.read!(@readme_path)
  @quickstart File.read!(@quickstart_path)
  @example_readme File.read!(@example_readme_path)
  @host_integration File.read!(@host_integration_path)
  @troubleshooting File.read!(@troubleshooting_path)
  @combined_docs [@host_integration, @troubleshooting, @mcp_guide] |> Enum.join("\n\n")

  defp section(markdown, heading) do
    [_before, rest] = String.split(markdown, heading, parts: 2)

    rest
    |> String.split(~r/\n## /, parts: 2)
    |> hd()
  end

  describe "MCP auth guide" do
    test "names the live AuthPlug module and no stale auth module" do
      assert @mcp_guide =~ "Cairnloop.Web.MCP.AuthPlug"
      refute @mcp_guide =~ "Cairnloop.Web.MCP.Auth\n"
      refute @mcp_guide =~ "Cairnloop.Web.MCP.Auth "
    end

    test "does not claim raw tokens have a fixed public prefix" do
      refute @mcp_guide =~ "cl_mcp_"
      assert @mcp_guide =~ "raw token"
      assert @mcp_guide =~ "opaque copy-once"
      assert @mcp_guide =~ "SHA-256"
    end

    test "states token-required JSON-RPC methods require a valid Bearer token" do
      for method <- ["initialize", "tools/list", "tools/call"] do
        assert @mcp_guide =~ method
      end

      assert @mcp_guide =~
               "`initialize`, `tools/list`, and `tools/call` require a valid Bearer token"
    end

    test "keeps well-known metadata as the public discovery surface" do
      assert @mcp_guide =~ "well-known"
      assert @mcp_guide =~ "public discovery"
      assert @mcp_guide =~ "token-required"
    end

    test "states governed MCP writes create proposals instead of inline execution" do
      assert @mcp_guide =~ "Cairnloop.Governance.propose/3"
      assert @mcp_guide =~ "proposal"
      assert @mcp_guide =~ "not inline `run/3` execution"
    end
  end

  describe "Auth and operator identity guide" do
    test "shows host route auth around the dashboard and per-request session MFA" do
      assert @auth_guide =~ "pipe_through [:browser, :require_admin]"
      assert @auth_guide =~ "on_mount: [{MyAppWeb.UserAuth, :ensure_admin}]"
      assert @auth_guide =~ "session: {MyAppWeb.UserAuth, :cairnloop_session, []}"
      assert @auth_guide =~ "once per HTTP request"
    end

    test "labels static session maps as demo-only and unsafe for production" do
      assert @auth_guide =~ "Demo only. Do NOT ship this."
      assert @auth_guide =~ "static session maps are demo-only traps"
      assert @auth_guide =~ "frozen at build time"
      assert @auth_guide =~ "identical for every request"
    end

    test "public host-app docs do not copy-paste static production operator identity" do
      production_docs = %{
        "README.md" => @readme,
        "guides/01-quickstart.md" => @quickstart
      }

      for {path, source} <- production_docs do
        refute source =~ ~s(session: %{"host_user_id" => "demo_operator"}),
               "Expected #{path} not to show a static production dashboard session"
      end

      assert @quickstart =~ "session: {MyAppWeb.UserAuth, :cairnloop_session, []}",
             "Expected Quickstart to use per-request LiveView session MFA"

      refute @example_readme =~ ~s(session: %{"host_user_id" => "demo_operator"})
    end
  end

  describe "Extending guide" do
    test "shows the current governed tool macro and callbacks" do
      assert @extending_guide =~ "use Cairnloop.Tool,"
      assert @extending_guide =~ "risk_tier: :low_write"
      assert @extending_guide =~ "def changeset(struct, attrs)"
      assert @extending_guide =~ "def scope"
      assert @extending_guide =~ "def run(%__MODULE__{} = tool, _actor_id, context)"
      assert @extending_guide =~ "Cairnloop.Governance.propose/3"

      refute @extending_guide =~ "def spec do"
      refute @extending_guide =~ "risk_tier: :requires_approval"
    end

    test "shows current embedder, draft generator, and auditor callbacks" do
      assert @extending_guide =~
               "@callback generate_embeddings(chunks :: [String.t()], opts :: keyword())"

      assert @extending_guide =~ "Cairnloop.Automation.DraftGenerator"
      assert @extending_guide =~ "@callback generate_draft("
      assert @extending_guide =~ "@callback audit("
      assert @extending_guide =~ "@callback list_events(opts :: keyword())"

      refute @extending_guide =~ "@callback embed(text :: String.t(), opts :: keyword())"
      refute @extending_guide =~ "@callback log_event("
    end
  end

  describe "Phase 58 operational trust docs" do
    test "host integration documents health as liveness only and points readiness to doctor" do
      operations = section(@host_integration, "## Operations endpoints")

      assert operations =~ "`GET /health`"
      assert operations =~ "liveness only"
      assert operations =~ "mix cairnloop.doctor"

      refute operations =~ "liveness/readiness"
      refute operations =~ "readiness probe"
      refute operations =~ "ready when the database"
      refute operations =~ "checks DB"
      refute operations =~ "checks Oban"
      refute operations =~ "checks pgvector"
      refute operations =~ "checks notifier"
      refute operations =~ "checks MCP"
      refute operations =~ "checks Scrypath"
    end

    test "Scrypath docs describe opt-in, disabled, and misconfigured no-enqueue states" do
      assert @combined_docs =~ "Scrypath automation is disabled"
      assert @combined_docs =~ "unless the host opts in"
      assert @combined_docs =~ "Scrypath automation is enabled but not ready"
      assert @combined_docs =~ "will not enqueue"

      refute @combined_docs =~ "Scrypath automation is enabled by default"
      refute @combined_docs =~ "Scrypath runs by default"
    end

    test "troubleshooting identifies trust failure domains and doctor guidance" do
      for expected <- [
            "mix cairnloop.doctor",
            "host config",
            "DB state",
            "Oban",
            "Cairnloop wiring",
            "external dependency",
            "Widget ingress is blocked",
            "Email webhook ingress is blocked",
            "MCP request blocked",
            "Scrypath automation is disabled",
            "Scrypath automation is enabled but not ready"
          ] do
        assert @troubleshooting =~ expected
      end
    end

    test "telemetry docs keep default examples bounded and reject sensitive metadata logging" do
      telemetry = section(@host_integration, "## Telemetry")

      assert telemetry =~ "Default telemetry is bounded"
      assert telemetry =~ "not customer message bodies, secrets, or raw payloads"
      assert telemetry =~ "conversation_id"

      refute telemetry =~ "conversation = metadata.conversation"
      refute telemetry =~ "metadata.actor"
      refute telemetry =~ "metadata.host_user_id"
      refute telemetry =~ "metadata.raw_payload"
      refute telemetry =~ "raw_body"
      refute telemetry =~ "support message body"
      refute telemetry =~ "full Conversation"
    end
  end
end
