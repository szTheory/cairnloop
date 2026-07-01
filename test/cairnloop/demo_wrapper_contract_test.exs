defmodule Cairnloop.DemoWrapperContractTest do
  @moduledoc """
  DB-free source contract for the Docker demo wrapper.

  The test reads wrapper and Compose source only. It never starts Docker,
  Phoenix, Repo, browser tooling, or `./bin/demo smoke`.
  """

  use ExUnit.Case, async: true

  @wrapper_path "bin/demo"
  @compose_path "examples/cairnloop_example/compose.demo.yml"

  @url_routes [
    {"Demo index:", "/"},
    {"Operator cockpit:", "/support"},
    {"Inbox:", "/support/inbox"},
    {"Customer chat:", "/chat"},
    {"Knowledge Base:", "/support/knowledge-base"},
    {"Gaps:", "/support/knowledge-base/gaps"},
    {"Suggestions:", "/support/knowledge-base/suggestions"},
    {"Audit log:", "/support/audit-log"},
    {"Settings:", "/support/settings"},
    {"Health:", "/health"}
  ]

  @smoke_routes ~w(
    /
    /support
    /support/inbox
    /chat
    /support/knowledge-base
    /support/knowledge-base/gaps
    /support/knowledge-base/suggestions
    /support/audit-log
    /support/settings
  )

  test "wrapper shell syntax and command surface stay canonical" do
    {bash_output, bash_exit} = System.cmd("bash", ["-n", @wrapper_path], stderr_to_stdout: true)
    assert bash_exit == 0, "Expected #{@wrapper_path} to pass bash -n:\n#{bash_output}"

    source = wrapper_source()
    help = help_output()

    for expected <- [
          "start|up)",
          "urls)",
          "logs)",
          "stop)",
          "down)",
          "reset)",
          "smoke)",
          "ps|status)",
          "help|-h|--help)"
        ] do
      assert_contains(source, expected)
    end

    assert_contains(help, "ps")
    assert_contains(help, "status")
  end

  test "printed URL block and smoke route list use the locked demo routes" do
    source = wrapper_source()

    for {label, path} <- @url_routes do
      assert source =~ ~r/#{Regex.escape(label)}\s+\$url#{Regex.escape(path)}/,
             "Expected print_urls/0 to include #{label} $url#{path}"
    end

    assert_ordered_route_block(source)
  end

  test "browser URLs are discovered from Compose instead of assuming port 4000" do
    source = wrapper_source()

    assert_contains(source, ~s(compose port web "$CONTAINER_PORT"))

    refute source =~ "localhost:4000",
           "Expected #{@wrapper_path} not to print Docker demo browser URLs with localhost:4000"

    refute source =~ "127.0.0.1:4000",
           "Expected #{@wrapper_path} not to print Docker demo browser URLs with 127.0.0.1:4000"
  end

  test "Compose keeps Postgres private and publishes only Phoenix on localhost" do
    compose = compose_source()

    assert db_service_block(compose) =~ "image: pgvector/pgvector:pg16"

    refute db_service_block(compose) =~ ~r/^\s+ports:/m,
           "Expected db service to remain private with no host ports block"

    for expected <- [
          ~s(host_ip: "${CAIRNLOOP_BIND_HOST:-127.0.0.1}"),
          ~s(published: "${CAIRNLOOP_WEB_PORT:-4100-4199}"),
          "target: 4000"
        ] do
      assert_contains(compose, expected)
    end
  end

  test "smoke uses isolated Compose scope, locked routes, and project-scoped cleanup" do
    source = wrapper_source()

    for expected <- [
          "_smoke",
          "CAIRNLOOP_SMOKE_WEB_PORT",
          "compose down -v --remove-orphans",
          "Docker demo smoke passed."
        ] do
      assert_contains(source, expected)
    end

    for route <- @smoke_routes do
      assert_contains(source, ~s(smoke_route "$url" "#{route}"))
    end
  end

  test "failure diagnostics name the boundary and include recent web logs" do
    source = wrapper_source()

    for expected <- [
          "wait_for_web_endpoint",
          "recent_web_logs",
          "fail_with_web_logs",
          "run_compose_or_explain",
          "Recent web logs:",
          "compose logs --tail=80 web",
          "Smoke check failed for"
        ] do
      assert_contains(source, expected)
    end
  end

  test "start and smoke do not require host curl or a free first default port" do
    source = wrapper_source()

    for expected <- [
          "compose_up_with_port_fallback",
          "address already in use",
          "ports are not available",
          "web_get",
          ~s(compose exec -T web curl -fsS),
          ~s(export CAIRNLOOP_WEB_PORT="$port"),
          ~S(_smoke_${smoke_id})
        ] do
      assert_contains(source, expected)
    end

    refute source =~ ~r/^\s*(?:until|if)\s+curl\s+-/m,
           "Expected wrapper readiness and smoke checks to use container-backed curl, not host curl"
  end

  defp wrapper_source, do: File.read!(@wrapper_path)
  defp compose_source, do: File.read!(@compose_path)

  defp help_output do
    {output, exit} = System.cmd("bash", [@wrapper_path, "help"], stderr_to_stdout: true)
    assert exit == 0, "Expected ./bin/demo help to exit 0:\n#{output}"
    output
  end

  defp assert_contains(source, expected) do
    assert source =~ expected, "Expected source to include #{inspect(expected)}"
  end

  defp assert_ordered_route_block(source) do
    positions =
      Enum.map(@smoke_routes, fn route ->
        needle = ~s(smoke_route "$url" "#{route}")

        case :binary.match(source, needle) do
          {position, _length} -> position
          :nomatch -> flunk("Expected smoke route list to include #{inspect(needle)}")
        end
      end)

    assert positions == Enum.sort(positions),
           "Expected smoke routes to remain in the locked Phase 54 order"
  end

  defp db_service_block(compose) do
    case Regex.run(~r/\n  db:\n(?<block>.*?)(?=\n  web:\n)/s, compose, capture: ["block"]) do
      [block] -> block
      nil -> flunk("Expected #{inspect(@compose_path)} to contain a db service before web")
    end
  end
end
