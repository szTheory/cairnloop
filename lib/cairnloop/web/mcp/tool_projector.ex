defmodule Cairnloop.Web.MCP.ToolProjector do
  @moduledoc """
  Pure total function transform: `%Cairnloop.Tool.Spec{}` + tool module → MCP tool definition map.

  No DB, no side effects, no supervision. Host opts in by mounting
  `Cairnloop.Web.MCP.Router` (D17-08) — this module is called by the Router's
  `tools/list` handler.

  ## MCP tool definition shape

  Produces a plain map with string keys matching the MCP 2025-03-26 `Tool` object:

      %{
        "name"        => "Elixir.Cairnloop.Tools.InternalNote",
        "title"       => "Add internal note",
        "description" => "Appends an operator-only note to the conversation thread.",
        "inputSchema" => %{
          "type"       => "object",
          "properties" => %{
            "conversation_id" => %{"type" => "string"},
            "content"         => %{"type" => "string"}
          },
          "required" => ["conversation_id", "content"]
        },
        "x-cairnloop-risk-tier"     => "low_write",
        "x-cairnloop-approval-mode" => "requires_approval"
      }

  ## inputSchema derivation

  `inputSchema` is derived by calling `tool_module.changeset(struct(tool_module), %{})`
  with empty attrs. This yields:
    - `cs.required` — list of required field atoms from `validate_required/2`
    - `cs.types`    — map of field atom → Ecto type atom

  The `:id` auto-generated field is excluded from `properties` (Pitfall 2 from RESEARCH.md).
  Ecto types are mapped to JSON Schema type strings via a minimal safe mapping table.
  """

  @doc """
  Projects a `{tool_module, %Cairnloop.Tool.Spec{}}` tuple to an MCP tool definition map.

  Returns a plain map with string keys. All values are JSON-safe.
  """
  @spec spec_to_mcp({module(), Cairnloop.Tool.Spec.t()}) :: map()
  def spec_to_mcp({tool_module, spec}) do
    %{
      "name" => Atom.to_string(tool_module),
      "title" => spec.title || "",
      "description" => spec.description || "",
      "inputSchema" => derive_input_schema(tool_module),
      "x-cairnloop-risk-tier" => Atom.to_string(spec.risk_tier),
      "x-cairnloop-approval-mode" => Atom.to_string(spec.approval_mode)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Derives a JSON Schema `object` from the tool module's Ecto embedded schema.
  # Calls `changeset/2` with empty attrs to extract `required` and `types`.
  # Excludes the auto-generated `:id` field (Pitfall 2 — embedded_schema adds :id).
  defp derive_input_schema(tool_module) do
    struct = struct(tool_module)
    cs = tool_module.changeset(struct, %{})

    required_json = Enum.map(cs.required, &to_string/1)

    properties =
      cs.types
      |> Enum.reject(fn {field, _} -> field == :id end)
      |> Enum.map(fn {field, ecto_type} ->
        {to_string(field), %{"type" => ecto_type_to_json_schema(ecto_type)}}
      end)
      |> Map.new()

    schema = %{"type" => "object", "properties" => properties}
    if required_json != [], do: Map.put(schema, "required", required_json), else: schema
  end

  # Maps Ecto types to JSON Schema type strings.
  # Safe fallback for unknown types — never hand-roll an elaborate resolver (RESEARCH.md).
  defp ecto_type_to_json_schema(:string), do: "string"
  defp ecto_type_to_json_schema(:integer), do: "integer"
  defp ecto_type_to_json_schema(:float), do: "number"
  defp ecto_type_to_json_schema(:boolean), do: "boolean"
  defp ecto_type_to_json_schema(:binary_id), do: "string"
  defp ecto_type_to_json_schema({:array, _}), do: "array"
  defp ecto_type_to_json_schema(:map), do: "object"
  defp ecto_type_to_json_schema(_), do: "string"
end
