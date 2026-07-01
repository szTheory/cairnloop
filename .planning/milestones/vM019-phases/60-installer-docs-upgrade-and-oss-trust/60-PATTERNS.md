# Phase 60: Installer, Docs, Upgrade, and OSS Trust - Pattern Map

**Mapped:** 2026-06-30
**Files analyzed:** 28 new/modified candidate files
**Analogs found:** 28 / 28

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `README.md` | documentation | file-I/O / transform | `README.md`, `lib/mix/tasks/cairnloop/install.ex` | exact |
| `guides/01-quickstart.md` | documentation | file-I/O / transform | `guides/01-quickstart.md`, `lib/mix/tasks/cairnloop/install.ex` | exact |
| `guides/02-jtbd-walkthrough.md` | documentation | file-I/O / asset reference | `guides/02-jtbd-walkthrough.md`, `test/cairnloop/web/collateral_wiring_test.exs` | exact |
| `guides/03-host-integration.md` | documentation | request-response / transform | `guides/03-host-integration.md`, `test/cairnloop/docs_trust_test.exs` | exact |
| `guides/04-troubleshooting.md` | documentation | file-I/O / transform | `guides/04-troubleshooting.md`, `test/cairnloop/docs/docker_first_docs_test.exs` | exact |
| `guides/05-mcp-clients.md` | documentation | request-response / auth contract | `test/cairnloop/docs_trust_test.exs` | role-match |
| `guides/06-extending.md` | documentation | API contract / transform | `guides/03-host-integration.md` | role-match |
| `guides/07-auth-and-operator-identity.md` | documentation | request-response / auth contract | `guides/07-auth-and-operator-identity.md` | exact |
| `SECURITY.md` | documentation | trust policy / transform | `SECURITY.md`, `test/cairnloop/docs_trust_test.exs` | exact |
| `UPGRADING.md` | documentation | upgrade / file-I/O | `UPGRADING.md`, `test/cairnloop/schema_prefix_test.exs` | exact |
| `CHANGELOG.md` | documentation | release metadata / transform | `CHANGELOG.md` | exact |
| `examples/cairnloop_example/README.md` | documentation | file-I/O / request-response | `examples/cairnloop_example/README.md` | exact |
| `guides/assets/02-operator-inbox.png` or guide reference fix | asset | file-I/O | `guides/assets/02b-operator-inbox.png`, `test/cairnloop/web/collateral_wiring_test.exs` | role-match |
| `mix.exs` | config | package/docs build | `mix.exs` | exact |
| `lib/mix/tasks/cairnloop/install.ex` | task | codegen / request-response notice | `lib/mix/tasks/cairnloop/install.ex` | exact |
| `lib/mix/tasks/cairnloop.doctor.ex` | task | request-response CLI | `lib/mix/tasks/cairnloop.doctor.ex` | exact |
| `lib/cairnloop.ex` | documentation module | transform | `lib/cairnloop.ex` | exact |
| `lib/cairnloop/schema_prefix.ex` | utility | transform / config normalization | `lib/cairnloop/schema_prefix.ex` | exact |
| `lib/cairnloop/doctor.ex` | service/utility | request-response diagnostics | `lib/cairnloop/doctor.ex` | exact |
| `test/cairnloop/docs/install_upgrade_truth_test.exs` | test | file-I/O / source-scan | `test/cairnloop/tasks/install_test.exs`, `test/cairnloop/demo_runtime_contract_test.exs` | exact |
| `test/cairnloop/docs/package_docs_truth_test.exs` | test | file-I/O / package source-scan | `test/cairnloop/web/collateral_wiring_test.exs` | exact |
| `test/cairnloop/docs/security_policy_test.exs` | test | file-I/O / source-scan | `test/cairnloop/docs_trust_test.exs` | exact |
| `test/cairnloop/tasks/install_test.exs` | test | file-I/O / installer source-scan | `test/cairnloop/tasks/install_test.exs` | exact |
| `test/cairnloop/docs_trust_test.exs` | test | file-I/O / trust source-scan | `test/cairnloop/docs_trust_test.exs` | exact |
| `test/cairnloop/docs/docker_first_docs_test.exs` | test | file-I/O / docs source-scan | `test/cairnloop/docs/docker_first_docs_test.exs` | exact |
| `test/cairnloop/demo_runtime_contract_test.exs` | test | file-I/O / source contract | `test/cairnloop/demo_runtime_contract_test.exs` | exact |
| `test/cairnloop/web/collateral_wiring_test.exs` | test | file-I/O / package+asset source-scan | `test/cairnloop/web/collateral_wiring_test.exs` | exact |
| `test/cairnloop/schema_prefix_test.exs` | test | config / transform | `test/cairnloop/schema_prefix_test.exs` | exact |

