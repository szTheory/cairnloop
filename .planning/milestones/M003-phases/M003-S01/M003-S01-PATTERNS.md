# Phase M003-S01: ContextProvider Behaviour & Core Integration - Pattern Map

**Mapped:** 2023-10-27
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/context_provider.ex` | behaviour | request-response | `lib/cairnloop/automation_policy.ex` | exact |
| `lib/cairnloop/default_context_provider.ex` | provider | request-response | `lib/cairnloop/default_automation_policy.ex` | exact |
| `test/cairnloop/context_provider_test.exs` | test | none | `test/cairnloop/automation_policy_test.exs` | exact |
| `lib/cairnloop/web/conversation_live.ex` | controller | request-response | `lib/cairnloop/web/conversation_live.ex` | exact |

## Pattern Assignments

### `lib/cairnloop/context_provider.ex` (behaviour, request-response)

**Analog:** `lib/cairnloop/automation_policy.ex`

**Behaviour Definition Pattern** (lines 1-12):
```elixir
defmodule Cairnloop.AutomationPolicy do
  @moduledoc """
  Behaviour for providing host application AI policy boundaries.
  Allows host applications to dictate how AI drafts are handled.
  """

  @doc """
  Decides how a given AI proposal should be handled.
  Returns :allow, :draft_only, :require_approval, or :deny.
  """
  @callback decide(proposal :: map(), opts :: map()) ::
              :allow | :draft_only | :require_approval | :deny
end
```

---

### `lib/cairnloop/default_context_provider.ex` (provider, request-response)

**Analog:** `lib/cairnloop/default_automation_policy.ex`

**Behaviour Implementation Pattern** (lines 1-13):
```elixir
defmodule Cairnloop.DefaultAutomationPolicy do
  @moduledoc """
  Default implementation of Cairnloop.AutomationPolicy.
  Always returns :draft_only to ensure AI generated outputs are treated safely by default.
  """

  @behaviour Cairnloop.AutomationPolicy

  @impl true
  def decide(_proposal, _opts) do
    :draft_only
  end
end
```

---

### `test/cairnloop/context_provider_test.exs` (test, none)

**Analog:** `test/cairnloop/automation_policy_test.exs`

**Test Pattern** (lines 1-13):
```elixir
defmodule Cairnloop.AutomationPolicyTest do
  use ExUnit.Case, async: true

  alias Cairnloop.DefaultAutomationPolicy

  describe "DefaultAutomationPolicy" do
    test "decide/2 returns :draft_only for any proposal" do
      proposal = %{content: "This is a proposal", conversation_id: "conv_123"}
      opts = %{}

      assert :draft_only == DefaultAutomationPolicy.decide(proposal, opts)
    end
  end
end
```

---

### `lib/cairnloop/web/conversation_live.ex` (controller, request-response)

**Analog:** `lib/cairnloop/web/conversation_live.ex`

**Configuration Dependency Injection Pattern** (lines 12-23):
```elixir
    context =
      case Application.get_env(:cairnloop, :context_provider) do
        provider when is_atom(provider) and not is_nil(provider) ->
          if conversation.host_user_id do
            provider.get_context(conversation.host_user_id)
          else
            %{}
          end

        _ ->
          %{}
      end
```
*Note: This will be updated to handle the new `{:ok, map()} | {:error, term()}` return signature.*

## Shared Patterns

### Dependency Injection via Application Config
**Source:** `lib/cairnloop/web/conversation_live.ex`
**Apply to:** All points where behaviour implementations need to be dynamically loaded.
```elixir
Application.get_env(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider)
```

## Metadata

**Analog search scope:** `lib/**/*.ex`, `test/**/*.exs`
**Files scanned:** ~30
**Pattern extraction date:** 2023-10-27