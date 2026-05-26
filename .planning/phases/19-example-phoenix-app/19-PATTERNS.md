# Phase 19: Example Phoenix App - Pattern Map

**Mapped:** 2026-05-10 (approx)
**Files analyzed:** 5
**Analogs found:** 4 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/cairnloop_example/mix.exs` | config | config | N/A | none |
| `examples/cairnloop_example/config/config.exs` | config | config | `config/test.exs` | role-match |
| `examples/cairnloop_example/priv/repo/seeds.exs` | script | CRUD | `test/support/fixtures.ex` | role-match |
| `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` | route | request-response | `lib/cairnloop/router.ex` | partial |
| `examples/cairnloop_example/assets/css/app.css` | style | asset | `prompts/cairnloop.css` | exact |

## Pattern Assignments

### `examples/cairnloop_example/config/config.exs` (config, config)

**Analog:** `config/test.exs`

**Host configuration pattern** (lines 20-30):
```elixir
# Baseline repo injection — the key every lib module reads via
# Application.fetch_env!(:cairnloop, :repo).
config :cairnloop, :repo, CairnloopExample.Repo

# Register any tools provided by the host application
config :cairnloop, :tools, []
```

### `examples/cairnloop_example/priv/repo/seeds.exs` (script, CRUD)

**Analog:** `test/support/fixtures.ex`

**Seeding pattern for Conversations/Messages** (lines 14-43):
```elixir
# Create a dummy conversation using direct Repo insertion
{:ok, conversation} =
  %Cairnloop.Conversation{}
  |> Ecto.Changeset.change(%{
    status: :open, 
    subject: "Demo Customer Request", 
    host_user_id: "demo_user"
  })
  |> CairnloopExample.Repo.insert()

{:ok, _message} =
  %Cairnloop.Message{}
  |> Ecto.Changeset.change(%{
    conversation_id: conversation.id,
    content: "I need help with my account, can you reset my billing?",
    role: :user,
    metadata: %{}
  })
  |> CairnloopExample.Repo.insert()
```
*(Planner note: Ecto insertion ensures the dashboard has data to display immediately for DEMO-02).*

### `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` (route, request-response)

**Analog:** `lib/cairnloop/router.ex`

**Dashboard mounting pattern** (lines 2-20):
```elixir
# Import the dashboard macro
import Cairnloop.Router, only: [cairnloop_dashboard: 2]

scope "/support", CairnloopExampleWeb do
  pipe_through :browser

  # Mount the dashboard under a path. In a real app this is usually inside an admin pipeline.
  cairnloop_dashboard("/", host_user_id: "demo_operator")
end
```

### `examples/cairnloop_example/assets/css/app.css` (style, asset)

**Analog:** `prompts/cairnloop.css`

**Brand coloring pattern** (lines 2-18):
```css
/* Cairnloop brand tokens injected into host app for aesthetic cohesion */
:root {
  --cl-color-basalt: #18211F;
  --cl-color-trailpaper: #F5F0E6;
  --cl-color-warm-stone: #FBF7EE;
  --cl-color-path-copper: #A94F30;
  --cl-bg: var(--cl-color-trailpaper);
  --cl-primary: var(--cl-color-path-copper);
}

body {
  background-color: var(--cl-bg);
  color: var(--cl-color-basalt);
}
```

## Shared Patterns

### Brand Identity
**Source:** `prompts/cairnloop_brand_book.md`
**Apply to:** Example App's `README.md` and UI copy.
Use "Cairnloop" in prose (not `:cairn_loop`), emphasize "Support that leaves a trail", and avoid generic chatbot jargon. The tone should be "Operator-grade" and "Safe-by-default".

## No Analog Found

Files with no close match in the codebase:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `examples/cairnloop_example/mix.exs` | config | config | Standard Phoenix file, not present inside the codebase except for the lib `mix.exs`. The planner should use standard `mix phx.new` commands and inject `{:cairnloop, "~> 0.1"}`. |

## Metadata

**Analog search scope:** `test/support/**/*.ex`, `config/*.exs`, `lib/cairnloop/*.ex`, `prompts/*`
**Files scanned:** ~25
**Pattern extraction date:** 2026-05-10
