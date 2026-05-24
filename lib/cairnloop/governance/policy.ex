defmodule Cairnloop.Governance.Policy do
  @moduledoc """
  Approval-mode resolver for governed tool proposals.

  Precedence: tool-declared `approval_mode` → host config override for the tier →
  `Cairnloop.Tool.derive_approval_mode/1` tier default.

  **Phase 15 seam:** Extend ONLY this module (`resolve/3`) to factor in actor scope and
  runtime context (the PDP). No schema change or call-site change needed. The resolver's
  function signature stays fixed; Phase 15 adds policy-context logic inside it.

  **Tighten-only by default (D-13):** A host may configure `approval_mode_overrides` to
  make the gate stricter (e.g. `:read_only → :requires_approval`). Loosening below the
  tier default (e.g. `:destructive → :auto`) is an explicit host-config choice and should
  be noted in the host's configuration documentation.
  """

  @doc """
  Resolves the approval mode for a governed tool.

  Precedence order:
  1. Tool's declared `approval_mode` (set via `use Cairnloop.Tool, approval_mode: ...`)
  2. Host config override for the resolved `risk_tier` (from `:approval_mode_overrides`)
  3. Tier default from `Cairnloop.Tool.derive_approval_mode/1` (fail-closed)
  """
  def resolve(tool_module, actor_id, context) do
    spec = tool_module.__tool_spec__()

    # Precedence: tool declaration → host config override → tier default (D-12)
    base_mode =
      spec.approval_mode ||
        host_config_override(spec.risk_tier) ||
        Cairnloop.Tool.derive_approval_mode(spec.risk_tier)

    # Phase 15 PDP extension: apply host policy context factors (D15-08).
    # No call-site change — signature stays fixed (D-12).
    apply_context_factors(base_mode, tool_module, actor_id, context)
  end

  defp host_config_override(risk_tier) do
    overrides = Application.get_env(:cairnloop, :approval_mode_overrides, %{})
    Map.get(overrides, risk_tier)
  end

  # Phase 15 PDP actor-scope hook (D15-08).
  #
  # This is the offered-NOT-enforced seam for host-defined four-eyes / RBAC logic.
  # The library does NOT enforce actor scope or identity-based rules here — there is no
  # identity model in Phase 15. Host integrators can override this pattern by injecting
  # custom policy logic via the `:approval_mode_overrides` config or by subclassing this
  # resolver in their host application.
  #
  # Starts as a pass-through; extending it in future phases does NOT require a call-site
  # change anywhere (D-12 signature-fixed guarantee).
  defp apply_context_factors(mode, _tool_module, _actor_id, _context) do
    # Pass-through: return base_mode unchanged.
    # Phase 16+ may add actor-scope or four-eyes enforcement here.
    mode
  end
end