## Pattern Assignments

### `test/cairnloop/docs/install_upgrade_truth_test.exs` (test, file-I/O / source-scan)

**Analog:** `test/cairnloop/tasks/install_test.exs` and `test/cairnloop/demo_runtime_contract_test.exs`

**Imports/module pattern** (`test/cairnloop/tasks/install_test.exs` lines 1-7):
```elixir
defmodule Mix.Tasks.Cairnloop.InstallTest do
  use ExUnit.Case, async: true

  @source_path "lib/mix/tasks/cairnloop/install.ex"
  @test_host_migration_path "priv/test_host/migrations/20260101000000_create_host_owned_tables.exs"
  @example_migration_path "examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs"
```

**Installer truth assertions** (`test/cairnloop/tasks/install_test.exs` lines 17-34):
```elixir
test "installer notice includes required repo config and dependency migrations" do
  source = File.read!(@source_path)

  assert source =~ "config :cairnloop, :repo, MyApp.Repo"
  assert source =~ ~s(config :cairnloop, :schema_prefix, "cairnloop")
  assert source =~ ~s(config :cairnloop, :schema_prefix, "public")
  assert source =~ "legacy `nil`"

  assert source =~
           "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations"

  refute source =~
           "mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations --prefix cairnloop"
end
```

**Cross-doc version and migration order pattern** (`test/cairnloop/demo_runtime_contract_test.exs` lines 127-158):
```elixir
test "docs preserve dependency split, migration order, and printed URL boundary" do
  version = project_version()
  readme = read!(@readme_path)
  quickstart = read!(@quickstart_path)
  troubleshooting = read!(@troubleshooting_path)
  example_readme = read!(@example_readme_path)

  for source <- [readme, quickstart] do
    assert_contains(source, ~s({:cairnloop, "~> #{version}"}))
  end

  assert_contains(readme, ~s({:cairnloop, path: "../.."}))
  assert_contains(quickstart, "Run host migrations")
  assert_contains(quickstart, "Run the Cairnloop library's own migrations")
end
```

**Helper pattern** (`test/cairnloop/demo_runtime_contract_test.exs` lines 189-253):
```elixir
defp read!(path), do: File.read!(path)

defp project_version do
  @root_mix_path
  |> read!()
  |> then(fn source ->
    case Regex.run(~r/version:\s+"([^"]+)"/, source, capture: :all_but_first) do
      [version] -> version
      nil -> flunk("Could not find project version in #{@root_mix_path}")
    end
  end)
end

defp assert_contains(source, expected) do
  assert source =~ expected, "Expected source to include #{inspect(expected)}"
end
```

**Apply to:** create this test under `test/cairnloop/docs/`; scan `README.md`, `guides/01-quickstart.md`, `guides/03-host-integration.md`, `guides/04-troubleshooting.md`, `UPGRADING.md`, `examples/cairnloop_example/README.md`, and `lib/mix/tasks/cairnloop/install.ex`. Add explicit `refute` checks for recommended `schema_prefix: nil`, dependency migration `--prefix cairnloop`, and split-brain public compatibility wording.

---

### `test/cairnloop/docs/package_docs_truth_test.exs` (test, file-I/O / package source-scan)

**Analog:** `test/cairnloop/web/collateral_wiring_test.exs`

**Package file allowlist pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 31-47):
```elixir
@package_files ~w(
  lib
  priv
  mix.exs
  README.md
  LICENSE
  SECURITY.md
  UPGRADING.md
  CHANGELOG.md
  guides/01-quickstart.md
  guides/02-jtbd-walkthrough.md
  guides/03-host-integration.md
  guides/04-troubleshooting.md
  guides/05-mcp-clients.md
  guides/06-extending.md
  guides/07-auth-and-operator-identity.md
)
```

