# M003-S01 Context: ContextProvider Behaviour & Core Integration

This document captures the architectural decisions resolved autonomously during the discussion phase for Milestone 3, Slice 01, following a deep research analysis of Elixir/Phoenix ecosystem idioms and Cairnloop's zero-API-sync design goals.

## 1. Callback Signature: Tagged Tuples Over Raw Maps
- **Decision:** Update the callback to return `{:ok, map()} | {:error, term()}` and accept the `actor_id` string rather than just expecting an unwrapped map.
  ```elixir
  @callback get_context(actor_id :: String.t(), opts :: keyword()) :: 
    {:ok, map()} | {:error, term()}
  ```
- **Rationale:** Relying on `try/rescue` is an anti-pattern for expected control flow in Elixir. Libraries like Oban and Pow expect tagged tuples to handle host-provided outcomes. If the host's database is down or a user record is missing, returning `{:error, :not_found}` allows Cairnloop's LiveView to gracefully render a "Context Unavailable" state without crashing the support operator's dashboard.

## 2. UI Rendering Structure (Zero-Config UI)
- **Decision:** The returned map should be a deeply nested map of simple Elixir terms (strings, numbers, booleans, dates) that Cairnloop will recursively render as categorized UI sections.
  ```elixir
  {:ok, %{
    "User Details" => %{name: "Alice", lifetime_value: "$450"},
    "Active Plan" => %{tier: "Pro", status: "past_due"}
  }}
  ```
- **Rationale:** The host developer just dumps their domain data into a map and instantly receives a beautifully structured UI in the dashboard without writing any frontend code. Furthermore, a structured map of simple terms is directly serializable into a JSON context payload for the AI RAG pipeline.

## 3. Identity Binding
- **Decision:** The behaviour accepts the raw `actor_id` verbatim. Do not assume `actor_id` maps perfectly to an internal `User` schema.
- **Rationale:** The host application must be responsible for mapping the raw identity string to their domain (e.g., resolving integer IDs, UUIDs, or emails). This cleanly decouples Cairnloop from the host's specific Ecto layout and identity primitives.

## 4. Path to S03 (LiveComponent Injection)
- **Decision:** For S03, we will extend this same map structure to allow returning a tuple of `{Module, assigns}` for specific keys, signaling that the host wants to take over rendering for that section.
  ```elixir
  {:ok, %{
    "Billing" => MyApp.Billing.support_snapshot(account), # Renders default key/value UI
    "Actions" => {MyAppWeb.SupportActionsComponent, %{account_id: account.id}} # Renders custom LiveComponent
  }}
  ```
- **Rationale:** This provides progressive enhancement. Hosts start with the 5-minute "Zero-Config" map approach and progressively swap out specific sections with custom interactive LiveComponents (like a "Refund User" button) only when needed, while maintaining strict process/namespace isolation via `phx-target`.
