defmodule Cairnloop.Governance.PreviewTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Module-under-test reference
  #
  # Cairnloop.Governance.Preview does NOT exist until Wave 1.
  # We reference it via a runtime alias so this file compiles now.
  # All tests that call Preview.render/1 are tagged :skip until Wave 1 ships.
  # ---------------------------------------------------------------------------

  @preview_module Cairnloop.Governance.Preview

  # ---------------------------------------------------------------------------
  # Inline fixture helpers (no shared factory — existing repo idiom)
  # ---------------------------------------------------------------------------

  defp base_proposal do
    %Cairnloop.Governance.ToolProposal{
      id: 1,
      tool_ref: "Cairnloop.Tools.LookupOrder",
      tool_version: nil,
      status: :proposed,
      risk_tier: :read_only,
      approval_mode: :auto,
      actor_id: "user_42",
      account_id: "acct_1",
      input_snapshot: %{order_id: "ord_123"},
      scope_snapshot: %{scopes: []},
      policy_snapshot: %{outcome: :proposed, reason: nil},
      events: []
    }
  end

  defp string_keyed_proposal do
    # Simulates the JSONB round-trip: after Postgres INSERT+SELECT, atom keys become strings.
    %{base_proposal() | input_snapshot: %{"order_id" => "ord_123"}}
  end

  # ---------------------------------------------------------------------------
  # describe: common path — structured summary (D-17)
  #
  # No tool in the test registry exports `preview/1`, so the COMMON path is
  # {:structured, _}. Tests run immediately; the live leg tests are skipped.
  # ---------------------------------------------------------------------------

  describe "Preview.render/1 — common path (no preview/1 callback, D-17)" do
    test "returns {:structured, map} when the tool does not export preview/1" do
      proposal = base_proposal()
      result = apply(@preview_module, :render, [proposal])
      assert {:structured, structured} = result
      assert is_map(structured)
    end

    test "structured result contains risk_tier" do
      proposal = base_proposal()
      {:structured, structured} = apply(@preview_module, :render, [proposal])
      assert Map.has_key?(structured, :risk_tier) or Map.has_key?(structured, "risk_tier")
    end

    test "structured result contains approval_mode" do
      proposal = base_proposal()
      {:structured, structured} = apply(@preview_module, :render, [proposal])
      assert Map.has_key?(structured, :approval_mode) or Map.has_key?(structured, "approval_mode")
    end
  end

  # ---------------------------------------------------------------------------
  # describe: fallback triggers — four D-19 footguns degrade to {:structured, _}
  # ---------------------------------------------------------------------------

  describe "Preview.render/1 — fallback when tool is unregistered (D-19 footgun 4)" do
    test "returns {:structured, _} when tool_ref resolves to unknown tool" do
      proposal = %{base_proposal() | tool_ref: "Elixir.NoSuchTool.DoesNotExist"}
      result = apply(@preview_module, :render, [proposal])
      assert {:structured, _} = result
    end
  end

  describe "Preview.render/1 — fallback when live preview/1 raises (D-19 try/rescue)" do
    test "returns {:structured, _} when preview/1 raises an exception" do
      # Test-only tool that exports preview/1 and raises RuntimeError
      defmodule RaisingPreviewTool do
        use Cairnloop.Tool,
          risk_tier: :read_only,
          title: "Raising Preview Tool"

        embedded_schema do
          field(:order_id, :string)
        end

        def changeset(struct, attrs) do
          Ecto.Changeset.cast(struct, attrs, [:order_id])
        end

        def run(_tool, _actor, _ctx), do: {:ok, %{}}
        def scope, do: []

        @impl Cairnloop.Tool
        def authorize(_actor_id, _context), do: :ok

        @impl Cairnloop.Tool
        def preview(_tool), do: raise(RuntimeError, "preview explodes")
      end

      Application.put_env(:cairnloop, :tools, [RaisingPreviewTool])

      proposal = %{base_proposal() | tool_ref: Atom.to_string(RaisingPreviewTool)}
      result = apply(@preview_module, :render, [proposal])
      assert {:structured, _} = result

      Application.delete_env(:cairnloop, :tools)
    end
  end

  describe "Preview.render/1 — fallback when live preview/1 returns non-string (D-19)" do
    test "returns {:structured, _} when preview/1 returns a non-string value" do
      # Test-only tool whose preview/1 returns {:ok, "description"} (not a plain binary)
      defmodule NonStringPreviewTool do
        use Cairnloop.Tool,
          risk_tier: :read_only,
          title: "Non String Preview Tool"

        embedded_schema do
          field(:order_id, :string)
        end

        def changeset(struct, attrs) do
          Ecto.Changeset.cast(struct, attrs, [:order_id])
        end

        def run(_tool, _actor, _ctx), do: {:ok, %{}}
        def scope, do: []

        @impl Cairnloop.Tool
        def authorize(_actor_id, _context), do: :ok

        @impl Cairnloop.Tool
        def preview(_tool), do: {:ok, "this is a description"}
      end

      Application.put_env(:cairnloop, :tools, [NonStringPreviewTool])

      proposal = %{base_proposal() | tool_ref: Atom.to_string(NonStringPreviewTool)}
      result = apply(@preview_module, :render, [proposal])
      assert {:structured, _} = result

      Application.delete_env(:cairnloop, :tools)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: string-keyed input_snapshot — partial JSONB round-trip simulation
  # (D-19 footgun 1 — string keys after Postgres INSERT+SELECT)
  # ---------------------------------------------------------------------------

  describe "Preview.render/1 — string-keyed snapshot (D-19 footgun 1)" do
    # REPO-UNAVAILABLE: full JSONB round-trip requires Postgres; string-keyed fixture is
    # partial coverage. The real footgun (atom→string key coercion on INSERT+SELECT) only
    # surfaces on a live Postgres round-trip. This test simulates the post-reload shape so
    # the code path is exercised without a DB.

    test "string-keyed input_snapshot produces same {:structured, _} as atom-keyed variant" do
      # Both atom-keyed and string-keyed proposals should produce the same structured output.
      atom_proposal = base_proposal()
      string_proposal = string_keyed_proposal()

      # Postcondition: both calls succeed and both return {:structured, _}.
      # (Key equality of the structured result is a Wave 1 assertion once Preview exists.)
      atom_result = apply(@preview_module, :render, [atom_proposal])
      string_result = apply(@preview_module, :render, [string_proposal])

      assert {:structured, _} = atom_result
      assert {:structured, _} = string_result
    end

    test "atomization uses String.to_existing_atom/1 not String.to_atom/1 (D-19 safety)" do
      # Source-assertion: the Preview module must not contain String.to_atom( (unbounded-atom DoS — D-19).
      preview_source = File.read!("lib/cairnloop/governance/preview.ex")
      refute preview_source =~ ~r/String\.to_atom\s*\(/,
             "Preview must not call String.to_atom/1 (unbounded-atom DoS — D-19 / T-14-01)"
    end
  end
end