**Package metadata assertion pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 265-282):
```elixir
test "Hex package files allowlist keeps brand collateral unshipped" do
  mix_exs = File.read!("mix.exs")
  expected = Enum.join(@package_files, " ")

  assert mix_exs =~ ~r/files:\s*~w\([^)]*guides\/01-quickstart\.md[^)]*\)/,
         "Expected mix.exs package files allowlist to remain files: ~w(#{expected})"

  [_, files] = Regex.run(~r/files:\s*~w\(([^)]*)\)/, mix_exs)
  package_files = String.split(files)

  assert package_files == @package_files,
         "Expected package files #{inspect(@package_files)}, got #{inspect(package_files)}"
end
```

**Tracked file helper pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 284-290):
```elixir
defp tracked_files(pattern) do
  {output, 0} = System.cmd("git", ["ls-files", pattern], stderr_to_stdout: true)

  output
  |> String.split("\n", trim: true)
  |> Enum.sort()
end
```

**Apply to:** compare `mix.exs` `package[:files]`, `docs[:extras]`, and `docs[:assets]`; verify every guide linked from README/ExDoc exists; scan Markdown image links like `](assets/*.png)` and assert the corresponding `guides/assets/*` file exists. Use `System.cmd("git", ["ls-files", pattern])` rather than shell pipelines inside tests.

---

### `test/cairnloop/docs/security_policy_test.exs` (test, file-I/O / source-scan)

**Analog:** `test/cairnloop/docs_trust_test.exs`

**Module and eager file-read pattern** (`test/cairnloop/docs_trust_test.exs` lines 1-10):
```elixir
defmodule Cairnloop.DocsTrustTest do
  use ExUnit.Case, async: true

  @mcp_guide_path Path.expand("../../guides/05-mcp-clients.md", __DIR__)
  @host_integration_path Path.expand("../../guides/03-host-integration.md", __DIR__)
  @troubleshooting_path Path.expand("../../guides/04-troubleshooting.md", __DIR__)
  @mcp_guide File.read!(@mcp_guide_path)
  @host_integration File.read!(@host_integration_path)
  @troubleshooting File.read!(@troubleshooting_path)
  @combined_docs [@host_integration, @troubleshooting, @mcp_guide] |> Enum.join("\n\n")
```

**Section extraction pattern** (`test/cairnloop/docs_trust_test.exs` lines 12-18):
```elixir
defp section(markdown, heading) do
  [_before, rest] = String.split(markdown, heading, parts: 2)

  rest
  |> String.split(~r/\n## /, parts: 2)
  |> hd()
end
```

**Allow/deny trust assertion style** (`test/cairnloop/docs_trust_test.exs` lines 49-66):
```elixir
test "host integration documents health as liveness only and points readiness to doctor" do
  operations = section(@host_integration, "## Operations endpoints")

  assert operations =~ "`GET /health`"
  assert operations =~ "liveness only"
  assert operations =~ "mix cairnloop.doctor"

  refute operations =~ "liveness/readiness"
  refute operations =~ "readiness probe"
  refute operations =~ "checks DB"
end
```

**Apply to:** assert `SECURITY.md` includes supported version posture, private reporting, impacted version/config details, host responsibilities, and security-sensitive areas. Refute internal planning language, enterprise SLA wording, compliance claims, public exploit disclosure instructions, and broad version support promises.

---

### Existing Source-Scan Tests

**Files:** `test/cairnloop/tasks/install_test.exs`, `test/cairnloop/docs_trust_test.exs`, `test/cairnloop/docs/docker_first_docs_test.exs`, `test/cairnloop/demo_runtime_contract_test.exs`, `test/cairnloop/web/collateral_wiring_test.exs`, `test/cairnloop/schema_prefix_test.exs`

**Analog:** self, plus neighboring source-scan tests above.

