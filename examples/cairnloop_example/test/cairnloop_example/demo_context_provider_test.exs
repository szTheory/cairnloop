defmodule CairnloopExample.DemoContextProviderTest do
  use ExUnit.Case, async: true

  alias CairnloopExample.DemoContextProvider

  @known_actors [
    "demo_user_acme_billing",
    "demo_user_globex_seats",
    "demo_user_initech_billing",
    "demo_user_umbrella_ci",
    "demo_user_hooli_tokens"
  ]

  describe "DemoContextProvider" do
    test "get_context/2 returns documented shape for demo_user_acme_billing" do
      assert {:ok, %{"User Details" => ud, "Active Plan" => ap}} =
               DemoContextProvider.get_context("demo_user_acme_billing", [])

      assert is_binary(ud[:email])
      assert is_binary(ap[:tier])
    end

    test "get_context/2 returns at least 2 sections for each known demo actor" do
      for actor <- @known_actors do
        assert {:ok, ctx} = DemoContextProvider.get_context(actor, []),
               "Expected {:ok, ctx} for actor #{inspect(actor)}"

        assert map_size(ctx) >= 2,
               "Expected at least 2 sections for actor #{inspect(actor)}, got #{map_size(ctx)}"
      end
    end

    test "get_context/2 fail-opens for unknown actors" do
      assert {:ok, %{}} == DemoContextProvider.get_context("totally_random_unknown_user_xyz", [])
    end

    test "all section keys are strings (no raw atoms surfaced)" do
      for actor <- @known_actors do
        {:ok, ctx} = DemoContextProvider.get_context(actor, [])

        assert Enum.all?(Map.keys(ctx), &is_binary/1),
               "Expected all section keys to be strings for actor #{inspect(actor)}, got: #{inspect(Map.keys(ctx))}"
      end
    end

    test "all inner-map values are simple terms (no Elixir atoms in values)" do
      for actor <- @known_actors do
        {:ok, ctx} = DemoContextProvider.get_context(actor, [])

        for {section, inner_map} <- ctx, is_map(inner_map), {_key, value} <- inner_map do
          assert is_binary(value) or is_integer(value) or is_float(value) or is_boolean(value) or
                   is_nil(value) or match?(%Date{}, value) or match?(%DateTime{}, value),
                 "Expected simple term in section #{inspect(section)} for actor #{inspect(actor)}, got atom: #{inspect(value)}"
        end
      end
    end
  end
end
