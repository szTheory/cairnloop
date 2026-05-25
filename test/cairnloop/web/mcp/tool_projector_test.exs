defmodule Cairnloop.Web.MCP.ToolProjectorTest do
  @moduledoc """
  Headless (pure, no DB) proof of `Cairnloop.Web.MCP.ToolProjector.spec_to_mcp/1`.

  D17-10 requirements verified here:
  - `spec_to_mcp/1` projects `Cairnloop.Tools.InternalNote` to the correct MCP tool
    definition shape per RESEARCH.md Code Examples.
  - `inputSchema` contains only user-visible fields (no auto-generated `:id` — Pitfall 2).
  - `inputSchema.required` matches changeset `validate_required/2` fields.
  - `x-cairnloop-*` extension fields are present for risk_tier and approval_mode.
  """

  use ExUnit.Case, async: true

  alias Cairnloop.Web.MCP.ToolProjector

  # ---------------------------------------------------------------------------
  # Env isolation: ensure :tools env is clean around each test
  # ---------------------------------------------------------------------------

  setup do
    Application.put_env(:cairnloop, :tools, [Cairnloop.Tools.InternalNote])
    on_exit(fn -> Application.delete_env(:cairnloop, :tools) end)
    :ok
  end

  # ---------------------------------------------------------------------------
  # spec_to_mcp/1 — InternalNote round-trip proof (D17-10)
  # ---------------------------------------------------------------------------

  describe "spec_to_mcp/1" do
    test "projects InternalNote to correct MCP tool definition" do
      result =
        ToolProjector.spec_to_mcp(
          {Cairnloop.Tools.InternalNote, Cairnloop.Tools.InternalNote.__tool_spec__()}
        )

      # name: module atom as string (Atom.to_string produces "Elixir.Module.Name")
      assert result["name"] == "Elixir.Cairnloop.Tools.InternalNote"

      # title and description come from Spec fields
      assert result["title"] == "Add internal note"
      assert result["description"] == "Appends an operator-only note to the conversation thread."

      # inputSchema: outer shape
      assert result["inputSchema"]["type"] == "object"

      # inputSchema: user-visible field properties
      assert result["inputSchema"]["properties"]["conversation_id"] == %{"type" => "string"}
      assert result["inputSchema"]["properties"]["content"] == %{"type" => "string"}

      # inputSchema: NO auto-generated :id field (Pitfall 2)
      refute Map.has_key?(result["inputSchema"]["properties"], "id")

      # inputSchema: required list matches validate_required/2
      assert result["inputSchema"]["required"] == ["conversation_id", "content"]

      # x-cairnloop extension fields present
      assert Map.has_key?(result, "x-cairnloop-risk-tier")
      assert Map.has_key?(result, "x-cairnloop-approval-mode")
    end

    test "x-cairnloop-risk-tier is string atom representation" do
      result =
        ToolProjector.spec_to_mcp(
          {Cairnloop.Tools.InternalNote, Cairnloop.Tools.InternalNote.__tool_spec__()}
        )

      # Atom.to_string(:low_write) == "low_write"
      assert result["x-cairnloop-risk-tier"] == "low_write"
      assert result["x-cairnloop-approval-mode"] == "requires_approval"
    end
  end
end