**Docker-first docs pattern** (`test/cairnloop/docs/docker_first_docs_test.exs` lines 1-16):
```elixir
defmodule Cairnloop.Docs.DockerFirstDocsTest do
  @moduledoc """
  DB-free source scan for the Docker-first adopter docs.

  The test reads documentation and wrapper source only. It never starts Docker, Phoenix, Repo,
  browser tooling, or `./bin/demo smoke`.
  """

  use ExUnit.Case, async: true

  @readme_path "README.md"
  @quickstart_path "guides/01-quickstart.md"
  @troubleshooting_path "guides/04-troubleshooting.md"
  @example_readme_path "examples/cairnloop_example/README.md"
```

**Ordering and helper pattern** (`test/cairnloop/docs/docker_first_docs_test.exs` lines 176-193):
```elixir
defp assert_contains(source, expected) do
  assert source =~ expected, "Expected source to include #{inspect(expected)}"
end

defp assert_order(source, first, second, label) do
  first_position = position!(source, first, label)
  second_position = position!(source, second, label)

  assert first_position < second_position,
         "Expected #{inspect(first)} to appear before #{inspect(second)} in #{label}"
end
```

**Schema-prefix semantics pattern** (`test/cairnloop/schema_prefix_test.exs` lines 16-47):
```elixir
test "new installs default to the cairnloop schema prefix" do
  Application.delete_env(:cairnloop, :schema_prefix)

  assert Cairnloop.SchemaPrefix.default() == "cairnloop"
  assert Cairnloop.SchemaPrefix.configured() == "cairnloop"
  assert Cairnloop.SchemaPrefix.repo_opts() == [prefix: "cairnloop"]
end

test "public compatibility prefers explicit public schema" do
  assert Cairnloop.SchemaPrefix.configured(schema_prefix: "public") == "public"
end
```

**Apply to:** extend in place only when the corresponding source or docs claims change. Keep these tests DB-free unless a planner explicitly assigns runtime prefix proof.

---

### Public Install Docs

**Files:** `README.md`, `guides/01-quickstart.md`, `guides/04-troubleshooting.md`, `examples/cairnloop_example/README.md`, `UPGRADING.md`

**Analog:** `lib/mix/tasks/cairnloop/install.ex`, existing Docker-first sections in README/Quickstart/example README.

**Installer notice source of truth** (`lib/mix/tasks/cairnloop/install.ex` lines 86-146):
```elixir
defp next_steps_notice do
  """
  Cairnloop is host-owned. To finish wiring it up:

    2. Configure Cairnloop to use your Ecto repo:

         config :cairnloop, :repo, MyApp.Repo

       New installs default Cairnloop support tables to the `cairnloop` Postgres schema:

         config :cairnloop, :schema_prefix, "cairnloop"

       Existing public-schema installs can explicitly keep public compatibility while migrating:

         config :cairnloop, :schema_prefix, "public"

    4. Run the host migration generated in your app, then the Cairnloop dependency migrations:

         mix ecto.migrate
         mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations

       Cairnloop migrations read `:schema_prefix` and qualify their own tables in source.
       Do not use `mix ecto.migrate --prefix cairnloop` as a shortcut; that can move
       migrator bookkeeping and still would not fix raw SQL, triggers, or generated host DDL.
  """
end
```

**README ordering pattern** (`README.md` lines 11-29):
````markdown
### Try the live demo first

From a fresh clone, the fastest way to see Cairnloop working is the Docker demo:

```bash
./bin/demo
```

The command starts the example Phoenix app, a private pgvector Postgres container, migrations, and
the realistic Trailmark seed data.

### Install in your app
````

**Quickstart Docker-first pattern** (`guides/01-quickstart.md` lines 6-27):
````markdown
## Fastest path: Docker demo

If your goal is to click around the operator UI and understand the product, start here:

```bash
./bin/demo
```

That single command starts a private pgvector Postgres container, builds the example Phoenix app,
runs migrations, loads the realistic Trailmark seed data, waits for `/health`, and prints the URLs
you need next.
````

**Upgrade schema-prefix pattern** (`UPGRADING.md` lines 6-50):
````markdown
## v0.5.1 and the `cairnloop` Postgres schema default

New installs default Cairnloop support-domain tables to the dedicated Postgres schema prefix
`cairnloop`:

```elixir
config :cairnloop, :schema_prefix, "cairnloop"
```

