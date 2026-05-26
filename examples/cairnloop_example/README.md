# Cairnloop Example Application

This is an example host application demonstrating how to embed **Cairnloop** into an existing Phoenix application.

Cairnloop turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions—directly inside your existing monolith. 

**Support that leaves a trail.**

## Requirements

1. Elixir 1.15+ / OTP 26+
2. Postgres 16+ with `pgvector` extension installed.

## Setup

To start the demo app:

1. Setup the project dependencies and database:

   ```bash
   # Make sure your database has pgvector installed.
   # You can run `PGPORT=5433 docker compose up -d db` from the parent repository if you need one.
   mix setup
   ```

2. Start the Phoenix endpoint:

   ```bash
   mix phx.server
   ```

## Included Integrations

This example app includes:

1. **Oban**: `mix oban.install` has been run and Oban is configured in `config.exs`.
2. **pgvector**: A migration exists to add the `vector` extension, enabling Cairnloop's Knowledge Base embeddings.
3. **Cairnloop Core**: `mix cairnloop.install` and `mix cairnloop.add_draft_table` have been run.
4. **Cairnloop Dashboard**: Mounted at `/support` for Operator access.
5. **ChatLive Demo**: A mock customer chat interface at `/chat`.

## Routing

Cairnloop's dashboard is mounted in `lib/cairnloop_example_web/router.ex`:

```elixir
import Cairnloop.Router, only: [cairnloop_dashboard: 2]

scope "/support", CairnloopExampleWeb do
  pipe_through :browser
  
  cairnloop_dashboard("/", host_user_id: "demo_operator")
end
```

Visit [`localhost:4000/support`](http://localhost:4000/support) to view the Operator interface.
Visit [`localhost:4000/chat`](http://localhost:4000/chat) to interact with the mock customer ChatLive view.
