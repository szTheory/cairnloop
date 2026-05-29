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

The `mix test.setup` alias handles this automatically by dropping the test database (if it exists), creating it, running the host migrations (found in `priv/test_host/repo/migrations`), and then running the library's internal migrations (found in `priv/repo/migrations`).

## Running Tests

Cairnloop splits its test suite to keep the feedback loop fast for unit tests, while still providing robust end-to-end guarantees.

### 1. Isolated Unit Suite (Fast)

For TDD and fast feedback, run the isolated unit suite. These tests do not touch the database.

```bash
mix test
```

### 2. Integration Suite (DB-backed)

To run the full suite, including all Ecto-backed repository tests and full E2E state machine integration tests, use the integration alias:

```bash
mix test.integration
```

Always ensure `mix test.integration` passes before opening a Pull Request.

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

Thank you for helping make Cairnloop better!