Existing installs that already have `public.cairnloop_*` tables should not silently switch to an
empty dedicated schema. Pin explicit public compatibility first:

```elixir
config :cairnloop, :schema_prefix, "public"
```

Do not treat `mix ecto.migrate --prefix cairnloop` as the setup contract.
````

**Example README compatibility pattern** (`examples/cairnloop_example/README.md` lines 81-83):
```markdown
The example config uses `schema_prefix: "cairnloop"` so new installs create Cairnloop support
tables in the dedicated `cairnloop` Postgres schema. Existing public-schema adopters can set
`schema_prefix: "public"` as an intentional compatibility switch while planning a data migration.
```

**Apply to:** preserve Docker-first evaluation before host install. Replace stale public-schema compatibility references to `nil` with explicit `"public"` plus legacy-only wording. Replace dependency migration commands containing `--prefix cairnloop` with the two ordered commands from the installer. Keep host-owned responsibilities explicit.

---

### Public Trust and Auth Docs

**Files:** `SECURITY.md`, `guides/03-host-integration.md`, `guides/05-mcp-clients.md`, `guides/07-auth-and-operator-identity.md`, trust-sensitive sections of README/Quickstart/Troubleshooting

**Analog:** `SECURITY.md`, `guides/07-auth-and-operator-identity.md`, `guides/03-host-integration.md`, `lib/cairnloop/doctor.ex`

**Security policy pattern** (`SECURITY.md` lines 3-42):
```markdown
## Supported Versions

Cairnloop is pre-1.0 OSS. Security fixes target the latest released version and `main` unless a
maintainer explicitly states otherwise in a release note.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories when available,
or by opening a minimal private contact request with the maintainer. Do not include working exploit
details in a public issue.

## Scope

Security-sensitive Cairnloop areas include:

- operator identity and host-auth integration
- email/webhook ingress
- governed tool approvals and outbound side effects
- MCP tokens and admin surfaces
```

**Auth seam pattern** (`guides/07-auth-and-operator-identity.md` lines 58-70):
```elixir
scope "/support" do
  pipe_through [:browser, :require_admin]

  Cairnloop.Router.cairnloop_dashboard "/",
    on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
    session: {MyAppWeb.UserAuth, :cairnloop_session, []}
end
```

**Per-request identity pattern** (`guides/07-auth-and-operator-identity.md` lines 107-142):
```elixir
defmodule MyAppWeb.UserAuth do
  def cairnloop_session(conn) do
    %{"host_user_id" => to_string(conn.assigns.current_user.id)}
  end
end

scope "/support" do
  pipe_through [:browser, :require_admin]

  Cairnloop.Router.cairnloop_dashboard "/",
    on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
    session: {MyAppWeb.UserAuth, :cairnloop_session, []}
end
```

**Doctor honesty pattern** (`lib/cairnloop/doctor.ex` lines 156-159):
```elixir
{:ok,
 "Ready: `/health` is mounted as liveness only. Not checked here: database, Oban, " <>
   "pgvector, notifier, ingress, MCP, and Scrypath readiness."}
```

**Apply to:** keep trust docs modest and source-backed. State Cairnloop does not replace host auth/authorization, route protection, secret storage, production monitoring, or tenant isolation. Keep `/health` liveness-only and point readiness diagnostics to `mix cairnloop.doctor`.

---

### ExDoc, Hex Package, and Quality Lane

**File:** `mix.exs`

**Analog:** `mix.exs`, `test/cairnloop/web/collateral_wiring_test.exs`

**Package and ExDoc pattern** (`mix.exs` lines 22-67):
```elixir
package: [
  name: "cairnloop",
  files: ~w(
      lib
      priv
      mix.exs
      README.md
      LICENSE
      SECURITY.md
      UPGRADING.md
      CHANGELOG.md
      guides/01-quickstart.md
      guides/02-jtbd-walkthrough.md
      guides/03-host-integration.md
      guides/04-troubleshooting.md
      guides/05-mcp-clients.md
      guides/06-extending.md
      guides/07-auth-and-operator-identity.md
    ),
  licenses: ["MIT"]
],
docs: [
  main: "readme",
  extras: [
    {"guides/01-quickstart.md", title: "Quickstart"},
    {"guides/02-jtbd-walkthrough.md", title: "JTBD Walkthrough"},
    "UPGRADING.md",
    "README.md",
    "SECURITY.md",
    "CHANGELOG.md"
  ],
  assets: %{"guides/assets" => "assets"}
]
```

