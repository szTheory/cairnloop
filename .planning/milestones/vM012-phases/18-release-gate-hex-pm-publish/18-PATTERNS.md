# Phase 18: Release Gate & Hex.pm Publish - Pattern Map

**Mapped:** 2026-05-25 (simulated)
**Files analyzed:** 4
**Analogs found:** 2 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `mix.exs` | config | batch | `mix.exs` (itself) | exact |
| `.github/workflows/release.yml` | config | batch | `.github/workflows/ci.yml` | role-match |
| `LICENSE` | config | file-I/O | None | none |
| `CHANGELOG.md` | config | file-I/O | None | none |

## Pattern Assignments

### `mix.exs` (config, batch)

**Analog:** `mix.exs`

**Project block pattern** (lines 4-13):
```elixir
  def project do
    [
      app: :cairnloop,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps()
    ]
  end
```

**Deps block pattern** (lines 43-47):
```elixir
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:pgvector, "~> 0.3.1"},
```

---

### `.github/workflows/release.yml` (config, batch)

**Analog:** `.github/workflows/ci.yml`

**CI Action and Elixir Setup Pattern** (lines 13-33):
```yaml
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19.0"
          otp-version: "27.2"

      - name: Restore Mix cache
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-

      - name: Install dependencies
        run: mix deps.get
```

---

## Shared Patterns

### Action Node Version
**Source:** `.github/workflows/ci.yml`
**Apply to:** `.github/workflows/release.yml`
```yaml
# Opt into Node.js 24 for all actions (actions/checkout, actions/cache, etc.)
env:
  ACTIONS_RUNNER_NODE_VERSION: "24"
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md / CONTEXT.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `LICENSE` | config | file-I/O | New root text file for the project's MIT license. |
| `CHANGELOG.md` | config | file-I/O | New markdown file following the keep-a-changelog format. |

## Metadata

**Analog search scope:** Workspace root, `.github/workflows/`
**Files scanned:** 2
**Pattern extraction date:** 2026-05-25 (simulated)
