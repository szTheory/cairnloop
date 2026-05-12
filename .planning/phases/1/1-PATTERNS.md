# Phase 1: Foundation (Telemetry & Events) - Pattern Map

**Mapped:** 2024-05-18
**Files analyzed:** 2
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/chat.ex` | service | event-driven | `lib/cairnloop/chat.ex` (existing) | exact |
| `test/cairnloop/chat_test.exs` | test | event-driven | `test/cairnloop/chat_test.exs` (existing) | exact |

## Pattern Assignments

### `lib/cairnloop/chat.ex` (service, event-driven)

**Analog:** `lib/cairnloop/chat.ex` (Existing Implementation)

**Telemetry emission pattern** (lines 69-79):
```elixir
        :telemetry.execute(
          [:cairnloop, :conversation, :resolved],
          %{count: 1, duration_seconds: duration_seconds},
          %{
            conversation_id: updated_conversation.id,
            host_user_id: updated_conversation.host_user_id,
            actor: actor,
            metadata: Enum.into(metadata, %{})
          }
        )
```

---

### `test/cairnloop/chat_test.exs` (test, event-driven)

**Analog:** `test/cairnloop/chat_test.exs` (Existing Implementation)

**Telemetry testing pattern** (lines 96-118):
```elixir
    test "requires resolved_by in options and emits telemetry" do
      actor = %{type: "system", id: "system"}

      # Attach handler to capture telemetry
      :telemetry.attach(
        "test-resolve-handler",
        [:cairnloop, :conversation, :resolved],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )

      assert {:ok, _} = Chat.resolve_conversation(1, resolved_by: actor, custom_meta: "foo")

      assert_receive {:telemetry_event, measurements, metadata}
      assert Map.has_key?(measurements, :duration_seconds)
      assert measurements.duration_seconds >= 100

      assert metadata.actor == actor
      assert metadata.metadata[:custom_meta] == "foo"
      assert metadata.conversation_id == 1

      :telemetry.detach("test-resolve-handler")
    end
```

---

## Shared Patterns

### Telemetry Execution
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** All services emitting observability events
```elixir
:telemetry.execute(
  [:app, :domain, :event_name],
  %{count: 1, metric: value}, # Measurements
  %{id: id, actor: actor} # Metadata
)
```

### Telemetry Testing
**Source:** `test/cairnloop/chat_test.exs`
**Apply to:** All tests for services that emit telemetry
```elixir
:telemetry.attach(
  "test-handler-id",
  [:app, :domain, :event_name],
  fn _event, measurements, metadata, _config ->
    send(self(), {:telemetry_event, measurements, metadata})
  end,
  nil
)

# ... perform action ...

assert_receive {:telemetry_event, measurements, metadata}
# ... assert on measurements and metadata ...

:telemetry.detach("test-handler-id")
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| None | - | - | All files have an exact match. |

## Metadata

**Analog search scope:** `lib/`, `test/`
**Files scanned:** 2
**Pattern extraction date:** 2024-05-18