**Quality lane pattern** (`mix.exs` lines 97-148):
```elixir
"ci.fast": [
  "deps.get --check-locked",
  "format --check-formatted",
  "compile --warnings-as-errors",
  "test --exclude integration --warnings-as-errors"
],
"ci.quality": [
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "credo --strict",
  "cmd mix hex.build",
  "docs --warnings-as-errors",
  "deps.audit --ignore-advisory-ids GHSA-gp9c-pm5m-5cxr,GHSA-j9wq-vxxc-94wf,GHSA-mp55-p8c9-rfw2,GHSA-pj7v-xfvx-wmjq"
]
```

**Apply to:** keep README, LICENSE, SECURITY, UPGRADING, CHANGELOG, and guides in `package[:files]`; keep the same public docs in `docs[:extras]`; keep `docs[:assets]` mapping `guides/assets` to `assets`; verify with source-scan tests plus `mix ci.fast && mix ci.quality`.

---

### Installer, Root Module, and Doctor Docs

**Files:** `lib/mix/tasks/cairnloop/install.ex`, `lib/mix/tasks/cairnloop.doctor.ex`, `lib/cairnloop.ex`, `lib/cairnloop/schema_prefix.ex`, `lib/cairnloop/doctor.ex`

**Analog:** self for each file.

**Igniter task pattern** (`lib/mix/tasks/cairnloop/install.ex` lines 13-31):
```elixir
use Igniter.Mix.Task

@cairnloop_version Mix.Project.config()[:version]

@impl Igniter.Mix.Task
def igniter(igniter) do
  igniter
  |> Igniter.Project.Deps.add_dep({:cairnloop, "~> #{@cairnloop_version}"})
  |> add_base_migration()
  |> Igniter.add_notice(next_steps_notice())
end
```

**Schema-prefix contract wording** (`lib/cairnloop/schema_prefix.ex` lines 2-9):
```elixir
@moduledoc """
Internal helpers for Cairnloop's Postgres schema-prefix contract.

New installs default Cairnloop support-domain tables to the `cairnloop` Postgres schema. Existing
public-schema installs may explicitly set `config :cairnloop, :schema_prefix, "public"` or the
legacy `nil` compatibility value while they migrate. Oban remains host-owned and is not covered
by this prefix.
"""
```

**Root module guide links** (`lib/cairnloop.ex` lines 9-14):
```elixir
Start with the README and guides:

- `README.md` for the fastest Docker demo path and host-app install overview.
- `guides/01-quickstart.md` for setup and migration order.
- `guides/03-host-integration.md` for callbacks, router mounting, telemetry, and production notes.
```

**Doctor task doc pattern** (`lib/mix/tasks/cairnloop.doctor.ex` lines 4-31):
```elixir
@moduledoc """
Diagnoses your host application's Cairnloop wiring and prints calm, reason-forward findings.

It inspects your router and `:cairnloop` config to catch the "compiles but isn't wired"
problems that are easy to miss.

## Usage

    mix cairnloop.doctor
    mix cairnloop.doctor MyAppWeb.Router
    mix cairnloop.doctor --strict
"""
```

**Apply to:** prefer docs-only edits here. Do not alter runtime behavior unless a phase task identifies a tiny source-doc typo. Keep source docs aligned with README/guides and avoid claiming doctor performs DB-backed readiness checks it does not perform.

---

### Changelog and Release Trust

**File:** `CHANGELOG.md`

**Analog:** `CHANGELOG.md`

**Changelog structure pattern** (`CHANGELOG.md` lines 1-8 and 79-85):
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

**Apply to:** add Phase 60 notes under `Unreleased` if docs/package trust changes need public release visibility. Check compare links and avoid stale pre-v0.5 package claims.

---

### Guide Assets

**Files:** `guides/02-jtbd-walkthrough.md`, `guides/assets/*`

