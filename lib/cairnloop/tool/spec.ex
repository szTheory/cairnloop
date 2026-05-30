defmodule Cairnloop.Tool.Spec do
  @moduledoc """
  Pure data struct carrying compile-time governed-tool metadata.

  No behaviour, no database — just a plain `defstruct` with enforced required fields.
  Forward-compatible with MCP tool definition projection (Phase 17): the `Spec` fields
  map directly to an MCP `tool` definition with zero model change.

  ## MCP-01 projection seam (Phase 17)

  The `%Cairnloop.Tool.Spec{}` fields project to MCP as:

  - `title`       → MCP `title`
  - `description` → MCP `description`
  - tool module name → MCP `name`
  - `changeset/2` Ecto embedded schema → MCP `inputSchema` (JSON Schema projection)

  Phase 17 performs this projection as a pure `Spec → map` transformation
  with no behaviour or database involvement.
  """

  @type t :: %__MODULE__{
          risk_tier: atom(),
          approval_mode: atom(),
          idempotency: atom() | map() | nil,
          result_states: [atom()] | nil,
          title: String.t() | nil,
          description: String.t() | nil
        }

  @enforce_keys [:risk_tier, :approval_mode]
  defstruct [
    # atom — :read_only | :low_write | :high_write | :destructive
    :risk_tier,
    # atom — :auto | :requires_approval | :always_block
    :approval_mode,
    # atom or map — idempotency key derivation strategy
    :idempotency,
    # list of atoms — declared result vocabulary for this tool
    :result_states,
    # string — human-readable name (Phase 14 preview, Phase 17 MCP "title")
    :title,
    # string — operator description (Phase 17 MCP "description")
    :description
  ]
end
