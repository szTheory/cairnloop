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

## Demo Index

Start at the guided demo index: **http://localhost:4000**. It frames the Trailmark scenario
(a small dev-tools SaaS support desk) and links to every stage of the JTBD lifecycle. The seed
places 20 conversations across all lifecycle states — including four pre-positioned in specific
JTBD states (a pending AI draft, an action awaiting approval, an executed action, and an outbound
follow-up) — so every screen is live and clickable with no setup.

> **Port in use?** `PORT=4010 mix phx.server` (and `PGPORT=...` if Postgres isn't on 5433).

## Two-Tab Demo

Open two browser tabs after running `mix setup && mix phx.server` in the
`examples/cairnloop_example/` directory.

- **Tab 1 — Operator inbox:** http://localhost:4000/support
- **Tab 2 — Customer chat:** http://localhost:4000/chat

Type a message in the customer chat tab. The message lands in the operator
inbox as a new conversation. Open the conversation and reply. The reply
appears in the customer chat tab.

## Screenshots

The PNGs in the library's `guides/` (the JTBD walkthrough) are captured from this app's seeded
state by the Playwright tool in [`screenshots/`](screenshots/). To refresh them:

```bash
mix ecto.reset && mix phx.server          # boot the seeded demo
cd screenshots && npm install && npm run capture
```

The capture is **non-gating** — it asserts nothing and is not part of CI. The deterministic
`test/integration/golden_path_test.exs` (`Phoenix.LiveViewTest`) remains the source of CI truth.

## Included Integrations

This example app includes:

1. **Oban**: `mix oban.install` has been run and Oban is configured in `config.exs`.
2. **pgvector**: A migration exists to add the `vector` extension, enabling Cairnloop's Knowledge Base embeddings.
3. **Cairnloop Core**: `mix cairnloop.install` and `mix cairnloop.add_draft_table` have been run.
4. **Cairnloop Dashboard**: Mounted at `/support` for Operator access.
5. **Customer Chat (real ingress):** A `/chat` LiveView wired to `Cairnloop.Channels.WidgetSocket` so customer messages flow into the operator inbox in real time.

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