**Analog:** `guides/02-jtbd-walkthrough.md`, `test/cairnloop/web/collateral_wiring_test.exs`

**Markdown asset reference pattern** (`guides/02-jtbd-walkthrough.md` lines 14-44):
```markdown
![Cairnloop demo index - the Trailmark scenario and a guided tour of all nine JTBD stages](assets/00-demo-index.png)

![The customer-facing chat widget at /chat](assets/01-customer-chat.png)

![The operator inbox at /support, listing conversations across the lifecycle](assets/02-operator-inbox.png)
```

**Apply to:** either restore the missing `guides/assets/02-operator-inbox.png` or update the guide to an existing intended asset such as `guides/assets/02b-operator-inbox.png` after comparing the screenshot content. Add a source-scan in `package_docs_truth_test.exs` so missing guide assets fail fast.

## Shared Patterns

### Source-Scanned Docs Truth

**Source:** `test/cairnloop/docs/docker_first_docs_test.exs`, `test/cairnloop/demo_runtime_contract_test.exs`, `test/cairnloop/tasks/install_test.exs`
**Apply to:** all new/extended docs tests

Use `use ExUnit.Case, async: true`, module attributes for file paths, `File.read!`, explicit `assert source =~ expected`, explicit `refute source =~ forbidden`, and small helper functions. Keep tests DB-free and browser-free.

### Installer as Install Contract

**Source:** `lib/mix/tasks/cairnloop/install.ex`
**Apply to:** README, Quickstart, Troubleshooting, UPGRADING, example README, installer tests

The installer owns dependency version derivation, generated migration shape, schema-prefix guidance, migration order, and `mix cairnloop.doctor` next step. Public docs mirror this rather than inventing independent snippets.

### Package and ExDoc Authority

**Source:** `mix.exs`
**Apply to:** `mix.exs`, package/docs source-scan tests, README guide links, CHANGELOG/SECURITY/UPGRADING docs

Treat `mix.exs` as the source of truth for version, package files, ExDoc extras/assets/groups, and `ci.quality`. Tests should compare docs snippets to `Mix.Project.config()[:version]` or parse `mix.exs` directly.

### Host-Owned Trust Boundary

**Source:** `guides/07-auth-and-operator-identity.md`, `guides/03-host-integration.md`, `SECURITY.md`, `lib/cairnloop/doctor.ex`
**Apply to:** README, Quickstart, Host Integration, Troubleshooting, MCP, Security, Upgrading

State that host apps own route auth, authorization, repo config, operator identity injection, Oban, secrets, monitoring, and public-schema migration timing. Cairnloop supplies safe defaults, explicit seams, doctor checks, and docs.

### Verification

**Source:** `mix.exs` aliases, `60-VALIDATION.md`
**Apply to:** all Phase 60 plans

Focused tests should run first:

```bash
mix test test/cairnloop/tasks/install_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/docs_trust_test.exs test/cairnloop/demo_runtime_contract_test.exs test/cairnloop/web/collateral_wiring_test.exs --exclude integration --warnings-as-errors
```

Phase gate:

```bash
mix ci.fast && mix ci.quality
```

Add `mix ci.integration` only if implementation touches DB-backed behavior or needs live Postgres proof for a docs claim.

## No Analog Found

No new/modified file lacks a close analog. The only decision-shaped item is the missing guide asset: the planner should choose between restoring `guides/assets/02-operator-inbox.png` or changing the reference to an existing asset after checking the guide copy against current screenshots.

## Metadata

**Analog search scope:** `README.md`, `guides/`, `examples/cairnloop_example/`, `lib/mix/tasks/`, `lib/cairnloop*.ex`, `mix.exs`, `test/cairnloop/`
**Files scanned:** 30+ candidate docs, tests, tasks, source docs, assets, and metadata files
**Primary analog files read:** `test/cairnloop/tasks/install_test.exs`, `test/cairnloop/docs/docker_first_docs_test.exs`, `test/cairnloop/docs_trust_test.exs`, `test/cairnloop/demo_runtime_contract_test.exs`, `test/cairnloop/web/collateral_wiring_test.exs`, `mix.exs`, `lib/mix/tasks/cairnloop/install.ex`
**Pattern extraction date:** 2026-06-30
