# Contributing to Cairnloop

Thank you for your interest in contributing to Cairnloop!

As an embedded support operations layer for Phoenix apps, Cairnloop has a unique testing and development setup. Because it ships its own Ecto migrations but *also* relies on host application tables (like `cairnloop_conversations`), the local development environment must simulate a host Phoenix application.

## Local Development Setup

To get started, clone the repository and follow the standard Elixir setup routine:

```bash
# Fetch dependencies
mix deps.get

# Bootstrap the test database and run all migrations
mix test.setup
```

### Why `mix test.setup` is required

Unlike typical libraries, you cannot just run `mix test` out of the box or rely solely on `mix ecto.migrate`. Cairnloop requires a dual-path migration strategy:

1.  **Host Tables:** The tables that your Phoenix app would typically own (e.g., the primary `cairnloop_conversations` table) must be created first.
2.  **Library Tables:** Cairnloop's internal tables (knowledge base, audit logs, MCP tokens) are created second.

The `mix test.setup` alias handles this automatically by creating the test databases, running the
host migrations (found in `priv/test_host/migrations`), and then running the library's internal
migrations (found in `priv/repo/migrations`).

## Running Checks

Cairnloop splits its checks to keep contributor feedback fast while still preserving DB-backed and
browser confidence.

### 1. Fast Headless CI Lane

For normal library work, run the same fast lane CI uses:

```bash
mix ci.fast
```

This verifies locked deps, formatting, warnings-as-errors compilation, and the full headless ExUnit
suite with `:integration` excluded.

For release-sized changes, run the full local gate:

```bash
mix ci
```

This shells out to the fast, integration, and quality lanes so each lane keeps the same environment
it uses in CI.

### 2. Static Quality Lane

For docs, public API, packaging, or dependency changes:

```bash
mix ci.quality
```

This checks unused deps, warnings-as-errors compilation, Credo, ExDoc warnings, Hex package build,
and dependency audit.

### 3. Integration Suite (DB-backed)

For DB-backed workflows and full state-machine integration tests:

```bash
mix ci.integration
```

### 4. Example Browser Lane

For mounted dashboard UI, LiveView browser behavior, or example app changes:

```bash
cd examples/cairnloop_example
mix test.e2e
```

If your local example database is running on the expected port, `mix ci.full` runs `mix ci` and then
the example E2E lane.

### 5. Docker Adoption Smoke

For Docker/demo setup, docs, or adoption-flow changes:

```bash
./bin/demo smoke
```

The smoke command uses an isolated Compose project, checks the main demo routes, and removes its
containers and volumes when it finishes.

## Generating Documentation

We use `ExDoc` for documentation. To generate and view the hexdocs locally:

```bash
mix docs
open doc/index.html
```

## Pull Request Guidelines

1.  **Tests:** All new features or bug fixes must include corresponding tests.
2.  **Documentation:** If you add a new `@callback` behaviour or change the public API, update the relevant guides in the `guides/` directory.
3.  **Format:** Ensure your code is formatted correctly by running `mix format`.
4.  **Changelog:** Do not update `CHANGELOG.md` in your PR. The maintainers will update it during the release process.
5.  **Operator UI:** Read `docs/operator-ui-principles.md` before changing dashboard UI. Reuse the Cairnloop component/token system instead of adding one-off styles.

Thank you for helping make Cairnloop better!
