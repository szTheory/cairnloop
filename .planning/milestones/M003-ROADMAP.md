# Milestone M003: Deep Context Enrichment (The "SaaS in a Box" Integrations)

## Vision
Bind the support ticket natively to the Host's billing (Accrue) and identity (Sigra) state without brittle API syncing. Cairnloop remains decoupled by relying entirely on Elixir Behaviours (`Cairnloop.ContextProvider`) and Protocols, allowing the embedded LiveView to query the host's Ecto repo directly for deep context.

## Slices

- [x] **S01: ContextProvider Behaviour & Core Integration** `risk:medium` `depends:[]`
  > After this: A formal `Cairnloop.ContextProvider` behaviour is defined. The host can implement this to map a Cairnloop `actor_id` to their own domain models (e.g., `Users` or `Organizations`).

- [x] **S02: Dynamic Context Pane UI in LiveView** `risk:medium` `depends:[S01]`
  > After this: The `ConversationLive` dashboard features a dynamic right-hand "Context Pane" that renders data (like subscription tiers or identity claims) fetched via the host's `ContextProvider`.

- [x] **S03: Extensibility Components & Actions** `risk:high` `depends:[S02]`
  > After this: Host developers can inject custom interactive components (e.g., "Refund User" button talking to Accrue) directly into the Context Pane, with Cairnloop handling the layout and error boundaries.

## Success Criteria
- **Zero API Sync:** Context is queried dynamically from the host app's database using Elixir protocols/behaviours; no duplicate data ingestion is required.
- **Ergonomics:** The host developer experience for implementing the context provider is straightforward and well-documented.
- **Resilience:** If a host's context implementation fails or times out, the core support dashboard degrades gracefully without crashing.

## Horizontal Checklist
- [ ] Schema changes follow append-only conventions.
- [ ] Oban workers include retry logic.
- [ ] LiveView updates efficiently utilizing `stream/3`.